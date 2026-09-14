import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Local cache of the server's meters so the technician can pick a meter
/// with no connectivity. Refreshed from the API whenever it is reachable.
/// `photoKey` is only ever populated for engineers (the API withholds it
/// from technicians).
class Meters extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get location => text()();
  IntColumn get floorNumber => integer()();
  TextColumn get description => text().nullable()();
  TextColumn get photoKey => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Every reading is written here first, at the moment of logging, and only
/// later pushed to the server by the sync engine. The `syncStatus`,
/// `retryCount`, `lastError` and `localPhotoPath` columns are device-only
/// bookkeeping and never leave the phone.
class Readings extends Table {
  TextColumn get id => text()();
  TextColumn get meterId => text()();
  RealColumn get value => real()();
  TextColumn get notes => text().nullable()();
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
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(meters, meters.photoKey);
        await m.addColumn(readings, readings.notes);
      }
      if (from < 3) {
        // Drops logged_by_name: the name now comes from the session /
        // server so a renamed account is reflected everywhere.
        await m.alterTable(TableMigration(readings));
      }
    },
  );

  // ---- meters -------------------------------------------------------------

  /// Upserts everything the server returned and marks any locally-known
  /// meter that the server no longer lists as inactive. Rows are never
  /// deleted, because local readings may still reference them.
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
      ..orderBy([
        (m) => OrderingTerm.asc(m.floorNumber),
        (m) => OrderingTerm.asc(m.location),
      ]);
    if (type != null) q.where((m) => m.type.equals(type));
    return q.watch();
  }

  Future<Meter?> meterById(String id) =>
      (select(meters)..where((m) => m.id.equals(id))).getSingleOrNull();

  // ---- readings -----------------------------------------------------------

  Future<void> insertReading(ReadingsCompanion reading) =>
      into(readings).insert(reading);

  Future<void> deleteReading(String id) =>
      (delete(readings)..where((r) => r.id.equals(id))).go();

  Stream<List<Reading>> watchReadingsBy(String userId) =>
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
