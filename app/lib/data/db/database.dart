import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Local cache of the server's meters so the technician can pick a meter
/// with no connectivity. Refreshed from the API whenever it is reachable.
/// `lastLoggedAt` is the newest reading on the server for that meter (by
/// anyone), used with the local queue to mark meters done for today.
class Meters extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get type => text()();
  TextColumn get area => text().withDefault(const Constant(''))();
  TextColumn get number => text().nullable()();
  TextColumn get photoKey => text().nullable()();
  TextColumn get lastLoggedAt => text().nullable()();
  IntColumn get todoOrder => integer().nullable()();
  IntColumn get exportOrder => integer().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The upload queue. A reading is written here the moment it is logged and
/// removed once the server has it (from then on the readings tab reads it
/// from the server). `localPhotoPath` is relative to the app documents
/// directory (see photo_store.dart).
class Readings extends Table {
  TextColumn get id => text()();
  TextColumn get meterId => text()();
  RealColumn get value => real()();
  TextColumn get photoKey => text().nullable()();
  TextColumn get localPhotoPath => text().nullable()();
  TextColumn get loggedBy => text()();
  TextColumn get loggedAt => text()();
  TextColumn get syncedAt => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Meters, Readings])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'meters_app'));

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(meters, meters.photoKey);
      }
      if (from < 3) {
        await m.alterTable(TableMigration(readings));
      }
      if (from < 4) {
        await m.addColumn(meters, meters.name);
        await customStatement(
          "UPDATE meters SET name = location WHERE name = ''",
        );
      }
      if (from < 5) {
        await m.addColumn(meters, meters.area);
        await m.addColumn(meters, meters.number);
        await m.addColumn(meters, meters.lastLoggedAt);
        // Drops `notes`; already-synced rows are no longer kept locally.
        await m.alterTable(TableMigration(readings));
        await customStatement(
          "DELETE FROM readings WHERE sync_status = 'synced'",
        );
      }
      if (from < 6) {
        // Drops floor_number, adds the order numbers.
        await m.addColumn(meters, meters.todoOrder);
        await m.addColumn(meters, meters.exportOrder);
        await m.alterTable(TableMigration(meters));
      }
      if (from < 7) {
        // Drops location and description (the cache refills from the server).
        await m.alterTable(TableMigration(meters));
      }
    },
  );

  // ---- meters -------------------------------------------------------------

  /// Upserts everything the server returned and marks any locally-known
  /// meter that the server no longer lists as inactive. Rows are never
  /// deleted, because queued readings may still reference them.
  Future<void> replaceMeters(List<Meter> fromServer) async {
    await transaction(() async {
      await batch((b) => b.insertAllOnConflictUpdate(meters, fromServer));
      final ids = fromServer.map((m) => m.id).toList();
      if (ids.isEmpty) {
        await update(meters)
            .write(const MetersCompanion(isActive: Value(false)));
      } else {
        await (update(meters)..where((m) => m.id.isNotIn(ids))).write(
          const MetersCompanion(isActive: Value(false)),
        );
      }
    });
  }

  Stream<List<Meter>> watchActiveMeters({String? type}) {
    final q = select(meters)
      ..where((m) => m.isActive.equals(true))
      ..orderBy([(m) => OrderingTerm.asc(m.name)]);
    if (type != null) q.where((m) => m.type.equals(type));
    return q.watch();
  }

  Future<Meter?> meterById(String id) =>
      (select(meters)..where((m) => m.id.equals(id))).getSingleOrNull();

  /// Bumps the meter's last reading time after a successful upload so the
  /// "done today" tick stays correct even before the next server refresh.
  Future<void> touchMeterLastLogged(String meterId, String loggedAt) async {
    final m = await meterById(meterId);
    if (m == null) return;
    final current = m.lastLoggedAt;
    if (current != null && current.compareTo(loggedAt) >= 0) return;
    await (update(meters)..where((r) => r.id.equals(meterId))).write(
      MetersCompanion(lastLoggedAt: Value(loggedAt)),
    );
  }

  // ---- readings queue -----------------------------------------------------

  Future<void> insertReading(ReadingsCompanion reading) =>
      into(readings).insert(reading);

  Future<void> deleteReading(String id) =>
      (delete(readings)..where((r) => r.id.equals(id))).go();

  /// Everything still on the device, newest first.
  Stream<List<Reading>> watchQueue(String userId) =>
      (select(readings)
            ..where((r) => r.loggedBy.equals(userId))
            ..orderBy([(r) => OrderingTerm.desc(r.loggedAt)]))
          .watch();

  Future<List<Reading>> unsyncedReadings() =>
      (select(readings)
            ..where((r) => r.syncStatus.isNotValue('synced'))
            ..orderBy([(r) => OrderingTerm.asc(r.loggedAt)]))
          .get();

  Stream<int> watchPendingCount() {
    final count = readings.id.count();
    final q = selectOnly(readings)
      ..addColumns([count])
      ..where(readings.syncStatus.isNotValue('synced'));
    return q.watchSingle().map((row) => row.read(count) ?? 0);
  }

  Future<void> updateReadingSync(
    String id, {
    required String status,
    String? photoKey,
    String? syncedAt,
    String? lastError,
    int? retryCount,
  }) => (update(readings)..where((r) => r.id.equals(id))).write(
    ReadingsCompanion(
      syncStatus: Value(status),
      photoKey: photoKey != null ? Value(photoKey) : const Value.absent(),
      syncedAt: syncedAt != null ? Value(syncedAt) : const Value.absent(),
      lastError: Value(lastError),
      retryCount: retryCount != null ? Value(retryCount) : const Value.absent(),
    ),
  );
}
