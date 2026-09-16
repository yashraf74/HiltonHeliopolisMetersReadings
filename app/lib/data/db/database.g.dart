// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $MetersTable extends Meters with TableInfo<$MetersTable, Meter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _areaMeta = const VerificationMeta('area');
  @override
  late final GeneratedColumn<String> area = GeneratedColumn<String>(
    'area',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<String> number = GeneratedColumn<String>(
    'number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _photoKeyMeta = const VerificationMeta(
    'photoKey',
  );
  @override
  late final GeneratedColumn<String> photoKey = GeneratedColumn<String>(
    'photo_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastLoggedAtMeta = const VerificationMeta(
    'lastLoggedAt',
  );
  @override
  late final GeneratedColumn<String> lastLoggedAt = GeneratedColumn<String>(
    'last_logged_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _todoOrderMeta = const VerificationMeta(
    'todoOrder',
  );
  @override
  late final GeneratedColumn<int> todoOrder = GeneratedColumn<int>(
    'todo_order',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exportOrderMeta = const VerificationMeta(
    'exportOrder',
  );
  @override
  late final GeneratedColumn<int> exportOrder = GeneratedColumn<int>(
    'export_order',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    location,
    area,
    number,
    description,
    photoKey,
    lastLoggedAt,
    todoOrder,
    exportOrder,
    isActive,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meters';
  @override
  VerificationContext validateIntegrity(
    Insertable<Meter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    } else if (isInserting) {
      context.missing(_locationMeta);
    }
    if (data.containsKey('area')) {
      context.handle(
        _areaMeta,
        area.isAcceptableOrUnknown(data['area']!, _areaMeta),
      );
    }
    if (data.containsKey('number')) {
      context.handle(
        _numberMeta,
        number.isAcceptableOrUnknown(data['number']!, _numberMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('photo_key')) {
      context.handle(
        _photoKeyMeta,
        photoKey.isAcceptableOrUnknown(data['photo_key']!, _photoKeyMeta),
      );
    }
    if (data.containsKey('last_logged_at')) {
      context.handle(
        _lastLoggedAtMeta,
        lastLoggedAt.isAcceptableOrUnknown(
          data['last_logged_at']!,
          _lastLoggedAtMeta,
        ),
      );
    }
    if (data.containsKey('todo_order')) {
      context.handle(
        _todoOrderMeta,
        todoOrder.isAcceptableOrUnknown(data['todo_order']!, _todoOrderMeta),
      );
    }
    if (data.containsKey('export_order')) {
      context.handle(
        _exportOrderMeta,
        exportOrder.isAcceptableOrUnknown(
          data['export_order']!,
          _exportOrderMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Meter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Meter(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      )!,
      area: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}area'],
      )!,
      number: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}number'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      photoKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_key'],
      ),
      lastLoggedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_logged_at'],
      ),
      todoOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}todo_order'],
      ),
      exportOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}export_order'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MetersTable createAlias(String alias) {
    return $MetersTable(attachedDatabase, alias);
  }
}

class Meter extends DataClass implements Insertable<Meter> {
  final String id;
  final String name;
  final String type;
  final String location;
  final String area;
  final String? number;
  final String? description;
  final String? photoKey;
  final String? lastLoggedAt;
  final int? todoOrder;
  final int? exportOrder;
  final bool isActive;
  final String updatedAt;
  const Meter({
    required this.id,
    required this.name,
    required this.type,
    required this.location,
    required this.area,
    this.number,
    this.description,
    this.photoKey,
    this.lastLoggedAt,
    this.todoOrder,
    this.exportOrder,
    required this.isActive,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['location'] = Variable<String>(location);
    map['area'] = Variable<String>(area);
    if (!nullToAbsent || number != null) {
      map['number'] = Variable<String>(number);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || photoKey != null) {
      map['photo_key'] = Variable<String>(photoKey);
    }
    if (!nullToAbsent || lastLoggedAt != null) {
      map['last_logged_at'] = Variable<String>(lastLoggedAt);
    }
    if (!nullToAbsent || todoOrder != null) {
      map['todo_order'] = Variable<int>(todoOrder);
    }
    if (!nullToAbsent || exportOrder != null) {
      map['export_order'] = Variable<int>(exportOrder);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  MetersCompanion toCompanion(bool nullToAbsent) {
    return MetersCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      location: Value(location),
      area: Value(area),
      number: number == null && nullToAbsent
          ? const Value.absent()
          : Value(number),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      photoKey: photoKey == null && nullToAbsent
          ? const Value.absent()
          : Value(photoKey),
      lastLoggedAt: lastLoggedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastLoggedAt),
      todoOrder: todoOrder == null && nullToAbsent
          ? const Value.absent()
          : Value(todoOrder),
      exportOrder: exportOrder == null && nullToAbsent
          ? const Value.absent()
          : Value(exportOrder),
      isActive: Value(isActive),
      updatedAt: Value(updatedAt),
    );
  }

  factory Meter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Meter(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      location: serializer.fromJson<String>(json['location']),
      area: serializer.fromJson<String>(json['area']),
      number: serializer.fromJson<String?>(json['number']),
      description: serializer.fromJson<String?>(json['description']),
      photoKey: serializer.fromJson<String?>(json['photoKey']),
      lastLoggedAt: serializer.fromJson<String?>(json['lastLoggedAt']),
      todoOrder: serializer.fromJson<int?>(json['todoOrder']),
      exportOrder: serializer.fromJson<int?>(json['exportOrder']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'location': serializer.toJson<String>(location),
      'area': serializer.toJson<String>(area),
      'number': serializer.toJson<String?>(number),
      'description': serializer.toJson<String?>(description),
      'photoKey': serializer.toJson<String?>(photoKey),
      'lastLoggedAt': serializer.toJson<String?>(lastLoggedAt),
      'todoOrder': serializer.toJson<int?>(todoOrder),
      'exportOrder': serializer.toJson<int?>(exportOrder),
      'isActive': serializer.toJson<bool>(isActive),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  Meter copyWith({
    String? id,
    String? name,
    String? type,
    String? location,
    String? area,
    Value<String?> number = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> photoKey = const Value.absent(),
    Value<String?> lastLoggedAt = const Value.absent(),
    Value<int?> todoOrder = const Value.absent(),
    Value<int?> exportOrder = const Value.absent(),
    bool? isActive,
    String? updatedAt,
  }) => Meter(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    location: location ?? this.location,
    area: area ?? this.area,
    number: number.present ? number.value : this.number,
    description: description.present ? description.value : this.description,
    photoKey: photoKey.present ? photoKey.value : this.photoKey,
    lastLoggedAt: lastLoggedAt.present ? lastLoggedAt.value : this.lastLoggedAt,
    todoOrder: todoOrder.present ? todoOrder.value : this.todoOrder,
    exportOrder: exportOrder.present ? exportOrder.value : this.exportOrder,
    isActive: isActive ?? this.isActive,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Meter copyWithCompanion(MetersCompanion data) {
    return Meter(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      location: data.location.present ? data.location.value : this.location,
      area: data.area.present ? data.area.value : this.area,
      number: data.number.present ? data.number.value : this.number,
      description: data.description.present
          ? data.description.value
          : this.description,
      photoKey: data.photoKey.present ? data.photoKey.value : this.photoKey,
      lastLoggedAt: data.lastLoggedAt.present
          ? data.lastLoggedAt.value
          : this.lastLoggedAt,
      todoOrder: data.todoOrder.present ? data.todoOrder.value : this.todoOrder,
      exportOrder: data.exportOrder.present
          ? data.exportOrder.value
          : this.exportOrder,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Meter(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('location: $location, ')
          ..write('area: $area, ')
          ..write('number: $number, ')
          ..write('description: $description, ')
          ..write('photoKey: $photoKey, ')
          ..write('lastLoggedAt: $lastLoggedAt, ')
          ..write('todoOrder: $todoOrder, ')
          ..write('exportOrder: $exportOrder, ')
          ..write('isActive: $isActive, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    location,
    area,
    number,
    description,
    photoKey,
    lastLoggedAt,
    todoOrder,
    exportOrder,
    isActive,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Meter &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.location == this.location &&
          other.area == this.area &&
          other.number == this.number &&
          other.description == this.description &&
          other.photoKey == this.photoKey &&
          other.lastLoggedAt == this.lastLoggedAt &&
          other.todoOrder == this.todoOrder &&
          other.exportOrder == this.exportOrder &&
          other.isActive == this.isActive &&
          other.updatedAt == this.updatedAt);
}

class MetersCompanion extends UpdateCompanion<Meter> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String> location;
  final Value<String> area;
  final Value<String?> number;
  final Value<String?> description;
  final Value<String?> photoKey;
  final Value<String?> lastLoggedAt;
  final Value<int?> todoOrder;
  final Value<int?> exportOrder;
  final Value<bool> isActive;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const MetersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.location = const Value.absent(),
    this.area = const Value.absent(),
    this.number = const Value.absent(),
    this.description = const Value.absent(),
    this.photoKey = const Value.absent(),
    this.lastLoggedAt = const Value.absent(),
    this.todoOrder = const Value.absent(),
    this.exportOrder = const Value.absent(),
    this.isActive = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetersCompanion.insert({
    required String id,
    this.name = const Value.absent(),
    required String type,
    required String location,
    this.area = const Value.absent(),
    this.number = const Value.absent(),
    this.description = const Value.absent(),
    this.photoKey = const Value.absent(),
    this.lastLoggedAt = const Value.absent(),
    this.todoOrder = const Value.absent(),
    this.exportOrder = const Value.absent(),
    this.isActive = const Value.absent(),
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       location = Value(location),
       updatedAt = Value(updatedAt);
  static Insertable<Meter> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? location,
    Expression<String>? area,
    Expression<String>? number,
    Expression<String>? description,
    Expression<String>? photoKey,
    Expression<String>? lastLoggedAt,
    Expression<int>? todoOrder,
    Expression<int>? exportOrder,
    Expression<bool>? isActive,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (location != null) 'location': location,
      if (area != null) 'area': area,
      if (number != null) 'number': number,
      if (description != null) 'description': description,
      if (photoKey != null) 'photo_key': photoKey,
      if (lastLoggedAt != null) 'last_logged_at': lastLoggedAt,
      if (todoOrder != null) 'todo_order': todoOrder,
      if (exportOrder != null) 'export_order': exportOrder,
      if (isActive != null) 'is_active': isActive,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? type,
    Value<String>? location,
    Value<String>? area,
    Value<String?>? number,
    Value<String?>? description,
    Value<String?>? photoKey,
    Value<String?>? lastLoggedAt,
    Value<int?>? todoOrder,
    Value<int?>? exportOrder,
    Value<bool>? isActive,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return MetersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      location: location ?? this.location,
      area: area ?? this.area,
      number: number ?? this.number,
      description: description ?? this.description,
      photoKey: photoKey ?? this.photoKey,
      lastLoggedAt: lastLoggedAt ?? this.lastLoggedAt,
      todoOrder: todoOrder ?? this.todoOrder,
      exportOrder: exportOrder ?? this.exportOrder,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (area.present) {
      map['area'] = Variable<String>(area.value);
    }
    if (number.present) {
      map['number'] = Variable<String>(number.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (photoKey.present) {
      map['photo_key'] = Variable<String>(photoKey.value);
    }
    if (lastLoggedAt.present) {
      map['last_logged_at'] = Variable<String>(lastLoggedAt.value);
    }
    if (todoOrder.present) {
      map['todo_order'] = Variable<int>(todoOrder.value);
    }
    if (exportOrder.present) {
      map['export_order'] = Variable<int>(exportOrder.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('location: $location, ')
          ..write('area: $area, ')
          ..write('number: $number, ')
          ..write('description: $description, ')
          ..write('photoKey: $photoKey, ')
          ..write('lastLoggedAt: $lastLoggedAt, ')
          ..write('todoOrder: $todoOrder, ')
          ..write('exportOrder: $exportOrder, ')
          ..write('isActive: $isActive, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReadingsTable extends Readings with TableInfo<$ReadingsTable, Reading> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _meterIdMeta = const VerificationMeta(
    'meterId',
  );
  @override
  late final GeneratedColumn<String> meterId = GeneratedColumn<String>(
    'meter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<double> value = GeneratedColumn<double>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _photoKeyMeta = const VerificationMeta(
    'photoKey',
  );
  @override
  late final GeneratedColumn<String> photoKey = GeneratedColumn<String>(
    'photo_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localPhotoPathMeta = const VerificationMeta(
    'localPhotoPath',
  );
  @override
  late final GeneratedColumn<String> localPhotoPath = GeneratedColumn<String>(
    'local_photo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _loggedByMeta = const VerificationMeta(
    'loggedBy',
  );
  @override
  late final GeneratedColumn<String> loggedBy = GeneratedColumn<String>(
    'logged_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _loggedAtMeta = const VerificationMeta(
    'loggedAt',
  );
  @override
  late final GeneratedColumn<String> loggedAt = GeneratedColumn<String>(
    'logged_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<String> syncedAt = GeneratedColumn<String>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    meterId,
    value,
    photoKey,
    localPhotoPath,
    loggedBy,
    loggedAt,
    syncedAt,
    syncStatus,
    retryCount,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'readings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Reading> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('meter_id')) {
      context.handle(
        _meterIdMeta,
        meterId.isAcceptableOrUnknown(data['meter_id']!, _meterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meterIdMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('photo_key')) {
      context.handle(
        _photoKeyMeta,
        photoKey.isAcceptableOrUnknown(data['photo_key']!, _photoKeyMeta),
      );
    }
    if (data.containsKey('local_photo_path')) {
      context.handle(
        _localPhotoPathMeta,
        localPhotoPath.isAcceptableOrUnknown(
          data['local_photo_path']!,
          _localPhotoPathMeta,
        ),
      );
    }
    if (data.containsKey('logged_by')) {
      context.handle(
        _loggedByMeta,
        loggedBy.isAcceptableOrUnknown(data['logged_by']!, _loggedByMeta),
      );
    } else if (isInserting) {
      context.missing(_loggedByMeta);
    }
    if (data.containsKey('logged_at')) {
      context.handle(
        _loggedAtMeta,
        loggedAt.isAcceptableOrUnknown(data['logged_at']!, _loggedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_loggedAtMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Reading map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Reading(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      meterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meter_id'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}value'],
      )!,
      photoKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_key'],
      ),
      localPhotoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_photo_path'],
      ),
      loggedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}logged_by'],
      )!,
      loggedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}logged_at'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}synced_at'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $ReadingsTable createAlias(String alias) {
    return $ReadingsTable(attachedDatabase, alias);
  }
}

class Reading extends DataClass implements Insertable<Reading> {
  final String id;
  final String meterId;
  final double value;
  final String? photoKey;
  final String? localPhotoPath;
  final String loggedBy;
  final String loggedAt;
  final String? syncedAt;
  final String syncStatus;
  final int retryCount;
  final String? lastError;
  const Reading({
    required this.id,
    required this.meterId,
    required this.value,
    this.photoKey,
    this.localPhotoPath,
    required this.loggedBy,
    required this.loggedAt,
    this.syncedAt,
    required this.syncStatus,
    required this.retryCount,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['meter_id'] = Variable<String>(meterId);
    map['value'] = Variable<double>(value);
    if (!nullToAbsent || photoKey != null) {
      map['photo_key'] = Variable<String>(photoKey);
    }
    if (!nullToAbsent || localPhotoPath != null) {
      map['local_photo_path'] = Variable<String>(localPhotoPath);
    }
    map['logged_by'] = Variable<String>(loggedBy);
    map['logged_at'] = Variable<String>(loggedAt);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<String>(syncedAt);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  ReadingsCompanion toCompanion(bool nullToAbsent) {
    return ReadingsCompanion(
      id: Value(id),
      meterId: Value(meterId),
      value: Value(value),
      photoKey: photoKey == null && nullToAbsent
          ? const Value.absent()
          : Value(photoKey),
      localPhotoPath: localPhotoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPhotoPath),
      loggedBy: Value(loggedBy),
      loggedAt: Value(loggedAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      syncStatus: Value(syncStatus),
      retryCount: Value(retryCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory Reading.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Reading(
      id: serializer.fromJson<String>(json['id']),
      meterId: serializer.fromJson<String>(json['meterId']),
      value: serializer.fromJson<double>(json['value']),
      photoKey: serializer.fromJson<String?>(json['photoKey']),
      localPhotoPath: serializer.fromJson<String?>(json['localPhotoPath']),
      loggedBy: serializer.fromJson<String>(json['loggedBy']),
      loggedAt: serializer.fromJson<String>(json['loggedAt']),
      syncedAt: serializer.fromJson<String?>(json['syncedAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'meterId': serializer.toJson<String>(meterId),
      'value': serializer.toJson<double>(value),
      'photoKey': serializer.toJson<String?>(photoKey),
      'localPhotoPath': serializer.toJson<String?>(localPhotoPath),
      'loggedBy': serializer.toJson<String>(loggedBy),
      'loggedAt': serializer.toJson<String>(loggedAt),
      'syncedAt': serializer.toJson<String?>(syncedAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'retryCount': serializer.toJson<int>(retryCount),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  Reading copyWith({
    String? id,
    String? meterId,
    double? value,
    Value<String?> photoKey = const Value.absent(),
    Value<String?> localPhotoPath = const Value.absent(),
    String? loggedBy,
    String? loggedAt,
    Value<String?> syncedAt = const Value.absent(),
    String? syncStatus,
    int? retryCount,
    Value<String?> lastError = const Value.absent(),
  }) => Reading(
    id: id ?? this.id,
    meterId: meterId ?? this.meterId,
    value: value ?? this.value,
    photoKey: photoKey.present ? photoKey.value : this.photoKey,
    localPhotoPath: localPhotoPath.present
        ? localPhotoPath.value
        : this.localPhotoPath,
    loggedBy: loggedBy ?? this.loggedBy,
    loggedAt: loggedAt ?? this.loggedAt,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    syncStatus: syncStatus ?? this.syncStatus,
    retryCount: retryCount ?? this.retryCount,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  Reading copyWithCompanion(ReadingsCompanion data) {
    return Reading(
      id: data.id.present ? data.id.value : this.id,
      meterId: data.meterId.present ? data.meterId.value : this.meterId,
      value: data.value.present ? data.value.value : this.value,
      photoKey: data.photoKey.present ? data.photoKey.value : this.photoKey,
      localPhotoPath: data.localPhotoPath.present
          ? data.localPhotoPath.value
          : this.localPhotoPath,
      loggedBy: data.loggedBy.present ? data.loggedBy.value : this.loggedBy,
      loggedAt: data.loggedAt.present ? data.loggedAt.value : this.loggedAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Reading(')
          ..write('id: $id, ')
          ..write('meterId: $meterId, ')
          ..write('value: $value, ')
          ..write('photoKey: $photoKey, ')
          ..write('localPhotoPath: $localPhotoPath, ')
          ..write('loggedBy: $loggedBy, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    meterId,
    value,
    photoKey,
    localPhotoPath,
    loggedBy,
    loggedAt,
    syncedAt,
    syncStatus,
    retryCount,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reading &&
          other.id == this.id &&
          other.meterId == this.meterId &&
          other.value == this.value &&
          other.photoKey == this.photoKey &&
          other.localPhotoPath == this.localPhotoPath &&
          other.loggedBy == this.loggedBy &&
          other.loggedAt == this.loggedAt &&
          other.syncedAt == this.syncedAt &&
          other.syncStatus == this.syncStatus &&
          other.retryCount == this.retryCount &&
          other.lastError == this.lastError);
}

class ReadingsCompanion extends UpdateCompanion<Reading> {
  final Value<String> id;
  final Value<String> meterId;
  final Value<double> value;
  final Value<String?> photoKey;
  final Value<String?> localPhotoPath;
  final Value<String> loggedBy;
  final Value<String> loggedAt;
  final Value<String?> syncedAt;
  final Value<String> syncStatus;
  final Value<int> retryCount;
  final Value<String?> lastError;
  final Value<int> rowid;
  const ReadingsCompanion({
    this.id = const Value.absent(),
    this.meterId = const Value.absent(),
    this.value = const Value.absent(),
    this.photoKey = const Value.absent(),
    this.localPhotoPath = const Value.absent(),
    this.loggedBy = const Value.absent(),
    this.loggedAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReadingsCompanion.insert({
    required String id,
    required String meterId,
    required double value,
    this.photoKey = const Value.absent(),
    this.localPhotoPath = const Value.absent(),
    required String loggedBy,
    required String loggedAt,
    this.syncedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       meterId = Value(meterId),
       value = Value(value),
       loggedBy = Value(loggedBy),
       loggedAt = Value(loggedAt);
  static Insertable<Reading> custom({
    Expression<String>? id,
    Expression<String>? meterId,
    Expression<double>? value,
    Expression<String>? photoKey,
    Expression<String>? localPhotoPath,
    Expression<String>? loggedBy,
    Expression<String>? loggedAt,
    Expression<String>? syncedAt,
    Expression<String>? syncStatus,
    Expression<int>? retryCount,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (meterId != null) 'meter_id': meterId,
      if (value != null) 'value': value,
      if (photoKey != null) 'photo_key': photoKey,
      if (localPhotoPath != null) 'local_photo_path': localPhotoPath,
      if (loggedBy != null) 'logged_by': loggedBy,
      if (loggedAt != null) 'logged_at': loggedAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (retryCount != null) 'retry_count': retryCount,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReadingsCompanion copyWith({
    Value<String>? id,
    Value<String>? meterId,
    Value<double>? value,
    Value<String?>? photoKey,
    Value<String?>? localPhotoPath,
    Value<String>? loggedBy,
    Value<String>? loggedAt,
    Value<String?>? syncedAt,
    Value<String>? syncStatus,
    Value<int>? retryCount,
    Value<String?>? lastError,
    Value<int>? rowid,
  }) {
    return ReadingsCompanion(
      id: id ?? this.id,
      meterId: meterId ?? this.meterId,
      value: value ?? this.value,
      photoKey: photoKey ?? this.photoKey,
      localPhotoPath: localPhotoPath ?? this.localPhotoPath,
      loggedBy: loggedBy ?? this.loggedBy,
      loggedAt: loggedAt ?? this.loggedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (meterId.present) {
      map['meter_id'] = Variable<String>(meterId.value);
    }
    if (value.present) {
      map['value'] = Variable<double>(value.value);
    }
    if (photoKey.present) {
      map['photo_key'] = Variable<String>(photoKey.value);
    }
    if (localPhotoPath.present) {
      map['local_photo_path'] = Variable<String>(localPhotoPath.value);
    }
    if (loggedBy.present) {
      map['logged_by'] = Variable<String>(loggedBy.value);
    }
    if (loggedAt.present) {
      map['logged_at'] = Variable<String>(loggedAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<String>(syncedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingsCompanion(')
          ..write('id: $id, ')
          ..write('meterId: $meterId, ')
          ..write('value: $value, ')
          ..write('photoKey: $photoKey, ')
          ..write('localPhotoPath: $localPhotoPath, ')
          ..write('loggedBy: $loggedBy, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MetersTable meters = $MetersTable(this);
  late final $ReadingsTable readings = $ReadingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [meters, readings];
}

typedef $$MetersTableCreateCompanionBuilder = MetersCompanion Function({
  required String id,
  Value<String> name,
  required String type,
  required String location,
  Value<String> area,
  Value<String?> number,
  Value<String?> description,
  Value<String?> photoKey,
  Value<String?> lastLoggedAt,
  Value<int?> todoOrder,
  Value<int?> exportOrder,
  Value<bool> isActive,
  required String updatedAt,
  Value<int> rowid,
});
typedef $$MetersTableUpdateCompanionBuilder = MetersCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> type,
  Value<String> location,
  Value<String> area,
  Value<String?> number,
  Value<String?> description,
  Value<String?> photoKey,
  Value<String?> lastLoggedAt,
  Value<int?> todoOrder,
  Value<int?> exportOrder,
  Value<bool> isActive,
  Value<String> updatedAt,
  Value<int> rowid,
});

class $$MetersTableFilterComposer
    extends Composer<_$AppDatabase, $MetersTable> {
  $$MetersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get area => $composableBuilder(
    column: $table.area,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoKey => $composableBuilder(
    column: $table.photoKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastLoggedAt => $composableBuilder(
    column: $table.lastLoggedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get todoOrder => $composableBuilder(
    column: $table.todoOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get exportOrder => $composableBuilder(
    column: $table.exportOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MetersTableOrderingComposer
    extends Composer<_$AppDatabase, $MetersTable> {
  $$MetersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get area => $composableBuilder(
    column: $table.area,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoKey => $composableBuilder(
    column: $table.photoKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastLoggedAt => $composableBuilder(
    column: $table.lastLoggedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get todoOrder => $composableBuilder(
    column: $table.todoOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get exportOrder => $composableBuilder(
    column: $table.exportOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MetersTableAnnotationComposer
    extends Composer<_$AppDatabase, $MetersTable> {
  $$MetersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get area =>
      $composableBuilder(column: $table.area, builder: (column) => column);

  GeneratedColumn<String> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get photoKey =>
      $composableBuilder(column: $table.photoKey, builder: (column) => column);

  GeneratedColumn<String> get lastLoggedAt => $composableBuilder(
    column: $table.lastLoggedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get todoOrder =>
      $composableBuilder(column: $table.todoOrder, builder: (column) => column);

  GeneratedColumn<int> get exportOrder => $composableBuilder(
    column: $table.exportOrder,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MetersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MetersTable,
          Meter,
          $$MetersTableFilterComposer,
          $$MetersTableOrderingComposer,
          $$MetersTableAnnotationComposer,
          $$MetersTableCreateCompanionBuilder,
          $$MetersTableUpdateCompanionBuilder,
          (Meter, BaseReferences<_$AppDatabase, $MetersTable, Meter>),
          Meter,
          PrefetchHooks Function()
        > {
  $$MetersTableTableManager(_$AppDatabase db, $MetersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> location = const Value.absent(),
                Value<String> area = const Value.absent(),
                Value<String?> number = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> photoKey = const Value.absent(),
                Value<String?> lastLoggedAt = const Value.absent(),
                Value<int?> todoOrder = const Value.absent(),
                Value<int?> exportOrder = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MetersCompanion(
                id: id,
                name: name,
                type: type,
                location: location,
                area: area,
                number: number,
                description: description,
                photoKey: photoKey,
                lastLoggedAt: lastLoggedAt,
                todoOrder: todoOrder,
                exportOrder: exportOrder,
                isActive: isActive,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> name = const Value.absent(),
                required String type,
                required String location,
                Value<String> area = const Value.absent(),
                Value<String?> number = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> photoKey = const Value.absent(),
                Value<String?> lastLoggedAt = const Value.absent(),
                Value<int?> todoOrder = const Value.absent(),
                Value<int?> exportOrder = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MetersCompanion.insert(
                id: id,
                name: name,
                type: type,
                location: location,
                area: area,
                number: number,
                description: description,
                photoKey: photoKey,
                lastLoggedAt: lastLoggedAt,
                todoOrder: todoOrder,
                exportOrder: exportOrder,
                isActive: isActive,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MetersTable, Meter>(table),
                  BaseReferences<_$AppDatabase, $MetersTable, Meter>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MetersTable,
      Meter,
      $$MetersTableFilterComposer,
      $$MetersTableOrderingComposer,
      $$MetersTableAnnotationComposer,
      $$MetersTableCreateCompanionBuilder,
      $$MetersTableUpdateCompanionBuilder,
      (Meter, BaseReferences<_$AppDatabase, $MetersTable, Meter>),
      Meter,
      PrefetchHooks Function()
    >;
typedef $$ReadingsTableCreateCompanionBuilder = ReadingsCompanion Function({
  required String id,
  required String meterId,
  required double value,
  Value<String?> photoKey,
  Value<String?> localPhotoPath,
  required String loggedBy,
  required String loggedAt,
  Value<String?> syncedAt,
  Value<String> syncStatus,
  Value<int> retryCount,
  Value<String?> lastError,
  Value<int> rowid,
});
typedef $$ReadingsTableUpdateCompanionBuilder = ReadingsCompanion Function({
  Value<String> id,
  Value<String> meterId,
  Value<double> value,
  Value<String?> photoKey,
  Value<String?> localPhotoPath,
  Value<String> loggedBy,
  Value<String> loggedAt,
  Value<String?> syncedAt,
  Value<String> syncStatus,
  Value<int> retryCount,
  Value<String?> lastError,
  Value<int> rowid,
});

class $$ReadingsTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingsTable> {
  $$ReadingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meterId => $composableBuilder(
    column: $table.meterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoKey => $composableBuilder(
    column: $table.photoKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPhotoPath => $composableBuilder(
    column: $table.localPhotoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get loggedBy => $composableBuilder(
    column: $table.loggedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get loggedAt => $composableBuilder(
    column: $table.loggedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReadingsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingsTable> {
  $$ReadingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meterId => $composableBuilder(
    column: $table.meterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoKey => $composableBuilder(
    column: $table.photoKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPhotoPath => $composableBuilder(
    column: $table.localPhotoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loggedBy => $composableBuilder(
    column: $table.loggedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loggedAt => $composableBuilder(
    column: $table.loggedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReadingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingsTable> {
  $$ReadingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get meterId =>
      $composableBuilder(column: $table.meterId, builder: (column) => column);

  GeneratedColumn<double> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get photoKey =>
      $composableBuilder(column: $table.photoKey, builder: (column) => column);

  GeneratedColumn<String> get localPhotoPath => $composableBuilder(
    column: $table.localPhotoPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get loggedBy =>
      $composableBuilder(column: $table.loggedBy, builder: (column) => column);

  GeneratedColumn<String> get loggedAt =>
      $composableBuilder(column: $table.loggedAt, builder: (column) => column);

  GeneratedColumn<String> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$ReadingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingsTable,
          Reading,
          $$ReadingsTableFilterComposer,
          $$ReadingsTableOrderingComposer,
          $$ReadingsTableAnnotationComposer,
          $$ReadingsTableCreateCompanionBuilder,
          $$ReadingsTableUpdateCompanionBuilder,
          (Reading, BaseReferences<_$AppDatabase, $ReadingsTable, Reading>),
          Reading,
          PrefetchHooks Function()
        > {
  $$ReadingsTableTableManager(_$AppDatabase db, $ReadingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> meterId = const Value.absent(),
                Value<double> value = const Value.absent(),
                Value<String?> photoKey = const Value.absent(),
                Value<String?> localPhotoPath = const Value.absent(),
                Value<String> loggedBy = const Value.absent(),
                Value<String> loggedAt = const Value.absent(),
                Value<String?> syncedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadingsCompanion(
                id: id,
                meterId: meterId,
                value: value,
                photoKey: photoKey,
                localPhotoPath: localPhotoPath,
                loggedBy: loggedBy,
                loggedAt: loggedAt,
                syncedAt: syncedAt,
                syncStatus: syncStatus,
                retryCount: retryCount,
                lastError: lastError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String meterId,
                required double value,
                Value<String?> photoKey = const Value.absent(),
                Value<String?> localPhotoPath = const Value.absent(),
                required String loggedBy,
                required String loggedAt,
                Value<String?> syncedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadingsCompanion.insert(
                id: id,
                meterId: meterId,
                value: value,
                photoKey: photoKey,
                localPhotoPath: localPhotoPath,
                loggedBy: loggedBy,
                loggedAt: loggedAt,
                syncedAt: syncedAt,
                syncStatus: syncStatus,
                retryCount: retryCount,
                lastError: lastError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReadingsTable, Reading>(table),
                  BaseReferences<_$AppDatabase, $ReadingsTable, Reading>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReadingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingsTable,
      Reading,
      $$ReadingsTableFilterComposer,
      $$ReadingsTableOrderingComposer,
      $$ReadingsTableAnnotationComposer,
      $$ReadingsTableCreateCompanionBuilder,
      $$ReadingsTableUpdateCompanionBuilder,
      (Reading, BaseReferences<_$AppDatabase, $ReadingsTable, Reading>),
      Reading,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MetersTableTableManager get meters =>
      $$MetersTableTableManager(_db, _db.meters);
  $$ReadingsTableTableManager get readings =>
      $$ReadingsTableTableManager(_db, _db.readings);
}
