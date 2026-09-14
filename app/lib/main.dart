import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/strings.dart';
import 'core/theme.dart';
import 'data/api/api_client.dart';
import 'data/db/database.dart';
import 'state/connectivity_controller.dart';
import 'state/meters_controller.dart';
import 'state/session_controller.dart';
import 'ui/home_shell.dart';
import 'ui/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');

  final db = AppDatabase();
  final session = SessionController(storage: const FlutterSecureStorage());
  final api = ApiClient(tokenProvider: () => session.token);
  final meters = MetersController(db: db, api: api, session: session);

  await session.restore();

  runApp(MetersApp(db: db, session: session, api: api, meters: meters));
}

class MetersApp extends StatelessWidget {
  const MetersApp({
    super.key,
    required this.db,
    required this.session,
    required this.api,
    required this.meters,
  });

  final AppDatabase db;
  final SessionController session;
  final ApiClient api;
  final MetersController meters;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider<SessionController>.value(value: session),
        ChangeNotifierProvider<MetersController>.value(value: meters),
        ChangeNotifierProvider<ConnectivityController>(
          create: (_) => ConnectivityController(),
        ),
      ],
      child: MaterialApp(
        title: S.appNameShort,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Consumer<SessionController>(
          builder: (context, session, _) => switch (session.status) {
            SessionStatus.restoring => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            SessionStatus.signedOut => const LoginScreen(),
            SessionStatus.signedIn => const HomeShell(),
          },
        ),
      ),
    );
  }
}
