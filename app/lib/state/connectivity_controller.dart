import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Tracks whether the device has any network interface up. This is a hint
/// for the UI (offline banner) and a trigger for sync — not a guarantee that
/// the server is reachable, which only an actual request can tell.
class ConnectivityController extends ChangeNotifier {
  ConnectivityController() {
    _sub = Connectivity().onConnectivityChanged.listen(_apply);
    Connectivity().checkConnectivity().then(_apply);
  }

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  void _apply(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
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
