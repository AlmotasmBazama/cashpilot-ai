// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AccountsTable extends Accounts
    with TableInfo<$AccountsTable, AccountRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerScopeIdMeta = const VerificationMeta(
    'ownerScopeId',
  );
  @override
  late final GeneratedColumn<String> ownerScopeId = GeneratedColumn<String>(
    'owner_scope_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 3,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _balanceMeta = const VerificationMeta(
    'balance',
  );
  @override
  late final GeneratedColumn<String> balance = GeneratedColumn<String>(
    'balance',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paymentMethodIdsMeta = const VerificationMeta(
    'paymentMethodIds',
  );
  @override
  late final GeneratedColumn<String> paymentMethodIds = GeneratedColumn<String>(
    'payment_method_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerScopeId,
    name,
    type,
    currencyCode,
    balance,
    icon,
    color,
    paymentMethodIds,
    isArchived,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<AccountRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_scope_id')) {
      context.handle(
        _ownerScopeIdMeta,
        ownerScopeId.isAcceptableOrUnknown(
          data['owner_scope_id']!,
          _ownerScopeIdMeta,
        ),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currencyCodeMeta);
    }
    if (data.containsKey('balance')) {
      context.handle(
        _balanceMeta,
        balance.isAcceptableOrUnknown(data['balance']!, _balanceMeta),
      );
    } else if (isInserting) {
      context.missing(_balanceMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    } else if (isInserting) {
      context.missing(_iconMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('payment_method_ids')) {
      context.handle(
        _paymentMethodIdsMeta,
        paymentMethodIds.isAcceptableOrUnknown(
          data['payment_method_ids']!,
          _paymentMethodIdsMeta,
        ),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
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
  AccountRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AccountRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_scope_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      )!,
      balance: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}balance'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
      paymentMethodIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_method_ids'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }
}

class AccountRow extends DataClass implements Insertable<AccountRow> {
  final String id;

  /// Opaque, locally-derived owner scope. Null is reserved for unclaimed
  /// pre-v15 rows and is rejected for all new production writes.
  final String? ownerScopeId;
  final String name;
  final String type;
  final String currencyCode;
  final String balance;
  final String icon;
  final int color;
  final String paymentMethodIds;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  const AccountRow({
    required this.id,
    this.ownerScopeId,
    required this.name,
    required this.type,
    required this.currencyCode,
    required this.balance,
    required this.icon,
    required this.color,
    required this.paymentMethodIds,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || ownerScopeId != null) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId);
    }
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['currency_code'] = Variable<String>(currencyCode);
    map['balance'] = Variable<String>(balance);
    map['icon'] = Variable<String>(icon);
    map['color'] = Variable<int>(color);
    map['payment_method_ids'] = Variable<String>(paymentMethodIds);
    map['is_archived'] = Variable<bool>(isArchived);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      ownerScopeId: ownerScopeId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerScopeId),
      name: Value(name),
      type: Value(type),
      currencyCode: Value(currencyCode),
      balance: Value(balance),
      icon: Value(icon),
      color: Value(color),
      paymentMethodIds: Value(paymentMethodIds),
      isArchived: Value(isArchived),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AccountRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccountRow(
      id: serializer.fromJson<String>(json['id']),
      ownerScopeId: serializer.fromJson<String?>(json['ownerScopeId']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      currencyCode: serializer.fromJson<String>(json['currencyCode']),
      balance: serializer.fromJson<String>(json['balance']),
      icon: serializer.fromJson<String>(json['icon']),
      color: serializer.fromJson<int>(json['color']),
      paymentMethodIds: serializer.fromJson<String>(json['paymentMethodIds']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerScopeId': serializer.toJson<String?>(ownerScopeId),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'currencyCode': serializer.toJson<String>(currencyCode),
      'balance': serializer.toJson<String>(balance),
      'icon': serializer.toJson<String>(icon),
      'color': serializer.toJson<int>(color),
      'paymentMethodIds': serializer.toJson<String>(paymentMethodIds),
      'isArchived': serializer.toJson<bool>(isArchived),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AccountRow copyWith({
    String? id,
    Value<String?> ownerScopeId = const Value.absent(),
    String? name,
    String? type,
    String? currencyCode,
    String? balance,
    String? icon,
    int? color,
    String? paymentMethodIds,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => AccountRow(
    id: id ?? this.id,
    ownerScopeId: ownerScopeId.present ? ownerScopeId.value : this.ownerScopeId,
    name: name ?? this.name,
    type: type ?? this.type,
    currencyCode: currencyCode ?? this.currencyCode,
    balance: balance ?? this.balance,
    icon: icon ?? this.icon,
    color: color ?? this.color,
    paymentMethodIds: paymentMethodIds ?? this.paymentMethodIds,
    isArchived: isArchived ?? this.isArchived,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AccountRow copyWithCompanion(AccountsCompanion data) {
    return AccountRow(
      id: data.id.present ? data.id.value : this.id,
      ownerScopeId: data.ownerScopeId.present
          ? data.ownerScopeId.value
          : this.ownerScopeId,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      balance: data.balance.present ? data.balance.value : this.balance,
      icon: data.icon.present ? data.icon.value : this.icon,
      color: data.color.present ? data.color.value : this.color,
      paymentMethodIds: data.paymentMethodIds.present
          ? data.paymentMethodIds.value
          : this.paymentMethodIds,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccountRow(')
          ..write('id: $id, ')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('balance: $balance, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('paymentMethodIds: $paymentMethodIds, ')
          ..write('isArchived: $isArchived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerScopeId,
    name,
    type,
    currencyCode,
    balance,
    icon,
    color,
    paymentMethodIds,
    isArchived,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountRow &&
          other.id == this.id &&
          other.ownerScopeId == this.ownerScopeId &&
          other.name == this.name &&
          other.type == this.type &&
          other.currencyCode == this.currencyCode &&
          other.balance == this.balance &&
          other.icon == this.icon &&
          other.color == this.color &&
          other.paymentMethodIds == this.paymentMethodIds &&
          other.isArchived == this.isArchived &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AccountsCompanion extends UpdateCompanion<AccountRow> {
  final Value<String> id;
  final Value<String?> ownerScopeId;
  final Value<String> name;
  final Value<String> type;
  final Value<String> currencyCode;
  final Value<String> balance;
  final Value<String> icon;
  final Value<int> color;
  final Value<String> paymentMethodIds;
  final Value<bool> isArchived;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.ownerScopeId = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.balance = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.paymentMethodIds = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountsCompanion.insert({
    required String id,
    this.ownerScopeId = const Value.absent(),
    required String name,
    required String type,
    required String currencyCode,
    required String balance,
    required String icon,
    required int color,
    this.paymentMethodIds = const Value.absent(),
    this.isArchived = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       type = Value(type),
       currencyCode = Value(currencyCode),
       balance = Value(balance),
       icon = Value(icon),
       color = Value(color),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<AccountRow> custom({
    Expression<String>? id,
    Expression<String>? ownerScopeId,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? currencyCode,
    Expression<String>? balance,
    Expression<String>? icon,
    Expression<int>? color,
    Expression<String>? paymentMethodIds,
    Expression<bool>? isArchived,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerScopeId != null) 'owner_scope_id': ownerScopeId,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (balance != null) 'balance': balance,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      if (paymentMethodIds != null) 'payment_method_ids': paymentMethodIds,
      if (isArchived != null) 'is_archived': isArchived,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountsCompanion copyWith({
    Value<String>? id,
    Value<String?>? ownerScopeId,
    Value<String>? name,
    Value<String>? type,
    Value<String>? currencyCode,
    Value<String>? balance,
    Value<String>? icon,
    Value<int>? color,
    Value<String>? paymentMethodIds,
    Value<bool>? isArchived,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AccountsCompanion(
      id: id ?? this.id,
      ownerScopeId: ownerScopeId ?? this.ownerScopeId,
      name: name ?? this.name,
      type: type ?? this.type,
      currencyCode: currencyCode ?? this.currencyCode,
      balance: balance ?? this.balance,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      paymentMethodIds: paymentMethodIds ?? this.paymentMethodIds,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
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
    if (ownerScopeId.present) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (balance.present) {
      map['balance'] = Variable<String>(balance.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (paymentMethodIds.present) {
      map['payment_method_ids'] = Variable<String>(paymentMethodIds.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('balance: $balance, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('paymentMethodIds: $paymentMethodIds, ')
          ..write('isArchived: $isArchived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, CategoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerScopeIdMeta = const VerificationMeta(
    'ownerScopeId',
  );
  @override
  late final GeneratedColumn<String> ownerScopeId = GeneratedColumn<String>(
    'owner_scope_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentCategoryIdMeta = const VerificationMeta(
    'parentCategoryId',
  );
  @override
  late final GeneratedColumn<String> parentCategoryId = GeneratedColumn<String>(
    'parent_category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerScopeId,
    name,
    type,
    icon,
    color,
    parentCategoryId,
    isDefault,
    isArchived,
    sortOrder,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_scope_id')) {
      context.handle(
        _ownerScopeIdMeta,
        ownerScopeId.isAcceptableOrUnknown(
          data['owner_scope_id']!,
          _ownerScopeIdMeta,
        ),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    } else if (isInserting) {
      context.missing(_iconMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('parent_category_id')) {
      context.handle(
        _parentCategoryIdMeta,
        parentCategoryId.isAcceptableOrUnknown(
          data['parent_category_id']!,
          _parentCategoryIdMeta,
        ),
      );
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
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
  CategoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_scope_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
      parentCategoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_category_id'],
      ),
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class CategoryRow extends DataClass implements Insertable<CategoryRow> {
  final String id;

  /// Null is allowed only for immutable built-in reference categories and
  /// unclaimed legacy rows. Custom categories are always owner-scoped.
  final String? ownerScopeId;
  final String name;
  final String type;
  final String icon;
  final int color;
  final String? parentCategoryId;
  final bool isDefault;
  final bool isArchived;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  const CategoryRow({
    required this.id,
    this.ownerScopeId,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    this.parentCategoryId,
    required this.isDefault,
    required this.isArchived,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || ownerScopeId != null) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId);
    }
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['icon'] = Variable<String>(icon);
    map['color'] = Variable<int>(color);
    if (!nullToAbsent || parentCategoryId != null) {
      map['parent_category_id'] = Variable<String>(parentCategoryId);
    }
    map['is_default'] = Variable<bool>(isDefault);
    map['is_archived'] = Variable<bool>(isArchived);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      ownerScopeId: ownerScopeId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerScopeId),
      name: Value(name),
      type: Value(type),
      icon: Value(icon),
      color: Value(color),
      parentCategoryId: parentCategoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentCategoryId),
      isDefault: Value(isDefault),
      isArchived: Value(isArchived),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CategoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryRow(
      id: serializer.fromJson<String>(json['id']),
      ownerScopeId: serializer.fromJson<String?>(json['ownerScopeId']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      icon: serializer.fromJson<String>(json['icon']),
      color: serializer.fromJson<int>(json['color']),
      parentCategoryId: serializer.fromJson<String?>(json['parentCategoryId']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerScopeId': serializer.toJson<String?>(ownerScopeId),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'icon': serializer.toJson<String>(icon),
      'color': serializer.toJson<int>(color),
      'parentCategoryId': serializer.toJson<String?>(parentCategoryId),
      'isDefault': serializer.toJson<bool>(isDefault),
      'isArchived': serializer.toJson<bool>(isArchived),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CategoryRow copyWith({
    String? id,
    Value<String?> ownerScopeId = const Value.absent(),
    String? name,
    String? type,
    String? icon,
    int? color,
    Value<String?> parentCategoryId = const Value.absent(),
    bool? isDefault,
    bool? isArchived,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CategoryRow(
    id: id ?? this.id,
    ownerScopeId: ownerScopeId.present ? ownerScopeId.value : this.ownerScopeId,
    name: name ?? this.name,
    type: type ?? this.type,
    icon: icon ?? this.icon,
    color: color ?? this.color,
    parentCategoryId: parentCategoryId.present
        ? parentCategoryId.value
        : this.parentCategoryId,
    isDefault: isDefault ?? this.isDefault,
    isArchived: isArchived ?? this.isArchived,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CategoryRow copyWithCompanion(CategoriesCompanion data) {
    return CategoryRow(
      id: data.id.present ? data.id.value : this.id,
      ownerScopeId: data.ownerScopeId.present
          ? data.ownerScopeId.value
          : this.ownerScopeId,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      icon: data.icon.present ? data.icon.value : this.icon,
      color: data.color.present ? data.color.value : this.color,
      parentCategoryId: data.parentCategoryId.present
          ? data.parentCategoryId.value
          : this.parentCategoryId,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryRow(')
          ..write('id: $id, ')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('parentCategoryId: $parentCategoryId, ')
          ..write('isDefault: $isDefault, ')
          ..write('isArchived: $isArchived, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerScopeId,
    name,
    type,
    icon,
    color,
    parentCategoryId,
    isDefault,
    isArchived,
    sortOrder,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryRow &&
          other.id == this.id &&
          other.ownerScopeId == this.ownerScopeId &&
          other.name == this.name &&
          other.type == this.type &&
          other.icon == this.icon &&
          other.color == this.color &&
          other.parentCategoryId == this.parentCategoryId &&
          other.isDefault == this.isDefault &&
          other.isArchived == this.isArchived &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CategoriesCompanion extends UpdateCompanion<CategoryRow> {
  final Value<String> id;
  final Value<String?> ownerScopeId;
  final Value<String> name;
  final Value<String> type;
  final Value<String> icon;
  final Value<int> color;
  final Value<String?> parentCategoryId;
  final Value<bool> isDefault;
  final Value<bool> isArchived;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.ownerScopeId = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.parentCategoryId = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    this.ownerScopeId = const Value.absent(),
    required String name,
    required String type,
    required String icon,
    required int color,
    this.parentCategoryId = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.isArchived = const Value.absent(),
    required int sortOrder,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       type = Value(type),
       icon = Value(icon),
       color = Value(color),
       sortOrder = Value(sortOrder),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<CategoryRow> custom({
    Expression<String>? id,
    Expression<String>? ownerScopeId,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? icon,
    Expression<int>? color,
    Expression<String>? parentCategoryId,
    Expression<bool>? isDefault,
    Expression<bool>? isArchived,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerScopeId != null) 'owner_scope_id': ownerScopeId,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      if (parentCategoryId != null) 'parent_category_id': parentCategoryId,
      if (isDefault != null) 'is_default': isDefault,
      if (isArchived != null) 'is_archived': isArchived,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<String?>? ownerScopeId,
    Value<String>? name,
    Value<String>? type,
    Value<String>? icon,
    Value<int>? color,
    Value<String?>? parentCategoryId,
    Value<bool>? isDefault,
    Value<bool>? isArchived,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      ownerScopeId: ownerScopeId ?? this.ownerScopeId,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      parentCategoryId: parentCategoryId ?? this.parentCategoryId,
      isDefault: isDefault ?? this.isDefault,
      isArchived: isArchived ?? this.isArchived,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
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
    if (ownerScopeId.present) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (parentCategoryId.present) {
      map['parent_category_id'] = Variable<String>(parentCategoryId.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('parentCategoryId: $parentCategoryId, ')
          ..write('isDefault: $isDefault, ')
          ..write('isArchived: $isArchived, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PayeesTable extends Payees with TableInfo<$PayeesTable, PayeeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PayeesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerScopeIdMeta = const VerificationMeta(
    'ownerScopeId',
  );
  @override
  late final GeneratedColumn<String> ownerScopeId = GeneratedColumn<String>(
    'owner_scope_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedNameMeta = const VerificationMeta(
    'normalizedName',
  );
  @override
  late final GeneratedColumn<String> normalizedName = GeneratedColumn<String>(
    'normalized_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('other'),
  );
  static const VerificationMeta _aliasesMeta = const VerificationMeta(
    'aliases',
  );
  @override
  late final GeneratedColumn<String> aliases = GeneratedColumn<String>(
    'aliases',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _defaultCategoryIdMeta = const VerificationMeta(
    'defaultCategoryId',
  );
  @override
  late final GeneratedColumn<String> defaultCategoryId =
      GeneratedColumn<String>(
        'default_category_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _defaultAccountIdMeta = const VerificationMeta(
    'defaultAccountId',
  );
  @override
  late final GeneratedColumn<String> defaultAccountId = GeneratedColumn<String>(
    'default_account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastUsedAtMeta = const VerificationMeta(
    'lastUsedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastUsedAt = GeneratedColumn<DateTime>(
    'last_used_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerScopeId,
    name,
    normalizedName,
    type,
    aliases,
    defaultCategoryId,
    defaultAccountId,
    notes,
    lastUsedAt,
    createdAt,
    updatedAt,
    archivedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payees';
  @override
  VerificationContext validateIntegrity(
    Insertable<PayeeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_scope_id')) {
      context.handle(
        _ownerScopeIdMeta,
        ownerScopeId.isAcceptableOrUnknown(
          data['owner_scope_id']!,
          _ownerScopeIdMeta,
        ),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('normalized_name')) {
      context.handle(
        _normalizedNameMeta,
        normalizedName.isAcceptableOrUnknown(
          data['normalized_name']!,
          _normalizedNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedNameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('aliases')) {
      context.handle(
        _aliasesMeta,
        aliases.isAcceptableOrUnknown(data['aliases']!, _aliasesMeta),
      );
    }
    if (data.containsKey('default_category_id')) {
      context.handle(
        _defaultCategoryIdMeta,
        defaultCategoryId.isAcceptableOrUnknown(
          data['default_category_id']!,
          _defaultCategoryIdMeta,
        ),
      );
    }
    if (data.containsKey('default_account_id')) {
      context.handle(
        _defaultAccountIdMeta,
        defaultAccountId.isAcceptableOrUnknown(
          data['default_account_id']!,
          _defaultAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('last_used_at')) {
      context.handle(
        _lastUsedAtMeta,
        lastUsedAt.isAcceptableOrUnknown(
          data['last_used_at']!,
          _lastUsedAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PayeeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PayeeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_scope_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      normalizedName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      aliases: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aliases'],
      )!,
      defaultCategoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_category_id'],
      ),
      defaultAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_account_id'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      lastUsedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_used_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
    );
  }

  @override
  $PayeesTable createAlias(String alias) {
    return $PayeesTable(attachedDatabase, alias);
  }
}

class PayeeRow extends DataClass implements Insertable<PayeeRow> {
  final String id;
  final String? ownerScopeId;
  final String name;
  final String normalizedName;
  final String type;
  final String aliases;
  final String? defaultCategoryId;
  final String? defaultAccountId;
  final String? notes;
  final DateTime? lastUsedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  const PayeeRow({
    required this.id,
    this.ownerScopeId,
    required this.name,
    required this.normalizedName,
    required this.type,
    required this.aliases,
    this.defaultCategoryId,
    this.defaultAccountId,
    this.notes,
    this.lastUsedAt,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || ownerScopeId != null) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId);
    }
    map['name'] = Variable<String>(name);
    map['normalized_name'] = Variable<String>(normalizedName);
    map['type'] = Variable<String>(type);
    map['aliases'] = Variable<String>(aliases);
    if (!nullToAbsent || defaultCategoryId != null) {
      map['default_category_id'] = Variable<String>(defaultCategoryId);
    }
    if (!nullToAbsent || defaultAccountId != null) {
      map['default_account_id'] = Variable<String>(defaultAccountId);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || lastUsedAt != null) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    return map;
  }

  PayeesCompanion toCompanion(bool nullToAbsent) {
    return PayeesCompanion(
      id: Value(id),
      ownerScopeId: ownerScopeId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerScopeId),
      name: Value(name),
      normalizedName: Value(normalizedName),
      type: Value(type),
      aliases: Value(aliases),
      defaultCategoryId: defaultCategoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultCategoryId),
      defaultAccountId: defaultAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultAccountId),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      lastUsedAt: lastUsedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUsedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
    );
  }

  factory PayeeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PayeeRow(
      id: serializer.fromJson<String>(json['id']),
      ownerScopeId: serializer.fromJson<String?>(json['ownerScopeId']),
      name: serializer.fromJson<String>(json['name']),
      normalizedName: serializer.fromJson<String>(json['normalizedName']),
      type: serializer.fromJson<String>(json['type']),
      aliases: serializer.fromJson<String>(json['aliases']),
      defaultCategoryId: serializer.fromJson<String?>(
        json['defaultCategoryId'],
      ),
      defaultAccountId: serializer.fromJson<String?>(json['defaultAccountId']),
      notes: serializer.fromJson<String?>(json['notes']),
      lastUsedAt: serializer.fromJson<DateTime?>(json['lastUsedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerScopeId': serializer.toJson<String?>(ownerScopeId),
      'name': serializer.toJson<String>(name),
      'normalizedName': serializer.toJson<String>(normalizedName),
      'type': serializer.toJson<String>(type),
      'aliases': serializer.toJson<String>(aliases),
      'defaultCategoryId': serializer.toJson<String?>(defaultCategoryId),
      'defaultAccountId': serializer.toJson<String?>(defaultAccountId),
      'notes': serializer.toJson<String?>(notes),
      'lastUsedAt': serializer.toJson<DateTime?>(lastUsedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
    };
  }

  PayeeRow copyWith({
    String? id,
    Value<String?> ownerScopeId = const Value.absent(),
    String? name,
    String? normalizedName,
    String? type,
    String? aliases,
    Value<String?> defaultCategoryId = const Value.absent(),
    Value<String?> defaultAccountId = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<DateTime?> lastUsedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> archivedAt = const Value.absent(),
  }) => PayeeRow(
    id: id ?? this.id,
    ownerScopeId: ownerScopeId.present ? ownerScopeId.value : this.ownerScopeId,
    name: name ?? this.name,
    normalizedName: normalizedName ?? this.normalizedName,
    type: type ?? this.type,
    aliases: aliases ?? this.aliases,
    defaultCategoryId: defaultCategoryId.present
        ? defaultCategoryId.value
        : this.defaultCategoryId,
    defaultAccountId: defaultAccountId.present
        ? defaultAccountId.value
        : this.defaultAccountId,
    notes: notes.present ? notes.value : this.notes,
    lastUsedAt: lastUsedAt.present ? lastUsedAt.value : this.lastUsedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
  );
  PayeeRow copyWithCompanion(PayeesCompanion data) {
    return PayeeRow(
      id: data.id.present ? data.id.value : this.id,
      ownerScopeId: data.ownerScopeId.present
          ? data.ownerScopeId.value
          : this.ownerScopeId,
      name: data.name.present ? data.name.value : this.name,
      normalizedName: data.normalizedName.present
          ? data.normalizedName.value
          : this.normalizedName,
      type: data.type.present ? data.type.value : this.type,
      aliases: data.aliases.present ? data.aliases.value : this.aliases,
      defaultCategoryId: data.defaultCategoryId.present
          ? data.defaultCategoryId.value
          : this.defaultCategoryId,
      defaultAccountId: data.defaultAccountId.present
          ? data.defaultAccountId.value
          : this.defaultAccountId,
      notes: data.notes.present ? data.notes.value : this.notes,
      lastUsedAt: data.lastUsedAt.present
          ? data.lastUsedAt.value
          : this.lastUsedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PayeeRow(')
          ..write('id: $id, ')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('type: $type, ')
          ..write('aliases: $aliases, ')
          ..write('defaultCategoryId: $defaultCategoryId, ')
          ..write('defaultAccountId: $defaultAccountId, ')
          ..write('notes: $notes, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('archivedAt: $archivedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerScopeId,
    name,
    normalizedName,
    type,
    aliases,
    defaultCategoryId,
    defaultAccountId,
    notes,
    lastUsedAt,
    createdAt,
    updatedAt,
    archivedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PayeeRow &&
          other.id == this.id &&
          other.ownerScopeId == this.ownerScopeId &&
          other.name == this.name &&
          other.normalizedName == this.normalizedName &&
          other.type == this.type &&
          other.aliases == this.aliases &&
          other.defaultCategoryId == this.defaultCategoryId &&
          other.defaultAccountId == this.defaultAccountId &&
          other.notes == this.notes &&
          other.lastUsedAt == this.lastUsedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.archivedAt == this.archivedAt);
}

class PayeesCompanion extends UpdateCompanion<PayeeRow> {
  final Value<String> id;
  final Value<String?> ownerScopeId;
  final Value<String> name;
  final Value<String> normalizedName;
  final Value<String> type;
  final Value<String> aliases;
  final Value<String?> defaultCategoryId;
  final Value<String?> defaultAccountId;
  final Value<String?> notes;
  final Value<DateTime?> lastUsedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> archivedAt;
  final Value<int> rowid;
  const PayeesCompanion({
    this.id = const Value.absent(),
    this.ownerScopeId = const Value.absent(),
    this.name = const Value.absent(),
    this.normalizedName = const Value.absent(),
    this.type = const Value.absent(),
    this.aliases = const Value.absent(),
    this.defaultCategoryId = const Value.absent(),
    this.defaultAccountId = const Value.absent(),
    this.notes = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PayeesCompanion.insert({
    required String id,
    this.ownerScopeId = const Value.absent(),
    required String name,
    required String normalizedName,
    this.type = const Value.absent(),
    this.aliases = const Value.absent(),
    this.defaultCategoryId = const Value.absent(),
    this.defaultAccountId = const Value.absent(),
    this.notes = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       normalizedName = Value(normalizedName),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<PayeeRow> custom({
    Expression<String>? id,
    Expression<String>? ownerScopeId,
    Expression<String>? name,
    Expression<String>? normalizedName,
    Expression<String>? type,
    Expression<String>? aliases,
    Expression<String>? defaultCategoryId,
    Expression<String>? defaultAccountId,
    Expression<String>? notes,
    Expression<DateTime>? lastUsedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? archivedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerScopeId != null) 'owner_scope_id': ownerScopeId,
      if (name != null) 'name': name,
      if (normalizedName != null) 'normalized_name': normalizedName,
      if (type != null) 'type': type,
      if (aliases != null) 'aliases': aliases,
      if (defaultCategoryId != null) 'default_category_id': defaultCategoryId,
      if (defaultAccountId != null) 'default_account_id': defaultAccountId,
      if (notes != null) 'notes': notes,
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PayeesCompanion copyWith({
    Value<String>? id,
    Value<String?>? ownerScopeId,
    Value<String>? name,
    Value<String>? normalizedName,
    Value<String>? type,
    Value<String>? aliases,
    Value<String?>? defaultCategoryId,
    Value<String?>? defaultAccountId,
    Value<String?>? notes,
    Value<DateTime?>? lastUsedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? archivedAt,
    Value<int>? rowid,
  }) {
    return PayeesCompanion(
      id: id ?? this.id,
      ownerScopeId: ownerScopeId ?? this.ownerScopeId,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      type: type ?? this.type,
      aliases: aliases ?? this.aliases,
      defaultCategoryId: defaultCategoryId ?? this.defaultCategoryId,
      defaultAccountId: defaultAccountId ?? this.defaultAccountId,
      notes: notes ?? this.notes,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerScopeId.present) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (normalizedName.present) {
      map['normalized_name'] = Variable<String>(normalizedName.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (aliases.present) {
      map['aliases'] = Variable<String>(aliases.value);
    }
    if (defaultCategoryId.present) {
      map['default_category_id'] = Variable<String>(defaultCategoryId.value);
    }
    if (defaultAccountId.present) {
      map['default_account_id'] = Variable<String>(defaultAccountId.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (lastUsedAt.present) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PayeesCompanion(')
          ..write('id: $id, ')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('type: $type, ')
          ..write('aliases: $aliases, ')
          ..write('defaultCategoryId: $defaultCategoryId, ')
          ..write('defaultAccountId: $defaultAccountId, ')
          ..write('notes: $notes, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, TransactionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerScopeIdMeta = const VerificationMeta(
    'ownerScopeId',
  );
  @override
  late final GeneratedColumn<String> ownerScopeId = GeneratedColumn<String>(
    'owner_scope_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payeeIdMeta = const VerificationMeta(
    'payeeId',
  );
  @override
  late final GeneratedColumn<String> payeeId = GeneratedColumn<String>(
    'payee_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<String> amount = GeneratedColumn<String>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _paymentMethodMeta = const VerificationMeta(
    'paymentMethod',
  );
  @override
  late final GeneratedColumn<String> paymentMethod = GeneratedColumn<String>(
    'payment_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _incomeSourceTypeMeta = const VerificationMeta(
    'incomeSourceType',
  );
  @override
  late final GeneratedColumn<String> incomeSourceType = GeneratedColumn<String>(
    'income_source_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transferGroupIdMeta = const VerificationMeta(
    'transferGroupId',
  );
  @override
  late final GeneratedColumn<String> transferGroupId = GeneratedColumn<String>(
    'transfer_group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transferPayloadFingerprintMeta =
      const VerificationMeta('transferPayloadFingerprint');
  @override
  late final GeneratedColumn<String> transferPayloadFingerprint =
      GeneratedColumn<String>(
        'transfer_payload_fingerprint',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _exchangeRateFromCurrencyCodeMeta =
      const VerificationMeta('exchangeRateFromCurrencyCode');
  @override
  late final GeneratedColumn<String> exchangeRateFromCurrencyCode =
      GeneratedColumn<String>(
        'exchange_rate_from_currency_code',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _exchangeRateToCurrencyCodeMeta =
      const VerificationMeta('exchangeRateToCurrencyCode');
  @override
  late final GeneratedColumn<String> exchangeRateToCurrencyCode =
      GeneratedColumn<String>(
        'exchange_rate_to_currency_code',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _exchangeRateMeta = const VerificationMeta(
    'exchangeRate',
  );
  @override
  late final GeneratedColumn<String> exchangeRate = GeneratedColumn<String>(
    'exchange_rate',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exchangeRateAsOfMeta = const VerificationMeta(
    'exchangeRateAsOf',
  );
  @override
  late final GeneratedColumn<DateTime> exchangeRateAsOf =
      GeneratedColumn<DateTime>(
        'exchange_rate_as_of',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transactionDateMeta = const VerificationMeta(
    'transactionDate',
  );
  @override
  late final GeneratedColumn<DateTime> transactionDate =
      GeneratedColumn<DateTime>(
        'transaction_date',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attachmentCountMeta = const VerificationMeta(
    'attachmentCount',
  );
  @override
  late final GeneratedColumn<int> attachmentCount = GeneratedColumn<int>(
    'attachment_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _aiConfidenceMeta = const VerificationMeta(
    'aiConfidence',
  );
  @override
  late final GeneratedColumn<int> aiConfidence = GeneratedColumn<int>(
    'ai_confidence',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _needsReviewMeta = const VerificationMeta(
    'needsReview',
  );
  @override
  late final GeneratedColumn<bool> needsReview = GeneratedColumn<bool>(
    'needs_review',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("needs_review" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerScopeId,
    accountId,
    categoryId,
    payeeId,
    amount,
    currencyCode,
    type,
    paymentMethod,
    source,
    status,
    incomeSourceType,
    transferGroupId,
    transferPayloadFingerprint,
    exchangeRateFromCurrencyCode,
    exchangeRateToCurrencyCode,
    exchangeRate,
    exchangeRateAsOf,
    note,
    transactionDate,
    location,
    attachmentCount,
    aiConfidence,
    needsReview,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<TransactionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_scope_id')) {
      context.handle(
        _ownerScopeIdMeta,
        ownerScopeId.isAcceptableOrUnknown(
          data['owner_scope_id']!,
          _ownerScopeIdMeta,
        ),
      );
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('payee_id')) {
      context.handle(
        _payeeIdMeta,
        payeeId.isAcceptableOrUnknown(data['payee_id']!, _payeeIdMeta),
      );
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currencyCodeMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('payment_method')) {
      context.handle(
        _paymentMethodMeta,
        paymentMethod.isAcceptableOrUnknown(
          data['payment_method']!,
          _paymentMethodMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paymentMethodMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('income_source_type')) {
      context.handle(
        _incomeSourceTypeMeta,
        incomeSourceType.isAcceptableOrUnknown(
          data['income_source_type']!,
          _incomeSourceTypeMeta,
        ),
      );
    }
    if (data.containsKey('transfer_group_id')) {
      context.handle(
        _transferGroupIdMeta,
        transferGroupId.isAcceptableOrUnknown(
          data['transfer_group_id']!,
          _transferGroupIdMeta,
        ),
      );
    }
    if (data.containsKey('transfer_payload_fingerprint')) {
      context.handle(
        _transferPayloadFingerprintMeta,
        transferPayloadFingerprint.isAcceptableOrUnknown(
          data['transfer_payload_fingerprint']!,
          _transferPayloadFingerprintMeta,
        ),
      );
    }
    if (data.containsKey('exchange_rate_from_currency_code')) {
      context.handle(
        _exchangeRateFromCurrencyCodeMeta,
        exchangeRateFromCurrencyCode.isAcceptableOrUnknown(
          data['exchange_rate_from_currency_code']!,
          _exchangeRateFromCurrencyCodeMeta,
        ),
      );
    }
    if (data.containsKey('exchange_rate_to_currency_code')) {
      context.handle(
        _exchangeRateToCurrencyCodeMeta,
        exchangeRateToCurrencyCode.isAcceptableOrUnknown(
          data['exchange_rate_to_currency_code']!,
          _exchangeRateToCurrencyCodeMeta,
        ),
      );
    }
    if (data.containsKey('exchange_rate')) {
      context.handle(
        _exchangeRateMeta,
        exchangeRate.isAcceptableOrUnknown(
          data['exchange_rate']!,
          _exchangeRateMeta,
        ),
      );
    }
    if (data.containsKey('exchange_rate_as_of')) {
      context.handle(
        _exchangeRateAsOfMeta,
        exchangeRateAsOf.isAcceptableOrUnknown(
          data['exchange_rate_as_of']!,
          _exchangeRateAsOfMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('transaction_date')) {
      context.handle(
        _transactionDateMeta,
        transactionDate.isAcceptableOrUnknown(
          data['transaction_date']!,
          _transactionDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionDateMeta);
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('attachment_count')) {
      context.handle(
        _attachmentCountMeta,
        attachmentCount.isAcceptableOrUnknown(
          data['attachment_count']!,
          _attachmentCountMeta,
        ),
      );
    }
    if (data.containsKey('ai_confidence')) {
      context.handle(
        _aiConfidenceMeta,
        aiConfidence.isAcceptableOrUnknown(
          data['ai_confidence']!,
          _aiConfidenceMeta,
        ),
      );
    }
    if (data.containsKey('needs_review')) {
      context.handle(
        _needsReviewMeta,
        needsReview.isAcceptableOrUnknown(
          data['needs_review']!,
          _needsReviewMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
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
  TransactionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransactionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_scope_id'],
      ),
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      payeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payee_id'],
      ),
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}amount'],
      )!,
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      paymentMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_method'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      incomeSourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}income_source_type'],
      ),
      transferGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transfer_group_id'],
      ),
      transferPayloadFingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transfer_payload_fingerprint'],
      ),
      exchangeRateFromCurrencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exchange_rate_from_currency_code'],
      ),
      exchangeRateToCurrencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exchange_rate_to_currency_code'],
      ),
      exchangeRate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exchange_rate'],
      ),
      exchangeRateAsOf: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}exchange_rate_as_of'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      transactionDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}transaction_date'],
      )!,
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      ),
      attachmentCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attachment_count'],
      )!,
      aiConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ai_confidence'],
      ),
      needsReview: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}needs_review'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }
}

class TransactionRow extends DataClass implements Insertable<TransactionRow> {
  final String id;
  final String? ownerScopeId;
  final String accountId;
  final String categoryId;
  final String? payeeId;
  final String amount;
  final String currencyCode;
  final String type;
  final String paymentMethod;
  final String source;
  final String status;
  final String? incomeSourceType;
  final String? transferGroupId;

  /// SHA-256 of the canonical owner-scoped transfer creation intent. New
  /// transfer pairs store the same value on both legs so the committed pair
  /// is also the durable idempotency record. Null is reserved for legacy rows.
  final String? transferPayloadFingerprint;
  final String? exchangeRateFromCurrencyCode;
  final String? exchangeRateToCurrencyCode;
  final String? exchangeRate;
  final DateTime? exchangeRateAsOf;
  final String? note;
  final DateTime transactionDate;
  final String? location;
  final int attachmentCount;
  final int? aiConfidence;
  final bool needsReview;
  final DateTime createdAt;
  final DateTime updatedAt;
  const TransactionRow({
    required this.id,
    this.ownerScopeId,
    required this.accountId,
    required this.categoryId,
    this.payeeId,
    required this.amount,
    required this.currencyCode,
    required this.type,
    required this.paymentMethod,
    required this.source,
    required this.status,
    this.incomeSourceType,
    this.transferGroupId,
    this.transferPayloadFingerprint,
    this.exchangeRateFromCurrencyCode,
    this.exchangeRateToCurrencyCode,
    this.exchangeRate,
    this.exchangeRateAsOf,
    this.note,
    required this.transactionDate,
    this.location,
    required this.attachmentCount,
    this.aiConfidence,
    required this.needsReview,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || ownerScopeId != null) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId);
    }
    map['account_id'] = Variable<String>(accountId);
    map['category_id'] = Variable<String>(categoryId);
    if (!nullToAbsent || payeeId != null) {
      map['payee_id'] = Variable<String>(payeeId);
    }
    map['amount'] = Variable<String>(amount);
    map['currency_code'] = Variable<String>(currencyCode);
    map['type'] = Variable<String>(type);
    map['payment_method'] = Variable<String>(paymentMethod);
    map['source'] = Variable<String>(source);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || incomeSourceType != null) {
      map['income_source_type'] = Variable<String>(incomeSourceType);
    }
    if (!nullToAbsent || transferGroupId != null) {
      map['transfer_group_id'] = Variable<String>(transferGroupId);
    }
    if (!nullToAbsent || transferPayloadFingerprint != null) {
      map['transfer_payload_fingerprint'] = Variable<String>(
        transferPayloadFingerprint,
      );
    }
    if (!nullToAbsent || exchangeRateFromCurrencyCode != null) {
      map['exchange_rate_from_currency_code'] = Variable<String>(
        exchangeRateFromCurrencyCode,
      );
    }
    if (!nullToAbsent || exchangeRateToCurrencyCode != null) {
      map['exchange_rate_to_currency_code'] = Variable<String>(
        exchangeRateToCurrencyCode,
      );
    }
    if (!nullToAbsent || exchangeRate != null) {
      map['exchange_rate'] = Variable<String>(exchangeRate);
    }
    if (!nullToAbsent || exchangeRateAsOf != null) {
      map['exchange_rate_as_of'] = Variable<DateTime>(exchangeRateAsOf);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['transaction_date'] = Variable<DateTime>(transactionDate);
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    map['attachment_count'] = Variable<int>(attachmentCount);
    if (!nullToAbsent || aiConfidence != null) {
      map['ai_confidence'] = Variable<int>(aiConfidence);
    }
    map['needs_review'] = Variable<bool>(needsReview);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      ownerScopeId: ownerScopeId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerScopeId),
      accountId: Value(accountId),
      categoryId: Value(categoryId),
      payeeId: payeeId == null && nullToAbsent
          ? const Value.absent()
          : Value(payeeId),
      amount: Value(amount),
      currencyCode: Value(currencyCode),
      type: Value(type),
      paymentMethod: Value(paymentMethod),
      source: Value(source),
      status: Value(status),
      incomeSourceType: incomeSourceType == null && nullToAbsent
          ? const Value.absent()
          : Value(incomeSourceType),
      transferGroupId: transferGroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(transferGroupId),
      transferPayloadFingerprint:
          transferPayloadFingerprint == null && nullToAbsent
          ? const Value.absent()
          : Value(transferPayloadFingerprint),
      exchangeRateFromCurrencyCode:
          exchangeRateFromCurrencyCode == null && nullToAbsent
          ? const Value.absent()
          : Value(exchangeRateFromCurrencyCode),
      exchangeRateToCurrencyCode:
          exchangeRateToCurrencyCode == null && nullToAbsent
          ? const Value.absent()
          : Value(exchangeRateToCurrencyCode),
      exchangeRate: exchangeRate == null && nullToAbsent
          ? const Value.absent()
          : Value(exchangeRate),
      exchangeRateAsOf: exchangeRateAsOf == null && nullToAbsent
          ? const Value.absent()
          : Value(exchangeRateAsOf),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      transactionDate: Value(transactionDate),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      attachmentCount: Value(attachmentCount),
      aiConfidence: aiConfidence == null && nullToAbsent
          ? const Value.absent()
          : Value(aiConfidence),
      needsReview: Value(needsReview),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TransactionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransactionRow(
      id: serializer.fromJson<String>(json['id']),
      ownerScopeId: serializer.fromJson<String?>(json['ownerScopeId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      payeeId: serializer.fromJson<String?>(json['payeeId']),
      amount: serializer.fromJson<String>(json['amount']),
      currencyCode: serializer.fromJson<String>(json['currencyCode']),
      type: serializer.fromJson<String>(json['type']),
      paymentMethod: serializer.fromJson<String>(json['paymentMethod']),
      source: serializer.fromJson<String>(json['source']),
      status: serializer.fromJson<String>(json['status']),
      incomeSourceType: serializer.fromJson<String?>(json['incomeSourceType']),
      transferGroupId: serializer.fromJson<String?>(json['transferGroupId']),
      transferPayloadFingerprint: serializer.fromJson<String?>(
        json['transferPayloadFingerprint'],
      ),
      exchangeRateFromCurrencyCode: serializer.fromJson<String?>(
        json['exchangeRateFromCurrencyCode'],
      ),
      exchangeRateToCurrencyCode: serializer.fromJson<String?>(
        json['exchangeRateToCurrencyCode'],
      ),
      exchangeRate: serializer.fromJson<String?>(json['exchangeRate']),
      exchangeRateAsOf: serializer.fromJson<DateTime?>(
        json['exchangeRateAsOf'],
      ),
      note: serializer.fromJson<String?>(json['note']),
      transactionDate: serializer.fromJson<DateTime>(json['transactionDate']),
      location: serializer.fromJson<String?>(json['location']),
      attachmentCount: serializer.fromJson<int>(json['attachmentCount']),
      aiConfidence: serializer.fromJson<int?>(json['aiConfidence']),
      needsReview: serializer.fromJson<bool>(json['needsReview']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerScopeId': serializer.toJson<String?>(ownerScopeId),
      'accountId': serializer.toJson<String>(accountId),
      'categoryId': serializer.toJson<String>(categoryId),
      'payeeId': serializer.toJson<String?>(payeeId),
      'amount': serializer.toJson<String>(amount),
      'currencyCode': serializer.toJson<String>(currencyCode),
      'type': serializer.toJson<String>(type),
      'paymentMethod': serializer.toJson<String>(paymentMethod),
      'source': serializer.toJson<String>(source),
      'status': serializer.toJson<String>(status),
      'incomeSourceType': serializer.toJson<String?>(incomeSourceType),
      'transferGroupId': serializer.toJson<String?>(transferGroupId),
      'transferPayloadFingerprint': serializer.toJson<String?>(
        transferPayloadFingerprint,
      ),
      'exchangeRateFromCurrencyCode': serializer.toJson<String?>(
        exchangeRateFromCurrencyCode,
      ),
      'exchangeRateToCurrencyCode': serializer.toJson<String?>(
        exchangeRateToCurrencyCode,
      ),
      'exchangeRate': serializer.toJson<String?>(exchangeRate),
      'exchangeRateAsOf': serializer.toJson<DateTime?>(exchangeRateAsOf),
      'note': serializer.toJson<String?>(note),
      'transactionDate': serializer.toJson<DateTime>(transactionDate),
      'location': serializer.toJson<String?>(location),
      'attachmentCount': serializer.toJson<int>(attachmentCount),
      'aiConfidence': serializer.toJson<int?>(aiConfidence),
      'needsReview': serializer.toJson<bool>(needsReview),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TransactionRow copyWith({
    String? id,
    Value<String?> ownerScopeId = const Value.absent(),
    String? accountId,
    String? categoryId,
    Value<String?> payeeId = const Value.absent(),
    String? amount,
    String? currencyCode,
    String? type,
    String? paymentMethod,
    String? source,
    String? status,
    Value<String?> incomeSourceType = const Value.absent(),
    Value<String?> transferGroupId = const Value.absent(),
    Value<String?> transferPayloadFingerprint = const Value.absent(),
    Value<String?> exchangeRateFromCurrencyCode = const Value.absent(),
    Value<String?> exchangeRateToCurrencyCode = const Value.absent(),
    Value<String?> exchangeRate = const Value.absent(),
    Value<DateTime?> exchangeRateAsOf = const Value.absent(),
    Value<String?> note = const Value.absent(),
    DateTime? transactionDate,
    Value<String?> location = const Value.absent(),
    int? attachmentCount,
    Value<int?> aiConfidence = const Value.absent(),
    bool? needsReview,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TransactionRow(
    id: id ?? this.id,
    ownerScopeId: ownerScopeId.present ? ownerScopeId.value : this.ownerScopeId,
    accountId: accountId ?? this.accountId,
    categoryId: categoryId ?? this.categoryId,
    payeeId: payeeId.present ? payeeId.value : this.payeeId,
    amount: amount ?? this.amount,
    currencyCode: currencyCode ?? this.currencyCode,
    type: type ?? this.type,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    source: source ?? this.source,
    status: status ?? this.status,
    incomeSourceType: incomeSourceType.present
        ? incomeSourceType.value
        : this.incomeSourceType,
    transferGroupId: transferGroupId.present
        ? transferGroupId.value
        : this.transferGroupId,
    transferPayloadFingerprint: transferPayloadFingerprint.present
        ? transferPayloadFingerprint.value
        : this.transferPayloadFingerprint,
    exchangeRateFromCurrencyCode: exchangeRateFromCurrencyCode.present
        ? exchangeRateFromCurrencyCode.value
        : this.exchangeRateFromCurrencyCode,
    exchangeRateToCurrencyCode: exchangeRateToCurrencyCode.present
        ? exchangeRateToCurrencyCode.value
        : this.exchangeRateToCurrencyCode,
    exchangeRate: exchangeRate.present ? exchangeRate.value : this.exchangeRate,
    exchangeRateAsOf: exchangeRateAsOf.present
        ? exchangeRateAsOf.value
        : this.exchangeRateAsOf,
    note: note.present ? note.value : this.note,
    transactionDate: transactionDate ?? this.transactionDate,
    location: location.present ? location.value : this.location,
    attachmentCount: attachmentCount ?? this.attachmentCount,
    aiConfidence: aiConfidence.present ? aiConfidence.value : this.aiConfidence,
    needsReview: needsReview ?? this.needsReview,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TransactionRow copyWithCompanion(TransactionsCompanion data) {
    return TransactionRow(
      id: data.id.present ? data.id.value : this.id,
      ownerScopeId: data.ownerScopeId.present
          ? data.ownerScopeId.value
          : this.ownerScopeId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      payeeId: data.payeeId.present ? data.payeeId.value : this.payeeId,
      amount: data.amount.present ? data.amount.value : this.amount,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      type: data.type.present ? data.type.value : this.type,
      paymentMethod: data.paymentMethod.present
          ? data.paymentMethod.value
          : this.paymentMethod,
      source: data.source.present ? data.source.value : this.source,
      status: data.status.present ? data.status.value : this.status,
      incomeSourceType: data.incomeSourceType.present
          ? data.incomeSourceType.value
          : this.incomeSourceType,
      transferGroupId: data.transferGroupId.present
          ? data.transferGroupId.value
          : this.transferGroupId,
      transferPayloadFingerprint: data.transferPayloadFingerprint.present
          ? data.transferPayloadFingerprint.value
          : this.transferPayloadFingerprint,
      exchangeRateFromCurrencyCode: data.exchangeRateFromCurrencyCode.present
          ? data.exchangeRateFromCurrencyCode.value
          : this.exchangeRateFromCurrencyCode,
      exchangeRateToCurrencyCode: data.exchangeRateToCurrencyCode.present
          ? data.exchangeRateToCurrencyCode.value
          : this.exchangeRateToCurrencyCode,
      exchangeRate: data.exchangeRate.present
          ? data.exchangeRate.value
          : this.exchangeRate,
      exchangeRateAsOf: data.exchangeRateAsOf.present
          ? data.exchangeRateAsOf.value
          : this.exchangeRateAsOf,
      note: data.note.present ? data.note.value : this.note,
      transactionDate: data.transactionDate.present
          ? data.transactionDate.value
          : this.transactionDate,
      location: data.location.present ? data.location.value : this.location,
      attachmentCount: data.attachmentCount.present
          ? data.attachmentCount.value
          : this.attachmentCount,
      aiConfidence: data.aiConfidence.present
          ? data.aiConfidence.value
          : this.aiConfidence,
      needsReview: data.needsReview.present
          ? data.needsReview.value
          : this.needsReview,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransactionRow(')
          ..write('id: $id, ')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('accountId: $accountId, ')
          ..write('categoryId: $categoryId, ')
          ..write('payeeId: $payeeId, ')
          ..write('amount: $amount, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('type: $type, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('source: $source, ')
          ..write('status: $status, ')
          ..write('incomeSourceType: $incomeSourceType, ')
          ..write('transferGroupId: $transferGroupId, ')
          ..write('transferPayloadFingerprint: $transferPayloadFingerprint, ')
          ..write(
            'exchangeRateFromCurrencyCode: $exchangeRateFromCurrencyCode, ',
          )
          ..write('exchangeRateToCurrencyCode: $exchangeRateToCurrencyCode, ')
          ..write('exchangeRate: $exchangeRate, ')
          ..write('exchangeRateAsOf: $exchangeRateAsOf, ')
          ..write('note: $note, ')
          ..write('transactionDate: $transactionDate, ')
          ..write('location: $location, ')
          ..write('attachmentCount: $attachmentCount, ')
          ..write('aiConfidence: $aiConfidence, ')
          ..write('needsReview: $needsReview, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    ownerScopeId,
    accountId,
    categoryId,
    payeeId,
    amount,
    currencyCode,
    type,
    paymentMethod,
    source,
    status,
    incomeSourceType,
    transferGroupId,
    transferPayloadFingerprint,
    exchangeRateFromCurrencyCode,
    exchangeRateToCurrencyCode,
    exchangeRate,
    exchangeRateAsOf,
    note,
    transactionDate,
    location,
    attachmentCount,
    aiConfidence,
    needsReview,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionRow &&
          other.id == this.id &&
          other.ownerScopeId == this.ownerScopeId &&
          other.accountId == this.accountId &&
          other.categoryId == this.categoryId &&
          other.payeeId == this.payeeId &&
          other.amount == this.amount &&
          other.currencyCode == this.currencyCode &&
          other.type == this.type &&
          other.paymentMethod == this.paymentMethod &&
          other.source == this.source &&
          other.status == this.status &&
          other.incomeSourceType == this.incomeSourceType &&
          other.transferGroupId == this.transferGroupId &&
          other.transferPayloadFingerprint == this.transferPayloadFingerprint &&
          other.exchangeRateFromCurrencyCode ==
              this.exchangeRateFromCurrencyCode &&
          other.exchangeRateToCurrencyCode == this.exchangeRateToCurrencyCode &&
          other.exchangeRate == this.exchangeRate &&
          other.exchangeRateAsOf == this.exchangeRateAsOf &&
          other.note == this.note &&
          other.transactionDate == this.transactionDate &&
          other.location == this.location &&
          other.attachmentCount == this.attachmentCount &&
          other.aiConfidence == this.aiConfidence &&
          other.needsReview == this.needsReview &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TransactionsCompanion extends UpdateCompanion<TransactionRow> {
  final Value<String> id;
  final Value<String?> ownerScopeId;
  final Value<String> accountId;
  final Value<String> categoryId;
  final Value<String?> payeeId;
  final Value<String> amount;
  final Value<String> currencyCode;
  final Value<String> type;
  final Value<String> paymentMethod;
  final Value<String> source;
  final Value<String> status;
  final Value<String?> incomeSourceType;
  final Value<String?> transferGroupId;
  final Value<String?> transferPayloadFingerprint;
  final Value<String?> exchangeRateFromCurrencyCode;
  final Value<String?> exchangeRateToCurrencyCode;
  final Value<String?> exchangeRate;
  final Value<DateTime?> exchangeRateAsOf;
  final Value<String?> note;
  final Value<DateTime> transactionDate;
  final Value<String?> location;
  final Value<int> attachmentCount;
  final Value<int?> aiConfidence;
  final Value<bool> needsReview;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.ownerScopeId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.payeeId = const Value.absent(),
    this.amount = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.type = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.source = const Value.absent(),
    this.status = const Value.absent(),
    this.incomeSourceType = const Value.absent(),
    this.transferGroupId = const Value.absent(),
    this.transferPayloadFingerprint = const Value.absent(),
    this.exchangeRateFromCurrencyCode = const Value.absent(),
    this.exchangeRateToCurrencyCode = const Value.absent(),
    this.exchangeRate = const Value.absent(),
    this.exchangeRateAsOf = const Value.absent(),
    this.note = const Value.absent(),
    this.transactionDate = const Value.absent(),
    this.location = const Value.absent(),
    this.attachmentCount = const Value.absent(),
    this.aiConfidence = const Value.absent(),
    this.needsReview = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionsCompanion.insert({
    required String id,
    this.ownerScopeId = const Value.absent(),
    required String accountId,
    required String categoryId,
    this.payeeId = const Value.absent(),
    required String amount,
    required String currencyCode,
    required String type,
    required String paymentMethod,
    required String source,
    required String status,
    this.incomeSourceType = const Value.absent(),
    this.transferGroupId = const Value.absent(),
    this.transferPayloadFingerprint = const Value.absent(),
    this.exchangeRateFromCurrencyCode = const Value.absent(),
    this.exchangeRateToCurrencyCode = const Value.absent(),
    this.exchangeRate = const Value.absent(),
    this.exchangeRateAsOf = const Value.absent(),
    this.note = const Value.absent(),
    required DateTime transactionDate,
    this.location = const Value.absent(),
    this.attachmentCount = const Value.absent(),
    this.aiConfidence = const Value.absent(),
    this.needsReview = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       categoryId = Value(categoryId),
       amount = Value(amount),
       currencyCode = Value(currencyCode),
       type = Value(type),
       paymentMethod = Value(paymentMethod),
       source = Value(source),
       status = Value(status),
       transactionDate = Value(transactionDate),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TransactionRow> custom({
    Expression<String>? id,
    Expression<String>? ownerScopeId,
    Expression<String>? accountId,
    Expression<String>? categoryId,
    Expression<String>? payeeId,
    Expression<String>? amount,
    Expression<String>? currencyCode,
    Expression<String>? type,
    Expression<String>? paymentMethod,
    Expression<String>? source,
    Expression<String>? status,
    Expression<String>? incomeSourceType,
    Expression<String>? transferGroupId,
    Expression<String>? transferPayloadFingerprint,
    Expression<String>? exchangeRateFromCurrencyCode,
    Expression<String>? exchangeRateToCurrencyCode,
    Expression<String>? exchangeRate,
    Expression<DateTime>? exchangeRateAsOf,
    Expression<String>? note,
    Expression<DateTime>? transactionDate,
    Expression<String>? location,
    Expression<int>? attachmentCount,
    Expression<int>? aiConfidence,
    Expression<bool>? needsReview,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerScopeId != null) 'owner_scope_id': ownerScopeId,
      if (accountId != null) 'account_id': accountId,
      if (categoryId != null) 'category_id': categoryId,
      if (payeeId != null) 'payee_id': payeeId,
      if (amount != null) 'amount': amount,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (type != null) 'type': type,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (source != null) 'source': source,
      if (status != null) 'status': status,
      if (incomeSourceType != null) 'income_source_type': incomeSourceType,
      if (transferGroupId != null) 'transfer_group_id': transferGroupId,
      if (transferPayloadFingerprint != null)
        'transfer_payload_fingerprint': transferPayloadFingerprint,
      if (exchangeRateFromCurrencyCode != null)
        'exchange_rate_from_currency_code': exchangeRateFromCurrencyCode,
      if (exchangeRateToCurrencyCode != null)
        'exchange_rate_to_currency_code': exchangeRateToCurrencyCode,
      if (exchangeRate != null) 'exchange_rate': exchangeRate,
      if (exchangeRateAsOf != null) 'exchange_rate_as_of': exchangeRateAsOf,
      if (note != null) 'note': note,
      if (transactionDate != null) 'transaction_date': transactionDate,
      if (location != null) 'location': location,
      if (attachmentCount != null) 'attachment_count': attachmentCount,
      if (aiConfidence != null) 'ai_confidence': aiConfidence,
      if (needsReview != null) 'needs_review': needsReview,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionsCompanion copyWith({
    Value<String>? id,
    Value<String?>? ownerScopeId,
    Value<String>? accountId,
    Value<String>? categoryId,
    Value<String?>? payeeId,
    Value<String>? amount,
    Value<String>? currencyCode,
    Value<String>? type,
    Value<String>? paymentMethod,
    Value<String>? source,
    Value<String>? status,
    Value<String?>? incomeSourceType,
    Value<String?>? transferGroupId,
    Value<String?>? transferPayloadFingerprint,
    Value<String?>? exchangeRateFromCurrencyCode,
    Value<String?>? exchangeRateToCurrencyCode,
    Value<String?>? exchangeRate,
    Value<DateTime?>? exchangeRateAsOf,
    Value<String?>? note,
    Value<DateTime>? transactionDate,
    Value<String?>? location,
    Value<int>? attachmentCount,
    Value<int?>? aiConfidence,
    Value<bool>? needsReview,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TransactionsCompanion(
      id: id ?? this.id,
      ownerScopeId: ownerScopeId ?? this.ownerScopeId,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      payeeId: payeeId ?? this.payeeId,
      amount: amount ?? this.amount,
      currencyCode: currencyCode ?? this.currencyCode,
      type: type ?? this.type,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      source: source ?? this.source,
      status: status ?? this.status,
      incomeSourceType: incomeSourceType ?? this.incomeSourceType,
      transferGroupId: transferGroupId ?? this.transferGroupId,
      transferPayloadFingerprint:
          transferPayloadFingerprint ?? this.transferPayloadFingerprint,
      exchangeRateFromCurrencyCode:
          exchangeRateFromCurrencyCode ?? this.exchangeRateFromCurrencyCode,
      exchangeRateToCurrencyCode:
          exchangeRateToCurrencyCode ?? this.exchangeRateToCurrencyCode,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      exchangeRateAsOf: exchangeRateAsOf ?? this.exchangeRateAsOf,
      note: note ?? this.note,
      transactionDate: transactionDate ?? this.transactionDate,
      location: location ?? this.location,
      attachmentCount: attachmentCount ?? this.attachmentCount,
      aiConfidence: aiConfidence ?? this.aiConfidence,
      needsReview: needsReview ?? this.needsReview,
      createdAt: createdAt ?? this.createdAt,
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
    if (ownerScopeId.present) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (payeeId.present) {
      map['payee_id'] = Variable<String>(payeeId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<String>(amount.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (paymentMethod.present) {
      map['payment_method'] = Variable<String>(paymentMethod.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (incomeSourceType.present) {
      map['income_source_type'] = Variable<String>(incomeSourceType.value);
    }
    if (transferGroupId.present) {
      map['transfer_group_id'] = Variable<String>(transferGroupId.value);
    }
    if (transferPayloadFingerprint.present) {
      map['transfer_payload_fingerprint'] = Variable<String>(
        transferPayloadFingerprint.value,
      );
    }
    if (exchangeRateFromCurrencyCode.present) {
      map['exchange_rate_from_currency_code'] = Variable<String>(
        exchangeRateFromCurrencyCode.value,
      );
    }
    if (exchangeRateToCurrencyCode.present) {
      map['exchange_rate_to_currency_code'] = Variable<String>(
        exchangeRateToCurrencyCode.value,
      );
    }
    if (exchangeRate.present) {
      map['exchange_rate'] = Variable<String>(exchangeRate.value);
    }
    if (exchangeRateAsOf.present) {
      map['exchange_rate_as_of'] = Variable<DateTime>(exchangeRateAsOf.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (transactionDate.present) {
      map['transaction_date'] = Variable<DateTime>(transactionDate.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (attachmentCount.present) {
      map['attachment_count'] = Variable<int>(attachmentCount.value);
    }
    if (aiConfidence.present) {
      map['ai_confidence'] = Variable<int>(aiConfidence.value);
    }
    if (needsReview.present) {
      map['needs_review'] = Variable<bool>(needsReview.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('accountId: $accountId, ')
          ..write('categoryId: $categoryId, ')
          ..write('payeeId: $payeeId, ')
          ..write('amount: $amount, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('type: $type, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('source: $source, ')
          ..write('status: $status, ')
          ..write('incomeSourceType: $incomeSourceType, ')
          ..write('transferGroupId: $transferGroupId, ')
          ..write('transferPayloadFingerprint: $transferPayloadFingerprint, ')
          ..write(
            'exchangeRateFromCurrencyCode: $exchangeRateFromCurrencyCode, ',
          )
          ..write('exchangeRateToCurrencyCode: $exchangeRateToCurrencyCode, ')
          ..write('exchangeRate: $exchangeRate, ')
          ..write('exchangeRateAsOf: $exchangeRateAsOf, ')
          ..write('note: $note, ')
          ..write('transactionDate: $transactionDate, ')
          ..write('location: $location, ')
          ..write('attachmentCount: $attachmentCount, ')
          ..write('aiConfidence: $aiConfidence, ')
          ..write('needsReview: $needsReview, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExchangeRatesTable extends ExchangeRates
    with TableInfo<$ExchangeRatesTable, ExchangeRateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExchangeRatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerScopeIdMeta = const VerificationMeta(
    'ownerScopeId',
  );
  @override
  late final GeneratedColumn<String> ownerScopeId = GeneratedColumn<String>(
    'owner_scope_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _baseCurrencyMeta = const VerificationMeta(
    'baseCurrency',
  );
  @override
  late final GeneratedColumn<String> baseCurrency = GeneratedColumn<String>(
    'base_currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quoteCurrencyMeta = const VerificationMeta(
    'quoteCurrency',
  );
  @override
  late final GeneratedColumn<String> quoteCurrency = GeneratedColumn<String>(
    'quote_currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rateMeta = const VerificationMeta('rate');
  @override
  late final GeneratedColumn<String> rate = GeneratedColumn<String>(
    'rate',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerScopeId,
    baseCurrency,
    quoteCurrency,
    rate,
    source,
    fetchedAt,
    createdAt,
    updatedAt,
    archivedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exchange_rates';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExchangeRateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_scope_id')) {
      context.handle(
        _ownerScopeIdMeta,
        ownerScopeId.isAcceptableOrUnknown(
          data['owner_scope_id']!,
          _ownerScopeIdMeta,
        ),
      );
    }
    if (data.containsKey('base_currency')) {
      context.handle(
        _baseCurrencyMeta,
        baseCurrency.isAcceptableOrUnknown(
          data['base_currency']!,
          _baseCurrencyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_baseCurrencyMeta);
    }
    if (data.containsKey('quote_currency')) {
      context.handle(
        _quoteCurrencyMeta,
        quoteCurrency.isAcceptableOrUnknown(
          data['quote_currency']!,
          _quoteCurrencyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_quoteCurrencyMeta);
    }
    if (data.containsKey('rate')) {
      context.handle(
        _rateMeta,
        rate.isAcceptableOrUnknown(data['rate']!, _rateMeta),
      );
    } else if (isInserting) {
      context.missing(_rateMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExchangeRateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExchangeRateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_scope_id'],
      ),
      baseCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_currency'],
      )!,
      quoteCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quote_currency'],
      )!,
      rate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rate'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
    );
  }

  @override
  $ExchangeRatesTable createAlias(String alias) {
    return $ExchangeRatesTable(attachedDatabase, alias);
  }
}

class ExchangeRateRow extends DataClass implements Insertable<ExchangeRateRow> {
  final String id;
  final String? ownerScopeId;
  final String baseCurrency;
  final String quoteCurrency;
  final String rate;
  final String source;
  final DateTime fetchedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  const ExchangeRateRow({
    required this.id,
    this.ownerScopeId,
    required this.baseCurrency,
    required this.quoteCurrency,
    required this.rate,
    required this.source,
    required this.fetchedAt,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || ownerScopeId != null) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId);
    }
    map['base_currency'] = Variable<String>(baseCurrency);
    map['quote_currency'] = Variable<String>(quoteCurrency);
    map['rate'] = Variable<String>(rate);
    map['source'] = Variable<String>(source);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    return map;
  }

  ExchangeRatesCompanion toCompanion(bool nullToAbsent) {
    return ExchangeRatesCompanion(
      id: Value(id),
      ownerScopeId: ownerScopeId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerScopeId),
      baseCurrency: Value(baseCurrency),
      quoteCurrency: Value(quoteCurrency),
      rate: Value(rate),
      source: Value(source),
      fetchedAt: Value(fetchedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
    );
  }

  factory ExchangeRateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExchangeRateRow(
      id: serializer.fromJson<String>(json['id']),
      ownerScopeId: serializer.fromJson<String?>(json['ownerScopeId']),
      baseCurrency: serializer.fromJson<String>(json['baseCurrency']),
      quoteCurrency: serializer.fromJson<String>(json['quoteCurrency']),
      rate: serializer.fromJson<String>(json['rate']),
      source: serializer.fromJson<String>(json['source']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerScopeId': serializer.toJson<String?>(ownerScopeId),
      'baseCurrency': serializer.toJson<String>(baseCurrency),
      'quoteCurrency': serializer.toJson<String>(quoteCurrency),
      'rate': serializer.toJson<String>(rate),
      'source': serializer.toJson<String>(source),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
    };
  }

  ExchangeRateRow copyWith({
    String? id,
    Value<String?> ownerScopeId = const Value.absent(),
    String? baseCurrency,
    String? quoteCurrency,
    String? rate,
    String? source,
    DateTime? fetchedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> archivedAt = const Value.absent(),
  }) => ExchangeRateRow(
    id: id ?? this.id,
    ownerScopeId: ownerScopeId.present ? ownerScopeId.value : this.ownerScopeId,
    baseCurrency: baseCurrency ?? this.baseCurrency,
    quoteCurrency: quoteCurrency ?? this.quoteCurrency,
    rate: rate ?? this.rate,
    source: source ?? this.source,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
  );
  ExchangeRateRow copyWithCompanion(ExchangeRatesCompanion data) {
    return ExchangeRateRow(
      id: data.id.present ? data.id.value : this.id,
      ownerScopeId: data.ownerScopeId.present
          ? data.ownerScopeId.value
          : this.ownerScopeId,
      baseCurrency: data.baseCurrency.present
          ? data.baseCurrency.value
          : this.baseCurrency,
      quoteCurrency: data.quoteCurrency.present
          ? data.quoteCurrency.value
          : this.quoteCurrency,
      rate: data.rate.present ? data.rate.value : this.rate,
      source: data.source.present ? data.source.value : this.source,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExchangeRateRow(')
          ..write('id: $id, ')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('baseCurrency: $baseCurrency, ')
          ..write('quoteCurrency: $quoteCurrency, ')
          ..write('rate: $rate, ')
          ..write('source: $source, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('archivedAt: $archivedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerScopeId,
    baseCurrency,
    quoteCurrency,
    rate,
    source,
    fetchedAt,
    createdAt,
    updatedAt,
    archivedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExchangeRateRow &&
          other.id == this.id &&
          other.ownerScopeId == this.ownerScopeId &&
          other.baseCurrency == this.baseCurrency &&
          other.quoteCurrency == this.quoteCurrency &&
          other.rate == this.rate &&
          other.source == this.source &&
          other.fetchedAt == this.fetchedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.archivedAt == this.archivedAt);
}

class ExchangeRatesCompanion extends UpdateCompanion<ExchangeRateRow> {
  final Value<String> id;
  final Value<String?> ownerScopeId;
  final Value<String> baseCurrency;
  final Value<String> quoteCurrency;
  final Value<String> rate;
  final Value<String> source;
  final Value<DateTime> fetchedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> archivedAt;
  final Value<int> rowid;
  const ExchangeRatesCompanion({
    this.id = const Value.absent(),
    this.ownerScopeId = const Value.absent(),
    this.baseCurrency = const Value.absent(),
    this.quoteCurrency = const Value.absent(),
    this.rate = const Value.absent(),
    this.source = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExchangeRatesCompanion.insert({
    required String id,
    this.ownerScopeId = const Value.absent(),
    required String baseCurrency,
    required String quoteCurrency,
    required String rate,
    required String source,
    required DateTime fetchedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       baseCurrency = Value(baseCurrency),
       quoteCurrency = Value(quoteCurrency),
       rate = Value(rate),
       source = Value(source),
       fetchedAt = Value(fetchedAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ExchangeRateRow> custom({
    Expression<String>? id,
    Expression<String>? ownerScopeId,
    Expression<String>? baseCurrency,
    Expression<String>? quoteCurrency,
    Expression<String>? rate,
    Expression<String>? source,
    Expression<DateTime>? fetchedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? archivedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerScopeId != null) 'owner_scope_id': ownerScopeId,
      if (baseCurrency != null) 'base_currency': baseCurrency,
      if (quoteCurrency != null) 'quote_currency': quoteCurrency,
      if (rate != null) 'rate': rate,
      if (source != null) 'source': source,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExchangeRatesCompanion copyWith({
    Value<String>? id,
    Value<String?>? ownerScopeId,
    Value<String>? baseCurrency,
    Value<String>? quoteCurrency,
    Value<String>? rate,
    Value<String>? source,
    Value<DateTime>? fetchedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? archivedAt,
    Value<int>? rowid,
  }) {
    return ExchangeRatesCompanion(
      id: id ?? this.id,
      ownerScopeId: ownerScopeId ?? this.ownerScopeId,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      quoteCurrency: quoteCurrency ?? this.quoteCurrency,
      rate: rate ?? this.rate,
      source: source ?? this.source,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerScopeId.present) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId.value);
    }
    if (baseCurrency.present) {
      map['base_currency'] = Variable<String>(baseCurrency.value);
    }
    if (quoteCurrency.present) {
      map['quote_currency'] = Variable<String>(quoteCurrency.value);
    }
    if (rate.present) {
      map['rate'] = Variable<String>(rate.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExchangeRatesCompanion(')
          ..write('id: $id, ')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('baseCurrency: $baseCurrency, ')
          ..write('quoteCurrency: $quoteCurrency, ')
          ..write('rate: $rate, ')
          ..write('source: $source, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BudgetsTable extends Budgets with TableInfo<$BudgetsTable, BudgetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BudgetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerScopeIdMeta = const VerificationMeta(
    'ownerScopeId',
  );
  @override
  late final GeneratedColumn<String> ownerScopeId = GeneratedColumn<String>(
    'owner_scope_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<String> amount = GeneratedColumn<String>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _periodTypeMeta = const VerificationMeta(
    'periodType',
  );
  @override
  late final GeneratedColumn<String> periodType = GeneratedColumn<String>(
    'period_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _alertThresholdPercentMeta =
      const VerificationMeta('alertThresholdPercent');
  @override
  late final GeneratedColumn<int> alertThresholdPercent = GeneratedColumn<int>(
    'alert_threshold_percent',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerScopeId,
    name,
    categoryId,
    amount,
    currency,
    periodType,
    startDate,
    endDate,
    alertThresholdPercent,
    isActive,
    createdAt,
    updatedAt,
    archivedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'budgets';
  @override
  VerificationContext validateIntegrity(
    Insertable<BudgetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_scope_id')) {
      context.handle(
        _ownerScopeIdMeta,
        ownerScopeId.isAcceptableOrUnknown(
          data['owner_scope_id']!,
          _ownerScopeIdMeta,
        ),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('period_type')) {
      context.handle(
        _periodTypeMeta,
        periodType.isAcceptableOrUnknown(data['period_type']!, _periodTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_periodTypeMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    } else if (isInserting) {
      context.missing(_endDateMeta);
    }
    if (data.containsKey('alert_threshold_percent')) {
      context.handle(
        _alertThresholdPercentMeta,
        alertThresholdPercent.isAcceptableOrUnknown(
          data['alert_threshold_percent']!,
          _alertThresholdPercentMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_alertThresholdPercentMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BudgetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BudgetRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_scope_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}amount'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      periodType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period_type'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      )!,
      alertThresholdPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}alert_threshold_percent'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
    );
  }

  @override
  $BudgetsTable createAlias(String alias) {
    return $BudgetsTable(attachedDatabase, alias);
  }
}

class BudgetRow extends DataClass implements Insertable<BudgetRow> {
  final String id;
  final String? ownerScopeId;
  final String name;
  final String categoryId;
  final String amount;
  final String currency;
  final String periodType;
  final DateTime startDate;
  final DateTime endDate;
  final int alertThresholdPercent;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  const BudgetRow({
    required this.id,
    this.ownerScopeId,
    required this.name,
    required this.categoryId,
    required this.amount,
    required this.currency,
    required this.periodType,
    required this.startDate,
    required this.endDate,
    required this.alertThresholdPercent,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || ownerScopeId != null) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId);
    }
    map['name'] = Variable<String>(name);
    map['category_id'] = Variable<String>(categoryId);
    map['amount'] = Variable<String>(amount);
    map['currency'] = Variable<String>(currency);
    map['period_type'] = Variable<String>(periodType);
    map['start_date'] = Variable<DateTime>(startDate);
    map['end_date'] = Variable<DateTime>(endDate);
    map['alert_threshold_percent'] = Variable<int>(alertThresholdPercent);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    return map;
  }

  BudgetsCompanion toCompanion(bool nullToAbsent) {
    return BudgetsCompanion(
      id: Value(id),
      ownerScopeId: ownerScopeId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerScopeId),
      name: Value(name),
      categoryId: Value(categoryId),
      amount: Value(amount),
      currency: Value(currency),
      periodType: Value(periodType),
      startDate: Value(startDate),
      endDate: Value(endDate),
      alertThresholdPercent: Value(alertThresholdPercent),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
    );
  }

  factory BudgetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BudgetRow(
      id: serializer.fromJson<String>(json['id']),
      ownerScopeId: serializer.fromJson<String?>(json['ownerScopeId']),
      name: serializer.fromJson<String>(json['name']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      amount: serializer.fromJson<String>(json['amount']),
      currency: serializer.fromJson<String>(json['currency']),
      periodType: serializer.fromJson<String>(json['periodType']),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      endDate: serializer.fromJson<DateTime>(json['endDate']),
      alertThresholdPercent: serializer.fromJson<int>(
        json['alertThresholdPercent'],
      ),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerScopeId': serializer.toJson<String?>(ownerScopeId),
      'name': serializer.toJson<String>(name),
      'categoryId': serializer.toJson<String>(categoryId),
      'amount': serializer.toJson<String>(amount),
      'currency': serializer.toJson<String>(currency),
      'periodType': serializer.toJson<String>(periodType),
      'startDate': serializer.toJson<DateTime>(startDate),
      'endDate': serializer.toJson<DateTime>(endDate),
      'alertThresholdPercent': serializer.toJson<int>(alertThresholdPercent),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
    };
  }

  BudgetRow copyWith({
    String? id,
    Value<String?> ownerScopeId = const Value.absent(),
    String? name,
    String? categoryId,
    String? amount,
    String? currency,
    String? periodType,
    DateTime? startDate,
    DateTime? endDate,
    int? alertThresholdPercent,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> archivedAt = const Value.absent(),
  }) => BudgetRow(
    id: id ?? this.id,
    ownerScopeId: ownerScopeId.present ? ownerScopeId.value : this.ownerScopeId,
    name: name ?? this.name,
    categoryId: categoryId ?? this.categoryId,
    amount: amount ?? this.amount,
    currency: currency ?? this.currency,
    periodType: periodType ?? this.periodType,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    alertThresholdPercent: alertThresholdPercent ?? this.alertThresholdPercent,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
  );
  BudgetRow copyWithCompanion(BudgetsCompanion data) {
    return BudgetRow(
      id: data.id.present ? data.id.value : this.id,
      ownerScopeId: data.ownerScopeId.present
          ? data.ownerScopeId.value
          : this.ownerScopeId,
      name: data.name.present ? data.name.value : this.name,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      amount: data.amount.present ? data.amount.value : this.amount,
      currency: data.currency.present ? data.currency.value : this.currency,
      periodType: data.periodType.present
          ? data.periodType.value
          : this.periodType,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      alertThresholdPercent: data.alertThresholdPercent.present
          ? data.alertThresholdPercent.value
          : this.alertThresholdPercent,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BudgetRow(')
          ..write('id: $id, ')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('name: $name, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('periodType: $periodType, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('alertThresholdPercent: $alertThresholdPercent, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('archivedAt: $archivedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerScopeId,
    name,
    categoryId,
    amount,
    currency,
    periodType,
    startDate,
    endDate,
    alertThresholdPercent,
    isActive,
    createdAt,
    updatedAt,
    archivedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BudgetRow &&
          other.id == this.id &&
          other.ownerScopeId == this.ownerScopeId &&
          other.name == this.name &&
          other.categoryId == this.categoryId &&
          other.amount == this.amount &&
          other.currency == this.currency &&
          other.periodType == this.periodType &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.alertThresholdPercent == this.alertThresholdPercent &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.archivedAt == this.archivedAt);
}

class BudgetsCompanion extends UpdateCompanion<BudgetRow> {
  final Value<String> id;
  final Value<String?> ownerScopeId;
  final Value<String> name;
  final Value<String> categoryId;
  final Value<String> amount;
  final Value<String> currency;
  final Value<String> periodType;
  final Value<DateTime> startDate;
  final Value<DateTime> endDate;
  final Value<int> alertThresholdPercent;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> archivedAt;
  final Value<int> rowid;
  const BudgetsCompanion({
    this.id = const Value.absent(),
    this.ownerScopeId = const Value.absent(),
    this.name = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.amount = const Value.absent(),
    this.currency = const Value.absent(),
    this.periodType = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.alertThresholdPercent = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BudgetsCompanion.insert({
    required String id,
    this.ownerScopeId = const Value.absent(),
    required String name,
    required String categoryId,
    required String amount,
    required String currency,
    required String periodType,
    required DateTime startDate,
    required DateTime endDate,
    required int alertThresholdPercent,
    this.isActive = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       categoryId = Value(categoryId),
       amount = Value(amount),
       currency = Value(currency),
       periodType = Value(periodType),
       startDate = Value(startDate),
       endDate = Value(endDate),
       alertThresholdPercent = Value(alertThresholdPercent),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<BudgetRow> custom({
    Expression<String>? id,
    Expression<String>? ownerScopeId,
    Expression<String>? name,
    Expression<String>? categoryId,
    Expression<String>? amount,
    Expression<String>? currency,
    Expression<String>? periodType,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<int>? alertThresholdPercent,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? archivedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerScopeId != null) 'owner_scope_id': ownerScopeId,
      if (name != null) 'name': name,
      if (categoryId != null) 'category_id': categoryId,
      if (amount != null) 'amount': amount,
      if (currency != null) 'currency': currency,
      if (periodType != null) 'period_type': periodType,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (alertThresholdPercent != null)
        'alert_threshold_percent': alertThresholdPercent,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BudgetsCompanion copyWith({
    Value<String>? id,
    Value<String?>? ownerScopeId,
    Value<String>? name,
    Value<String>? categoryId,
    Value<String>? amount,
    Value<String>? currency,
    Value<String>? periodType,
    Value<DateTime>? startDate,
    Value<DateTime>? endDate,
    Value<int>? alertThresholdPercent,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? archivedAt,
    Value<int>? rowid,
  }) {
    return BudgetsCompanion(
      id: id ?? this.id,
      ownerScopeId: ownerScopeId ?? this.ownerScopeId,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      periodType: periodType ?? this.periodType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      alertThresholdPercent:
          alertThresholdPercent ?? this.alertThresholdPercent,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerScopeId.present) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<String>(amount.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (periodType.present) {
      map['period_type'] = Variable<String>(periodType.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (alertThresholdPercent.present) {
      map['alert_threshold_percent'] = Variable<int>(
        alertThresholdPercent.value,
      );
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BudgetsCompanion(')
          ..write('id: $id, ')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('name: $name, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('periodType: $periodType, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('alertThresholdPercent: $alertThresholdPercent, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GoalsTable extends Goals with TableInfo<$GoalsTable, GoalRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GoalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerScopeIdMeta = const VerificationMeta(
    'ownerScopeId',
  );
  @override
  late final GeneratedColumn<String> ownerScopeId = GeneratedColumn<String>(
    'owner_scope_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
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
  static const VerificationMeta _targetAmountMeta = const VerificationMeta(
    'targetAmount',
  );
  @override
  late final GeneratedColumn<String> targetAmount = GeneratedColumn<String>(
    'target_amount',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentAmountMeta = const VerificationMeta(
    'currentAmount',
  );
  @override
  late final GeneratedColumn<String> currentAmount = GeneratedColumn<String>(
    'current_amount',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _linkedAccountIdMeta = const VerificationMeta(
    'linkedAccountId',
  );
  @override
  late final GeneratedColumn<String> linkedAccountId = GeneratedColumn<String>(
    'linked_account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetDateMeta = const VerificationMeta(
    'targetDate',
  );
  @override
  late final GeneratedColumn<DateTime> targetDate = GeneratedColumn<DateTime>(
    'target_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerScopeId,
    title,
    description,
    type,
    targetAmount,
    currentAmount,
    currency,
    linkedAccountId,
    targetDate,
    icon,
    color,
    status,
    createdAt,
    updatedAt,
    archivedAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'goals';
  @override
  VerificationContext validateIntegrity(
    Insertable<GoalRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_scope_id')) {
      context.handle(
        _ownerScopeIdMeta,
        ownerScopeId.isAcceptableOrUnknown(
          data['owner_scope_id']!,
          _ownerScopeIdMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
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
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('target_amount')) {
      context.handle(
        _targetAmountMeta,
        targetAmount.isAcceptableOrUnknown(
          data['target_amount']!,
          _targetAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetAmountMeta);
    }
    if (data.containsKey('current_amount')) {
      context.handle(
        _currentAmountMeta,
        currentAmount.isAcceptableOrUnknown(
          data['current_amount']!,
          _currentAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currentAmountMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('linked_account_id')) {
      context.handle(
        _linkedAccountIdMeta,
        linkedAccountId.isAcceptableOrUnknown(
          data['linked_account_id']!,
          _linkedAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('target_date')) {
      context.handle(
        _targetDateMeta,
        targetDate.isAcceptableOrUnknown(data['target_date']!, _targetDateMeta),
      );
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    } else if (isInserting) {
      context.missing(_iconMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GoalRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GoalRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_scope_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      targetAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_amount'],
      )!,
      currentAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_amount'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      linkedAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linked_account_id'],
      ),
      targetDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}target_date'],
      ),
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $GoalsTable createAlias(String alias) {
    return $GoalsTable(attachedDatabase, alias);
  }
}

class GoalRow extends DataClass implements Insertable<GoalRow> {
  final String id;
  final String? ownerScopeId;
  final String title;
  final String description;
  final String type;
  final String targetAmount;
  final String currentAmount;
  final String currency;
  final String? linkedAccountId;
  final DateTime? targetDate;
  final String icon;
  final int color;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  final DateTime? completedAt;
  const GoalRow({
    required this.id,
    this.ownerScopeId,
    required this.title,
    required this.description,
    required this.type,
    required this.targetAmount,
    required this.currentAmount,
    required this.currency,
    this.linkedAccountId,
    this.targetDate,
    required this.icon,
    required this.color,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || ownerScopeId != null) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId);
    }
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['type'] = Variable<String>(type);
    map['target_amount'] = Variable<String>(targetAmount);
    map['current_amount'] = Variable<String>(currentAmount);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || linkedAccountId != null) {
      map['linked_account_id'] = Variable<String>(linkedAccountId);
    }
    if (!nullToAbsent || targetDate != null) {
      map['target_date'] = Variable<DateTime>(targetDate);
    }
    map['icon'] = Variable<String>(icon);
    map['color'] = Variable<int>(color);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  GoalsCompanion toCompanion(bool nullToAbsent) {
    return GoalsCompanion(
      id: Value(id),
      ownerScopeId: ownerScopeId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerScopeId),
      title: Value(title),
      description: Value(description),
      type: Value(type),
      targetAmount: Value(targetAmount),
      currentAmount: Value(currentAmount),
      currency: Value(currency),
      linkedAccountId: linkedAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedAccountId),
      targetDate: targetDate == null && nullToAbsent
          ? const Value.absent()
          : Value(targetDate),
      icon: Value(icon),
      color: Value(color),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory GoalRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GoalRow(
      id: serializer.fromJson<String>(json['id']),
      ownerScopeId: serializer.fromJson<String?>(json['ownerScopeId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      type: serializer.fromJson<String>(json['type']),
      targetAmount: serializer.fromJson<String>(json['targetAmount']),
      currentAmount: serializer.fromJson<String>(json['currentAmount']),
      currency: serializer.fromJson<String>(json['currency']),
      linkedAccountId: serializer.fromJson<String?>(json['linkedAccountId']),
      targetDate: serializer.fromJson<DateTime?>(json['targetDate']),
      icon: serializer.fromJson<String>(json['icon']),
      color: serializer.fromJson<int>(json['color']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerScopeId': serializer.toJson<String?>(ownerScopeId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'type': serializer.toJson<String>(type),
      'targetAmount': serializer.toJson<String>(targetAmount),
      'currentAmount': serializer.toJson<String>(currentAmount),
      'currency': serializer.toJson<String>(currency),
      'linkedAccountId': serializer.toJson<String?>(linkedAccountId),
      'targetDate': serializer.toJson<DateTime?>(targetDate),
      'icon': serializer.toJson<String>(icon),
      'color': serializer.toJson<int>(color),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  GoalRow copyWith({
    String? id,
    Value<String?> ownerScopeId = const Value.absent(),
    String? title,
    String? description,
    String? type,
    String? targetAmount,
    String? currentAmount,
    String? currency,
    Value<String?> linkedAccountId = const Value.absent(),
    Value<DateTime?> targetDate = const Value.absent(),
    String? icon,
    int? color,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> archivedAt = const Value.absent(),
    Value<DateTime?> completedAt = const Value.absent(),
  }) => GoalRow(
    id: id ?? this.id,
    ownerScopeId: ownerScopeId.present ? ownerScopeId.value : this.ownerScopeId,
    title: title ?? this.title,
    description: description ?? this.description,
    type: type ?? this.type,
    targetAmount: targetAmount ?? this.targetAmount,
    currentAmount: currentAmount ?? this.currentAmount,
    currency: currency ?? this.currency,
    linkedAccountId: linkedAccountId.present
        ? linkedAccountId.value
        : this.linkedAccountId,
    targetDate: targetDate.present ? targetDate.value : this.targetDate,
    icon: icon ?? this.icon,
    color: color ?? this.color,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  GoalRow copyWithCompanion(GoalsCompanion data) {
    return GoalRow(
      id: data.id.present ? data.id.value : this.id,
      ownerScopeId: data.ownerScopeId.present
          ? data.ownerScopeId.value
          : this.ownerScopeId,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      type: data.type.present ? data.type.value : this.type,
      targetAmount: data.targetAmount.present
          ? data.targetAmount.value
          : this.targetAmount,
      currentAmount: data.currentAmount.present
          ? data.currentAmount.value
          : this.currentAmount,
      currency: data.currency.present ? data.currency.value : this.currency,
      linkedAccountId: data.linkedAccountId.present
          ? data.linkedAccountId.value
          : this.linkedAccountId,
      targetDate: data.targetDate.present
          ? data.targetDate.value
          : this.targetDate,
      icon: data.icon.present ? data.icon.value : this.icon,
      color: data.color.present ? data.color.value : this.color,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GoalRow(')
          ..write('id: $id, ')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('type: $type, ')
          ..write('targetAmount: $targetAmount, ')
          ..write('currentAmount: $currentAmount, ')
          ..write('currency: $currency, ')
          ..write('linkedAccountId: $linkedAccountId, ')
          ..write('targetDate: $targetDate, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerScopeId,
    title,
    description,
    type,
    targetAmount,
    currentAmount,
    currency,
    linkedAccountId,
    targetDate,
    icon,
    color,
    status,
    createdAt,
    updatedAt,
    archivedAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoalRow &&
          other.id == this.id &&
          other.ownerScopeId == this.ownerScopeId &&
          other.title == this.title &&
          other.description == this.description &&
          other.type == this.type &&
          other.targetAmount == this.targetAmount &&
          other.currentAmount == this.currentAmount &&
          other.currency == this.currency &&
          other.linkedAccountId == this.linkedAccountId &&
          other.targetDate == this.targetDate &&
          other.icon == this.icon &&
          other.color == this.color &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.archivedAt == this.archivedAt &&
          other.completedAt == this.completedAt);
}

class GoalsCompanion extends UpdateCompanion<GoalRow> {
  final Value<String> id;
  final Value<String?> ownerScopeId;
  final Value<String> title;
  final Value<String> description;
  final Value<String> type;
  final Value<String> targetAmount;
  final Value<String> currentAmount;
  final Value<String> currency;
  final Value<String?> linkedAccountId;
  final Value<DateTime?> targetDate;
  final Value<String> icon;
  final Value<int> color;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> archivedAt;
  final Value<DateTime?> completedAt;
  final Value<int> rowid;
  const GoalsCompanion({
    this.id = const Value.absent(),
    this.ownerScopeId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.type = const Value.absent(),
    this.targetAmount = const Value.absent(),
    this.currentAmount = const Value.absent(),
    this.currency = const Value.absent(),
    this.linkedAccountId = const Value.absent(),
    this.targetDate = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GoalsCompanion.insert({
    required String id,
    this.ownerScopeId = const Value.absent(),
    required String title,
    this.description = const Value.absent(),
    required String type,
    required String targetAmount,
    required String currentAmount,
    required String currency,
    this.linkedAccountId = const Value.absent(),
    this.targetDate = const Value.absent(),
    required String icon,
    required int color,
    required String status,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.archivedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       type = Value(type),
       targetAmount = Value(targetAmount),
       currentAmount = Value(currentAmount),
       currency = Value(currency),
       icon = Value(icon),
       color = Value(color),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<GoalRow> custom({
    Expression<String>? id,
    Expression<String>? ownerScopeId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? type,
    Expression<String>? targetAmount,
    Expression<String>? currentAmount,
    Expression<String>? currency,
    Expression<String>? linkedAccountId,
    Expression<DateTime>? targetDate,
    Expression<String>? icon,
    Expression<int>? color,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerScopeId != null) 'owner_scope_id': ownerScopeId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (type != null) 'type': type,
      if (targetAmount != null) 'target_amount': targetAmount,
      if (currentAmount != null) 'current_amount': currentAmount,
      if (currency != null) 'currency': currency,
      if (linkedAccountId != null) 'linked_account_id': linkedAccountId,
      if (targetDate != null) 'target_date': targetDate,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GoalsCompanion copyWith({
    Value<String>? id,
    Value<String?>? ownerScopeId,
    Value<String>? title,
    Value<String>? description,
    Value<String>? type,
    Value<String>? targetAmount,
    Value<String>? currentAmount,
    Value<String>? currency,
    Value<String?>? linkedAccountId,
    Value<DateTime?>? targetDate,
    Value<String>? icon,
    Value<int>? color,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? archivedAt,
    Value<DateTime?>? completedAt,
    Value<int>? rowid,
  }) {
    return GoalsCompanion(
      id: id ?? this.id,
      ownerScopeId: ownerScopeId ?? this.ownerScopeId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      currency: currency ?? this.currency,
      linkedAccountId: linkedAccountId ?? this.linkedAccountId,
      targetDate: targetDate ?? this.targetDate,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerScopeId.present) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (targetAmount.present) {
      map['target_amount'] = Variable<String>(targetAmount.value);
    }
    if (currentAmount.present) {
      map['current_amount'] = Variable<String>(currentAmount.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (linkedAccountId.present) {
      map['linked_account_id'] = Variable<String>(linkedAccountId.value);
    }
    if (targetDate.present) {
      map['target_date'] = Variable<DateTime>(targetDate.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GoalsCompanion(')
          ..write('id: $id, ')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('type: $type, ')
          ..write('targetAmount: $targetAmount, ')
          ..write('currentAmount: $currentAmount, ')
          ..write('currency: $currency, ')
          ..write('linkedAccountId: $linkedAccountId, ')
          ..write('targetDate: $targetDate, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GoalContributionsTable extends GoalContributions
    with TableInfo<$GoalContributionsTable, GoalContributionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GoalContributionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerScopeIdMeta = const VerificationMeta(
    'ownerScopeId',
  );
  @override
  late final GeneratedColumn<String> ownerScopeId = GeneratedColumn<String>(
    'owner_scope_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _goalIdMeta = const VerificationMeta('goalId');
  @override
  late final GeneratedColumn<String> goalId = GeneratedColumn<String>(
    'goal_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<String> amount = GeneratedColumn<String>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creditedAmountMeta = const VerificationMeta(
    'creditedAmount',
  );
  @override
  late final GeneratedColumn<String> creditedAmount = GeneratedColumn<String>(
    'credited_amount',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _linkedTransactionIdMeta =
      const VerificationMeta('linkedTransactionId');
  @override
  late final GeneratedColumn<String> linkedTransactionId =
      GeneratedColumn<String>(
        'linked_transaction_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reversedAtMeta = const VerificationMeta(
    'reversedAt',
  );
  @override
  late final GeneratedColumn<DateTime> reversedAt = GeneratedColumn<DateTime>(
    'reversed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerScopeId,
    goalId,
    amount,
    currency,
    creditedAmount,
    date,
    note,
    linkedTransactionId,
    createdAt,
    updatedAt,
    reversedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'goal_contributions';
  @override
  VerificationContext validateIntegrity(
    Insertable<GoalContributionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_scope_id')) {
      context.handle(
        _ownerScopeIdMeta,
        ownerScopeId.isAcceptableOrUnknown(
          data['owner_scope_id']!,
          _ownerScopeIdMeta,
        ),
      );
    }
    if (data.containsKey('goal_id')) {
      context.handle(
        _goalIdMeta,
        goalId.isAcceptableOrUnknown(data['goal_id']!, _goalIdMeta),
      );
    } else if (isInserting) {
      context.missing(_goalIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('credited_amount')) {
      context.handle(
        _creditedAmountMeta,
        creditedAmount.isAcceptableOrUnknown(
          data['credited_amount']!,
          _creditedAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_creditedAmountMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('linked_transaction_id')) {
      context.handle(
        _linkedTransactionIdMeta,
        linkedTransactionId.isAcceptableOrUnknown(
          data['linked_transaction_id']!,
          _linkedTransactionIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('reversed_at')) {
      context.handle(
        _reversedAtMeta,
        reversedAt.isAcceptableOrUnknown(data['reversed_at']!, _reversedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GoalContributionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GoalContributionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_scope_id'],
      ),
      goalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal_id'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}amount'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      creditedAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}credited_amount'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      linkedTransactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linked_transaction_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      reversedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}reversed_at'],
      ),
    );
  }

  @override
  $GoalContributionsTable createAlias(String alias) {
    return $GoalContributionsTable(attachedDatabase, alias);
  }
}

class GoalContributionRow extends DataClass
    implements Insertable<GoalContributionRow> {
  final String id;
  final String? ownerScopeId;
  final String goalId;
  final String amount;
  final String currency;
  final String creditedAmount;
  final DateTime date;
  final String note;
  final String? linkedTransactionId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? reversedAt;
  const GoalContributionRow({
    required this.id,
    this.ownerScopeId,
    required this.goalId,
    required this.amount,
    required this.currency,
    required this.creditedAmount,
    required this.date,
    required this.note,
    this.linkedTransactionId,
    required this.createdAt,
    required this.updatedAt,
    this.reversedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || ownerScopeId != null) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId);
    }
    map['goal_id'] = Variable<String>(goalId);
    map['amount'] = Variable<String>(amount);
    map['currency'] = Variable<String>(currency);
    map['credited_amount'] = Variable<String>(creditedAmount);
    map['date'] = Variable<DateTime>(date);
    map['note'] = Variable<String>(note);
    if (!nullToAbsent || linkedTransactionId != null) {
      map['linked_transaction_id'] = Variable<String>(linkedTransactionId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || reversedAt != null) {
      map['reversed_at'] = Variable<DateTime>(reversedAt);
    }
    return map;
  }

  GoalContributionsCompanion toCompanion(bool nullToAbsent) {
    return GoalContributionsCompanion(
      id: Value(id),
      ownerScopeId: ownerScopeId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerScopeId),
      goalId: Value(goalId),
      amount: Value(amount),
      currency: Value(currency),
      creditedAmount: Value(creditedAmount),
      date: Value(date),
      note: Value(note),
      linkedTransactionId: linkedTransactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedTransactionId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      reversedAt: reversedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(reversedAt),
    );
  }

  factory GoalContributionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GoalContributionRow(
      id: serializer.fromJson<String>(json['id']),
      ownerScopeId: serializer.fromJson<String?>(json['ownerScopeId']),
      goalId: serializer.fromJson<String>(json['goalId']),
      amount: serializer.fromJson<String>(json['amount']),
      currency: serializer.fromJson<String>(json['currency']),
      creditedAmount: serializer.fromJson<String>(json['creditedAmount']),
      date: serializer.fromJson<DateTime>(json['date']),
      note: serializer.fromJson<String>(json['note']),
      linkedTransactionId: serializer.fromJson<String?>(
        json['linkedTransactionId'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      reversedAt: serializer.fromJson<DateTime?>(json['reversedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerScopeId': serializer.toJson<String?>(ownerScopeId),
      'goalId': serializer.toJson<String>(goalId),
      'amount': serializer.toJson<String>(amount),
      'currency': serializer.toJson<String>(currency),
      'creditedAmount': serializer.toJson<String>(creditedAmount),
      'date': serializer.toJson<DateTime>(date),
      'note': serializer.toJson<String>(note),
      'linkedTransactionId': serializer.toJson<String?>(linkedTransactionId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'reversedAt': serializer.toJson<DateTime?>(reversedAt),
    };
  }

  GoalContributionRow copyWith({
    String? id,
    Value<String?> ownerScopeId = const Value.absent(),
    String? goalId,
    String? amount,
    String? currency,
    String? creditedAmount,
    DateTime? date,
    String? note,
    Value<String?> linkedTransactionId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> reversedAt = const Value.absent(),
  }) => GoalContributionRow(
    id: id ?? this.id,
    ownerScopeId: ownerScopeId.present ? ownerScopeId.value : this.ownerScopeId,
    goalId: goalId ?? this.goalId,
    amount: amount ?? this.amount,
    currency: currency ?? this.currency,
    creditedAmount: creditedAmount ?? this.creditedAmount,
    date: date ?? this.date,
    note: note ?? this.note,
    linkedTransactionId: linkedTransactionId.present
        ? linkedTransactionId.value
        : this.linkedTransactionId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    reversedAt: reversedAt.present ? reversedAt.value : this.reversedAt,
  );
  GoalContributionRow copyWithCompanion(GoalContributionsCompanion data) {
    return GoalContributionRow(
      id: data.id.present ? data.id.value : this.id,
      ownerScopeId: data.ownerScopeId.present
          ? data.ownerScopeId.value
          : this.ownerScopeId,
      goalId: data.goalId.present ? data.goalId.value : this.goalId,
      amount: data.amount.present ? data.amount.value : this.amount,
      currency: data.currency.present ? data.currency.value : this.currency,
      creditedAmount: data.creditedAmount.present
          ? data.creditedAmount.value
          : this.creditedAmount,
      date: data.date.present ? data.date.value : this.date,
      note: data.note.present ? data.note.value : this.note,
      linkedTransactionId: data.linkedTransactionId.present
          ? data.linkedTransactionId.value
          : this.linkedTransactionId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      reversedAt: data.reversedAt.present
          ? data.reversedAt.value
          : this.reversedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GoalContributionRow(')
          ..write('id: $id, ')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('goalId: $goalId, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('creditedAmount: $creditedAmount, ')
          ..write('date: $date, ')
          ..write('note: $note, ')
          ..write('linkedTransactionId: $linkedTransactionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('reversedAt: $reversedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerScopeId,
    goalId,
    amount,
    currency,
    creditedAmount,
    date,
    note,
    linkedTransactionId,
    createdAt,
    updatedAt,
    reversedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoalContributionRow &&
          other.id == this.id &&
          other.ownerScopeId == this.ownerScopeId &&
          other.goalId == this.goalId &&
          other.amount == this.amount &&
          other.currency == this.currency &&
          other.creditedAmount == this.creditedAmount &&
          other.date == this.date &&
          other.note == this.note &&
          other.linkedTransactionId == this.linkedTransactionId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.reversedAt == this.reversedAt);
}

class GoalContributionsCompanion extends UpdateCompanion<GoalContributionRow> {
  final Value<String> id;
  final Value<String?> ownerScopeId;
  final Value<String> goalId;
  final Value<String> amount;
  final Value<String> currency;
  final Value<String> creditedAmount;
  final Value<DateTime> date;
  final Value<String> note;
  final Value<String?> linkedTransactionId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> reversedAt;
  final Value<int> rowid;
  const GoalContributionsCompanion({
    this.id = const Value.absent(),
    this.ownerScopeId = const Value.absent(),
    this.goalId = const Value.absent(),
    this.amount = const Value.absent(),
    this.currency = const Value.absent(),
    this.creditedAmount = const Value.absent(),
    this.date = const Value.absent(),
    this.note = const Value.absent(),
    this.linkedTransactionId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.reversedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GoalContributionsCompanion.insert({
    required String id,
    this.ownerScopeId = const Value.absent(),
    required String goalId,
    required String amount,
    required String currency,
    required String creditedAmount,
    required DateTime date,
    this.note = const Value.absent(),
    this.linkedTransactionId = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.reversedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       goalId = Value(goalId),
       amount = Value(amount),
       currency = Value(currency),
       creditedAmount = Value(creditedAmount),
       date = Value(date),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<GoalContributionRow> custom({
    Expression<String>? id,
    Expression<String>? ownerScopeId,
    Expression<String>? goalId,
    Expression<String>? amount,
    Expression<String>? currency,
    Expression<String>? creditedAmount,
    Expression<DateTime>? date,
    Expression<String>? note,
    Expression<String>? linkedTransactionId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? reversedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerScopeId != null) 'owner_scope_id': ownerScopeId,
      if (goalId != null) 'goal_id': goalId,
      if (amount != null) 'amount': amount,
      if (currency != null) 'currency': currency,
      if (creditedAmount != null) 'credited_amount': creditedAmount,
      if (date != null) 'date': date,
      if (note != null) 'note': note,
      if (linkedTransactionId != null)
        'linked_transaction_id': linkedTransactionId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (reversedAt != null) 'reversed_at': reversedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GoalContributionsCompanion copyWith({
    Value<String>? id,
    Value<String?>? ownerScopeId,
    Value<String>? goalId,
    Value<String>? amount,
    Value<String>? currency,
    Value<String>? creditedAmount,
    Value<DateTime>? date,
    Value<String>? note,
    Value<String?>? linkedTransactionId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? reversedAt,
    Value<int>? rowid,
  }) {
    return GoalContributionsCompanion(
      id: id ?? this.id,
      ownerScopeId: ownerScopeId ?? this.ownerScopeId,
      goalId: goalId ?? this.goalId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      creditedAmount: creditedAmount ?? this.creditedAmount,
      date: date ?? this.date,
      note: note ?? this.note,
      linkedTransactionId: linkedTransactionId ?? this.linkedTransactionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reversedAt: reversedAt ?? this.reversedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerScopeId.present) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId.value);
    }
    if (goalId.present) {
      map['goal_id'] = Variable<String>(goalId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<String>(amount.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (creditedAmount.present) {
      map['credited_amount'] = Variable<String>(creditedAmount.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (linkedTransactionId.present) {
      map['linked_transaction_id'] = Variable<String>(
        linkedTransactionId.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (reversedAt.present) {
      map['reversed_at'] = Variable<DateTime>(reversedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GoalContributionsCompanion(')
          ..write('id: $id, ')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('goalId: $goalId, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('creditedAmount: $creditedAmount, ')
          ..write('date: $date, ')
          ..write('note: $note, ')
          ..write('linkedTransactionId: $linkedTransactionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('reversedAt: $reversedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueTable extends SyncQueue
    with TableInfo<$SyncQueueTable, SyncQueueRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerScopeIdMeta = const VerificationMeta(
    'ownerScopeId',
  );
  @override
  late final GeneratedColumn<String> ownerScopeId = GeneratedColumn<String>(
    'owner_scope_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ownerUserIdMeta = const VerificationMeta(
    'ownerUserId',
  );
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
    'owner_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
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
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerScopeId,
    ownerUserId,
    entityType,
    entityId,
    operation,
    payloadJson,
    status,
    attemptCount,
    lastError,
    createdAt,
    updatedAt,
    lastAttemptAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncQueueRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_scope_id')) {
      context.handle(
        _ownerScopeIdMeta,
        ownerScopeId.isAcceptableOrUnknown(
          data['owner_scope_id']!,
          _ownerScopeIdMeta,
        ),
      );
    }
    if (data.containsKey('owner_user_id')) {
      context.handle(
        _ownerUserIdMeta,
        ownerUserId.isAcceptableOrUnknown(
          data['owner_user_id']!,
          _ownerUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerUserIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_scope_id'],
      ),
      ownerUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_user_id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt_at'],
      ),
    );
  }

  @override
  $SyncQueueTable createAlias(String alias) {
    return $SyncQueueTable(attachedDatabase, alias);
  }
}

class SyncQueueRow extends DataClass implements Insertable<SyncQueueRow> {
  final String id;
  final String? ownerScopeId;
  final String ownerUserId;
  final String entityType;
  final String entityId;
  final String operation;
  final String payloadJson;
  final String status;
  final int attemptCount;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastAttemptAt;
  const SyncQueueRow({
    required this.id,
    this.ownerScopeId,
    required this.ownerUserId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payloadJson,
    required this.status,
    required this.attemptCount,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
    this.lastAttemptAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || ownerScopeId != null) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId);
    }
    map['owner_user_id'] = Variable<String>(ownerUserId);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['operation'] = Variable<String>(operation);
    map['payload_json'] = Variable<String>(payloadJson);
    map['status'] = Variable<String>(status);
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    return map;
  }

  SyncQueueCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueCompanion(
      id: Value(id),
      ownerScopeId: ownerScopeId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerScopeId),
      ownerUserId: Value(ownerUserId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      operation: Value(operation),
      payloadJson: Value(payloadJson),
      status: Value(status),
      attemptCount: Value(attemptCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
    );
  }

  factory SyncQueueRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueRow(
      id: serializer.fromJson<String>(json['id']),
      ownerScopeId: serializer.fromJson<String?>(json['ownerScopeId']),
      ownerUserId: serializer.fromJson<String>(json['ownerUserId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      operation: serializer.fromJson<String>(json['operation']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      status: serializer.fromJson<String>(json['status']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerScopeId': serializer.toJson<String?>(ownerScopeId),
      'ownerUserId': serializer.toJson<String>(ownerUserId),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'operation': serializer.toJson<String>(operation),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'status': serializer.toJson<String>(status),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
    };
  }

  SyncQueueRow copyWith({
    String? id,
    Value<String?> ownerScopeId = const Value.absent(),
    String? ownerUserId,
    String? entityType,
    String? entityId,
    String? operation,
    String? payloadJson,
    String? status,
    int? attemptCount,
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> lastAttemptAt = const Value.absent(),
  }) => SyncQueueRow(
    id: id ?? this.id,
    ownerScopeId: ownerScopeId.present ? ownerScopeId.value : this.ownerScopeId,
    ownerUserId: ownerUserId ?? this.ownerUserId,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    operation: operation ?? this.operation,
    payloadJson: payloadJson ?? this.payloadJson,
    status: status ?? this.status,
    attemptCount: attemptCount ?? this.attemptCount,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
  );
  SyncQueueRow copyWithCompanion(SyncQueueCompanion data) {
    return SyncQueueRow(
      id: data.id.present ? data.id.value : this.id,
      ownerScopeId: data.ownerScopeId.present
          ? data.ownerScopeId.value
          : this.ownerScopeId,
      ownerUserId: data.ownerUserId.present
          ? data.ownerUserId.value
          : this.ownerUserId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      operation: data.operation.present ? data.operation.value : this.operation,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      status: data.status.present ? data.status.value : this.status,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueRow(')
          ..write('id: $id, ')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastAttemptAt: $lastAttemptAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerScopeId,
    ownerUserId,
    entityType,
    entityId,
    operation,
    payloadJson,
    status,
    attemptCount,
    lastError,
    createdAt,
    updatedAt,
    lastAttemptAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueRow &&
          other.id == this.id &&
          other.ownerScopeId == this.ownerScopeId &&
          other.ownerUserId == this.ownerUserId &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.operation == this.operation &&
          other.payloadJson == this.payloadJson &&
          other.status == this.status &&
          other.attemptCount == this.attemptCount &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.lastAttemptAt == this.lastAttemptAt);
}

class SyncQueueCompanion extends UpdateCompanion<SyncQueueRow> {
  final Value<String> id;
  final Value<String?> ownerScopeId;
  final Value<String> ownerUserId;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> operation;
  final Value<String> payloadJson;
  final Value<String> status;
  final Value<int> attemptCount;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> lastAttemptAt;
  final Value<int> rowid;
  const SyncQueueCompanion({
    this.id = const Value.absent(),
    this.ownerScopeId = const Value.absent(),
    this.ownerUserId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.operation = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.status = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncQueueCompanion.insert({
    required String id,
    this.ownerScopeId = const Value.absent(),
    required String ownerUserId,
    required String entityType,
    required String entityId,
    required String operation,
    required String payloadJson,
    this.status = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastError = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.lastAttemptAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerUserId = Value(ownerUserId),
       entityType = Value(entityType),
       entityId = Value(entityId),
       operation = Value(operation),
       payloadJson = Value(payloadJson),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SyncQueueRow> custom({
    Expression<String>? id,
    Expression<String>? ownerScopeId,
    Expression<String>? ownerUserId,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? operation,
    Expression<String>? payloadJson,
    Expression<String>? status,
    Expression<int>? attemptCount,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? lastAttemptAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerScopeId != null) 'owner_scope_id': ownerScopeId,
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (operation != null) 'operation': operation,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (status != null) 'status': status,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncQueueCompanion copyWith({
    Value<String>? id,
    Value<String?>? ownerScopeId,
    Value<String>? ownerUserId,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? operation,
    Value<String>? payloadJson,
    Value<String>? status,
    Value<int>? attemptCount,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? lastAttemptAt,
    Value<int>? rowid,
  }) {
    return SyncQueueCompanion(
      id: id ?? this.id,
      ownerScopeId: ownerScopeId ?? this.ownerScopeId,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      payloadJson: payloadJson ?? this.payloadJson,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerScopeId.present) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId.value);
    }
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueCompanion(')
          ..write('id: $id, ')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReceiptsTable extends Receipts
    with TableInfo<$ReceiptsTable, ReceiptRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReceiptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerScopeIdMeta = const VerificationMeta(
    'ownerScopeId',
  );
  @override
  late final GeneratedColumn<String> ownerScopeId = GeneratedColumn<String>(
    'owner_scope_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _documentTypeMeta = const VerificationMeta(
    'documentType',
  );
  @override
  late final GeneratedColumn<String> documentType = GeneratedColumn<String>(
    'document_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paymentStatusMeta = const VerificationMeta(
    'paymentStatus',
  );
  @override
  late final GeneratedColumn<String> paymentStatus = GeneratedColumn<String>(
    'payment_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _merchantNameMeta = const VerificationMeta(
    'merchantName',
  );
  @override
  late final GeneratedColumn<String> merchantName = GeneratedColumn<String>(
    'merchant_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _merchantPayeeIdMeta = const VerificationMeta(
    'merchantPayeeId',
  );
  @override
  late final GeneratedColumn<String> merchantPayeeId = GeneratedColumn<String>(
    'merchant_payee_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _merchantAddressMeta = const VerificationMeta(
    'merchantAddress',
  );
  @override
  late final GeneratedColumn<String> merchantAddress = GeneratedColumn<String>(
    'merchant_address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _merchantTaxIdMeta = const VerificationMeta(
    'merchantTaxId',
  );
  @override
  late final GeneratedColumn<String> merchantTaxId = GeneratedColumn<String>(
    'merchant_tax_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _receiptNumberMeta = const VerificationMeta(
    'receiptNumber',
  );
  @override
  late final GeneratedColumn<String> receiptNumber = GeneratedColumn<String>(
    'receipt_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _invoiceNumberMeta = const VerificationMeta(
    'invoiceNumber',
  );
  @override
  late final GeneratedColumn<String> invoiceNumber = GeneratedColumn<String>(
    'invoice_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _purchaseDateMeta = const VerificationMeta(
    'purchaseDate',
  );
  @override
  late final GeneratedColumn<DateTime> purchaseDate = GeneratedColumn<DateTime>(
    'purchase_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subtotalMeta = const VerificationMeta(
    'subtotal',
  );
  @override
  late final GeneratedColumn<String> subtotal = GeneratedColumn<String>(
    'subtotal',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taxMeta = const VerificationMeta('tax');
  @override
  late final GeneratedColumn<String> tax = GeneratedColumn<String>(
    'tax',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _discountMeta = const VerificationMeta(
    'discount',
  );
  @override
  late final GeneratedColumn<String> discount = GeneratedColumn<String>(
    'discount',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serviceChargeMeta = const VerificationMeta(
    'serviceCharge',
  );
  @override
  late final GeneratedColumn<String> serviceCharge = GeneratedColumn<String>(
    'service_charge',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tipMeta = const VerificationMeta('tip');
  @override
  late final GeneratedColumn<String> tip = GeneratedColumn<String>(
    'tip',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _otherFeesMeta = const VerificationMeta(
    'otherFees',
  );
  @override
  late final GeneratedColumn<String> otherFees = GeneratedColumn<String>(
    'other_fees',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<String> total = GeneratedColumn<String>(
    'total',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountPaidMeta = const VerificationMeta(
    'amountPaid',
  );
  @override
  late final GeneratedColumn<String> amountPaid = GeneratedColumn<String>(
    'amount_paid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountDueMeta = const VerificationMeta(
    'amountDue',
  );
  @override
  late final GeneratedColumn<String> amountDue = GeneratedColumn<String>(
    'amount_due',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paymentMethodHintMeta = const VerificationMeta(
    'paymentMethodHint',
  );
  @override
  late final GeneratedColumn<String> paymentMethodHint =
      GeneratedColumn<String>(
        'payment_method_hint',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _accountHintMeta = const VerificationMeta(
    'accountHint',
  );
  @override
  late final GeneratedColumn<String> accountHint = GeneratedColumn<String>(
    'account_hint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<int> confidence = GeneratedColumn<int>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _warningsJsonMeta = const VerificationMeta(
    'warningsJson',
  );
  @override
  late final GeneratedColumn<String> warningsJson = GeneratedColumn<String>(
    'warnings_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _duplicateCandidateIdsJsonMeta =
      const VerificationMeta('duplicateCandidateIdsJson');
  @override
  late final GeneratedColumn<String> duplicateCandidateIdsJson =
      GeneratedColumn<String>(
        'duplicate_candidate_ids_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _imageRetentionChoiceMeta =
      const VerificationMeta('imageRetentionChoice');
  @override
  late final GeneratedColumn<String> imageRetentionChoice =
      GeneratedColumn<String>(
        'image_retention_choice',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _localImageReferenceMeta =
      const VerificationMeta('localImageReference');
  @override
  late final GeneratedColumn<String> localImageReference =
      GeneratedColumn<String>(
        'local_image_reference',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _imageHashMeta = const VerificationMeta(
    'imageHash',
  );
  @override
  late final GeneratedColumn<String> imageHash = GeneratedColumn<String>(
    'image_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _linkedTransactionIdMeta =
      const VerificationMeta('linkedTransactionId');
  @override
  late final GeneratedColumn<String> linkedTransactionId =
      GeneratedColumn<String>(
        'linked_transaction_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerScopeId,
    documentType,
    paymentStatus,
    merchantName,
    merchantPayeeId,
    merchantAddress,
    merchantTaxId,
    receiptNumber,
    invoiceNumber,
    purchaseDate,
    dueDate,
    currency,
    subtotal,
    tax,
    discount,
    serviceCharge,
    tip,
    otherFees,
    total,
    amountPaid,
    amountDue,
    paymentMethodHint,
    accountHint,
    confidence,
    warningsJson,
    duplicateCandidateIdsJson,
    imageRetentionChoice,
    localImageReference,
    imageHash,
    status,
    linkedTransactionId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'receipts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReceiptRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_scope_id')) {
      context.handle(
        _ownerScopeIdMeta,
        ownerScopeId.isAcceptableOrUnknown(
          data['owner_scope_id']!,
          _ownerScopeIdMeta,
        ),
      );
    }
    if (data.containsKey('document_type')) {
      context.handle(
        _documentTypeMeta,
        documentType.isAcceptableOrUnknown(
          data['document_type']!,
          _documentTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_documentTypeMeta);
    }
    if (data.containsKey('payment_status')) {
      context.handle(
        _paymentStatusMeta,
        paymentStatus.isAcceptableOrUnknown(
          data['payment_status']!,
          _paymentStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paymentStatusMeta);
    }
    if (data.containsKey('merchant_name')) {
      context.handle(
        _merchantNameMeta,
        merchantName.isAcceptableOrUnknown(
          data['merchant_name']!,
          _merchantNameMeta,
        ),
      );
    }
    if (data.containsKey('merchant_payee_id')) {
      context.handle(
        _merchantPayeeIdMeta,
        merchantPayeeId.isAcceptableOrUnknown(
          data['merchant_payee_id']!,
          _merchantPayeeIdMeta,
        ),
      );
    }
    if (data.containsKey('merchant_address')) {
      context.handle(
        _merchantAddressMeta,
        merchantAddress.isAcceptableOrUnknown(
          data['merchant_address']!,
          _merchantAddressMeta,
        ),
      );
    }
    if (data.containsKey('merchant_tax_id')) {
      context.handle(
        _merchantTaxIdMeta,
        merchantTaxId.isAcceptableOrUnknown(
          data['merchant_tax_id']!,
          _merchantTaxIdMeta,
        ),
      );
    }
    if (data.containsKey('receipt_number')) {
      context.handle(
        _receiptNumberMeta,
        receiptNumber.isAcceptableOrUnknown(
          data['receipt_number']!,
          _receiptNumberMeta,
        ),
      );
    }
    if (data.containsKey('invoice_number')) {
      context.handle(
        _invoiceNumberMeta,
        invoiceNumber.isAcceptableOrUnknown(
          data['invoice_number']!,
          _invoiceNumberMeta,
        ),
      );
    }
    if (data.containsKey('purchase_date')) {
      context.handle(
        _purchaseDateMeta,
        purchaseDate.isAcceptableOrUnknown(
          data['purchase_date']!,
          _purchaseDateMeta,
        ),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('subtotal')) {
      context.handle(
        _subtotalMeta,
        subtotal.isAcceptableOrUnknown(data['subtotal']!, _subtotalMeta),
      );
    }
    if (data.containsKey('tax')) {
      context.handle(
        _taxMeta,
        tax.isAcceptableOrUnknown(data['tax']!, _taxMeta),
      );
    }
    if (data.containsKey('discount')) {
      context.handle(
        _discountMeta,
        discount.isAcceptableOrUnknown(data['discount']!, _discountMeta),
      );
    }
    if (data.containsKey('service_charge')) {
      context.handle(
        _serviceChargeMeta,
        serviceCharge.isAcceptableOrUnknown(
          data['service_charge']!,
          _serviceChargeMeta,
        ),
      );
    }
    if (data.containsKey('tip')) {
      context.handle(
        _tipMeta,
        tip.isAcceptableOrUnknown(data['tip']!, _tipMeta),
      );
    }
    if (data.containsKey('other_fees')) {
      context.handle(
        _otherFeesMeta,
        otherFees.isAcceptableOrUnknown(data['other_fees']!, _otherFeesMeta),
      );
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    }
    if (data.containsKey('amount_paid')) {
      context.handle(
        _amountPaidMeta,
        amountPaid.isAcceptableOrUnknown(data['amount_paid']!, _amountPaidMeta),
      );
    }
    if (data.containsKey('amount_due')) {
      context.handle(
        _amountDueMeta,
        amountDue.isAcceptableOrUnknown(data['amount_due']!, _amountDueMeta),
      );
    }
    if (data.containsKey('payment_method_hint')) {
      context.handle(
        _paymentMethodHintMeta,
        paymentMethodHint.isAcceptableOrUnknown(
          data['payment_method_hint']!,
          _paymentMethodHintMeta,
        ),
      );
    }
    if (data.containsKey('account_hint')) {
      context.handle(
        _accountHintMeta,
        accountHint.isAcceptableOrUnknown(
          data['account_hint']!,
          _accountHintMeta,
        ),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('warnings_json')) {
      context.handle(
        _warningsJsonMeta,
        warningsJson.isAcceptableOrUnknown(
          data['warnings_json']!,
          _warningsJsonMeta,
        ),
      );
    }
    if (data.containsKey('duplicate_candidate_ids_json')) {
      context.handle(
        _duplicateCandidateIdsJsonMeta,
        duplicateCandidateIdsJson.isAcceptableOrUnknown(
          data['duplicate_candidate_ids_json']!,
          _duplicateCandidateIdsJsonMeta,
        ),
      );
    }
    if (data.containsKey('image_retention_choice')) {
      context.handle(
        _imageRetentionChoiceMeta,
        imageRetentionChoice.isAcceptableOrUnknown(
          data['image_retention_choice']!,
          _imageRetentionChoiceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_imageRetentionChoiceMeta);
    }
    if (data.containsKey('local_image_reference')) {
      context.handle(
        _localImageReferenceMeta,
        localImageReference.isAcceptableOrUnknown(
          data['local_image_reference']!,
          _localImageReferenceMeta,
        ),
      );
    }
    if (data.containsKey('image_hash')) {
      context.handle(
        _imageHashMeta,
        imageHash.isAcceptableOrUnknown(data['image_hash']!, _imageHashMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('linked_transaction_id')) {
      context.handle(
        _linkedTransactionIdMeta,
        linkedTransactionId.isAcceptableOrUnknown(
          data['linked_transaction_id']!,
          _linkedTransactionIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
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
  ReceiptRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReceiptRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_scope_id'],
      ),
      documentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_type'],
      )!,
      paymentStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_status'],
      )!,
      merchantName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant_name'],
      ),
      merchantPayeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant_payee_id'],
      ),
      merchantAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant_address'],
      ),
      merchantTaxId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant_tax_id'],
      ),
      receiptNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_number'],
      ),
      invoiceNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invoice_number'],
      ),
      purchaseDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}purchase_date'],
      ),
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      ),
      subtotal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subtotal'],
      ),
      tax: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tax'],
      ),
      discount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}discount'],
      ),
      serviceCharge: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}service_charge'],
      ),
      tip: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tip'],
      ),
      otherFees: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}other_fees'],
      ),
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}total'],
      ),
      amountPaid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}amount_paid'],
      ),
      amountDue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}amount_due'],
      ),
      paymentMethodHint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_method_hint'],
      ),
      accountHint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_hint'],
      ),
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}confidence'],
      )!,
      warningsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}warnings_json'],
      )!,
      duplicateCandidateIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}duplicate_candidate_ids_json'],
      )!,
      imageRetentionChoice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_retention_choice'],
      )!,
      localImageReference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_image_reference'],
      ),
      imageHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_hash'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      linkedTransactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linked_transaction_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ReceiptsTable createAlias(String alias) {
    return $ReceiptsTable(attachedDatabase, alias);
  }
}

class ReceiptRow extends DataClass implements Insertable<ReceiptRow> {
  final String id;
  final String? ownerScopeId;
  final String documentType;
  final String paymentStatus;
  final String? merchantName;
  final String? merchantPayeeId;
  final String? merchantAddress;
  final String? merchantTaxId;
  final String? receiptNumber;
  final String? invoiceNumber;
  final DateTime? purchaseDate;
  final DateTime? dueDate;
  final String? currency;
  final String? subtotal;
  final String? tax;
  final String? discount;
  final String? serviceCharge;
  final String? tip;
  final String? otherFees;
  final String? total;
  final String? amountPaid;
  final String? amountDue;
  final String? paymentMethodHint;
  final String? accountHint;
  final int confidence;
  final String warningsJson;
  final String duplicateCandidateIdsJson;
  final String imageRetentionChoice;
  final String? localImageReference;
  final String? imageHash;
  final String status;
  final String? linkedTransactionId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ReceiptRow({
    required this.id,
    this.ownerScopeId,
    required this.documentType,
    required this.paymentStatus,
    this.merchantName,
    this.merchantPayeeId,
    this.merchantAddress,
    this.merchantTaxId,
    this.receiptNumber,
    this.invoiceNumber,
    this.purchaseDate,
    this.dueDate,
    this.currency,
    this.subtotal,
    this.tax,
    this.discount,
    this.serviceCharge,
    this.tip,
    this.otherFees,
    this.total,
    this.amountPaid,
    this.amountDue,
    this.paymentMethodHint,
    this.accountHint,
    required this.confidence,
    required this.warningsJson,
    required this.duplicateCandidateIdsJson,
    required this.imageRetentionChoice,
    this.localImageReference,
    this.imageHash,
    required this.status,
    this.linkedTransactionId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || ownerScopeId != null) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId);
    }
    map['document_type'] = Variable<String>(documentType);
    map['payment_status'] = Variable<String>(paymentStatus);
    if (!nullToAbsent || merchantName != null) {
      map['merchant_name'] = Variable<String>(merchantName);
    }
    if (!nullToAbsent || merchantPayeeId != null) {
      map['merchant_payee_id'] = Variable<String>(merchantPayeeId);
    }
    if (!nullToAbsent || merchantAddress != null) {
      map['merchant_address'] = Variable<String>(merchantAddress);
    }
    if (!nullToAbsent || merchantTaxId != null) {
      map['merchant_tax_id'] = Variable<String>(merchantTaxId);
    }
    if (!nullToAbsent || receiptNumber != null) {
      map['receipt_number'] = Variable<String>(receiptNumber);
    }
    if (!nullToAbsent || invoiceNumber != null) {
      map['invoice_number'] = Variable<String>(invoiceNumber);
    }
    if (!nullToAbsent || purchaseDate != null) {
      map['purchase_date'] = Variable<DateTime>(purchaseDate);
    }
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<DateTime>(dueDate);
    }
    if (!nullToAbsent || currency != null) {
      map['currency'] = Variable<String>(currency);
    }
    if (!nullToAbsent || subtotal != null) {
      map['subtotal'] = Variable<String>(subtotal);
    }
    if (!nullToAbsent || tax != null) {
      map['tax'] = Variable<String>(tax);
    }
    if (!nullToAbsent || discount != null) {
      map['discount'] = Variable<String>(discount);
    }
    if (!nullToAbsent || serviceCharge != null) {
      map['service_charge'] = Variable<String>(serviceCharge);
    }
    if (!nullToAbsent || tip != null) {
      map['tip'] = Variable<String>(tip);
    }
    if (!nullToAbsent || otherFees != null) {
      map['other_fees'] = Variable<String>(otherFees);
    }
    if (!nullToAbsent || total != null) {
      map['total'] = Variable<String>(total);
    }
    if (!nullToAbsent || amountPaid != null) {
      map['amount_paid'] = Variable<String>(amountPaid);
    }
    if (!nullToAbsent || amountDue != null) {
      map['amount_due'] = Variable<String>(amountDue);
    }
    if (!nullToAbsent || paymentMethodHint != null) {
      map['payment_method_hint'] = Variable<String>(paymentMethodHint);
    }
    if (!nullToAbsent || accountHint != null) {
      map['account_hint'] = Variable<String>(accountHint);
    }
    map['confidence'] = Variable<int>(confidence);
    map['warnings_json'] = Variable<String>(warningsJson);
    map['duplicate_candidate_ids_json'] = Variable<String>(
      duplicateCandidateIdsJson,
    );
    map['image_retention_choice'] = Variable<String>(imageRetentionChoice);
    if (!nullToAbsent || localImageReference != null) {
      map['local_image_reference'] = Variable<String>(localImageReference);
    }
    if (!nullToAbsent || imageHash != null) {
      map['image_hash'] = Variable<String>(imageHash);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || linkedTransactionId != null) {
      map['linked_transaction_id'] = Variable<String>(linkedTransactionId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ReceiptsCompanion toCompanion(bool nullToAbsent) {
    return ReceiptsCompanion(
      id: Value(id),
      ownerScopeId: ownerScopeId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerScopeId),
      documentType: Value(documentType),
      paymentStatus: Value(paymentStatus),
      merchantName: merchantName == null && nullToAbsent
          ? const Value.absent()
          : Value(merchantName),
      merchantPayeeId: merchantPayeeId == null && nullToAbsent
          ? const Value.absent()
          : Value(merchantPayeeId),
      merchantAddress: merchantAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(merchantAddress),
      merchantTaxId: merchantTaxId == null && nullToAbsent
          ? const Value.absent()
          : Value(merchantTaxId),
      receiptNumber: receiptNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(receiptNumber),
      invoiceNumber: invoiceNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(invoiceNumber),
      purchaseDate: purchaseDate == null && nullToAbsent
          ? const Value.absent()
          : Value(purchaseDate),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      currency: currency == null && nullToAbsent
          ? const Value.absent()
          : Value(currency),
      subtotal: subtotal == null && nullToAbsent
          ? const Value.absent()
          : Value(subtotal),
      tax: tax == null && nullToAbsent ? const Value.absent() : Value(tax),
      discount: discount == null && nullToAbsent
          ? const Value.absent()
          : Value(discount),
      serviceCharge: serviceCharge == null && nullToAbsent
          ? const Value.absent()
          : Value(serviceCharge),
      tip: tip == null && nullToAbsent ? const Value.absent() : Value(tip),
      otherFees: otherFees == null && nullToAbsent
          ? const Value.absent()
          : Value(otherFees),
      total: total == null && nullToAbsent
          ? const Value.absent()
          : Value(total),
      amountPaid: amountPaid == null && nullToAbsent
          ? const Value.absent()
          : Value(amountPaid),
      amountDue: amountDue == null && nullToAbsent
          ? const Value.absent()
          : Value(amountDue),
      paymentMethodHint: paymentMethodHint == null && nullToAbsent
          ? const Value.absent()
          : Value(paymentMethodHint),
      accountHint: accountHint == null && nullToAbsent
          ? const Value.absent()
          : Value(accountHint),
      confidence: Value(confidence),
      warningsJson: Value(warningsJson),
      duplicateCandidateIdsJson: Value(duplicateCandidateIdsJson),
      imageRetentionChoice: Value(imageRetentionChoice),
      localImageReference: localImageReference == null && nullToAbsent
          ? const Value.absent()
          : Value(localImageReference),
      imageHash: imageHash == null && nullToAbsent
          ? const Value.absent()
          : Value(imageHash),
      status: Value(status),
      linkedTransactionId: linkedTransactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedTransactionId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReceiptRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReceiptRow(
      id: serializer.fromJson<String>(json['id']),
      ownerScopeId: serializer.fromJson<String?>(json['ownerScopeId']),
      documentType: serializer.fromJson<String>(json['documentType']),
      paymentStatus: serializer.fromJson<String>(json['paymentStatus']),
      merchantName: serializer.fromJson<String?>(json['merchantName']),
      merchantPayeeId: serializer.fromJson<String?>(json['merchantPayeeId']),
      merchantAddress: serializer.fromJson<String?>(json['merchantAddress']),
      merchantTaxId: serializer.fromJson<String?>(json['merchantTaxId']),
      receiptNumber: serializer.fromJson<String?>(json['receiptNumber']),
      invoiceNumber: serializer.fromJson<String?>(json['invoiceNumber']),
      purchaseDate: serializer.fromJson<DateTime?>(json['purchaseDate']),
      dueDate: serializer.fromJson<DateTime?>(json['dueDate']),
      currency: serializer.fromJson<String?>(json['currency']),
      subtotal: serializer.fromJson<String?>(json['subtotal']),
      tax: serializer.fromJson<String?>(json['tax']),
      discount: serializer.fromJson<String?>(json['discount']),
      serviceCharge: serializer.fromJson<String?>(json['serviceCharge']),
      tip: serializer.fromJson<String?>(json['tip']),
      otherFees: serializer.fromJson<String?>(json['otherFees']),
      total: serializer.fromJson<String?>(json['total']),
      amountPaid: serializer.fromJson<String?>(json['amountPaid']),
      amountDue: serializer.fromJson<String?>(json['amountDue']),
      paymentMethodHint: serializer.fromJson<String?>(
        json['paymentMethodHint'],
      ),
      accountHint: serializer.fromJson<String?>(json['accountHint']),
      confidence: serializer.fromJson<int>(json['confidence']),
      warningsJson: serializer.fromJson<String>(json['warningsJson']),
      duplicateCandidateIdsJson: serializer.fromJson<String>(
        json['duplicateCandidateIdsJson'],
      ),
      imageRetentionChoice: serializer.fromJson<String>(
        json['imageRetentionChoice'],
      ),
      localImageReference: serializer.fromJson<String?>(
        json['localImageReference'],
      ),
      imageHash: serializer.fromJson<String?>(json['imageHash']),
      status: serializer.fromJson<String>(json['status']),
      linkedTransactionId: serializer.fromJson<String?>(
        json['linkedTransactionId'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerScopeId': serializer.toJson<String?>(ownerScopeId),
      'documentType': serializer.toJson<String>(documentType),
      'paymentStatus': serializer.toJson<String>(paymentStatus),
      'merchantName': serializer.toJson<String?>(merchantName),
      'merchantPayeeId': serializer.toJson<String?>(merchantPayeeId),
      'merchantAddress': serializer.toJson<String?>(merchantAddress),
      'merchantTaxId': serializer.toJson<String?>(merchantTaxId),
      'receiptNumber': serializer.toJson<String?>(receiptNumber),
      'invoiceNumber': serializer.toJson<String?>(invoiceNumber),
      'purchaseDate': serializer.toJson<DateTime?>(purchaseDate),
      'dueDate': serializer.toJson<DateTime?>(dueDate),
      'currency': serializer.toJson<String?>(currency),
      'subtotal': serializer.toJson<String?>(subtotal),
      'tax': serializer.toJson<String?>(tax),
      'discount': serializer.toJson<String?>(discount),
      'serviceCharge': serializer.toJson<String?>(serviceCharge),
      'tip': serializer.toJson<String?>(tip),
      'otherFees': serializer.toJson<String?>(otherFees),
      'total': serializer.toJson<String?>(total),
      'amountPaid': serializer.toJson<String?>(amountPaid),
      'amountDue': serializer.toJson<String?>(amountDue),
      'paymentMethodHint': serializer.toJson<String?>(paymentMethodHint),
      'accountHint': serializer.toJson<String?>(accountHint),
      'confidence': serializer.toJson<int>(confidence),
      'warningsJson': serializer.toJson<String>(warningsJson),
      'duplicateCandidateIdsJson': serializer.toJson<String>(
        duplicateCandidateIdsJson,
      ),
      'imageRetentionChoice': serializer.toJson<String>(imageRetentionChoice),
      'localImageReference': serializer.toJson<String?>(localImageReference),
      'imageHash': serializer.toJson<String?>(imageHash),
      'status': serializer.toJson<String>(status),
      'linkedTransactionId': serializer.toJson<String?>(linkedTransactionId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ReceiptRow copyWith({
    String? id,
    Value<String?> ownerScopeId = const Value.absent(),
    String? documentType,
    String? paymentStatus,
    Value<String?> merchantName = const Value.absent(),
    Value<String?> merchantPayeeId = const Value.absent(),
    Value<String?> merchantAddress = const Value.absent(),
    Value<String?> merchantTaxId = const Value.absent(),
    Value<String?> receiptNumber = const Value.absent(),
    Value<String?> invoiceNumber = const Value.absent(),
    Value<DateTime?> purchaseDate = const Value.absent(),
    Value<DateTime?> dueDate = const Value.absent(),
    Value<String?> currency = const Value.absent(),
    Value<String?> subtotal = const Value.absent(),
    Value<String?> tax = const Value.absent(),
    Value<String?> discount = const Value.absent(),
    Value<String?> serviceCharge = const Value.absent(),
    Value<String?> tip = const Value.absent(),
    Value<String?> otherFees = const Value.absent(),
    Value<String?> total = const Value.absent(),
    Value<String?> amountPaid = const Value.absent(),
    Value<String?> amountDue = const Value.absent(),
    Value<String?> paymentMethodHint = const Value.absent(),
    Value<String?> accountHint = const Value.absent(),
    int? confidence,
    String? warningsJson,
    String? duplicateCandidateIdsJson,
    String? imageRetentionChoice,
    Value<String?> localImageReference = const Value.absent(),
    Value<String?> imageHash = const Value.absent(),
    String? status,
    Value<String?> linkedTransactionId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ReceiptRow(
    id: id ?? this.id,
    ownerScopeId: ownerScopeId.present ? ownerScopeId.value : this.ownerScopeId,
    documentType: documentType ?? this.documentType,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    merchantName: merchantName.present ? merchantName.value : this.merchantName,
    merchantPayeeId: merchantPayeeId.present
        ? merchantPayeeId.value
        : this.merchantPayeeId,
    merchantAddress: merchantAddress.present
        ? merchantAddress.value
        : this.merchantAddress,
    merchantTaxId: merchantTaxId.present
        ? merchantTaxId.value
        : this.merchantTaxId,
    receiptNumber: receiptNumber.present
        ? receiptNumber.value
        : this.receiptNumber,
    invoiceNumber: invoiceNumber.present
        ? invoiceNumber.value
        : this.invoiceNumber,
    purchaseDate: purchaseDate.present ? purchaseDate.value : this.purchaseDate,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    currency: currency.present ? currency.value : this.currency,
    subtotal: subtotal.present ? subtotal.value : this.subtotal,
    tax: tax.present ? tax.value : this.tax,
    discount: discount.present ? discount.value : this.discount,
    serviceCharge: serviceCharge.present
        ? serviceCharge.value
        : this.serviceCharge,
    tip: tip.present ? tip.value : this.tip,
    otherFees: otherFees.present ? otherFees.value : this.otherFees,
    total: total.present ? total.value : this.total,
    amountPaid: amountPaid.present ? amountPaid.value : this.amountPaid,
    amountDue: amountDue.present ? amountDue.value : this.amountDue,
    paymentMethodHint: paymentMethodHint.present
        ? paymentMethodHint.value
        : this.paymentMethodHint,
    accountHint: accountHint.present ? accountHint.value : this.accountHint,
    confidence: confidence ?? this.confidence,
    warningsJson: warningsJson ?? this.warningsJson,
    duplicateCandidateIdsJson:
        duplicateCandidateIdsJson ?? this.duplicateCandidateIdsJson,
    imageRetentionChoice: imageRetentionChoice ?? this.imageRetentionChoice,
    localImageReference: localImageReference.present
        ? localImageReference.value
        : this.localImageReference,
    imageHash: imageHash.present ? imageHash.value : this.imageHash,
    status: status ?? this.status,
    linkedTransactionId: linkedTransactionId.present
        ? linkedTransactionId.value
        : this.linkedTransactionId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ReceiptRow copyWithCompanion(ReceiptsCompanion data) {
    return ReceiptRow(
      id: data.id.present ? data.id.value : this.id,
      ownerScopeId: data.ownerScopeId.present
          ? data.ownerScopeId.value
          : this.ownerScopeId,
      documentType: data.documentType.present
          ? data.documentType.value
          : this.documentType,
      paymentStatus: data.paymentStatus.present
          ? data.paymentStatus.value
          : this.paymentStatus,
      merchantName: data.merchantName.present
          ? data.merchantName.value
          : this.merchantName,
      merchantPayeeId: data.merchantPayeeId.present
          ? data.merchantPayeeId.value
          : this.merchantPayeeId,
      merchantAddress: data.merchantAddress.present
          ? data.merchantAddress.value
          : this.merchantAddress,
      merchantTaxId: data.merchantTaxId.present
          ? data.merchantTaxId.value
          : this.merchantTaxId,
      receiptNumber: data.receiptNumber.present
          ? data.receiptNumber.value
          : this.receiptNumber,
      invoiceNumber: data.invoiceNumber.present
          ? data.invoiceNumber.value
          : this.invoiceNumber,
      purchaseDate: data.purchaseDate.present
          ? data.purchaseDate.value
          : this.purchaseDate,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      currency: data.currency.present ? data.currency.value : this.currency,
      subtotal: data.subtotal.present ? data.subtotal.value : this.subtotal,
      tax: data.tax.present ? data.tax.value : this.tax,
      discount: data.discount.present ? data.discount.value : this.discount,
      serviceCharge: data.serviceCharge.present
          ? data.serviceCharge.value
          : this.serviceCharge,
      tip: data.tip.present ? data.tip.value : this.tip,
      otherFees: data.otherFees.present ? data.otherFees.value : this.otherFees,
      total: data.total.present ? data.total.value : this.total,
      amountPaid: data.amountPaid.present
          ? data.amountPaid.value
          : this.amountPaid,
      amountDue: data.amountDue.present ? data.amountDue.value : this.amountDue,
      paymentMethodHint: data.paymentMethodHint.present
          ? data.paymentMethodHint.value
          : this.paymentMethodHint,
      accountHint: data.accountHint.present
          ? data.accountHint.value
          : this.accountHint,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      warningsJson: data.warningsJson.present
          ? data.warningsJson.value
          : this.warningsJson,
      duplicateCandidateIdsJson: data.duplicateCandidateIdsJson.present
          ? data.duplicateCandidateIdsJson.value
          : this.duplicateCandidateIdsJson,
      imageRetentionChoice: data.imageRetentionChoice.present
          ? data.imageRetentionChoice.value
          : this.imageRetentionChoice,
      localImageReference: data.localImageReference.present
          ? data.localImageReference.value
          : this.localImageReference,
      imageHash: data.imageHash.present ? data.imageHash.value : this.imageHash,
      status: data.status.present ? data.status.value : this.status,
      linkedTransactionId: data.linkedTransactionId.present
          ? data.linkedTransactionId.value
          : this.linkedTransactionId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReceiptRow(')
          ..write('id: $id, ')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('documentType: $documentType, ')
          ..write('paymentStatus: $paymentStatus, ')
          ..write('merchantName: $merchantName, ')
          ..write('merchantPayeeId: $merchantPayeeId, ')
          ..write('merchantAddress: $merchantAddress, ')
          ..write('merchantTaxId: $merchantTaxId, ')
          ..write('receiptNumber: $receiptNumber, ')
          ..write('invoiceNumber: $invoiceNumber, ')
          ..write('purchaseDate: $purchaseDate, ')
          ..write('dueDate: $dueDate, ')
          ..write('currency: $currency, ')
          ..write('subtotal: $subtotal, ')
          ..write('tax: $tax, ')
          ..write('discount: $discount, ')
          ..write('serviceCharge: $serviceCharge, ')
          ..write('tip: $tip, ')
          ..write('otherFees: $otherFees, ')
          ..write('total: $total, ')
          ..write('amountPaid: $amountPaid, ')
          ..write('amountDue: $amountDue, ')
          ..write('paymentMethodHint: $paymentMethodHint, ')
          ..write('accountHint: $accountHint, ')
          ..write('confidence: $confidence, ')
          ..write('warningsJson: $warningsJson, ')
          ..write('duplicateCandidateIdsJson: $duplicateCandidateIdsJson, ')
          ..write('imageRetentionChoice: $imageRetentionChoice, ')
          ..write('localImageReference: $localImageReference, ')
          ..write('imageHash: $imageHash, ')
          ..write('status: $status, ')
          ..write('linkedTransactionId: $linkedTransactionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    ownerScopeId,
    documentType,
    paymentStatus,
    merchantName,
    merchantPayeeId,
    merchantAddress,
    merchantTaxId,
    receiptNumber,
    invoiceNumber,
    purchaseDate,
    dueDate,
    currency,
    subtotal,
    tax,
    discount,
    serviceCharge,
    tip,
    otherFees,
    total,
    amountPaid,
    amountDue,
    paymentMethodHint,
    accountHint,
    confidence,
    warningsJson,
    duplicateCandidateIdsJson,
    imageRetentionChoice,
    localImageReference,
    imageHash,
    status,
    linkedTransactionId,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReceiptRow &&
          other.id == this.id &&
          other.ownerScopeId == this.ownerScopeId &&
          other.documentType == this.documentType &&
          other.paymentStatus == this.paymentStatus &&
          other.merchantName == this.merchantName &&
          other.merchantPayeeId == this.merchantPayeeId &&
          other.merchantAddress == this.merchantAddress &&
          other.merchantTaxId == this.merchantTaxId &&
          other.receiptNumber == this.receiptNumber &&
          other.invoiceNumber == this.invoiceNumber &&
          other.purchaseDate == this.purchaseDate &&
          other.dueDate == this.dueDate &&
          other.currency == this.currency &&
          other.subtotal == this.subtotal &&
          other.tax == this.tax &&
          other.discount == this.discount &&
          other.serviceCharge == this.serviceCharge &&
          other.tip == this.tip &&
          other.otherFees == this.otherFees &&
          other.total == this.total &&
          other.amountPaid == this.amountPaid &&
          other.amountDue == this.amountDue &&
          other.paymentMethodHint == this.paymentMethodHint &&
          other.accountHint == this.accountHint &&
          other.confidence == this.confidence &&
          other.warningsJson == this.warningsJson &&
          other.duplicateCandidateIdsJson == this.duplicateCandidateIdsJson &&
          other.imageRetentionChoice == this.imageRetentionChoice &&
          other.localImageReference == this.localImageReference &&
          other.imageHash == this.imageHash &&
          other.status == this.status &&
          other.linkedTransactionId == this.linkedTransactionId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ReceiptsCompanion extends UpdateCompanion<ReceiptRow> {
  final Value<String> id;
  final Value<String?> ownerScopeId;
  final Value<String> documentType;
  final Value<String> paymentStatus;
  final Value<String?> merchantName;
  final Value<String?> merchantPayeeId;
  final Value<String?> merchantAddress;
  final Value<String?> merchantTaxId;
  final Value<String?> receiptNumber;
  final Value<String?> invoiceNumber;
  final Value<DateTime?> purchaseDate;
  final Value<DateTime?> dueDate;
  final Value<String?> currency;
  final Value<String?> subtotal;
  final Value<String?> tax;
  final Value<String?> discount;
  final Value<String?> serviceCharge;
  final Value<String?> tip;
  final Value<String?> otherFees;
  final Value<String?> total;
  final Value<String?> amountPaid;
  final Value<String?> amountDue;
  final Value<String?> paymentMethodHint;
  final Value<String?> accountHint;
  final Value<int> confidence;
  final Value<String> warningsJson;
  final Value<String> duplicateCandidateIdsJson;
  final Value<String> imageRetentionChoice;
  final Value<String?> localImageReference;
  final Value<String?> imageHash;
  final Value<String> status;
  final Value<String?> linkedTransactionId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ReceiptsCompanion({
    this.id = const Value.absent(),
    this.ownerScopeId = const Value.absent(),
    this.documentType = const Value.absent(),
    this.paymentStatus = const Value.absent(),
    this.merchantName = const Value.absent(),
    this.merchantPayeeId = const Value.absent(),
    this.merchantAddress = const Value.absent(),
    this.merchantTaxId = const Value.absent(),
    this.receiptNumber = const Value.absent(),
    this.invoiceNumber = const Value.absent(),
    this.purchaseDate = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.currency = const Value.absent(),
    this.subtotal = const Value.absent(),
    this.tax = const Value.absent(),
    this.discount = const Value.absent(),
    this.serviceCharge = const Value.absent(),
    this.tip = const Value.absent(),
    this.otherFees = const Value.absent(),
    this.total = const Value.absent(),
    this.amountPaid = const Value.absent(),
    this.amountDue = const Value.absent(),
    this.paymentMethodHint = const Value.absent(),
    this.accountHint = const Value.absent(),
    this.confidence = const Value.absent(),
    this.warningsJson = const Value.absent(),
    this.duplicateCandidateIdsJson = const Value.absent(),
    this.imageRetentionChoice = const Value.absent(),
    this.localImageReference = const Value.absent(),
    this.imageHash = const Value.absent(),
    this.status = const Value.absent(),
    this.linkedTransactionId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReceiptsCompanion.insert({
    required String id,
    this.ownerScopeId = const Value.absent(),
    required String documentType,
    required String paymentStatus,
    this.merchantName = const Value.absent(),
    this.merchantPayeeId = const Value.absent(),
    this.merchantAddress = const Value.absent(),
    this.merchantTaxId = const Value.absent(),
    this.receiptNumber = const Value.absent(),
    this.invoiceNumber = const Value.absent(),
    this.purchaseDate = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.currency = const Value.absent(),
    this.subtotal = const Value.absent(),
    this.tax = const Value.absent(),
    this.discount = const Value.absent(),
    this.serviceCharge = const Value.absent(),
    this.tip = const Value.absent(),
    this.otherFees = const Value.absent(),
    this.total = const Value.absent(),
    this.amountPaid = const Value.absent(),
    this.amountDue = const Value.absent(),
    this.paymentMethodHint = const Value.absent(),
    this.accountHint = const Value.absent(),
    this.confidence = const Value.absent(),
    this.warningsJson = const Value.absent(),
    this.duplicateCandidateIdsJson = const Value.absent(),
    required String imageRetentionChoice,
    this.localImageReference = const Value.absent(),
    this.imageHash = const Value.absent(),
    required String status,
    this.linkedTransactionId = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       documentType = Value(documentType),
       paymentStatus = Value(paymentStatus),
       imageRetentionChoice = Value(imageRetentionChoice),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ReceiptRow> custom({
    Expression<String>? id,
    Expression<String>? ownerScopeId,
    Expression<String>? documentType,
    Expression<String>? paymentStatus,
    Expression<String>? merchantName,
    Expression<String>? merchantPayeeId,
    Expression<String>? merchantAddress,
    Expression<String>? merchantTaxId,
    Expression<String>? receiptNumber,
    Expression<String>? invoiceNumber,
    Expression<DateTime>? purchaseDate,
    Expression<DateTime>? dueDate,
    Expression<String>? currency,
    Expression<String>? subtotal,
    Expression<String>? tax,
    Expression<String>? discount,
    Expression<String>? serviceCharge,
    Expression<String>? tip,
    Expression<String>? otherFees,
    Expression<String>? total,
    Expression<String>? amountPaid,
    Expression<String>? amountDue,
    Expression<String>? paymentMethodHint,
    Expression<String>? accountHint,
    Expression<int>? confidence,
    Expression<String>? warningsJson,
    Expression<String>? duplicateCandidateIdsJson,
    Expression<String>? imageRetentionChoice,
    Expression<String>? localImageReference,
    Expression<String>? imageHash,
    Expression<String>? status,
    Expression<String>? linkedTransactionId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerScopeId != null) 'owner_scope_id': ownerScopeId,
      if (documentType != null) 'document_type': documentType,
      if (paymentStatus != null) 'payment_status': paymentStatus,
      if (merchantName != null) 'merchant_name': merchantName,
      if (merchantPayeeId != null) 'merchant_payee_id': merchantPayeeId,
      if (merchantAddress != null) 'merchant_address': merchantAddress,
      if (merchantTaxId != null) 'merchant_tax_id': merchantTaxId,
      if (receiptNumber != null) 'receipt_number': receiptNumber,
      if (invoiceNumber != null) 'invoice_number': invoiceNumber,
      if (purchaseDate != null) 'purchase_date': purchaseDate,
      if (dueDate != null) 'due_date': dueDate,
      if (currency != null) 'currency': currency,
      if (subtotal != null) 'subtotal': subtotal,
      if (tax != null) 'tax': tax,
      if (discount != null) 'discount': discount,
      if (serviceCharge != null) 'service_charge': serviceCharge,
      if (tip != null) 'tip': tip,
      if (otherFees != null) 'other_fees': otherFees,
      if (total != null) 'total': total,
      if (amountPaid != null) 'amount_paid': amountPaid,
      if (amountDue != null) 'amount_due': amountDue,
      if (paymentMethodHint != null) 'payment_method_hint': paymentMethodHint,
      if (accountHint != null) 'account_hint': accountHint,
      if (confidence != null) 'confidence': confidence,
      if (warningsJson != null) 'warnings_json': warningsJson,
      if (duplicateCandidateIdsJson != null)
        'duplicate_candidate_ids_json': duplicateCandidateIdsJson,
      if (imageRetentionChoice != null)
        'image_retention_choice': imageRetentionChoice,
      if (localImageReference != null)
        'local_image_reference': localImageReference,
      if (imageHash != null) 'image_hash': imageHash,
      if (status != null) 'status': status,
      if (linkedTransactionId != null)
        'linked_transaction_id': linkedTransactionId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReceiptsCompanion copyWith({
    Value<String>? id,
    Value<String?>? ownerScopeId,
    Value<String>? documentType,
    Value<String>? paymentStatus,
    Value<String?>? merchantName,
    Value<String?>? merchantPayeeId,
    Value<String?>? merchantAddress,
    Value<String?>? merchantTaxId,
    Value<String?>? receiptNumber,
    Value<String?>? invoiceNumber,
    Value<DateTime?>? purchaseDate,
    Value<DateTime?>? dueDate,
    Value<String?>? currency,
    Value<String?>? subtotal,
    Value<String?>? tax,
    Value<String?>? discount,
    Value<String?>? serviceCharge,
    Value<String?>? tip,
    Value<String?>? otherFees,
    Value<String?>? total,
    Value<String?>? amountPaid,
    Value<String?>? amountDue,
    Value<String?>? paymentMethodHint,
    Value<String?>? accountHint,
    Value<int>? confidence,
    Value<String>? warningsJson,
    Value<String>? duplicateCandidateIdsJson,
    Value<String>? imageRetentionChoice,
    Value<String?>? localImageReference,
    Value<String?>? imageHash,
    Value<String>? status,
    Value<String?>? linkedTransactionId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ReceiptsCompanion(
      id: id ?? this.id,
      ownerScopeId: ownerScopeId ?? this.ownerScopeId,
      documentType: documentType ?? this.documentType,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      merchantName: merchantName ?? this.merchantName,
      merchantPayeeId: merchantPayeeId ?? this.merchantPayeeId,
      merchantAddress: merchantAddress ?? this.merchantAddress,
      merchantTaxId: merchantTaxId ?? this.merchantTaxId,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      dueDate: dueDate ?? this.dueDate,
      currency: currency ?? this.currency,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      discount: discount ?? this.discount,
      serviceCharge: serviceCharge ?? this.serviceCharge,
      tip: tip ?? this.tip,
      otherFees: otherFees ?? this.otherFees,
      total: total ?? this.total,
      amountPaid: amountPaid ?? this.amountPaid,
      amountDue: amountDue ?? this.amountDue,
      paymentMethodHint: paymentMethodHint ?? this.paymentMethodHint,
      accountHint: accountHint ?? this.accountHint,
      confidence: confidence ?? this.confidence,
      warningsJson: warningsJson ?? this.warningsJson,
      duplicateCandidateIdsJson:
          duplicateCandidateIdsJson ?? this.duplicateCandidateIdsJson,
      imageRetentionChoice: imageRetentionChoice ?? this.imageRetentionChoice,
      localImageReference: localImageReference ?? this.localImageReference,
      imageHash: imageHash ?? this.imageHash,
      status: status ?? this.status,
      linkedTransactionId: linkedTransactionId ?? this.linkedTransactionId,
      createdAt: createdAt ?? this.createdAt,
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
    if (ownerScopeId.present) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId.value);
    }
    if (documentType.present) {
      map['document_type'] = Variable<String>(documentType.value);
    }
    if (paymentStatus.present) {
      map['payment_status'] = Variable<String>(paymentStatus.value);
    }
    if (merchantName.present) {
      map['merchant_name'] = Variable<String>(merchantName.value);
    }
    if (merchantPayeeId.present) {
      map['merchant_payee_id'] = Variable<String>(merchantPayeeId.value);
    }
    if (merchantAddress.present) {
      map['merchant_address'] = Variable<String>(merchantAddress.value);
    }
    if (merchantTaxId.present) {
      map['merchant_tax_id'] = Variable<String>(merchantTaxId.value);
    }
    if (receiptNumber.present) {
      map['receipt_number'] = Variable<String>(receiptNumber.value);
    }
    if (invoiceNumber.present) {
      map['invoice_number'] = Variable<String>(invoiceNumber.value);
    }
    if (purchaseDate.present) {
      map['purchase_date'] = Variable<DateTime>(purchaseDate.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (subtotal.present) {
      map['subtotal'] = Variable<String>(subtotal.value);
    }
    if (tax.present) {
      map['tax'] = Variable<String>(tax.value);
    }
    if (discount.present) {
      map['discount'] = Variable<String>(discount.value);
    }
    if (serviceCharge.present) {
      map['service_charge'] = Variable<String>(serviceCharge.value);
    }
    if (tip.present) {
      map['tip'] = Variable<String>(tip.value);
    }
    if (otherFees.present) {
      map['other_fees'] = Variable<String>(otherFees.value);
    }
    if (total.present) {
      map['total'] = Variable<String>(total.value);
    }
    if (amountPaid.present) {
      map['amount_paid'] = Variable<String>(amountPaid.value);
    }
    if (amountDue.present) {
      map['amount_due'] = Variable<String>(amountDue.value);
    }
    if (paymentMethodHint.present) {
      map['payment_method_hint'] = Variable<String>(paymentMethodHint.value);
    }
    if (accountHint.present) {
      map['account_hint'] = Variable<String>(accountHint.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<int>(confidence.value);
    }
    if (warningsJson.present) {
      map['warnings_json'] = Variable<String>(warningsJson.value);
    }
    if (duplicateCandidateIdsJson.present) {
      map['duplicate_candidate_ids_json'] = Variable<String>(
        duplicateCandidateIdsJson.value,
      );
    }
    if (imageRetentionChoice.present) {
      map['image_retention_choice'] = Variable<String>(
        imageRetentionChoice.value,
      );
    }
    if (localImageReference.present) {
      map['local_image_reference'] = Variable<String>(
        localImageReference.value,
      );
    }
    if (imageHash.present) {
      map['image_hash'] = Variable<String>(imageHash.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (linkedTransactionId.present) {
      map['linked_transaction_id'] = Variable<String>(
        linkedTransactionId.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReceiptsCompanion(')
          ..write('id: $id, ')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('documentType: $documentType, ')
          ..write('paymentStatus: $paymentStatus, ')
          ..write('merchantName: $merchantName, ')
          ..write('merchantPayeeId: $merchantPayeeId, ')
          ..write('merchantAddress: $merchantAddress, ')
          ..write('merchantTaxId: $merchantTaxId, ')
          ..write('receiptNumber: $receiptNumber, ')
          ..write('invoiceNumber: $invoiceNumber, ')
          ..write('purchaseDate: $purchaseDate, ')
          ..write('dueDate: $dueDate, ')
          ..write('currency: $currency, ')
          ..write('subtotal: $subtotal, ')
          ..write('tax: $tax, ')
          ..write('discount: $discount, ')
          ..write('serviceCharge: $serviceCharge, ')
          ..write('tip: $tip, ')
          ..write('otherFees: $otherFees, ')
          ..write('total: $total, ')
          ..write('amountPaid: $amountPaid, ')
          ..write('amountDue: $amountDue, ')
          ..write('paymentMethodHint: $paymentMethodHint, ')
          ..write('accountHint: $accountHint, ')
          ..write('confidence: $confidence, ')
          ..write('warningsJson: $warningsJson, ')
          ..write('duplicateCandidateIdsJson: $duplicateCandidateIdsJson, ')
          ..write('imageRetentionChoice: $imageRetentionChoice, ')
          ..write('localImageReference: $localImageReference, ')
          ..write('imageHash: $imageHash, ')
          ..write('status: $status, ')
          ..write('linkedTransactionId: $linkedTransactionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReceiptLineItemsTable extends ReceiptLineItems
    with TableInfo<$ReceiptLineItemsTable, ReceiptLineItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReceiptLineItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerScopeIdMeta = const VerificationMeta(
    'ownerScopeId',
  );
  @override
  late final GeneratedColumn<String> ownerScopeId = GeneratedColumn<String>(
    'owner_scope_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _receiptIdMeta = const VerificationMeta(
    'receiptId',
  );
  @override
  late final GeneratedColumn<String> receiptId = GeneratedColumn<String>(
    'receipt_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedDescriptionMeta =
      const VerificationMeta('normalizedDescription');
  @override
  late final GeneratedColumn<String> normalizedDescription =
      GeneratedColumn<String>(
        'normalized_description',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<String> quantity = GeneratedColumn<String>(
    'quantity',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitPriceMeta = const VerificationMeta(
    'unitPrice',
  );
  @override
  late final GeneratedColumn<String> unitPrice = GeneratedColumn<String>(
    'unit_price',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _discountMeta = const VerificationMeta(
    'discount',
  );
  @override
  late final GeneratedColumn<String> discount = GeneratedColumn<String>(
    'discount',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taxMeta = const VerificationMeta('tax');
  @override
  late final GeneratedColumn<String> tax = GeneratedColumn<String>(
    'tax',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalPriceMeta = const VerificationMeta(
    'totalPrice',
  );
  @override
  late final GeneratedColumn<String> totalPrice = GeneratedColumn<String>(
    'total_price',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryHintMeta = const VerificationMeta(
    'categoryHint',
  );
  @override
  late final GeneratedColumn<String> categoryHint = GeneratedColumn<String>(
    'category_hint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryConfidenceMeta =
      const VerificationMeta('categoryConfidence');
  @override
  late final GeneratedColumn<int> categoryConfidence = GeneratedColumn<int>(
    'category_confidence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _categorySuggestionSourceMeta =
      const VerificationMeta('categorySuggestionSource');
  @override
  late final GeneratedColumn<String> categorySuggestionSource =
      GeneratedColumn<String>(
        'category_suggestion_source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _categoryAlternativesJsonMeta =
      const VerificationMeta('categoryAlternativesJson');
  @override
  late final GeneratedColumn<String> categoryAlternativesJson =
      GeneratedColumn<String>(
        'category_alternatives_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _skuOrBarcodeMeta = const VerificationMeta(
    'skuOrBarcode',
  );
  @override
  late final GeneratedColumn<String> skuOrBarcode = GeneratedColumn<String>(
    'sku_or_barcode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _warningsJsonMeta = const VerificationMeta(
    'warningsJson',
  );
  @override
  late final GeneratedColumn<String> warningsJson = GeneratedColumn<String>(
    'warnings_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerScopeId,
    receiptId,
    description,
    normalizedDescription,
    quantity,
    unit,
    unitPrice,
    discount,
    tax,
    totalPrice,
    categoryId,
    categoryHint,
    categoryConfidence,
    categorySuggestionSource,
    categoryAlternativesJson,
    skuOrBarcode,
    warningsJson,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'receipt_line_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReceiptLineItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_scope_id')) {
      context.handle(
        _ownerScopeIdMeta,
        ownerScopeId.isAcceptableOrUnknown(
          data['owner_scope_id']!,
          _ownerScopeIdMeta,
        ),
      );
    }
    if (data.containsKey('receipt_id')) {
      context.handle(
        _receiptIdMeta,
        receiptId.isAcceptableOrUnknown(data['receipt_id']!, _receiptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_receiptIdMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('normalized_description')) {
      context.handle(
        _normalizedDescriptionMeta,
        normalizedDescription.isAcceptableOrUnknown(
          data['normalized_description']!,
          _normalizedDescriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedDescriptionMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('unit_price')) {
      context.handle(
        _unitPriceMeta,
        unitPrice.isAcceptableOrUnknown(data['unit_price']!, _unitPriceMeta),
      );
    }
    if (data.containsKey('discount')) {
      context.handle(
        _discountMeta,
        discount.isAcceptableOrUnknown(data['discount']!, _discountMeta),
      );
    }
    if (data.containsKey('tax')) {
      context.handle(
        _taxMeta,
        tax.isAcceptableOrUnknown(data['tax']!, _taxMeta),
      );
    }
    if (data.containsKey('total_price')) {
      context.handle(
        _totalPriceMeta,
        totalPrice.isAcceptableOrUnknown(data['total_price']!, _totalPriceMeta),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('category_hint')) {
      context.handle(
        _categoryHintMeta,
        categoryHint.isAcceptableOrUnknown(
          data['category_hint']!,
          _categoryHintMeta,
        ),
      );
    }
    if (data.containsKey('category_confidence')) {
      context.handle(
        _categoryConfidenceMeta,
        categoryConfidence.isAcceptableOrUnknown(
          data['category_confidence']!,
          _categoryConfidenceMeta,
        ),
      );
    }
    if (data.containsKey('category_suggestion_source')) {
      context.handle(
        _categorySuggestionSourceMeta,
        categorySuggestionSource.isAcceptableOrUnknown(
          data['category_suggestion_source']!,
          _categorySuggestionSourceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_categorySuggestionSourceMeta);
    }
    if (data.containsKey('category_alternatives_json')) {
      context.handle(
        _categoryAlternativesJsonMeta,
        categoryAlternativesJson.isAcceptableOrUnknown(
          data['category_alternatives_json']!,
          _categoryAlternativesJsonMeta,
        ),
      );
    }
    if (data.containsKey('sku_or_barcode')) {
      context.handle(
        _skuOrBarcodeMeta,
        skuOrBarcode.isAcceptableOrUnknown(
          data['sku_or_barcode']!,
          _skuOrBarcodeMeta,
        ),
      );
    }
    if (data.containsKey('warnings_json')) {
      context.handle(
        _warningsJsonMeta,
        warningsJson.isAcceptableOrUnknown(
          data['warnings_json']!,
          _warningsJsonMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReceiptLineItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReceiptLineItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_scope_id'],
      ),
      receiptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_id'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      normalizedDescription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_description'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quantity'],
      ),
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      ),
      unitPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_price'],
      ),
      discount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}discount'],
      ),
      tax: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tax'],
      ),
      totalPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}total_price'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      categoryHint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_hint'],
      ),
      categoryConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_confidence'],
      )!,
      categorySuggestionSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_suggestion_source'],
      )!,
      categoryAlternativesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_alternatives_json'],
      )!,
      skuOrBarcode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sku_or_barcode'],
      ),
      warningsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}warnings_json'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $ReceiptLineItemsTable createAlias(String alias) {
    return $ReceiptLineItemsTable(attachedDatabase, alias);
  }
}

class ReceiptLineItemRow extends DataClass
    implements Insertable<ReceiptLineItemRow> {
  final String id;
  final String? ownerScopeId;
  final String receiptId;
  final String description;
  final String normalizedDescription;
  final String? quantity;
  final String? unit;
  final String? unitPrice;
  final String? discount;
  final String? tax;
  final String? totalPrice;
  final String? categoryId;
  final String? categoryHint;
  final int categoryConfidence;
  final String categorySuggestionSource;
  final String categoryAlternativesJson;
  final String? skuOrBarcode;
  final String warningsJson;
  final int sortOrder;
  const ReceiptLineItemRow({
    required this.id,
    this.ownerScopeId,
    required this.receiptId,
    required this.description,
    required this.normalizedDescription,
    this.quantity,
    this.unit,
    this.unitPrice,
    this.discount,
    this.tax,
    this.totalPrice,
    this.categoryId,
    this.categoryHint,
    required this.categoryConfidence,
    required this.categorySuggestionSource,
    required this.categoryAlternativesJson,
    this.skuOrBarcode,
    required this.warningsJson,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || ownerScopeId != null) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId);
    }
    map['receipt_id'] = Variable<String>(receiptId);
    map['description'] = Variable<String>(description);
    map['normalized_description'] = Variable<String>(normalizedDescription);
    if (!nullToAbsent || quantity != null) {
      map['quantity'] = Variable<String>(quantity);
    }
    if (!nullToAbsent || unit != null) {
      map['unit'] = Variable<String>(unit);
    }
    if (!nullToAbsent || unitPrice != null) {
      map['unit_price'] = Variable<String>(unitPrice);
    }
    if (!nullToAbsent || discount != null) {
      map['discount'] = Variable<String>(discount);
    }
    if (!nullToAbsent || tax != null) {
      map['tax'] = Variable<String>(tax);
    }
    if (!nullToAbsent || totalPrice != null) {
      map['total_price'] = Variable<String>(totalPrice);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || categoryHint != null) {
      map['category_hint'] = Variable<String>(categoryHint);
    }
    map['category_confidence'] = Variable<int>(categoryConfidence);
    map['category_suggestion_source'] = Variable<String>(
      categorySuggestionSource,
    );
    map['category_alternatives_json'] = Variable<String>(
      categoryAlternativesJson,
    );
    if (!nullToAbsent || skuOrBarcode != null) {
      map['sku_or_barcode'] = Variable<String>(skuOrBarcode);
    }
    map['warnings_json'] = Variable<String>(warningsJson);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  ReceiptLineItemsCompanion toCompanion(bool nullToAbsent) {
    return ReceiptLineItemsCompanion(
      id: Value(id),
      ownerScopeId: ownerScopeId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerScopeId),
      receiptId: Value(receiptId),
      description: Value(description),
      normalizedDescription: Value(normalizedDescription),
      quantity: quantity == null && nullToAbsent
          ? const Value.absent()
          : Value(quantity),
      unit: unit == null && nullToAbsent ? const Value.absent() : Value(unit),
      unitPrice: unitPrice == null && nullToAbsent
          ? const Value.absent()
          : Value(unitPrice),
      discount: discount == null && nullToAbsent
          ? const Value.absent()
          : Value(discount),
      tax: tax == null && nullToAbsent ? const Value.absent() : Value(tax),
      totalPrice: totalPrice == null && nullToAbsent
          ? const Value.absent()
          : Value(totalPrice),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      categoryHint: categoryHint == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryHint),
      categoryConfidence: Value(categoryConfidence),
      categorySuggestionSource: Value(categorySuggestionSource),
      categoryAlternativesJson: Value(categoryAlternativesJson),
      skuOrBarcode: skuOrBarcode == null && nullToAbsent
          ? const Value.absent()
          : Value(skuOrBarcode),
      warningsJson: Value(warningsJson),
      sortOrder: Value(sortOrder),
    );
  }

  factory ReceiptLineItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReceiptLineItemRow(
      id: serializer.fromJson<String>(json['id']),
      ownerScopeId: serializer.fromJson<String?>(json['ownerScopeId']),
      receiptId: serializer.fromJson<String>(json['receiptId']),
      description: serializer.fromJson<String>(json['description']),
      normalizedDescription: serializer.fromJson<String>(
        json['normalizedDescription'],
      ),
      quantity: serializer.fromJson<String?>(json['quantity']),
      unit: serializer.fromJson<String?>(json['unit']),
      unitPrice: serializer.fromJson<String?>(json['unitPrice']),
      discount: serializer.fromJson<String?>(json['discount']),
      tax: serializer.fromJson<String?>(json['tax']),
      totalPrice: serializer.fromJson<String?>(json['totalPrice']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      categoryHint: serializer.fromJson<String?>(json['categoryHint']),
      categoryConfidence: serializer.fromJson<int>(json['categoryConfidence']),
      categorySuggestionSource: serializer.fromJson<String>(
        json['categorySuggestionSource'],
      ),
      categoryAlternativesJson: serializer.fromJson<String>(
        json['categoryAlternativesJson'],
      ),
      skuOrBarcode: serializer.fromJson<String?>(json['skuOrBarcode']),
      warningsJson: serializer.fromJson<String>(json['warningsJson']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerScopeId': serializer.toJson<String?>(ownerScopeId),
      'receiptId': serializer.toJson<String>(receiptId),
      'description': serializer.toJson<String>(description),
      'normalizedDescription': serializer.toJson<String>(normalizedDescription),
      'quantity': serializer.toJson<String?>(quantity),
      'unit': serializer.toJson<String?>(unit),
      'unitPrice': serializer.toJson<String?>(unitPrice),
      'discount': serializer.toJson<String?>(discount),
      'tax': serializer.toJson<String?>(tax),
      'totalPrice': serializer.toJson<String?>(totalPrice),
      'categoryId': serializer.toJson<String?>(categoryId),
      'categoryHint': serializer.toJson<String?>(categoryHint),
      'categoryConfidence': serializer.toJson<int>(categoryConfidence),
      'categorySuggestionSource': serializer.toJson<String>(
        categorySuggestionSource,
      ),
      'categoryAlternativesJson': serializer.toJson<String>(
        categoryAlternativesJson,
      ),
      'skuOrBarcode': serializer.toJson<String?>(skuOrBarcode),
      'warningsJson': serializer.toJson<String>(warningsJson),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  ReceiptLineItemRow copyWith({
    String? id,
    Value<String?> ownerScopeId = const Value.absent(),
    String? receiptId,
    String? description,
    String? normalizedDescription,
    Value<String?> quantity = const Value.absent(),
    Value<String?> unit = const Value.absent(),
    Value<String?> unitPrice = const Value.absent(),
    Value<String?> discount = const Value.absent(),
    Value<String?> tax = const Value.absent(),
    Value<String?> totalPrice = const Value.absent(),
    Value<String?> categoryId = const Value.absent(),
    Value<String?> categoryHint = const Value.absent(),
    int? categoryConfidence,
    String? categorySuggestionSource,
    String? categoryAlternativesJson,
    Value<String?> skuOrBarcode = const Value.absent(),
    String? warningsJson,
    int? sortOrder,
  }) => ReceiptLineItemRow(
    id: id ?? this.id,
    ownerScopeId: ownerScopeId.present ? ownerScopeId.value : this.ownerScopeId,
    receiptId: receiptId ?? this.receiptId,
    description: description ?? this.description,
    normalizedDescription: normalizedDescription ?? this.normalizedDescription,
    quantity: quantity.present ? quantity.value : this.quantity,
    unit: unit.present ? unit.value : this.unit,
    unitPrice: unitPrice.present ? unitPrice.value : this.unitPrice,
    discount: discount.present ? discount.value : this.discount,
    tax: tax.present ? tax.value : this.tax,
    totalPrice: totalPrice.present ? totalPrice.value : this.totalPrice,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    categoryHint: categoryHint.present ? categoryHint.value : this.categoryHint,
    categoryConfidence: categoryConfidence ?? this.categoryConfidence,
    categorySuggestionSource:
        categorySuggestionSource ?? this.categorySuggestionSource,
    categoryAlternativesJson:
        categoryAlternativesJson ?? this.categoryAlternativesJson,
    skuOrBarcode: skuOrBarcode.present ? skuOrBarcode.value : this.skuOrBarcode,
    warningsJson: warningsJson ?? this.warningsJson,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  ReceiptLineItemRow copyWithCompanion(ReceiptLineItemsCompanion data) {
    return ReceiptLineItemRow(
      id: data.id.present ? data.id.value : this.id,
      ownerScopeId: data.ownerScopeId.present
          ? data.ownerScopeId.value
          : this.ownerScopeId,
      receiptId: data.receiptId.present ? data.receiptId.value : this.receiptId,
      description: data.description.present
          ? data.description.value
          : this.description,
      normalizedDescription: data.normalizedDescription.present
          ? data.normalizedDescription.value
          : this.normalizedDescription,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unit: data.unit.present ? data.unit.value : this.unit,
      unitPrice: data.unitPrice.present ? data.unitPrice.value : this.unitPrice,
      discount: data.discount.present ? data.discount.value : this.discount,
      tax: data.tax.present ? data.tax.value : this.tax,
      totalPrice: data.totalPrice.present
          ? data.totalPrice.value
          : this.totalPrice,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      categoryHint: data.categoryHint.present
          ? data.categoryHint.value
          : this.categoryHint,
      categoryConfidence: data.categoryConfidence.present
          ? data.categoryConfidence.value
          : this.categoryConfidence,
      categorySuggestionSource: data.categorySuggestionSource.present
          ? data.categorySuggestionSource.value
          : this.categorySuggestionSource,
      categoryAlternativesJson: data.categoryAlternativesJson.present
          ? data.categoryAlternativesJson.value
          : this.categoryAlternativesJson,
      skuOrBarcode: data.skuOrBarcode.present
          ? data.skuOrBarcode.value
          : this.skuOrBarcode,
      warningsJson: data.warningsJson.present
          ? data.warningsJson.value
          : this.warningsJson,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReceiptLineItemRow(')
          ..write('id: $id, ')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('receiptId: $receiptId, ')
          ..write('description: $description, ')
          ..write('normalizedDescription: $normalizedDescription, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('discount: $discount, ')
          ..write('tax: $tax, ')
          ..write('totalPrice: $totalPrice, ')
          ..write('categoryId: $categoryId, ')
          ..write('categoryHint: $categoryHint, ')
          ..write('categoryConfidence: $categoryConfidence, ')
          ..write('categorySuggestionSource: $categorySuggestionSource, ')
          ..write('categoryAlternativesJson: $categoryAlternativesJson, ')
          ..write('skuOrBarcode: $skuOrBarcode, ')
          ..write('warningsJson: $warningsJson, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerScopeId,
    receiptId,
    description,
    normalizedDescription,
    quantity,
    unit,
    unitPrice,
    discount,
    tax,
    totalPrice,
    categoryId,
    categoryHint,
    categoryConfidence,
    categorySuggestionSource,
    categoryAlternativesJson,
    skuOrBarcode,
    warningsJson,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReceiptLineItemRow &&
          other.id == this.id &&
          other.ownerScopeId == this.ownerScopeId &&
          other.receiptId == this.receiptId &&
          other.description == this.description &&
          other.normalizedDescription == this.normalizedDescription &&
          other.quantity == this.quantity &&
          other.unit == this.unit &&
          other.unitPrice == this.unitPrice &&
          other.discount == this.discount &&
          other.tax == this.tax &&
          other.totalPrice == this.totalPrice &&
          other.categoryId == this.categoryId &&
          other.categoryHint == this.categoryHint &&
          other.categoryConfidence == this.categoryConfidence &&
          other.categorySuggestionSource == this.categorySuggestionSource &&
          other.categoryAlternativesJson == this.categoryAlternativesJson &&
          other.skuOrBarcode == this.skuOrBarcode &&
          other.warningsJson == this.warningsJson &&
          other.sortOrder == this.sortOrder);
}

class ReceiptLineItemsCompanion extends UpdateCompanion<ReceiptLineItemRow> {
  final Value<String> id;
  final Value<String?> ownerScopeId;
  final Value<String> receiptId;
  final Value<String> description;
  final Value<String> normalizedDescription;
  final Value<String?> quantity;
  final Value<String?> unit;
  final Value<String?> unitPrice;
  final Value<String?> discount;
  final Value<String?> tax;
  final Value<String?> totalPrice;
  final Value<String?> categoryId;
  final Value<String?> categoryHint;
  final Value<int> categoryConfidence;
  final Value<String> categorySuggestionSource;
  final Value<String> categoryAlternativesJson;
  final Value<String?> skuOrBarcode;
  final Value<String> warningsJson;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const ReceiptLineItemsCompanion({
    this.id = const Value.absent(),
    this.ownerScopeId = const Value.absent(),
    this.receiptId = const Value.absent(),
    this.description = const Value.absent(),
    this.normalizedDescription = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unit = const Value.absent(),
    this.unitPrice = const Value.absent(),
    this.discount = const Value.absent(),
    this.tax = const Value.absent(),
    this.totalPrice = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.categoryHint = const Value.absent(),
    this.categoryConfidence = const Value.absent(),
    this.categorySuggestionSource = const Value.absent(),
    this.categoryAlternativesJson = const Value.absent(),
    this.skuOrBarcode = const Value.absent(),
    this.warningsJson = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReceiptLineItemsCompanion.insert({
    required String id,
    this.ownerScopeId = const Value.absent(),
    required String receiptId,
    required String description,
    required String normalizedDescription,
    this.quantity = const Value.absent(),
    this.unit = const Value.absent(),
    this.unitPrice = const Value.absent(),
    this.discount = const Value.absent(),
    this.tax = const Value.absent(),
    this.totalPrice = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.categoryHint = const Value.absent(),
    this.categoryConfidence = const Value.absent(),
    required String categorySuggestionSource,
    this.categoryAlternativesJson = const Value.absent(),
    this.skuOrBarcode = const Value.absent(),
    this.warningsJson = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       receiptId = Value(receiptId),
       description = Value(description),
       normalizedDescription = Value(normalizedDescription),
       categorySuggestionSource = Value(categorySuggestionSource);
  static Insertable<ReceiptLineItemRow> custom({
    Expression<String>? id,
    Expression<String>? ownerScopeId,
    Expression<String>? receiptId,
    Expression<String>? description,
    Expression<String>? normalizedDescription,
    Expression<String>? quantity,
    Expression<String>? unit,
    Expression<String>? unitPrice,
    Expression<String>? discount,
    Expression<String>? tax,
    Expression<String>? totalPrice,
    Expression<String>? categoryId,
    Expression<String>? categoryHint,
    Expression<int>? categoryConfidence,
    Expression<String>? categorySuggestionSource,
    Expression<String>? categoryAlternativesJson,
    Expression<String>? skuOrBarcode,
    Expression<String>? warningsJson,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerScopeId != null) 'owner_scope_id': ownerScopeId,
      if (receiptId != null) 'receipt_id': receiptId,
      if (description != null) 'description': description,
      if (normalizedDescription != null)
        'normalized_description': normalizedDescription,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (unitPrice != null) 'unit_price': unitPrice,
      if (discount != null) 'discount': discount,
      if (tax != null) 'tax': tax,
      if (totalPrice != null) 'total_price': totalPrice,
      if (categoryId != null) 'category_id': categoryId,
      if (categoryHint != null) 'category_hint': categoryHint,
      if (categoryConfidence != null) 'category_confidence': categoryConfidence,
      if (categorySuggestionSource != null)
        'category_suggestion_source': categorySuggestionSource,
      if (categoryAlternativesJson != null)
        'category_alternatives_json': categoryAlternativesJson,
      if (skuOrBarcode != null) 'sku_or_barcode': skuOrBarcode,
      if (warningsJson != null) 'warnings_json': warningsJson,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReceiptLineItemsCompanion copyWith({
    Value<String>? id,
    Value<String?>? ownerScopeId,
    Value<String>? receiptId,
    Value<String>? description,
    Value<String>? normalizedDescription,
    Value<String?>? quantity,
    Value<String?>? unit,
    Value<String?>? unitPrice,
    Value<String?>? discount,
    Value<String?>? tax,
    Value<String?>? totalPrice,
    Value<String?>? categoryId,
    Value<String?>? categoryHint,
    Value<int>? categoryConfidence,
    Value<String>? categorySuggestionSource,
    Value<String>? categoryAlternativesJson,
    Value<String?>? skuOrBarcode,
    Value<String>? warningsJson,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return ReceiptLineItemsCompanion(
      id: id ?? this.id,
      ownerScopeId: ownerScopeId ?? this.ownerScopeId,
      receiptId: receiptId ?? this.receiptId,
      description: description ?? this.description,
      normalizedDescription:
          normalizedDescription ?? this.normalizedDescription,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      totalPrice: totalPrice ?? this.totalPrice,
      categoryId: categoryId ?? this.categoryId,
      categoryHint: categoryHint ?? this.categoryHint,
      categoryConfidence: categoryConfidence ?? this.categoryConfidence,
      categorySuggestionSource:
          categorySuggestionSource ?? this.categorySuggestionSource,
      categoryAlternativesJson:
          categoryAlternativesJson ?? this.categoryAlternativesJson,
      skuOrBarcode: skuOrBarcode ?? this.skuOrBarcode,
      warningsJson: warningsJson ?? this.warningsJson,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerScopeId.present) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId.value);
    }
    if (receiptId.present) {
      map['receipt_id'] = Variable<String>(receiptId.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (normalizedDescription.present) {
      map['normalized_description'] = Variable<String>(
        normalizedDescription.value,
      );
    }
    if (quantity.present) {
      map['quantity'] = Variable<String>(quantity.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (unitPrice.present) {
      map['unit_price'] = Variable<String>(unitPrice.value);
    }
    if (discount.present) {
      map['discount'] = Variable<String>(discount.value);
    }
    if (tax.present) {
      map['tax'] = Variable<String>(tax.value);
    }
    if (totalPrice.present) {
      map['total_price'] = Variable<String>(totalPrice.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (categoryHint.present) {
      map['category_hint'] = Variable<String>(categoryHint.value);
    }
    if (categoryConfidence.present) {
      map['category_confidence'] = Variable<int>(categoryConfidence.value);
    }
    if (categorySuggestionSource.present) {
      map['category_suggestion_source'] = Variable<String>(
        categorySuggestionSource.value,
      );
    }
    if (categoryAlternativesJson.present) {
      map['category_alternatives_json'] = Variable<String>(
        categoryAlternativesJson.value,
      );
    }
    if (skuOrBarcode.present) {
      map['sku_or_barcode'] = Variable<String>(skuOrBarcode.value);
    }
    if (warningsJson.present) {
      map['warnings_json'] = Variable<String>(warningsJson.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReceiptLineItemsCompanion(')
          ..write('id: $id, ')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('receiptId: $receiptId, ')
          ..write('description: $description, ')
          ..write('normalizedDescription: $normalizedDescription, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('discount: $discount, ')
          ..write('tax: $tax, ')
          ..write('totalPrice: $totalPrice, ')
          ..write('categoryId: $categoryId, ')
          ..write('categoryHint: $categoryHint, ')
          ..write('categoryConfidence: $categoryConfidence, ')
          ..write('categorySuggestionSource: $categorySuggestionSource, ')
          ..write('categoryAlternativesJson: $categoryAlternativesJson, ')
          ..write('skuOrBarcode: $skuOrBarcode, ')
          ..write('warningsJson: $warningsJson, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransactionSplitsTable extends TransactionSplits
    with TableInfo<$TransactionSplitsTable, TransactionSplitRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionSplitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerScopeIdMeta = const VerificationMeta(
    'ownerScopeId',
  );
  @override
  late final GeneratedColumn<String> ownerScopeId = GeneratedColumn<String>(
    'owner_scope_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _receiptIdMeta = const VerificationMeta(
    'receiptId',
  );
  @override
  late final GeneratedColumn<String> receiptId = GeneratedColumn<String>(
    'receipt_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<String> transactionId = GeneratedColumn<String>(
    'transaction_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _draftIdMeta = const VerificationMeta(
    'draftId',
  );
  @override
  late final GeneratedColumn<String> draftId = GeneratedColumn<String>(
    'draft_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<String> amount = GeneratedColumn<String>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceReceiptItemIdsJsonMeta =
      const VerificationMeta('sourceReceiptItemIdsJson');
  @override
  late final GeneratedColumn<String> sourceReceiptItemIdsJson =
      GeneratedColumn<String>(
        'source_receipt_item_ids_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerScopeId,
    receiptId,
    transactionId,
    draftId,
    categoryId,
    amount,
    sourceReceiptItemIdsJson,
    description,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transaction_splits';
  @override
  VerificationContext validateIntegrity(
    Insertable<TransactionSplitRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_scope_id')) {
      context.handle(
        _ownerScopeIdMeta,
        ownerScopeId.isAcceptableOrUnknown(
          data['owner_scope_id']!,
          _ownerScopeIdMeta,
        ),
      );
    }
    if (data.containsKey('receipt_id')) {
      context.handle(
        _receiptIdMeta,
        receiptId.isAcceptableOrUnknown(data['receipt_id']!, _receiptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_receiptIdMeta);
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    }
    if (data.containsKey('draft_id')) {
      context.handle(
        _draftIdMeta,
        draftId.isAcceptableOrUnknown(data['draft_id']!, _draftIdMeta),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('source_receipt_item_ids_json')) {
      context.handle(
        _sourceReceiptItemIdsJsonMeta,
        sourceReceiptItemIdsJson.isAcceptableOrUnknown(
          data['source_receipt_item_ids_json']!,
          _sourceReceiptItemIdsJsonMeta,
        ),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TransactionSplitRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransactionSplitRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_scope_id'],
      ),
      receiptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_id'],
      )!,
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transaction_id'],
      ),
      draftId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}draft_id'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}amount'],
      )!,
      sourceReceiptItemIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_receipt_item_ids_json'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
    );
  }

  @override
  $TransactionSplitsTable createAlias(String alias) {
    return $TransactionSplitsTable(attachedDatabase, alias);
  }
}

class TransactionSplitRow extends DataClass
    implements Insertable<TransactionSplitRow> {
  final String id;
  final String? ownerScopeId;
  final String receiptId;
  final String? transactionId;
  final String? draftId;
  final String categoryId;
  final String amount;
  final String sourceReceiptItemIdsJson;
  final String? description;
  const TransactionSplitRow({
    required this.id,
    this.ownerScopeId,
    required this.receiptId,
    this.transactionId,
    this.draftId,
    required this.categoryId,
    required this.amount,
    required this.sourceReceiptItemIdsJson,
    this.description,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || ownerScopeId != null) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId);
    }
    map['receipt_id'] = Variable<String>(receiptId);
    if (!nullToAbsent || transactionId != null) {
      map['transaction_id'] = Variable<String>(transactionId);
    }
    if (!nullToAbsent || draftId != null) {
      map['draft_id'] = Variable<String>(draftId);
    }
    map['category_id'] = Variable<String>(categoryId);
    map['amount'] = Variable<String>(amount);
    map['source_receipt_item_ids_json'] = Variable<String>(
      sourceReceiptItemIdsJson,
    );
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    return map;
  }

  TransactionSplitsCompanion toCompanion(bool nullToAbsent) {
    return TransactionSplitsCompanion(
      id: Value(id),
      ownerScopeId: ownerScopeId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerScopeId),
      receiptId: Value(receiptId),
      transactionId: transactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(transactionId),
      draftId: draftId == null && nullToAbsent
          ? const Value.absent()
          : Value(draftId),
      categoryId: Value(categoryId),
      amount: Value(amount),
      sourceReceiptItemIdsJson: Value(sourceReceiptItemIdsJson),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
    );
  }

  factory TransactionSplitRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransactionSplitRow(
      id: serializer.fromJson<String>(json['id']),
      ownerScopeId: serializer.fromJson<String?>(json['ownerScopeId']),
      receiptId: serializer.fromJson<String>(json['receiptId']),
      transactionId: serializer.fromJson<String?>(json['transactionId']),
      draftId: serializer.fromJson<String?>(json['draftId']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      amount: serializer.fromJson<String>(json['amount']),
      sourceReceiptItemIdsJson: serializer.fromJson<String>(
        json['sourceReceiptItemIdsJson'],
      ),
      description: serializer.fromJson<String?>(json['description']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerScopeId': serializer.toJson<String?>(ownerScopeId),
      'receiptId': serializer.toJson<String>(receiptId),
      'transactionId': serializer.toJson<String?>(transactionId),
      'draftId': serializer.toJson<String?>(draftId),
      'categoryId': serializer.toJson<String>(categoryId),
      'amount': serializer.toJson<String>(amount),
      'sourceReceiptItemIdsJson': serializer.toJson<String>(
        sourceReceiptItemIdsJson,
      ),
      'description': serializer.toJson<String?>(description),
    };
  }

  TransactionSplitRow copyWith({
    String? id,
    Value<String?> ownerScopeId = const Value.absent(),
    String? receiptId,
    Value<String?> transactionId = const Value.absent(),
    Value<String?> draftId = const Value.absent(),
    String? categoryId,
    String? amount,
    String? sourceReceiptItemIdsJson,
    Value<String?> description = const Value.absent(),
  }) => TransactionSplitRow(
    id: id ?? this.id,
    ownerScopeId: ownerScopeId.present ? ownerScopeId.value : this.ownerScopeId,
    receiptId: receiptId ?? this.receiptId,
    transactionId: transactionId.present
        ? transactionId.value
        : this.transactionId,
    draftId: draftId.present ? draftId.value : this.draftId,
    categoryId: categoryId ?? this.categoryId,
    amount: amount ?? this.amount,
    sourceReceiptItemIdsJson:
        sourceReceiptItemIdsJson ?? this.sourceReceiptItemIdsJson,
    description: description.present ? description.value : this.description,
  );
  TransactionSplitRow copyWithCompanion(TransactionSplitsCompanion data) {
    return TransactionSplitRow(
      id: data.id.present ? data.id.value : this.id,
      ownerScopeId: data.ownerScopeId.present
          ? data.ownerScopeId.value
          : this.ownerScopeId,
      receiptId: data.receiptId.present ? data.receiptId.value : this.receiptId,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      draftId: data.draftId.present ? data.draftId.value : this.draftId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      amount: data.amount.present ? data.amount.value : this.amount,
      sourceReceiptItemIdsJson: data.sourceReceiptItemIdsJson.present
          ? data.sourceReceiptItemIdsJson.value
          : this.sourceReceiptItemIdsJson,
      description: data.description.present
          ? data.description.value
          : this.description,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransactionSplitRow(')
          ..write('id: $id, ')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('receiptId: $receiptId, ')
          ..write('transactionId: $transactionId, ')
          ..write('draftId: $draftId, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount, ')
          ..write('sourceReceiptItemIdsJson: $sourceReceiptItemIdsJson, ')
          ..write('description: $description')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerScopeId,
    receiptId,
    transactionId,
    draftId,
    categoryId,
    amount,
    sourceReceiptItemIdsJson,
    description,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionSplitRow &&
          other.id == this.id &&
          other.ownerScopeId == this.ownerScopeId &&
          other.receiptId == this.receiptId &&
          other.transactionId == this.transactionId &&
          other.draftId == this.draftId &&
          other.categoryId == this.categoryId &&
          other.amount == this.amount &&
          other.sourceReceiptItemIdsJson == this.sourceReceiptItemIdsJson &&
          other.description == this.description);
}

class TransactionSplitsCompanion extends UpdateCompanion<TransactionSplitRow> {
  final Value<String> id;
  final Value<String?> ownerScopeId;
  final Value<String> receiptId;
  final Value<String?> transactionId;
  final Value<String?> draftId;
  final Value<String> categoryId;
  final Value<String> amount;
  final Value<String> sourceReceiptItemIdsJson;
  final Value<String?> description;
  final Value<int> rowid;
  const TransactionSplitsCompanion({
    this.id = const Value.absent(),
    this.ownerScopeId = const Value.absent(),
    this.receiptId = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.draftId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.amount = const Value.absent(),
    this.sourceReceiptItemIdsJson = const Value.absent(),
    this.description = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionSplitsCompanion.insert({
    required String id,
    this.ownerScopeId = const Value.absent(),
    required String receiptId,
    this.transactionId = const Value.absent(),
    this.draftId = const Value.absent(),
    required String categoryId,
    required String amount,
    this.sourceReceiptItemIdsJson = const Value.absent(),
    this.description = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       receiptId = Value(receiptId),
       categoryId = Value(categoryId),
       amount = Value(amount);
  static Insertable<TransactionSplitRow> custom({
    Expression<String>? id,
    Expression<String>? ownerScopeId,
    Expression<String>? receiptId,
    Expression<String>? transactionId,
    Expression<String>? draftId,
    Expression<String>? categoryId,
    Expression<String>? amount,
    Expression<String>? sourceReceiptItemIdsJson,
    Expression<String>? description,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerScopeId != null) 'owner_scope_id': ownerScopeId,
      if (receiptId != null) 'receipt_id': receiptId,
      if (transactionId != null) 'transaction_id': transactionId,
      if (draftId != null) 'draft_id': draftId,
      if (categoryId != null) 'category_id': categoryId,
      if (amount != null) 'amount': amount,
      if (sourceReceiptItemIdsJson != null)
        'source_receipt_item_ids_json': sourceReceiptItemIdsJson,
      if (description != null) 'description': description,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionSplitsCompanion copyWith({
    Value<String>? id,
    Value<String?>? ownerScopeId,
    Value<String>? receiptId,
    Value<String?>? transactionId,
    Value<String?>? draftId,
    Value<String>? categoryId,
    Value<String>? amount,
    Value<String>? sourceReceiptItemIdsJson,
    Value<String?>? description,
    Value<int>? rowid,
  }) {
    return TransactionSplitsCompanion(
      id: id ?? this.id,
      ownerScopeId: ownerScopeId ?? this.ownerScopeId,
      receiptId: receiptId ?? this.receiptId,
      transactionId: transactionId ?? this.transactionId,
      draftId: draftId ?? this.draftId,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      sourceReceiptItemIdsJson:
          sourceReceiptItemIdsJson ?? this.sourceReceiptItemIdsJson,
      description: description ?? this.description,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerScopeId.present) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId.value);
    }
    if (receiptId.present) {
      map['receipt_id'] = Variable<String>(receiptId.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<String>(transactionId.value);
    }
    if (draftId.present) {
      map['draft_id'] = Variable<String>(draftId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<String>(amount.value);
    }
    if (sourceReceiptItemIdsJson.present) {
      map['source_receipt_item_ids_json'] = Variable<String>(
        sourceReceiptItemIdsJson.value,
      );
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionSplitsCompanion(')
          ..write('id: $id, ')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('receiptId: $receiptId, ')
          ..write('transactionId: $transactionId, ')
          ..write('draftId: $draftId, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount, ')
          ..write('sourceReceiptItemIdsJson: $sourceReceiptItemIdsJson, ')
          ..write('description: $description, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OwnerScopeMigrationAuditsTable extends OwnerScopeMigrationAudits
    with
        TableInfo<
          $OwnerScopeMigrationAuditsTable,
          OwnerScopeMigrationAuditRow
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OwnerScopeMigrationAuditsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerScopeIdMeta = const VerificationMeta(
    'ownerScopeId',
  );
  @override
  late final GeneratedColumn<String> ownerScopeId = GeneratedColumn<String>(
    'owner_scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _boundedCountsJsonMeta = const VerificationMeta(
    'boundedCountsJson',
  );
  @override
  late final GeneratedColumn<String> boundedCountsJson =
      GeneratedColumn<String>(
        'bounded_counts_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _safeFailureCodeMeta = const VerificationMeta(
    'safeFailureCode',
  );
  @override
  late final GeneratedColumn<String> safeFailureCode = GeneratedColumn<String>(
    'safe_failure_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerScopeId,
    status,
    boundedCountsJson,
    safeFailureCode,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'owner_scope_migration_audits';
  @override
  VerificationContext validateIntegrity(
    Insertable<OwnerScopeMigrationAuditRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_scope_id')) {
      context.handle(
        _ownerScopeIdMeta,
        ownerScopeId.isAcceptableOrUnknown(
          data['owner_scope_id']!,
          _ownerScopeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerScopeIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('bounded_counts_json')) {
      context.handle(
        _boundedCountsJsonMeta,
        boundedCountsJson.isAcceptableOrUnknown(
          data['bounded_counts_json']!,
          _boundedCountsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_boundedCountsJsonMeta);
    }
    if (data.containsKey('safe_failure_code')) {
      context.handle(
        _safeFailureCodeMeta,
        safeFailureCode.isAcceptableOrUnknown(
          data['safe_failure_code']!,
          _safeFailureCodeMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
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
  OwnerScopeMigrationAuditRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OwnerScopeMigrationAuditRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_scope_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      boundedCountsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bounded_counts_json'],
      )!,
      safeFailureCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}safe_failure_code'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $OwnerScopeMigrationAuditsTable createAlias(String alias) {
    return $OwnerScopeMigrationAuditsTable(attachedDatabase, alias);
  }
}

class OwnerScopeMigrationAuditRow extends DataClass
    implements Insertable<OwnerScopeMigrationAuditRow> {
  final String id;
  final String ownerScopeId;
  final String status;
  final String boundedCountsJson;
  final String? safeFailureCode;
  final DateTime createdAt;
  final DateTime updatedAt;
  const OwnerScopeMigrationAuditRow({
    required this.id,
    required this.ownerScopeId,
    required this.status,
    required this.boundedCountsJson,
    this.safeFailureCode,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_scope_id'] = Variable<String>(ownerScopeId);
    map['status'] = Variable<String>(status);
    map['bounded_counts_json'] = Variable<String>(boundedCountsJson);
    if (!nullToAbsent || safeFailureCode != null) {
      map['safe_failure_code'] = Variable<String>(safeFailureCode);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  OwnerScopeMigrationAuditsCompanion toCompanion(bool nullToAbsent) {
    return OwnerScopeMigrationAuditsCompanion(
      id: Value(id),
      ownerScopeId: Value(ownerScopeId),
      status: Value(status),
      boundedCountsJson: Value(boundedCountsJson),
      safeFailureCode: safeFailureCode == null && nullToAbsent
          ? const Value.absent()
          : Value(safeFailureCode),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory OwnerScopeMigrationAuditRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OwnerScopeMigrationAuditRow(
      id: serializer.fromJson<String>(json['id']),
      ownerScopeId: serializer.fromJson<String>(json['ownerScopeId']),
      status: serializer.fromJson<String>(json['status']),
      boundedCountsJson: serializer.fromJson<String>(json['boundedCountsJson']),
      safeFailureCode: serializer.fromJson<String?>(json['safeFailureCode']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerScopeId': serializer.toJson<String>(ownerScopeId),
      'status': serializer.toJson<String>(status),
      'boundedCountsJson': serializer.toJson<String>(boundedCountsJson),
      'safeFailureCode': serializer.toJson<String?>(safeFailureCode),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  OwnerScopeMigrationAuditRow copyWith({
    String? id,
    String? ownerScopeId,
    String? status,
    String? boundedCountsJson,
    Value<String?> safeFailureCode = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => OwnerScopeMigrationAuditRow(
    id: id ?? this.id,
    ownerScopeId: ownerScopeId ?? this.ownerScopeId,
    status: status ?? this.status,
    boundedCountsJson: boundedCountsJson ?? this.boundedCountsJson,
    safeFailureCode: safeFailureCode.present
        ? safeFailureCode.value
        : this.safeFailureCode,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  OwnerScopeMigrationAuditRow copyWithCompanion(
    OwnerScopeMigrationAuditsCompanion data,
  ) {
    return OwnerScopeMigrationAuditRow(
      id: data.id.present ? data.id.value : this.id,
      ownerScopeId: data.ownerScopeId.present
          ? data.ownerScopeId.value
          : this.ownerScopeId,
      status: data.status.present ? data.status.value : this.status,
      boundedCountsJson: data.boundedCountsJson.present
          ? data.boundedCountsJson.value
          : this.boundedCountsJson,
      safeFailureCode: data.safeFailureCode.present
          ? data.safeFailureCode.value
          : this.safeFailureCode,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OwnerScopeMigrationAuditRow(')
          ..write('id: $id, ')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('status: $status, ')
          ..write('boundedCountsJson: $boundedCountsJson, ')
          ..write('safeFailureCode: $safeFailureCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerScopeId,
    status,
    boundedCountsJson,
    safeFailureCode,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OwnerScopeMigrationAuditRow &&
          other.id == this.id &&
          other.ownerScopeId == this.ownerScopeId &&
          other.status == this.status &&
          other.boundedCountsJson == this.boundedCountsJson &&
          other.safeFailureCode == this.safeFailureCode &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class OwnerScopeMigrationAuditsCompanion
    extends UpdateCompanion<OwnerScopeMigrationAuditRow> {
  final Value<String> id;
  final Value<String> ownerScopeId;
  final Value<String> status;
  final Value<String> boundedCountsJson;
  final Value<String?> safeFailureCode;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const OwnerScopeMigrationAuditsCompanion({
    this.id = const Value.absent(),
    this.ownerScopeId = const Value.absent(),
    this.status = const Value.absent(),
    this.boundedCountsJson = const Value.absent(),
    this.safeFailureCode = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OwnerScopeMigrationAuditsCompanion.insert({
    required String id,
    required String ownerScopeId,
    required String status,
    required String boundedCountsJson,
    this.safeFailureCode = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerScopeId = Value(ownerScopeId),
       status = Value(status),
       boundedCountsJson = Value(boundedCountsJson),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<OwnerScopeMigrationAuditRow> custom({
    Expression<String>? id,
    Expression<String>? ownerScopeId,
    Expression<String>? status,
    Expression<String>? boundedCountsJson,
    Expression<String>? safeFailureCode,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerScopeId != null) 'owner_scope_id': ownerScopeId,
      if (status != null) 'status': status,
      if (boundedCountsJson != null) 'bounded_counts_json': boundedCountsJson,
      if (safeFailureCode != null) 'safe_failure_code': safeFailureCode,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OwnerScopeMigrationAuditsCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerScopeId,
    Value<String>? status,
    Value<String>? boundedCountsJson,
    Value<String?>? safeFailureCode,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return OwnerScopeMigrationAuditsCompanion(
      id: id ?? this.id,
      ownerScopeId: ownerScopeId ?? this.ownerScopeId,
      status: status ?? this.status,
      boundedCountsJson: boundedCountsJson ?? this.boundedCountsJson,
      safeFailureCode: safeFailureCode ?? this.safeFailureCode,
      createdAt: createdAt ?? this.createdAt,
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
    if (ownerScopeId.present) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (boundedCountsJson.present) {
      map['bounded_counts_json'] = Variable<String>(boundedCountsJson.value);
    }
    if (safeFailureCode.present) {
      map['safe_failure_code'] = Variable<String>(safeFailureCode.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OwnerScopeMigrationAuditsCompanion(')
          ..write('id: $id, ')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('status: $status, ')
          ..write('boundedCountsJson: $boundedCountsJson, ')
          ..write('safeFailureCode: $safeFailureCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiAgentCommandsTable extends AiAgentCommands
    with TableInfo<$AiAgentCommandsTable, AiAgentCommandRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiAgentCommandsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerScopeIdMeta = const VerificationMeta(
    'ownerScopeId',
  );
  @override
  late final GeneratedColumn<String> ownerScopeId = GeneratedColumn<String>(
    'owner_scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commandTypeMeta = const VerificationMeta(
    'commandType',
  );
  @override
  late final GeneratedColumn<String> commandType = GeneratedColumn<String>(
    'command_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toolIdMeta = const VerificationMeta('toolId');
  @override
  late final GeneratedColumn<String> toolId = GeneratedColumn<String>(
    'tool_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedArgumentsJsonMeta =
      const VerificationMeta('normalizedArgumentsJson');
  @override
  late final GeneratedColumn<String> normalizedArgumentsJson =
      GeneratedColumn<String>(
        'normalized_arguments_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _permissionMeta = const VerificationMeta(
    'permission',
  );
  @override
  late final GeneratedColumn<String> permission = GeneratedColumn<String>(
    'permission',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _riskMeta = const VerificationMeta('risk');
  @override
  late final GeneratedColumn<String> risk = GeneratedColumn<String>(
    'risk',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _previewFingerprintMeta =
      const VerificationMeta('previewFingerprint');
  @override
  late final GeneratedColumn<String> previewFingerprint =
      GeneratedColumn<String>(
        'preview_fingerprint',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _safeFailureCodeMeta = const VerificationMeta(
    'safeFailureCode',
  );
  @override
  late final GeneratedColumn<String> safeFailureCode = GeneratedColumn<String>(
    'safe_failure_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerScopeId,
    createdAt,
    updatedAt,
    id,
    conversationId,
    commandType,
    toolId,
    normalizedArgumentsJson,
    permission,
    risk,
    status,
    revision,
    previewFingerprint,
    safeFailureCode,
    expiresAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_agent_commands';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiAgentCommandRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_scope_id')) {
      context.handle(
        _ownerScopeIdMeta,
        ownerScopeId.isAcceptableOrUnknown(
          data['owner_scope_id']!,
          _ownerScopeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerScopeIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('command_type')) {
      context.handle(
        _commandTypeMeta,
        commandType.isAcceptableOrUnknown(
          data['command_type']!,
          _commandTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_commandTypeMeta);
    }
    if (data.containsKey('tool_id')) {
      context.handle(
        _toolIdMeta,
        toolId.isAcceptableOrUnknown(data['tool_id']!, _toolIdMeta),
      );
    } else if (isInserting) {
      context.missing(_toolIdMeta);
    }
    if (data.containsKey('normalized_arguments_json')) {
      context.handle(
        _normalizedArgumentsJsonMeta,
        normalizedArgumentsJson.isAcceptableOrUnknown(
          data['normalized_arguments_json']!,
          _normalizedArgumentsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedArgumentsJsonMeta);
    }
    if (data.containsKey('permission')) {
      context.handle(
        _permissionMeta,
        permission.isAcceptableOrUnknown(data['permission']!, _permissionMeta),
      );
    } else if (isInserting) {
      context.missing(_permissionMeta);
    }
    if (data.containsKey('risk')) {
      context.handle(
        _riskMeta,
        risk.isAcceptableOrUnknown(data['risk']!, _riskMeta),
      );
    } else if (isInserting) {
      context.missing(_riskMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('preview_fingerprint')) {
      context.handle(
        _previewFingerprintMeta,
        previewFingerprint.isAcceptableOrUnknown(
          data['preview_fingerprint']!,
          _previewFingerprintMeta,
        ),
      );
    }
    if (data.containsKey('safe_failure_code')) {
      context.handle(
        _safeFailureCodeMeta,
        safeFailureCode.isAcceptableOrUnknown(
          data['safe_failure_code']!,
          _safeFailureCodeMeta,
        ),
      );
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiAgentCommandRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiAgentCommandRow(
      ownerScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_scope_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      commandType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}command_type'],
      )!,
      toolId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tool_id'],
      )!,
      normalizedArgumentsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_arguments_json'],
      )!,
      permission: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}permission'],
      )!,
      risk: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}risk'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      previewFingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preview_fingerprint'],
      ),
      safeFailureCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}safe_failure_code'],
      ),
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
    );
  }

  @override
  $AiAgentCommandsTable createAlias(String alias) {
    return $AiAgentCommandsTable(attachedDatabase, alias);
  }
}

class AiAgentCommandRow extends DataClass
    implements Insertable<AiAgentCommandRow> {
  final String ownerScopeId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String id;
  final String conversationId;
  final String commandType;
  final String toolId;
  final String normalizedArgumentsJson;
  final String permission;
  final String risk;
  final String status;
  final int revision;
  final String? previewFingerprint;
  final String? safeFailureCode;
  final DateTime expiresAt;
  const AiAgentCommandRow({
    required this.ownerScopeId,
    required this.createdAt,
    required this.updatedAt,
    required this.id,
    required this.conversationId,
    required this.commandType,
    required this.toolId,
    required this.normalizedArgumentsJson,
    required this.permission,
    required this.risk,
    required this.status,
    required this.revision,
    this.previewFingerprint,
    this.safeFailureCode,
    required this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_scope_id'] = Variable<String>(ownerScopeId);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['command_type'] = Variable<String>(commandType);
    map['tool_id'] = Variable<String>(toolId);
    map['normalized_arguments_json'] = Variable<String>(
      normalizedArgumentsJson,
    );
    map['permission'] = Variable<String>(permission);
    map['risk'] = Variable<String>(risk);
    map['status'] = Variable<String>(status);
    map['revision'] = Variable<int>(revision);
    if (!nullToAbsent || previewFingerprint != null) {
      map['preview_fingerprint'] = Variable<String>(previewFingerprint);
    }
    if (!nullToAbsent || safeFailureCode != null) {
      map['safe_failure_code'] = Variable<String>(safeFailureCode);
    }
    map['expires_at'] = Variable<DateTime>(expiresAt);
    return map;
  }

  AiAgentCommandsCompanion toCompanion(bool nullToAbsent) {
    return AiAgentCommandsCompanion(
      ownerScopeId: Value(ownerScopeId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      id: Value(id),
      conversationId: Value(conversationId),
      commandType: Value(commandType),
      toolId: Value(toolId),
      normalizedArgumentsJson: Value(normalizedArgumentsJson),
      permission: Value(permission),
      risk: Value(risk),
      status: Value(status),
      revision: Value(revision),
      previewFingerprint: previewFingerprint == null && nullToAbsent
          ? const Value.absent()
          : Value(previewFingerprint),
      safeFailureCode: safeFailureCode == null && nullToAbsent
          ? const Value.absent()
          : Value(safeFailureCode),
      expiresAt: Value(expiresAt),
    );
  }

  factory AiAgentCommandRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiAgentCommandRow(
      ownerScopeId: serializer.fromJson<String>(json['ownerScopeId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      commandType: serializer.fromJson<String>(json['commandType']),
      toolId: serializer.fromJson<String>(json['toolId']),
      normalizedArgumentsJson: serializer.fromJson<String>(
        json['normalizedArgumentsJson'],
      ),
      permission: serializer.fromJson<String>(json['permission']),
      risk: serializer.fromJson<String>(json['risk']),
      status: serializer.fromJson<String>(json['status']),
      revision: serializer.fromJson<int>(json['revision']),
      previewFingerprint: serializer.fromJson<String?>(
        json['previewFingerprint'],
      ),
      safeFailureCode: serializer.fromJson<String?>(json['safeFailureCode']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerScopeId': serializer.toJson<String>(ownerScopeId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'commandType': serializer.toJson<String>(commandType),
      'toolId': serializer.toJson<String>(toolId),
      'normalizedArgumentsJson': serializer.toJson<String>(
        normalizedArgumentsJson,
      ),
      'permission': serializer.toJson<String>(permission),
      'risk': serializer.toJson<String>(risk),
      'status': serializer.toJson<String>(status),
      'revision': serializer.toJson<int>(revision),
      'previewFingerprint': serializer.toJson<String?>(previewFingerprint),
      'safeFailureCode': serializer.toJson<String?>(safeFailureCode),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
    };
  }

  AiAgentCommandRow copyWith({
    String? ownerScopeId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? id,
    String? conversationId,
    String? commandType,
    String? toolId,
    String? normalizedArgumentsJson,
    String? permission,
    String? risk,
    String? status,
    int? revision,
    Value<String?> previewFingerprint = const Value.absent(),
    Value<String?> safeFailureCode = const Value.absent(),
    DateTime? expiresAt,
  }) => AiAgentCommandRow(
    ownerScopeId: ownerScopeId ?? this.ownerScopeId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    commandType: commandType ?? this.commandType,
    toolId: toolId ?? this.toolId,
    normalizedArgumentsJson:
        normalizedArgumentsJson ?? this.normalizedArgumentsJson,
    permission: permission ?? this.permission,
    risk: risk ?? this.risk,
    status: status ?? this.status,
    revision: revision ?? this.revision,
    previewFingerprint: previewFingerprint.present
        ? previewFingerprint.value
        : this.previewFingerprint,
    safeFailureCode: safeFailureCode.present
        ? safeFailureCode.value
        : this.safeFailureCode,
    expiresAt: expiresAt ?? this.expiresAt,
  );
  AiAgentCommandRow copyWithCompanion(AiAgentCommandsCompanion data) {
    return AiAgentCommandRow(
      ownerScopeId: data.ownerScopeId.present
          ? data.ownerScopeId.value
          : this.ownerScopeId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      commandType: data.commandType.present
          ? data.commandType.value
          : this.commandType,
      toolId: data.toolId.present ? data.toolId.value : this.toolId,
      normalizedArgumentsJson: data.normalizedArgumentsJson.present
          ? data.normalizedArgumentsJson.value
          : this.normalizedArgumentsJson,
      permission: data.permission.present
          ? data.permission.value
          : this.permission,
      risk: data.risk.present ? data.risk.value : this.risk,
      status: data.status.present ? data.status.value : this.status,
      revision: data.revision.present ? data.revision.value : this.revision,
      previewFingerprint: data.previewFingerprint.present
          ? data.previewFingerprint.value
          : this.previewFingerprint,
      safeFailureCode: data.safeFailureCode.present
          ? data.safeFailureCode.value
          : this.safeFailureCode,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiAgentCommandRow(')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('commandType: $commandType, ')
          ..write('toolId: $toolId, ')
          ..write('normalizedArgumentsJson: $normalizedArgumentsJson, ')
          ..write('permission: $permission, ')
          ..write('risk: $risk, ')
          ..write('status: $status, ')
          ..write('revision: $revision, ')
          ..write('previewFingerprint: $previewFingerprint, ')
          ..write('safeFailureCode: $safeFailureCode, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ownerScopeId,
    createdAt,
    updatedAt,
    id,
    conversationId,
    commandType,
    toolId,
    normalizedArgumentsJson,
    permission,
    risk,
    status,
    revision,
    previewFingerprint,
    safeFailureCode,
    expiresAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiAgentCommandRow &&
          other.ownerScopeId == this.ownerScopeId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.commandType == this.commandType &&
          other.toolId == this.toolId &&
          other.normalizedArgumentsJson == this.normalizedArgumentsJson &&
          other.permission == this.permission &&
          other.risk == this.risk &&
          other.status == this.status &&
          other.revision == this.revision &&
          other.previewFingerprint == this.previewFingerprint &&
          other.safeFailureCode == this.safeFailureCode &&
          other.expiresAt == this.expiresAt);
}

class AiAgentCommandsCompanion extends UpdateCompanion<AiAgentCommandRow> {
  final Value<String> ownerScopeId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> commandType;
  final Value<String> toolId;
  final Value<String> normalizedArgumentsJson;
  final Value<String> permission;
  final Value<String> risk;
  final Value<String> status;
  final Value<int> revision;
  final Value<String?> previewFingerprint;
  final Value<String?> safeFailureCode;
  final Value<DateTime> expiresAt;
  final Value<int> rowid;
  const AiAgentCommandsCompanion({
    this.ownerScopeId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.commandType = const Value.absent(),
    this.toolId = const Value.absent(),
    this.normalizedArgumentsJson = const Value.absent(),
    this.permission = const Value.absent(),
    this.risk = const Value.absent(),
    this.status = const Value.absent(),
    this.revision = const Value.absent(),
    this.previewFingerprint = const Value.absent(),
    this.safeFailureCode = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiAgentCommandsCompanion.insert({
    required String ownerScopeId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String id,
    required String conversationId,
    required String commandType,
    required String toolId,
    required String normalizedArgumentsJson,
    required String permission,
    required String risk,
    required String status,
    this.revision = const Value.absent(),
    this.previewFingerprint = const Value.absent(),
    this.safeFailureCode = const Value.absent(),
    required DateTime expiresAt,
    this.rowid = const Value.absent(),
  }) : ownerScopeId = Value(ownerScopeId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       id = Value(id),
       conversationId = Value(conversationId),
       commandType = Value(commandType),
       toolId = Value(toolId),
       normalizedArgumentsJson = Value(normalizedArgumentsJson),
       permission = Value(permission),
       risk = Value(risk),
       status = Value(status),
       expiresAt = Value(expiresAt);
  static Insertable<AiAgentCommandRow> custom({
    Expression<String>? ownerScopeId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? commandType,
    Expression<String>? toolId,
    Expression<String>? normalizedArgumentsJson,
    Expression<String>? permission,
    Expression<String>? risk,
    Expression<String>? status,
    Expression<int>? revision,
    Expression<String>? previewFingerprint,
    Expression<String>? safeFailureCode,
    Expression<DateTime>? expiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerScopeId != null) 'owner_scope_id': ownerScopeId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (commandType != null) 'command_type': commandType,
      if (toolId != null) 'tool_id': toolId,
      if (normalizedArgumentsJson != null)
        'normalized_arguments_json': normalizedArgumentsJson,
      if (permission != null) 'permission': permission,
      if (risk != null) 'risk': risk,
      if (status != null) 'status': status,
      if (revision != null) 'revision': revision,
      if (previewFingerprint != null) 'preview_fingerprint': previewFingerprint,
      if (safeFailureCode != null) 'safe_failure_code': safeFailureCode,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiAgentCommandsCompanion copyWith({
    Value<String>? ownerScopeId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String>? id,
    Value<String>? conversationId,
    Value<String>? commandType,
    Value<String>? toolId,
    Value<String>? normalizedArgumentsJson,
    Value<String>? permission,
    Value<String>? risk,
    Value<String>? status,
    Value<int>? revision,
    Value<String?>? previewFingerprint,
    Value<String?>? safeFailureCode,
    Value<DateTime>? expiresAt,
    Value<int>? rowid,
  }) {
    return AiAgentCommandsCompanion(
      ownerScopeId: ownerScopeId ?? this.ownerScopeId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      commandType: commandType ?? this.commandType,
      toolId: toolId ?? this.toolId,
      normalizedArgumentsJson:
          normalizedArgumentsJson ?? this.normalizedArgumentsJson,
      permission: permission ?? this.permission,
      risk: risk ?? this.risk,
      status: status ?? this.status,
      revision: revision ?? this.revision,
      previewFingerprint: previewFingerprint ?? this.previewFingerprint,
      safeFailureCode: safeFailureCode ?? this.safeFailureCode,
      expiresAt: expiresAt ?? this.expiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerScopeId.present) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (commandType.present) {
      map['command_type'] = Variable<String>(commandType.value);
    }
    if (toolId.present) {
      map['tool_id'] = Variable<String>(toolId.value);
    }
    if (normalizedArgumentsJson.present) {
      map['normalized_arguments_json'] = Variable<String>(
        normalizedArgumentsJson.value,
      );
    }
    if (permission.present) {
      map['permission'] = Variable<String>(permission.value);
    }
    if (risk.present) {
      map['risk'] = Variable<String>(risk.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (previewFingerprint.present) {
      map['preview_fingerprint'] = Variable<String>(previewFingerprint.value);
    }
    if (safeFailureCode.present) {
      map['safe_failure_code'] = Variable<String>(safeFailureCode.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiAgentCommandsCompanion(')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('commandType: $commandType, ')
          ..write('toolId: $toolId, ')
          ..write('normalizedArgumentsJson: $normalizedArgumentsJson, ')
          ..write('permission: $permission, ')
          ..write('risk: $risk, ')
          ..write('status: $status, ')
          ..write('revision: $revision, ')
          ..write('previewFingerprint: $previewFingerprint, ')
          ..write('safeFailureCode: $safeFailureCode, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiAgentPreviewsTable extends AiAgentPreviews
    with TableInfo<$AiAgentPreviewsTable, AiAgentPreviewRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiAgentPreviewsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerScopeIdMeta = const VerificationMeta(
    'ownerScopeId',
  );
  @override
  late final GeneratedColumn<String> ownerScopeId = GeneratedColumn<String>(
    'owner_scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commandIdMeta = const VerificationMeta(
    'commandId',
  );
  @override
  late final GeneratedColumn<String> commandId = GeneratedColumn<String>(
    'command_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateFingerprintMeta = const VerificationMeta(
    'stateFingerprint',
  );
  @override
  late final GeneratedColumn<String> stateFingerprint = GeneratedColumn<String>(
    'state_fingerprint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerScopeId,
    createdAt,
    updatedAt,
    id,
    commandId,
    revision,
    status,
    stateFingerprint,
    payloadJson,
    expiresAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_agent_previews';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiAgentPreviewRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_scope_id')) {
      context.handle(
        _ownerScopeIdMeta,
        ownerScopeId.isAcceptableOrUnknown(
          data['owner_scope_id']!,
          _ownerScopeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerScopeIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('command_id')) {
      context.handle(
        _commandIdMeta,
        commandId.isAcceptableOrUnknown(data['command_id']!, _commandIdMeta),
      );
    } else if (isInserting) {
      context.missing(_commandIdMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('state_fingerprint')) {
      context.handle(
        _stateFingerprintMeta,
        stateFingerprint.isAcceptableOrUnknown(
          data['state_fingerprint']!,
          _stateFingerprintMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_stateFingerprintMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiAgentPreviewRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiAgentPreviewRow(
      ownerScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_scope_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      commandId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}command_id'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      stateFingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state_fingerprint'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
    );
  }

  @override
  $AiAgentPreviewsTable createAlias(String alias) {
    return $AiAgentPreviewsTable(attachedDatabase, alias);
  }
}

class AiAgentPreviewRow extends DataClass
    implements Insertable<AiAgentPreviewRow> {
  final String ownerScopeId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String id;
  final String commandId;
  final int revision;
  final String status;
  final String stateFingerprint;
  final String payloadJson;
  final DateTime expiresAt;
  const AiAgentPreviewRow({
    required this.ownerScopeId,
    required this.createdAt,
    required this.updatedAt,
    required this.id,
    required this.commandId,
    required this.revision,
    required this.status,
    required this.stateFingerprint,
    required this.payloadJson,
    required this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_scope_id'] = Variable<String>(ownerScopeId);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['id'] = Variable<String>(id);
    map['command_id'] = Variable<String>(commandId);
    map['revision'] = Variable<int>(revision);
    map['status'] = Variable<String>(status);
    map['state_fingerprint'] = Variable<String>(stateFingerprint);
    map['payload_json'] = Variable<String>(payloadJson);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    return map;
  }

  AiAgentPreviewsCompanion toCompanion(bool nullToAbsent) {
    return AiAgentPreviewsCompanion(
      ownerScopeId: Value(ownerScopeId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      id: Value(id),
      commandId: Value(commandId),
      revision: Value(revision),
      status: Value(status),
      stateFingerprint: Value(stateFingerprint),
      payloadJson: Value(payloadJson),
      expiresAt: Value(expiresAt),
    );
  }

  factory AiAgentPreviewRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiAgentPreviewRow(
      ownerScopeId: serializer.fromJson<String>(json['ownerScopeId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      id: serializer.fromJson<String>(json['id']),
      commandId: serializer.fromJson<String>(json['commandId']),
      revision: serializer.fromJson<int>(json['revision']),
      status: serializer.fromJson<String>(json['status']),
      stateFingerprint: serializer.fromJson<String>(json['stateFingerprint']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerScopeId': serializer.toJson<String>(ownerScopeId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'id': serializer.toJson<String>(id),
      'commandId': serializer.toJson<String>(commandId),
      'revision': serializer.toJson<int>(revision),
      'status': serializer.toJson<String>(status),
      'stateFingerprint': serializer.toJson<String>(stateFingerprint),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
    };
  }

  AiAgentPreviewRow copyWith({
    String? ownerScopeId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? id,
    String? commandId,
    int? revision,
    String? status,
    String? stateFingerprint,
    String? payloadJson,
    DateTime? expiresAt,
  }) => AiAgentPreviewRow(
    ownerScopeId: ownerScopeId ?? this.ownerScopeId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    id: id ?? this.id,
    commandId: commandId ?? this.commandId,
    revision: revision ?? this.revision,
    status: status ?? this.status,
    stateFingerprint: stateFingerprint ?? this.stateFingerprint,
    payloadJson: payloadJson ?? this.payloadJson,
    expiresAt: expiresAt ?? this.expiresAt,
  );
  AiAgentPreviewRow copyWithCompanion(AiAgentPreviewsCompanion data) {
    return AiAgentPreviewRow(
      ownerScopeId: data.ownerScopeId.present
          ? data.ownerScopeId.value
          : this.ownerScopeId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      id: data.id.present ? data.id.value : this.id,
      commandId: data.commandId.present ? data.commandId.value : this.commandId,
      revision: data.revision.present ? data.revision.value : this.revision,
      status: data.status.present ? data.status.value : this.status,
      stateFingerprint: data.stateFingerprint.present
          ? data.stateFingerprint.value
          : this.stateFingerprint,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiAgentPreviewRow(')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('id: $id, ')
          ..write('commandId: $commandId, ')
          ..write('revision: $revision, ')
          ..write('status: $status, ')
          ..write('stateFingerprint: $stateFingerprint, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ownerScopeId,
    createdAt,
    updatedAt,
    id,
    commandId,
    revision,
    status,
    stateFingerprint,
    payloadJson,
    expiresAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiAgentPreviewRow &&
          other.ownerScopeId == this.ownerScopeId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.id == this.id &&
          other.commandId == this.commandId &&
          other.revision == this.revision &&
          other.status == this.status &&
          other.stateFingerprint == this.stateFingerprint &&
          other.payloadJson == this.payloadJson &&
          other.expiresAt == this.expiresAt);
}

class AiAgentPreviewsCompanion extends UpdateCompanion<AiAgentPreviewRow> {
  final Value<String> ownerScopeId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> id;
  final Value<String> commandId;
  final Value<int> revision;
  final Value<String> status;
  final Value<String> stateFingerprint;
  final Value<String> payloadJson;
  final Value<DateTime> expiresAt;
  final Value<int> rowid;
  const AiAgentPreviewsCompanion({
    this.ownerScopeId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.commandId = const Value.absent(),
    this.revision = const Value.absent(),
    this.status = const Value.absent(),
    this.stateFingerprint = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiAgentPreviewsCompanion.insert({
    required String ownerScopeId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String id,
    required String commandId,
    required int revision,
    required String status,
    required String stateFingerprint,
    required String payloadJson,
    required DateTime expiresAt,
    this.rowid = const Value.absent(),
  }) : ownerScopeId = Value(ownerScopeId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       id = Value(id),
       commandId = Value(commandId),
       revision = Value(revision),
       status = Value(status),
       stateFingerprint = Value(stateFingerprint),
       payloadJson = Value(payloadJson),
       expiresAt = Value(expiresAt);
  static Insertable<AiAgentPreviewRow> custom({
    Expression<String>? ownerScopeId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? id,
    Expression<String>? commandId,
    Expression<int>? revision,
    Expression<String>? status,
    Expression<String>? stateFingerprint,
    Expression<String>? payloadJson,
    Expression<DateTime>? expiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerScopeId != null) 'owner_scope_id': ownerScopeId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (id != null) 'id': id,
      if (commandId != null) 'command_id': commandId,
      if (revision != null) 'revision': revision,
      if (status != null) 'status': status,
      if (stateFingerprint != null) 'state_fingerprint': stateFingerprint,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiAgentPreviewsCompanion copyWith({
    Value<String>? ownerScopeId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String>? id,
    Value<String>? commandId,
    Value<int>? revision,
    Value<String>? status,
    Value<String>? stateFingerprint,
    Value<String>? payloadJson,
    Value<DateTime>? expiresAt,
    Value<int>? rowid,
  }) {
    return AiAgentPreviewsCompanion(
      ownerScopeId: ownerScopeId ?? this.ownerScopeId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      id: id ?? this.id,
      commandId: commandId ?? this.commandId,
      revision: revision ?? this.revision,
      status: status ?? this.status,
      stateFingerprint: stateFingerprint ?? this.stateFingerprint,
      payloadJson: payloadJson ?? this.payloadJson,
      expiresAt: expiresAt ?? this.expiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerScopeId.present) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (commandId.present) {
      map['command_id'] = Variable<String>(commandId.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (stateFingerprint.present) {
      map['state_fingerprint'] = Variable<String>(stateFingerprint.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiAgentPreviewsCompanion(')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('id: $id, ')
          ..write('commandId: $commandId, ')
          ..write('revision: $revision, ')
          ..write('status: $status, ')
          ..write('stateFingerprint: $stateFingerprint, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiAgentConfirmationProofsTable extends AiAgentConfirmationProofs
    with
        TableInfo<
          $AiAgentConfirmationProofsTable,
          AiAgentConfirmationProofRow
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiAgentConfirmationProofsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerScopeIdMeta = const VerificationMeta(
    'ownerScopeId',
  );
  @override
  late final GeneratedColumn<String> ownerScopeId = GeneratedColumn<String>(
    'owner_scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commandIdMeta = const VerificationMeta(
    'commandId',
  );
  @override
  late final GeneratedColumn<String> commandId = GeneratedColumn<String>(
    'command_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _previewRevisionMeta = const VerificationMeta(
    'previewRevision',
  );
  @override
  late final GeneratedColumn<int> previewRevision = GeneratedColumn<int>(
    'preview_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confirmationMethodMeta =
      const VerificationMeta('confirmationMethod');
  @override
  late final GeneratedColumn<String> confirmationMethod =
      GeneratedColumn<String>(
        'confirmation_method',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _proofHashMeta = const VerificationMeta(
    'proofHash',
  );
  @override
  late final GeneratedColumn<String> proofHash = GeneratedColumn<String>(
    'proof_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _proofSaltMeta = const VerificationMeta(
    'proofSalt',
  );
  @override
  late final GeneratedColumn<String> proofSalt = GeneratedColumn<String>(
    'proof_salt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _consumedAtMeta = const VerificationMeta(
    'consumedAt',
  );
  @override
  late final GeneratedColumn<DateTime> consumedAt = GeneratedColumn<DateTime>(
    'consumed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerScopeId,
    createdAt,
    updatedAt,
    id,
    commandId,
    previewRevision,
    confirmationMethod,
    proofHash,
    proofSalt,
    status,
    expiresAt,
    consumedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_agent_confirmation_proofs';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiAgentConfirmationProofRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_scope_id')) {
      context.handle(
        _ownerScopeIdMeta,
        ownerScopeId.isAcceptableOrUnknown(
          data['owner_scope_id']!,
          _ownerScopeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerScopeIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('command_id')) {
      context.handle(
        _commandIdMeta,
        commandId.isAcceptableOrUnknown(data['command_id']!, _commandIdMeta),
      );
    } else if (isInserting) {
      context.missing(_commandIdMeta);
    }
    if (data.containsKey('preview_revision')) {
      context.handle(
        _previewRevisionMeta,
        previewRevision.isAcceptableOrUnknown(
          data['preview_revision']!,
          _previewRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_previewRevisionMeta);
    }
    if (data.containsKey('confirmation_method')) {
      context.handle(
        _confirmationMethodMeta,
        confirmationMethod.isAcceptableOrUnknown(
          data['confirmation_method']!,
          _confirmationMethodMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_confirmationMethodMeta);
    }
    if (data.containsKey('proof_hash')) {
      context.handle(
        _proofHashMeta,
        proofHash.isAcceptableOrUnknown(data['proof_hash']!, _proofHashMeta),
      );
    } else if (isInserting) {
      context.missing(_proofHashMeta);
    }
    if (data.containsKey('proof_salt')) {
      context.handle(
        _proofSaltMeta,
        proofSalt.isAcceptableOrUnknown(data['proof_salt']!, _proofSaltMeta),
      );
    } else if (isInserting) {
      context.missing(_proofSaltMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    if (data.containsKey('consumed_at')) {
      context.handle(
        _consumedAtMeta,
        consumedAt.isAcceptableOrUnknown(data['consumed_at']!, _consumedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiAgentConfirmationProofRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiAgentConfirmationProofRow(
      ownerScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_scope_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      commandId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}command_id'],
      )!,
      previewRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}preview_revision'],
      )!,
      confirmationMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}confirmation_method'],
      )!,
      proofHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}proof_hash'],
      )!,
      proofSalt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}proof_salt'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
      consumedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}consumed_at'],
      ),
    );
  }

  @override
  $AiAgentConfirmationProofsTable createAlias(String alias) {
    return $AiAgentConfirmationProofsTable(attachedDatabase, alias);
  }
}

class AiAgentConfirmationProofRow extends DataClass
    implements Insertable<AiAgentConfirmationProofRow> {
  final String ownerScopeId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String id;
  final String commandId;
  final int previewRevision;
  final String confirmationMethod;
  final String proofHash;
  final String proofSalt;
  final String status;
  final DateTime expiresAt;
  final DateTime? consumedAt;
  const AiAgentConfirmationProofRow({
    required this.ownerScopeId,
    required this.createdAt,
    required this.updatedAt,
    required this.id,
    required this.commandId,
    required this.previewRevision,
    required this.confirmationMethod,
    required this.proofHash,
    required this.proofSalt,
    required this.status,
    required this.expiresAt,
    this.consumedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_scope_id'] = Variable<String>(ownerScopeId);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['id'] = Variable<String>(id);
    map['command_id'] = Variable<String>(commandId);
    map['preview_revision'] = Variable<int>(previewRevision);
    map['confirmation_method'] = Variable<String>(confirmationMethod);
    map['proof_hash'] = Variable<String>(proofHash);
    map['proof_salt'] = Variable<String>(proofSalt);
    map['status'] = Variable<String>(status);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    if (!nullToAbsent || consumedAt != null) {
      map['consumed_at'] = Variable<DateTime>(consumedAt);
    }
    return map;
  }

  AiAgentConfirmationProofsCompanion toCompanion(bool nullToAbsent) {
    return AiAgentConfirmationProofsCompanion(
      ownerScopeId: Value(ownerScopeId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      id: Value(id),
      commandId: Value(commandId),
      previewRevision: Value(previewRevision),
      confirmationMethod: Value(confirmationMethod),
      proofHash: Value(proofHash),
      proofSalt: Value(proofSalt),
      status: Value(status),
      expiresAt: Value(expiresAt),
      consumedAt: consumedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(consumedAt),
    );
  }

  factory AiAgentConfirmationProofRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiAgentConfirmationProofRow(
      ownerScopeId: serializer.fromJson<String>(json['ownerScopeId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      id: serializer.fromJson<String>(json['id']),
      commandId: serializer.fromJson<String>(json['commandId']),
      previewRevision: serializer.fromJson<int>(json['previewRevision']),
      confirmationMethod: serializer.fromJson<String>(
        json['confirmationMethod'],
      ),
      proofHash: serializer.fromJson<String>(json['proofHash']),
      proofSalt: serializer.fromJson<String>(json['proofSalt']),
      status: serializer.fromJson<String>(json['status']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
      consumedAt: serializer.fromJson<DateTime?>(json['consumedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerScopeId': serializer.toJson<String>(ownerScopeId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'id': serializer.toJson<String>(id),
      'commandId': serializer.toJson<String>(commandId),
      'previewRevision': serializer.toJson<int>(previewRevision),
      'confirmationMethod': serializer.toJson<String>(confirmationMethod),
      'proofHash': serializer.toJson<String>(proofHash),
      'proofSalt': serializer.toJson<String>(proofSalt),
      'status': serializer.toJson<String>(status),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
      'consumedAt': serializer.toJson<DateTime?>(consumedAt),
    };
  }

  AiAgentConfirmationProofRow copyWith({
    String? ownerScopeId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? id,
    String? commandId,
    int? previewRevision,
    String? confirmationMethod,
    String? proofHash,
    String? proofSalt,
    String? status,
    DateTime? expiresAt,
    Value<DateTime?> consumedAt = const Value.absent(),
  }) => AiAgentConfirmationProofRow(
    ownerScopeId: ownerScopeId ?? this.ownerScopeId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    id: id ?? this.id,
    commandId: commandId ?? this.commandId,
    previewRevision: previewRevision ?? this.previewRevision,
    confirmationMethod: confirmationMethod ?? this.confirmationMethod,
    proofHash: proofHash ?? this.proofHash,
    proofSalt: proofSalt ?? this.proofSalt,
    status: status ?? this.status,
    expiresAt: expiresAt ?? this.expiresAt,
    consumedAt: consumedAt.present ? consumedAt.value : this.consumedAt,
  );
  AiAgentConfirmationProofRow copyWithCompanion(
    AiAgentConfirmationProofsCompanion data,
  ) {
    return AiAgentConfirmationProofRow(
      ownerScopeId: data.ownerScopeId.present
          ? data.ownerScopeId.value
          : this.ownerScopeId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      id: data.id.present ? data.id.value : this.id,
      commandId: data.commandId.present ? data.commandId.value : this.commandId,
      previewRevision: data.previewRevision.present
          ? data.previewRevision.value
          : this.previewRevision,
      confirmationMethod: data.confirmationMethod.present
          ? data.confirmationMethod.value
          : this.confirmationMethod,
      proofHash: data.proofHash.present ? data.proofHash.value : this.proofHash,
      proofSalt: data.proofSalt.present ? data.proofSalt.value : this.proofSalt,
      status: data.status.present ? data.status.value : this.status,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      consumedAt: data.consumedAt.present
          ? data.consumedAt.value
          : this.consumedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiAgentConfirmationProofRow(')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('id: $id, ')
          ..write('commandId: $commandId, ')
          ..write('previewRevision: $previewRevision, ')
          ..write('confirmationMethod: $confirmationMethod, ')
          ..write('proofHash: $proofHash, ')
          ..write('proofSalt: $proofSalt, ')
          ..write('status: $status, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('consumedAt: $consumedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ownerScopeId,
    createdAt,
    updatedAt,
    id,
    commandId,
    previewRevision,
    confirmationMethod,
    proofHash,
    proofSalt,
    status,
    expiresAt,
    consumedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiAgentConfirmationProofRow &&
          other.ownerScopeId == this.ownerScopeId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.id == this.id &&
          other.commandId == this.commandId &&
          other.previewRevision == this.previewRevision &&
          other.confirmationMethod == this.confirmationMethod &&
          other.proofHash == this.proofHash &&
          other.proofSalt == this.proofSalt &&
          other.status == this.status &&
          other.expiresAt == this.expiresAt &&
          other.consumedAt == this.consumedAt);
}

class AiAgentConfirmationProofsCompanion
    extends UpdateCompanion<AiAgentConfirmationProofRow> {
  final Value<String> ownerScopeId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> id;
  final Value<String> commandId;
  final Value<int> previewRevision;
  final Value<String> confirmationMethod;
  final Value<String> proofHash;
  final Value<String> proofSalt;
  final Value<String> status;
  final Value<DateTime> expiresAt;
  final Value<DateTime?> consumedAt;
  final Value<int> rowid;
  const AiAgentConfirmationProofsCompanion({
    this.ownerScopeId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.commandId = const Value.absent(),
    this.previewRevision = const Value.absent(),
    this.confirmationMethod = const Value.absent(),
    this.proofHash = const Value.absent(),
    this.proofSalt = const Value.absent(),
    this.status = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.consumedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiAgentConfirmationProofsCompanion.insert({
    required String ownerScopeId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String id,
    required String commandId,
    required int previewRevision,
    required String confirmationMethod,
    required String proofHash,
    required String proofSalt,
    required String status,
    required DateTime expiresAt,
    this.consumedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ownerScopeId = Value(ownerScopeId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       id = Value(id),
       commandId = Value(commandId),
       previewRevision = Value(previewRevision),
       confirmationMethod = Value(confirmationMethod),
       proofHash = Value(proofHash),
       proofSalt = Value(proofSalt),
       status = Value(status),
       expiresAt = Value(expiresAt);
  static Insertable<AiAgentConfirmationProofRow> custom({
    Expression<String>? ownerScopeId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? id,
    Expression<String>? commandId,
    Expression<int>? previewRevision,
    Expression<String>? confirmationMethod,
    Expression<String>? proofHash,
    Expression<String>? proofSalt,
    Expression<String>? status,
    Expression<DateTime>? expiresAt,
    Expression<DateTime>? consumedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerScopeId != null) 'owner_scope_id': ownerScopeId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (id != null) 'id': id,
      if (commandId != null) 'command_id': commandId,
      if (previewRevision != null) 'preview_revision': previewRevision,
      if (confirmationMethod != null) 'confirmation_method': confirmationMethod,
      if (proofHash != null) 'proof_hash': proofHash,
      if (proofSalt != null) 'proof_salt': proofSalt,
      if (status != null) 'status': status,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (consumedAt != null) 'consumed_at': consumedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiAgentConfirmationProofsCompanion copyWith({
    Value<String>? ownerScopeId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String>? id,
    Value<String>? commandId,
    Value<int>? previewRevision,
    Value<String>? confirmationMethod,
    Value<String>? proofHash,
    Value<String>? proofSalt,
    Value<String>? status,
    Value<DateTime>? expiresAt,
    Value<DateTime?>? consumedAt,
    Value<int>? rowid,
  }) {
    return AiAgentConfirmationProofsCompanion(
      ownerScopeId: ownerScopeId ?? this.ownerScopeId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      id: id ?? this.id,
      commandId: commandId ?? this.commandId,
      previewRevision: previewRevision ?? this.previewRevision,
      confirmationMethod: confirmationMethod ?? this.confirmationMethod,
      proofHash: proofHash ?? this.proofHash,
      proofSalt: proofSalt ?? this.proofSalt,
      status: status ?? this.status,
      expiresAt: expiresAt ?? this.expiresAt,
      consumedAt: consumedAt ?? this.consumedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerScopeId.present) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (commandId.present) {
      map['command_id'] = Variable<String>(commandId.value);
    }
    if (previewRevision.present) {
      map['preview_revision'] = Variable<int>(previewRevision.value);
    }
    if (confirmationMethod.present) {
      map['confirmation_method'] = Variable<String>(confirmationMethod.value);
    }
    if (proofHash.present) {
      map['proof_hash'] = Variable<String>(proofHash.value);
    }
    if (proofSalt.present) {
      map['proof_salt'] = Variable<String>(proofSalt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (consumedAt.present) {
      map['consumed_at'] = Variable<DateTime>(consumedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiAgentConfirmationProofsCompanion(')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('id: $id, ')
          ..write('commandId: $commandId, ')
          ..write('previewRevision: $previewRevision, ')
          ..write('confirmationMethod: $confirmationMethod, ')
          ..write('proofHash: $proofHash, ')
          ..write('proofSalt: $proofSalt, ')
          ..write('status: $status, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('consumedAt: $consumedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiAgentExecutionAttemptsTable extends AiAgentExecutionAttempts
    with TableInfo<$AiAgentExecutionAttemptsTable, AiAgentExecutionAttemptRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiAgentExecutionAttemptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerScopeIdMeta = const VerificationMeta(
    'ownerScopeId',
  );
  @override
  late final GeneratedColumn<String> ownerScopeId = GeneratedColumn<String>(
    'owner_scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commandIdMeta = const VerificationMeta(
    'commandId',
  );
  @override
  late final GeneratedColumn<String> commandId = GeneratedColumn<String>(
    'command_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commandRevisionMeta = const VerificationMeta(
    'commandRevision',
  );
  @override
  late final GeneratedColumn<int> commandRevision = GeneratedColumn<int>(
    'command_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionTypeMeta = const VerificationMeta(
    'actionType',
  );
  @override
  late final GeneratedColumn<String> actionType = GeneratedColumn<String>(
    'action_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _businessOperationIdMeta =
      const VerificationMeta('businessOperationId');
  @override
  late final GeneratedColumn<String> businessOperationId =
      GeneratedColumn<String>(
        'business_operation_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _safeFailureCodeMeta = const VerificationMeta(
    'safeFailureCode',
  );
  @override
  late final GeneratedColumn<String> safeFailureCode = GeneratedColumn<String>(
    'safe_failure_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _claimedAtMeta = const VerificationMeta(
    'claimedAt',
  );
  @override
  late final GeneratedColumn<DateTime> claimedAt = GeneratedColumn<DateTime>(
    'claimed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerScopeId,
    createdAt,
    updatedAt,
    id,
    commandId,
    idempotencyKey,
    commandRevision,
    actionType,
    status,
    businessOperationId,
    safeFailureCode,
    claimedAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_agent_execution_attempts';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiAgentExecutionAttemptRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_scope_id')) {
      context.handle(
        _ownerScopeIdMeta,
        ownerScopeId.isAcceptableOrUnknown(
          data['owner_scope_id']!,
          _ownerScopeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerScopeIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('command_id')) {
      context.handle(
        _commandIdMeta,
        commandId.isAcceptableOrUnknown(data['command_id']!, _commandIdMeta),
      );
    } else if (isInserting) {
      context.missing(_commandIdMeta);
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('command_revision')) {
      context.handle(
        _commandRevisionMeta,
        commandRevision.isAcceptableOrUnknown(
          data['command_revision']!,
          _commandRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_commandRevisionMeta);
    }
    if (data.containsKey('action_type')) {
      context.handle(
        _actionTypeMeta,
        actionType.isAcceptableOrUnknown(data['action_type']!, _actionTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_actionTypeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('business_operation_id')) {
      context.handle(
        _businessOperationIdMeta,
        businessOperationId.isAcceptableOrUnknown(
          data['business_operation_id']!,
          _businessOperationIdMeta,
        ),
      );
    }
    if (data.containsKey('safe_failure_code')) {
      context.handle(
        _safeFailureCodeMeta,
        safeFailureCode.isAcceptableOrUnknown(
          data['safe_failure_code']!,
          _safeFailureCodeMeta,
        ),
      );
    }
    if (data.containsKey('claimed_at')) {
      context.handle(
        _claimedAtMeta,
        claimedAt.isAcceptableOrUnknown(data['claimed_at']!, _claimedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_claimedAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiAgentExecutionAttemptRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiAgentExecutionAttemptRow(
      ownerScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_scope_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      commandId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}command_id'],
      )!,
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      commandRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}command_revision'],
      )!,
      actionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action_type'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      businessOperationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_operation_id'],
      ),
      safeFailureCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}safe_failure_code'],
      ),
      claimedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}claimed_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $AiAgentExecutionAttemptsTable createAlias(String alias) {
    return $AiAgentExecutionAttemptsTable(attachedDatabase, alias);
  }
}

class AiAgentExecutionAttemptRow extends DataClass
    implements Insertable<AiAgentExecutionAttemptRow> {
  final String ownerScopeId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String id;
  final String commandId;
  final String idempotencyKey;
  final int commandRevision;
  final String actionType;
  final String status;
  final String? businessOperationId;
  final String? safeFailureCode;
  final DateTime claimedAt;
  final DateTime? completedAt;
  const AiAgentExecutionAttemptRow({
    required this.ownerScopeId,
    required this.createdAt,
    required this.updatedAt,
    required this.id,
    required this.commandId,
    required this.idempotencyKey,
    required this.commandRevision,
    required this.actionType,
    required this.status,
    this.businessOperationId,
    this.safeFailureCode,
    required this.claimedAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_scope_id'] = Variable<String>(ownerScopeId);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['id'] = Variable<String>(id);
    map['command_id'] = Variable<String>(commandId);
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['command_revision'] = Variable<int>(commandRevision);
    map['action_type'] = Variable<String>(actionType);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || businessOperationId != null) {
      map['business_operation_id'] = Variable<String>(businessOperationId);
    }
    if (!nullToAbsent || safeFailureCode != null) {
      map['safe_failure_code'] = Variable<String>(safeFailureCode);
    }
    map['claimed_at'] = Variable<DateTime>(claimedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  AiAgentExecutionAttemptsCompanion toCompanion(bool nullToAbsent) {
    return AiAgentExecutionAttemptsCompanion(
      ownerScopeId: Value(ownerScopeId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      id: Value(id),
      commandId: Value(commandId),
      idempotencyKey: Value(idempotencyKey),
      commandRevision: Value(commandRevision),
      actionType: Value(actionType),
      status: Value(status),
      businessOperationId: businessOperationId == null && nullToAbsent
          ? const Value.absent()
          : Value(businessOperationId),
      safeFailureCode: safeFailureCode == null && nullToAbsent
          ? const Value.absent()
          : Value(safeFailureCode),
      claimedAt: Value(claimedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory AiAgentExecutionAttemptRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiAgentExecutionAttemptRow(
      ownerScopeId: serializer.fromJson<String>(json['ownerScopeId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      id: serializer.fromJson<String>(json['id']),
      commandId: serializer.fromJson<String>(json['commandId']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      commandRevision: serializer.fromJson<int>(json['commandRevision']),
      actionType: serializer.fromJson<String>(json['actionType']),
      status: serializer.fromJson<String>(json['status']),
      businessOperationId: serializer.fromJson<String?>(
        json['businessOperationId'],
      ),
      safeFailureCode: serializer.fromJson<String?>(json['safeFailureCode']),
      claimedAt: serializer.fromJson<DateTime>(json['claimedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerScopeId': serializer.toJson<String>(ownerScopeId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'id': serializer.toJson<String>(id),
      'commandId': serializer.toJson<String>(commandId),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'commandRevision': serializer.toJson<int>(commandRevision),
      'actionType': serializer.toJson<String>(actionType),
      'status': serializer.toJson<String>(status),
      'businessOperationId': serializer.toJson<String?>(businessOperationId),
      'safeFailureCode': serializer.toJson<String?>(safeFailureCode),
      'claimedAt': serializer.toJson<DateTime>(claimedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  AiAgentExecutionAttemptRow copyWith({
    String? ownerScopeId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? id,
    String? commandId,
    String? idempotencyKey,
    int? commandRevision,
    String? actionType,
    String? status,
    Value<String?> businessOperationId = const Value.absent(),
    Value<String?> safeFailureCode = const Value.absent(),
    DateTime? claimedAt,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => AiAgentExecutionAttemptRow(
    ownerScopeId: ownerScopeId ?? this.ownerScopeId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    id: id ?? this.id,
    commandId: commandId ?? this.commandId,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    commandRevision: commandRevision ?? this.commandRevision,
    actionType: actionType ?? this.actionType,
    status: status ?? this.status,
    businessOperationId: businessOperationId.present
        ? businessOperationId.value
        : this.businessOperationId,
    safeFailureCode: safeFailureCode.present
        ? safeFailureCode.value
        : this.safeFailureCode,
    claimedAt: claimedAt ?? this.claimedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  AiAgentExecutionAttemptRow copyWithCompanion(
    AiAgentExecutionAttemptsCompanion data,
  ) {
    return AiAgentExecutionAttemptRow(
      ownerScopeId: data.ownerScopeId.present
          ? data.ownerScopeId.value
          : this.ownerScopeId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      id: data.id.present ? data.id.value : this.id,
      commandId: data.commandId.present ? data.commandId.value : this.commandId,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      commandRevision: data.commandRevision.present
          ? data.commandRevision.value
          : this.commandRevision,
      actionType: data.actionType.present
          ? data.actionType.value
          : this.actionType,
      status: data.status.present ? data.status.value : this.status,
      businessOperationId: data.businessOperationId.present
          ? data.businessOperationId.value
          : this.businessOperationId,
      safeFailureCode: data.safeFailureCode.present
          ? data.safeFailureCode.value
          : this.safeFailureCode,
      claimedAt: data.claimedAt.present ? data.claimedAt.value : this.claimedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiAgentExecutionAttemptRow(')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('id: $id, ')
          ..write('commandId: $commandId, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('commandRevision: $commandRevision, ')
          ..write('actionType: $actionType, ')
          ..write('status: $status, ')
          ..write('businessOperationId: $businessOperationId, ')
          ..write('safeFailureCode: $safeFailureCode, ')
          ..write('claimedAt: $claimedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ownerScopeId,
    createdAt,
    updatedAt,
    id,
    commandId,
    idempotencyKey,
    commandRevision,
    actionType,
    status,
    businessOperationId,
    safeFailureCode,
    claimedAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiAgentExecutionAttemptRow &&
          other.ownerScopeId == this.ownerScopeId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.id == this.id &&
          other.commandId == this.commandId &&
          other.idempotencyKey == this.idempotencyKey &&
          other.commandRevision == this.commandRevision &&
          other.actionType == this.actionType &&
          other.status == this.status &&
          other.businessOperationId == this.businessOperationId &&
          other.safeFailureCode == this.safeFailureCode &&
          other.claimedAt == this.claimedAt &&
          other.completedAt == this.completedAt);
}

class AiAgentExecutionAttemptsCompanion
    extends UpdateCompanion<AiAgentExecutionAttemptRow> {
  final Value<String> ownerScopeId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> id;
  final Value<String> commandId;
  final Value<String> idempotencyKey;
  final Value<int> commandRevision;
  final Value<String> actionType;
  final Value<String> status;
  final Value<String?> businessOperationId;
  final Value<String?> safeFailureCode;
  final Value<DateTime> claimedAt;
  final Value<DateTime?> completedAt;
  final Value<int> rowid;
  const AiAgentExecutionAttemptsCompanion({
    this.ownerScopeId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.commandId = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.commandRevision = const Value.absent(),
    this.actionType = const Value.absent(),
    this.status = const Value.absent(),
    this.businessOperationId = const Value.absent(),
    this.safeFailureCode = const Value.absent(),
    this.claimedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiAgentExecutionAttemptsCompanion.insert({
    required String ownerScopeId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String id,
    required String commandId,
    required String idempotencyKey,
    required int commandRevision,
    required String actionType,
    required String status,
    this.businessOperationId = const Value.absent(),
    this.safeFailureCode = const Value.absent(),
    required DateTime claimedAt,
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ownerScopeId = Value(ownerScopeId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       id = Value(id),
       commandId = Value(commandId),
       idempotencyKey = Value(idempotencyKey),
       commandRevision = Value(commandRevision),
       actionType = Value(actionType),
       status = Value(status),
       claimedAt = Value(claimedAt);
  static Insertable<AiAgentExecutionAttemptRow> custom({
    Expression<String>? ownerScopeId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? id,
    Expression<String>? commandId,
    Expression<String>? idempotencyKey,
    Expression<int>? commandRevision,
    Expression<String>? actionType,
    Expression<String>? status,
    Expression<String>? businessOperationId,
    Expression<String>? safeFailureCode,
    Expression<DateTime>? claimedAt,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerScopeId != null) 'owner_scope_id': ownerScopeId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (id != null) 'id': id,
      if (commandId != null) 'command_id': commandId,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (commandRevision != null) 'command_revision': commandRevision,
      if (actionType != null) 'action_type': actionType,
      if (status != null) 'status': status,
      if (businessOperationId != null)
        'business_operation_id': businessOperationId,
      if (safeFailureCode != null) 'safe_failure_code': safeFailureCode,
      if (claimedAt != null) 'claimed_at': claimedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiAgentExecutionAttemptsCompanion copyWith({
    Value<String>? ownerScopeId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String>? id,
    Value<String>? commandId,
    Value<String>? idempotencyKey,
    Value<int>? commandRevision,
    Value<String>? actionType,
    Value<String>? status,
    Value<String?>? businessOperationId,
    Value<String?>? safeFailureCode,
    Value<DateTime>? claimedAt,
    Value<DateTime?>? completedAt,
    Value<int>? rowid,
  }) {
    return AiAgentExecutionAttemptsCompanion(
      ownerScopeId: ownerScopeId ?? this.ownerScopeId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      id: id ?? this.id,
      commandId: commandId ?? this.commandId,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      commandRevision: commandRevision ?? this.commandRevision,
      actionType: actionType ?? this.actionType,
      status: status ?? this.status,
      businessOperationId: businessOperationId ?? this.businessOperationId,
      safeFailureCode: safeFailureCode ?? this.safeFailureCode,
      claimedAt: claimedAt ?? this.claimedAt,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerScopeId.present) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (commandId.present) {
      map['command_id'] = Variable<String>(commandId.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (commandRevision.present) {
      map['command_revision'] = Variable<int>(commandRevision.value);
    }
    if (actionType.present) {
      map['action_type'] = Variable<String>(actionType.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (businessOperationId.present) {
      map['business_operation_id'] = Variable<String>(
        businessOperationId.value,
      );
    }
    if (safeFailureCode.present) {
      map['safe_failure_code'] = Variable<String>(safeFailureCode.value);
    }
    if (claimedAt.present) {
      map['claimed_at'] = Variable<DateTime>(claimedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiAgentExecutionAttemptsCompanion(')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('id: $id, ')
          ..write('commandId: $commandId, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('commandRevision: $commandRevision, ')
          ..write('actionType: $actionType, ')
          ..write('status: $status, ')
          ..write('businessOperationId: $businessOperationId, ')
          ..write('safeFailureCode: $safeFailureCode, ')
          ..write('claimedAt: $claimedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiAgentExecutionResultsTable extends AiAgentExecutionResults
    with TableInfo<$AiAgentExecutionResultsTable, AiAgentExecutionResultRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiAgentExecutionResultsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerScopeIdMeta = const VerificationMeta(
    'ownerScopeId',
  );
  @override
  late final GeneratedColumn<String> ownerScopeId = GeneratedColumn<String>(
    'owner_scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commandIdMeta = const VerificationMeta(
    'commandId',
  );
  @override
  late final GeneratedColumn<String> commandId = GeneratedColumn<String>(
    'command_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptIdMeta = const VerificationMeta(
    'attemptId',
  );
  @override
  late final GeneratedColumn<String> attemptId = GeneratedColumn<String>(
    'attempt_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _verifiedMeta = const VerificationMeta(
    'verified',
  );
  @override
  late final GeneratedColumn<bool> verified = GeneratedColumn<bool>(
    'verified',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("verified" IN (0, 1))',
    ),
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _affectedCountMeta = const VerificationMeta(
    'affectedCount',
  );
  @override
  late final GeneratedColumn<int> affectedCount = GeneratedColumn<int>(
    'affected_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _safeResultJsonMeta = const VerificationMeta(
    'safeResultJson',
  );
  @override
  late final GeneratedColumn<String> safeResultJson = GeneratedColumn<String>(
    'safe_result_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _safeFailureCodeMeta = const VerificationMeta(
    'safeFailureCode',
  );
  @override
  late final GeneratedColumn<String> safeFailureCode = GeneratedColumn<String>(
    'safe_failure_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerScopeId,
    createdAt,
    updatedAt,
    id,
    commandId,
    attemptId,
    status,
    verified,
    entityType,
    affectedCount,
    safeResultJson,
    safeFailureCode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_agent_execution_results';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiAgentExecutionResultRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_scope_id')) {
      context.handle(
        _ownerScopeIdMeta,
        ownerScopeId.isAcceptableOrUnknown(
          data['owner_scope_id']!,
          _ownerScopeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerScopeIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('command_id')) {
      context.handle(
        _commandIdMeta,
        commandId.isAcceptableOrUnknown(data['command_id']!, _commandIdMeta),
      );
    } else if (isInserting) {
      context.missing(_commandIdMeta);
    }
    if (data.containsKey('attempt_id')) {
      context.handle(
        _attemptIdMeta,
        attemptId.isAcceptableOrUnknown(data['attempt_id']!, _attemptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_attemptIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('verified')) {
      context.handle(
        _verifiedMeta,
        verified.isAcceptableOrUnknown(data['verified']!, _verifiedMeta),
      );
    } else if (isInserting) {
      context.missing(_verifiedMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('affected_count')) {
      context.handle(
        _affectedCountMeta,
        affectedCount.isAcceptableOrUnknown(
          data['affected_count']!,
          _affectedCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_affectedCountMeta);
    }
    if (data.containsKey('safe_result_json')) {
      context.handle(
        _safeResultJsonMeta,
        safeResultJson.isAcceptableOrUnknown(
          data['safe_result_json']!,
          _safeResultJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_safeResultJsonMeta);
    }
    if (data.containsKey('safe_failure_code')) {
      context.handle(
        _safeFailureCodeMeta,
        safeFailureCode.isAcceptableOrUnknown(
          data['safe_failure_code']!,
          _safeFailureCodeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiAgentExecutionResultRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiAgentExecutionResultRow(
      ownerScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_scope_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      commandId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}command_id'],
      )!,
      attemptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attempt_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      verified: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}verified'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      affectedCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}affected_count'],
      )!,
      safeResultJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}safe_result_json'],
      )!,
      safeFailureCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}safe_failure_code'],
      ),
    );
  }

  @override
  $AiAgentExecutionResultsTable createAlias(String alias) {
    return $AiAgentExecutionResultsTable(attachedDatabase, alias);
  }
}

class AiAgentExecutionResultRow extends DataClass
    implements Insertable<AiAgentExecutionResultRow> {
  final String ownerScopeId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String id;
  final String commandId;
  final String attemptId;
  final String status;
  final bool verified;
  final String entityType;
  final int affectedCount;
  final String safeResultJson;
  final String? safeFailureCode;
  const AiAgentExecutionResultRow({
    required this.ownerScopeId,
    required this.createdAt,
    required this.updatedAt,
    required this.id,
    required this.commandId,
    required this.attemptId,
    required this.status,
    required this.verified,
    required this.entityType,
    required this.affectedCount,
    required this.safeResultJson,
    this.safeFailureCode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_scope_id'] = Variable<String>(ownerScopeId);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['id'] = Variable<String>(id);
    map['command_id'] = Variable<String>(commandId);
    map['attempt_id'] = Variable<String>(attemptId);
    map['status'] = Variable<String>(status);
    map['verified'] = Variable<bool>(verified);
    map['entity_type'] = Variable<String>(entityType);
    map['affected_count'] = Variable<int>(affectedCount);
    map['safe_result_json'] = Variable<String>(safeResultJson);
    if (!nullToAbsent || safeFailureCode != null) {
      map['safe_failure_code'] = Variable<String>(safeFailureCode);
    }
    return map;
  }

  AiAgentExecutionResultsCompanion toCompanion(bool nullToAbsent) {
    return AiAgentExecutionResultsCompanion(
      ownerScopeId: Value(ownerScopeId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      id: Value(id),
      commandId: Value(commandId),
      attemptId: Value(attemptId),
      status: Value(status),
      verified: Value(verified),
      entityType: Value(entityType),
      affectedCount: Value(affectedCount),
      safeResultJson: Value(safeResultJson),
      safeFailureCode: safeFailureCode == null && nullToAbsent
          ? const Value.absent()
          : Value(safeFailureCode),
    );
  }

  factory AiAgentExecutionResultRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiAgentExecutionResultRow(
      ownerScopeId: serializer.fromJson<String>(json['ownerScopeId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      id: serializer.fromJson<String>(json['id']),
      commandId: serializer.fromJson<String>(json['commandId']),
      attemptId: serializer.fromJson<String>(json['attemptId']),
      status: serializer.fromJson<String>(json['status']),
      verified: serializer.fromJson<bool>(json['verified']),
      entityType: serializer.fromJson<String>(json['entityType']),
      affectedCount: serializer.fromJson<int>(json['affectedCount']),
      safeResultJson: serializer.fromJson<String>(json['safeResultJson']),
      safeFailureCode: serializer.fromJson<String?>(json['safeFailureCode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerScopeId': serializer.toJson<String>(ownerScopeId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'id': serializer.toJson<String>(id),
      'commandId': serializer.toJson<String>(commandId),
      'attemptId': serializer.toJson<String>(attemptId),
      'status': serializer.toJson<String>(status),
      'verified': serializer.toJson<bool>(verified),
      'entityType': serializer.toJson<String>(entityType),
      'affectedCount': serializer.toJson<int>(affectedCount),
      'safeResultJson': serializer.toJson<String>(safeResultJson),
      'safeFailureCode': serializer.toJson<String?>(safeFailureCode),
    };
  }

  AiAgentExecutionResultRow copyWith({
    String? ownerScopeId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? id,
    String? commandId,
    String? attemptId,
    String? status,
    bool? verified,
    String? entityType,
    int? affectedCount,
    String? safeResultJson,
    Value<String?> safeFailureCode = const Value.absent(),
  }) => AiAgentExecutionResultRow(
    ownerScopeId: ownerScopeId ?? this.ownerScopeId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    id: id ?? this.id,
    commandId: commandId ?? this.commandId,
    attemptId: attemptId ?? this.attemptId,
    status: status ?? this.status,
    verified: verified ?? this.verified,
    entityType: entityType ?? this.entityType,
    affectedCount: affectedCount ?? this.affectedCount,
    safeResultJson: safeResultJson ?? this.safeResultJson,
    safeFailureCode: safeFailureCode.present
        ? safeFailureCode.value
        : this.safeFailureCode,
  );
  AiAgentExecutionResultRow copyWithCompanion(
    AiAgentExecutionResultsCompanion data,
  ) {
    return AiAgentExecutionResultRow(
      ownerScopeId: data.ownerScopeId.present
          ? data.ownerScopeId.value
          : this.ownerScopeId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      id: data.id.present ? data.id.value : this.id,
      commandId: data.commandId.present ? data.commandId.value : this.commandId,
      attemptId: data.attemptId.present ? data.attemptId.value : this.attemptId,
      status: data.status.present ? data.status.value : this.status,
      verified: data.verified.present ? data.verified.value : this.verified,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      affectedCount: data.affectedCount.present
          ? data.affectedCount.value
          : this.affectedCount,
      safeResultJson: data.safeResultJson.present
          ? data.safeResultJson.value
          : this.safeResultJson,
      safeFailureCode: data.safeFailureCode.present
          ? data.safeFailureCode.value
          : this.safeFailureCode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiAgentExecutionResultRow(')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('id: $id, ')
          ..write('commandId: $commandId, ')
          ..write('attemptId: $attemptId, ')
          ..write('status: $status, ')
          ..write('verified: $verified, ')
          ..write('entityType: $entityType, ')
          ..write('affectedCount: $affectedCount, ')
          ..write('safeResultJson: $safeResultJson, ')
          ..write('safeFailureCode: $safeFailureCode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ownerScopeId,
    createdAt,
    updatedAt,
    id,
    commandId,
    attemptId,
    status,
    verified,
    entityType,
    affectedCount,
    safeResultJson,
    safeFailureCode,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiAgentExecutionResultRow &&
          other.ownerScopeId == this.ownerScopeId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.id == this.id &&
          other.commandId == this.commandId &&
          other.attemptId == this.attemptId &&
          other.status == this.status &&
          other.verified == this.verified &&
          other.entityType == this.entityType &&
          other.affectedCount == this.affectedCount &&
          other.safeResultJson == this.safeResultJson &&
          other.safeFailureCode == this.safeFailureCode);
}

class AiAgentExecutionResultsCompanion
    extends UpdateCompanion<AiAgentExecutionResultRow> {
  final Value<String> ownerScopeId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> id;
  final Value<String> commandId;
  final Value<String> attemptId;
  final Value<String> status;
  final Value<bool> verified;
  final Value<String> entityType;
  final Value<int> affectedCount;
  final Value<String> safeResultJson;
  final Value<String?> safeFailureCode;
  final Value<int> rowid;
  const AiAgentExecutionResultsCompanion({
    this.ownerScopeId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.commandId = const Value.absent(),
    this.attemptId = const Value.absent(),
    this.status = const Value.absent(),
    this.verified = const Value.absent(),
    this.entityType = const Value.absent(),
    this.affectedCount = const Value.absent(),
    this.safeResultJson = const Value.absent(),
    this.safeFailureCode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiAgentExecutionResultsCompanion.insert({
    required String ownerScopeId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String id,
    required String commandId,
    required String attemptId,
    required String status,
    required bool verified,
    required String entityType,
    required int affectedCount,
    required String safeResultJson,
    this.safeFailureCode = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ownerScopeId = Value(ownerScopeId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       id = Value(id),
       commandId = Value(commandId),
       attemptId = Value(attemptId),
       status = Value(status),
       verified = Value(verified),
       entityType = Value(entityType),
       affectedCount = Value(affectedCount),
       safeResultJson = Value(safeResultJson);
  static Insertable<AiAgentExecutionResultRow> custom({
    Expression<String>? ownerScopeId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? id,
    Expression<String>? commandId,
    Expression<String>? attemptId,
    Expression<String>? status,
    Expression<bool>? verified,
    Expression<String>? entityType,
    Expression<int>? affectedCount,
    Expression<String>? safeResultJson,
    Expression<String>? safeFailureCode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerScopeId != null) 'owner_scope_id': ownerScopeId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (id != null) 'id': id,
      if (commandId != null) 'command_id': commandId,
      if (attemptId != null) 'attempt_id': attemptId,
      if (status != null) 'status': status,
      if (verified != null) 'verified': verified,
      if (entityType != null) 'entity_type': entityType,
      if (affectedCount != null) 'affected_count': affectedCount,
      if (safeResultJson != null) 'safe_result_json': safeResultJson,
      if (safeFailureCode != null) 'safe_failure_code': safeFailureCode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiAgentExecutionResultsCompanion copyWith({
    Value<String>? ownerScopeId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String>? id,
    Value<String>? commandId,
    Value<String>? attemptId,
    Value<String>? status,
    Value<bool>? verified,
    Value<String>? entityType,
    Value<int>? affectedCount,
    Value<String>? safeResultJson,
    Value<String?>? safeFailureCode,
    Value<int>? rowid,
  }) {
    return AiAgentExecutionResultsCompanion(
      ownerScopeId: ownerScopeId ?? this.ownerScopeId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      id: id ?? this.id,
      commandId: commandId ?? this.commandId,
      attemptId: attemptId ?? this.attemptId,
      status: status ?? this.status,
      verified: verified ?? this.verified,
      entityType: entityType ?? this.entityType,
      affectedCount: affectedCount ?? this.affectedCount,
      safeResultJson: safeResultJson ?? this.safeResultJson,
      safeFailureCode: safeFailureCode ?? this.safeFailureCode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerScopeId.present) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (commandId.present) {
      map['command_id'] = Variable<String>(commandId.value);
    }
    if (attemptId.present) {
      map['attempt_id'] = Variable<String>(attemptId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (verified.present) {
      map['verified'] = Variable<bool>(verified.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (affectedCount.present) {
      map['affected_count'] = Variable<int>(affectedCount.value);
    }
    if (safeResultJson.present) {
      map['safe_result_json'] = Variable<String>(safeResultJson.value);
    }
    if (safeFailureCode.present) {
      map['safe_failure_code'] = Variable<String>(safeFailureCode.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiAgentExecutionResultsCompanion(')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('id: $id, ')
          ..write('commandId: $commandId, ')
          ..write('attemptId: $attemptId, ')
          ..write('status: $status, ')
          ..write('verified: $verified, ')
          ..write('entityType: $entityType, ')
          ..write('affectedCount: $affectedCount, ')
          ..write('safeResultJson: $safeResultJson, ')
          ..write('safeFailureCode: $safeFailureCode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiAgentPlansTable extends AiAgentPlans
    with TableInfo<$AiAgentPlansTable, AiAgentPlanRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiAgentPlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerScopeIdMeta = const VerificationMeta(
    'ownerScopeId',
  );
  @override
  late final GeneratedColumn<String> ownerScopeId = GeneratedColumn<String>(
    'owner_scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atomicMeta = const VerificationMeta('atomic');
  @override
  late final GeneratedColumn<bool> atomic = GeneratedColumn<bool>(
    'atomic',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("atomic" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerScopeId,
    createdAt,
    updatedAt,
    id,
    conversationId,
    status,
    atomic,
    expiresAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_agent_plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiAgentPlanRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_scope_id')) {
      context.handle(
        _ownerScopeIdMeta,
        ownerScopeId.isAcceptableOrUnknown(
          data['owner_scope_id']!,
          _ownerScopeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerScopeIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('atomic')) {
      context.handle(
        _atomicMeta,
        atomic.isAcceptableOrUnknown(data['atomic']!, _atomicMeta),
      );
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiAgentPlanRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiAgentPlanRow(
      ownerScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_scope_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      atomic: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}atomic'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
    );
  }

  @override
  $AiAgentPlansTable createAlias(String alias) {
    return $AiAgentPlansTable(attachedDatabase, alias);
  }
}

class AiAgentPlanRow extends DataClass implements Insertable<AiAgentPlanRow> {
  final String ownerScopeId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String id;
  final String conversationId;
  final String status;
  final bool atomic;
  final DateTime expiresAt;
  const AiAgentPlanRow({
    required this.ownerScopeId,
    required this.createdAt,
    required this.updatedAt,
    required this.id,
    required this.conversationId,
    required this.status,
    required this.atomic,
    required this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_scope_id'] = Variable<String>(ownerScopeId);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['status'] = Variable<String>(status);
    map['atomic'] = Variable<bool>(atomic);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    return map;
  }

  AiAgentPlansCompanion toCompanion(bool nullToAbsent) {
    return AiAgentPlansCompanion(
      ownerScopeId: Value(ownerScopeId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      id: Value(id),
      conversationId: Value(conversationId),
      status: Value(status),
      atomic: Value(atomic),
      expiresAt: Value(expiresAt),
    );
  }

  factory AiAgentPlanRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiAgentPlanRow(
      ownerScopeId: serializer.fromJson<String>(json['ownerScopeId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      status: serializer.fromJson<String>(json['status']),
      atomic: serializer.fromJson<bool>(json['atomic']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerScopeId': serializer.toJson<String>(ownerScopeId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'status': serializer.toJson<String>(status),
      'atomic': serializer.toJson<bool>(atomic),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
    };
  }

  AiAgentPlanRow copyWith({
    String? ownerScopeId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? id,
    String? conversationId,
    String? status,
    bool? atomic,
    DateTime? expiresAt,
  }) => AiAgentPlanRow(
    ownerScopeId: ownerScopeId ?? this.ownerScopeId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    status: status ?? this.status,
    atomic: atomic ?? this.atomic,
    expiresAt: expiresAt ?? this.expiresAt,
  );
  AiAgentPlanRow copyWithCompanion(AiAgentPlansCompanion data) {
    return AiAgentPlanRow(
      ownerScopeId: data.ownerScopeId.present
          ? data.ownerScopeId.value
          : this.ownerScopeId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      status: data.status.present ? data.status.value : this.status,
      atomic: data.atomic.present ? data.atomic.value : this.atomic,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiAgentPlanRow(')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('status: $status, ')
          ..write('atomic: $atomic, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ownerScopeId,
    createdAt,
    updatedAt,
    id,
    conversationId,
    status,
    atomic,
    expiresAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiAgentPlanRow &&
          other.ownerScopeId == this.ownerScopeId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.status == this.status &&
          other.atomic == this.atomic &&
          other.expiresAt == this.expiresAt);
}

class AiAgentPlansCompanion extends UpdateCompanion<AiAgentPlanRow> {
  final Value<String> ownerScopeId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> status;
  final Value<bool> atomic;
  final Value<DateTime> expiresAt;
  final Value<int> rowid;
  const AiAgentPlansCompanion({
    this.ownerScopeId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.status = const Value.absent(),
    this.atomic = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiAgentPlansCompanion.insert({
    required String ownerScopeId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String id,
    required String conversationId,
    required String status,
    this.atomic = const Value.absent(),
    required DateTime expiresAt,
    this.rowid = const Value.absent(),
  }) : ownerScopeId = Value(ownerScopeId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       id = Value(id),
       conversationId = Value(conversationId),
       status = Value(status),
       expiresAt = Value(expiresAt);
  static Insertable<AiAgentPlanRow> custom({
    Expression<String>? ownerScopeId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? status,
    Expression<bool>? atomic,
    Expression<DateTime>? expiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerScopeId != null) 'owner_scope_id': ownerScopeId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (status != null) 'status': status,
      if (atomic != null) 'atomic': atomic,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiAgentPlansCompanion copyWith({
    Value<String>? ownerScopeId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String>? id,
    Value<String>? conversationId,
    Value<String>? status,
    Value<bool>? atomic,
    Value<DateTime>? expiresAt,
    Value<int>? rowid,
  }) {
    return AiAgentPlansCompanion(
      ownerScopeId: ownerScopeId ?? this.ownerScopeId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      status: status ?? this.status,
      atomic: atomic ?? this.atomic,
      expiresAt: expiresAt ?? this.expiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerScopeId.present) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (atomic.present) {
      map['atomic'] = Variable<bool>(atomic.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiAgentPlansCompanion(')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('status: $status, ')
          ..write('atomic: $atomic, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiAgentPlanStepsTable extends AiAgentPlanSteps
    with TableInfo<$AiAgentPlanStepsTable, AiAgentPlanStepRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiAgentPlanStepsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerScopeIdMeta = const VerificationMeta(
    'ownerScopeId',
  );
  @override
  late final GeneratedColumn<String> ownerScopeId = GeneratedColumn<String>(
    'owner_scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
    'plan_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commandIdMeta = const VerificationMeta(
    'commandId',
  );
  @override
  late final GeneratedColumn<String> commandId = GeneratedColumn<String>(
    'command_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerScopeId,
    createdAt,
    updatedAt,
    id,
    planId,
    commandId,
    position,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_agent_plan_steps';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiAgentPlanStepRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_scope_id')) {
      context.handle(
        _ownerScopeIdMeta,
        ownerScopeId.isAcceptableOrUnknown(
          data['owner_scope_id']!,
          _ownerScopeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerScopeIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('plan_id')) {
      context.handle(
        _planIdMeta,
        planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta),
      );
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('command_id')) {
      context.handle(
        _commandIdMeta,
        commandId.isAcceptableOrUnknown(data['command_id']!, _commandIdMeta),
      );
    } else if (isInserting) {
      context.missing(_commandIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiAgentPlanStepRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiAgentPlanStepRow(
      ownerScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_scope_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      planId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_id'],
      )!,
      commandId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}command_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $AiAgentPlanStepsTable createAlias(String alias) {
    return $AiAgentPlanStepsTable(attachedDatabase, alias);
  }
}

class AiAgentPlanStepRow extends DataClass
    implements Insertable<AiAgentPlanStepRow> {
  final String ownerScopeId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String id;
  final String planId;
  final String commandId;
  final int position;
  final String status;
  const AiAgentPlanStepRow({
    required this.ownerScopeId,
    required this.createdAt,
    required this.updatedAt,
    required this.id,
    required this.planId,
    required this.commandId,
    required this.position,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_scope_id'] = Variable<String>(ownerScopeId);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['id'] = Variable<String>(id);
    map['plan_id'] = Variable<String>(planId);
    map['command_id'] = Variable<String>(commandId);
    map['position'] = Variable<int>(position);
    map['status'] = Variable<String>(status);
    return map;
  }

  AiAgentPlanStepsCompanion toCompanion(bool nullToAbsent) {
    return AiAgentPlanStepsCompanion(
      ownerScopeId: Value(ownerScopeId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      id: Value(id),
      planId: Value(planId),
      commandId: Value(commandId),
      position: Value(position),
      status: Value(status),
    );
  }

  factory AiAgentPlanStepRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiAgentPlanStepRow(
      ownerScopeId: serializer.fromJson<String>(json['ownerScopeId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      id: serializer.fromJson<String>(json['id']),
      planId: serializer.fromJson<String>(json['planId']),
      commandId: serializer.fromJson<String>(json['commandId']),
      position: serializer.fromJson<int>(json['position']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerScopeId': serializer.toJson<String>(ownerScopeId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'id': serializer.toJson<String>(id),
      'planId': serializer.toJson<String>(planId),
      'commandId': serializer.toJson<String>(commandId),
      'position': serializer.toJson<int>(position),
      'status': serializer.toJson<String>(status),
    };
  }

  AiAgentPlanStepRow copyWith({
    String? ownerScopeId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? id,
    String? planId,
    String? commandId,
    int? position,
    String? status,
  }) => AiAgentPlanStepRow(
    ownerScopeId: ownerScopeId ?? this.ownerScopeId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    id: id ?? this.id,
    planId: planId ?? this.planId,
    commandId: commandId ?? this.commandId,
    position: position ?? this.position,
    status: status ?? this.status,
  );
  AiAgentPlanStepRow copyWithCompanion(AiAgentPlanStepsCompanion data) {
    return AiAgentPlanStepRow(
      ownerScopeId: data.ownerScopeId.present
          ? data.ownerScopeId.value
          : this.ownerScopeId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      id: data.id.present ? data.id.value : this.id,
      planId: data.planId.present ? data.planId.value : this.planId,
      commandId: data.commandId.present ? data.commandId.value : this.commandId,
      position: data.position.present ? data.position.value : this.position,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiAgentPlanStepRow(')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('commandId: $commandId, ')
          ..write('position: $position, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ownerScopeId,
    createdAt,
    updatedAt,
    id,
    planId,
    commandId,
    position,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiAgentPlanStepRow &&
          other.ownerScopeId == this.ownerScopeId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.id == this.id &&
          other.planId == this.planId &&
          other.commandId == this.commandId &&
          other.position == this.position &&
          other.status == this.status);
}

class AiAgentPlanStepsCompanion extends UpdateCompanion<AiAgentPlanStepRow> {
  final Value<String> ownerScopeId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> id;
  final Value<String> planId;
  final Value<String> commandId;
  final Value<int> position;
  final Value<String> status;
  final Value<int> rowid;
  const AiAgentPlanStepsCompanion({
    this.ownerScopeId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.planId = const Value.absent(),
    this.commandId = const Value.absent(),
    this.position = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiAgentPlanStepsCompanion.insert({
    required String ownerScopeId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String id,
    required String planId,
    required String commandId,
    required int position,
    required String status,
    this.rowid = const Value.absent(),
  }) : ownerScopeId = Value(ownerScopeId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       id = Value(id),
       planId = Value(planId),
       commandId = Value(commandId),
       position = Value(position),
       status = Value(status);
  static Insertable<AiAgentPlanStepRow> custom({
    Expression<String>? ownerScopeId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? id,
    Expression<String>? planId,
    Expression<String>? commandId,
    Expression<int>? position,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerScopeId != null) 'owner_scope_id': ownerScopeId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (id != null) 'id': id,
      if (planId != null) 'plan_id': planId,
      if (commandId != null) 'command_id': commandId,
      if (position != null) 'position': position,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiAgentPlanStepsCompanion copyWith({
    Value<String>? ownerScopeId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String>? id,
    Value<String>? planId,
    Value<String>? commandId,
    Value<int>? position,
    Value<String>? status,
    Value<int>? rowid,
  }) {
    return AiAgentPlanStepsCompanion(
      ownerScopeId: ownerScopeId ?? this.ownerScopeId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      id: id ?? this.id,
      planId: planId ?? this.planId,
      commandId: commandId ?? this.commandId,
      position: position ?? this.position,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerScopeId.present) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (commandId.present) {
      map['command_id'] = Variable<String>(commandId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiAgentPlanStepsCompanion(')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('commandId: $commandId, ')
          ..write('position: $position, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiAgentAuditEventsTable extends AiAgentAuditEvents
    with TableInfo<$AiAgentAuditEventsTable, AiAgentAuditEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiAgentAuditEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerScopeIdMeta = const VerificationMeta(
    'ownerScopeId',
  );
  @override
  late final GeneratedColumn<String> ownerScopeId = GeneratedColumn<String>(
    'owner_scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commandIdMeta = const VerificationMeta(
    'commandId',
  );
  @override
  late final GeneratedColumn<String> commandId = GeneratedColumn<String>(
    'command_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionTypeMeta = const VerificationMeta(
    'actionType',
  );
  @override
  late final GeneratedColumn<String> actionType = GeneratedColumn<String>(
    'action_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  @override
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
    'result',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confirmationMethodMeta =
      const VerificationMeta('confirmationMethod');
  @override
  late final GeneratedColumn<String> confirmationMethod =
      GeneratedColumn<String>(
        'confirmation_method',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _safeFailureCodeMeta = const VerificationMeta(
    'safeFailureCode',
  );
  @override
  late final GeneratedColumn<String> safeFailureCode = GeneratedColumn<String>(
    'safe_failure_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _undoAvailableMeta = const VerificationMeta(
    'undoAvailable',
  );
  @override
  late final GeneratedColumn<bool> undoAvailable = GeneratedColumn<bool>(
    'undo_available',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("undo_available" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerScopeId,
    createdAt,
    updatedAt,
    id,
    commandId,
    actionType,
    entityType,
    result,
    confirmationMethod,
    safeFailureCode,
    undoAvailable,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_agent_audit_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiAgentAuditEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_scope_id')) {
      context.handle(
        _ownerScopeIdMeta,
        ownerScopeId.isAcceptableOrUnknown(
          data['owner_scope_id']!,
          _ownerScopeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerScopeIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('command_id')) {
      context.handle(
        _commandIdMeta,
        commandId.isAcceptableOrUnknown(data['command_id']!, _commandIdMeta),
      );
    } else if (isInserting) {
      context.missing(_commandIdMeta);
    }
    if (data.containsKey('action_type')) {
      context.handle(
        _actionTypeMeta,
        actionType.isAcceptableOrUnknown(data['action_type']!, _actionTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_actionTypeMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('result')) {
      context.handle(
        _resultMeta,
        result.isAcceptableOrUnknown(data['result']!, _resultMeta),
      );
    } else if (isInserting) {
      context.missing(_resultMeta);
    }
    if (data.containsKey('confirmation_method')) {
      context.handle(
        _confirmationMethodMeta,
        confirmationMethod.isAcceptableOrUnknown(
          data['confirmation_method']!,
          _confirmationMethodMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_confirmationMethodMeta);
    }
    if (data.containsKey('safe_failure_code')) {
      context.handle(
        _safeFailureCodeMeta,
        safeFailureCode.isAcceptableOrUnknown(
          data['safe_failure_code']!,
          _safeFailureCodeMeta,
        ),
      );
    }
    if (data.containsKey('undo_available')) {
      context.handle(
        _undoAvailableMeta,
        undoAvailable.isAcceptableOrUnknown(
          data['undo_available']!,
          _undoAvailableMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiAgentAuditEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiAgentAuditEventRow(
      ownerScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_scope_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      commandId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}command_id'],
      )!,
      actionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action_type'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      result: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result'],
      )!,
      confirmationMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}confirmation_method'],
      )!,
      safeFailureCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}safe_failure_code'],
      ),
      undoAvailable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}undo_available'],
      )!,
    );
  }

  @override
  $AiAgentAuditEventsTable createAlias(String alias) {
    return $AiAgentAuditEventsTable(attachedDatabase, alias);
  }
}

class AiAgentAuditEventRow extends DataClass
    implements Insertable<AiAgentAuditEventRow> {
  final String ownerScopeId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String id;
  final String commandId;
  final String actionType;
  final String entityType;
  final String result;
  final String confirmationMethod;
  final String? safeFailureCode;
  final bool undoAvailable;
  const AiAgentAuditEventRow({
    required this.ownerScopeId,
    required this.createdAt,
    required this.updatedAt,
    required this.id,
    required this.commandId,
    required this.actionType,
    required this.entityType,
    required this.result,
    required this.confirmationMethod,
    this.safeFailureCode,
    required this.undoAvailable,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_scope_id'] = Variable<String>(ownerScopeId);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['id'] = Variable<String>(id);
    map['command_id'] = Variable<String>(commandId);
    map['action_type'] = Variable<String>(actionType);
    map['entity_type'] = Variable<String>(entityType);
    map['result'] = Variable<String>(result);
    map['confirmation_method'] = Variable<String>(confirmationMethod);
    if (!nullToAbsent || safeFailureCode != null) {
      map['safe_failure_code'] = Variable<String>(safeFailureCode);
    }
    map['undo_available'] = Variable<bool>(undoAvailable);
    return map;
  }

  AiAgentAuditEventsCompanion toCompanion(bool nullToAbsent) {
    return AiAgentAuditEventsCompanion(
      ownerScopeId: Value(ownerScopeId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      id: Value(id),
      commandId: Value(commandId),
      actionType: Value(actionType),
      entityType: Value(entityType),
      result: Value(result),
      confirmationMethod: Value(confirmationMethod),
      safeFailureCode: safeFailureCode == null && nullToAbsent
          ? const Value.absent()
          : Value(safeFailureCode),
      undoAvailable: Value(undoAvailable),
    );
  }

  factory AiAgentAuditEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiAgentAuditEventRow(
      ownerScopeId: serializer.fromJson<String>(json['ownerScopeId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      id: serializer.fromJson<String>(json['id']),
      commandId: serializer.fromJson<String>(json['commandId']),
      actionType: serializer.fromJson<String>(json['actionType']),
      entityType: serializer.fromJson<String>(json['entityType']),
      result: serializer.fromJson<String>(json['result']),
      confirmationMethod: serializer.fromJson<String>(
        json['confirmationMethod'],
      ),
      safeFailureCode: serializer.fromJson<String?>(json['safeFailureCode']),
      undoAvailable: serializer.fromJson<bool>(json['undoAvailable']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerScopeId': serializer.toJson<String>(ownerScopeId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'id': serializer.toJson<String>(id),
      'commandId': serializer.toJson<String>(commandId),
      'actionType': serializer.toJson<String>(actionType),
      'entityType': serializer.toJson<String>(entityType),
      'result': serializer.toJson<String>(result),
      'confirmationMethod': serializer.toJson<String>(confirmationMethod),
      'safeFailureCode': serializer.toJson<String?>(safeFailureCode),
      'undoAvailable': serializer.toJson<bool>(undoAvailable),
    };
  }

  AiAgentAuditEventRow copyWith({
    String? ownerScopeId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? id,
    String? commandId,
    String? actionType,
    String? entityType,
    String? result,
    String? confirmationMethod,
    Value<String?> safeFailureCode = const Value.absent(),
    bool? undoAvailable,
  }) => AiAgentAuditEventRow(
    ownerScopeId: ownerScopeId ?? this.ownerScopeId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    id: id ?? this.id,
    commandId: commandId ?? this.commandId,
    actionType: actionType ?? this.actionType,
    entityType: entityType ?? this.entityType,
    result: result ?? this.result,
    confirmationMethod: confirmationMethod ?? this.confirmationMethod,
    safeFailureCode: safeFailureCode.present
        ? safeFailureCode.value
        : this.safeFailureCode,
    undoAvailable: undoAvailable ?? this.undoAvailable,
  );
  AiAgentAuditEventRow copyWithCompanion(AiAgentAuditEventsCompanion data) {
    return AiAgentAuditEventRow(
      ownerScopeId: data.ownerScopeId.present
          ? data.ownerScopeId.value
          : this.ownerScopeId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      id: data.id.present ? data.id.value : this.id,
      commandId: data.commandId.present ? data.commandId.value : this.commandId,
      actionType: data.actionType.present
          ? data.actionType.value
          : this.actionType,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      result: data.result.present ? data.result.value : this.result,
      confirmationMethod: data.confirmationMethod.present
          ? data.confirmationMethod.value
          : this.confirmationMethod,
      safeFailureCode: data.safeFailureCode.present
          ? data.safeFailureCode.value
          : this.safeFailureCode,
      undoAvailable: data.undoAvailable.present
          ? data.undoAvailable.value
          : this.undoAvailable,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiAgentAuditEventRow(')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('id: $id, ')
          ..write('commandId: $commandId, ')
          ..write('actionType: $actionType, ')
          ..write('entityType: $entityType, ')
          ..write('result: $result, ')
          ..write('confirmationMethod: $confirmationMethod, ')
          ..write('safeFailureCode: $safeFailureCode, ')
          ..write('undoAvailable: $undoAvailable')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ownerScopeId,
    createdAt,
    updatedAt,
    id,
    commandId,
    actionType,
    entityType,
    result,
    confirmationMethod,
    safeFailureCode,
    undoAvailable,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiAgentAuditEventRow &&
          other.ownerScopeId == this.ownerScopeId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.id == this.id &&
          other.commandId == this.commandId &&
          other.actionType == this.actionType &&
          other.entityType == this.entityType &&
          other.result == this.result &&
          other.confirmationMethod == this.confirmationMethod &&
          other.safeFailureCode == this.safeFailureCode &&
          other.undoAvailable == this.undoAvailable);
}

class AiAgentAuditEventsCompanion
    extends UpdateCompanion<AiAgentAuditEventRow> {
  final Value<String> ownerScopeId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> id;
  final Value<String> commandId;
  final Value<String> actionType;
  final Value<String> entityType;
  final Value<String> result;
  final Value<String> confirmationMethod;
  final Value<String?> safeFailureCode;
  final Value<bool> undoAvailable;
  final Value<int> rowid;
  const AiAgentAuditEventsCompanion({
    this.ownerScopeId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.commandId = const Value.absent(),
    this.actionType = const Value.absent(),
    this.entityType = const Value.absent(),
    this.result = const Value.absent(),
    this.confirmationMethod = const Value.absent(),
    this.safeFailureCode = const Value.absent(),
    this.undoAvailable = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiAgentAuditEventsCompanion.insert({
    required String ownerScopeId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String id,
    required String commandId,
    required String actionType,
    required String entityType,
    required String result,
    required String confirmationMethod,
    this.safeFailureCode = const Value.absent(),
    this.undoAvailable = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ownerScopeId = Value(ownerScopeId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       id = Value(id),
       commandId = Value(commandId),
       actionType = Value(actionType),
       entityType = Value(entityType),
       result = Value(result),
       confirmationMethod = Value(confirmationMethod);
  static Insertable<AiAgentAuditEventRow> custom({
    Expression<String>? ownerScopeId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? id,
    Expression<String>? commandId,
    Expression<String>? actionType,
    Expression<String>? entityType,
    Expression<String>? result,
    Expression<String>? confirmationMethod,
    Expression<String>? safeFailureCode,
    Expression<bool>? undoAvailable,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerScopeId != null) 'owner_scope_id': ownerScopeId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (id != null) 'id': id,
      if (commandId != null) 'command_id': commandId,
      if (actionType != null) 'action_type': actionType,
      if (entityType != null) 'entity_type': entityType,
      if (result != null) 'result': result,
      if (confirmationMethod != null) 'confirmation_method': confirmationMethod,
      if (safeFailureCode != null) 'safe_failure_code': safeFailureCode,
      if (undoAvailable != null) 'undo_available': undoAvailable,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiAgentAuditEventsCompanion copyWith({
    Value<String>? ownerScopeId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String>? id,
    Value<String>? commandId,
    Value<String>? actionType,
    Value<String>? entityType,
    Value<String>? result,
    Value<String>? confirmationMethod,
    Value<String?>? safeFailureCode,
    Value<bool>? undoAvailable,
    Value<int>? rowid,
  }) {
    return AiAgentAuditEventsCompanion(
      ownerScopeId: ownerScopeId ?? this.ownerScopeId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      id: id ?? this.id,
      commandId: commandId ?? this.commandId,
      actionType: actionType ?? this.actionType,
      entityType: entityType ?? this.entityType,
      result: result ?? this.result,
      confirmationMethod: confirmationMethod ?? this.confirmationMethod,
      safeFailureCode: safeFailureCode ?? this.safeFailureCode,
      undoAvailable: undoAvailable ?? this.undoAvailable,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerScopeId.present) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (commandId.present) {
      map['command_id'] = Variable<String>(commandId.value);
    }
    if (actionType.present) {
      map['action_type'] = Variable<String>(actionType.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    if (confirmationMethod.present) {
      map['confirmation_method'] = Variable<String>(confirmationMethod.value);
    }
    if (safeFailureCode.present) {
      map['safe_failure_code'] = Variable<String>(safeFailureCode.value);
    }
    if (undoAvailable.present) {
      map['undo_available'] = Variable<bool>(undoAvailable.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiAgentAuditEventsCompanion(')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('id: $id, ')
          ..write('commandId: $commandId, ')
          ..write('actionType: $actionType, ')
          ..write('entityType: $entityType, ')
          ..write('result: $result, ')
          ..write('confirmationMethod: $confirmationMethod, ')
          ..write('safeFailureCode: $safeFailureCode, ')
          ..write('undoAvailable: $undoAvailable, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiAgentIdempotencyRecordsTable extends AiAgentIdempotencyRecords
    with
        TableInfo<
          $AiAgentIdempotencyRecordsTable,
          AiAgentIdempotencyRecordRow
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiAgentIdempotencyRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerScopeIdMeta = const VerificationMeta(
    'ownerScopeId',
  );
  @override
  late final GeneratedColumn<String> ownerScopeId = GeneratedColumn<String>(
    'owner_scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commandIdMeta = const VerificationMeta(
    'commandId',
  );
  @override
  late final GeneratedColumn<String> commandId = GeneratedColumn<String>(
    'command_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commandRevisionMeta = const VerificationMeta(
    'commandRevision',
  );
  @override
  late final GeneratedColumn<int> commandRevision = GeneratedColumn<int>(
    'command_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionTypeMeta = const VerificationMeta(
    'actionType',
  );
  @override
  late final GeneratedColumn<String> actionType = GeneratedColumn<String>(
    'action_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idempotencyHashMeta = const VerificationMeta(
    'idempotencyHash',
  );
  @override
  late final GeneratedColumn<String> idempotencyHash = GeneratedColumn<String>(
    'idempotency_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _executionResultIdMeta = const VerificationMeta(
    'executionResultId',
  );
  @override
  late final GeneratedColumn<String> executionResultId =
      GeneratedColumn<String>(
        'execution_result_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerScopeId,
    createdAt,
    updatedAt,
    id,
    commandId,
    commandRevision,
    actionType,
    idempotencyHash,
    status,
    executionResultId,
    expiresAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_agent_idempotency_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiAgentIdempotencyRecordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_scope_id')) {
      context.handle(
        _ownerScopeIdMeta,
        ownerScopeId.isAcceptableOrUnknown(
          data['owner_scope_id']!,
          _ownerScopeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerScopeIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('command_id')) {
      context.handle(
        _commandIdMeta,
        commandId.isAcceptableOrUnknown(data['command_id']!, _commandIdMeta),
      );
    } else if (isInserting) {
      context.missing(_commandIdMeta);
    }
    if (data.containsKey('command_revision')) {
      context.handle(
        _commandRevisionMeta,
        commandRevision.isAcceptableOrUnknown(
          data['command_revision']!,
          _commandRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_commandRevisionMeta);
    }
    if (data.containsKey('action_type')) {
      context.handle(
        _actionTypeMeta,
        actionType.isAcceptableOrUnknown(data['action_type']!, _actionTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_actionTypeMeta);
    }
    if (data.containsKey('idempotency_hash')) {
      context.handle(
        _idempotencyHashMeta,
        idempotencyHash.isAcceptableOrUnknown(
          data['idempotency_hash']!,
          _idempotencyHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyHashMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('execution_result_id')) {
      context.handle(
        _executionResultIdMeta,
        executionResultId.isAcceptableOrUnknown(
          data['execution_result_id']!,
          _executionResultIdMeta,
        ),
      );
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiAgentIdempotencyRecordRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiAgentIdempotencyRecordRow(
      ownerScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_scope_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      commandId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}command_id'],
      )!,
      commandRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}command_revision'],
      )!,
      actionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action_type'],
      )!,
      idempotencyHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_hash'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      executionResultId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}execution_result_id'],
      ),
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      ),
    );
  }

  @override
  $AiAgentIdempotencyRecordsTable createAlias(String alias) {
    return $AiAgentIdempotencyRecordsTable(attachedDatabase, alias);
  }
}

class AiAgentIdempotencyRecordRow extends DataClass
    implements Insertable<AiAgentIdempotencyRecordRow> {
  final String ownerScopeId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String id;
  final String commandId;
  final int commandRevision;
  final String actionType;
  final String idempotencyHash;
  final String status;
  final String? executionResultId;
  final DateTime? expiresAt;
  const AiAgentIdempotencyRecordRow({
    required this.ownerScopeId,
    required this.createdAt,
    required this.updatedAt,
    required this.id,
    required this.commandId,
    required this.commandRevision,
    required this.actionType,
    required this.idempotencyHash,
    required this.status,
    this.executionResultId,
    this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_scope_id'] = Variable<String>(ownerScopeId);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['id'] = Variable<String>(id);
    map['command_id'] = Variable<String>(commandId);
    map['command_revision'] = Variable<int>(commandRevision);
    map['action_type'] = Variable<String>(actionType);
    map['idempotency_hash'] = Variable<String>(idempotencyHash);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || executionResultId != null) {
      map['execution_result_id'] = Variable<String>(executionResultId);
    }
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<DateTime>(expiresAt);
    }
    return map;
  }

  AiAgentIdempotencyRecordsCompanion toCompanion(bool nullToAbsent) {
    return AiAgentIdempotencyRecordsCompanion(
      ownerScopeId: Value(ownerScopeId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      id: Value(id),
      commandId: Value(commandId),
      commandRevision: Value(commandRevision),
      actionType: Value(actionType),
      idempotencyHash: Value(idempotencyHash),
      status: Value(status),
      executionResultId: executionResultId == null && nullToAbsent
          ? const Value.absent()
          : Value(executionResultId),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
    );
  }

  factory AiAgentIdempotencyRecordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiAgentIdempotencyRecordRow(
      ownerScopeId: serializer.fromJson<String>(json['ownerScopeId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      id: serializer.fromJson<String>(json['id']),
      commandId: serializer.fromJson<String>(json['commandId']),
      commandRevision: serializer.fromJson<int>(json['commandRevision']),
      actionType: serializer.fromJson<String>(json['actionType']),
      idempotencyHash: serializer.fromJson<String>(json['idempotencyHash']),
      status: serializer.fromJson<String>(json['status']),
      executionResultId: serializer.fromJson<String?>(
        json['executionResultId'],
      ),
      expiresAt: serializer.fromJson<DateTime?>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerScopeId': serializer.toJson<String>(ownerScopeId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'id': serializer.toJson<String>(id),
      'commandId': serializer.toJson<String>(commandId),
      'commandRevision': serializer.toJson<int>(commandRevision),
      'actionType': serializer.toJson<String>(actionType),
      'idempotencyHash': serializer.toJson<String>(idempotencyHash),
      'status': serializer.toJson<String>(status),
      'executionResultId': serializer.toJson<String?>(executionResultId),
      'expiresAt': serializer.toJson<DateTime?>(expiresAt),
    };
  }

  AiAgentIdempotencyRecordRow copyWith({
    String? ownerScopeId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? id,
    String? commandId,
    int? commandRevision,
    String? actionType,
    String? idempotencyHash,
    String? status,
    Value<String?> executionResultId = const Value.absent(),
    Value<DateTime?> expiresAt = const Value.absent(),
  }) => AiAgentIdempotencyRecordRow(
    ownerScopeId: ownerScopeId ?? this.ownerScopeId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    id: id ?? this.id,
    commandId: commandId ?? this.commandId,
    commandRevision: commandRevision ?? this.commandRevision,
    actionType: actionType ?? this.actionType,
    idempotencyHash: idempotencyHash ?? this.idempotencyHash,
    status: status ?? this.status,
    executionResultId: executionResultId.present
        ? executionResultId.value
        : this.executionResultId,
    expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
  );
  AiAgentIdempotencyRecordRow copyWithCompanion(
    AiAgentIdempotencyRecordsCompanion data,
  ) {
    return AiAgentIdempotencyRecordRow(
      ownerScopeId: data.ownerScopeId.present
          ? data.ownerScopeId.value
          : this.ownerScopeId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      id: data.id.present ? data.id.value : this.id,
      commandId: data.commandId.present ? data.commandId.value : this.commandId,
      commandRevision: data.commandRevision.present
          ? data.commandRevision.value
          : this.commandRevision,
      actionType: data.actionType.present
          ? data.actionType.value
          : this.actionType,
      idempotencyHash: data.idempotencyHash.present
          ? data.idempotencyHash.value
          : this.idempotencyHash,
      status: data.status.present ? data.status.value : this.status,
      executionResultId: data.executionResultId.present
          ? data.executionResultId.value
          : this.executionResultId,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiAgentIdempotencyRecordRow(')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('id: $id, ')
          ..write('commandId: $commandId, ')
          ..write('commandRevision: $commandRevision, ')
          ..write('actionType: $actionType, ')
          ..write('idempotencyHash: $idempotencyHash, ')
          ..write('status: $status, ')
          ..write('executionResultId: $executionResultId, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ownerScopeId,
    createdAt,
    updatedAt,
    id,
    commandId,
    commandRevision,
    actionType,
    idempotencyHash,
    status,
    executionResultId,
    expiresAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiAgentIdempotencyRecordRow &&
          other.ownerScopeId == this.ownerScopeId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.id == this.id &&
          other.commandId == this.commandId &&
          other.commandRevision == this.commandRevision &&
          other.actionType == this.actionType &&
          other.idempotencyHash == this.idempotencyHash &&
          other.status == this.status &&
          other.executionResultId == this.executionResultId &&
          other.expiresAt == this.expiresAt);
}

class AiAgentIdempotencyRecordsCompanion
    extends UpdateCompanion<AiAgentIdempotencyRecordRow> {
  final Value<String> ownerScopeId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> id;
  final Value<String> commandId;
  final Value<int> commandRevision;
  final Value<String> actionType;
  final Value<String> idempotencyHash;
  final Value<String> status;
  final Value<String?> executionResultId;
  final Value<DateTime?> expiresAt;
  final Value<int> rowid;
  const AiAgentIdempotencyRecordsCompanion({
    this.ownerScopeId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.commandId = const Value.absent(),
    this.commandRevision = const Value.absent(),
    this.actionType = const Value.absent(),
    this.idempotencyHash = const Value.absent(),
    this.status = const Value.absent(),
    this.executionResultId = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiAgentIdempotencyRecordsCompanion.insert({
    required String ownerScopeId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String id,
    required String commandId,
    required int commandRevision,
    required String actionType,
    required String idempotencyHash,
    required String status,
    this.executionResultId = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ownerScopeId = Value(ownerScopeId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       id = Value(id),
       commandId = Value(commandId),
       commandRevision = Value(commandRevision),
       actionType = Value(actionType),
       idempotencyHash = Value(idempotencyHash),
       status = Value(status);
  static Insertable<AiAgentIdempotencyRecordRow> custom({
    Expression<String>? ownerScopeId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? id,
    Expression<String>? commandId,
    Expression<int>? commandRevision,
    Expression<String>? actionType,
    Expression<String>? idempotencyHash,
    Expression<String>? status,
    Expression<String>? executionResultId,
    Expression<DateTime>? expiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerScopeId != null) 'owner_scope_id': ownerScopeId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (id != null) 'id': id,
      if (commandId != null) 'command_id': commandId,
      if (commandRevision != null) 'command_revision': commandRevision,
      if (actionType != null) 'action_type': actionType,
      if (idempotencyHash != null) 'idempotency_hash': idempotencyHash,
      if (status != null) 'status': status,
      if (executionResultId != null) 'execution_result_id': executionResultId,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiAgentIdempotencyRecordsCompanion copyWith({
    Value<String>? ownerScopeId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String>? id,
    Value<String>? commandId,
    Value<int>? commandRevision,
    Value<String>? actionType,
    Value<String>? idempotencyHash,
    Value<String>? status,
    Value<String?>? executionResultId,
    Value<DateTime?>? expiresAt,
    Value<int>? rowid,
  }) {
    return AiAgentIdempotencyRecordsCompanion(
      ownerScopeId: ownerScopeId ?? this.ownerScopeId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      id: id ?? this.id,
      commandId: commandId ?? this.commandId,
      commandRevision: commandRevision ?? this.commandRevision,
      actionType: actionType ?? this.actionType,
      idempotencyHash: idempotencyHash ?? this.idempotencyHash,
      status: status ?? this.status,
      executionResultId: executionResultId ?? this.executionResultId,
      expiresAt: expiresAt ?? this.expiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerScopeId.present) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (commandId.present) {
      map['command_id'] = Variable<String>(commandId.value);
    }
    if (commandRevision.present) {
      map['command_revision'] = Variable<int>(commandRevision.value);
    }
    if (actionType.present) {
      map['action_type'] = Variable<String>(actionType.value);
    }
    if (idempotencyHash.present) {
      map['idempotency_hash'] = Variable<String>(idempotencyHash.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (executionResultId.present) {
      map['execution_result_id'] = Variable<String>(executionResultId.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiAgentIdempotencyRecordsCompanion(')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('id: $id, ')
          ..write('commandId: $commandId, ')
          ..write('commandRevision: $commandRevision, ')
          ..write('actionType: $actionType, ')
          ..write('idempotencyHash: $idempotencyHash, ')
          ..write('status: $status, ')
          ..write('executionResultId: $executionResultId, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiAgentBusinessOperationsTable extends AiAgentBusinessOperations
    with
        TableInfo<
          $AiAgentBusinessOperationsTable,
          AiAgentBusinessOperationRow
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiAgentBusinessOperationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerScopeIdMeta = const VerificationMeta(
    'ownerScopeId',
  );
  @override
  late final GeneratedColumn<String> ownerScopeId = GeneratedColumn<String>(
    'owner_scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commandIdMeta = const VerificationMeta(
    'commandId',
  );
  @override
  late final GeneratedColumn<String> commandId = GeneratedColumn<String>(
    'command_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commandRevisionMeta = const VerificationMeta(
    'commandRevision',
  );
  @override
  late final GeneratedColumn<int> commandRevision = GeneratedColumn<int>(
    'command_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionTypeMeta = const VerificationMeta(
    'actionType',
  );
  @override
  late final GeneratedColumn<String> actionType = GeneratedColumn<String>(
    'action_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expectedEntityIdsJsonMeta =
      const VerificationMeta('expectedEntityIdsJson');
  @override
  late final GeneratedColumn<String> expectedEntityIdsJson =
      GeneratedColumn<String>(
        'expected_entity_ids_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _verificationMethodMeta =
      const VerificationMeta('verificationMethod');
  @override
  late final GeneratedColumn<String> verificationMethod =
      GeneratedColumn<String>(
        'verification_method',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _automaticResumeAllowedMeta =
      const VerificationMeta('automaticResumeAllowed');
  @override
  late final GeneratedColumn<bool> automaticResumeAllowed =
      GeneratedColumn<bool>(
        'automatic_resume_allowed',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("automatic_resume_allowed" IN (0, 1))',
        ),
      );
  static const VerificationMeta _automaticRetryProhibitedMeta =
      const VerificationMeta('automaticRetryProhibited');
  @override
  late final GeneratedColumn<bool> automaticRetryProhibited =
      GeneratedColumn<bool>(
        'automatic_retry_prohibited',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("automatic_retry_prohibited" IN (0, 1))',
        ),
      );
  static const VerificationMeta _uiDeliveryAcknowledgedMeta =
      const VerificationMeta('uiDeliveryAcknowledged');
  @override
  late final GeneratedColumn<bool> uiDeliveryAcknowledged =
      GeneratedColumn<bool>(
        'ui_delivery_acknowledged',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("ui_delivery_acknowledged" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _safeFailureCodeMeta = const VerificationMeta(
    'safeFailureCode',
  );
  @override
  late final GeneratedColumn<String> safeFailureCode = GeneratedColumn<String>(
    'safe_failure_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerScopeId,
    createdAt,
    updatedAt,
    id,
    commandId,
    commandRevision,
    actionType,
    entityType,
    expectedEntityIdsJson,
    verificationMethod,
    status,
    automaticResumeAllowed,
    automaticRetryProhibited,
    uiDeliveryAcknowledged,
    safeFailureCode,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_agent_business_operations';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiAgentBusinessOperationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_scope_id')) {
      context.handle(
        _ownerScopeIdMeta,
        ownerScopeId.isAcceptableOrUnknown(
          data['owner_scope_id']!,
          _ownerScopeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerScopeIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('command_id')) {
      context.handle(
        _commandIdMeta,
        commandId.isAcceptableOrUnknown(data['command_id']!, _commandIdMeta),
      );
    } else if (isInserting) {
      context.missing(_commandIdMeta);
    }
    if (data.containsKey('command_revision')) {
      context.handle(
        _commandRevisionMeta,
        commandRevision.isAcceptableOrUnknown(
          data['command_revision']!,
          _commandRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_commandRevisionMeta);
    }
    if (data.containsKey('action_type')) {
      context.handle(
        _actionTypeMeta,
        actionType.isAcceptableOrUnknown(data['action_type']!, _actionTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_actionTypeMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('expected_entity_ids_json')) {
      context.handle(
        _expectedEntityIdsJsonMeta,
        expectedEntityIdsJson.isAcceptableOrUnknown(
          data['expected_entity_ids_json']!,
          _expectedEntityIdsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_expectedEntityIdsJsonMeta);
    }
    if (data.containsKey('verification_method')) {
      context.handle(
        _verificationMethodMeta,
        verificationMethod.isAcceptableOrUnknown(
          data['verification_method']!,
          _verificationMethodMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_verificationMethodMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('automatic_resume_allowed')) {
      context.handle(
        _automaticResumeAllowedMeta,
        automaticResumeAllowed.isAcceptableOrUnknown(
          data['automatic_resume_allowed']!,
          _automaticResumeAllowedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_automaticResumeAllowedMeta);
    }
    if (data.containsKey('automatic_retry_prohibited')) {
      context.handle(
        _automaticRetryProhibitedMeta,
        automaticRetryProhibited.isAcceptableOrUnknown(
          data['automatic_retry_prohibited']!,
          _automaticRetryProhibitedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_automaticRetryProhibitedMeta);
    }
    if (data.containsKey('ui_delivery_acknowledged')) {
      context.handle(
        _uiDeliveryAcknowledgedMeta,
        uiDeliveryAcknowledged.isAcceptableOrUnknown(
          data['ui_delivery_acknowledged']!,
          _uiDeliveryAcknowledgedMeta,
        ),
      );
    }
    if (data.containsKey('safe_failure_code')) {
      context.handle(
        _safeFailureCodeMeta,
        safeFailureCode.isAcceptableOrUnknown(
          data['safe_failure_code']!,
          _safeFailureCodeMeta,
        ),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiAgentBusinessOperationRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiAgentBusinessOperationRow(
      ownerScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_scope_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      commandId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}command_id'],
      )!,
      commandRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}command_revision'],
      )!,
      actionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action_type'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      expectedEntityIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expected_entity_ids_json'],
      )!,
      verificationMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}verification_method'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      automaticResumeAllowed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}automatic_resume_allowed'],
      )!,
      automaticRetryProhibited: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}automatic_retry_prohibited'],
      )!,
      uiDeliveryAcknowledged: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}ui_delivery_acknowledged'],
      )!,
      safeFailureCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}safe_failure_code'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $AiAgentBusinessOperationsTable createAlias(String alias) {
    return $AiAgentBusinessOperationsTable(attachedDatabase, alias);
  }
}

class AiAgentBusinessOperationRow extends DataClass
    implements Insertable<AiAgentBusinessOperationRow> {
  final String ownerScopeId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String id;
  final String commandId;
  final int commandRevision;
  final String actionType;
  final String entityType;
  final String expectedEntityIdsJson;
  final String verificationMethod;
  final String status;
  final bool automaticResumeAllowed;
  final bool automaticRetryProhibited;
  final bool uiDeliveryAcknowledged;
  final String? safeFailureCode;
  final DateTime? completedAt;
  const AiAgentBusinessOperationRow({
    required this.ownerScopeId,
    required this.createdAt,
    required this.updatedAt,
    required this.id,
    required this.commandId,
    required this.commandRevision,
    required this.actionType,
    required this.entityType,
    required this.expectedEntityIdsJson,
    required this.verificationMethod,
    required this.status,
    required this.automaticResumeAllowed,
    required this.automaticRetryProhibited,
    required this.uiDeliveryAcknowledged,
    this.safeFailureCode,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_scope_id'] = Variable<String>(ownerScopeId);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['id'] = Variable<String>(id);
    map['command_id'] = Variable<String>(commandId);
    map['command_revision'] = Variable<int>(commandRevision);
    map['action_type'] = Variable<String>(actionType);
    map['entity_type'] = Variable<String>(entityType);
    map['expected_entity_ids_json'] = Variable<String>(expectedEntityIdsJson);
    map['verification_method'] = Variable<String>(verificationMethod);
    map['status'] = Variable<String>(status);
    map['automatic_resume_allowed'] = Variable<bool>(automaticResumeAllowed);
    map['automatic_retry_prohibited'] = Variable<bool>(
      automaticRetryProhibited,
    );
    map['ui_delivery_acknowledged'] = Variable<bool>(uiDeliveryAcknowledged);
    if (!nullToAbsent || safeFailureCode != null) {
      map['safe_failure_code'] = Variable<String>(safeFailureCode);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  AiAgentBusinessOperationsCompanion toCompanion(bool nullToAbsent) {
    return AiAgentBusinessOperationsCompanion(
      ownerScopeId: Value(ownerScopeId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      id: Value(id),
      commandId: Value(commandId),
      commandRevision: Value(commandRevision),
      actionType: Value(actionType),
      entityType: Value(entityType),
      expectedEntityIdsJson: Value(expectedEntityIdsJson),
      verificationMethod: Value(verificationMethod),
      status: Value(status),
      automaticResumeAllowed: Value(automaticResumeAllowed),
      automaticRetryProhibited: Value(automaticRetryProhibited),
      uiDeliveryAcknowledged: Value(uiDeliveryAcknowledged),
      safeFailureCode: safeFailureCode == null && nullToAbsent
          ? const Value.absent()
          : Value(safeFailureCode),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory AiAgentBusinessOperationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiAgentBusinessOperationRow(
      ownerScopeId: serializer.fromJson<String>(json['ownerScopeId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      id: serializer.fromJson<String>(json['id']),
      commandId: serializer.fromJson<String>(json['commandId']),
      commandRevision: serializer.fromJson<int>(json['commandRevision']),
      actionType: serializer.fromJson<String>(json['actionType']),
      entityType: serializer.fromJson<String>(json['entityType']),
      expectedEntityIdsJson: serializer.fromJson<String>(
        json['expectedEntityIdsJson'],
      ),
      verificationMethod: serializer.fromJson<String>(
        json['verificationMethod'],
      ),
      status: serializer.fromJson<String>(json['status']),
      automaticResumeAllowed: serializer.fromJson<bool>(
        json['automaticResumeAllowed'],
      ),
      automaticRetryProhibited: serializer.fromJson<bool>(
        json['automaticRetryProhibited'],
      ),
      uiDeliveryAcknowledged: serializer.fromJson<bool>(
        json['uiDeliveryAcknowledged'],
      ),
      safeFailureCode: serializer.fromJson<String?>(json['safeFailureCode']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerScopeId': serializer.toJson<String>(ownerScopeId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'id': serializer.toJson<String>(id),
      'commandId': serializer.toJson<String>(commandId),
      'commandRevision': serializer.toJson<int>(commandRevision),
      'actionType': serializer.toJson<String>(actionType),
      'entityType': serializer.toJson<String>(entityType),
      'expectedEntityIdsJson': serializer.toJson<String>(expectedEntityIdsJson),
      'verificationMethod': serializer.toJson<String>(verificationMethod),
      'status': serializer.toJson<String>(status),
      'automaticResumeAllowed': serializer.toJson<bool>(automaticResumeAllowed),
      'automaticRetryProhibited': serializer.toJson<bool>(
        automaticRetryProhibited,
      ),
      'uiDeliveryAcknowledged': serializer.toJson<bool>(uiDeliveryAcknowledged),
      'safeFailureCode': serializer.toJson<String?>(safeFailureCode),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  AiAgentBusinessOperationRow copyWith({
    String? ownerScopeId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? id,
    String? commandId,
    int? commandRevision,
    String? actionType,
    String? entityType,
    String? expectedEntityIdsJson,
    String? verificationMethod,
    String? status,
    bool? automaticResumeAllowed,
    bool? automaticRetryProhibited,
    bool? uiDeliveryAcknowledged,
    Value<String?> safeFailureCode = const Value.absent(),
    Value<DateTime?> completedAt = const Value.absent(),
  }) => AiAgentBusinessOperationRow(
    ownerScopeId: ownerScopeId ?? this.ownerScopeId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    id: id ?? this.id,
    commandId: commandId ?? this.commandId,
    commandRevision: commandRevision ?? this.commandRevision,
    actionType: actionType ?? this.actionType,
    entityType: entityType ?? this.entityType,
    expectedEntityIdsJson: expectedEntityIdsJson ?? this.expectedEntityIdsJson,
    verificationMethod: verificationMethod ?? this.verificationMethod,
    status: status ?? this.status,
    automaticResumeAllowed:
        automaticResumeAllowed ?? this.automaticResumeAllowed,
    automaticRetryProhibited:
        automaticRetryProhibited ?? this.automaticRetryProhibited,
    uiDeliveryAcknowledged:
        uiDeliveryAcknowledged ?? this.uiDeliveryAcknowledged,
    safeFailureCode: safeFailureCode.present
        ? safeFailureCode.value
        : this.safeFailureCode,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  AiAgentBusinessOperationRow copyWithCompanion(
    AiAgentBusinessOperationsCompanion data,
  ) {
    return AiAgentBusinessOperationRow(
      ownerScopeId: data.ownerScopeId.present
          ? data.ownerScopeId.value
          : this.ownerScopeId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      id: data.id.present ? data.id.value : this.id,
      commandId: data.commandId.present ? data.commandId.value : this.commandId,
      commandRevision: data.commandRevision.present
          ? data.commandRevision.value
          : this.commandRevision,
      actionType: data.actionType.present
          ? data.actionType.value
          : this.actionType,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      expectedEntityIdsJson: data.expectedEntityIdsJson.present
          ? data.expectedEntityIdsJson.value
          : this.expectedEntityIdsJson,
      verificationMethod: data.verificationMethod.present
          ? data.verificationMethod.value
          : this.verificationMethod,
      status: data.status.present ? data.status.value : this.status,
      automaticResumeAllowed: data.automaticResumeAllowed.present
          ? data.automaticResumeAllowed.value
          : this.automaticResumeAllowed,
      automaticRetryProhibited: data.automaticRetryProhibited.present
          ? data.automaticRetryProhibited.value
          : this.automaticRetryProhibited,
      uiDeliveryAcknowledged: data.uiDeliveryAcknowledged.present
          ? data.uiDeliveryAcknowledged.value
          : this.uiDeliveryAcknowledged,
      safeFailureCode: data.safeFailureCode.present
          ? data.safeFailureCode.value
          : this.safeFailureCode,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiAgentBusinessOperationRow(')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('id: $id, ')
          ..write('commandId: $commandId, ')
          ..write('commandRevision: $commandRevision, ')
          ..write('actionType: $actionType, ')
          ..write('entityType: $entityType, ')
          ..write('expectedEntityIdsJson: $expectedEntityIdsJson, ')
          ..write('verificationMethod: $verificationMethod, ')
          ..write('status: $status, ')
          ..write('automaticResumeAllowed: $automaticResumeAllowed, ')
          ..write('automaticRetryProhibited: $automaticRetryProhibited, ')
          ..write('uiDeliveryAcknowledged: $uiDeliveryAcknowledged, ')
          ..write('safeFailureCode: $safeFailureCode, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ownerScopeId,
    createdAt,
    updatedAt,
    id,
    commandId,
    commandRevision,
    actionType,
    entityType,
    expectedEntityIdsJson,
    verificationMethod,
    status,
    automaticResumeAllowed,
    automaticRetryProhibited,
    uiDeliveryAcknowledged,
    safeFailureCode,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiAgentBusinessOperationRow &&
          other.ownerScopeId == this.ownerScopeId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.id == this.id &&
          other.commandId == this.commandId &&
          other.commandRevision == this.commandRevision &&
          other.actionType == this.actionType &&
          other.entityType == this.entityType &&
          other.expectedEntityIdsJson == this.expectedEntityIdsJson &&
          other.verificationMethod == this.verificationMethod &&
          other.status == this.status &&
          other.automaticResumeAllowed == this.automaticResumeAllowed &&
          other.automaticRetryProhibited == this.automaticRetryProhibited &&
          other.uiDeliveryAcknowledged == this.uiDeliveryAcknowledged &&
          other.safeFailureCode == this.safeFailureCode &&
          other.completedAt == this.completedAt);
}

class AiAgentBusinessOperationsCompanion
    extends UpdateCompanion<AiAgentBusinessOperationRow> {
  final Value<String> ownerScopeId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> id;
  final Value<String> commandId;
  final Value<int> commandRevision;
  final Value<String> actionType;
  final Value<String> entityType;
  final Value<String> expectedEntityIdsJson;
  final Value<String> verificationMethod;
  final Value<String> status;
  final Value<bool> automaticResumeAllowed;
  final Value<bool> automaticRetryProhibited;
  final Value<bool> uiDeliveryAcknowledged;
  final Value<String?> safeFailureCode;
  final Value<DateTime?> completedAt;
  final Value<int> rowid;
  const AiAgentBusinessOperationsCompanion({
    this.ownerScopeId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.commandId = const Value.absent(),
    this.commandRevision = const Value.absent(),
    this.actionType = const Value.absent(),
    this.entityType = const Value.absent(),
    this.expectedEntityIdsJson = const Value.absent(),
    this.verificationMethod = const Value.absent(),
    this.status = const Value.absent(),
    this.automaticResumeAllowed = const Value.absent(),
    this.automaticRetryProhibited = const Value.absent(),
    this.uiDeliveryAcknowledged = const Value.absent(),
    this.safeFailureCode = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiAgentBusinessOperationsCompanion.insert({
    required String ownerScopeId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String id,
    required String commandId,
    required int commandRevision,
    required String actionType,
    required String entityType,
    required String expectedEntityIdsJson,
    required String verificationMethod,
    required String status,
    required bool automaticResumeAllowed,
    required bool automaticRetryProhibited,
    this.uiDeliveryAcknowledged = const Value.absent(),
    this.safeFailureCode = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ownerScopeId = Value(ownerScopeId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       id = Value(id),
       commandId = Value(commandId),
       commandRevision = Value(commandRevision),
       actionType = Value(actionType),
       entityType = Value(entityType),
       expectedEntityIdsJson = Value(expectedEntityIdsJson),
       verificationMethod = Value(verificationMethod),
       status = Value(status),
       automaticResumeAllowed = Value(automaticResumeAllowed),
       automaticRetryProhibited = Value(automaticRetryProhibited);
  static Insertable<AiAgentBusinessOperationRow> custom({
    Expression<String>? ownerScopeId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? id,
    Expression<String>? commandId,
    Expression<int>? commandRevision,
    Expression<String>? actionType,
    Expression<String>? entityType,
    Expression<String>? expectedEntityIdsJson,
    Expression<String>? verificationMethod,
    Expression<String>? status,
    Expression<bool>? automaticResumeAllowed,
    Expression<bool>? automaticRetryProhibited,
    Expression<bool>? uiDeliveryAcknowledged,
    Expression<String>? safeFailureCode,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerScopeId != null) 'owner_scope_id': ownerScopeId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (id != null) 'id': id,
      if (commandId != null) 'command_id': commandId,
      if (commandRevision != null) 'command_revision': commandRevision,
      if (actionType != null) 'action_type': actionType,
      if (entityType != null) 'entity_type': entityType,
      if (expectedEntityIdsJson != null)
        'expected_entity_ids_json': expectedEntityIdsJson,
      if (verificationMethod != null) 'verification_method': verificationMethod,
      if (status != null) 'status': status,
      if (automaticResumeAllowed != null)
        'automatic_resume_allowed': automaticResumeAllowed,
      if (automaticRetryProhibited != null)
        'automatic_retry_prohibited': automaticRetryProhibited,
      if (uiDeliveryAcknowledged != null)
        'ui_delivery_acknowledged': uiDeliveryAcknowledged,
      if (safeFailureCode != null) 'safe_failure_code': safeFailureCode,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiAgentBusinessOperationsCompanion copyWith({
    Value<String>? ownerScopeId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String>? id,
    Value<String>? commandId,
    Value<int>? commandRevision,
    Value<String>? actionType,
    Value<String>? entityType,
    Value<String>? expectedEntityIdsJson,
    Value<String>? verificationMethod,
    Value<String>? status,
    Value<bool>? automaticResumeAllowed,
    Value<bool>? automaticRetryProhibited,
    Value<bool>? uiDeliveryAcknowledged,
    Value<String?>? safeFailureCode,
    Value<DateTime?>? completedAt,
    Value<int>? rowid,
  }) {
    return AiAgentBusinessOperationsCompanion(
      ownerScopeId: ownerScopeId ?? this.ownerScopeId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      id: id ?? this.id,
      commandId: commandId ?? this.commandId,
      commandRevision: commandRevision ?? this.commandRevision,
      actionType: actionType ?? this.actionType,
      entityType: entityType ?? this.entityType,
      expectedEntityIdsJson:
          expectedEntityIdsJson ?? this.expectedEntityIdsJson,
      verificationMethod: verificationMethod ?? this.verificationMethod,
      status: status ?? this.status,
      automaticResumeAllowed:
          automaticResumeAllowed ?? this.automaticResumeAllowed,
      automaticRetryProhibited:
          automaticRetryProhibited ?? this.automaticRetryProhibited,
      uiDeliveryAcknowledged:
          uiDeliveryAcknowledged ?? this.uiDeliveryAcknowledged,
      safeFailureCode: safeFailureCode ?? this.safeFailureCode,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerScopeId.present) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (commandId.present) {
      map['command_id'] = Variable<String>(commandId.value);
    }
    if (commandRevision.present) {
      map['command_revision'] = Variable<int>(commandRevision.value);
    }
    if (actionType.present) {
      map['action_type'] = Variable<String>(actionType.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (expectedEntityIdsJson.present) {
      map['expected_entity_ids_json'] = Variable<String>(
        expectedEntityIdsJson.value,
      );
    }
    if (verificationMethod.present) {
      map['verification_method'] = Variable<String>(verificationMethod.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (automaticResumeAllowed.present) {
      map['automatic_resume_allowed'] = Variable<bool>(
        automaticResumeAllowed.value,
      );
    }
    if (automaticRetryProhibited.present) {
      map['automatic_retry_prohibited'] = Variable<bool>(
        automaticRetryProhibited.value,
      );
    }
    if (uiDeliveryAcknowledged.present) {
      map['ui_delivery_acknowledged'] = Variable<bool>(
        uiDeliveryAcknowledged.value,
      );
    }
    if (safeFailureCode.present) {
      map['safe_failure_code'] = Variable<String>(safeFailureCode.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiAgentBusinessOperationsCompanion(')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('id: $id, ')
          ..write('commandId: $commandId, ')
          ..write('commandRevision: $commandRevision, ')
          ..write('actionType: $actionType, ')
          ..write('entityType: $entityType, ')
          ..write('expectedEntityIdsJson: $expectedEntityIdsJson, ')
          ..write('verificationMethod: $verificationMethod, ')
          ..write('status: $status, ')
          ..write('automaticResumeAllowed: $automaticResumeAllowed, ')
          ..write('automaticRetryProhibited: $automaticRetryProhibited, ')
          ..write('uiDeliveryAcknowledged: $uiDeliveryAcknowledged, ')
          ..write('safeFailureCode: $safeFailureCode, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $PayeesTable payees = $PayeesTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $ExchangeRatesTable exchangeRates = $ExchangeRatesTable(this);
  late final $BudgetsTable budgets = $BudgetsTable(this);
  late final $GoalsTable goals = $GoalsTable(this);
  late final $GoalContributionsTable goalContributions =
      $GoalContributionsTable(this);
  late final $SyncQueueTable syncQueue = $SyncQueueTable(this);
  late final $ReceiptsTable receipts = $ReceiptsTable(this);
  late final $ReceiptLineItemsTable receiptLineItems = $ReceiptLineItemsTable(
    this,
  );
  late final $TransactionSplitsTable transactionSplits =
      $TransactionSplitsTable(this);
  late final $OwnerScopeMigrationAuditsTable ownerScopeMigrationAudits =
      $OwnerScopeMigrationAuditsTable(this);
  late final $AiAgentCommandsTable aiAgentCommands = $AiAgentCommandsTable(
    this,
  );
  late final $AiAgentPreviewsTable aiAgentPreviews = $AiAgentPreviewsTable(
    this,
  );
  late final $AiAgentConfirmationProofsTable aiAgentConfirmationProofs =
      $AiAgentConfirmationProofsTable(this);
  late final $AiAgentExecutionAttemptsTable aiAgentExecutionAttempts =
      $AiAgentExecutionAttemptsTable(this);
  late final $AiAgentExecutionResultsTable aiAgentExecutionResults =
      $AiAgentExecutionResultsTable(this);
  late final $AiAgentPlansTable aiAgentPlans = $AiAgentPlansTable(this);
  late final $AiAgentPlanStepsTable aiAgentPlanSteps = $AiAgentPlanStepsTable(
    this,
  );
  late final $AiAgentAuditEventsTable aiAgentAuditEvents =
      $AiAgentAuditEventsTable(this);
  late final $AiAgentIdempotencyRecordsTable aiAgentIdempotencyRecords =
      $AiAgentIdempotencyRecordsTable(this);
  late final $AiAgentBusinessOperationsTable aiAgentBusinessOperations =
      $AiAgentBusinessOperationsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    accounts,
    categories,
    payees,
    transactions,
    exchangeRates,
    budgets,
    goals,
    goalContributions,
    syncQueue,
    receipts,
    receiptLineItems,
    transactionSplits,
    ownerScopeMigrationAudits,
    aiAgentCommands,
    aiAgentPreviews,
    aiAgentConfirmationProofs,
    aiAgentExecutionAttempts,
    aiAgentExecutionResults,
    aiAgentPlans,
    aiAgentPlanSteps,
    aiAgentAuditEvents,
    aiAgentIdempotencyRecords,
    aiAgentBusinessOperations,
  ];
}

typedef $$AccountsTableCreateCompanionBuilder =
    AccountsCompanion Function({
      required String id,
      Value<String?> ownerScopeId,
      required String name,
      required String type,
      required String currencyCode,
      required String balance,
      required String icon,
      required int color,
      Value<String> paymentMethodIds,
      Value<bool> isArchived,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$AccountsTableUpdateCompanionBuilder =
    AccountsCompanion Function({
      Value<String> id,
      Value<String?> ownerScopeId,
      Value<String> name,
      Value<String> type,
      Value<String> currencyCode,
      Value<String> balance,
      Value<String> icon,
      Value<int> color,
      Value<String> paymentMethodIds,
      Value<bool> isArchived,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AccountsTableFilterComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
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

  ColumnFilters<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
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

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get balance => $composableBuilder(
    column: $table.balance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentMethodIds => $composableBuilder(
    column: $table.paymentMethodIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
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

  ColumnOrderings<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
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

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get balance => $composableBuilder(
    column: $table.balance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentMethodIds => $composableBuilder(
    column: $table.paymentMethodIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get balance =>
      $composableBuilder(column: $table.balance, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get paymentMethodIds => $composableBuilder(
    column: $table.paymentMethodIds,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccountsTable,
          AccountRow,
          $$AccountsTableFilterComposer,
          $$AccountsTableOrderingComposer,
          $$AccountsTableAnnotationComposer,
          $$AccountsTableCreateCompanionBuilder,
          $$AccountsTableUpdateCompanionBuilder,
          (
            AccountRow,
            BaseReferences<_$AppDatabase, $AccountsTable, AccountRow>,
          ),
          AccountRow,
          PrefetchHooks Function()
        > {
  $$AccountsTableTableManager(_$AppDatabase db, $AccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> ownerScopeId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<String> balance = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<String> paymentMethodIds = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion(
                id: id,
                ownerScopeId: ownerScopeId,
                name: name,
                type: type,
                currencyCode: currencyCode,
                balance: balance,
                icon: icon,
                color: color,
                paymentMethodIds: paymentMethodIds,
                isArchived: isArchived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> ownerScopeId = const Value.absent(),
                required String name,
                required String type,
                required String currencyCode,
                required String balance,
                required String icon,
                required int color,
                Value<String> paymentMethodIds = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion.insert(
                id: id,
                ownerScopeId: ownerScopeId,
                name: name,
                type: type,
                currencyCode: currencyCode,
                balance: balance,
                icon: icon,
                color: color,
                paymentMethodIds: paymentMethodIds,
                isArchived: isArchived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccountsTable,
      AccountRow,
      $$AccountsTableFilterComposer,
      $$AccountsTableOrderingComposer,
      $$AccountsTableAnnotationComposer,
      $$AccountsTableCreateCompanionBuilder,
      $$AccountsTableUpdateCompanionBuilder,
      (AccountRow, BaseReferences<_$AppDatabase, $AccountsTable, AccountRow>),
      AccountRow,
      PrefetchHooks Function()
    >;
typedef $$CategoriesTableCreateCompanionBuilder =
    CategoriesCompanion Function({
      required String id,
      Value<String?> ownerScopeId,
      required String name,
      required String type,
      required String icon,
      required int color,
      Value<String?> parentCategoryId,
      Value<bool> isDefault,
      Value<bool> isArchived,
      required int sortOrder,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CategoriesTableUpdateCompanionBuilder =
    CategoriesCompanion Function({
      Value<String> id,
      Value<String?> ownerScopeId,
      Value<String> name,
      Value<String> type,
      Value<String> icon,
      Value<int> color,
      Value<String?> parentCategoryId,
      Value<bool> isDefault,
      Value<bool> isArchived,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
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

  ColumnFilters<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
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

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentCategoryId => $composableBuilder(
    column: $table.parentCategoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
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

  ColumnOrderings<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
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

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentCategoryId => $composableBuilder(
    column: $table.parentCategoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get parentCategoryId => $composableBuilder(
    column: $table.parentCategoryId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          CategoryRow,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (
            CategoryRow,
            BaseReferences<_$AppDatabase, $CategoriesTable, CategoryRow>,
          ),
          CategoryRow,
          PrefetchHooks Function()
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> ownerScopeId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<String?> parentCategoryId = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                ownerScopeId: ownerScopeId,
                name: name,
                type: type,
                icon: icon,
                color: color,
                parentCategoryId: parentCategoryId,
                isDefault: isDefault,
                isArchived: isArchived,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> ownerScopeId = const Value.absent(),
                required String name,
                required String type,
                required String icon,
                required int color,
                Value<String?> parentCategoryId = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                required int sortOrder,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                ownerScopeId: ownerScopeId,
                name: name,
                type: type,
                icon: icon,
                color: color,
                parentCategoryId: parentCategoryId,
                isDefault: isDefault,
                isArchived: isArchived,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      CategoryRow,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (
        CategoryRow,
        BaseReferences<_$AppDatabase, $CategoriesTable, CategoryRow>,
      ),
      CategoryRow,
      PrefetchHooks Function()
    >;
typedef $$PayeesTableCreateCompanionBuilder =
    PayeesCompanion Function({
      required String id,
      Value<String?> ownerScopeId,
      required String name,
      required String normalizedName,
      Value<String> type,
      Value<String> aliases,
      Value<String?> defaultCategoryId,
      Value<String?> defaultAccountId,
      Value<String?> notes,
      Value<DateTime?> lastUsedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> archivedAt,
      Value<int> rowid,
    });
typedef $$PayeesTableUpdateCompanionBuilder =
    PayeesCompanion Function({
      Value<String> id,
      Value<String?> ownerScopeId,
      Value<String> name,
      Value<String> normalizedName,
      Value<String> type,
      Value<String> aliases,
      Value<String?> defaultCategoryId,
      Value<String?> defaultAccountId,
      Value<String?> notes,
      Value<DateTime?> lastUsedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> archivedAt,
      Value<int> rowid,
    });

class $$PayeesTableFilterComposer
    extends Composer<_$AppDatabase, $PayeesTable> {
  $$PayeesTableFilterComposer({
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

  ColumnFilters<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aliases => $composableBuilder(
    column: $table.aliases,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultCategoryId => $composableBuilder(
    column: $table.defaultCategoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultAccountId => $composableBuilder(
    column: $table.defaultAccountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PayeesTableOrderingComposer
    extends Composer<_$AppDatabase, $PayeesTable> {
  $$PayeesTableOrderingComposer({
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

  ColumnOrderings<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aliases => $composableBuilder(
    column: $table.aliases,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultCategoryId => $composableBuilder(
    column: $table.defaultCategoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultAccountId => $composableBuilder(
    column: $table.defaultAccountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PayeesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PayeesTable> {
  $$PayeesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get aliases =>
      $composableBuilder(column: $table.aliases, builder: (column) => column);

  GeneratedColumn<String> get defaultCategoryId => $composableBuilder(
    column: $table.defaultCategoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get defaultAccountId => $composableBuilder(
    column: $table.defaultAccountId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );
}

class $$PayeesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PayeesTable,
          PayeeRow,
          $$PayeesTableFilterComposer,
          $$PayeesTableOrderingComposer,
          $$PayeesTableAnnotationComposer,
          $$PayeesTableCreateCompanionBuilder,
          $$PayeesTableUpdateCompanionBuilder,
          (PayeeRow, BaseReferences<_$AppDatabase, $PayeesTable, PayeeRow>),
          PayeeRow,
          PrefetchHooks Function()
        > {
  $$PayeesTableTableManager(_$AppDatabase db, $PayeesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PayeesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PayeesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PayeesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> ownerScopeId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> normalizedName = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> aliases = const Value.absent(),
                Value<String?> defaultCategoryId = const Value.absent(),
                Value<String?> defaultAccountId = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> lastUsedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PayeesCompanion(
                id: id,
                ownerScopeId: ownerScopeId,
                name: name,
                normalizedName: normalizedName,
                type: type,
                aliases: aliases,
                defaultCategoryId: defaultCategoryId,
                defaultAccountId: defaultAccountId,
                notes: notes,
                lastUsedAt: lastUsedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                archivedAt: archivedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> ownerScopeId = const Value.absent(),
                required String name,
                required String normalizedName,
                Value<String> type = const Value.absent(),
                Value<String> aliases = const Value.absent(),
                Value<String?> defaultCategoryId = const Value.absent(),
                Value<String?> defaultAccountId = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> lastUsedAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PayeesCompanion.insert(
                id: id,
                ownerScopeId: ownerScopeId,
                name: name,
                normalizedName: normalizedName,
                type: type,
                aliases: aliases,
                defaultCategoryId: defaultCategoryId,
                defaultAccountId: defaultAccountId,
                notes: notes,
                lastUsedAt: lastUsedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                archivedAt: archivedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PayeesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PayeesTable,
      PayeeRow,
      $$PayeesTableFilterComposer,
      $$PayeesTableOrderingComposer,
      $$PayeesTableAnnotationComposer,
      $$PayeesTableCreateCompanionBuilder,
      $$PayeesTableUpdateCompanionBuilder,
      (PayeeRow, BaseReferences<_$AppDatabase, $PayeesTable, PayeeRow>),
      PayeeRow,
      PrefetchHooks Function()
    >;
typedef $$TransactionsTableCreateCompanionBuilder =
    TransactionsCompanion Function({
      required String id,
      Value<String?> ownerScopeId,
      required String accountId,
      required String categoryId,
      Value<String?> payeeId,
      required String amount,
      required String currencyCode,
      required String type,
      required String paymentMethod,
      required String source,
      required String status,
      Value<String?> incomeSourceType,
      Value<String?> transferGroupId,
      Value<String?> transferPayloadFingerprint,
      Value<String?> exchangeRateFromCurrencyCode,
      Value<String?> exchangeRateToCurrencyCode,
      Value<String?> exchangeRate,
      Value<DateTime?> exchangeRateAsOf,
      Value<String?> note,
      required DateTime transactionDate,
      Value<String?> location,
      Value<int> attachmentCount,
      Value<int?> aiConfidence,
      Value<bool> needsReview,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$TransactionsTableUpdateCompanionBuilder =
    TransactionsCompanion Function({
      Value<String> id,
      Value<String?> ownerScopeId,
      Value<String> accountId,
      Value<String> categoryId,
      Value<String?> payeeId,
      Value<String> amount,
      Value<String> currencyCode,
      Value<String> type,
      Value<String> paymentMethod,
      Value<String> source,
      Value<String> status,
      Value<String?> incomeSourceType,
      Value<String?> transferGroupId,
      Value<String?> transferPayloadFingerprint,
      Value<String?> exchangeRateFromCurrencyCode,
      Value<String?> exchangeRateToCurrencyCode,
      Value<String?> exchangeRate,
      Value<DateTime?> exchangeRateAsOf,
      Value<String?> note,
      Value<DateTime> transactionDate,
      Value<String?> location,
      Value<int> attachmentCount,
      Value<int?> aiConfidence,
      Value<bool> needsReview,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$TransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
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

  ColumnFilters<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payeeId => $composableBuilder(
    column: $table.payeeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get incomeSourceType => $composableBuilder(
    column: $table.incomeSourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transferGroupId => $composableBuilder(
    column: $table.transferGroupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transferPayloadFingerprint => $composableBuilder(
    column: $table.transferPayloadFingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exchangeRateFromCurrencyCode => $composableBuilder(
    column: $table.exchangeRateFromCurrencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exchangeRateToCurrencyCode => $composableBuilder(
    column: $table.exchangeRateToCurrencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exchangeRate => $composableBuilder(
    column: $table.exchangeRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get exchangeRateAsOf => $composableBuilder(
    column: $table.exchangeRateAsOf,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get transactionDate => $composableBuilder(
    column: $table.transactionDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attachmentCount => $composableBuilder(
    column: $table.attachmentCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get aiConfidence => $composableBuilder(
    column: $table.aiConfidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get needsReview => $composableBuilder(
    column: $table.needsReview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
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

  ColumnOrderings<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payeeId => $composableBuilder(
    column: $table.payeeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get incomeSourceType => $composableBuilder(
    column: $table.incomeSourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transferGroupId => $composableBuilder(
    column: $table.transferGroupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transferPayloadFingerprint => $composableBuilder(
    column: $table.transferPayloadFingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exchangeRateFromCurrencyCode =>
      $composableBuilder(
        column: $table.exchangeRateFromCurrencyCode,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<String> get exchangeRateToCurrencyCode => $composableBuilder(
    column: $table.exchangeRateToCurrencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exchangeRate => $composableBuilder(
    column: $table.exchangeRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get exchangeRateAsOf => $composableBuilder(
    column: $table.exchangeRateAsOf,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get transactionDate => $composableBuilder(
    column: $table.transactionDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attachmentCount => $composableBuilder(
    column: $table.attachmentCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get aiConfidence => $composableBuilder(
    column: $table.aiConfidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get needsReview => $composableBuilder(
    column: $table.needsReview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payeeId =>
      $composableBuilder(column: $table.payeeId, builder: (column) => column);

  GeneratedColumn<String> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get incomeSourceType => $composableBuilder(
    column: $table.incomeSourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transferGroupId => $composableBuilder(
    column: $table.transferGroupId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transferPayloadFingerprint => $composableBuilder(
    column: $table.transferPayloadFingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get exchangeRateFromCurrencyCode =>
      $composableBuilder(
        column: $table.exchangeRateFromCurrencyCode,
        builder: (column) => column,
      );

  GeneratedColumn<String> get exchangeRateToCurrencyCode => $composableBuilder(
    column: $table.exchangeRateToCurrencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get exchangeRate => $composableBuilder(
    column: $table.exchangeRate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get exchangeRateAsOf => $composableBuilder(
    column: $table.exchangeRateAsOf,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get transactionDate => $composableBuilder(
    column: $table.transactionDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<int> get attachmentCount => $composableBuilder(
    column: $table.attachmentCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get aiConfidence => $composableBuilder(
    column: $table.aiConfidence,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get needsReview => $composableBuilder(
    column: $table.needsReview,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionsTable,
          TransactionRow,
          $$TransactionsTableFilterComposer,
          $$TransactionsTableOrderingComposer,
          $$TransactionsTableAnnotationComposer,
          $$TransactionsTableCreateCompanionBuilder,
          $$TransactionsTableUpdateCompanionBuilder,
          (
            TransactionRow,
            BaseReferences<_$AppDatabase, $TransactionsTable, TransactionRow>,
          ),
          TransactionRow,
          PrefetchHooks Function()
        > {
  $$TransactionsTableTableManager(_$AppDatabase db, $TransactionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> ownerScopeId = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<String?> payeeId = const Value.absent(),
                Value<String> amount = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> paymentMethod = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> incomeSourceType = const Value.absent(),
                Value<String?> transferGroupId = const Value.absent(),
                Value<String?> transferPayloadFingerprint =
                    const Value.absent(),
                Value<String?> exchangeRateFromCurrencyCode =
                    const Value.absent(),
                Value<String?> exchangeRateToCurrencyCode =
                    const Value.absent(),
                Value<String?> exchangeRate = const Value.absent(),
                Value<DateTime?> exchangeRateAsOf = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> transactionDate = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<int> attachmentCount = const Value.absent(),
                Value<int?> aiConfidence = const Value.absent(),
                Value<bool> needsReview = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion(
                id: id,
                ownerScopeId: ownerScopeId,
                accountId: accountId,
                categoryId: categoryId,
                payeeId: payeeId,
                amount: amount,
                currencyCode: currencyCode,
                type: type,
                paymentMethod: paymentMethod,
                source: source,
                status: status,
                incomeSourceType: incomeSourceType,
                transferGroupId: transferGroupId,
                transferPayloadFingerprint: transferPayloadFingerprint,
                exchangeRateFromCurrencyCode: exchangeRateFromCurrencyCode,
                exchangeRateToCurrencyCode: exchangeRateToCurrencyCode,
                exchangeRate: exchangeRate,
                exchangeRateAsOf: exchangeRateAsOf,
                note: note,
                transactionDate: transactionDate,
                location: location,
                attachmentCount: attachmentCount,
                aiConfidence: aiConfidence,
                needsReview: needsReview,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> ownerScopeId = const Value.absent(),
                required String accountId,
                required String categoryId,
                Value<String?> payeeId = const Value.absent(),
                required String amount,
                required String currencyCode,
                required String type,
                required String paymentMethod,
                required String source,
                required String status,
                Value<String?> incomeSourceType = const Value.absent(),
                Value<String?> transferGroupId = const Value.absent(),
                Value<String?> transferPayloadFingerprint =
                    const Value.absent(),
                Value<String?> exchangeRateFromCurrencyCode =
                    const Value.absent(),
                Value<String?> exchangeRateToCurrencyCode =
                    const Value.absent(),
                Value<String?> exchangeRate = const Value.absent(),
                Value<DateTime?> exchangeRateAsOf = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required DateTime transactionDate,
                Value<String?> location = const Value.absent(),
                Value<int> attachmentCount = const Value.absent(),
                Value<int?> aiConfidence = const Value.absent(),
                Value<bool> needsReview = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion.insert(
                id: id,
                ownerScopeId: ownerScopeId,
                accountId: accountId,
                categoryId: categoryId,
                payeeId: payeeId,
                amount: amount,
                currencyCode: currencyCode,
                type: type,
                paymentMethod: paymentMethod,
                source: source,
                status: status,
                incomeSourceType: incomeSourceType,
                transferGroupId: transferGroupId,
                transferPayloadFingerprint: transferPayloadFingerprint,
                exchangeRateFromCurrencyCode: exchangeRateFromCurrencyCode,
                exchangeRateToCurrencyCode: exchangeRateToCurrencyCode,
                exchangeRate: exchangeRate,
                exchangeRateAsOf: exchangeRateAsOf,
                note: note,
                transactionDate: transactionDate,
                location: location,
                attachmentCount: attachmentCount,
                aiConfidence: aiConfidence,
                needsReview: needsReview,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionsTable,
      TransactionRow,
      $$TransactionsTableFilterComposer,
      $$TransactionsTableOrderingComposer,
      $$TransactionsTableAnnotationComposer,
      $$TransactionsTableCreateCompanionBuilder,
      $$TransactionsTableUpdateCompanionBuilder,
      (
        TransactionRow,
        BaseReferences<_$AppDatabase, $TransactionsTable, TransactionRow>,
      ),
      TransactionRow,
      PrefetchHooks Function()
    >;
typedef $$ExchangeRatesTableCreateCompanionBuilder =
    ExchangeRatesCompanion Function({
      required String id,
      Value<String?> ownerScopeId,
      required String baseCurrency,
      required String quoteCurrency,
      required String rate,
      required String source,
      required DateTime fetchedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> archivedAt,
      Value<int> rowid,
    });
typedef $$ExchangeRatesTableUpdateCompanionBuilder =
    ExchangeRatesCompanion Function({
      Value<String> id,
      Value<String?> ownerScopeId,
      Value<String> baseCurrency,
      Value<String> quoteCurrency,
      Value<String> rate,
      Value<String> source,
      Value<DateTime> fetchedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> archivedAt,
      Value<int> rowid,
    });

class $$ExchangeRatesTableFilterComposer
    extends Composer<_$AppDatabase, $ExchangeRatesTable> {
  $$ExchangeRatesTableFilterComposer({
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

  ColumnFilters<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseCurrency => $composableBuilder(
    column: $table.baseCurrency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quoteCurrency => $composableBuilder(
    column: $table.quoteCurrency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rate => $composableBuilder(
    column: $table.rate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExchangeRatesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExchangeRatesTable> {
  $$ExchangeRatesTableOrderingComposer({
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

  ColumnOrderings<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseCurrency => $composableBuilder(
    column: $table.baseCurrency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quoteCurrency => $composableBuilder(
    column: $table.quoteCurrency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rate => $composableBuilder(
    column: $table.rate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExchangeRatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExchangeRatesTable> {
  $$ExchangeRatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get baseCurrency => $composableBuilder(
    column: $table.baseCurrency,
    builder: (column) => column,
  );

  GeneratedColumn<String> get quoteCurrency => $composableBuilder(
    column: $table.quoteCurrency,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rate =>
      $composableBuilder(column: $table.rate, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );
}

class $$ExchangeRatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExchangeRatesTable,
          ExchangeRateRow,
          $$ExchangeRatesTableFilterComposer,
          $$ExchangeRatesTableOrderingComposer,
          $$ExchangeRatesTableAnnotationComposer,
          $$ExchangeRatesTableCreateCompanionBuilder,
          $$ExchangeRatesTableUpdateCompanionBuilder,
          (
            ExchangeRateRow,
            BaseReferences<_$AppDatabase, $ExchangeRatesTable, ExchangeRateRow>,
          ),
          ExchangeRateRow,
          PrefetchHooks Function()
        > {
  $$ExchangeRatesTableTableManager(_$AppDatabase db, $ExchangeRatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExchangeRatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExchangeRatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExchangeRatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> ownerScopeId = const Value.absent(),
                Value<String> baseCurrency = const Value.absent(),
                Value<String> quoteCurrency = const Value.absent(),
                Value<String> rate = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExchangeRatesCompanion(
                id: id,
                ownerScopeId: ownerScopeId,
                baseCurrency: baseCurrency,
                quoteCurrency: quoteCurrency,
                rate: rate,
                source: source,
                fetchedAt: fetchedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                archivedAt: archivedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> ownerScopeId = const Value.absent(),
                required String baseCurrency,
                required String quoteCurrency,
                required String rate,
                required String source,
                required DateTime fetchedAt,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExchangeRatesCompanion.insert(
                id: id,
                ownerScopeId: ownerScopeId,
                baseCurrency: baseCurrency,
                quoteCurrency: quoteCurrency,
                rate: rate,
                source: source,
                fetchedAt: fetchedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                archivedAt: archivedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExchangeRatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExchangeRatesTable,
      ExchangeRateRow,
      $$ExchangeRatesTableFilterComposer,
      $$ExchangeRatesTableOrderingComposer,
      $$ExchangeRatesTableAnnotationComposer,
      $$ExchangeRatesTableCreateCompanionBuilder,
      $$ExchangeRatesTableUpdateCompanionBuilder,
      (
        ExchangeRateRow,
        BaseReferences<_$AppDatabase, $ExchangeRatesTable, ExchangeRateRow>,
      ),
      ExchangeRateRow,
      PrefetchHooks Function()
    >;
typedef $$BudgetsTableCreateCompanionBuilder =
    BudgetsCompanion Function({
      required String id,
      Value<String?> ownerScopeId,
      required String name,
      required String categoryId,
      required String amount,
      required String currency,
      required String periodType,
      required DateTime startDate,
      required DateTime endDate,
      required int alertThresholdPercent,
      Value<bool> isActive,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> archivedAt,
      Value<int> rowid,
    });
typedef $$BudgetsTableUpdateCompanionBuilder =
    BudgetsCompanion Function({
      Value<String> id,
      Value<String?> ownerScopeId,
      Value<String> name,
      Value<String> categoryId,
      Value<String> amount,
      Value<String> currency,
      Value<String> periodType,
      Value<DateTime> startDate,
      Value<DateTime> endDate,
      Value<int> alertThresholdPercent,
      Value<bool> isActive,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> archivedAt,
      Value<int> rowid,
    });

class $$BudgetsTableFilterComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableFilterComposer({
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

  ColumnFilters<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get periodType => $composableBuilder(
    column: $table.periodType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get alertThresholdPercent => $composableBuilder(
    column: $table.alertThresholdPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BudgetsTableOrderingComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableOrderingComposer({
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

  ColumnOrderings<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get periodType => $composableBuilder(
    column: $table.periodType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get alertThresholdPercent => $composableBuilder(
    column: $table.alertThresholdPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BudgetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get periodType => $composableBuilder(
    column: $table.periodType,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<int> get alertThresholdPercent => $composableBuilder(
    column: $table.alertThresholdPercent,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );
}

class $$BudgetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BudgetsTable,
          BudgetRow,
          $$BudgetsTableFilterComposer,
          $$BudgetsTableOrderingComposer,
          $$BudgetsTableAnnotationComposer,
          $$BudgetsTableCreateCompanionBuilder,
          $$BudgetsTableUpdateCompanionBuilder,
          (BudgetRow, BaseReferences<_$AppDatabase, $BudgetsTable, BudgetRow>),
          BudgetRow,
          PrefetchHooks Function()
        > {
  $$BudgetsTableTableManager(_$AppDatabase db, $BudgetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BudgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BudgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BudgetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> ownerScopeId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<String> amount = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> periodType = const Value.absent(),
                Value<DateTime> startDate = const Value.absent(),
                Value<DateTime> endDate = const Value.absent(),
                Value<int> alertThresholdPercent = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BudgetsCompanion(
                id: id,
                ownerScopeId: ownerScopeId,
                name: name,
                categoryId: categoryId,
                amount: amount,
                currency: currency,
                periodType: periodType,
                startDate: startDate,
                endDate: endDate,
                alertThresholdPercent: alertThresholdPercent,
                isActive: isActive,
                createdAt: createdAt,
                updatedAt: updatedAt,
                archivedAt: archivedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> ownerScopeId = const Value.absent(),
                required String name,
                required String categoryId,
                required String amount,
                required String currency,
                required String periodType,
                required DateTime startDate,
                required DateTime endDate,
                required int alertThresholdPercent,
                Value<bool> isActive = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BudgetsCompanion.insert(
                id: id,
                ownerScopeId: ownerScopeId,
                name: name,
                categoryId: categoryId,
                amount: amount,
                currency: currency,
                periodType: periodType,
                startDate: startDate,
                endDate: endDate,
                alertThresholdPercent: alertThresholdPercent,
                isActive: isActive,
                createdAt: createdAt,
                updatedAt: updatedAt,
                archivedAt: archivedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BudgetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BudgetsTable,
      BudgetRow,
      $$BudgetsTableFilterComposer,
      $$BudgetsTableOrderingComposer,
      $$BudgetsTableAnnotationComposer,
      $$BudgetsTableCreateCompanionBuilder,
      $$BudgetsTableUpdateCompanionBuilder,
      (BudgetRow, BaseReferences<_$AppDatabase, $BudgetsTable, BudgetRow>),
      BudgetRow,
      PrefetchHooks Function()
    >;
typedef $$GoalsTableCreateCompanionBuilder =
    GoalsCompanion Function({
      required String id,
      Value<String?> ownerScopeId,
      required String title,
      Value<String> description,
      required String type,
      required String targetAmount,
      required String currentAmount,
      required String currency,
      Value<String?> linkedAccountId,
      Value<DateTime?> targetDate,
      required String icon,
      required int color,
      required String status,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> archivedAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });
typedef $$GoalsTableUpdateCompanionBuilder =
    GoalsCompanion Function({
      Value<String> id,
      Value<String?> ownerScopeId,
      Value<String> title,
      Value<String> description,
      Value<String> type,
      Value<String> targetAmount,
      Value<String> currentAmount,
      Value<String> currency,
      Value<String?> linkedAccountId,
      Value<DateTime?> targetDate,
      Value<String> icon,
      Value<int> color,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> archivedAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });

class $$GoalsTableFilterComposer extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableFilterComposer({
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

  ColumnFilters<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetAmount => $composableBuilder(
    column: $table.targetAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentAmount => $composableBuilder(
    column: $table.currentAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkedAccountId => $composableBuilder(
    column: $table.linkedAccountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GoalsTableOrderingComposer
    extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableOrderingComposer({
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

  ColumnOrderings<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetAmount => $composableBuilder(
    column: $table.targetAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentAmount => $composableBuilder(
    column: $table.currentAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkedAccountId => $composableBuilder(
    column: $table.linkedAccountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GoalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get targetAmount => $composableBuilder(
    column: $table.targetAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currentAmount => $composableBuilder(
    column: $table.currentAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get linkedAccountId => $composableBuilder(
    column: $table.linkedAccountId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$GoalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GoalsTable,
          GoalRow,
          $$GoalsTableFilterComposer,
          $$GoalsTableOrderingComposer,
          $$GoalsTableAnnotationComposer,
          $$GoalsTableCreateCompanionBuilder,
          $$GoalsTableUpdateCompanionBuilder,
          (GoalRow, BaseReferences<_$AppDatabase, $GoalsTable, GoalRow>),
          GoalRow,
          PrefetchHooks Function()
        > {
  $$GoalsTableTableManager(_$AppDatabase db, $GoalsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GoalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GoalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GoalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> ownerScopeId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> targetAmount = const Value.absent(),
                Value<String> currentAmount = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String?> linkedAccountId = const Value.absent(),
                Value<DateTime?> targetDate = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GoalsCompanion(
                id: id,
                ownerScopeId: ownerScopeId,
                title: title,
                description: description,
                type: type,
                targetAmount: targetAmount,
                currentAmount: currentAmount,
                currency: currency,
                linkedAccountId: linkedAccountId,
                targetDate: targetDate,
                icon: icon,
                color: color,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                archivedAt: archivedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> ownerScopeId = const Value.absent(),
                required String title,
                Value<String> description = const Value.absent(),
                required String type,
                required String targetAmount,
                required String currentAmount,
                required String currency,
                Value<String?> linkedAccountId = const Value.absent(),
                Value<DateTime?> targetDate = const Value.absent(),
                required String icon,
                required int color,
                required String status,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GoalsCompanion.insert(
                id: id,
                ownerScopeId: ownerScopeId,
                title: title,
                description: description,
                type: type,
                targetAmount: targetAmount,
                currentAmount: currentAmount,
                currency: currency,
                linkedAccountId: linkedAccountId,
                targetDate: targetDate,
                icon: icon,
                color: color,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                archivedAt: archivedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GoalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GoalsTable,
      GoalRow,
      $$GoalsTableFilterComposer,
      $$GoalsTableOrderingComposer,
      $$GoalsTableAnnotationComposer,
      $$GoalsTableCreateCompanionBuilder,
      $$GoalsTableUpdateCompanionBuilder,
      (GoalRow, BaseReferences<_$AppDatabase, $GoalsTable, GoalRow>),
      GoalRow,
      PrefetchHooks Function()
    >;
typedef $$GoalContributionsTableCreateCompanionBuilder =
    GoalContributionsCompanion Function({
      required String id,
      Value<String?> ownerScopeId,
      required String goalId,
      required String amount,
      required String currency,
      required String creditedAmount,
      required DateTime date,
      Value<String> note,
      Value<String?> linkedTransactionId,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> reversedAt,
      Value<int> rowid,
    });
typedef $$GoalContributionsTableUpdateCompanionBuilder =
    GoalContributionsCompanion Function({
      Value<String> id,
      Value<String?> ownerScopeId,
      Value<String> goalId,
      Value<String> amount,
      Value<String> currency,
      Value<String> creditedAmount,
      Value<DateTime> date,
      Value<String> note,
      Value<String?> linkedTransactionId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> reversedAt,
      Value<int> rowid,
    });

class $$GoalContributionsTableFilterComposer
    extends Composer<_$AppDatabase, $GoalContributionsTable> {
  $$GoalContributionsTableFilterComposer({
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

  ColumnFilters<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get goalId => $composableBuilder(
    column: $table.goalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get creditedAmount => $composableBuilder(
    column: $table.creditedAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkedTransactionId => $composableBuilder(
    column: $table.linkedTransactionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get reversedAt => $composableBuilder(
    column: $table.reversedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GoalContributionsTableOrderingComposer
    extends Composer<_$AppDatabase, $GoalContributionsTable> {
  $$GoalContributionsTableOrderingComposer({
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

  ColumnOrderings<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get goalId => $composableBuilder(
    column: $table.goalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get creditedAmount => $composableBuilder(
    column: $table.creditedAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkedTransactionId => $composableBuilder(
    column: $table.linkedTransactionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get reversedAt => $composableBuilder(
    column: $table.reversedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GoalContributionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GoalContributionsTable> {
  $$GoalContributionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get goalId =>
      $composableBuilder(column: $table.goalId, builder: (column) => column);

  GeneratedColumn<String> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get creditedAmount => $composableBuilder(
    column: $table.creditedAmount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get linkedTransactionId => $composableBuilder(
    column: $table.linkedTransactionId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get reversedAt => $composableBuilder(
    column: $table.reversedAt,
    builder: (column) => column,
  );
}

class $$GoalContributionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GoalContributionsTable,
          GoalContributionRow,
          $$GoalContributionsTableFilterComposer,
          $$GoalContributionsTableOrderingComposer,
          $$GoalContributionsTableAnnotationComposer,
          $$GoalContributionsTableCreateCompanionBuilder,
          $$GoalContributionsTableUpdateCompanionBuilder,
          (
            GoalContributionRow,
            BaseReferences<
              _$AppDatabase,
              $GoalContributionsTable,
              GoalContributionRow
            >,
          ),
          GoalContributionRow,
          PrefetchHooks Function()
        > {
  $$GoalContributionsTableTableManager(
    _$AppDatabase db,
    $GoalContributionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GoalContributionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GoalContributionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GoalContributionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> ownerScopeId = const Value.absent(),
                Value<String> goalId = const Value.absent(),
                Value<String> amount = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> creditedAmount = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String?> linkedTransactionId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> reversedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GoalContributionsCompanion(
                id: id,
                ownerScopeId: ownerScopeId,
                goalId: goalId,
                amount: amount,
                currency: currency,
                creditedAmount: creditedAmount,
                date: date,
                note: note,
                linkedTransactionId: linkedTransactionId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                reversedAt: reversedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> ownerScopeId = const Value.absent(),
                required String goalId,
                required String amount,
                required String currency,
                required String creditedAmount,
                required DateTime date,
                Value<String> note = const Value.absent(),
                Value<String?> linkedTransactionId = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> reversedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GoalContributionsCompanion.insert(
                id: id,
                ownerScopeId: ownerScopeId,
                goalId: goalId,
                amount: amount,
                currency: currency,
                creditedAmount: creditedAmount,
                date: date,
                note: note,
                linkedTransactionId: linkedTransactionId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                reversedAt: reversedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GoalContributionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GoalContributionsTable,
      GoalContributionRow,
      $$GoalContributionsTableFilterComposer,
      $$GoalContributionsTableOrderingComposer,
      $$GoalContributionsTableAnnotationComposer,
      $$GoalContributionsTableCreateCompanionBuilder,
      $$GoalContributionsTableUpdateCompanionBuilder,
      (
        GoalContributionRow,
        BaseReferences<
          _$AppDatabase,
          $GoalContributionsTable,
          GoalContributionRow
        >,
      ),
      GoalContributionRow,
      PrefetchHooks Function()
    >;
typedef $$SyncQueueTableCreateCompanionBuilder =
    SyncQueueCompanion Function({
      required String id,
      Value<String?> ownerScopeId,
      required String ownerUserId,
      required String entityType,
      required String entityId,
      required String operation,
      required String payloadJson,
      Value<String> status,
      Value<int> attemptCount,
      Value<String?> lastError,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> lastAttemptAt,
      Value<int> rowid,
    });
typedef $$SyncQueueTableUpdateCompanionBuilder =
    SyncQueueCompanion Function({
      Value<String> id,
      Value<String?> ownerScopeId,
      Value<String> ownerUserId,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> operation,
      Value<String> payloadJson,
      Value<String> status,
      Value<int> attemptCount,
      Value<String?> lastError,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> lastAttemptAt,
      Value<int> rowid,
    });

class $$SyncQueueTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableFilterComposer({
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

  ColumnFilters<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableOrderingComposer({
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

  ColumnOrderings<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );
}

class $$SyncQueueTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncQueueTable,
          SyncQueueRow,
          $$SyncQueueTableFilterComposer,
          $$SyncQueueTableOrderingComposer,
          $$SyncQueueTableAnnotationComposer,
          $$SyncQueueTableCreateCompanionBuilder,
          $$SyncQueueTableUpdateCompanionBuilder,
          (
            SyncQueueRow,
            BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueRow>,
          ),
          SyncQueueRow,
          PrefetchHooks Function()
        > {
  $$SyncQueueTableTableManager(_$AppDatabase db, $SyncQueueTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> ownerScopeId = const Value.absent(),
                Value<String> ownerUserId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncQueueCompanion(
                id: id,
                ownerScopeId: ownerScopeId,
                ownerUserId: ownerUserId,
                entityType: entityType,
                entityId: entityId,
                operation: operation,
                payloadJson: payloadJson,
                status: status,
                attemptCount: attemptCount,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastAttemptAt: lastAttemptAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> ownerScopeId = const Value.absent(),
                required String ownerUserId,
                required String entityType,
                required String entityId,
                required String operation,
                required String payloadJson,
                Value<String> status = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncQueueCompanion.insert(
                id: id,
                ownerScopeId: ownerScopeId,
                ownerUserId: ownerUserId,
                entityType: entityType,
                entityId: entityId,
                operation: operation,
                payloadJson: payloadJson,
                status: status,
                attemptCount: attemptCount,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastAttemptAt: lastAttemptAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncQueueTable,
      SyncQueueRow,
      $$SyncQueueTableFilterComposer,
      $$SyncQueueTableOrderingComposer,
      $$SyncQueueTableAnnotationComposer,
      $$SyncQueueTableCreateCompanionBuilder,
      $$SyncQueueTableUpdateCompanionBuilder,
      (
        SyncQueueRow,
        BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueRow>,
      ),
      SyncQueueRow,
      PrefetchHooks Function()
    >;
typedef $$ReceiptsTableCreateCompanionBuilder =
    ReceiptsCompanion Function({
      required String id,
      Value<String?> ownerScopeId,
      required String documentType,
      required String paymentStatus,
      Value<String?> merchantName,
      Value<String?> merchantPayeeId,
      Value<String?> merchantAddress,
      Value<String?> merchantTaxId,
      Value<String?> receiptNumber,
      Value<String?> invoiceNumber,
      Value<DateTime?> purchaseDate,
      Value<DateTime?> dueDate,
      Value<String?> currency,
      Value<String?> subtotal,
      Value<String?> tax,
      Value<String?> discount,
      Value<String?> serviceCharge,
      Value<String?> tip,
      Value<String?> otherFees,
      Value<String?> total,
      Value<String?> amountPaid,
      Value<String?> amountDue,
      Value<String?> paymentMethodHint,
      Value<String?> accountHint,
      Value<int> confidence,
      Value<String> warningsJson,
      Value<String> duplicateCandidateIdsJson,
      required String imageRetentionChoice,
      Value<String?> localImageReference,
      Value<String?> imageHash,
      required String status,
      Value<String?> linkedTransactionId,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ReceiptsTableUpdateCompanionBuilder =
    ReceiptsCompanion Function({
      Value<String> id,
      Value<String?> ownerScopeId,
      Value<String> documentType,
      Value<String> paymentStatus,
      Value<String?> merchantName,
      Value<String?> merchantPayeeId,
      Value<String?> merchantAddress,
      Value<String?> merchantTaxId,
      Value<String?> receiptNumber,
      Value<String?> invoiceNumber,
      Value<DateTime?> purchaseDate,
      Value<DateTime?> dueDate,
      Value<String?> currency,
      Value<String?> subtotal,
      Value<String?> tax,
      Value<String?> discount,
      Value<String?> serviceCharge,
      Value<String?> tip,
      Value<String?> otherFees,
      Value<String?> total,
      Value<String?> amountPaid,
      Value<String?> amountDue,
      Value<String?> paymentMethodHint,
      Value<String?> accountHint,
      Value<int> confidence,
      Value<String> warningsJson,
      Value<String> duplicateCandidateIdsJson,
      Value<String> imageRetentionChoice,
      Value<String?> localImageReference,
      Value<String?> imageHash,
      Value<String> status,
      Value<String?> linkedTransactionId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ReceiptsTableFilterComposer
    extends Composer<_$AppDatabase, $ReceiptsTable> {
  $$ReceiptsTableFilterComposer({
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

  ColumnFilters<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentType => $composableBuilder(
    column: $table.documentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentStatus => $composableBuilder(
    column: $table.paymentStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get merchantName => $composableBuilder(
    column: $table.merchantName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get merchantPayeeId => $composableBuilder(
    column: $table.merchantPayeeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get merchantAddress => $composableBuilder(
    column: $table.merchantAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get merchantTaxId => $composableBuilder(
    column: $table.merchantTaxId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiptNumber => $composableBuilder(
    column: $table.receiptNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get invoiceNumber => $composableBuilder(
    column: $table.invoiceNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get purchaseDate => $composableBuilder(
    column: $table.purchaseDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subtotal => $composableBuilder(
    column: $table.subtotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tax => $composableBuilder(
    column: $table.tax,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get discount => $composableBuilder(
    column: $table.discount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serviceCharge => $composableBuilder(
    column: $table.serviceCharge,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tip => $composableBuilder(
    column: $table.tip,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get otherFees => $composableBuilder(
    column: $table.otherFees,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get amountPaid => $composableBuilder(
    column: $table.amountPaid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get amountDue => $composableBuilder(
    column: $table.amountDue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentMethodHint => $composableBuilder(
    column: $table.paymentMethodHint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountHint => $composableBuilder(
    column: $table.accountHint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get warningsJson => $composableBuilder(
    column: $table.warningsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get duplicateCandidateIdsJson => $composableBuilder(
    column: $table.duplicateCandidateIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageRetentionChoice => $composableBuilder(
    column: $table.imageRetentionChoice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localImageReference => $composableBuilder(
    column: $table.localImageReference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageHash => $composableBuilder(
    column: $table.imageHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkedTransactionId => $composableBuilder(
    column: $table.linkedTransactionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReceiptsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReceiptsTable> {
  $$ReceiptsTableOrderingComposer({
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

  ColumnOrderings<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentType => $composableBuilder(
    column: $table.documentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentStatus => $composableBuilder(
    column: $table.paymentStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get merchantName => $composableBuilder(
    column: $table.merchantName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get merchantPayeeId => $composableBuilder(
    column: $table.merchantPayeeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get merchantAddress => $composableBuilder(
    column: $table.merchantAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get merchantTaxId => $composableBuilder(
    column: $table.merchantTaxId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiptNumber => $composableBuilder(
    column: $table.receiptNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get invoiceNumber => $composableBuilder(
    column: $table.invoiceNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get purchaseDate => $composableBuilder(
    column: $table.purchaseDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subtotal => $composableBuilder(
    column: $table.subtotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tax => $composableBuilder(
    column: $table.tax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get discount => $composableBuilder(
    column: $table.discount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serviceCharge => $composableBuilder(
    column: $table.serviceCharge,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tip => $composableBuilder(
    column: $table.tip,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get otherFees => $composableBuilder(
    column: $table.otherFees,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amountPaid => $composableBuilder(
    column: $table.amountPaid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amountDue => $composableBuilder(
    column: $table.amountDue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentMethodHint => $composableBuilder(
    column: $table.paymentMethodHint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountHint => $composableBuilder(
    column: $table.accountHint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get warningsJson => $composableBuilder(
    column: $table.warningsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get duplicateCandidateIdsJson => $composableBuilder(
    column: $table.duplicateCandidateIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageRetentionChoice => $composableBuilder(
    column: $table.imageRetentionChoice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localImageReference => $composableBuilder(
    column: $table.localImageReference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageHash => $composableBuilder(
    column: $table.imageHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkedTransactionId => $composableBuilder(
    column: $table.linkedTransactionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReceiptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReceiptsTable> {
  $$ReceiptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get documentType => $composableBuilder(
    column: $table.documentType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get paymentStatus => $composableBuilder(
    column: $table.paymentStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get merchantName => $composableBuilder(
    column: $table.merchantName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get merchantPayeeId => $composableBuilder(
    column: $table.merchantPayeeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get merchantAddress => $composableBuilder(
    column: $table.merchantAddress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get merchantTaxId => $composableBuilder(
    column: $table.merchantTaxId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get receiptNumber => $composableBuilder(
    column: $table.receiptNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get invoiceNumber => $composableBuilder(
    column: $table.invoiceNumber,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get purchaseDate => $composableBuilder(
    column: $table.purchaseDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get subtotal =>
      $composableBuilder(column: $table.subtotal, builder: (column) => column);

  GeneratedColumn<String> get tax =>
      $composableBuilder(column: $table.tax, builder: (column) => column);

  GeneratedColumn<String> get discount =>
      $composableBuilder(column: $table.discount, builder: (column) => column);

  GeneratedColumn<String> get serviceCharge => $composableBuilder(
    column: $table.serviceCharge,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tip =>
      $composableBuilder(column: $table.tip, builder: (column) => column);

  GeneratedColumn<String> get otherFees =>
      $composableBuilder(column: $table.otherFees, builder: (column) => column);

  GeneratedColumn<String> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<String> get amountPaid => $composableBuilder(
    column: $table.amountPaid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get amountDue =>
      $composableBuilder(column: $table.amountDue, builder: (column) => column);

  GeneratedColumn<String> get paymentMethodHint => $composableBuilder(
    column: $table.paymentMethodHint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accountHint => $composableBuilder(
    column: $table.accountHint,
    builder: (column) => column,
  );

  GeneratedColumn<int> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get warningsJson => $composableBuilder(
    column: $table.warningsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get duplicateCandidateIdsJson => $composableBuilder(
    column: $table.duplicateCandidateIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageRetentionChoice => $composableBuilder(
    column: $table.imageRetentionChoice,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localImageReference => $composableBuilder(
    column: $table.localImageReference,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageHash =>
      $composableBuilder(column: $table.imageHash, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get linkedTransactionId => $composableBuilder(
    column: $table.linkedTransactionId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ReceiptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReceiptsTable,
          ReceiptRow,
          $$ReceiptsTableFilterComposer,
          $$ReceiptsTableOrderingComposer,
          $$ReceiptsTableAnnotationComposer,
          $$ReceiptsTableCreateCompanionBuilder,
          $$ReceiptsTableUpdateCompanionBuilder,
          (
            ReceiptRow,
            BaseReferences<_$AppDatabase, $ReceiptsTable, ReceiptRow>,
          ),
          ReceiptRow,
          PrefetchHooks Function()
        > {
  $$ReceiptsTableTableManager(_$AppDatabase db, $ReceiptsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReceiptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReceiptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReceiptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> ownerScopeId = const Value.absent(),
                Value<String> documentType = const Value.absent(),
                Value<String> paymentStatus = const Value.absent(),
                Value<String?> merchantName = const Value.absent(),
                Value<String?> merchantPayeeId = const Value.absent(),
                Value<String?> merchantAddress = const Value.absent(),
                Value<String?> merchantTaxId = const Value.absent(),
                Value<String?> receiptNumber = const Value.absent(),
                Value<String?> invoiceNumber = const Value.absent(),
                Value<DateTime?> purchaseDate = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<String?> currency = const Value.absent(),
                Value<String?> subtotal = const Value.absent(),
                Value<String?> tax = const Value.absent(),
                Value<String?> discount = const Value.absent(),
                Value<String?> serviceCharge = const Value.absent(),
                Value<String?> tip = const Value.absent(),
                Value<String?> otherFees = const Value.absent(),
                Value<String?> total = const Value.absent(),
                Value<String?> amountPaid = const Value.absent(),
                Value<String?> amountDue = const Value.absent(),
                Value<String?> paymentMethodHint = const Value.absent(),
                Value<String?> accountHint = const Value.absent(),
                Value<int> confidence = const Value.absent(),
                Value<String> warningsJson = const Value.absent(),
                Value<String> duplicateCandidateIdsJson = const Value.absent(),
                Value<String> imageRetentionChoice = const Value.absent(),
                Value<String?> localImageReference = const Value.absent(),
                Value<String?> imageHash = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> linkedTransactionId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReceiptsCompanion(
                id: id,
                ownerScopeId: ownerScopeId,
                documentType: documentType,
                paymentStatus: paymentStatus,
                merchantName: merchantName,
                merchantPayeeId: merchantPayeeId,
                merchantAddress: merchantAddress,
                merchantTaxId: merchantTaxId,
                receiptNumber: receiptNumber,
                invoiceNumber: invoiceNumber,
                purchaseDate: purchaseDate,
                dueDate: dueDate,
                currency: currency,
                subtotal: subtotal,
                tax: tax,
                discount: discount,
                serviceCharge: serviceCharge,
                tip: tip,
                otherFees: otherFees,
                total: total,
                amountPaid: amountPaid,
                amountDue: amountDue,
                paymentMethodHint: paymentMethodHint,
                accountHint: accountHint,
                confidence: confidence,
                warningsJson: warningsJson,
                duplicateCandidateIdsJson: duplicateCandidateIdsJson,
                imageRetentionChoice: imageRetentionChoice,
                localImageReference: localImageReference,
                imageHash: imageHash,
                status: status,
                linkedTransactionId: linkedTransactionId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> ownerScopeId = const Value.absent(),
                required String documentType,
                required String paymentStatus,
                Value<String?> merchantName = const Value.absent(),
                Value<String?> merchantPayeeId = const Value.absent(),
                Value<String?> merchantAddress = const Value.absent(),
                Value<String?> merchantTaxId = const Value.absent(),
                Value<String?> receiptNumber = const Value.absent(),
                Value<String?> invoiceNumber = const Value.absent(),
                Value<DateTime?> purchaseDate = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<String?> currency = const Value.absent(),
                Value<String?> subtotal = const Value.absent(),
                Value<String?> tax = const Value.absent(),
                Value<String?> discount = const Value.absent(),
                Value<String?> serviceCharge = const Value.absent(),
                Value<String?> tip = const Value.absent(),
                Value<String?> otherFees = const Value.absent(),
                Value<String?> total = const Value.absent(),
                Value<String?> amountPaid = const Value.absent(),
                Value<String?> amountDue = const Value.absent(),
                Value<String?> paymentMethodHint = const Value.absent(),
                Value<String?> accountHint = const Value.absent(),
                Value<int> confidence = const Value.absent(),
                Value<String> warningsJson = const Value.absent(),
                Value<String> duplicateCandidateIdsJson = const Value.absent(),
                required String imageRetentionChoice,
                Value<String?> localImageReference = const Value.absent(),
                Value<String?> imageHash = const Value.absent(),
                required String status,
                Value<String?> linkedTransactionId = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ReceiptsCompanion.insert(
                id: id,
                ownerScopeId: ownerScopeId,
                documentType: documentType,
                paymentStatus: paymentStatus,
                merchantName: merchantName,
                merchantPayeeId: merchantPayeeId,
                merchantAddress: merchantAddress,
                merchantTaxId: merchantTaxId,
                receiptNumber: receiptNumber,
                invoiceNumber: invoiceNumber,
                purchaseDate: purchaseDate,
                dueDate: dueDate,
                currency: currency,
                subtotal: subtotal,
                tax: tax,
                discount: discount,
                serviceCharge: serviceCharge,
                tip: tip,
                otherFees: otherFees,
                total: total,
                amountPaid: amountPaid,
                amountDue: amountDue,
                paymentMethodHint: paymentMethodHint,
                accountHint: accountHint,
                confidence: confidence,
                warningsJson: warningsJson,
                duplicateCandidateIdsJson: duplicateCandidateIdsJson,
                imageRetentionChoice: imageRetentionChoice,
                localImageReference: localImageReference,
                imageHash: imageHash,
                status: status,
                linkedTransactionId: linkedTransactionId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReceiptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReceiptsTable,
      ReceiptRow,
      $$ReceiptsTableFilterComposer,
      $$ReceiptsTableOrderingComposer,
      $$ReceiptsTableAnnotationComposer,
      $$ReceiptsTableCreateCompanionBuilder,
      $$ReceiptsTableUpdateCompanionBuilder,
      (ReceiptRow, BaseReferences<_$AppDatabase, $ReceiptsTable, ReceiptRow>),
      ReceiptRow,
      PrefetchHooks Function()
    >;
typedef $$ReceiptLineItemsTableCreateCompanionBuilder =
    ReceiptLineItemsCompanion Function({
      required String id,
      Value<String?> ownerScopeId,
      required String receiptId,
      required String description,
      required String normalizedDescription,
      Value<String?> quantity,
      Value<String?> unit,
      Value<String?> unitPrice,
      Value<String?> discount,
      Value<String?> tax,
      Value<String?> totalPrice,
      Value<String?> categoryId,
      Value<String?> categoryHint,
      Value<int> categoryConfidence,
      required String categorySuggestionSource,
      Value<String> categoryAlternativesJson,
      Value<String?> skuOrBarcode,
      Value<String> warningsJson,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$ReceiptLineItemsTableUpdateCompanionBuilder =
    ReceiptLineItemsCompanion Function({
      Value<String> id,
      Value<String?> ownerScopeId,
      Value<String> receiptId,
      Value<String> description,
      Value<String> normalizedDescription,
      Value<String?> quantity,
      Value<String?> unit,
      Value<String?> unitPrice,
      Value<String?> discount,
      Value<String?> tax,
      Value<String?> totalPrice,
      Value<String?> categoryId,
      Value<String?> categoryHint,
      Value<int> categoryConfidence,
      Value<String> categorySuggestionSource,
      Value<String> categoryAlternativesJson,
      Value<String?> skuOrBarcode,
      Value<String> warningsJson,
      Value<int> sortOrder,
      Value<int> rowid,
    });

class $$ReceiptLineItemsTableFilterComposer
    extends Composer<_$AppDatabase, $ReceiptLineItemsTable> {
  $$ReceiptLineItemsTableFilterComposer({
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

  ColumnFilters<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiptId => $composableBuilder(
    column: $table.receiptId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedDescription => $composableBuilder(
    column: $table.normalizedDescription,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unitPrice => $composableBuilder(
    column: $table.unitPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get discount => $composableBuilder(
    column: $table.discount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tax => $composableBuilder(
    column: $table.tax,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get totalPrice => $composableBuilder(
    column: $table.totalPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryHint => $composableBuilder(
    column: $table.categoryHint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get categoryConfidence => $composableBuilder(
    column: $table.categoryConfidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categorySuggestionSource => $composableBuilder(
    column: $table.categorySuggestionSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryAlternativesJson => $composableBuilder(
    column: $table.categoryAlternativesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get skuOrBarcode => $composableBuilder(
    column: $table.skuOrBarcode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get warningsJson => $composableBuilder(
    column: $table.warningsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReceiptLineItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReceiptLineItemsTable> {
  $$ReceiptLineItemsTableOrderingComposer({
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

  ColumnOrderings<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiptId => $composableBuilder(
    column: $table.receiptId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedDescription => $composableBuilder(
    column: $table.normalizedDescription,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitPrice => $composableBuilder(
    column: $table.unitPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get discount => $composableBuilder(
    column: $table.discount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tax => $composableBuilder(
    column: $table.tax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get totalPrice => $composableBuilder(
    column: $table.totalPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryHint => $composableBuilder(
    column: $table.categoryHint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get categoryConfidence => $composableBuilder(
    column: $table.categoryConfidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categorySuggestionSource => $composableBuilder(
    column: $table.categorySuggestionSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryAlternativesJson => $composableBuilder(
    column: $table.categoryAlternativesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get skuOrBarcode => $composableBuilder(
    column: $table.skuOrBarcode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get warningsJson => $composableBuilder(
    column: $table.warningsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReceiptLineItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReceiptLineItemsTable> {
  $$ReceiptLineItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get receiptId =>
      $composableBuilder(column: $table.receiptId, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get normalizedDescription => $composableBuilder(
    column: $table.normalizedDescription,
    builder: (column) => column,
  );

  GeneratedColumn<String> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get unitPrice =>
      $composableBuilder(column: $table.unitPrice, builder: (column) => column);

  GeneratedColumn<String> get discount =>
      $composableBuilder(column: $table.discount, builder: (column) => column);

  GeneratedColumn<String> get tax =>
      $composableBuilder(column: $table.tax, builder: (column) => column);

  GeneratedColumn<String> get totalPrice => $composableBuilder(
    column: $table.totalPrice,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoryHint => $composableBuilder(
    column: $table.categoryHint,
    builder: (column) => column,
  );

  GeneratedColumn<int> get categoryConfidence => $composableBuilder(
    column: $table.categoryConfidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categorySuggestionSource => $composableBuilder(
    column: $table.categorySuggestionSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoryAlternativesJson => $composableBuilder(
    column: $table.categoryAlternativesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get skuOrBarcode => $composableBuilder(
    column: $table.skuOrBarcode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get warningsJson => $composableBuilder(
    column: $table.warningsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$ReceiptLineItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReceiptLineItemsTable,
          ReceiptLineItemRow,
          $$ReceiptLineItemsTableFilterComposer,
          $$ReceiptLineItemsTableOrderingComposer,
          $$ReceiptLineItemsTableAnnotationComposer,
          $$ReceiptLineItemsTableCreateCompanionBuilder,
          $$ReceiptLineItemsTableUpdateCompanionBuilder,
          (
            ReceiptLineItemRow,
            BaseReferences<
              _$AppDatabase,
              $ReceiptLineItemsTable,
              ReceiptLineItemRow
            >,
          ),
          ReceiptLineItemRow,
          PrefetchHooks Function()
        > {
  $$ReceiptLineItemsTableTableManager(
    _$AppDatabase db,
    $ReceiptLineItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReceiptLineItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReceiptLineItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReceiptLineItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> ownerScopeId = const Value.absent(),
                Value<String> receiptId = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> normalizedDescription = const Value.absent(),
                Value<String?> quantity = const Value.absent(),
                Value<String?> unit = const Value.absent(),
                Value<String?> unitPrice = const Value.absent(),
                Value<String?> discount = const Value.absent(),
                Value<String?> tax = const Value.absent(),
                Value<String?> totalPrice = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> categoryHint = const Value.absent(),
                Value<int> categoryConfidence = const Value.absent(),
                Value<String> categorySuggestionSource = const Value.absent(),
                Value<String> categoryAlternativesJson = const Value.absent(),
                Value<String?> skuOrBarcode = const Value.absent(),
                Value<String> warningsJson = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReceiptLineItemsCompanion(
                id: id,
                ownerScopeId: ownerScopeId,
                receiptId: receiptId,
                description: description,
                normalizedDescription: normalizedDescription,
                quantity: quantity,
                unit: unit,
                unitPrice: unitPrice,
                discount: discount,
                tax: tax,
                totalPrice: totalPrice,
                categoryId: categoryId,
                categoryHint: categoryHint,
                categoryConfidence: categoryConfidence,
                categorySuggestionSource: categorySuggestionSource,
                categoryAlternativesJson: categoryAlternativesJson,
                skuOrBarcode: skuOrBarcode,
                warningsJson: warningsJson,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> ownerScopeId = const Value.absent(),
                required String receiptId,
                required String description,
                required String normalizedDescription,
                Value<String?> quantity = const Value.absent(),
                Value<String?> unit = const Value.absent(),
                Value<String?> unitPrice = const Value.absent(),
                Value<String?> discount = const Value.absent(),
                Value<String?> tax = const Value.absent(),
                Value<String?> totalPrice = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> categoryHint = const Value.absent(),
                Value<int> categoryConfidence = const Value.absent(),
                required String categorySuggestionSource,
                Value<String> categoryAlternativesJson = const Value.absent(),
                Value<String?> skuOrBarcode = const Value.absent(),
                Value<String> warningsJson = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReceiptLineItemsCompanion.insert(
                id: id,
                ownerScopeId: ownerScopeId,
                receiptId: receiptId,
                description: description,
                normalizedDescription: normalizedDescription,
                quantity: quantity,
                unit: unit,
                unitPrice: unitPrice,
                discount: discount,
                tax: tax,
                totalPrice: totalPrice,
                categoryId: categoryId,
                categoryHint: categoryHint,
                categoryConfidence: categoryConfidence,
                categorySuggestionSource: categorySuggestionSource,
                categoryAlternativesJson: categoryAlternativesJson,
                skuOrBarcode: skuOrBarcode,
                warningsJson: warningsJson,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReceiptLineItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReceiptLineItemsTable,
      ReceiptLineItemRow,
      $$ReceiptLineItemsTableFilterComposer,
      $$ReceiptLineItemsTableOrderingComposer,
      $$ReceiptLineItemsTableAnnotationComposer,
      $$ReceiptLineItemsTableCreateCompanionBuilder,
      $$ReceiptLineItemsTableUpdateCompanionBuilder,
      (
        ReceiptLineItemRow,
        BaseReferences<
          _$AppDatabase,
          $ReceiptLineItemsTable,
          ReceiptLineItemRow
        >,
      ),
      ReceiptLineItemRow,
      PrefetchHooks Function()
    >;
typedef $$TransactionSplitsTableCreateCompanionBuilder =
    TransactionSplitsCompanion Function({
      required String id,
      Value<String?> ownerScopeId,
      required String receiptId,
      Value<String?> transactionId,
      Value<String?> draftId,
      required String categoryId,
      required String amount,
      Value<String> sourceReceiptItemIdsJson,
      Value<String?> description,
      Value<int> rowid,
    });
typedef $$TransactionSplitsTableUpdateCompanionBuilder =
    TransactionSplitsCompanion Function({
      Value<String> id,
      Value<String?> ownerScopeId,
      Value<String> receiptId,
      Value<String?> transactionId,
      Value<String?> draftId,
      Value<String> categoryId,
      Value<String> amount,
      Value<String> sourceReceiptItemIdsJson,
      Value<String?> description,
      Value<int> rowid,
    });

class $$TransactionSplitsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionSplitsTable> {
  $$TransactionSplitsTableFilterComposer({
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

  ColumnFilters<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiptId => $composableBuilder(
    column: $table.receiptId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transactionId => $composableBuilder(
    column: $table.transactionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get draftId => $composableBuilder(
    column: $table.draftId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceReceiptItemIdsJson => $composableBuilder(
    column: $table.sourceReceiptItemIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TransactionSplitsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionSplitsTable> {
  $$TransactionSplitsTableOrderingComposer({
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

  ColumnOrderings<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiptId => $composableBuilder(
    column: $table.receiptId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transactionId => $composableBuilder(
    column: $table.transactionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get draftId => $composableBuilder(
    column: $table.draftId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceReceiptItemIdsJson => $composableBuilder(
    column: $table.sourceReceiptItemIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TransactionSplitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionSplitsTable> {
  $$TransactionSplitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get receiptId =>
      $composableBuilder(column: $table.receiptId, builder: (column) => column);

  GeneratedColumn<String> get transactionId => $composableBuilder(
    column: $table.transactionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get draftId =>
      $composableBuilder(column: $table.draftId, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get sourceReceiptItemIdsJson => $composableBuilder(
    column: $table.sourceReceiptItemIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );
}

class $$TransactionSplitsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionSplitsTable,
          TransactionSplitRow,
          $$TransactionSplitsTableFilterComposer,
          $$TransactionSplitsTableOrderingComposer,
          $$TransactionSplitsTableAnnotationComposer,
          $$TransactionSplitsTableCreateCompanionBuilder,
          $$TransactionSplitsTableUpdateCompanionBuilder,
          (
            TransactionSplitRow,
            BaseReferences<
              _$AppDatabase,
              $TransactionSplitsTable,
              TransactionSplitRow
            >,
          ),
          TransactionSplitRow,
          PrefetchHooks Function()
        > {
  $$TransactionSplitsTableTableManager(
    _$AppDatabase db,
    $TransactionSplitsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionSplitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionSplitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionSplitsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> ownerScopeId = const Value.absent(),
                Value<String> receiptId = const Value.absent(),
                Value<String?> transactionId = const Value.absent(),
                Value<String?> draftId = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<String> amount = const Value.absent(),
                Value<String> sourceReceiptItemIdsJson = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionSplitsCompanion(
                id: id,
                ownerScopeId: ownerScopeId,
                receiptId: receiptId,
                transactionId: transactionId,
                draftId: draftId,
                categoryId: categoryId,
                amount: amount,
                sourceReceiptItemIdsJson: sourceReceiptItemIdsJson,
                description: description,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> ownerScopeId = const Value.absent(),
                required String receiptId,
                Value<String?> transactionId = const Value.absent(),
                Value<String?> draftId = const Value.absent(),
                required String categoryId,
                required String amount,
                Value<String> sourceReceiptItemIdsJson = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionSplitsCompanion.insert(
                id: id,
                ownerScopeId: ownerScopeId,
                receiptId: receiptId,
                transactionId: transactionId,
                draftId: draftId,
                categoryId: categoryId,
                amount: amount,
                sourceReceiptItemIdsJson: sourceReceiptItemIdsJson,
                description: description,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TransactionSplitsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionSplitsTable,
      TransactionSplitRow,
      $$TransactionSplitsTableFilterComposer,
      $$TransactionSplitsTableOrderingComposer,
      $$TransactionSplitsTableAnnotationComposer,
      $$TransactionSplitsTableCreateCompanionBuilder,
      $$TransactionSplitsTableUpdateCompanionBuilder,
      (
        TransactionSplitRow,
        BaseReferences<
          _$AppDatabase,
          $TransactionSplitsTable,
          TransactionSplitRow
        >,
      ),
      TransactionSplitRow,
      PrefetchHooks Function()
    >;
typedef $$OwnerScopeMigrationAuditsTableCreateCompanionBuilder =
    OwnerScopeMigrationAuditsCompanion Function({
      required String id,
      required String ownerScopeId,
      required String status,
      required String boundedCountsJson,
      Value<String?> safeFailureCode,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$OwnerScopeMigrationAuditsTableUpdateCompanionBuilder =
    OwnerScopeMigrationAuditsCompanion Function({
      Value<String> id,
      Value<String> ownerScopeId,
      Value<String> status,
      Value<String> boundedCountsJson,
      Value<String?> safeFailureCode,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$OwnerScopeMigrationAuditsTableFilterComposer
    extends Composer<_$AppDatabase, $OwnerScopeMigrationAuditsTable> {
  $$OwnerScopeMigrationAuditsTableFilterComposer({
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

  ColumnFilters<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get boundedCountsJson => $composableBuilder(
    column: $table.boundedCountsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get safeFailureCode => $composableBuilder(
    column: $table.safeFailureCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OwnerScopeMigrationAuditsTableOrderingComposer
    extends Composer<_$AppDatabase, $OwnerScopeMigrationAuditsTable> {
  $$OwnerScopeMigrationAuditsTableOrderingComposer({
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

  ColumnOrderings<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get boundedCountsJson => $composableBuilder(
    column: $table.boundedCountsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get safeFailureCode => $composableBuilder(
    column: $table.safeFailureCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OwnerScopeMigrationAuditsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OwnerScopeMigrationAuditsTable> {
  $$OwnerScopeMigrationAuditsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get boundedCountsJson => $composableBuilder(
    column: $table.boundedCountsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get safeFailureCode => $composableBuilder(
    column: $table.safeFailureCode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$OwnerScopeMigrationAuditsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OwnerScopeMigrationAuditsTable,
          OwnerScopeMigrationAuditRow,
          $$OwnerScopeMigrationAuditsTableFilterComposer,
          $$OwnerScopeMigrationAuditsTableOrderingComposer,
          $$OwnerScopeMigrationAuditsTableAnnotationComposer,
          $$OwnerScopeMigrationAuditsTableCreateCompanionBuilder,
          $$OwnerScopeMigrationAuditsTableUpdateCompanionBuilder,
          (
            OwnerScopeMigrationAuditRow,
            BaseReferences<
              _$AppDatabase,
              $OwnerScopeMigrationAuditsTable,
              OwnerScopeMigrationAuditRow
            >,
          ),
          OwnerScopeMigrationAuditRow,
          PrefetchHooks Function()
        > {
  $$OwnerScopeMigrationAuditsTableTableManager(
    _$AppDatabase db,
    $OwnerScopeMigrationAuditsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OwnerScopeMigrationAuditsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$OwnerScopeMigrationAuditsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$OwnerScopeMigrationAuditsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerScopeId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> boundedCountsJson = const Value.absent(),
                Value<String?> safeFailureCode = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OwnerScopeMigrationAuditsCompanion(
                id: id,
                ownerScopeId: ownerScopeId,
                status: status,
                boundedCountsJson: boundedCountsJson,
                safeFailureCode: safeFailureCode,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ownerScopeId,
                required String status,
                required String boundedCountsJson,
                Value<String?> safeFailureCode = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => OwnerScopeMigrationAuditsCompanion.insert(
                id: id,
                ownerScopeId: ownerScopeId,
                status: status,
                boundedCountsJson: boundedCountsJson,
                safeFailureCode: safeFailureCode,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OwnerScopeMigrationAuditsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OwnerScopeMigrationAuditsTable,
      OwnerScopeMigrationAuditRow,
      $$OwnerScopeMigrationAuditsTableFilterComposer,
      $$OwnerScopeMigrationAuditsTableOrderingComposer,
      $$OwnerScopeMigrationAuditsTableAnnotationComposer,
      $$OwnerScopeMigrationAuditsTableCreateCompanionBuilder,
      $$OwnerScopeMigrationAuditsTableUpdateCompanionBuilder,
      (
        OwnerScopeMigrationAuditRow,
        BaseReferences<
          _$AppDatabase,
          $OwnerScopeMigrationAuditsTable,
          OwnerScopeMigrationAuditRow
        >,
      ),
      OwnerScopeMigrationAuditRow,
      PrefetchHooks Function()
    >;
typedef $$AiAgentCommandsTableCreateCompanionBuilder =
    AiAgentCommandsCompanion Function({
      required String ownerScopeId,
      required DateTime createdAt,
      required DateTime updatedAt,
      required String id,
      required String conversationId,
      required String commandType,
      required String toolId,
      required String normalizedArgumentsJson,
      required String permission,
      required String risk,
      required String status,
      Value<int> revision,
      Value<String?> previewFingerprint,
      Value<String?> safeFailureCode,
      required DateTime expiresAt,
      Value<int> rowid,
    });
typedef $$AiAgentCommandsTableUpdateCompanionBuilder =
    AiAgentCommandsCompanion Function({
      Value<String> ownerScopeId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String> id,
      Value<String> conversationId,
      Value<String> commandType,
      Value<String> toolId,
      Value<String> normalizedArgumentsJson,
      Value<String> permission,
      Value<String> risk,
      Value<String> status,
      Value<int> revision,
      Value<String?> previewFingerprint,
      Value<String?> safeFailureCode,
      Value<DateTime> expiresAt,
      Value<int> rowid,
    });

class $$AiAgentCommandsTableFilterComposer
    extends Composer<_$AppDatabase, $AiAgentCommandsTable> {
  $$AiAgentCommandsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commandType => $composableBuilder(
    column: $table.commandType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toolId => $composableBuilder(
    column: $table.toolId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedArgumentsJson => $composableBuilder(
    column: $table.normalizedArgumentsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get permission => $composableBuilder(
    column: $table.permission,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get risk => $composableBuilder(
    column: $table.risk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get previewFingerprint => $composableBuilder(
    column: $table.previewFingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get safeFailureCode => $composableBuilder(
    column: $table.safeFailureCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiAgentCommandsTableOrderingComposer
    extends Composer<_$AppDatabase, $AiAgentCommandsTable> {
  $$AiAgentCommandsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commandType => $composableBuilder(
    column: $table.commandType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toolId => $composableBuilder(
    column: $table.toolId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedArgumentsJson => $composableBuilder(
    column: $table.normalizedArgumentsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get permission => $composableBuilder(
    column: $table.permission,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get risk => $composableBuilder(
    column: $table.risk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get previewFingerprint => $composableBuilder(
    column: $table.previewFingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get safeFailureCode => $composableBuilder(
    column: $table.safeFailureCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiAgentCommandsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiAgentCommandsTable> {
  $$AiAgentCommandsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get commandType => $composableBuilder(
    column: $table.commandType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get toolId =>
      $composableBuilder(column: $table.toolId, builder: (column) => column);

  GeneratedColumn<String> get normalizedArgumentsJson => $composableBuilder(
    column: $table.normalizedArgumentsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get permission => $composableBuilder(
    column: $table.permission,
    builder: (column) => column,
  );

  GeneratedColumn<String> get risk =>
      $composableBuilder(column: $table.risk, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get previewFingerprint => $composableBuilder(
    column: $table.previewFingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get safeFailureCode => $composableBuilder(
    column: $table.safeFailureCode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$AiAgentCommandsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiAgentCommandsTable,
          AiAgentCommandRow,
          $$AiAgentCommandsTableFilterComposer,
          $$AiAgentCommandsTableOrderingComposer,
          $$AiAgentCommandsTableAnnotationComposer,
          $$AiAgentCommandsTableCreateCompanionBuilder,
          $$AiAgentCommandsTableUpdateCompanionBuilder,
          (
            AiAgentCommandRow,
            BaseReferences<
              _$AppDatabase,
              $AiAgentCommandsTable,
              AiAgentCommandRow
            >,
          ),
          AiAgentCommandRow,
          PrefetchHooks Function()
        > {
  $$AiAgentCommandsTableTableManager(
    _$AppDatabase db,
    $AiAgentCommandsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiAgentCommandsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiAgentCommandsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiAgentCommandsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ownerScopeId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> commandType = const Value.absent(),
                Value<String> toolId = const Value.absent(),
                Value<String> normalizedArgumentsJson = const Value.absent(),
                Value<String> permission = const Value.absent(),
                Value<String> risk = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String?> previewFingerprint = const Value.absent(),
                Value<String?> safeFailureCode = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiAgentCommandsCompanion(
                ownerScopeId: ownerScopeId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                id: id,
                conversationId: conversationId,
                commandType: commandType,
                toolId: toolId,
                normalizedArgumentsJson: normalizedArgumentsJson,
                permission: permission,
                risk: risk,
                status: status,
                revision: revision,
                previewFingerprint: previewFingerprint,
                safeFailureCode: safeFailureCode,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerScopeId,
                required DateTime createdAt,
                required DateTime updatedAt,
                required String id,
                required String conversationId,
                required String commandType,
                required String toolId,
                required String normalizedArgumentsJson,
                required String permission,
                required String risk,
                required String status,
                Value<int> revision = const Value.absent(),
                Value<String?> previewFingerprint = const Value.absent(),
                Value<String?> safeFailureCode = const Value.absent(),
                required DateTime expiresAt,
                Value<int> rowid = const Value.absent(),
              }) => AiAgentCommandsCompanion.insert(
                ownerScopeId: ownerScopeId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                id: id,
                conversationId: conversationId,
                commandType: commandType,
                toolId: toolId,
                normalizedArgumentsJson: normalizedArgumentsJson,
                permission: permission,
                risk: risk,
                status: status,
                revision: revision,
                previewFingerprint: previewFingerprint,
                safeFailureCode: safeFailureCode,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiAgentCommandsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiAgentCommandsTable,
      AiAgentCommandRow,
      $$AiAgentCommandsTableFilterComposer,
      $$AiAgentCommandsTableOrderingComposer,
      $$AiAgentCommandsTableAnnotationComposer,
      $$AiAgentCommandsTableCreateCompanionBuilder,
      $$AiAgentCommandsTableUpdateCompanionBuilder,
      (
        AiAgentCommandRow,
        BaseReferences<_$AppDatabase, $AiAgentCommandsTable, AiAgentCommandRow>,
      ),
      AiAgentCommandRow,
      PrefetchHooks Function()
    >;
typedef $$AiAgentPreviewsTableCreateCompanionBuilder =
    AiAgentPreviewsCompanion Function({
      required String ownerScopeId,
      required DateTime createdAt,
      required DateTime updatedAt,
      required String id,
      required String commandId,
      required int revision,
      required String status,
      required String stateFingerprint,
      required String payloadJson,
      required DateTime expiresAt,
      Value<int> rowid,
    });
typedef $$AiAgentPreviewsTableUpdateCompanionBuilder =
    AiAgentPreviewsCompanion Function({
      Value<String> ownerScopeId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String> id,
      Value<String> commandId,
      Value<int> revision,
      Value<String> status,
      Value<String> stateFingerprint,
      Value<String> payloadJson,
      Value<DateTime> expiresAt,
      Value<int> rowid,
    });

class $$AiAgentPreviewsTableFilterComposer
    extends Composer<_$AppDatabase, $AiAgentPreviewsTable> {
  $$AiAgentPreviewsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commandId => $composableBuilder(
    column: $table.commandId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stateFingerprint => $composableBuilder(
    column: $table.stateFingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiAgentPreviewsTableOrderingComposer
    extends Composer<_$AppDatabase, $AiAgentPreviewsTable> {
  $$AiAgentPreviewsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commandId => $composableBuilder(
    column: $table.commandId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stateFingerprint => $composableBuilder(
    column: $table.stateFingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiAgentPreviewsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiAgentPreviewsTable> {
  $$AiAgentPreviewsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get commandId =>
      $composableBuilder(column: $table.commandId, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get stateFingerprint => $composableBuilder(
    column: $table.stateFingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$AiAgentPreviewsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiAgentPreviewsTable,
          AiAgentPreviewRow,
          $$AiAgentPreviewsTableFilterComposer,
          $$AiAgentPreviewsTableOrderingComposer,
          $$AiAgentPreviewsTableAnnotationComposer,
          $$AiAgentPreviewsTableCreateCompanionBuilder,
          $$AiAgentPreviewsTableUpdateCompanionBuilder,
          (
            AiAgentPreviewRow,
            BaseReferences<
              _$AppDatabase,
              $AiAgentPreviewsTable,
              AiAgentPreviewRow
            >,
          ),
          AiAgentPreviewRow,
          PrefetchHooks Function()
        > {
  $$AiAgentPreviewsTableTableManager(
    _$AppDatabase db,
    $AiAgentPreviewsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiAgentPreviewsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiAgentPreviewsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiAgentPreviewsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ownerScopeId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> commandId = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> stateFingerprint = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiAgentPreviewsCompanion(
                ownerScopeId: ownerScopeId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                id: id,
                commandId: commandId,
                revision: revision,
                status: status,
                stateFingerprint: stateFingerprint,
                payloadJson: payloadJson,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerScopeId,
                required DateTime createdAt,
                required DateTime updatedAt,
                required String id,
                required String commandId,
                required int revision,
                required String status,
                required String stateFingerprint,
                required String payloadJson,
                required DateTime expiresAt,
                Value<int> rowid = const Value.absent(),
              }) => AiAgentPreviewsCompanion.insert(
                ownerScopeId: ownerScopeId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                id: id,
                commandId: commandId,
                revision: revision,
                status: status,
                stateFingerprint: stateFingerprint,
                payloadJson: payloadJson,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiAgentPreviewsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiAgentPreviewsTable,
      AiAgentPreviewRow,
      $$AiAgentPreviewsTableFilterComposer,
      $$AiAgentPreviewsTableOrderingComposer,
      $$AiAgentPreviewsTableAnnotationComposer,
      $$AiAgentPreviewsTableCreateCompanionBuilder,
      $$AiAgentPreviewsTableUpdateCompanionBuilder,
      (
        AiAgentPreviewRow,
        BaseReferences<_$AppDatabase, $AiAgentPreviewsTable, AiAgentPreviewRow>,
      ),
      AiAgentPreviewRow,
      PrefetchHooks Function()
    >;
typedef $$AiAgentConfirmationProofsTableCreateCompanionBuilder =
    AiAgentConfirmationProofsCompanion Function({
      required String ownerScopeId,
      required DateTime createdAt,
      required DateTime updatedAt,
      required String id,
      required String commandId,
      required int previewRevision,
      required String confirmationMethod,
      required String proofHash,
      required String proofSalt,
      required String status,
      required DateTime expiresAt,
      Value<DateTime?> consumedAt,
      Value<int> rowid,
    });
typedef $$AiAgentConfirmationProofsTableUpdateCompanionBuilder =
    AiAgentConfirmationProofsCompanion Function({
      Value<String> ownerScopeId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String> id,
      Value<String> commandId,
      Value<int> previewRevision,
      Value<String> confirmationMethod,
      Value<String> proofHash,
      Value<String> proofSalt,
      Value<String> status,
      Value<DateTime> expiresAt,
      Value<DateTime?> consumedAt,
      Value<int> rowid,
    });

class $$AiAgentConfirmationProofsTableFilterComposer
    extends Composer<_$AppDatabase, $AiAgentConfirmationProofsTable> {
  $$AiAgentConfirmationProofsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commandId => $composableBuilder(
    column: $table.commandId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get previewRevision => $composableBuilder(
    column: $table.previewRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get confirmationMethod => $composableBuilder(
    column: $table.confirmationMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get proofHash => $composableBuilder(
    column: $table.proofHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get proofSalt => $composableBuilder(
    column: $table.proofSalt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get consumedAt => $composableBuilder(
    column: $table.consumedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiAgentConfirmationProofsTableOrderingComposer
    extends Composer<_$AppDatabase, $AiAgentConfirmationProofsTable> {
  $$AiAgentConfirmationProofsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commandId => $composableBuilder(
    column: $table.commandId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get previewRevision => $composableBuilder(
    column: $table.previewRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get confirmationMethod => $composableBuilder(
    column: $table.confirmationMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get proofHash => $composableBuilder(
    column: $table.proofHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get proofSalt => $composableBuilder(
    column: $table.proofSalt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get consumedAt => $composableBuilder(
    column: $table.consumedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiAgentConfirmationProofsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiAgentConfirmationProofsTable> {
  $$AiAgentConfirmationProofsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get commandId =>
      $composableBuilder(column: $table.commandId, builder: (column) => column);

  GeneratedColumn<int> get previewRevision => $composableBuilder(
    column: $table.previewRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get confirmationMethod => $composableBuilder(
    column: $table.confirmationMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get proofHash =>
      $composableBuilder(column: $table.proofHash, builder: (column) => column);

  GeneratedColumn<String> get proofSalt =>
      $composableBuilder(column: $table.proofSalt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<DateTime> get consumedAt => $composableBuilder(
    column: $table.consumedAt,
    builder: (column) => column,
  );
}

class $$AiAgentConfirmationProofsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiAgentConfirmationProofsTable,
          AiAgentConfirmationProofRow,
          $$AiAgentConfirmationProofsTableFilterComposer,
          $$AiAgentConfirmationProofsTableOrderingComposer,
          $$AiAgentConfirmationProofsTableAnnotationComposer,
          $$AiAgentConfirmationProofsTableCreateCompanionBuilder,
          $$AiAgentConfirmationProofsTableUpdateCompanionBuilder,
          (
            AiAgentConfirmationProofRow,
            BaseReferences<
              _$AppDatabase,
              $AiAgentConfirmationProofsTable,
              AiAgentConfirmationProofRow
            >,
          ),
          AiAgentConfirmationProofRow,
          PrefetchHooks Function()
        > {
  $$AiAgentConfirmationProofsTableTableManager(
    _$AppDatabase db,
    $AiAgentConfirmationProofsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiAgentConfirmationProofsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$AiAgentConfirmationProofsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AiAgentConfirmationProofsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> ownerScopeId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> commandId = const Value.absent(),
                Value<int> previewRevision = const Value.absent(),
                Value<String> confirmationMethod = const Value.absent(),
                Value<String> proofHash = const Value.absent(),
                Value<String> proofSalt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<DateTime?> consumedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiAgentConfirmationProofsCompanion(
                ownerScopeId: ownerScopeId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                id: id,
                commandId: commandId,
                previewRevision: previewRevision,
                confirmationMethod: confirmationMethod,
                proofHash: proofHash,
                proofSalt: proofSalt,
                status: status,
                expiresAt: expiresAt,
                consumedAt: consumedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerScopeId,
                required DateTime createdAt,
                required DateTime updatedAt,
                required String id,
                required String commandId,
                required int previewRevision,
                required String confirmationMethod,
                required String proofHash,
                required String proofSalt,
                required String status,
                required DateTime expiresAt,
                Value<DateTime?> consumedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiAgentConfirmationProofsCompanion.insert(
                ownerScopeId: ownerScopeId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                id: id,
                commandId: commandId,
                previewRevision: previewRevision,
                confirmationMethod: confirmationMethod,
                proofHash: proofHash,
                proofSalt: proofSalt,
                status: status,
                expiresAt: expiresAt,
                consumedAt: consumedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiAgentConfirmationProofsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiAgentConfirmationProofsTable,
      AiAgentConfirmationProofRow,
      $$AiAgentConfirmationProofsTableFilterComposer,
      $$AiAgentConfirmationProofsTableOrderingComposer,
      $$AiAgentConfirmationProofsTableAnnotationComposer,
      $$AiAgentConfirmationProofsTableCreateCompanionBuilder,
      $$AiAgentConfirmationProofsTableUpdateCompanionBuilder,
      (
        AiAgentConfirmationProofRow,
        BaseReferences<
          _$AppDatabase,
          $AiAgentConfirmationProofsTable,
          AiAgentConfirmationProofRow
        >,
      ),
      AiAgentConfirmationProofRow,
      PrefetchHooks Function()
    >;
typedef $$AiAgentExecutionAttemptsTableCreateCompanionBuilder =
    AiAgentExecutionAttemptsCompanion Function({
      required String ownerScopeId,
      required DateTime createdAt,
      required DateTime updatedAt,
      required String id,
      required String commandId,
      required String idempotencyKey,
      required int commandRevision,
      required String actionType,
      required String status,
      Value<String?> businessOperationId,
      Value<String?> safeFailureCode,
      required DateTime claimedAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });
typedef $$AiAgentExecutionAttemptsTableUpdateCompanionBuilder =
    AiAgentExecutionAttemptsCompanion Function({
      Value<String> ownerScopeId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String> id,
      Value<String> commandId,
      Value<String> idempotencyKey,
      Value<int> commandRevision,
      Value<String> actionType,
      Value<String> status,
      Value<String?> businessOperationId,
      Value<String?> safeFailureCode,
      Value<DateTime> claimedAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });

class $$AiAgentExecutionAttemptsTableFilterComposer
    extends Composer<_$AppDatabase, $AiAgentExecutionAttemptsTable> {
  $$AiAgentExecutionAttemptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commandId => $composableBuilder(
    column: $table.commandId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get commandRevision => $composableBuilder(
    column: $table.commandRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessOperationId => $composableBuilder(
    column: $table.businessOperationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get safeFailureCode => $composableBuilder(
    column: $table.safeFailureCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get claimedAt => $composableBuilder(
    column: $table.claimedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiAgentExecutionAttemptsTableOrderingComposer
    extends Composer<_$AppDatabase, $AiAgentExecutionAttemptsTable> {
  $$AiAgentExecutionAttemptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commandId => $composableBuilder(
    column: $table.commandId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get commandRevision => $composableBuilder(
    column: $table.commandRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessOperationId => $composableBuilder(
    column: $table.businessOperationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get safeFailureCode => $composableBuilder(
    column: $table.safeFailureCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get claimedAt => $composableBuilder(
    column: $table.claimedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiAgentExecutionAttemptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiAgentExecutionAttemptsTable> {
  $$AiAgentExecutionAttemptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get commandId =>
      $composableBuilder(column: $table.commandId, builder: (column) => column);

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get commandRevision => $composableBuilder(
    column: $table.commandRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get businessOperationId => $composableBuilder(
    column: $table.businessOperationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get safeFailureCode => $composableBuilder(
    column: $table.safeFailureCode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get claimedAt =>
      $composableBuilder(column: $table.claimedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$AiAgentExecutionAttemptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiAgentExecutionAttemptsTable,
          AiAgentExecutionAttemptRow,
          $$AiAgentExecutionAttemptsTableFilterComposer,
          $$AiAgentExecutionAttemptsTableOrderingComposer,
          $$AiAgentExecutionAttemptsTableAnnotationComposer,
          $$AiAgentExecutionAttemptsTableCreateCompanionBuilder,
          $$AiAgentExecutionAttemptsTableUpdateCompanionBuilder,
          (
            AiAgentExecutionAttemptRow,
            BaseReferences<
              _$AppDatabase,
              $AiAgentExecutionAttemptsTable,
              AiAgentExecutionAttemptRow
            >,
          ),
          AiAgentExecutionAttemptRow,
          PrefetchHooks Function()
        > {
  $$AiAgentExecutionAttemptsTableTableManager(
    _$AppDatabase db,
    $AiAgentExecutionAttemptsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiAgentExecutionAttemptsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$AiAgentExecutionAttemptsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AiAgentExecutionAttemptsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> ownerScopeId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> commandId = const Value.absent(),
                Value<String> idempotencyKey = const Value.absent(),
                Value<int> commandRevision = const Value.absent(),
                Value<String> actionType = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> businessOperationId = const Value.absent(),
                Value<String?> safeFailureCode = const Value.absent(),
                Value<DateTime> claimedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiAgentExecutionAttemptsCompanion(
                ownerScopeId: ownerScopeId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                id: id,
                commandId: commandId,
                idempotencyKey: idempotencyKey,
                commandRevision: commandRevision,
                actionType: actionType,
                status: status,
                businessOperationId: businessOperationId,
                safeFailureCode: safeFailureCode,
                claimedAt: claimedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerScopeId,
                required DateTime createdAt,
                required DateTime updatedAt,
                required String id,
                required String commandId,
                required String idempotencyKey,
                required int commandRevision,
                required String actionType,
                required String status,
                Value<String?> businessOperationId = const Value.absent(),
                Value<String?> safeFailureCode = const Value.absent(),
                required DateTime claimedAt,
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiAgentExecutionAttemptsCompanion.insert(
                ownerScopeId: ownerScopeId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                id: id,
                commandId: commandId,
                idempotencyKey: idempotencyKey,
                commandRevision: commandRevision,
                actionType: actionType,
                status: status,
                businessOperationId: businessOperationId,
                safeFailureCode: safeFailureCode,
                claimedAt: claimedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiAgentExecutionAttemptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiAgentExecutionAttemptsTable,
      AiAgentExecutionAttemptRow,
      $$AiAgentExecutionAttemptsTableFilterComposer,
      $$AiAgentExecutionAttemptsTableOrderingComposer,
      $$AiAgentExecutionAttemptsTableAnnotationComposer,
      $$AiAgentExecutionAttemptsTableCreateCompanionBuilder,
      $$AiAgentExecutionAttemptsTableUpdateCompanionBuilder,
      (
        AiAgentExecutionAttemptRow,
        BaseReferences<
          _$AppDatabase,
          $AiAgentExecutionAttemptsTable,
          AiAgentExecutionAttemptRow
        >,
      ),
      AiAgentExecutionAttemptRow,
      PrefetchHooks Function()
    >;
typedef $$AiAgentExecutionResultsTableCreateCompanionBuilder =
    AiAgentExecutionResultsCompanion Function({
      required String ownerScopeId,
      required DateTime createdAt,
      required DateTime updatedAt,
      required String id,
      required String commandId,
      required String attemptId,
      required String status,
      required bool verified,
      required String entityType,
      required int affectedCount,
      required String safeResultJson,
      Value<String?> safeFailureCode,
      Value<int> rowid,
    });
typedef $$AiAgentExecutionResultsTableUpdateCompanionBuilder =
    AiAgentExecutionResultsCompanion Function({
      Value<String> ownerScopeId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String> id,
      Value<String> commandId,
      Value<String> attemptId,
      Value<String> status,
      Value<bool> verified,
      Value<String> entityType,
      Value<int> affectedCount,
      Value<String> safeResultJson,
      Value<String?> safeFailureCode,
      Value<int> rowid,
    });

class $$AiAgentExecutionResultsTableFilterComposer
    extends Composer<_$AppDatabase, $AiAgentExecutionResultsTable> {
  $$AiAgentExecutionResultsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commandId => $composableBuilder(
    column: $table.commandId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attemptId => $composableBuilder(
    column: $table.attemptId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get verified => $composableBuilder(
    column: $table.verified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get affectedCount => $composableBuilder(
    column: $table.affectedCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get safeResultJson => $composableBuilder(
    column: $table.safeResultJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get safeFailureCode => $composableBuilder(
    column: $table.safeFailureCode,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiAgentExecutionResultsTableOrderingComposer
    extends Composer<_$AppDatabase, $AiAgentExecutionResultsTable> {
  $$AiAgentExecutionResultsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commandId => $composableBuilder(
    column: $table.commandId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attemptId => $composableBuilder(
    column: $table.attemptId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get verified => $composableBuilder(
    column: $table.verified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get affectedCount => $composableBuilder(
    column: $table.affectedCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get safeResultJson => $composableBuilder(
    column: $table.safeResultJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get safeFailureCode => $composableBuilder(
    column: $table.safeFailureCode,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiAgentExecutionResultsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiAgentExecutionResultsTable> {
  $$AiAgentExecutionResultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get commandId =>
      $composableBuilder(column: $table.commandId, builder: (column) => column);

  GeneratedColumn<String> get attemptId =>
      $composableBuilder(column: $table.attemptId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get verified =>
      $composableBuilder(column: $table.verified, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get affectedCount => $composableBuilder(
    column: $table.affectedCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get safeResultJson => $composableBuilder(
    column: $table.safeResultJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get safeFailureCode => $composableBuilder(
    column: $table.safeFailureCode,
    builder: (column) => column,
  );
}

class $$AiAgentExecutionResultsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiAgentExecutionResultsTable,
          AiAgentExecutionResultRow,
          $$AiAgentExecutionResultsTableFilterComposer,
          $$AiAgentExecutionResultsTableOrderingComposer,
          $$AiAgentExecutionResultsTableAnnotationComposer,
          $$AiAgentExecutionResultsTableCreateCompanionBuilder,
          $$AiAgentExecutionResultsTableUpdateCompanionBuilder,
          (
            AiAgentExecutionResultRow,
            BaseReferences<
              _$AppDatabase,
              $AiAgentExecutionResultsTable,
              AiAgentExecutionResultRow
            >,
          ),
          AiAgentExecutionResultRow,
          PrefetchHooks Function()
        > {
  $$AiAgentExecutionResultsTableTableManager(
    _$AppDatabase db,
    $AiAgentExecutionResultsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiAgentExecutionResultsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$AiAgentExecutionResultsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AiAgentExecutionResultsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> ownerScopeId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> commandId = const Value.absent(),
                Value<String> attemptId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> verified = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<int> affectedCount = const Value.absent(),
                Value<String> safeResultJson = const Value.absent(),
                Value<String?> safeFailureCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiAgentExecutionResultsCompanion(
                ownerScopeId: ownerScopeId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                id: id,
                commandId: commandId,
                attemptId: attemptId,
                status: status,
                verified: verified,
                entityType: entityType,
                affectedCount: affectedCount,
                safeResultJson: safeResultJson,
                safeFailureCode: safeFailureCode,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerScopeId,
                required DateTime createdAt,
                required DateTime updatedAt,
                required String id,
                required String commandId,
                required String attemptId,
                required String status,
                required bool verified,
                required String entityType,
                required int affectedCount,
                required String safeResultJson,
                Value<String?> safeFailureCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiAgentExecutionResultsCompanion.insert(
                ownerScopeId: ownerScopeId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                id: id,
                commandId: commandId,
                attemptId: attemptId,
                status: status,
                verified: verified,
                entityType: entityType,
                affectedCount: affectedCount,
                safeResultJson: safeResultJson,
                safeFailureCode: safeFailureCode,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiAgentExecutionResultsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiAgentExecutionResultsTable,
      AiAgentExecutionResultRow,
      $$AiAgentExecutionResultsTableFilterComposer,
      $$AiAgentExecutionResultsTableOrderingComposer,
      $$AiAgentExecutionResultsTableAnnotationComposer,
      $$AiAgentExecutionResultsTableCreateCompanionBuilder,
      $$AiAgentExecutionResultsTableUpdateCompanionBuilder,
      (
        AiAgentExecutionResultRow,
        BaseReferences<
          _$AppDatabase,
          $AiAgentExecutionResultsTable,
          AiAgentExecutionResultRow
        >,
      ),
      AiAgentExecutionResultRow,
      PrefetchHooks Function()
    >;
typedef $$AiAgentPlansTableCreateCompanionBuilder =
    AiAgentPlansCompanion Function({
      required String ownerScopeId,
      required DateTime createdAt,
      required DateTime updatedAt,
      required String id,
      required String conversationId,
      required String status,
      Value<bool> atomic,
      required DateTime expiresAt,
      Value<int> rowid,
    });
typedef $$AiAgentPlansTableUpdateCompanionBuilder =
    AiAgentPlansCompanion Function({
      Value<String> ownerScopeId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String> id,
      Value<String> conversationId,
      Value<String> status,
      Value<bool> atomic,
      Value<DateTime> expiresAt,
      Value<int> rowid,
    });

class $$AiAgentPlansTableFilterComposer
    extends Composer<_$AppDatabase, $AiAgentPlansTable> {
  $$AiAgentPlansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get atomic => $composableBuilder(
    column: $table.atomic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiAgentPlansTableOrderingComposer
    extends Composer<_$AppDatabase, $AiAgentPlansTable> {
  $$AiAgentPlansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get atomic => $composableBuilder(
    column: $table.atomic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiAgentPlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiAgentPlansTable> {
  $$AiAgentPlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get atomic =>
      $composableBuilder(column: $table.atomic, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$AiAgentPlansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiAgentPlansTable,
          AiAgentPlanRow,
          $$AiAgentPlansTableFilterComposer,
          $$AiAgentPlansTableOrderingComposer,
          $$AiAgentPlansTableAnnotationComposer,
          $$AiAgentPlansTableCreateCompanionBuilder,
          $$AiAgentPlansTableUpdateCompanionBuilder,
          (
            AiAgentPlanRow,
            BaseReferences<_$AppDatabase, $AiAgentPlansTable, AiAgentPlanRow>,
          ),
          AiAgentPlanRow,
          PrefetchHooks Function()
        > {
  $$AiAgentPlansTableTableManager(_$AppDatabase db, $AiAgentPlansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiAgentPlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiAgentPlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiAgentPlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ownerScopeId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> atomic = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiAgentPlansCompanion(
                ownerScopeId: ownerScopeId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                id: id,
                conversationId: conversationId,
                status: status,
                atomic: atomic,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerScopeId,
                required DateTime createdAt,
                required DateTime updatedAt,
                required String id,
                required String conversationId,
                required String status,
                Value<bool> atomic = const Value.absent(),
                required DateTime expiresAt,
                Value<int> rowid = const Value.absent(),
              }) => AiAgentPlansCompanion.insert(
                ownerScopeId: ownerScopeId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                id: id,
                conversationId: conversationId,
                status: status,
                atomic: atomic,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiAgentPlansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiAgentPlansTable,
      AiAgentPlanRow,
      $$AiAgentPlansTableFilterComposer,
      $$AiAgentPlansTableOrderingComposer,
      $$AiAgentPlansTableAnnotationComposer,
      $$AiAgentPlansTableCreateCompanionBuilder,
      $$AiAgentPlansTableUpdateCompanionBuilder,
      (
        AiAgentPlanRow,
        BaseReferences<_$AppDatabase, $AiAgentPlansTable, AiAgentPlanRow>,
      ),
      AiAgentPlanRow,
      PrefetchHooks Function()
    >;
typedef $$AiAgentPlanStepsTableCreateCompanionBuilder =
    AiAgentPlanStepsCompanion Function({
      required String ownerScopeId,
      required DateTime createdAt,
      required DateTime updatedAt,
      required String id,
      required String planId,
      required String commandId,
      required int position,
      required String status,
      Value<int> rowid,
    });
typedef $$AiAgentPlanStepsTableUpdateCompanionBuilder =
    AiAgentPlanStepsCompanion Function({
      Value<String> ownerScopeId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String> id,
      Value<String> planId,
      Value<String> commandId,
      Value<int> position,
      Value<String> status,
      Value<int> rowid,
    });

class $$AiAgentPlanStepsTableFilterComposer
    extends Composer<_$AppDatabase, $AiAgentPlanStepsTable> {
  $$AiAgentPlanStepsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get planId => $composableBuilder(
    column: $table.planId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commandId => $composableBuilder(
    column: $table.commandId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiAgentPlanStepsTableOrderingComposer
    extends Composer<_$AppDatabase, $AiAgentPlanStepsTable> {
  $$AiAgentPlanStepsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get planId => $composableBuilder(
    column: $table.planId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commandId => $composableBuilder(
    column: $table.commandId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiAgentPlanStepsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiAgentPlanStepsTable> {
  $$AiAgentPlanStepsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get planId =>
      $composableBuilder(column: $table.planId, builder: (column) => column);

  GeneratedColumn<String> get commandId =>
      $composableBuilder(column: $table.commandId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$AiAgentPlanStepsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiAgentPlanStepsTable,
          AiAgentPlanStepRow,
          $$AiAgentPlanStepsTableFilterComposer,
          $$AiAgentPlanStepsTableOrderingComposer,
          $$AiAgentPlanStepsTableAnnotationComposer,
          $$AiAgentPlanStepsTableCreateCompanionBuilder,
          $$AiAgentPlanStepsTableUpdateCompanionBuilder,
          (
            AiAgentPlanStepRow,
            BaseReferences<
              _$AppDatabase,
              $AiAgentPlanStepsTable,
              AiAgentPlanStepRow
            >,
          ),
          AiAgentPlanStepRow,
          PrefetchHooks Function()
        > {
  $$AiAgentPlanStepsTableTableManager(
    _$AppDatabase db,
    $AiAgentPlanStepsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiAgentPlanStepsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiAgentPlanStepsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiAgentPlanStepsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ownerScopeId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> planId = const Value.absent(),
                Value<String> commandId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiAgentPlanStepsCompanion(
                ownerScopeId: ownerScopeId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                id: id,
                planId: planId,
                commandId: commandId,
                position: position,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerScopeId,
                required DateTime createdAt,
                required DateTime updatedAt,
                required String id,
                required String planId,
                required String commandId,
                required int position,
                required String status,
                Value<int> rowid = const Value.absent(),
              }) => AiAgentPlanStepsCompanion.insert(
                ownerScopeId: ownerScopeId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                id: id,
                planId: planId,
                commandId: commandId,
                position: position,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiAgentPlanStepsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiAgentPlanStepsTable,
      AiAgentPlanStepRow,
      $$AiAgentPlanStepsTableFilterComposer,
      $$AiAgentPlanStepsTableOrderingComposer,
      $$AiAgentPlanStepsTableAnnotationComposer,
      $$AiAgentPlanStepsTableCreateCompanionBuilder,
      $$AiAgentPlanStepsTableUpdateCompanionBuilder,
      (
        AiAgentPlanStepRow,
        BaseReferences<
          _$AppDatabase,
          $AiAgentPlanStepsTable,
          AiAgentPlanStepRow
        >,
      ),
      AiAgentPlanStepRow,
      PrefetchHooks Function()
    >;
typedef $$AiAgentAuditEventsTableCreateCompanionBuilder =
    AiAgentAuditEventsCompanion Function({
      required String ownerScopeId,
      required DateTime createdAt,
      required DateTime updatedAt,
      required String id,
      required String commandId,
      required String actionType,
      required String entityType,
      required String result,
      required String confirmationMethod,
      Value<String?> safeFailureCode,
      Value<bool> undoAvailable,
      Value<int> rowid,
    });
typedef $$AiAgentAuditEventsTableUpdateCompanionBuilder =
    AiAgentAuditEventsCompanion Function({
      Value<String> ownerScopeId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String> id,
      Value<String> commandId,
      Value<String> actionType,
      Value<String> entityType,
      Value<String> result,
      Value<String> confirmationMethod,
      Value<String?> safeFailureCode,
      Value<bool> undoAvailable,
      Value<int> rowid,
    });

class $$AiAgentAuditEventsTableFilterComposer
    extends Composer<_$AppDatabase, $AiAgentAuditEventsTable> {
  $$AiAgentAuditEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commandId => $composableBuilder(
    column: $table.commandId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get confirmationMethod => $composableBuilder(
    column: $table.confirmationMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get safeFailureCode => $composableBuilder(
    column: $table.safeFailureCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get undoAvailable => $composableBuilder(
    column: $table.undoAvailable,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiAgentAuditEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $AiAgentAuditEventsTable> {
  $$AiAgentAuditEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commandId => $composableBuilder(
    column: $table.commandId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get confirmationMethod => $composableBuilder(
    column: $table.confirmationMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get safeFailureCode => $composableBuilder(
    column: $table.safeFailureCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get undoAvailable => $composableBuilder(
    column: $table.undoAvailable,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiAgentAuditEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiAgentAuditEventsTable> {
  $$AiAgentAuditEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get commandId =>
      $composableBuilder(column: $table.commandId, builder: (column) => column);

  GeneratedColumn<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<String> get confirmationMethod => $composableBuilder(
    column: $table.confirmationMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get safeFailureCode => $composableBuilder(
    column: $table.safeFailureCode,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get undoAvailable => $composableBuilder(
    column: $table.undoAvailable,
    builder: (column) => column,
  );
}

class $$AiAgentAuditEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiAgentAuditEventsTable,
          AiAgentAuditEventRow,
          $$AiAgentAuditEventsTableFilterComposer,
          $$AiAgentAuditEventsTableOrderingComposer,
          $$AiAgentAuditEventsTableAnnotationComposer,
          $$AiAgentAuditEventsTableCreateCompanionBuilder,
          $$AiAgentAuditEventsTableUpdateCompanionBuilder,
          (
            AiAgentAuditEventRow,
            BaseReferences<
              _$AppDatabase,
              $AiAgentAuditEventsTable,
              AiAgentAuditEventRow
            >,
          ),
          AiAgentAuditEventRow,
          PrefetchHooks Function()
        > {
  $$AiAgentAuditEventsTableTableManager(
    _$AppDatabase db,
    $AiAgentAuditEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiAgentAuditEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiAgentAuditEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiAgentAuditEventsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> ownerScopeId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> commandId = const Value.absent(),
                Value<String> actionType = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> result = const Value.absent(),
                Value<String> confirmationMethod = const Value.absent(),
                Value<String?> safeFailureCode = const Value.absent(),
                Value<bool> undoAvailable = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiAgentAuditEventsCompanion(
                ownerScopeId: ownerScopeId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                id: id,
                commandId: commandId,
                actionType: actionType,
                entityType: entityType,
                result: result,
                confirmationMethod: confirmationMethod,
                safeFailureCode: safeFailureCode,
                undoAvailable: undoAvailable,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerScopeId,
                required DateTime createdAt,
                required DateTime updatedAt,
                required String id,
                required String commandId,
                required String actionType,
                required String entityType,
                required String result,
                required String confirmationMethod,
                Value<String?> safeFailureCode = const Value.absent(),
                Value<bool> undoAvailable = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiAgentAuditEventsCompanion.insert(
                ownerScopeId: ownerScopeId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                id: id,
                commandId: commandId,
                actionType: actionType,
                entityType: entityType,
                result: result,
                confirmationMethod: confirmationMethod,
                safeFailureCode: safeFailureCode,
                undoAvailable: undoAvailable,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiAgentAuditEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiAgentAuditEventsTable,
      AiAgentAuditEventRow,
      $$AiAgentAuditEventsTableFilterComposer,
      $$AiAgentAuditEventsTableOrderingComposer,
      $$AiAgentAuditEventsTableAnnotationComposer,
      $$AiAgentAuditEventsTableCreateCompanionBuilder,
      $$AiAgentAuditEventsTableUpdateCompanionBuilder,
      (
        AiAgentAuditEventRow,
        BaseReferences<
          _$AppDatabase,
          $AiAgentAuditEventsTable,
          AiAgentAuditEventRow
        >,
      ),
      AiAgentAuditEventRow,
      PrefetchHooks Function()
    >;
typedef $$AiAgentIdempotencyRecordsTableCreateCompanionBuilder =
    AiAgentIdempotencyRecordsCompanion Function({
      required String ownerScopeId,
      required DateTime createdAt,
      required DateTime updatedAt,
      required String id,
      required String commandId,
      required int commandRevision,
      required String actionType,
      required String idempotencyHash,
      required String status,
      Value<String?> executionResultId,
      Value<DateTime?> expiresAt,
      Value<int> rowid,
    });
typedef $$AiAgentIdempotencyRecordsTableUpdateCompanionBuilder =
    AiAgentIdempotencyRecordsCompanion Function({
      Value<String> ownerScopeId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String> id,
      Value<String> commandId,
      Value<int> commandRevision,
      Value<String> actionType,
      Value<String> idempotencyHash,
      Value<String> status,
      Value<String?> executionResultId,
      Value<DateTime?> expiresAt,
      Value<int> rowid,
    });

class $$AiAgentIdempotencyRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $AiAgentIdempotencyRecordsTable> {
  $$AiAgentIdempotencyRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commandId => $composableBuilder(
    column: $table.commandId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get commandRevision => $composableBuilder(
    column: $table.commandRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idempotencyHash => $composableBuilder(
    column: $table.idempotencyHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get executionResultId => $composableBuilder(
    column: $table.executionResultId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiAgentIdempotencyRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $AiAgentIdempotencyRecordsTable> {
  $$AiAgentIdempotencyRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commandId => $composableBuilder(
    column: $table.commandId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get commandRevision => $composableBuilder(
    column: $table.commandRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idempotencyHash => $composableBuilder(
    column: $table.idempotencyHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get executionResultId => $composableBuilder(
    column: $table.executionResultId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiAgentIdempotencyRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiAgentIdempotencyRecordsTable> {
  $$AiAgentIdempotencyRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get commandId =>
      $composableBuilder(column: $table.commandId, builder: (column) => column);

  GeneratedColumn<int> get commandRevision => $composableBuilder(
    column: $table.commandRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get idempotencyHash => $composableBuilder(
    column: $table.idempotencyHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get executionResultId => $composableBuilder(
    column: $table.executionResultId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$AiAgentIdempotencyRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiAgentIdempotencyRecordsTable,
          AiAgentIdempotencyRecordRow,
          $$AiAgentIdempotencyRecordsTableFilterComposer,
          $$AiAgentIdempotencyRecordsTableOrderingComposer,
          $$AiAgentIdempotencyRecordsTableAnnotationComposer,
          $$AiAgentIdempotencyRecordsTableCreateCompanionBuilder,
          $$AiAgentIdempotencyRecordsTableUpdateCompanionBuilder,
          (
            AiAgentIdempotencyRecordRow,
            BaseReferences<
              _$AppDatabase,
              $AiAgentIdempotencyRecordsTable,
              AiAgentIdempotencyRecordRow
            >,
          ),
          AiAgentIdempotencyRecordRow,
          PrefetchHooks Function()
        > {
  $$AiAgentIdempotencyRecordsTableTableManager(
    _$AppDatabase db,
    $AiAgentIdempotencyRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiAgentIdempotencyRecordsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$AiAgentIdempotencyRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AiAgentIdempotencyRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> ownerScopeId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> commandId = const Value.absent(),
                Value<int> commandRevision = const Value.absent(),
                Value<String> actionType = const Value.absent(),
                Value<String> idempotencyHash = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> executionResultId = const Value.absent(),
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiAgentIdempotencyRecordsCompanion(
                ownerScopeId: ownerScopeId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                id: id,
                commandId: commandId,
                commandRevision: commandRevision,
                actionType: actionType,
                idempotencyHash: idempotencyHash,
                status: status,
                executionResultId: executionResultId,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerScopeId,
                required DateTime createdAt,
                required DateTime updatedAt,
                required String id,
                required String commandId,
                required int commandRevision,
                required String actionType,
                required String idempotencyHash,
                required String status,
                Value<String?> executionResultId = const Value.absent(),
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiAgentIdempotencyRecordsCompanion.insert(
                ownerScopeId: ownerScopeId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                id: id,
                commandId: commandId,
                commandRevision: commandRevision,
                actionType: actionType,
                idempotencyHash: idempotencyHash,
                status: status,
                executionResultId: executionResultId,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiAgentIdempotencyRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiAgentIdempotencyRecordsTable,
      AiAgentIdempotencyRecordRow,
      $$AiAgentIdempotencyRecordsTableFilterComposer,
      $$AiAgentIdempotencyRecordsTableOrderingComposer,
      $$AiAgentIdempotencyRecordsTableAnnotationComposer,
      $$AiAgentIdempotencyRecordsTableCreateCompanionBuilder,
      $$AiAgentIdempotencyRecordsTableUpdateCompanionBuilder,
      (
        AiAgentIdempotencyRecordRow,
        BaseReferences<
          _$AppDatabase,
          $AiAgentIdempotencyRecordsTable,
          AiAgentIdempotencyRecordRow
        >,
      ),
      AiAgentIdempotencyRecordRow,
      PrefetchHooks Function()
    >;
typedef $$AiAgentBusinessOperationsTableCreateCompanionBuilder =
    AiAgentBusinessOperationsCompanion Function({
      required String ownerScopeId,
      required DateTime createdAt,
      required DateTime updatedAt,
      required String id,
      required String commandId,
      required int commandRevision,
      required String actionType,
      required String entityType,
      required String expectedEntityIdsJson,
      required String verificationMethod,
      required String status,
      required bool automaticResumeAllowed,
      required bool automaticRetryProhibited,
      Value<bool> uiDeliveryAcknowledged,
      Value<String?> safeFailureCode,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });
typedef $$AiAgentBusinessOperationsTableUpdateCompanionBuilder =
    AiAgentBusinessOperationsCompanion Function({
      Value<String> ownerScopeId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String> id,
      Value<String> commandId,
      Value<int> commandRevision,
      Value<String> actionType,
      Value<String> entityType,
      Value<String> expectedEntityIdsJson,
      Value<String> verificationMethod,
      Value<String> status,
      Value<bool> automaticResumeAllowed,
      Value<bool> automaticRetryProhibited,
      Value<bool> uiDeliveryAcknowledged,
      Value<String?> safeFailureCode,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });

class $$AiAgentBusinessOperationsTableFilterComposer
    extends Composer<_$AppDatabase, $AiAgentBusinessOperationsTable> {
  $$AiAgentBusinessOperationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commandId => $composableBuilder(
    column: $table.commandId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get commandRevision => $composableBuilder(
    column: $table.commandRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expectedEntityIdsJson => $composableBuilder(
    column: $table.expectedEntityIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get verificationMethod => $composableBuilder(
    column: $table.verificationMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get automaticResumeAllowed => $composableBuilder(
    column: $table.automaticResumeAllowed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get automaticRetryProhibited => $composableBuilder(
    column: $table.automaticRetryProhibited,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get uiDeliveryAcknowledged => $composableBuilder(
    column: $table.uiDeliveryAcknowledged,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get safeFailureCode => $composableBuilder(
    column: $table.safeFailureCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiAgentBusinessOperationsTableOrderingComposer
    extends Composer<_$AppDatabase, $AiAgentBusinessOperationsTable> {
  $$AiAgentBusinessOperationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commandId => $composableBuilder(
    column: $table.commandId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get commandRevision => $composableBuilder(
    column: $table.commandRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expectedEntityIdsJson => $composableBuilder(
    column: $table.expectedEntityIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get verificationMethod => $composableBuilder(
    column: $table.verificationMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get automaticResumeAllowed => $composableBuilder(
    column: $table.automaticResumeAllowed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get automaticRetryProhibited => $composableBuilder(
    column: $table.automaticRetryProhibited,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get uiDeliveryAcknowledged => $composableBuilder(
    column: $table.uiDeliveryAcknowledged,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get safeFailureCode => $composableBuilder(
    column: $table.safeFailureCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiAgentBusinessOperationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiAgentBusinessOperationsTable> {
  $$AiAgentBusinessOperationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get commandId =>
      $composableBuilder(column: $table.commandId, builder: (column) => column);

  GeneratedColumn<int> get commandRevision => $composableBuilder(
    column: $table.commandRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get expectedEntityIdsJson => $composableBuilder(
    column: $table.expectedEntityIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get verificationMethod => $composableBuilder(
    column: $table.verificationMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get automaticResumeAllowed => $composableBuilder(
    column: $table.automaticResumeAllowed,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get automaticRetryProhibited => $composableBuilder(
    column: $table.automaticRetryProhibited,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get uiDeliveryAcknowledged => $composableBuilder(
    column: $table.uiDeliveryAcknowledged,
    builder: (column) => column,
  );

  GeneratedColumn<String> get safeFailureCode => $composableBuilder(
    column: $table.safeFailureCode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$AiAgentBusinessOperationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiAgentBusinessOperationsTable,
          AiAgentBusinessOperationRow,
          $$AiAgentBusinessOperationsTableFilterComposer,
          $$AiAgentBusinessOperationsTableOrderingComposer,
          $$AiAgentBusinessOperationsTableAnnotationComposer,
          $$AiAgentBusinessOperationsTableCreateCompanionBuilder,
          $$AiAgentBusinessOperationsTableUpdateCompanionBuilder,
          (
            AiAgentBusinessOperationRow,
            BaseReferences<
              _$AppDatabase,
              $AiAgentBusinessOperationsTable,
              AiAgentBusinessOperationRow
            >,
          ),
          AiAgentBusinessOperationRow,
          PrefetchHooks Function()
        > {
  $$AiAgentBusinessOperationsTableTableManager(
    _$AppDatabase db,
    $AiAgentBusinessOperationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiAgentBusinessOperationsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$AiAgentBusinessOperationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AiAgentBusinessOperationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> ownerScopeId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> commandId = const Value.absent(),
                Value<int> commandRevision = const Value.absent(),
                Value<String> actionType = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> expectedEntityIdsJson = const Value.absent(),
                Value<String> verificationMethod = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> automaticResumeAllowed = const Value.absent(),
                Value<bool> automaticRetryProhibited = const Value.absent(),
                Value<bool> uiDeliveryAcknowledged = const Value.absent(),
                Value<String?> safeFailureCode = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiAgentBusinessOperationsCompanion(
                ownerScopeId: ownerScopeId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                id: id,
                commandId: commandId,
                commandRevision: commandRevision,
                actionType: actionType,
                entityType: entityType,
                expectedEntityIdsJson: expectedEntityIdsJson,
                verificationMethod: verificationMethod,
                status: status,
                automaticResumeAllowed: automaticResumeAllowed,
                automaticRetryProhibited: automaticRetryProhibited,
                uiDeliveryAcknowledged: uiDeliveryAcknowledged,
                safeFailureCode: safeFailureCode,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerScopeId,
                required DateTime createdAt,
                required DateTime updatedAt,
                required String id,
                required String commandId,
                required int commandRevision,
                required String actionType,
                required String entityType,
                required String expectedEntityIdsJson,
                required String verificationMethod,
                required String status,
                required bool automaticResumeAllowed,
                required bool automaticRetryProhibited,
                Value<bool> uiDeliveryAcknowledged = const Value.absent(),
                Value<String?> safeFailureCode = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiAgentBusinessOperationsCompanion.insert(
                ownerScopeId: ownerScopeId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                id: id,
                commandId: commandId,
                commandRevision: commandRevision,
                actionType: actionType,
                entityType: entityType,
                expectedEntityIdsJson: expectedEntityIdsJson,
                verificationMethod: verificationMethod,
                status: status,
                automaticResumeAllowed: automaticResumeAllowed,
                automaticRetryProhibited: automaticRetryProhibited,
                uiDeliveryAcknowledged: uiDeliveryAcknowledged,
                safeFailureCode: safeFailureCode,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiAgentBusinessOperationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiAgentBusinessOperationsTable,
      AiAgentBusinessOperationRow,
      $$AiAgentBusinessOperationsTableFilterComposer,
      $$AiAgentBusinessOperationsTableOrderingComposer,
      $$AiAgentBusinessOperationsTableAnnotationComposer,
      $$AiAgentBusinessOperationsTableCreateCompanionBuilder,
      $$AiAgentBusinessOperationsTableUpdateCompanionBuilder,
      (
        AiAgentBusinessOperationRow,
        BaseReferences<
          _$AppDatabase,
          $AiAgentBusinessOperationsTable,
          AiAgentBusinessOperationRow
        >,
      ),
      AiAgentBusinessOperationRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$PayeesTableTableManager get payees =>
      $$PayeesTableTableManager(_db, _db.payees);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$ExchangeRatesTableTableManager get exchangeRates =>
      $$ExchangeRatesTableTableManager(_db, _db.exchangeRates);
  $$BudgetsTableTableManager get budgets =>
      $$BudgetsTableTableManager(_db, _db.budgets);
  $$GoalsTableTableManager get goals =>
      $$GoalsTableTableManager(_db, _db.goals);
  $$GoalContributionsTableTableManager get goalContributions =>
      $$GoalContributionsTableTableManager(_db, _db.goalContributions);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db, _db.syncQueue);
  $$ReceiptsTableTableManager get receipts =>
      $$ReceiptsTableTableManager(_db, _db.receipts);
  $$ReceiptLineItemsTableTableManager get receiptLineItems =>
      $$ReceiptLineItemsTableTableManager(_db, _db.receiptLineItems);
  $$TransactionSplitsTableTableManager get transactionSplits =>
      $$TransactionSplitsTableTableManager(_db, _db.transactionSplits);
  $$OwnerScopeMigrationAuditsTableTableManager get ownerScopeMigrationAudits =>
      $$OwnerScopeMigrationAuditsTableTableManager(
        _db,
        _db.ownerScopeMigrationAudits,
      );
  $$AiAgentCommandsTableTableManager get aiAgentCommands =>
      $$AiAgentCommandsTableTableManager(_db, _db.aiAgentCommands);
  $$AiAgentPreviewsTableTableManager get aiAgentPreviews =>
      $$AiAgentPreviewsTableTableManager(_db, _db.aiAgentPreviews);
  $$AiAgentConfirmationProofsTableTableManager get aiAgentConfirmationProofs =>
      $$AiAgentConfirmationProofsTableTableManager(
        _db,
        _db.aiAgentConfirmationProofs,
      );
  $$AiAgentExecutionAttemptsTableTableManager get aiAgentExecutionAttempts =>
      $$AiAgentExecutionAttemptsTableTableManager(
        _db,
        _db.aiAgentExecutionAttempts,
      );
  $$AiAgentExecutionResultsTableTableManager get aiAgentExecutionResults =>
      $$AiAgentExecutionResultsTableTableManager(
        _db,
        _db.aiAgentExecutionResults,
      );
  $$AiAgentPlansTableTableManager get aiAgentPlans =>
      $$AiAgentPlansTableTableManager(_db, _db.aiAgentPlans);
  $$AiAgentPlanStepsTableTableManager get aiAgentPlanSteps =>
      $$AiAgentPlanStepsTableTableManager(_db, _db.aiAgentPlanSteps);
  $$AiAgentAuditEventsTableTableManager get aiAgentAuditEvents =>
      $$AiAgentAuditEventsTableTableManager(_db, _db.aiAgentAuditEvents);
  $$AiAgentIdempotencyRecordsTableTableManager get aiAgentIdempotencyRecords =>
      $$AiAgentIdempotencyRecordsTableTableManager(
        _db,
        _db.aiAgentIdempotencyRecords,
      );
  $$AiAgentBusinessOperationsTableTableManager get aiAgentBusinessOperations =>
      $$AiAgentBusinessOperationsTableTableManager(
        _db,
        _db.aiAgentBusinessOperations,
      );
}
