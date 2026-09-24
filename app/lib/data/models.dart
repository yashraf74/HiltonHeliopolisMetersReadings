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
    this.phone,
    this.photoKey,
  });

  final String id;
  final String username;
  final String fullName;
  final UserRole role;

  /// From sign-in (null in sessions from older app versions).
  final String? email;
  final String? phone;
  final String? photoKey;

  /// The signed-in user after they edited their own profile.
  AuthUser withProfile({String? email, String? phone, String? photoKey}) =>
      AuthUser(
        id: id,
        username: username,
        fullName: fullName,
        role: role,
        language: language,
        email: email,
        phone: phone,
        photoKey: photoKey,
      );

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
    phone: json['phone'] as String?,
    photoKey: json['photoKey'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'fullName': fullName,
    'role': role.name,
    'language': ?language?.name,
    'email': ?email,
    'phone': ?phone,
    'photoKey': ?photoKey,
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
/// Columns the Excel export can include; [ExportSettings.columns] holds the
/// selected ones in export order.
enum ExportColumn {
  loggedAt('logged_at'),
  meterName('meter_name'),
  meterType('meter_type'),
  meterArea('meter_area'),
  meterNumber('meter_number'),
  value('value'),
  gain('gain'),
  unit('unit'),
  loggedBy('logged_by'),
  syncedAt('synced_at'),
  readingId('reading_id');

  const ExportColumn(this.id);

  final String id;

  static ExportColumn? fromId(String id) =>
      values.where((c) => c.id == id).firstOrNull;

  String get label => switch (this) {
    loggedAt => S.colDateTime,
    meterName => S.colMeterName,
    meterType => S.colType,
    meterArea => S.colMeterArea,
    meterNumber => S.colMeterNumber,
    value => S.colValue,
    gain => S.gainLabel,
    unit => S.colUnit,
    loggedBy => S.colLoggedBy,
    syncedAt => S.colSyncedAt,
    readingId => S.colReadingId,
  };

  /// Column width in the workbook.
  double get width => switch (this) {
    loggedAt || syncedAt => 18,
    meterName || loggedBy => 22,
    meterArea => 20,
    meterNumber || value || gain => 14,
    meterType => 12,
    unit => 10,
    readingId => 38,
  };
}

/// Sheet direction for the export: follow the exporter's language, or force.
enum ExportDirection { auto, rtl, ltr }

/// How the Excel export is built (set by a moderator, used by every device).
class ExportSettings {
  const ExportSettings({
    this.columns = ExportColumn.values,
    this.direction = ExportDirection.auto,
    this.dateFormat = defaultDateFormat,
    this.decimals = 2,
    this.thousandsSeparator = true,
    this.sheetPerType = false,
  });

  static const defaultDateFormat = 'yyyy-MM-dd HH:mm';

  /// Patterns offered for date cells.
  static const dateFormats = [
    'yyyy-MM-dd HH:mm',
    'dd/MM/yyyy HH:mm',
    'MM/dd/yyyy HH:mm',
    'yyyy-MM-dd',
    'dd/MM/yyyy',
  ];

  final List<ExportColumn> columns;
  final ExportDirection direction;
  final String dateFormat;
  final int decimals;
  final bool thousandsSeparator;

  /// One sheet per meter type, each tab named after the type.
  final bool sheetPerType;

  factory ExportSettings.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const ExportSettings();
    final ids = (j['columns'] as List<dynamic>?)?.cast<String>() ?? const [];
    final columns = [for (final id in ids) ?ExportColumn.fromId(id)];
    return ExportSettings(
      columns: columns.isEmpty ? ExportColumn.values : columns,
      direction: ExportDirection.values.firstWhere(
        (d) => d.name == j['direction'],
        orElse: () => ExportDirection.auto,
      ),
      dateFormat: dateFormats.contains(j['dateFormat'])
          ? j['dateFormat'] as String
          : defaultDateFormat,
      decimals: switch (j['decimals']) {
        final int d when d >= 0 && d <= 3 => d,
        _ => 2,
      },
      thousandsSeparator: j['thousandsSeparator'] as bool? ?? true,
      sheetPerType: j['sheetPerType'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'columns': [for (final c in columns) c.id],
    'direction': direction.name,
    'dateFormat': dateFormat,
    'decimals': decimals,
    'thousandsSeparator': thousandsSeparator,
    'sheetPerType': sheetPerType,
  };

  ExportSettings copyWith({
    List<ExportColumn>? columns,
    ExportDirection? direction,
    String? dateFormat,
    int? decimals,
    bool? thousandsSeparator,
    bool? sheetPerType,
  }) => ExportSettings(
    columns: columns ?? this.columns,
    direction: direction ?? this.direction,
    dateFormat: dateFormat ?? this.dateFormat,
    decimals: decimals ?? this.decimals,
    thousandsSeparator: thousandsSeparator ?? this.thousandsSeparator,
    sheetPerType: sheetPerType ?? this.sheetPerType,
  );
}

class AppConfig {
  const AppConfig({
    this.minAppVersion = '0.0.0',
    this.maintenanceMode = false,
    this.readingDeleteEnabled = true,
    this.exportEnabled = true,
    this.profileEditingEnabled = true,
    this.export = const ExportSettings(),
  });

  final String minAppVersion;
  final bool maintenanceMode;
  final bool readingDeleteEnabled;
  final bool exportEnabled;

  /// Users may edit their own photo, email and mobile number.
  final bool profileEditingEnabled;

  /// How this device builds the Excel workbook.
  final ExportSettings export;

  factory AppConfig.fromJson(Map<String, dynamic> j) => AppConfig(
    minAppVersion: j['minAppVersion'] as String? ?? '0.0.0',
    maintenanceMode: j['maintenanceMode'] as bool? ?? false,
    readingDeleteEnabled: j['readingDeleteEnabled'] as bool? ?? true,
    exportEnabled: j['exportEnabled'] as bool? ?? true,
    profileEditingEnabled: j['profileEditingEnabled'] as bool? ?? true,
    export: ExportSettings.fromJson(j['export'] as Map<String, dynamic>?),
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
    required this.profileEditingEnabled,
    required this.export,
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

  /// Users may edit their own photo, email and mobile number.
  final bool profileEditingEnabled;

  /// How the Excel export is built.
  final ExportSettings export;

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
    profileEditingEnabled: j['profileEditingEnabled'] as bool? ?? true,
    export: ExportSettings.fromJson(j['export'] as Map<String, dynamic>?),
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
    'profileEditingEnabled': profileEditingEnabled,
    'export': export.toJson(),
    'prices': {for (final e in prices.entries) e.key.name: e.value},
  };
}

class UserName {
  const UserName({required this.id, required this.fullName});

  final String id;
  final String fullName;
}
