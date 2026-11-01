// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'case_db.dart';

// ignore_for_file: type=lint
class $DimAgencyTable extends DimAgency
    with TableInfo<$DimAgencyTable, DimAgencyData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DimAgencyTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dim_agency';
  @override
  VerificationContext validateIntegrity(
    Insertable<DimAgencyData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DimAgencyData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DimAgencyData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $DimAgencyTable createAlias(String alias) {
    return $DimAgencyTable(attachedDatabase, alias);
  }
}

class DimAgencyData extends DataClass implements Insertable<DimAgencyData> {
  final int id;
  final String name;
  const DimAgencyData({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  DimAgencyCompanion toCompanion(bool nullToAbsent) {
    return DimAgencyCompanion(id: Value(id), name: Value(name));
  }

  factory DimAgencyData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DimAgencyData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  DimAgencyData copyWith({int? id, String? name}) =>
      DimAgencyData(id: id ?? this.id, name: name ?? this.name);
  DimAgencyData copyWithCompanion(DimAgencyCompanion data) {
    return DimAgencyData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DimAgencyData(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DimAgencyData &&
          other.id == this.id &&
          other.name == this.name);
}

class DimAgencyCompanion extends UpdateCompanion<DimAgencyData> {
  final Value<int> id;
  final Value<String> name;
  const DimAgencyCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
  });
  DimAgencyCompanion.insert({
    this.id = const Value.absent(),
    required String name,
  }) : name = Value(name);
  static Insertable<DimAgencyData> custom({
    Expression<int>? id,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
    });
  }

  DimAgencyCompanion copyWith({Value<int>? id, Value<String>? name}) {
    return DimAgencyCompanion(id: id ?? this.id, name: name ?? this.name);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DimAgencyCompanion(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

class $DimVendorTable extends DimVendor
    with TableInfo<$DimVendorTable, DimVendorData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DimVendorTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _taxIdMeta = const VerificationMeta('taxId');
  @override
  late final GeneratedColumn<String> taxId = GeneratedColumn<String>(
    'tax_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, taxId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dim_vendor';
  @override
  VerificationContext validateIntegrity(
    Insertable<DimVendorData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('tax_id')) {
      context.handle(
        _taxIdMeta,
        taxId.isAcceptableOrUnknown(data['tax_id']!, _taxIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DimVendorData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DimVendorData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      taxId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tax_id'],
      ),
    );
  }

  @override
  $DimVendorTable createAlias(String alias) {
    return $DimVendorTable(attachedDatabase, alias);
  }
}

class DimVendorData extends DataClass implements Insertable<DimVendorData> {
  final int id;
  final String name;
  final String? taxId;
  const DimVendorData({required this.id, required this.name, this.taxId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || taxId != null) {
      map['tax_id'] = Variable<String>(taxId);
    }
    return map;
  }

  DimVendorCompanion toCompanion(bool nullToAbsent) {
    return DimVendorCompanion(
      id: Value(id),
      name: Value(name),
      taxId: taxId == null && nullToAbsent
          ? const Value.absent()
          : Value(taxId),
    );
  }

  factory DimVendorData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DimVendorData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      taxId: serializer.fromJson<String?>(json['taxId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'taxId': serializer.toJson<String?>(taxId),
    };
  }

  DimVendorData copyWith({
    int? id,
    String? name,
    Value<String?> taxId = const Value.absent(),
  }) => DimVendorData(
    id: id ?? this.id,
    name: name ?? this.name,
    taxId: taxId.present ? taxId.value : this.taxId,
  );
  DimVendorData copyWithCompanion(DimVendorCompanion data) {
    return DimVendorData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      taxId: data.taxId.present ? data.taxId.value : this.taxId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DimVendorData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('taxId: $taxId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, taxId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DimVendorData &&
          other.id == this.id &&
          other.name == this.name &&
          other.taxId == this.taxId);
}

class DimVendorCompanion extends UpdateCompanion<DimVendorData> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> taxId;
  const DimVendorCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.taxId = const Value.absent(),
  });
  DimVendorCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.taxId = const Value.absent(),
  }) : name = Value(name);
  static Insertable<DimVendorData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? taxId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (taxId != null) 'tax_id': taxId,
    });
  }

  DimVendorCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? taxId,
  }) {
    return DimVendorCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      taxId: taxId ?? this.taxId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (taxId.present) {
      map['tax_id'] = Variable<String>(taxId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DimVendorCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('taxId: $taxId')
          ..write(')'))
        .toString();
  }
}

class $DimReviewerTable extends DimReviewer
    with TableInfo<$DimReviewerTable, DimReviewerData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DimReviewerTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
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
  static const VerificationMeta _jobMeta = const VerificationMeta('job');
  @override
  late final GeneratedColumn<String> job = GeneratedColumn<String>(
    'job',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, job];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dim_reviewer';
  @override
  VerificationContext validateIntegrity(
    Insertable<DimReviewerData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('job')) {
      context.handle(
        _jobMeta,
        job.isAcceptableOrUnknown(data['job']!, _jobMeta),
      );
    } else if (isInserting) {
      context.missing(_jobMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {name, job},
  ];
  @override
  DimReviewerData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DimReviewerData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      job: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}job'],
      )!,
    );
  }

  @override
  $DimReviewerTable createAlias(String alias) {
    return $DimReviewerTable(attachedDatabase, alias);
  }
}

class DimReviewerData extends DataClass implements Insertable<DimReviewerData> {
  final int id;
  final String name;
  final String job;
  const DimReviewerData({
    required this.id,
    required this.name,
    required this.job,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['job'] = Variable<String>(job);
    return map;
  }

  DimReviewerCompanion toCompanion(bool nullToAbsent) {
    return DimReviewerCompanion(
      id: Value(id),
      name: Value(name),
      job: Value(job),
    );
  }

  factory DimReviewerData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DimReviewerData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      job: serializer.fromJson<String>(json['job']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'job': serializer.toJson<String>(job),
    };
  }

  DimReviewerData copyWith({int? id, String? name, String? job}) =>
      DimReviewerData(
        id: id ?? this.id,
        name: name ?? this.name,
        job: job ?? this.job,
      );
  DimReviewerData copyWithCompanion(DimReviewerCompanion data) {
    return DimReviewerData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      job: data.job.present ? data.job.value : this.job,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DimReviewerData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('job: $job')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, job);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DimReviewerData &&
          other.id == this.id &&
          other.name == this.name &&
          other.job == this.job);
}

class DimReviewerCompanion extends UpdateCompanion<DimReviewerData> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> job;
  const DimReviewerCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.job = const Value.absent(),
  });
  DimReviewerCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String job,
  }) : name = Value(name),
       job = Value(job);
  static Insertable<DimReviewerData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? job,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (job != null) 'job': job,
    });
  }

  DimReviewerCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? job,
  }) {
    return DimReviewerCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      job: job ?? this.job,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (job.present) {
      map['job'] = Variable<String>(job.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DimReviewerCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('job: $job')
          ..write(')'))
        .toString();
  }
}

class $FactAwardTable extends FactAward
    with TableInfo<$FactAwardTable, FactAwardData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FactAwardTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _caseKeyMeta = const VerificationMeta(
    'caseKey',
  );
  @override
  late final GeneratedColumn<String> caseKey = GeneratedColumn<String>(
    'case_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _caseNoMeta = const VerificationMeta('caseNo');
  @override
  late final GeneratedColumn<String> caseNo = GeneratedColumn<String>(
    'case_no',
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _agencyIdMeta = const VerificationMeta(
    'agencyId',
  );
  @override
  late final GeneratedColumn<int> agencyId = GeneratedColumn<int>(
    'agency_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES dim_agency (id)',
    ),
  );
  static const VerificationMeta _winnerIdMeta = const VerificationMeta(
    'winnerId',
  );
  @override
  late final GeneratedColumn<int> winnerId = GeneratedColumn<int>(
    'winner_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES dim_vendor (id)',
    ),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _tenderMethodMeta = const VerificationMeta(
    'tenderMethod',
  );
  @override
  late final GeneratedColumn<String> tenderMethod = GeneratedColumn<String>(
    'tender_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _awardWayMeta = const VerificationMeta(
    'awardWay',
  );
  @override
  late final GeneratedColumn<String> awardWay = GeneratedColumn<String>(
    'award_way',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _budgetMeta = const VerificationMeta('budget');
  @override
  late final GeneratedColumn<double> budget = GeneratedColumn<double>(
    'budget',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _floorPriceMeta = const VerificationMeta(
    'floorPrice',
  );
  @override
  late final GeneratedColumn<double> floorPrice = GeneratedColumn<double>(
    'floor_price',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bidderCountMeta = const VerificationMeta(
    'bidderCount',
  );
  @override
  late final GeneratedColumn<int> bidderCount = GeneratedColumn<int>(
    'bidder_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noticeDateMeta = const VerificationMeta(
    'noticeDate',
  );
  @override
  late final GeneratedColumn<DateTime> noticeDate = GeneratedColumn<DateTime>(
    'notice_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _awardDateMeta = const VerificationMeta(
    'awardDate',
  );
  @override
  late final GeneratedColumn<DateTime> awardDate = GeneratedColumn<DateTime>(
    'award_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
  static const VerificationMeta _hasDetailMeta = const VerificationMeta(
    'hasDetail',
  );
  @override
  late final GeneratedColumn<bool> hasDetail = GeneratedColumn<bool>(
    'has_detail',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_detail" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  static const VerificationMeta _countryMeta = const VerificationMeta(
    'country',
  );
  @override
  late final GeneratedColumn<String> country = GeneratedColumn<String>(
    'country',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('tw'),
  );
  static const VerificationMeta _searchMeta = const VerificationMeta('search');
  @override
  late final GeneratedColumn<String> search = GeneratedColumn<String>(
    'search',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    caseKey,
    caseNo,
    name,
    agencyId,
    winnerId,
    category,
    tenderMethod,
    awardWay,
    amount,
    budget,
    floorPrice,
    bidderCount,
    noticeDate,
    awardDate,
    url,
    source,
    hasDetail,
    updatedAt,
    country,
    search,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fact_award';
  @override
  VerificationContext validateIntegrity(
    Insertable<FactAwardData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('case_key')) {
      context.handle(
        _caseKeyMeta,
        caseKey.isAcceptableOrUnknown(data['case_key']!, _caseKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_caseKeyMeta);
    }
    if (data.containsKey('case_no')) {
      context.handle(
        _caseNoMeta,
        caseNo.isAcceptableOrUnknown(data['case_no']!, _caseNoMeta),
      );
    } else if (isInserting) {
      context.missing(_caseNoMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('agency_id')) {
      context.handle(
        _agencyIdMeta,
        agencyId.isAcceptableOrUnknown(data['agency_id']!, _agencyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_agencyIdMeta);
    }
    if (data.containsKey('winner_id')) {
      context.handle(
        _winnerIdMeta,
        winnerId.isAcceptableOrUnknown(data['winner_id']!, _winnerIdMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('tender_method')) {
      context.handle(
        _tenderMethodMeta,
        tenderMethod.isAcceptableOrUnknown(
          data['tender_method']!,
          _tenderMethodMeta,
        ),
      );
    }
    if (data.containsKey('award_way')) {
      context.handle(
        _awardWayMeta,
        awardWay.isAcceptableOrUnknown(data['award_way']!, _awardWayMeta),
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
    if (data.containsKey('budget')) {
      context.handle(
        _budgetMeta,
        budget.isAcceptableOrUnknown(data['budget']!, _budgetMeta),
      );
    }
    if (data.containsKey('floor_price')) {
      context.handle(
        _floorPriceMeta,
        floorPrice.isAcceptableOrUnknown(data['floor_price']!, _floorPriceMeta),
      );
    }
    if (data.containsKey('bidder_count')) {
      context.handle(
        _bidderCountMeta,
        bidderCount.isAcceptableOrUnknown(
          data['bidder_count']!,
          _bidderCountMeta,
        ),
      );
    }
    if (data.containsKey('notice_date')) {
      context.handle(
        _noticeDateMeta,
        noticeDate.isAcceptableOrUnknown(data['notice_date']!, _noticeDateMeta),
      );
    }
    if (data.containsKey('award_date')) {
      context.handle(
        _awardDateMeta,
        awardDate.isAcceptableOrUnknown(data['award_date']!, _awardDateMeta),
      );
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('has_detail')) {
      context.handle(
        _hasDetailMeta,
        hasDetail.isAcceptableOrUnknown(data['has_detail']!, _hasDetailMeta),
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
    if (data.containsKey('country')) {
      context.handle(
        _countryMeta,
        country.isAcceptableOrUnknown(data['country']!, _countryMeta),
      );
    }
    if (data.containsKey('search')) {
      context.handle(
        _searchMeta,
        search.isAcceptableOrUnknown(data['search']!, _searchMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {caseKey};
  @override
  FactAwardData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FactAwardData(
      caseKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}case_key'],
      )!,
      caseNo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}case_no'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      agencyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}agency_id'],
      )!,
      winnerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}winner_id'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      tenderMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tender_method'],
      )!,
      awardWay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}award_way'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      budget: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}budget'],
      ),
      floorPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}floor_price'],
      ),
      bidderCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bidder_count'],
      ),
      noticeDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}notice_date'],
      ),
      awardDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}award_date'],
      ),
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      hasDetail: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_detail'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      country: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}country'],
      )!,
      search: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search'],
      ),
    );
  }

  @override
  $FactAwardTable createAlias(String alias) {
    return $FactAwardTable(attachedDatabase, alias);
  }
}

class FactAwardData extends DataClass implements Insertable<FactAwardData> {
  final String caseKey;
  final String caseNo;
  final String name;
  final int agencyId;
  final int? winnerId;
  final String category;
  final String tenderMethod;
  final String awardWay;
  final double amount;
  final double? budget;
  final double? floorPrice;
  final int? bidderCount;
  final DateTime? noticeDate;
  final DateTime? awardDate;
  final String url;
  final String source;
  final bool hasDetail;
  final DateTime updatedAt;
  final String country;
  final String? search;
  const FactAwardData({
    required this.caseKey,
    required this.caseNo,
    required this.name,
    required this.agencyId,
    this.winnerId,
    required this.category,
    required this.tenderMethod,
    required this.awardWay,
    required this.amount,
    this.budget,
    this.floorPrice,
    this.bidderCount,
    this.noticeDate,
    this.awardDate,
    required this.url,
    required this.source,
    required this.hasDetail,
    required this.updatedAt,
    required this.country,
    this.search,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['case_key'] = Variable<String>(caseKey);
    map['case_no'] = Variable<String>(caseNo);
    map['name'] = Variable<String>(name);
    map['agency_id'] = Variable<int>(agencyId);
    if (!nullToAbsent || winnerId != null) {
      map['winner_id'] = Variable<int>(winnerId);
    }
    map['category'] = Variable<String>(category);
    map['tender_method'] = Variable<String>(tenderMethod);
    map['award_way'] = Variable<String>(awardWay);
    map['amount'] = Variable<double>(amount);
    if (!nullToAbsent || budget != null) {
      map['budget'] = Variable<double>(budget);
    }
    if (!nullToAbsent || floorPrice != null) {
      map['floor_price'] = Variable<double>(floorPrice);
    }
    if (!nullToAbsent || bidderCount != null) {
      map['bidder_count'] = Variable<int>(bidderCount);
    }
    if (!nullToAbsent || noticeDate != null) {
      map['notice_date'] = Variable<DateTime>(noticeDate);
    }
    if (!nullToAbsent || awardDate != null) {
      map['award_date'] = Variable<DateTime>(awardDate);
    }
    map['url'] = Variable<String>(url);
    map['source'] = Variable<String>(source);
    map['has_detail'] = Variable<bool>(hasDetail);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['country'] = Variable<String>(country);
    if (!nullToAbsent || search != null) {
      map['search'] = Variable<String>(search);
    }
    return map;
  }

  FactAwardCompanion toCompanion(bool nullToAbsent) {
    return FactAwardCompanion(
      caseKey: Value(caseKey),
      caseNo: Value(caseNo),
      name: Value(name),
      agencyId: Value(agencyId),
      winnerId: winnerId == null && nullToAbsent
          ? const Value.absent()
          : Value(winnerId),
      category: Value(category),
      tenderMethod: Value(tenderMethod),
      awardWay: Value(awardWay),
      amount: Value(amount),
      budget: budget == null && nullToAbsent
          ? const Value.absent()
          : Value(budget),
      floorPrice: floorPrice == null && nullToAbsent
          ? const Value.absent()
          : Value(floorPrice),
      bidderCount: bidderCount == null && nullToAbsent
          ? const Value.absent()
          : Value(bidderCount),
      noticeDate: noticeDate == null && nullToAbsent
          ? const Value.absent()
          : Value(noticeDate),
      awardDate: awardDate == null && nullToAbsent
          ? const Value.absent()
          : Value(awardDate),
      url: Value(url),
      source: Value(source),
      hasDetail: Value(hasDetail),
      updatedAt: Value(updatedAt),
      country: Value(country),
      search: search == null && nullToAbsent
          ? const Value.absent()
          : Value(search),
    );
  }

  factory FactAwardData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FactAwardData(
      caseKey: serializer.fromJson<String>(json['caseKey']),
      caseNo: serializer.fromJson<String>(json['caseNo']),
      name: serializer.fromJson<String>(json['name']),
      agencyId: serializer.fromJson<int>(json['agencyId']),
      winnerId: serializer.fromJson<int?>(json['winnerId']),
      category: serializer.fromJson<String>(json['category']),
      tenderMethod: serializer.fromJson<String>(json['tenderMethod']),
      awardWay: serializer.fromJson<String>(json['awardWay']),
      amount: serializer.fromJson<double>(json['amount']),
      budget: serializer.fromJson<double?>(json['budget']),
      floorPrice: serializer.fromJson<double?>(json['floorPrice']),
      bidderCount: serializer.fromJson<int?>(json['bidderCount']),
      noticeDate: serializer.fromJson<DateTime?>(json['noticeDate']),
      awardDate: serializer.fromJson<DateTime?>(json['awardDate']),
      url: serializer.fromJson<String>(json['url']),
      source: serializer.fromJson<String>(json['source']),
      hasDetail: serializer.fromJson<bool>(json['hasDetail']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      country: serializer.fromJson<String>(json['country']),
      search: serializer.fromJson<String?>(json['search']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'caseKey': serializer.toJson<String>(caseKey),
      'caseNo': serializer.toJson<String>(caseNo),
      'name': serializer.toJson<String>(name),
      'agencyId': serializer.toJson<int>(agencyId),
      'winnerId': serializer.toJson<int?>(winnerId),
      'category': serializer.toJson<String>(category),
      'tenderMethod': serializer.toJson<String>(tenderMethod),
      'awardWay': serializer.toJson<String>(awardWay),
      'amount': serializer.toJson<double>(amount),
      'budget': serializer.toJson<double?>(budget),
      'floorPrice': serializer.toJson<double?>(floorPrice),
      'bidderCount': serializer.toJson<int?>(bidderCount),
      'noticeDate': serializer.toJson<DateTime?>(noticeDate),
      'awardDate': serializer.toJson<DateTime?>(awardDate),
      'url': serializer.toJson<String>(url),
      'source': serializer.toJson<String>(source),
      'hasDetail': serializer.toJson<bool>(hasDetail),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'country': serializer.toJson<String>(country),
      'search': serializer.toJson<String?>(search),
    };
  }

  FactAwardData copyWith({
    String? caseKey,
    String? caseNo,
    String? name,
    int? agencyId,
    Value<int?> winnerId = const Value.absent(),
    String? category,
    String? tenderMethod,
    String? awardWay,
    double? amount,
    Value<double?> budget = const Value.absent(),
    Value<double?> floorPrice = const Value.absent(),
    Value<int?> bidderCount = const Value.absent(),
    Value<DateTime?> noticeDate = const Value.absent(),
    Value<DateTime?> awardDate = const Value.absent(),
    String? url,
    String? source,
    bool? hasDetail,
    DateTime? updatedAt,
    String? country,
    Value<String?> search = const Value.absent(),
  }) => FactAwardData(
    caseKey: caseKey ?? this.caseKey,
    caseNo: caseNo ?? this.caseNo,
    name: name ?? this.name,
    agencyId: agencyId ?? this.agencyId,
    winnerId: winnerId.present ? winnerId.value : this.winnerId,
    category: category ?? this.category,
    tenderMethod: tenderMethod ?? this.tenderMethod,
    awardWay: awardWay ?? this.awardWay,
    amount: amount ?? this.amount,
    budget: budget.present ? budget.value : this.budget,
    floorPrice: floorPrice.present ? floorPrice.value : this.floorPrice,
    bidderCount: bidderCount.present ? bidderCount.value : this.bidderCount,
    noticeDate: noticeDate.present ? noticeDate.value : this.noticeDate,
    awardDate: awardDate.present ? awardDate.value : this.awardDate,
    url: url ?? this.url,
    source: source ?? this.source,
    hasDetail: hasDetail ?? this.hasDetail,
    updatedAt: updatedAt ?? this.updatedAt,
    country: country ?? this.country,
    search: search.present ? search.value : this.search,
  );
  FactAwardData copyWithCompanion(FactAwardCompanion data) {
    return FactAwardData(
      caseKey: data.caseKey.present ? data.caseKey.value : this.caseKey,
      caseNo: data.caseNo.present ? data.caseNo.value : this.caseNo,
      name: data.name.present ? data.name.value : this.name,
      agencyId: data.agencyId.present ? data.agencyId.value : this.agencyId,
      winnerId: data.winnerId.present ? data.winnerId.value : this.winnerId,
      category: data.category.present ? data.category.value : this.category,
      tenderMethod: data.tenderMethod.present
          ? data.tenderMethod.value
          : this.tenderMethod,
      awardWay: data.awardWay.present ? data.awardWay.value : this.awardWay,
      amount: data.amount.present ? data.amount.value : this.amount,
      budget: data.budget.present ? data.budget.value : this.budget,
      floorPrice: data.floorPrice.present
          ? data.floorPrice.value
          : this.floorPrice,
      bidderCount: data.bidderCount.present
          ? data.bidderCount.value
          : this.bidderCount,
      noticeDate: data.noticeDate.present
          ? data.noticeDate.value
          : this.noticeDate,
      awardDate: data.awardDate.present ? data.awardDate.value : this.awardDate,
      url: data.url.present ? data.url.value : this.url,
      source: data.source.present ? data.source.value : this.source,
      hasDetail: data.hasDetail.present ? data.hasDetail.value : this.hasDetail,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      country: data.country.present ? data.country.value : this.country,
      search: data.search.present ? data.search.value : this.search,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FactAwardData(')
          ..write('caseKey: $caseKey, ')
          ..write('caseNo: $caseNo, ')
          ..write('name: $name, ')
          ..write('agencyId: $agencyId, ')
          ..write('winnerId: $winnerId, ')
          ..write('category: $category, ')
          ..write('tenderMethod: $tenderMethod, ')
          ..write('awardWay: $awardWay, ')
          ..write('amount: $amount, ')
          ..write('budget: $budget, ')
          ..write('floorPrice: $floorPrice, ')
          ..write('bidderCount: $bidderCount, ')
          ..write('noticeDate: $noticeDate, ')
          ..write('awardDate: $awardDate, ')
          ..write('url: $url, ')
          ..write('source: $source, ')
          ..write('hasDetail: $hasDetail, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('country: $country, ')
          ..write('search: $search')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    caseKey,
    caseNo,
    name,
    agencyId,
    winnerId,
    category,
    tenderMethod,
    awardWay,
    amount,
    budget,
    floorPrice,
    bidderCount,
    noticeDate,
    awardDate,
    url,
    source,
    hasDetail,
    updatedAt,
    country,
    search,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FactAwardData &&
          other.caseKey == this.caseKey &&
          other.caseNo == this.caseNo &&
          other.name == this.name &&
          other.agencyId == this.agencyId &&
          other.winnerId == this.winnerId &&
          other.category == this.category &&
          other.tenderMethod == this.tenderMethod &&
          other.awardWay == this.awardWay &&
          other.amount == this.amount &&
          other.budget == this.budget &&
          other.floorPrice == this.floorPrice &&
          other.bidderCount == this.bidderCount &&
          other.noticeDate == this.noticeDate &&
          other.awardDate == this.awardDate &&
          other.url == this.url &&
          other.source == this.source &&
          other.hasDetail == this.hasDetail &&
          other.updatedAt == this.updatedAt &&
          other.country == this.country &&
          other.search == this.search);
}

class FactAwardCompanion extends UpdateCompanion<FactAwardData> {
  final Value<String> caseKey;
  final Value<String> caseNo;
  final Value<String> name;
  final Value<int> agencyId;
  final Value<int?> winnerId;
  final Value<String> category;
  final Value<String> tenderMethod;
  final Value<String> awardWay;
  final Value<double> amount;
  final Value<double?> budget;
  final Value<double?> floorPrice;
  final Value<int?> bidderCount;
  final Value<DateTime?> noticeDate;
  final Value<DateTime?> awardDate;
  final Value<String> url;
  final Value<String> source;
  final Value<bool> hasDetail;
  final Value<DateTime> updatedAt;
  final Value<String> country;
  final Value<String?> search;
  final Value<int> rowid;
  const FactAwardCompanion({
    this.caseKey = const Value.absent(),
    this.caseNo = const Value.absent(),
    this.name = const Value.absent(),
    this.agencyId = const Value.absent(),
    this.winnerId = const Value.absent(),
    this.category = const Value.absent(),
    this.tenderMethod = const Value.absent(),
    this.awardWay = const Value.absent(),
    this.amount = const Value.absent(),
    this.budget = const Value.absent(),
    this.floorPrice = const Value.absent(),
    this.bidderCount = const Value.absent(),
    this.noticeDate = const Value.absent(),
    this.awardDate = const Value.absent(),
    this.url = const Value.absent(),
    this.source = const Value.absent(),
    this.hasDetail = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.country = const Value.absent(),
    this.search = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FactAwardCompanion.insert({
    required String caseKey,
    required String caseNo,
    required String name,
    required int agencyId,
    this.winnerId = const Value.absent(),
    this.category = const Value.absent(),
    this.tenderMethod = const Value.absent(),
    this.awardWay = const Value.absent(),
    required double amount,
    this.budget = const Value.absent(),
    this.floorPrice = const Value.absent(),
    this.bidderCount = const Value.absent(),
    this.noticeDate = const Value.absent(),
    this.awardDate = const Value.absent(),
    this.url = const Value.absent(),
    required String source,
    this.hasDetail = const Value.absent(),
    required DateTime updatedAt,
    this.country = const Value.absent(),
    this.search = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : caseKey = Value(caseKey),
       caseNo = Value(caseNo),
       name = Value(name),
       agencyId = Value(agencyId),
       amount = Value(amount),
       source = Value(source),
       updatedAt = Value(updatedAt);
  static Insertable<FactAwardData> custom({
    Expression<String>? caseKey,
    Expression<String>? caseNo,
    Expression<String>? name,
    Expression<int>? agencyId,
    Expression<int>? winnerId,
    Expression<String>? category,
    Expression<String>? tenderMethod,
    Expression<String>? awardWay,
    Expression<double>? amount,
    Expression<double>? budget,
    Expression<double>? floorPrice,
    Expression<int>? bidderCount,
    Expression<DateTime>? noticeDate,
    Expression<DateTime>? awardDate,
    Expression<String>? url,
    Expression<String>? source,
    Expression<bool>? hasDetail,
    Expression<DateTime>? updatedAt,
    Expression<String>? country,
    Expression<String>? search,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (caseKey != null) 'case_key': caseKey,
      if (caseNo != null) 'case_no': caseNo,
      if (name != null) 'name': name,
      if (agencyId != null) 'agency_id': agencyId,
      if (winnerId != null) 'winner_id': winnerId,
      if (category != null) 'category': category,
      if (tenderMethod != null) 'tender_method': tenderMethod,
      if (awardWay != null) 'award_way': awardWay,
      if (amount != null) 'amount': amount,
      if (budget != null) 'budget': budget,
      if (floorPrice != null) 'floor_price': floorPrice,
      if (bidderCount != null) 'bidder_count': bidderCount,
      if (noticeDate != null) 'notice_date': noticeDate,
      if (awardDate != null) 'award_date': awardDate,
      if (url != null) 'url': url,
      if (source != null) 'source': source,
      if (hasDetail != null) 'has_detail': hasDetail,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (country != null) 'country': country,
      if (search != null) 'search': search,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FactAwardCompanion copyWith({
    Value<String>? caseKey,
    Value<String>? caseNo,
    Value<String>? name,
    Value<int>? agencyId,
    Value<int?>? winnerId,
    Value<String>? category,
    Value<String>? tenderMethod,
    Value<String>? awardWay,
    Value<double>? amount,
    Value<double?>? budget,
    Value<double?>? floorPrice,
    Value<int?>? bidderCount,
    Value<DateTime?>? noticeDate,
    Value<DateTime?>? awardDate,
    Value<String>? url,
    Value<String>? source,
    Value<bool>? hasDetail,
    Value<DateTime>? updatedAt,
    Value<String>? country,
    Value<String?>? search,
    Value<int>? rowid,
  }) {
    return FactAwardCompanion(
      caseKey: caseKey ?? this.caseKey,
      caseNo: caseNo ?? this.caseNo,
      name: name ?? this.name,
      agencyId: agencyId ?? this.agencyId,
      winnerId: winnerId ?? this.winnerId,
      category: category ?? this.category,
      tenderMethod: tenderMethod ?? this.tenderMethod,
      awardWay: awardWay ?? this.awardWay,
      amount: amount ?? this.amount,
      budget: budget ?? this.budget,
      floorPrice: floorPrice ?? this.floorPrice,
      bidderCount: bidderCount ?? this.bidderCount,
      noticeDate: noticeDate ?? this.noticeDate,
      awardDate: awardDate ?? this.awardDate,
      url: url ?? this.url,
      source: source ?? this.source,
      hasDetail: hasDetail ?? this.hasDetail,
      updatedAt: updatedAt ?? this.updatedAt,
      country: country ?? this.country,
      search: search ?? this.search,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (caseKey.present) {
      map['case_key'] = Variable<String>(caseKey.value);
    }
    if (caseNo.present) {
      map['case_no'] = Variable<String>(caseNo.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (agencyId.present) {
      map['agency_id'] = Variable<int>(agencyId.value);
    }
    if (winnerId.present) {
      map['winner_id'] = Variable<int>(winnerId.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (tenderMethod.present) {
      map['tender_method'] = Variable<String>(tenderMethod.value);
    }
    if (awardWay.present) {
      map['award_way'] = Variable<String>(awardWay.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (budget.present) {
      map['budget'] = Variable<double>(budget.value);
    }
    if (floorPrice.present) {
      map['floor_price'] = Variable<double>(floorPrice.value);
    }
    if (bidderCount.present) {
      map['bidder_count'] = Variable<int>(bidderCount.value);
    }
    if (noticeDate.present) {
      map['notice_date'] = Variable<DateTime>(noticeDate.value);
    }
    if (awardDate.present) {
      map['award_date'] = Variable<DateTime>(awardDate.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (hasDetail.present) {
      map['has_detail'] = Variable<bool>(hasDetail.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (country.present) {
      map['country'] = Variable<String>(country.value);
    }
    if (search.present) {
      map['search'] = Variable<String>(search.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FactAwardCompanion(')
          ..write('caseKey: $caseKey, ')
          ..write('caseNo: $caseNo, ')
          ..write('name: $name, ')
          ..write('agencyId: $agencyId, ')
          ..write('winnerId: $winnerId, ')
          ..write('category: $category, ')
          ..write('tenderMethod: $tenderMethod, ')
          ..write('awardWay: $awardWay, ')
          ..write('amount: $amount, ')
          ..write('budget: $budget, ')
          ..write('floorPrice: $floorPrice, ')
          ..write('bidderCount: $bidderCount, ')
          ..write('noticeDate: $noticeDate, ')
          ..write('awardDate: $awardDate, ')
          ..write('url: $url, ')
          ..write('source: $source, ')
          ..write('hasDetail: $hasDetail, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('country: $country, ')
          ..write('search: $search, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FactBidTable extends FactBid with TableInfo<$FactBidTable, FactBidData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FactBidTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _caseKeyMeta = const VerificationMeta(
    'caseKey',
  );
  @override
  late final GeneratedColumn<String> caseKey = GeneratedColumn<String>(
    'case_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES fact_award (case_key)',
    ),
  );
  static const VerificationMeta _vendorIdMeta = const VerificationMeta(
    'vendorId',
  );
  @override
  late final GeneratedColumn<int> vendorId = GeneratedColumn<int>(
    'vendor_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES dim_vendor (id)',
    ),
  );
  static const VerificationMeta _wonMeta = const VerificationMeta('won');
  @override
  late final GeneratedColumn<bool> won = GeneratedColumn<bool>(
    'won',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("won" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [caseKey, vendorId, won];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fact_bid';
  @override
  VerificationContext validateIntegrity(
    Insertable<FactBidData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('case_key')) {
      context.handle(
        _caseKeyMeta,
        caseKey.isAcceptableOrUnknown(data['case_key']!, _caseKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_caseKeyMeta);
    }
    if (data.containsKey('vendor_id')) {
      context.handle(
        _vendorIdMeta,
        vendorId.isAcceptableOrUnknown(data['vendor_id']!, _vendorIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vendorIdMeta);
    }
    if (data.containsKey('won')) {
      context.handle(
        _wonMeta,
        won.isAcceptableOrUnknown(data['won']!, _wonMeta),
      );
    } else if (isInserting) {
      context.missing(_wonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {caseKey, vendorId};
  @override
  FactBidData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FactBidData(
      caseKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}case_key'],
      )!,
      vendorId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}vendor_id'],
      )!,
      won: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}won'],
      )!,
    );
  }

  @override
  $FactBidTable createAlias(String alias) {
    return $FactBidTable(attachedDatabase, alias);
  }
}

class FactBidData extends DataClass implements Insertable<FactBidData> {
  final String caseKey;
  final int vendorId;
  final bool won;
  const FactBidData({
    required this.caseKey,
    required this.vendorId,
    required this.won,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['case_key'] = Variable<String>(caseKey);
    map['vendor_id'] = Variable<int>(vendorId);
    map['won'] = Variable<bool>(won);
    return map;
  }

  FactBidCompanion toCompanion(bool nullToAbsent) {
    return FactBidCompanion(
      caseKey: Value(caseKey),
      vendorId: Value(vendorId),
      won: Value(won),
    );
  }

  factory FactBidData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FactBidData(
      caseKey: serializer.fromJson<String>(json['caseKey']),
      vendorId: serializer.fromJson<int>(json['vendorId']),
      won: serializer.fromJson<bool>(json['won']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'caseKey': serializer.toJson<String>(caseKey),
      'vendorId': serializer.toJson<int>(vendorId),
      'won': serializer.toJson<bool>(won),
    };
  }

  FactBidData copyWith({String? caseKey, int? vendorId, bool? won}) =>
      FactBidData(
        caseKey: caseKey ?? this.caseKey,
        vendorId: vendorId ?? this.vendorId,
        won: won ?? this.won,
      );
  FactBidData copyWithCompanion(FactBidCompanion data) {
    return FactBidData(
      caseKey: data.caseKey.present ? data.caseKey.value : this.caseKey,
      vendorId: data.vendorId.present ? data.vendorId.value : this.vendorId,
      won: data.won.present ? data.won.value : this.won,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FactBidData(')
          ..write('caseKey: $caseKey, ')
          ..write('vendorId: $vendorId, ')
          ..write('won: $won')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(caseKey, vendorId, won);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FactBidData &&
          other.caseKey == this.caseKey &&
          other.vendorId == this.vendorId &&
          other.won == this.won);
}

class FactBidCompanion extends UpdateCompanion<FactBidData> {
  final Value<String> caseKey;
  final Value<int> vendorId;
  final Value<bool> won;
  final Value<int> rowid;
  const FactBidCompanion({
    this.caseKey = const Value.absent(),
    this.vendorId = const Value.absent(),
    this.won = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FactBidCompanion.insert({
    required String caseKey,
    required int vendorId,
    required bool won,
    this.rowid = const Value.absent(),
  }) : caseKey = Value(caseKey),
       vendorId = Value(vendorId),
       won = Value(won);
  static Insertable<FactBidData> custom({
    Expression<String>? caseKey,
    Expression<int>? vendorId,
    Expression<bool>? won,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (caseKey != null) 'case_key': caseKey,
      if (vendorId != null) 'vendor_id': vendorId,
      if (won != null) 'won': won,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FactBidCompanion copyWith({
    Value<String>? caseKey,
    Value<int>? vendorId,
    Value<bool>? won,
    Value<int>? rowid,
  }) {
    return FactBidCompanion(
      caseKey: caseKey ?? this.caseKey,
      vendorId: vendorId ?? this.vendorId,
      won: won ?? this.won,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (caseKey.present) {
      map['case_key'] = Variable<String>(caseKey.value);
    }
    if (vendorId.present) {
      map['vendor_id'] = Variable<int>(vendorId.value);
    }
    if (won.present) {
      map['won'] = Variable<bool>(won.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FactBidCompanion(')
          ..write('caseKey: $caseKey, ')
          ..write('vendorId: $vendorId, ')
          ..write('won: $won, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FactReviewTable extends FactReview
    with TableInfo<$FactReviewTable, FactReviewData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FactReviewTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _caseKeyMeta = const VerificationMeta(
    'caseKey',
  );
  @override
  late final GeneratedColumn<String> caseKey = GeneratedColumn<String>(
    'case_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES fact_award (case_key)',
    ),
  );
  static const VerificationMeta _reviewerIdMeta = const VerificationMeta(
    'reviewerId',
  );
  @override
  late final GeneratedColumn<int> reviewerId = GeneratedColumn<int>(
    'reviewer_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES dim_reviewer (id)',
    ),
  );
  static const VerificationMeta _attendedMeta = const VerificationMeta(
    'attended',
  );
  @override
  late final GeneratedColumn<bool> attended = GeneratedColumn<bool>(
    'attended',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("attended" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [caseKey, reviewerId, attended];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fact_review';
  @override
  VerificationContext validateIntegrity(
    Insertable<FactReviewData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('case_key')) {
      context.handle(
        _caseKeyMeta,
        caseKey.isAcceptableOrUnknown(data['case_key']!, _caseKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_caseKeyMeta);
    }
    if (data.containsKey('reviewer_id')) {
      context.handle(
        _reviewerIdMeta,
        reviewerId.isAcceptableOrUnknown(data['reviewer_id']!, _reviewerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_reviewerIdMeta);
    }
    if (data.containsKey('attended')) {
      context.handle(
        _attendedMeta,
        attended.isAcceptableOrUnknown(data['attended']!, _attendedMeta),
      );
    } else if (isInserting) {
      context.missing(_attendedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {caseKey, reviewerId};
  @override
  FactReviewData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FactReviewData(
      caseKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}case_key'],
      )!,
      reviewerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reviewer_id'],
      )!,
      attended: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}attended'],
      )!,
    );
  }

  @override
  $FactReviewTable createAlias(String alias) {
    return $FactReviewTable(attachedDatabase, alias);
  }
}

class FactReviewData extends DataClass implements Insertable<FactReviewData> {
  final String caseKey;
  final int reviewerId;
  final bool attended;
  const FactReviewData({
    required this.caseKey,
    required this.reviewerId,
    required this.attended,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['case_key'] = Variable<String>(caseKey);
    map['reviewer_id'] = Variable<int>(reviewerId);
    map['attended'] = Variable<bool>(attended);
    return map;
  }

  FactReviewCompanion toCompanion(bool nullToAbsent) {
    return FactReviewCompanion(
      caseKey: Value(caseKey),
      reviewerId: Value(reviewerId),
      attended: Value(attended),
    );
  }

  factory FactReviewData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FactReviewData(
      caseKey: serializer.fromJson<String>(json['caseKey']),
      reviewerId: serializer.fromJson<int>(json['reviewerId']),
      attended: serializer.fromJson<bool>(json['attended']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'caseKey': serializer.toJson<String>(caseKey),
      'reviewerId': serializer.toJson<int>(reviewerId),
      'attended': serializer.toJson<bool>(attended),
    };
  }

  FactReviewData copyWith({String? caseKey, int? reviewerId, bool? attended}) =>
      FactReviewData(
        caseKey: caseKey ?? this.caseKey,
        reviewerId: reviewerId ?? this.reviewerId,
        attended: attended ?? this.attended,
      );
  FactReviewData copyWithCompanion(FactReviewCompanion data) {
    return FactReviewData(
      caseKey: data.caseKey.present ? data.caseKey.value : this.caseKey,
      reviewerId: data.reviewerId.present
          ? data.reviewerId.value
          : this.reviewerId,
      attended: data.attended.present ? data.attended.value : this.attended,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FactReviewData(')
          ..write('caseKey: $caseKey, ')
          ..write('reviewerId: $reviewerId, ')
          ..write('attended: $attended')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(caseKey, reviewerId, attended);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FactReviewData &&
          other.caseKey == this.caseKey &&
          other.reviewerId == this.reviewerId &&
          other.attended == this.attended);
}

class FactReviewCompanion extends UpdateCompanion<FactReviewData> {
  final Value<String> caseKey;
  final Value<int> reviewerId;
  final Value<bool> attended;
  final Value<int> rowid;
  const FactReviewCompanion({
    this.caseKey = const Value.absent(),
    this.reviewerId = const Value.absent(),
    this.attended = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FactReviewCompanion.insert({
    required String caseKey,
    required int reviewerId,
    required bool attended,
    this.rowid = const Value.absent(),
  }) : caseKey = Value(caseKey),
       reviewerId = Value(reviewerId),
       attended = Value(attended);
  static Insertable<FactReviewData> custom({
    Expression<String>? caseKey,
    Expression<int>? reviewerId,
    Expression<bool>? attended,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (caseKey != null) 'case_key': caseKey,
      if (reviewerId != null) 'reviewer_id': reviewerId,
      if (attended != null) 'attended': attended,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FactReviewCompanion copyWith({
    Value<String>? caseKey,
    Value<int>? reviewerId,
    Value<bool>? attended,
    Value<int>? rowid,
  }) {
    return FactReviewCompanion(
      caseKey: caseKey ?? this.caseKey,
      reviewerId: reviewerId ?? this.reviewerId,
      attended: attended ?? this.attended,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (caseKey.present) {
      map['case_key'] = Variable<String>(caseKey.value);
    }
    if (reviewerId.present) {
      map['reviewer_id'] = Variable<int>(reviewerId.value);
    }
    if (attended.present) {
      map['attended'] = Variable<bool>(attended.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FactReviewCompanion(')
          ..write('caseKey: $caseKey, ')
          ..write('reviewerId: $reviewerId, ')
          ..write('attended: $attended, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DatasetFileTable extends DatasetFile
    with TableInfo<$DatasetFileTable, DatasetFileData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DatasetFileTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordsMeta = const VerificationMeta(
    'records',
  );
  @override
  late final GeneratedColumn<int> records = GeneratedColumn<int>(
    'records',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _checkedAtMeta = const VerificationMeta(
    'checkedAt',
  );
  @override
  late final GeneratedColumn<DateTime> checkedAt = GeneratedColumn<DateTime>(
    'checked_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [name, records, size, checkedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dataset_file';
  @override
  VerificationContext validateIntegrity(
    Insertable<DatasetFileData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('records')) {
      context.handle(
        _recordsMeta,
        records.isAcceptableOrUnknown(data['records']!, _recordsMeta),
      );
    } else if (isInserting) {
      context.missing(_recordsMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    }
    if (data.containsKey('checked_at')) {
      context.handle(
        _checkedAtMeta,
        checkedAt.isAcceptableOrUnknown(data['checked_at']!, _checkedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_checkedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {name};
  @override
  DatasetFileData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DatasetFileData(
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      records: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}records'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      ),
      checkedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}checked_at'],
      )!,
    );
  }

  @override
  $DatasetFileTable createAlias(String alias) {
    return $DatasetFileTable(attachedDatabase, alias);
  }
}

class DatasetFileData extends DataClass implements Insertable<DatasetFileData> {
  final String name;
  final int records;
  final int? size;
  final DateTime checkedAt;
  const DatasetFileData({
    required this.name,
    required this.records,
    this.size,
    required this.checkedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['name'] = Variable<String>(name);
    map['records'] = Variable<int>(records);
    if (!nullToAbsent || size != null) {
      map['size'] = Variable<int>(size);
    }
    map['checked_at'] = Variable<DateTime>(checkedAt);
    return map;
  }

  DatasetFileCompanion toCompanion(bool nullToAbsent) {
    return DatasetFileCompanion(
      name: Value(name),
      records: Value(records),
      size: size == null && nullToAbsent ? const Value.absent() : Value(size),
      checkedAt: Value(checkedAt),
    );
  }

  factory DatasetFileData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DatasetFileData(
      name: serializer.fromJson<String>(json['name']),
      records: serializer.fromJson<int>(json['records']),
      size: serializer.fromJson<int?>(json['size']),
      checkedAt: serializer.fromJson<DateTime>(json['checkedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'name': serializer.toJson<String>(name),
      'records': serializer.toJson<int>(records),
      'size': serializer.toJson<int?>(size),
      'checkedAt': serializer.toJson<DateTime>(checkedAt),
    };
  }

  DatasetFileData copyWith({
    String? name,
    int? records,
    Value<int?> size = const Value.absent(),
    DateTime? checkedAt,
  }) => DatasetFileData(
    name: name ?? this.name,
    records: records ?? this.records,
    size: size.present ? size.value : this.size,
    checkedAt: checkedAt ?? this.checkedAt,
  );
  DatasetFileData copyWithCompanion(DatasetFileCompanion data) {
    return DatasetFileData(
      name: data.name.present ? data.name.value : this.name,
      records: data.records.present ? data.records.value : this.records,
      size: data.size.present ? data.size.value : this.size,
      checkedAt: data.checkedAt.present ? data.checkedAt.value : this.checkedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DatasetFileData(')
          ..write('name: $name, ')
          ..write('records: $records, ')
          ..write('size: $size, ')
          ..write('checkedAt: $checkedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(name, records, size, checkedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DatasetFileData &&
          other.name == this.name &&
          other.records == this.records &&
          other.size == this.size &&
          other.checkedAt == this.checkedAt);
}

class DatasetFileCompanion extends UpdateCompanion<DatasetFileData> {
  final Value<String> name;
  final Value<int> records;
  final Value<int?> size;
  final Value<DateTime> checkedAt;
  final Value<int> rowid;
  const DatasetFileCompanion({
    this.name = const Value.absent(),
    this.records = const Value.absent(),
    this.size = const Value.absent(),
    this.checkedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DatasetFileCompanion.insert({
    required String name,
    required int records,
    this.size = const Value.absent(),
    required DateTime checkedAt,
    this.rowid = const Value.absent(),
  }) : name = Value(name),
       records = Value(records),
       checkedAt = Value(checkedAt);
  static Insertable<DatasetFileData> custom({
    Expression<String>? name,
    Expression<int>? records,
    Expression<int>? size,
    Expression<DateTime>? checkedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (name != null) 'name': name,
      if (records != null) 'records': records,
      if (size != null) 'size': size,
      if (checkedAt != null) 'checked_at': checkedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DatasetFileCompanion copyWith({
    Value<String>? name,
    Value<int>? records,
    Value<int?>? size,
    Value<DateTime>? checkedAt,
    Value<int>? rowid,
  }) {
    return DatasetFileCompanion(
      name: name ?? this.name,
      records: records ?? this.records,
      size: size ?? this.size,
      checkedAt: checkedAt ?? this.checkedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (records.present) {
      map['records'] = Variable<int>(records.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (checkedAt.present) {
      map['checked_at'] = Variable<DateTime>(checkedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DatasetFileCompanion(')
          ..write('name: $name, ')
          ..write('records: $records, ')
          ..write('size: $size, ')
          ..write('checkedAt: $checkedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SearchTotalTable extends SearchTotal
    with TableInfo<$SearchTotalTable, SearchTotalData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchTotalTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  @override
  List<GeneratedColumn> get $columns => [key, total, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_total';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchTotalData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SearchTotalData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchTotalData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $SearchTotalTable createAlias(String alias) {
    return $SearchTotalTable(attachedDatabase, alias);
  }
}

class SearchTotalData extends DataClass implements Insertable<SearchTotalData> {
  final String key;
  final int total;
  final DateTime fetchedAt;
  const SearchTotalData({
    required this.key,
    required this.total,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['total'] = Variable<int>(total);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  SearchTotalCompanion toCompanion(bool nullToAbsent) {
    return SearchTotalCompanion(
      key: Value(key),
      total: Value(total),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory SearchTotalData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchTotalData(
      key: serializer.fromJson<String>(json['key']),
      total: serializer.fromJson<int>(json['total']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'total': serializer.toJson<int>(total),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  SearchTotalData copyWith({String? key, int? total, DateTime? fetchedAt}) =>
      SearchTotalData(
        key: key ?? this.key,
        total: total ?? this.total,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );
  SearchTotalData copyWithCompanion(SearchTotalCompanion data) {
    return SearchTotalData(
      key: data.key.present ? data.key.value : this.key,
      total: data.total.present ? data.total.value : this.total,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchTotalData(')
          ..write('key: $key, ')
          ..write('total: $total, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, total, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchTotalData &&
          other.key == this.key &&
          other.total == this.total &&
          other.fetchedAt == this.fetchedAt);
}

class SearchTotalCompanion extends UpdateCompanion<SearchTotalData> {
  final Value<String> key;
  final Value<int> total;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const SearchTotalCompanion({
    this.key = const Value.absent(),
    this.total = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SearchTotalCompanion.insert({
    required String key,
    required int total,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       total = Value(total),
       fetchedAt = Value(fetchedAt);
  static Insertable<SearchTotalData> custom({
    Expression<String>? key,
    Expression<int>? total,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (total != null) 'total': total,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SearchTotalCompanion copyWith({
    Value<String>? key,
    Value<int>? total,
    Value<DateTime>? fetchedAt,
    Value<int>? rowid,
  }) {
    return SearchTotalCompanion(
      key: key ?? this.key,
      total: total ?? this.total,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchTotalCompanion(')
          ..write('key: $key, ')
          ..write('total: $total, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$CaseDb extends GeneratedDatabase {
  _$CaseDb(QueryExecutor e) : super(e);
  $CaseDbManager get managers => $CaseDbManager(this);
  late final $DimAgencyTable dimAgency = $DimAgencyTable(this);
  late final $DimVendorTable dimVendor = $DimVendorTable(this);
  late final $DimReviewerTable dimReviewer = $DimReviewerTable(this);
  late final $FactAwardTable factAward = $FactAwardTable(this);
  late final $FactBidTable factBid = $FactBidTable(this);
  late final $FactReviewTable factReview = $FactReviewTable(this);
  late final $DatasetFileTable datasetFile = $DatasetFileTable(this);
  late final $SearchTotalTable searchTotal = $SearchTotalTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    dimAgency,
    dimVendor,
    dimReviewer,
    factAward,
    factBid,
    factReview,
    datasetFile,
    searchTotal,
  ];
}

typedef $$DimAgencyTableCreateCompanionBuilder =
    DimAgencyCompanion Function({Value<int> id, required String name});
typedef $$DimAgencyTableUpdateCompanionBuilder =
    DimAgencyCompanion Function({Value<int> id, Value<String> name});

final class $$DimAgencyTableReferences
    extends BaseReferences<_$CaseDb, $DimAgencyTable, DimAgencyData> {
  $$DimAgencyTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FactAwardTable, List<FactAwardData>>
  _factAwardRefsTable(_$CaseDb db) => MultiTypedResultKey.fromTable(
    db.factAward,
    aliasName: 'dim_agency__id__fact_award__agency_id',
  );

  $$FactAwardTableProcessedTableManager get factAwardRefs {
    final manager = $$FactAwardTableTableManager(
      $_db,
      $_db.factAward,
    ).filter((f) => f.agencyId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_factAwardRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DimAgencyTableFilterComposer
    extends Composer<_$CaseDb, $DimAgencyTable> {
  $$DimAgencyTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> factAwardRefs(
    Expression<bool> Function($$FactAwardTableFilterComposer f) f,
  ) {
    final $$FactAwardTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.factAward,
      getReferencedColumn: (t) => t.agencyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FactAwardTableFilterComposer(
            $db: $db,
            $table: $db.factAward,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DimAgencyTableOrderingComposer
    extends Composer<_$CaseDb, $DimAgencyTable> {
  $$DimAgencyTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DimAgencyTableAnnotationComposer
    extends Composer<_$CaseDb, $DimAgencyTable> {
  $$DimAgencyTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  Expression<T> factAwardRefs<T extends Object>(
    Expression<T> Function($$FactAwardTableAnnotationComposer a) f,
  ) {
    final $$FactAwardTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.factAward,
      getReferencedColumn: (t) => t.agencyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FactAwardTableAnnotationComposer(
            $db: $db,
            $table: $db.factAward,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DimAgencyTableTableManager
    extends
        RootTableManager<
          _$CaseDb,
          $DimAgencyTable,
          DimAgencyData,
          $$DimAgencyTableFilterComposer,
          $$DimAgencyTableOrderingComposer,
          $$DimAgencyTableAnnotationComposer,
          $$DimAgencyTableCreateCompanionBuilder,
          $$DimAgencyTableUpdateCompanionBuilder,
          (DimAgencyData, $$DimAgencyTableReferences),
          DimAgencyData,
          PrefetchHooks Function({bool factAwardRefs})
        > {
  $$DimAgencyTableTableManager(_$CaseDb db, $DimAgencyTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DimAgencyTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DimAgencyTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DimAgencyTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
              }) => DimAgencyCompanion(id: id, name: name),
          createCompanionCallback:
              ({Value<int> id = const Value.absent(), required String name}) =>
                  DimAgencyCompanion.insert(id: id, name: name),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DimAgencyTable, DimAgencyData>(table),
                  $$DimAgencyTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({factAwardRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (factAwardRefs) db.factAward],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (factAwardRefs)
                    await $_getPrefetchedDataByColumns<
                      DimAgencyData,
                      $DimAgencyTable,
                      FactAwardData,
                      $FactAwardTable
                    >(
                      currentTable: table,
                      referencedTable: $$DimAgencyTableReferences
                          ._factAwardRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$DimAgencyTableReferences(
                            db,
                            table,
                            p0,
                          ).factAwardRefs,
                      currentColumn: 'id',
                      referencedColumn: 'agency_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$DimAgencyTableProcessedTableManager =
    ProcessedTableManager<
      _$CaseDb,
      $DimAgencyTable,
      DimAgencyData,
      $$DimAgencyTableFilterComposer,
      $$DimAgencyTableOrderingComposer,
      $$DimAgencyTableAnnotationComposer,
      $$DimAgencyTableCreateCompanionBuilder,
      $$DimAgencyTableUpdateCompanionBuilder,
      (DimAgencyData, $$DimAgencyTableReferences),
      DimAgencyData,
      PrefetchHooks Function({bool factAwardRefs})
    >;
typedef $$DimVendorTableCreateCompanionBuilder =
    DimVendorCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> taxId,
    });
typedef $$DimVendorTableUpdateCompanionBuilder =
    DimVendorCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> taxId,
    });

final class $$DimVendorTableReferences
    extends BaseReferences<_$CaseDb, $DimVendorTable, DimVendorData> {
  $$DimVendorTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FactAwardTable, List<FactAwardData>>
  _factAwardRefsTable(_$CaseDb db) => MultiTypedResultKey.fromTable(
    db.factAward,
    aliasName: 'dim_vendor__id__fact_award__winner_id',
  );

  $$FactAwardTableProcessedTableManager get factAwardRefs {
    final manager = $$FactAwardTableTableManager(
      $_db,
      $_db.factAward,
    ).filter((f) => f.winnerId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_factAwardRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FactBidTable, List<FactBidData>>
  _factBidRefsTable(_$CaseDb db) => MultiTypedResultKey.fromTable(
    db.factBid,
    aliasName: 'dim_vendor__id__fact_bid__vendor_id',
  );

  $$FactBidTableProcessedTableManager get factBidRefs {
    final manager = $$FactBidTableTableManager(
      $_db,
      $_db.factBid,
    ).filter((f) => f.vendorId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_factBidRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DimVendorTableFilterComposer
    extends Composer<_$CaseDb, $DimVendorTable> {
  $$DimVendorTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taxId => $composableBuilder(
    column: $table.taxId,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> factAwardRefs(
    Expression<bool> Function($$FactAwardTableFilterComposer f) f,
  ) {
    final $$FactAwardTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.factAward,
      getReferencedColumn: (t) => t.winnerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FactAwardTableFilterComposer(
            $db: $db,
            $table: $db.factAward,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> factBidRefs(
    Expression<bool> Function($$FactBidTableFilterComposer f) f,
  ) {
    final $$FactBidTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.factBid,
      getReferencedColumn: (t) => t.vendorId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FactBidTableFilterComposer(
            $db: $db,
            $table: $db.factBid,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DimVendorTableOrderingComposer
    extends Composer<_$CaseDb, $DimVendorTable> {
  $$DimVendorTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taxId => $composableBuilder(
    column: $table.taxId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DimVendorTableAnnotationComposer
    extends Composer<_$CaseDb, $DimVendorTable> {
  $$DimVendorTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get taxId =>
      $composableBuilder(column: $table.taxId, builder: (column) => column);

  Expression<T> factAwardRefs<T extends Object>(
    Expression<T> Function($$FactAwardTableAnnotationComposer a) f,
  ) {
    final $$FactAwardTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.factAward,
      getReferencedColumn: (t) => t.winnerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FactAwardTableAnnotationComposer(
            $db: $db,
            $table: $db.factAward,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> factBidRefs<T extends Object>(
    Expression<T> Function($$FactBidTableAnnotationComposer a) f,
  ) {
    final $$FactBidTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.factBid,
      getReferencedColumn: (t) => t.vendorId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FactBidTableAnnotationComposer(
            $db: $db,
            $table: $db.factBid,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DimVendorTableTableManager
    extends
        RootTableManager<
          _$CaseDb,
          $DimVendorTable,
          DimVendorData,
          $$DimVendorTableFilterComposer,
          $$DimVendorTableOrderingComposer,
          $$DimVendorTableAnnotationComposer,
          $$DimVendorTableCreateCompanionBuilder,
          $$DimVendorTableUpdateCompanionBuilder,
          (DimVendorData, $$DimVendorTableReferences),
          DimVendorData,
          PrefetchHooks Function({bool factAwardRefs, bool factBidRefs})
        > {
  $$DimVendorTableTableManager(_$CaseDb db, $DimVendorTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DimVendorTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DimVendorTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DimVendorTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> taxId = const Value.absent(),
              }) => DimVendorCompanion(id: id, name: name, taxId: taxId),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> taxId = const Value.absent(),
              }) => DimVendorCompanion.insert(id: id, name: name, taxId: taxId),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DimVendorTable, DimVendorData>(table),
                  $$DimVendorTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({factAwardRefs = false, factBidRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (factAwardRefs) db.factAward,
                    if (factBidRefs) db.factBid,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (factAwardRefs)
                        await $_getPrefetchedDataByColumns<
                          DimVendorData,
                          $DimVendorTable,
                          FactAwardData,
                          $FactAwardTable
                        >(
                          currentTable: table,
                          referencedTable: $$DimVendorTableReferences
                              ._factAwardRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DimVendorTableReferences(
                                db,
                                table,
                                p0,
                              ).factAwardRefs,
                          currentColumn: 'id',
                          referencedColumn: 'winner_id',
                          typedResults: items,
                        ),
                      if (factBidRefs)
                        await $_getPrefetchedDataByColumns<
                          DimVendorData,
                          $DimVendorTable,
                          FactBidData,
                          $FactBidTable
                        >(
                          currentTable: table,
                          referencedTable: $$DimVendorTableReferences
                              ._factBidRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DimVendorTableReferences(
                                db,
                                table,
                                p0,
                              ).factBidRefs,
                          currentColumn: 'id',
                          referencedColumn: 'vendor_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$DimVendorTableProcessedTableManager =
    ProcessedTableManager<
      _$CaseDb,
      $DimVendorTable,
      DimVendorData,
      $$DimVendorTableFilterComposer,
      $$DimVendorTableOrderingComposer,
      $$DimVendorTableAnnotationComposer,
      $$DimVendorTableCreateCompanionBuilder,
      $$DimVendorTableUpdateCompanionBuilder,
      (DimVendorData, $$DimVendorTableReferences),
      DimVendorData,
      PrefetchHooks Function({bool factAwardRefs, bool factBidRefs})
    >;
typedef $$DimReviewerTableCreateCompanionBuilder =
    DimReviewerCompanion Function({
      Value<int> id,
      required String name,
      required String job,
    });
typedef $$DimReviewerTableUpdateCompanionBuilder =
    DimReviewerCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> job,
    });

final class $$DimReviewerTableReferences
    extends BaseReferences<_$CaseDb, $DimReviewerTable, DimReviewerData> {
  $$DimReviewerTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FactReviewTable, List<FactReviewData>>
  _factReviewRefsTable(_$CaseDb db) => MultiTypedResultKey.fromTable(
    db.factReview,
    aliasName: 'dim_reviewer__id__fact_review__reviewer_id',
  );

  $$FactReviewTableProcessedTableManager get factReviewRefs {
    final manager = $$FactReviewTableTableManager(
      $_db,
      $_db.factReview,
    ).filter((f) => f.reviewerId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_factReviewRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DimReviewerTableFilterComposer
    extends Composer<_$CaseDb, $DimReviewerTable> {
  $$DimReviewerTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get job => $composableBuilder(
    column: $table.job,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> factReviewRefs(
    Expression<bool> Function($$FactReviewTableFilterComposer f) f,
  ) {
    final $$FactReviewTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.factReview,
      getReferencedColumn: (t) => t.reviewerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FactReviewTableFilterComposer(
            $db: $db,
            $table: $db.factReview,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DimReviewerTableOrderingComposer
    extends Composer<_$CaseDb, $DimReviewerTable> {
  $$DimReviewerTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get job => $composableBuilder(
    column: $table.job,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DimReviewerTableAnnotationComposer
    extends Composer<_$CaseDb, $DimReviewerTable> {
  $$DimReviewerTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get job =>
      $composableBuilder(column: $table.job, builder: (column) => column);

  Expression<T> factReviewRefs<T extends Object>(
    Expression<T> Function($$FactReviewTableAnnotationComposer a) f,
  ) {
    final $$FactReviewTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.factReview,
      getReferencedColumn: (t) => t.reviewerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FactReviewTableAnnotationComposer(
            $db: $db,
            $table: $db.factReview,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DimReviewerTableTableManager
    extends
        RootTableManager<
          _$CaseDb,
          $DimReviewerTable,
          DimReviewerData,
          $$DimReviewerTableFilterComposer,
          $$DimReviewerTableOrderingComposer,
          $$DimReviewerTableAnnotationComposer,
          $$DimReviewerTableCreateCompanionBuilder,
          $$DimReviewerTableUpdateCompanionBuilder,
          (DimReviewerData, $$DimReviewerTableReferences),
          DimReviewerData,
          PrefetchHooks Function({bool factReviewRefs})
        > {
  $$DimReviewerTableTableManager(_$CaseDb db, $DimReviewerTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DimReviewerTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DimReviewerTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DimReviewerTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> job = const Value.absent(),
              }) => DimReviewerCompanion(id: id, name: name, job: job),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String job,
              }) => DimReviewerCompanion.insert(id: id, name: name, job: job),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DimReviewerTable, DimReviewerData>(table),
                  $$DimReviewerTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({factReviewRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (factReviewRefs) db.factReview],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (factReviewRefs)
                    await $_getPrefetchedDataByColumns<
                      DimReviewerData,
                      $DimReviewerTable,
                      FactReviewData,
                      $FactReviewTable
                    >(
                      currentTable: table,
                      referencedTable: $$DimReviewerTableReferences
                          ._factReviewRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$DimReviewerTableReferences(
                            db,
                            table,
                            p0,
                          ).factReviewRefs,
                      currentColumn: 'id',
                      referencedColumn: 'reviewer_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$DimReviewerTableProcessedTableManager =
    ProcessedTableManager<
      _$CaseDb,
      $DimReviewerTable,
      DimReviewerData,
      $$DimReviewerTableFilterComposer,
      $$DimReviewerTableOrderingComposer,
      $$DimReviewerTableAnnotationComposer,
      $$DimReviewerTableCreateCompanionBuilder,
      $$DimReviewerTableUpdateCompanionBuilder,
      (DimReviewerData, $$DimReviewerTableReferences),
      DimReviewerData,
      PrefetchHooks Function({bool factReviewRefs})
    >;
typedef $$FactAwardTableCreateCompanionBuilder =
    FactAwardCompanion Function({
      required String caseKey,
      required String caseNo,
      required String name,
      required int agencyId,
      Value<int?> winnerId,
      Value<String> category,
      Value<String> tenderMethod,
      Value<String> awardWay,
      required double amount,
      Value<double?> budget,
      Value<double?> floorPrice,
      Value<int?> bidderCount,
      Value<DateTime?> noticeDate,
      Value<DateTime?> awardDate,
      Value<String> url,
      required String source,
      Value<bool> hasDetail,
      required DateTime updatedAt,
      Value<String> country,
      Value<String?> search,
      Value<int> rowid,
    });
typedef $$FactAwardTableUpdateCompanionBuilder =
    FactAwardCompanion Function({
      Value<String> caseKey,
      Value<String> caseNo,
      Value<String> name,
      Value<int> agencyId,
      Value<int?> winnerId,
      Value<String> category,
      Value<String> tenderMethod,
      Value<String> awardWay,
      Value<double> amount,
      Value<double?> budget,
      Value<double?> floorPrice,
      Value<int?> bidderCount,
      Value<DateTime?> noticeDate,
      Value<DateTime?> awardDate,
      Value<String> url,
      Value<String> source,
      Value<bool> hasDetail,
      Value<DateTime> updatedAt,
      Value<String> country,
      Value<String?> search,
      Value<int> rowid,
    });

final class $$FactAwardTableReferences
    extends BaseReferences<_$CaseDb, $FactAwardTable, FactAwardData> {
  $$FactAwardTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DimAgencyTable _agencyIdTable(_$CaseDb db) =>
      db.dimAgency.createAlias('fact_award__agency_id__dim_agency__id');

  $$DimAgencyTableProcessedTableManager get agencyId {
    final $_column = $_itemColumn<int>('agency_id')!;

    final manager = $$DimAgencyTableTableManager(
      $_db,
      $_db.dimAgency,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_agencyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $DimVendorTable _winnerIdTable(_$CaseDb db) =>
      db.dimVendor.createAlias('fact_award__winner_id__dim_vendor__id');

  $$DimVendorTableProcessedTableManager? get winnerId {
    final $_column = $_itemColumn<int>('winner_id');
    if ($_column == null) return null;
    final manager = $$DimVendorTableTableManager(
      $_db,
      $_db.dimVendor,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_winnerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$FactBidTable, List<FactBidData>>
  _factBidRefsTable(_$CaseDb db) => MultiTypedResultKey.fromTable(
    db.factBid,
    aliasName: 'fact_award__case_key__fact_bid__case_key',
  );

  $$FactBidTableProcessedTableManager get factBidRefs {
    final manager = $$FactBidTableTableManager($_db, $_db.factBid).filter(
      (f) => f.caseKey.caseKey.sqlEquals($_itemColumn<String>('case_key')!),
    );

    final cache = $_typedResult.readTableOrNull(_factBidRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FactReviewTable, List<FactReviewData>>
  _factReviewRefsTable(_$CaseDb db) => MultiTypedResultKey.fromTable(
    db.factReview,
    aliasName: 'fact_award__case_key__fact_review__case_key',
  );

  $$FactReviewTableProcessedTableManager get factReviewRefs {
    final manager = $$FactReviewTableTableManager($_db, $_db.factReview).filter(
      (f) => f.caseKey.caseKey.sqlEquals($_itemColumn<String>('case_key')!),
    );

    final cache = $_typedResult.readTableOrNull(_factReviewRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FactAwardTableFilterComposer
    extends Composer<_$CaseDb, $FactAwardTable> {
  $$FactAwardTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get caseKey => $composableBuilder(
    column: $table.caseKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caseNo => $composableBuilder(
    column: $table.caseNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenderMethod => $composableBuilder(
    column: $table.tenderMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get awardWay => $composableBuilder(
    column: $table.awardWay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get budget => $composableBuilder(
    column: $table.budget,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get floorPrice => $composableBuilder(
    column: $table.floorPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bidderCount => $composableBuilder(
    column: $table.bidderCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get noticeDate => $composableBuilder(
    column: $table.noticeDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get awardDate => $composableBuilder(
    column: $table.awardDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasDetail => $composableBuilder(
    column: $table.hasDetail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get country => $composableBuilder(
    column: $table.country,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get search => $composableBuilder(
    column: $table.search,
    builder: (column) => ColumnFilters(column),
  );

  $$DimAgencyTableFilterComposer get agencyId {
    final $$DimAgencyTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.agencyId,
      referencedTable: $db.dimAgency,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DimAgencyTableFilterComposer(
            $db: $db,
            $table: $db.dimAgency,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DimVendorTableFilterComposer get winnerId {
    final $$DimVendorTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.winnerId,
      referencedTable: $db.dimVendor,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DimVendorTableFilterComposer(
            $db: $db,
            $table: $db.dimVendor,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> factBidRefs(
    Expression<bool> Function($$FactBidTableFilterComposer f) f,
  ) {
    final $$FactBidTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.caseKey,
      referencedTable: $db.factBid,
      getReferencedColumn: (t) => t.caseKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FactBidTableFilterComposer(
            $db: $db,
            $table: $db.factBid,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> factReviewRefs(
    Expression<bool> Function($$FactReviewTableFilterComposer f) f,
  ) {
    final $$FactReviewTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.caseKey,
      referencedTable: $db.factReview,
      getReferencedColumn: (t) => t.caseKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FactReviewTableFilterComposer(
            $db: $db,
            $table: $db.factReview,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FactAwardTableOrderingComposer
    extends Composer<_$CaseDb, $FactAwardTable> {
  $$FactAwardTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get caseKey => $composableBuilder(
    column: $table.caseKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caseNo => $composableBuilder(
    column: $table.caseNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenderMethod => $composableBuilder(
    column: $table.tenderMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get awardWay => $composableBuilder(
    column: $table.awardWay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get budget => $composableBuilder(
    column: $table.budget,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get floorPrice => $composableBuilder(
    column: $table.floorPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bidderCount => $composableBuilder(
    column: $table.bidderCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get noticeDate => $composableBuilder(
    column: $table.noticeDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get awardDate => $composableBuilder(
    column: $table.awardDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasDetail => $composableBuilder(
    column: $table.hasDetail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get country => $composableBuilder(
    column: $table.country,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get search => $composableBuilder(
    column: $table.search,
    builder: (column) => ColumnOrderings(column),
  );

  $$DimAgencyTableOrderingComposer get agencyId {
    final $$DimAgencyTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.agencyId,
      referencedTable: $db.dimAgency,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DimAgencyTableOrderingComposer(
            $db: $db,
            $table: $db.dimAgency,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DimVendorTableOrderingComposer get winnerId {
    final $$DimVendorTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.winnerId,
      referencedTable: $db.dimVendor,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DimVendorTableOrderingComposer(
            $db: $db,
            $table: $db.dimVendor,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FactAwardTableAnnotationComposer
    extends Composer<_$CaseDb, $FactAwardTable> {
  $$FactAwardTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get caseKey =>
      $composableBuilder(column: $table.caseKey, builder: (column) => column);

  GeneratedColumn<String> get caseNo =>
      $composableBuilder(column: $table.caseNo, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get tenderMethod => $composableBuilder(
    column: $table.tenderMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get awardWay =>
      $composableBuilder(column: $table.awardWay, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<double> get budget =>
      $composableBuilder(column: $table.budget, builder: (column) => column);

  GeneratedColumn<double> get floorPrice => $composableBuilder(
    column: $table.floorPrice,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bidderCount => $composableBuilder(
    column: $table.bidderCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get noticeDate => $composableBuilder(
    column: $table.noticeDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get awardDate =>
      $composableBuilder(column: $table.awardDate, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<bool> get hasDetail =>
      $composableBuilder(column: $table.hasDetail, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get country =>
      $composableBuilder(column: $table.country, builder: (column) => column);

  GeneratedColumn<String> get search =>
      $composableBuilder(column: $table.search, builder: (column) => column);

  $$DimAgencyTableAnnotationComposer get agencyId {
    final $$DimAgencyTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.agencyId,
      referencedTable: $db.dimAgency,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DimAgencyTableAnnotationComposer(
            $db: $db,
            $table: $db.dimAgency,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DimVendorTableAnnotationComposer get winnerId {
    final $$DimVendorTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.winnerId,
      referencedTable: $db.dimVendor,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DimVendorTableAnnotationComposer(
            $db: $db,
            $table: $db.dimVendor,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> factBidRefs<T extends Object>(
    Expression<T> Function($$FactBidTableAnnotationComposer a) f,
  ) {
    final $$FactBidTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.caseKey,
      referencedTable: $db.factBid,
      getReferencedColumn: (t) => t.caseKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FactBidTableAnnotationComposer(
            $db: $db,
            $table: $db.factBid,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> factReviewRefs<T extends Object>(
    Expression<T> Function($$FactReviewTableAnnotationComposer a) f,
  ) {
    final $$FactReviewTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.caseKey,
      referencedTable: $db.factReview,
      getReferencedColumn: (t) => t.caseKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FactReviewTableAnnotationComposer(
            $db: $db,
            $table: $db.factReview,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FactAwardTableTableManager
    extends
        RootTableManager<
          _$CaseDb,
          $FactAwardTable,
          FactAwardData,
          $$FactAwardTableFilterComposer,
          $$FactAwardTableOrderingComposer,
          $$FactAwardTableAnnotationComposer,
          $$FactAwardTableCreateCompanionBuilder,
          $$FactAwardTableUpdateCompanionBuilder,
          (FactAwardData, $$FactAwardTableReferences),
          FactAwardData,
          PrefetchHooks Function({
            bool agencyId,
            bool winnerId,
            bool factBidRefs,
            bool factReviewRefs,
          })
        > {
  $$FactAwardTableTableManager(_$CaseDb db, $FactAwardTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FactAwardTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FactAwardTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FactAwardTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> caseKey = const Value.absent(),
                Value<String> caseNo = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> agencyId = const Value.absent(),
                Value<int?> winnerId = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> tenderMethod = const Value.absent(),
                Value<String> awardWay = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<double?> budget = const Value.absent(),
                Value<double?> floorPrice = const Value.absent(),
                Value<int?> bidderCount = const Value.absent(),
                Value<DateTime?> noticeDate = const Value.absent(),
                Value<DateTime?> awardDate = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<bool> hasDetail = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> country = const Value.absent(),
                Value<String?> search = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FactAwardCompanion(
                caseKey: caseKey,
                caseNo: caseNo,
                name: name,
                agencyId: agencyId,
                winnerId: winnerId,
                category: category,
                tenderMethod: tenderMethod,
                awardWay: awardWay,
                amount: amount,
                budget: budget,
                floorPrice: floorPrice,
                bidderCount: bidderCount,
                noticeDate: noticeDate,
                awardDate: awardDate,
                url: url,
                source: source,
                hasDetail: hasDetail,
                updatedAt: updatedAt,
                country: country,
                search: search,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String caseKey,
                required String caseNo,
                required String name,
                required int agencyId,
                Value<int?> winnerId = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> tenderMethod = const Value.absent(),
                Value<String> awardWay = const Value.absent(),
                required double amount,
                Value<double?> budget = const Value.absent(),
                Value<double?> floorPrice = const Value.absent(),
                Value<int?> bidderCount = const Value.absent(),
                Value<DateTime?> noticeDate = const Value.absent(),
                Value<DateTime?> awardDate = const Value.absent(),
                Value<String> url = const Value.absent(),
                required String source,
                Value<bool> hasDetail = const Value.absent(),
                required DateTime updatedAt,
                Value<String> country = const Value.absent(),
                Value<String?> search = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FactAwardCompanion.insert(
                caseKey: caseKey,
                caseNo: caseNo,
                name: name,
                agencyId: agencyId,
                winnerId: winnerId,
                category: category,
                tenderMethod: tenderMethod,
                awardWay: awardWay,
                amount: amount,
                budget: budget,
                floorPrice: floorPrice,
                bidderCount: bidderCount,
                noticeDate: noticeDate,
                awardDate: awardDate,
                url: url,
                source: source,
                hasDetail: hasDetail,
                updatedAt: updatedAt,
                country: country,
                search: search,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FactAwardTable, FactAwardData>(table),
                  $$FactAwardTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                agencyId = false,
                winnerId = false,
                factBidRefs = false,
                factReviewRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (factBidRefs) db.factBid,
                    if (factReviewRefs) db.factReview,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (agencyId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.agencyId,
                                    referencedTable: $$FactAwardTableReferences
                                        ._agencyIdTable(db),
                                    referencedColumn: $$FactAwardTableReferences
                                        ._agencyIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (winnerId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.winnerId,
                                    referencedTable: $$FactAwardTableReferences
                                        ._winnerIdTable(db),
                                    referencedColumn: $$FactAwardTableReferences
                                        ._winnerIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (factBidRefs)
                        await $_getPrefetchedDataByColumns<
                          FactAwardData,
                          $FactAwardTable,
                          FactBidData,
                          $FactBidTable
                        >(
                          currentTable: table,
                          referencedTable: $$FactAwardTableReferences
                              ._factBidRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FactAwardTableReferences(
                                db,
                                table,
                                p0,
                              ).factBidRefs,
                          currentColumn: 'case_key',
                          referencedColumn: 'case_key',
                          typedResults: items,
                        ),
                      if (factReviewRefs)
                        await $_getPrefetchedDataByColumns<
                          FactAwardData,
                          $FactAwardTable,
                          FactReviewData,
                          $FactReviewTable
                        >(
                          currentTable: table,
                          referencedTable: $$FactAwardTableReferences
                              ._factReviewRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FactAwardTableReferences(
                                db,
                                table,
                                p0,
                              ).factReviewRefs,
                          currentColumn: 'case_key',
                          referencedColumn: 'case_key',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$FactAwardTableProcessedTableManager =
    ProcessedTableManager<
      _$CaseDb,
      $FactAwardTable,
      FactAwardData,
      $$FactAwardTableFilterComposer,
      $$FactAwardTableOrderingComposer,
      $$FactAwardTableAnnotationComposer,
      $$FactAwardTableCreateCompanionBuilder,
      $$FactAwardTableUpdateCompanionBuilder,
      (FactAwardData, $$FactAwardTableReferences),
      FactAwardData,
      PrefetchHooks Function({
        bool agencyId,
        bool winnerId,
        bool factBidRefs,
        bool factReviewRefs,
      })
    >;
typedef $$FactBidTableCreateCompanionBuilder =
    FactBidCompanion Function({
      required String caseKey,
      required int vendorId,
      required bool won,
      Value<int> rowid,
    });
typedef $$FactBidTableUpdateCompanionBuilder =
    FactBidCompanion Function({
      Value<String> caseKey,
      Value<int> vendorId,
      Value<bool> won,
      Value<int> rowid,
    });

final class $$FactBidTableReferences
    extends BaseReferences<_$CaseDb, $FactBidTable, FactBidData> {
  $$FactBidTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FactAwardTable _caseKeyTable(_$CaseDb db) =>
      db.factAward.createAlias('fact_bid__case_key__fact_award__case_key');

  $$FactAwardTableProcessedTableManager get caseKey {
    final $_column = $_itemColumn<String>('case_key')!;

    final manager = $$FactAwardTableTableManager(
      $_db,
      $_db.factAward,
    ).filter((f) => f.caseKey.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_caseKeyTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $DimVendorTable _vendorIdTable(_$CaseDb db) =>
      db.dimVendor.createAlias('fact_bid__vendor_id__dim_vendor__id');

  $$DimVendorTableProcessedTableManager get vendorId {
    final $_column = $_itemColumn<int>('vendor_id')!;

    final manager = $$DimVendorTableTableManager(
      $_db,
      $_db.dimVendor,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_vendorIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FactBidTableFilterComposer extends Composer<_$CaseDb, $FactBidTable> {
  $$FactBidTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<bool> get won => $composableBuilder(
    column: $table.won,
    builder: (column) => ColumnFilters(column),
  );

  $$FactAwardTableFilterComposer get caseKey {
    final $$FactAwardTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.caseKey,
      referencedTable: $db.factAward,
      getReferencedColumn: (t) => t.caseKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FactAwardTableFilterComposer(
            $db: $db,
            $table: $db.factAward,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DimVendorTableFilterComposer get vendorId {
    final $$DimVendorTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vendorId,
      referencedTable: $db.dimVendor,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DimVendorTableFilterComposer(
            $db: $db,
            $table: $db.dimVendor,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FactBidTableOrderingComposer extends Composer<_$CaseDb, $FactBidTable> {
  $$FactBidTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<bool> get won => $composableBuilder(
    column: $table.won,
    builder: (column) => ColumnOrderings(column),
  );

  $$FactAwardTableOrderingComposer get caseKey {
    final $$FactAwardTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.caseKey,
      referencedTable: $db.factAward,
      getReferencedColumn: (t) => t.caseKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FactAwardTableOrderingComposer(
            $db: $db,
            $table: $db.factAward,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DimVendorTableOrderingComposer get vendorId {
    final $$DimVendorTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vendorId,
      referencedTable: $db.dimVendor,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DimVendorTableOrderingComposer(
            $db: $db,
            $table: $db.dimVendor,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FactBidTableAnnotationComposer
    extends Composer<_$CaseDb, $FactBidTable> {
  $$FactBidTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<bool> get won =>
      $composableBuilder(column: $table.won, builder: (column) => column);

  $$FactAwardTableAnnotationComposer get caseKey {
    final $$FactAwardTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.caseKey,
      referencedTable: $db.factAward,
      getReferencedColumn: (t) => t.caseKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FactAwardTableAnnotationComposer(
            $db: $db,
            $table: $db.factAward,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DimVendorTableAnnotationComposer get vendorId {
    final $$DimVendorTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vendorId,
      referencedTable: $db.dimVendor,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DimVendorTableAnnotationComposer(
            $db: $db,
            $table: $db.dimVendor,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FactBidTableTableManager
    extends
        RootTableManager<
          _$CaseDb,
          $FactBidTable,
          FactBidData,
          $$FactBidTableFilterComposer,
          $$FactBidTableOrderingComposer,
          $$FactBidTableAnnotationComposer,
          $$FactBidTableCreateCompanionBuilder,
          $$FactBidTableUpdateCompanionBuilder,
          (FactBidData, $$FactBidTableReferences),
          FactBidData,
          PrefetchHooks Function({bool caseKey, bool vendorId})
        > {
  $$FactBidTableTableManager(_$CaseDb db, $FactBidTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FactBidTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FactBidTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FactBidTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> caseKey = const Value.absent(),
                Value<int> vendorId = const Value.absent(),
                Value<bool> won = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FactBidCompanion(
                caseKey: caseKey,
                vendorId: vendorId,
                won: won,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String caseKey,
                required int vendorId,
                required bool won,
                Value<int> rowid = const Value.absent(),
              }) => FactBidCompanion.insert(
                caseKey: caseKey,
                vendorId: vendorId,
                won: won,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FactBidTable, FactBidData>(table),
                  $$FactBidTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({caseKey = false, vendorId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (caseKey) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.caseKey,
                                referencedTable: $$FactBidTableReferences
                                    ._caseKeyTable(db),
                                referencedColumn: $$FactBidTableReferences
                                    ._caseKeyTable(db)
                                    .caseKey,
                              )
                              as T;
                    }
                    if (vendorId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.vendorId,
                                referencedTable: $$FactBidTableReferences
                                    ._vendorIdTable(db),
                                referencedColumn: $$FactBidTableReferences
                                    ._vendorIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FactBidTableProcessedTableManager =
    ProcessedTableManager<
      _$CaseDb,
      $FactBidTable,
      FactBidData,
      $$FactBidTableFilterComposer,
      $$FactBidTableOrderingComposer,
      $$FactBidTableAnnotationComposer,
      $$FactBidTableCreateCompanionBuilder,
      $$FactBidTableUpdateCompanionBuilder,
      (FactBidData, $$FactBidTableReferences),
      FactBidData,
      PrefetchHooks Function({bool caseKey, bool vendorId})
    >;
typedef $$FactReviewTableCreateCompanionBuilder =
    FactReviewCompanion Function({
      required String caseKey,
      required int reviewerId,
      required bool attended,
      Value<int> rowid,
    });
typedef $$FactReviewTableUpdateCompanionBuilder =
    FactReviewCompanion Function({
      Value<String> caseKey,
      Value<int> reviewerId,
      Value<bool> attended,
      Value<int> rowid,
    });

final class $$FactReviewTableReferences
    extends BaseReferences<_$CaseDb, $FactReviewTable, FactReviewData> {
  $$FactReviewTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FactAwardTable _caseKeyTable(_$CaseDb db) =>
      db.factAward.createAlias('fact_review__case_key__fact_award__case_key');

  $$FactAwardTableProcessedTableManager get caseKey {
    final $_column = $_itemColumn<String>('case_key')!;

    final manager = $$FactAwardTableTableManager(
      $_db,
      $_db.factAward,
    ).filter((f) => f.caseKey.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_caseKeyTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $DimReviewerTable _reviewerIdTable(_$CaseDb db) =>
      db.dimReviewer.createAlias('fact_review__reviewer_id__dim_reviewer__id');

  $$DimReviewerTableProcessedTableManager get reviewerId {
    final $_column = $_itemColumn<int>('reviewer_id')!;

    final manager = $$DimReviewerTableTableManager(
      $_db,
      $_db.dimReviewer,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_reviewerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FactReviewTableFilterComposer
    extends Composer<_$CaseDb, $FactReviewTable> {
  $$FactReviewTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<bool> get attended => $composableBuilder(
    column: $table.attended,
    builder: (column) => ColumnFilters(column),
  );

  $$FactAwardTableFilterComposer get caseKey {
    final $$FactAwardTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.caseKey,
      referencedTable: $db.factAward,
      getReferencedColumn: (t) => t.caseKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FactAwardTableFilterComposer(
            $db: $db,
            $table: $db.factAward,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DimReviewerTableFilterComposer get reviewerId {
    final $$DimReviewerTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reviewerId,
      referencedTable: $db.dimReviewer,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DimReviewerTableFilterComposer(
            $db: $db,
            $table: $db.dimReviewer,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FactReviewTableOrderingComposer
    extends Composer<_$CaseDb, $FactReviewTable> {
  $$FactReviewTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<bool> get attended => $composableBuilder(
    column: $table.attended,
    builder: (column) => ColumnOrderings(column),
  );

  $$FactAwardTableOrderingComposer get caseKey {
    final $$FactAwardTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.caseKey,
      referencedTable: $db.factAward,
      getReferencedColumn: (t) => t.caseKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FactAwardTableOrderingComposer(
            $db: $db,
            $table: $db.factAward,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DimReviewerTableOrderingComposer get reviewerId {
    final $$DimReviewerTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reviewerId,
      referencedTable: $db.dimReviewer,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DimReviewerTableOrderingComposer(
            $db: $db,
            $table: $db.dimReviewer,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FactReviewTableAnnotationComposer
    extends Composer<_$CaseDb, $FactReviewTable> {
  $$FactReviewTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<bool> get attended =>
      $composableBuilder(column: $table.attended, builder: (column) => column);

  $$FactAwardTableAnnotationComposer get caseKey {
    final $$FactAwardTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.caseKey,
      referencedTable: $db.factAward,
      getReferencedColumn: (t) => t.caseKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FactAwardTableAnnotationComposer(
            $db: $db,
            $table: $db.factAward,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DimReviewerTableAnnotationComposer get reviewerId {
    final $$DimReviewerTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reviewerId,
      referencedTable: $db.dimReviewer,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DimReviewerTableAnnotationComposer(
            $db: $db,
            $table: $db.dimReviewer,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FactReviewTableTableManager
    extends
        RootTableManager<
          _$CaseDb,
          $FactReviewTable,
          FactReviewData,
          $$FactReviewTableFilterComposer,
          $$FactReviewTableOrderingComposer,
          $$FactReviewTableAnnotationComposer,
          $$FactReviewTableCreateCompanionBuilder,
          $$FactReviewTableUpdateCompanionBuilder,
          (FactReviewData, $$FactReviewTableReferences),
          FactReviewData,
          PrefetchHooks Function({bool caseKey, bool reviewerId})
        > {
  $$FactReviewTableTableManager(_$CaseDb db, $FactReviewTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FactReviewTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FactReviewTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FactReviewTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> caseKey = const Value.absent(),
                Value<int> reviewerId = const Value.absent(),
                Value<bool> attended = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FactReviewCompanion(
                caseKey: caseKey,
                reviewerId: reviewerId,
                attended: attended,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String caseKey,
                required int reviewerId,
                required bool attended,
                Value<int> rowid = const Value.absent(),
              }) => FactReviewCompanion.insert(
                caseKey: caseKey,
                reviewerId: reviewerId,
                attended: attended,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FactReviewTable, FactReviewData>(table),
                  $$FactReviewTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({caseKey = false, reviewerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (caseKey) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.caseKey,
                                referencedTable: $$FactReviewTableReferences
                                    ._caseKeyTable(db),
                                referencedColumn: $$FactReviewTableReferences
                                    ._caseKeyTable(db)
                                    .caseKey,
                              )
                              as T;
                    }
                    if (reviewerId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.reviewerId,
                                referencedTable: $$FactReviewTableReferences
                                    ._reviewerIdTable(db),
                                referencedColumn: $$FactReviewTableReferences
                                    ._reviewerIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FactReviewTableProcessedTableManager =
    ProcessedTableManager<
      _$CaseDb,
      $FactReviewTable,
      FactReviewData,
      $$FactReviewTableFilterComposer,
      $$FactReviewTableOrderingComposer,
      $$FactReviewTableAnnotationComposer,
      $$FactReviewTableCreateCompanionBuilder,
      $$FactReviewTableUpdateCompanionBuilder,
      (FactReviewData, $$FactReviewTableReferences),
      FactReviewData,
      PrefetchHooks Function({bool caseKey, bool reviewerId})
    >;
typedef $$DatasetFileTableCreateCompanionBuilder =
    DatasetFileCompanion Function({
      required String name,
      required int records,
      Value<int?> size,
      required DateTime checkedAt,
      Value<int> rowid,
    });
typedef $$DatasetFileTableUpdateCompanionBuilder =
    DatasetFileCompanion Function({
      Value<String> name,
      Value<int> records,
      Value<int?> size,
      Value<DateTime> checkedAt,
      Value<int> rowid,
    });

class $$DatasetFileTableFilterComposer
    extends Composer<_$CaseDb, $DatasetFileTable> {
  $$DatasetFileTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get records => $composableBuilder(
    column: $table.records,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get checkedAt => $composableBuilder(
    column: $table.checkedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DatasetFileTableOrderingComposer
    extends Composer<_$CaseDb, $DatasetFileTable> {
  $$DatasetFileTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get records => $composableBuilder(
    column: $table.records,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get checkedAt => $composableBuilder(
    column: $table.checkedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DatasetFileTableAnnotationComposer
    extends Composer<_$CaseDb, $DatasetFileTable> {
  $$DatasetFileTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get records =>
      $composableBuilder(column: $table.records, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<DateTime> get checkedAt =>
      $composableBuilder(column: $table.checkedAt, builder: (column) => column);
}

class $$DatasetFileTableTableManager
    extends
        RootTableManager<
          _$CaseDb,
          $DatasetFileTable,
          DatasetFileData,
          $$DatasetFileTableFilterComposer,
          $$DatasetFileTableOrderingComposer,
          $$DatasetFileTableAnnotationComposer,
          $$DatasetFileTableCreateCompanionBuilder,
          $$DatasetFileTableUpdateCompanionBuilder,
          (
            DatasetFileData,
            BaseReferences<_$CaseDb, $DatasetFileTable, DatasetFileData>,
          ),
          DatasetFileData,
          PrefetchHooks Function()
        > {
  $$DatasetFileTableTableManager(_$CaseDb db, $DatasetFileTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DatasetFileTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DatasetFileTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DatasetFileTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> name = const Value.absent(),
                Value<int> records = const Value.absent(),
                Value<int?> size = const Value.absent(),
                Value<DateTime> checkedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DatasetFileCompanion(
                name: name,
                records: records,
                size: size,
                checkedAt: checkedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String name,
                required int records,
                Value<int?> size = const Value.absent(),
                required DateTime checkedAt,
                Value<int> rowid = const Value.absent(),
              }) => DatasetFileCompanion.insert(
                name: name,
                records: records,
                size: size,
                checkedAt: checkedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DatasetFileTable, DatasetFileData>(table),
                  BaseReferences<_$CaseDb, $DatasetFileTable, DatasetFileData>(
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

typedef $$DatasetFileTableProcessedTableManager =
    ProcessedTableManager<
      _$CaseDb,
      $DatasetFileTable,
      DatasetFileData,
      $$DatasetFileTableFilterComposer,
      $$DatasetFileTableOrderingComposer,
      $$DatasetFileTableAnnotationComposer,
      $$DatasetFileTableCreateCompanionBuilder,
      $$DatasetFileTableUpdateCompanionBuilder,
      (
        DatasetFileData,
        BaseReferences<_$CaseDb, $DatasetFileTable, DatasetFileData>,
      ),
      DatasetFileData,
      PrefetchHooks Function()
    >;
typedef $$SearchTotalTableCreateCompanionBuilder =
    SearchTotalCompanion Function({
      required String key,
      required int total,
      required DateTime fetchedAt,
      Value<int> rowid,
    });
typedef $$SearchTotalTableUpdateCompanionBuilder =
    SearchTotalCompanion Function({
      Value<String> key,
      Value<int> total,
      Value<DateTime> fetchedAt,
      Value<int> rowid,
    });

class $$SearchTotalTableFilterComposer
    extends Composer<_$CaseDb, $SearchTotalTable> {
  $$SearchTotalTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SearchTotalTableOrderingComposer
    extends Composer<_$CaseDb, $SearchTotalTable> {
  $$SearchTotalTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SearchTotalTableAnnotationComposer
    extends Composer<_$CaseDb, $SearchTotalTable> {
  $$SearchTotalTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$SearchTotalTableTableManager
    extends
        RootTableManager<
          _$CaseDb,
          $SearchTotalTable,
          SearchTotalData,
          $$SearchTotalTableFilterComposer,
          $$SearchTotalTableOrderingComposer,
          $$SearchTotalTableAnnotationComposer,
          $$SearchTotalTableCreateCompanionBuilder,
          $$SearchTotalTableUpdateCompanionBuilder,
          (
            SearchTotalData,
            BaseReferences<_$CaseDb, $SearchTotalTable, SearchTotalData>,
          ),
          SearchTotalData,
          PrefetchHooks Function()
        > {
  $$SearchTotalTableTableManager(_$CaseDb db, $SearchTotalTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SearchTotalTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SearchTotalTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SearchTotalTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchTotalCompanion(
                key: key,
                total: total,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required int total,
                required DateTime fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => SearchTotalCompanion.insert(
                key: key,
                total: total,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SearchTotalTable, SearchTotalData>(table),
                  BaseReferences<_$CaseDb, $SearchTotalTable, SearchTotalData>(
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

typedef $$SearchTotalTableProcessedTableManager =
    ProcessedTableManager<
      _$CaseDb,
      $SearchTotalTable,
      SearchTotalData,
      $$SearchTotalTableFilterComposer,
      $$SearchTotalTableOrderingComposer,
      $$SearchTotalTableAnnotationComposer,
      $$SearchTotalTableCreateCompanionBuilder,
      $$SearchTotalTableUpdateCompanionBuilder,
      (
        SearchTotalData,
        BaseReferences<_$CaseDb, $SearchTotalTable, SearchTotalData>,
      ),
      SearchTotalData,
      PrefetchHooks Function()
    >;

class $CaseDbManager {
  final _$CaseDb _db;
  $CaseDbManager(this._db);
  $$DimAgencyTableTableManager get dimAgency =>
      $$DimAgencyTableTableManager(_db, _db.dimAgency);
  $$DimVendorTableTableManager get dimVendor =>
      $$DimVendorTableTableManager(_db, _db.dimVendor);
  $$DimReviewerTableTableManager get dimReviewer =>
      $$DimReviewerTableTableManager(_db, _db.dimReviewer);
  $$FactAwardTableTableManager get factAward =>
      $$FactAwardTableTableManager(_db, _db.factAward);
  $$FactBidTableTableManager get factBid =>
      $$FactBidTableTableManager(_db, _db.factBid);
  $$FactReviewTableTableManager get factReview =>
      $$FactReviewTableTableManager(_db, _db.factReview);
  $$DatasetFileTableTableManager get datasetFile =>
      $$DatasetFileTableTableManager(_db, _db.datasetFile);
  $$SearchTotalTableTableManager get searchTotal =>
      $$SearchTotalTableTableManager(_db, _db.searchTotal);
}
