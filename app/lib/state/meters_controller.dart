import 'package:flutter/foundation.dart';

import '../core/strings.dart';
import '../data/api/api_client.dart';
import '../data/db/database.dart';
import '../data/models.dart';
import 'session_controller.dart';

/// Keeps the local meter cache in step with the server. Reads always come
/// from the local database (via [AppDatabase.watchActiveMeters]); this class
/// only handles refreshing that cache when the network allows.
class MetersController extends ChangeNotifier {
  MetersController({
    required AppDatabase db,
    required ApiClient api,
    required SessionController session,
  }) : _db = db,
       _api = api,
       _session = session;

  final AppDatabase _db;
  final ApiClient _api;
  final SessionController _session;

  bool _refreshing = false;
  DateTime? _lastRefresh;

  bool get isRefreshing => _refreshing;
  DateTime? get lastRefresh => _lastRefresh;

  /// Returns true if the cache was updated from the server. A failure is
  /// swallowed (the cached list stays usable) except that a 401 flags the
  /// session for re-login.
  Future<bool> refresh() async {
    if (_refreshing) return false;
    _refreshing = true;
    notifyListeners();
    try {
      final includeInactive = _session.user?.isEngineer ?? false;
      final fromServer = await _api.fetchMeters(
        includeInactive: includeInactive,
      );
      await _db.replaceMeters(fromServer);
      _lastRefresh = DateTime.now();
      return true;
    } on ApiException catch (e) {
      if (e.isUnauthorized) _session.markTokenRejected();
      return false;
    } on NetworkException {
      return false;
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  // ---- engineer actions (online only) --------------------------------------

  /// Returns null on success or an Arabic error message. The cache is
  /// refreshed from the server afterwards so the list reflects the change.
  Future<String?> createMeter({
    required MeterType type,
    required String location,
    required int floorNumber,
    String? description,
    String? photoKey,
  }) => _mutate(
    () => _api.createMeter(
      type: type,
      location: location,
      floorNumber: floorNumber,
      description: description,
      photoKey: photoKey,
    ),
  );

  Future<String?> updateMeter(
    String id, {
    required MeterType type,
    required String location,
    required int floorNumber,
    String? description,
    String? photoKey,
    bool clearPhoto = false,
  }) => _mutate(
    () => _api.updateMeter(
      id,
      type: type,
      location: location,
      floorNumber: floorNumber,
      description: description ?? '',
      photoKey: photoKey,
      clearPhoto: clearPhoto,
    ),
  );

  Future<String?> retireMeter(String id) => _mutate(() => _api.retireMeter(id));

  Future<String?> _mutate(Future<void> Function() action) async {
    try {
      await action();
      await refresh();
      return null;
    } on ApiException catch (e) {
      if (e.isUnauthorized) _session.markTokenRejected();
      return e.message;
    } on NetworkException {
      return S.onlineRequired;
    }
  }
}
