import '../core/strings.dart';
import '../core/theme.dart';

import 'package:flutter/material.dart';

enum UserRole {
  engineer,
  technician;

  static UserRole fromApi(String value) =>
      values.firstWhere((r) => r.name == value, orElse: () => technician);

  String get label => switch (this) {
    engineer => S.roleEngineer,
    technician => S.roleTechnician,
  };
}

enum MeterType {
  electricity,
  water,
  gas;

  static MeterType fromApi(String value) =>
      values.firstWhere((t) => t.name == value, orElse: () => electricity);

  String get label => switch (this) {
    electricity => S.electricity,
    water => S.water,
    gas => S.gas,
  };

  IconData get icon => switch (this) {
    electricity => Icons.bolt_rounded,
    water => Icons.water_drop_rounded,
    gas => Icons.local_fire_department_rounded,
  };

  Color get color => switch (this) {
    electricity => AppColors.electricity,
    water => AppColors.water,
    gas => AppColors.gas,
  };
}

enum SyncStatus {
  pending,
  syncing,
  synced,
  failed;

  static SyncStatus fromDb(String value) =>
      values.firstWhere((s) => s.name == value, orElse: () => pending);

  String get label => switch (this) {
    pending => S.syncPending,
    syncing => S.syncSyncing,
    synced => S.syncSynced,
    failed => S.syncFailed,
  };

  Color get color => switch (this) {
    pending => AppColors.pending,
    syncing => AppColors.pending,
    synced => AppColors.synced,
    failed => AppColors.failed,
  };
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
  });

  final String id;
  final String username;
  final String fullName;
  final UserRole role;

  bool get isEngineer => role == UserRole.engineer;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    username: json['username'] as String,
    fullName: json['fullName'] as String,
    role: UserRole.fromApi(json['role'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'fullName': fullName,
    'role': role.name,
  };
}

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.isActive,
  });

  final String id;
  final String username;
  final String fullName;
  final UserRole role;
  final bool isActive;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    username: json['username'] as String,
    fullName: json['fullName'] as String,
    role: UserRole.fromApi(json['role'] as String),
    isActive: json['isActive'] as bool,
  );
}
