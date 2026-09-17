import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meters_app/data/db/database.dart';

void main() {
  test('refreshing meters clears fields the server cleared', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    const base = Meter(
      id: 'm1',
      name: 'Pool',
      type: 'water',
      area: 'Pool',
      number: '7',
      photoKey: 'meters/p.jpg',
      todoOrder: 3,
      exportOrder: 4,
      isActive: true,
      updatedAt: '2026-09-17T00:00:00Z',
    );
    await db.replaceMeters([base]);
    await db.replaceMeters([
      const Meter(
        id: 'm1',
        name: 'Pool',
        type: 'water',
        area: 'Pool',
        isActive: true,
        updatedAt: '2026-09-17T01:00:00Z',
      ),
    ]);
    final m = (await db.watchActiveMeters().first).single;
    expect(m.photoKey, isNull);
    expect(m.number, isNull);
    expect(m.todoOrder, isNull);
    expect(m.exportOrder, isNull);
  });
}
