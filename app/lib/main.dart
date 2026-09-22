import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'core/strings.dart';
import 'core/theme.dart';
import 'data/api/api_client.dart';
import 'data/db/database.dart';
import 'state/app_status_controller.dart';
import 'state/language_controller.dart';
import 'state/connectivity_controller.dart';
import 'state/meters_controller.dart';
import 'state/session_controller.dart';
import 'state/sync_controller.dart';
import 'ui/gate_screen.dart';
import 'ui/home_shell.dart';
import 'ui/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await initializeDateFormatting('ar');
  await initializeDateFormatting('en');
  final language = LanguageController(storage: const FlutterSecureStorage());
  await language.restore();
  final info = await PackageInfo.fromPlatform();

  final db = AppDatabase();
  final session = SessionController(storage: const FlutterSecureStorage());
  final connectivity = ConnectivityController();
  final status = AppStatusController(appVersion: info.version);
  final api = ApiClient(
    tokenProvider: () => session.token,
    appVersion: info.version,
    onReachability: (up) =>
        up ? connectivity.markOnline() : connectivity.markOffline(),
    onGate: status.onGate,
  );
  final meters = MetersController(db: db, api: api, session: session);
  final sync = SyncController(
    db: db,
    api: api,
    session: session,
    connectivity: connectivity,
  );

  await session.restore();
  // A restored session keeps the user's saved language (sessions from older
  // app versions have none and keep the device's choice).
  final saved = session.user?.language;
  if (saved != null) await language.apply(saved);

  runApp(
    MetersApp(
      db: db,
      session: session,
      api: api,
      meters: meters,
      connectivity: connectivity,
      sync: sync,
      status: status,
      language: language,
    ),
  );
}

class MetersApp extends StatelessWidget {
  const MetersApp({
    super.key,
    required this.db,
    required this.session,
    required this.api,
    required this.meters,
    required this.connectivity,
    required this.sync,
    required this.status,
    required this.language,
  });

  final AppDatabase db;
  final SessionController session;
  final ApiClient api;
  final MetersController meters;
  final ConnectivityController connectivity;
  final SyncController sync;
  final AppStatusController status;
  final LanguageController language;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider<SessionController>.value(value: session),
        ChangeNotifierProvider<MetersController>.value(value: meters),
        ChangeNotifierProvider<ConnectivityController>.value(
          value: connectivity,
        ),
        ChangeNotifierProvider<SyncController>.value(value: sync),
        ChangeNotifierProvider<AppStatusController>.value(value: status),
        ChangeNotifierProvider<LanguageController>.value(value: language),
      ],
      child: LanguageRebuilder(controller: language, builder: (_) => _app()),
    );
  }

  Widget _app() => MaterialApp(
    title: S.appNameShort,
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    // Arabic lays out right-to-left, English left-to-right.
    locale: Locale(S.localeCode),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    // Tapping anywhere that isn't a control (a text field, button, ...)
    // closes the keyboard.
    builder: (context, child) => GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: child,
    ),
    home: Consumer2<SessionController, AppStatusController>(
      builder: (context, session, status, _) {
        // Hard gates come first: an outdated build or maintenance mode
        // replaces the whole app regardless of sign-in state.
        if (status.upgradeRequired) return const GateScreen(upgrade: true);
        if (status.maintenance) return const GateScreen(upgrade: false);
        return switch (session.status) {
          SessionStatus.restoring => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          SessionStatus.signedOut => const LoginScreen(),
          SessionStatus.signedIn => const HomeShell(),
        };
      },
    ),
  );
}
