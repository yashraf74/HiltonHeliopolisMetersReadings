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

  int _unusualRevision = 0;

  /// Bumped when a reading is marked normal, edited or deleted, so the card
  /// on the readings screen recounts.
  int get unusualRevision => _unusualRevision;

  void unusualChanged() {
    _unusualRevision++;
    notifyListeners();
  }
}
