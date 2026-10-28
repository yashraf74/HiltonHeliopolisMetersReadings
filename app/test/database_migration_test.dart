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

  test('upgrading from schema 9 makes numbers whole and adds the group', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          // Schema 9 (v2.3 – v2.6): the number is free text.
          raw.execute('''
            CREATE TABLE meters (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL DEFAULT '',
              type TEXT NOT NULL,
              area TEXT NOT NULL DEFAULT '',
              number TEXT NULL,
              photo_key TEXT NULL,
              last_logged_at TEXT NULL,
              last_value REAL NULL,
              todo_order INTEGER NULL,
              export_order INTEGER NULL,
              is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
              is_main INTEGER NOT NULL DEFAULT 0 CHECK (is_main IN (0, 1)),
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
          for (final (id, number) in [
            ('m1', "'12'"),
            ('m2', "' 7 '"),
            ('m3', "'SN-7'"),
            ('m4', 'NULL'),
            ('m5', "''"),
          ]) {
            raw.execute(
              'INSERT INTO meters (id, name, type, area, number, last_value, '
              'is_main, updated_at) VALUES '
              "('$id', 'Meter $id', 'water', 'Pool', $number, 41.5, 1, "
              "'2026-10-01T00:00:00Z')",
            );
          }
          raw.execute(
            "INSERT INTO readings (id, meter_id, value, logged_by, logged_at) "
            "VALUES ('r1', 'm1', 42.5, 'u1', '2026-10-02T08:00:00Z')",
          );
          raw.execute('PRAGMA user_version = 9');
        },
      ),
    );
    addTearDown(db.close);

    final meters = {
      for (final m in await db.watchActiveMeters().first) m.id: m,
    };
    expect(meters['m1']!.number, 12);
    expect(meters['m2']!.number, 7);
    // Not a whole number: left empty until the next refresh from the server.
    expect(meters['m3']!.number, isNull);
    expect(meters['m4']!.number, isNull);
    expect(meters['m5']!.number, isNull);
    expect(meters.values.map((m) => m.groupName), everyElement(isNull));
    // Everything else on the meters survives the rebuild...
    expect(meters['m1']!.lastValue, 41.5);
    expect(meters['m1']!.isMain, isTrue);
    // ...and the upload queue isn't touched.
    expect((await db.latestQueuedReading('m1'))?.value, 42.5);
  });
}
