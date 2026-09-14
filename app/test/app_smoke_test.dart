import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meters_app/data/api/api_client.dart';
import 'package:meters_app/data/db/database.dart';
import 'package:meters_app/main.dart';
import 'package:meters_app/state/connectivity_controller.dart';
import 'package:meters_app/state/meters_controller.dart';
import 'package:meters_app/state/session_controller.dart';
import 'package:meters_app/state/sync_controller.dart';
import 'package:meters_app/ui/home_shell.dart';
import 'package:meters_app/ui/login_screen.dart';

/// Guards against a provider being left out of the app root: every screen
/// must be able to resolve every controller it reads.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  testWidgets('signed-out app renders the login screen', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final session = SessionController(storage: const FlutterSecureStorage());
    final api = ApiClient(tokenProvider: () => session.token);
    final connectivity = ConnectivityController();
    final sync = SyncController(
      db: db,
      api: api,
      session: session,
      connectivity: connectivity,
    );
    await session.restore();

    await tester.pumpWidget(
      MetersApp(
        db: db,
        session: session,
        api: api,
        meters: MetersController(db: db, api: api, session: session),
        connectivity: connectivity,
        sync: sync,
      ),
    );
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);
    expect(tester.takeException(), isNull);
    sync.dispose();
    connectivity.dispose();
    await db.close();
  });

  testWidgets('signed-in engineer shell resolves every provider', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({
      'auth_token': 't',
      'auth_user':
          '{"id":"u1","username":"eng","fullName":"مهندس","role":"engineer"}',
    });
    final db = AppDatabase(NativeDatabase.memory());
    final session = SessionController(storage: const FlutterSecureStorage());
    final api = ApiClient(
      tokenProvider: () => session.token,
      baseUrl: 'http://127.0.0.1:9',
    );
    final connectivity = ConnectivityController();
    final sync = SyncController(
      db: db,
      api: api,
      session: session,
      connectivity: connectivity,
    );
    await session.restore();

    await tester.pumpWidget(
      MetersApp(
        db: db,
        session: session,
        api: api,
        meters: MetersController(db: db, api: api, session: session),
        connectivity: connectivity,
        sync: sync,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    sync.dispose();
    connectivity.dispose();
    await db.close();
  });
}
