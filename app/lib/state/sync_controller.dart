import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/api/api_client.dart';
import '../data/db/database.dart';
import 'connectivity_controller.dart';
import 'session_controller.dart';

/// Drains the local queue of unsynced readings to the server.
///
/// Triggers: app start, connectivity coming back, a new reading being saved,
/// a periodic timer, and the user tapping "sync now". Runs are serialised;
/// a trigger during a run just marks that another pass is wanted.
///
/// Per reading: upload the photo (if not already uploaded) → post the
/// reading → mark synced. The reading id is generated on-device, so a retry
/// after a half-finished sync is idempotent on the server.
class SyncController extends ChangeNotifier {
  SyncController({
    required AppDatabase db,
    required ApiClient api,
    required SessionController session,
    required ConnectivityController connectivity,
  }) : _db = db,
       _api = api,
       _session = session,
       _connectivity = connectivity {
    _connectivity.addListener(_onConnectivityChanged);
    _session.addListener(_onSessionChanged);
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => sync());
  }

  final AppDatabase _db;
  final ApiClient _api;
  final SessionController _session;
  final ConnectivityController _connectivity;
  Timer? _timer;

  bool _running = false;
  bool _rerunRequested = false;
  DateTime? _lastSuccess;

  bool get isRunning => _running;
  DateTime? get lastSuccess => _lastSuccess;

  void _onConnectivityChanged() {
    if (_connectivity.isOnline) {
      sync();
    }
  }

  void _onSessionChanged() {
    if (_session.status == SessionStatus.signedIn && !_session.needsReauth) {
      sync();
    }
  }

  /// Returns the number of readings that reached the server in this pass.
  Future<int> sync() async {
    if (_session.status != SessionStatus.signedIn || _session.needsReauth) {
      return 0;
    }
    if (_running) {
      _rerunRequested = true;
      return 0;
    }
    _running = true;
    notifyListeners();
    var synced = 0;
    try {
      synced = await _drain();
    } finally {
      _running = false;
      notifyListeners();
      if (_rerunRequested) {
        _rerunRequested = false;
        unawaited(sync());
      }
    }
    return synced;
  }

  Future<int> _drain() async {
    final userId = _session.user!.id;
    // Only this user's readings: the server stamps `logged_by` from the
    // token, so syncing someone else's queued rows would misattribute them.
    final queue = (await _db.unsyncedReadings())
        .where((r) => r.loggedBy == userId)
        .toList();
    var synced = 0;

    for (final reading in queue) {
      await _db.updateReadingSync(reading.id, status: 'syncing');
      try {
        var photoKey = reading.photoKey;
        if (photoKey == null) {
          final path = reading.localPhotoPath;
          if (path == null || !await File(path).exists()) {
            await _db.updateReadingSync(
              reading.id,
              status: 'failed',
              lastError: 'الصورة غير موجودة على الجهاز',
              retryCount: reading.retryCount + 1,
            );
            continue;
          }
          final bytes = await File(path).readAsBytes();
          photoKey = await _api.uploadPhoto(
            bytes,
            contentType: _contentTypeFor(path),
          );
          await _db.updateReadingSync(
            reading.id,
            status: 'syncing',
            photoKey: photoKey,
          );
        }

        final syncedAt = await _api.submitReading(
          id: reading.id,
          meterId: reading.meterId,
          value: reading.value,
          photoKey: photoKey,
          loggedAt: reading.loggedAt,
        );
        await _db.updateReadingSync(
          reading.id,
          status: 'synced',
          syncedAt: syncedAt,
        );
        synced++;
        _lastSuccess = DateTime.now();
      } on NetworkException {
        // Lost connectivity mid-pass: leave the rest pending for next time.
        await _db.updateReadingSync(
          reading.id,
          status: 'pending',
          retryCount: reading.retryCount + 1,
        );
        break;
      } on ApiException catch (e) {
        if (e.isUnauthorized) {
          await _db.updateReadingSync(reading.id, status: 'pending');
          _session.markTokenRejected();
          break;
        }
        // A 4xx the server will keep rejecting (e.g. unknown meter): mark it
        // failed with the reason so the user can see it, and carry on.
        await _db.updateReadingSync(
          reading.id,
          status: 'failed',
          lastError: e.message,
          retryCount: reading.retryCount + 1,
        );
      } catch (e) {
        await _db.updateReadingSync(
          reading.id,
          status: 'failed',
          lastError: e.toString(),
          retryCount: reading.retryCount + 1,
        );
      }
    }
    return synced;
  }

  /// Puts a failed reading back in the queue and kicks a sync.
  Future<void> retry(String readingId) async {
    await _db.updateReadingSync(readingId, status: 'pending', lastError: null);
    unawaited(sync());
  }

  String _contentTypeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _connectivity.removeListener(_onConnectivityChanged);
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }
}
