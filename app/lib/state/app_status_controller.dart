import 'package:flutter/foundation.dart';

import '../data/api/api_client.dart';
import '../data/models.dart';

/// Server-driven switches and hard gates. Refreshed from GET /api/config on
/// start, on foreground and after sign-in; set immediately when any request
/// comes back 426 (upgrade required) or 503 (maintenance).
class AppStatusController extends ChangeNotifier {
  AppStatusController({required this.appVersion});

  final String appVersion;

  AppConfig _config = const AppConfig();
  bool _upgradeRequired = false;
  bool _maintenance = false;

  AppConfig get config => _config;
  bool get upgradeRequired => _upgradeRequired;
  bool get maintenance => _maintenance;

  void onGate(ApiException e) {
    if (e.isUpgradeRequired && !_upgradeRequired) {
      _upgradeRequired = true;
      notifyListeners();
    } else if (e.isMaintenance && !_maintenance) {
      _maintenance = true;
      notifyListeners();
    }
  }

  /// Returns true when the config was refreshed (any failure is swallowed;
  /// the gates are also raised through [onGate] when the server says so).
  Future<bool> refresh(ApiClient api, {bool isModerator = false}) async {
    try {
      final next = await api.fetchConfig();
      _config = next;
      _upgradeRequired = false;
      // A moderator keeps working during maintenance.
      _maintenance = next.maintenanceMode && !isModerator;
      notifyListeners();
      return true;
    } on ApiException {
      return false;
    } on NetworkException {
      return false;
    }
  }
}
