import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/strings.dart';
import '../data/api/api_client.dart';
import '../data/models.dart';

enum SessionStatus { restoring, signedOut, signedIn }

/// Owns the signed-in user and bearer token. Persists both in secure storage
/// so a technician who opens the app in a basement with no signal is still
/// signed in and can log readings; the token is only ever validated by the
/// server when a request is actually made.
class SessionController extends ChangeNotifier {
  SessionController({required FlutterSecureStorage storage})
    : _storage = storage;

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  final FlutterSecureStorage _storage;

  SessionStatus _status = SessionStatus.restoring;
  AuthUser? _user;
  String _token = '';
  bool _needsReauth = false;

  SessionStatus get status => _status;
  AuthUser? get user => _user;
  String get token => _token;

  /// True once the server has rejected the stored token (401). The UI shows a
  /// banner asking the user to sign in again; local data is kept.
  bool get needsReauth => _needsReauth;

  Future<void> restore() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      final userJson = await _storage.read(key: _userKey);
      if (token != null && userJson != null) {
        _token = token;
        _user = AuthUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
        _status = SessionStatus.signedIn;
      } else {
        _status = SessionStatus.signedOut;
      }
    } catch (_) {
      _status = SessionStatus.signedOut;
    }
    notifyListeners();
  }

  /// Returns null on success, otherwise an Arabic error message to display.
  /// [beforeSignedIn] runs once the user is known but before listeners hear
  /// about it (used to switch to the user's language first, so the home
  /// screen never draws in the previous one).
  Future<String?> signIn(
    ApiClient api,
    String username,
    String password, {
    Future<void> Function(AuthUser user)? beforeSignedIn,
  }) async {
    try {
      final result = await api.login(username.trim(), password);
      _token = result.token;
      _user = result.user;
      _needsReauth = false;
      await _storage.write(key: _tokenKey, value: _token);
      await _storage.write(key: _userKey, value: jsonEncode(_user!.toJson()));
      await beforeSignedIn?.call(_user!);
      _status = SessionStatus.signedIn;
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.isUnauthorized ? S.loginFailed : e.message;
    } on NetworkException {
      return S.loginOffline;
    }
  }

  /// Stores the profile the user just saved (photo, email, mobile), so the
  /// account menu and export hints use it without signing in again.
  Future<void> updateProfile({
    String? email,
    String? phone,
    String? photoKey,
  }) async {
    final user = _user;
    if (user == null) return;
    _user = user.withProfile(email: email, phone: phone, photoKey: photoKey);
    await _storage.write(key: _userKey, value: jsonEncode(_user!.toJson()));
    notifyListeners();
  }

  Future<void> signOut() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    _token = '';
    _user = null;
    _needsReauth = false;
    _status = SessionStatus.signedOut;
    notifyListeners();
  }

  void markTokenRejected() {
    if (_needsReauth) return;
    _needsReauth = true;
    notifyListeners();
  }
}
