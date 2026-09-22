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
    this.language,
    this.email,
  });

  final String id;
  final String username;
  final String fullName;
  final UserRole role;

  /// From sign-in (null in sessions from older app versions).
  final String? email;

  /// Saved app language from the server (null in sessions from older app
  /// versions, which then keep the device's choice).
  final AppLanguage? language;

  bool get canManage => role.canManage;
  bool get canSeeAllReadings => role.canSeeAllReadings;
  bool get canSeeDashboard => role.canSeeDashboard;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    username: json['username'] as String,
    fullName: json['fullName'] as String,
    role: UserRole.fromApi(json['role'] as String),
    language: json['language'] == null
        ? null
        : AppLanguage.fromCode(json['language'] as String),
    email: json['email'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'fullName': fullName,
    'role': role.name,
    'language': ?language?.name,
    'email': ?email,
  };
}

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isActive,
    this.phone,
    this.photoKey,
  });

  /// Stored for users created before emails existed.
  static const placeholderEmail = 'null@hilton.com';

  /// Same rule as the server: something@something.tld, no spaces.
  static final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  /// Egyptian mobile, same rule as the server: 01xxxxxxxxx or +20xxxxxxxxxx.
  static final phonePattern = RegExp(r'^(01\d{9}|\+20\d{10})$');

  final String id;
  final String username;
  final String fullName;
  final String email;
  final UserRole role;
  final bool isActive;
  final String? phone;
  final String? photoKey;

  bool get hasEmail => email.isNotEmpty && email != placeholderEmail;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    username: json['username'] as String,
    fullName: json['fullName'] as String,
    email: json['email'] as String? ?? '',
    role: UserRole.fromApi(json['role'] as String),
    isActive: json['isActive'] as bool,
    phone: json['phone'] as String?,
    photoKey: json['photoKey'] as String?,
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
    required this.tokenLifetimeDays,
    required this.prices,
    this.latestAppVersion,
  });

  final String minAppVersion;
  final bool maintenanceMode;
  final bool readingDeleteEnabled;
  final bool exportEnabled;
  final int photoRetentionDays;

  /// How long a login stays valid; applies to logins after it is changed.
  final int tokenLifetimeDays;

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
    tokenLifetimeDays: j['tokenLifetimeDays'] as int? ?? 7,
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
    'tokenLifetimeDays': tokenLifetimeDays,
    'prices': {for (final e in prices.entries) e.key.name: e.value},
  };
}

class UserName {
  const UserName({required this.id, required this.fullName});

  final String id;
  final String fullName;
}
