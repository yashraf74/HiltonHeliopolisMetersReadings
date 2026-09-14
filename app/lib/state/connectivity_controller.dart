import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Tracks whether the device appears to be online.
///
/// Two sources feed it: the OS network-change stream (fast, but on some
/// platforms — notably the iOS simulator — it can lag or skip events), and
/// the API client, which reports ground truth: a completed request means
/// online, a failed connection means offline. The API always wins.
class ConnectivityController extends ChangeNotifier {
  ConnectivityController() {
    _sub = Connectivity().onConnectivityChanged.listen(_apply);
    Connectivity().checkConnectivity().then(_apply);
  }

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  void _apply(List<ConnectivityResult> results) =>
      _set(results.any((r) => r != ConnectivityResult.none));

  /// Called by the API client after a request completed (any status code).
  void markOnline() => _set(true);

  /// Called by the API client when the server could not be reached.
  void markOffline() => _set(false);

  /// Re-queries the OS; used when the app returns to the foreground.
  Future<void> recheck() async =>
      _apply(await Connectivity().checkConnectivity());

  void _set(bool online) {
    if (online == _isOnline) return;
    _isOnline = online;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
