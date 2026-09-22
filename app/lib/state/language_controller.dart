import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/strings.dart';
import '../data/api/api_client.dart';
import '../data/models.dart';

/// The app language. Starts from this device's last choice (used on the
/// login screen); after sign-in it follows the user's saved preference, and
/// a toggle saves it to the user's account so it follows them to any phone.
class LanguageController extends ChangeNotifier {
  LanguageController({required FlutterSecureStorage storage})
    : _storage = storage;

  static const _key = 'app_language';

  /// Set when a toggle couldn't be saved to the account (offline).
  static const _pendingKey = 'app_language_unsaved';

  final FlutterSecureStorage _storage;

  AppLanguage get language => S.language;

  Future<void> restore() async {
    try {
      S.language = AppLanguage.fromCode(await _storage.read(key: _key));
    } catch (_) {
      S.language = AppLanguage.ar;
    }
  }

  /// Switches the app to [language] and remembers it on this device.
  Future<void> apply(AppLanguage language) async {
    if (language == S.language) return;
    S.language = language;
    notifyListeners();
    try {
      await _storage.write(key: _key, value: language.name);
    } catch (_) {
      // Only the login screen's default is lost; nothing to recover.
    }
  }

  /// After sign-in: switch to the account's saved language. A toggle made
  /// offline by an earlier session is dropped; the account's choice wins.
  Future<void> signedIn(AuthUser user) async {
    await _setPending(false);
    final saved = user.language;
    if (saved != null) await apply(saved);
  }

  /// The user's toggle: applies it and, when signed in, saves it as their
  /// preference. If that fails (offline) it's retried at the next start.
  Future<void> choose(AppLanguage language, {ApiClient? api}) async {
    await apply(language);
    if (api == null) return;
    await _save(api);
  }

  /// Saves a toggle that couldn't be saved earlier, if there is one.
  Future<void> retryPendingSave(ApiClient api) async {
    try {
      if (await _storage.read(key: _pendingKey) == 'true') await _save(api);
    } catch (_) {
      // Storage unavailable: nothing to retry.
    }
  }

  Future<void> _save(ApiClient api) async {
    try {
      await api.saveLanguage(S.language);
      await _setPending(false);
    } on NetworkException {
      await _setPending(true);
    } on ApiException {
      // Rejected (e.g. signed out): the device keeps its choice.
      await _setPending(false);
    }
  }

  Future<void> _setPending(bool pending) async {
    try {
      if (pending) {
        await _storage.write(key: _pendingKey, value: 'true');
      } else {
        await _storage.delete(key: _pendingKey);
      }
    } catch (_) {
      // Best effort.
    }
  }
}

/// Rebuilds the whole widget tree in place when the language changes: text
/// comes from [S] getters rather than inherited widgets, so without this only
/// widgets that depend on the locale would pick up the new strings. State
/// (the open tab, typed text) is kept.
class LanguageRebuilder extends StatefulWidget {
  const LanguageRebuilder({
    super.key,
    required this.controller,
    required this.builder,
  });

  final LanguageController controller;

  /// Called on every language change, so it can read the new locale.
  final WidgetBuilder builder;

  @override
  State<LanguageRebuilder> createState() => _LanguageRebuilderState();
}

class _LanguageRebuilderState extends State<LanguageRebuilder> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    void markAll(Element e) {
      e.markNeedsBuild();
      e.visitChildren(markAll);
    }

    setState(() {});
    (context as Element).visitChildren(markAll);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
