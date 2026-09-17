import '../core/strings.dart';
import '../core/theme.dart';

import 'package:flutter/material.dart';

enum UserRole {
  moderator,
  engineer,
  technician;

  static UserRole fromApi(String value) =>
      values.firstWhere((r) => r.name == value, orElse: () => technician);

  String get label => switch (this) {
    moderator => S.roleModerator,
    engineer => S.roleEngineer,
    technician => S.roleTechnician,
  };

  /// Meters and user accounts.
  bool get canManage => this == moderator;

  /// Sees every reading and may edit/delete any of them; can export.
  bool get canSeeAllReadings => this != technician;

  bool get canSeeDashboard => this != technician;
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

  /// Unit shown beside every value of this meter type.
  String get unit => this == electricity ? S.unitKwh : S.unitCubicMeters;
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

  bool get canManage => role.canManage;
  bool get canSeeAllReadings => role.canSeeAllReadings;
  bool get canSeeDashboard => role.canSeeDashboard;

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

/// Runtime switches from the server (GET /api/config), safe to show to any
/// role. Moderators edit the full set on the settings screen.
class AppConfig {
  const AppConfig({
    this.minAppVersion = '0.0.0',
    this.maintenanceMode = false,
    this.readingDeleteEnabled = true,
    this.exportEnabled = true,
  });

  final String minAppVersion;
  final bool maintenanceMode;
  final bool readingDeleteEnabled;
  final bool exportEnabled;

  factory AppConfig.fromJson(Map<String, dynamic> j) => AppConfig(
    minAppVersion: j['minAppVersion'] as String? ?? '0.0.0',
    maintenanceMode: j['maintenanceMode'] as bool? ?? false,
    readingDeleteEnabled: j['readingDeleteEnabled'] as bool? ?? true,
    exportEnabled: j['exportEnabled'] as bool? ?? true,
  );
}

class AppSettings {
  const AppSettings({
    required this.minAppVersion,
    required this.maintenanceMode,
    required this.readingDeleteEnabled,
    required this.exportEnabled,
    required this.photoRetentionDays,
    required this.prices,
    this.latestAppVersion,
  });

  final String minAppVersion;
  final bool maintenanceMode;
  final bool readingDeleteEnabled;
  final bool exportEnabled;
  final int photoRetentionDays;

  /// EGP per unit for the dashboard cost chart; 0 = not set.
  final Map<MeterType, double> prices;

  /// Newest published release, from the server (read-only; null if unknown).
  final String? latestAppVersion;

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    minAppVersion: j['minAppVersion'] as String,
    maintenanceMode: j['maintenanceMode'] as bool,
    readingDeleteEnabled: j['readingDeleteEnabled'] as bool,
    exportEnabled: j['exportEnabled'] as bool,
    photoRetentionDays: j['photoRetentionDays'] as int,
    prices: pricesFromJson(j['prices'] as Map<String, dynamic>?),
    latestAppVersion: j['latestAppVersion'] as String?,
  );

  static Map<MeterType, double> pricesFromJson(Map<String, dynamic>? j) => {
    for (final t in MeterType.values) t: (j?[t.name] as num?)?.toDouble() ?? 0,
  };

  Map<String, dynamic> toJson() => {
    'minAppVersion': minAppVersion,
    'maintenanceMode': maintenanceMode,
    'readingDeleteEnabled': readingDeleteEnabled,
    'exportEnabled': exportEnabled,
    'photoRetentionDays': photoRetentionDays,
    'prices': {for (final e in prices.entries) e.key.name: e.value},
  };
}

class UserName {
  const UserName({required this.id, required this.fullName});

  final String id;
  final String fullName;
}
