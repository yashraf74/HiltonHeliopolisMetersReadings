import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meters_app/data/db/database.dart';

/// Opens a database laid out exactly like schema v7 (v2.0.1 – v2.2.x) and
/// checks the upgrade keeps queued readings and cached meters.
void main() {
  test('upgrading from schema 7 adds lastValue and keeps data', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('''
            CREATE TABLE meters (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL DEFAULT '',
              type TEXT NOT NULL,
              area TEXT NOT NULL DEFAULT '',
              number TEXT NULL,
              photo_key TEXT NULL,
              last_logged_at TEXT NULL,
              todo_order INTEGER NULL,
              export_order INTEGER NULL,
              is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
              updated_at TEXT NOT NULL
            )''');
          raw.execute('''
            CREATE TABLE readings (
              id TEXT NOT NULL PRIMARY KEY,
              meter_id TEXT NOT NULL,
              value REAL NOT NULL,
              photo_key TEXT NULL,
              local_photo_path TEXT NULL,
              logged_by TEXT NOT NULL,
              logged_at TEXT NOT NULL,
              synced_at TEXT NULL,
              sync_status TEXT NOT NULL DEFAULT 'pending',
              retry_count INTEGER NOT NULL DEFAULT 0,
              last_error TEXT NULL
            )''');
          raw.execute(
            "INSERT INTO meters (id, name, type, area, updated_at) "
            "VALUES ('m1', 'Pool', 'water', 'Pool', '2026-09-20T00:00:00Z')",
          );
          raw.execute(
            "INSERT INTO readings (id, meter_id, value, logged_by, logged_at) "
            "VALUES ('r1', 'm1', 42.5, 'u1', '2026-09-21T08:00:00Z')",
          );
          raw.execute('PRAGMA user_version = 7');
        },
      ),
    );
    addTearDown(db.close);

    final meter = (await db.watchActiveMeters().first).single;
    expect(meter.name, 'Pool');
    expect(meter.lastValue, isNull);
    final queued = await db.latestQueuedReading('m1');
    expect(queued?.value, 42.5);

    await db.touchMeterLastLogged('m1', '2026-09-21T08:00:00Z', 42.5);
    expect((await db.meterById('m1'))!.lastValue, 42.5);
  });
}
