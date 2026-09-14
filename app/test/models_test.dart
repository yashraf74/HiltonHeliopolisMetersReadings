import 'package:flutter_test/flutter_test.dart';
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
    expect(restored.isEngineer, isFalse);
  });

  test('enums parse API values and fall back safely', () {
    expect(MeterType.fromApi('water'), MeterType.water);
    expect(MeterType.fromApi('unknown'), MeterType.electricity);
    expect(UserRole.fromApi('engineer'), UserRole.engineer);
    expect(SyncStatus.fromDb('synced'), SyncStatus.synced);
    expect(SyncStatus.fromDb('garbage'), SyncStatus.pending);
  });
}
