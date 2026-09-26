import 'package:flutter/material.dart';

/// Cross-screen signals, so a change on one tab reaches the others without
/// closing the app. The tabs live in an IndexedStack and keep their state,
/// so they can't rely on being rebuilt from scratch.
class AppEvents extends ChangeNotifier {
  int _usersRevision = 0;

  /// Bumped when user accounts change; the readings filter reloads its list
  /// of users (a moderator may have hidden one from the filter).
  int get usersRevision => _usersRevision;

  void usersChanged() {
    _usersRevision++;
    notifyListeners();
  }

  DateTimeRange? _dashboardRange;

  /// Asks the shell to open the dashboard, showing [range] (used by the
  /// export warning, so the unusual readings it counted are on screen).
  void openDashboard(DateTimeRange range) {
    _dashboardRange = range;
    notifyListeners();
  }

  bool get wantsDashboard => _dashboardRange != null;

  /// The dashboard takes the requested range once and applies it.
  DateTimeRange? takeDashboardRange() {
    final range = _dashboardRange;
    _dashboardRange = null;
    return range;
  }
}
