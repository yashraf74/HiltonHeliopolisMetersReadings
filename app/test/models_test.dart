import 'package:flutter_test/flutter_test.dart';
import 'package:meters_app/core/strings.dart';
import 'package:meters_app/data/models.dart';

void main() {
  test('AuthUser round-trips through JSON', () {
    const user = AuthUser(
      id: 'u1',
      username: 'tech',
      fullName: 'فني',
      role: UserRole.technician,
    );
    final restored = AuthUser.fromJson(user.toJson());
    expect(restored.id, 'u1');
    expect(restored.role, UserRole.technician);
    expect(restored.canManage, isFalse);
  });

  test('enums parse API values and fall back safely', () {
    expect(MeterType.fromApi('water'), MeterType.water);
    expect(MeterType.fromApi('unknown'), MeterType.electricity);
    expect(UserRole.fromApi('engineer'), UserRole.engineer);
    expect(UserRole.fromApi('moderator').canManage, isTrue);
    expect(UserRole.engineer.canManage, isFalse);
    expect(UserRole.engineer.canSeeAllReadings, isTrue);
    expect(UserRole.technician.canSeeAllReadings, isFalse);
    expect(SyncStatus.fromDb('synced'), SyncStatus.synced);
    expect(SyncStatus.fromDb('garbage'), SyncStatus.pending);
  });

  test('count units use singular, dual and plural forms', () {
    S.language = AppLanguage.en;
    expect(S.readingsUnit(1), 'reading');
    expect(S.readingsUnit(3), 'readings');
    expect(S.daysUnit(1), 'day');
    S.language = AppLanguage.ar;
    expect(S.readingsUnit(1), 'قراءة');
    expect(S.readingsUnit(2), 'قراءتان');
    expect(S.readingsUnit(5), 'قراءات');
    expect(S.readingsUnit(12), 'قراءة');
    expect(S.daysUnit(2), 'يومان');
    expect(S.daysUnit(4), 'أيام');
  });

  test('meter numbers parse from text or a number, and nothing else', () {
    expect(parseMeterNumber('12'), 12);
    expect(parseMeterNumber(' 7 '), 7);
    expect(parseMeterNumber(112), 112);
    expect(parseMeterNumber(null), isNull);
    expect(parseMeterNumber(''), isNull);
    expect(parseMeterNumber('SN-7'), isNull);
  });

  test('export settings keep the transposed options through JSON', () {
    const s = ExportSettings(transpose: true, groupHeaders: true, totals: true);
    final back = ExportSettings.fromJson(s.toJson());
    expect(
      (back.transpose, back.groupHeaders, back.totals),
      (true, true, true),
    );
    // A server that doesn't know them yet: all off.
    final old = ExportSettings.fromJson({
      'columns': ['value'],
    });
    expect(
      (old.transpose, old.groupHeaders, old.totals),
      (false, false, false),
    );
  });
}
