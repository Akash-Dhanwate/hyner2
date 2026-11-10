// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pricing_database.dart';

// ignore_for_file: type=lint
class PricingProfiles extends Table
    with TableInfo<PricingProfiles, PricingProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  PricingProfiles(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'draft\' CHECK (status IN (\'draft\', \'published\', \'archived\'))',
    defaultValue: const CustomExpression('\'draft\''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    businessId,
    id,
    name,
    status,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pricing_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<PricingProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
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
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
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
  Set<GeneratedColumn> get $primaryKey => {businessId, id};
  @override
  PricingProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PricingProfile(
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  PricingProfiles createAlias(String alias) {
    return PricingProfiles(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(business_id, id)'];
  @override
  bool get dontWriteConstraints => true;
}

class PricingProfile extends DataClass implements Insertable<PricingProfile> {
  final String businessId;
  final String id;
  final String name;
  final String status;
  final int createdAt;
  final int updatedAt;
  const PricingProfile({
    required this.businessId,
    required this.id,
    required this.name,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['business_id'] = Variable<String>(businessId);
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  PricingProfilesCompanion toCompanion(bool nullToAbsent) {
    return PricingProfilesCompanion(
      businessId: Value(businessId),
      id: Value(id),
      name: Value(name),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PricingProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PricingProfile(
      businessId: serializer.fromJson<String>(json['business_id']),
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'business_id': serializer.toJson<String>(businessId),
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'status': serializer.toJson<String>(status),
      'created_at': serializer.toJson<int>(createdAt),
      'updated_at': serializer.toJson<int>(updatedAt),
    };
  }

  PricingProfile copyWith({
    String? businessId,
    String? id,
    String? name,
    String? status,
    int? createdAt,
    int? updatedAt,
  }) => PricingProfile(
    businessId: businessId ?? this.businessId,
    id: id ?? this.id,
    name: name ?? this.name,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PricingProfile copyWithCompanion(PricingProfilesCompanion data) {
    return PricingProfile(
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PricingProfile(')
          ..write('businessId: $businessId, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(businessId, id, name, status, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PricingProfile &&
          other.businessId == this.businessId &&
          other.id == this.id &&
          other.name == this.name &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PricingProfilesCompanion extends UpdateCompanion<PricingProfile> {
  final Value<String> businessId;
  final Value<String> id;
  final Value<String> name;
  final Value<String> status;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const PricingProfilesCompanion({
    this.businessId = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PricingProfilesCompanion.insert({
    required String businessId,
    required String id,
    required String name,
    this.status = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : businessId = Value(businessId),
       id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<PricingProfile> custom({
    Expression<String>? businessId,
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? status,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (businessId != null) 'business_id': businessId,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PricingProfilesCompanion copyWith({
    Value<String>? businessId,
    Value<String>? id,
    Value<String>? name,
    Value<String>? status,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return PricingProfilesCompanion(
      businessId: businessId ?? this.businessId,
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PricingProfilesCompanion(')
          ..write('businessId: $businessId, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class PricingDrafts extends Table with TableInfo<PricingDrafts, PricingDraft> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  PricingDrafts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (revision > 0)',
  );
  static const VerificationMeta _snapshotJsonMeta = const VerificationMeta(
    'snapshotJson',
  );
  late final GeneratedColumn<String> snapshotJson = GeneratedColumn<String>(
    'snapshot_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    businessId,
    profileId,
    revision,
    snapshotJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pricing_drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<PricingDraft> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('snapshot_json')) {
      context.handle(
        _snapshotJsonMeta,
        snapshotJson.isAcceptableOrUnknown(
          data['snapshot_json']!,
          _snapshotJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_snapshotJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {businessId, profileId};
  @override
  PricingDraft map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PricingDraft(
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      snapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_json'],
      )!,
    );
  }

  @override
  PricingDrafts createAlias(String alias) {
    return PricingDrafts(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(business_id, profile_id)',
    'FOREIGN KEY(business_id, profile_id)REFERENCES pricing_profiles(business_id, id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class PricingDraft extends DataClass implements Insertable<PricingDraft> {
  final String businessId;
  final String profileId;
  final int revision;
  final String snapshotJson;
  const PricingDraft({
    required this.businessId,
    required this.profileId,
    required this.revision,
    required this.snapshotJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['business_id'] = Variable<String>(businessId);
    map['profile_id'] = Variable<String>(profileId);
    map['revision'] = Variable<int>(revision);
    map['snapshot_json'] = Variable<String>(snapshotJson);
    return map;
  }

  PricingDraftsCompanion toCompanion(bool nullToAbsent) {
    return PricingDraftsCompanion(
      businessId: Value(businessId),
      profileId: Value(profileId),
      revision: Value(revision),
      snapshotJson: Value(snapshotJson),
    );
  }

  factory PricingDraft.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PricingDraft(
      businessId: serializer.fromJson<String>(json['business_id']),
      profileId: serializer.fromJson<String>(json['profile_id']),
      revision: serializer.fromJson<int>(json['revision']),
      snapshotJson: serializer.fromJson<String>(json['snapshot_json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'business_id': serializer.toJson<String>(businessId),
      'profile_id': serializer.toJson<String>(profileId),
      'revision': serializer.toJson<int>(revision),
      'snapshot_json': serializer.toJson<String>(snapshotJson),
    };
  }

  PricingDraft copyWith({
    String? businessId,
    String? profileId,
    int? revision,
    String? snapshotJson,
  }) => PricingDraft(
    businessId: businessId ?? this.businessId,
    profileId: profileId ?? this.profileId,
    revision: revision ?? this.revision,
    snapshotJson: snapshotJson ?? this.snapshotJson,
  );
  PricingDraft copyWithCompanion(PricingDraftsCompanion data) {
    return PricingDraft(
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      revision: data.revision.present ? data.revision.value : this.revision,
      snapshotJson: data.snapshotJson.present
          ? data.snapshotJson.value
          : this.snapshotJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PricingDraft(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('revision: $revision, ')
          ..write('snapshotJson: $snapshotJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(businessId, profileId, revision, snapshotJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PricingDraft &&
          other.businessId == this.businessId &&
          other.profileId == this.profileId &&
          other.revision == this.revision &&
          other.snapshotJson == this.snapshotJson);
}

class PricingDraftsCompanion extends UpdateCompanion<PricingDraft> {
  final Value<String> businessId;
  final Value<String> profileId;
  final Value<int> revision;
  final Value<String> snapshotJson;
  final Value<int> rowid;
  const PricingDraftsCompanion({
    this.businessId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.revision = const Value.absent(),
    this.snapshotJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PricingDraftsCompanion.insert({
    required String businessId,
    required String profileId,
    required int revision,
    required String snapshotJson,
    this.rowid = const Value.absent(),
  }) : businessId = Value(businessId),
       profileId = Value(profileId),
       revision = Value(revision),
       snapshotJson = Value(snapshotJson);
  static Insertable<PricingDraft> custom({
    Expression<String>? businessId,
    Expression<String>? profileId,
    Expression<int>? revision,
    Expression<String>? snapshotJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (businessId != null) 'business_id': businessId,
      if (profileId != null) 'profile_id': profileId,
      if (revision != null) 'revision': revision,
      if (snapshotJson != null) 'snapshot_json': snapshotJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PricingDraftsCompanion copyWith({
    Value<String>? businessId,
    Value<String>? profileId,
    Value<int>? revision,
    Value<String>? snapshotJson,
    Value<int>? rowid,
  }) {
    return PricingDraftsCompanion(
      businessId: businessId ?? this.businessId,
      profileId: profileId ?? this.profileId,
      revision: revision ?? this.revision,
      snapshotJson: snapshotJson ?? this.snapshotJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (snapshotJson.present) {
      map['snapshot_json'] = Variable<String>(snapshotJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PricingDraftsCompanion(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('revision: $revision, ')
          ..write('snapshotJson: $snapshotJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class PricingRateCardVersions extends Table
    with TableInfo<PricingRateCardVersions, PricingRateCardVersion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  PricingRateCardVersions(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (version > 0)',
  );
  static const VerificationMeta _effectiveAtMeta = const VerificationMeta(
    'effectiveAt',
  );
  late final GeneratedColumn<int> effectiveAt = GeneratedColumn<int>(
    'effective_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  late final GeneratedColumn<int> expiresAt = GeneratedColumn<int>(
    'expires_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _publishedAtMeta = const VerificationMeta(
    'publishedAt',
  );
  late final GeneratedColumn<int> publishedAt = GeneratedColumn<int>(
    'published_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _publishedByMeta = const VerificationMeta(
    'publishedBy',
  );
  late final GeneratedColumn<String> publishedBy = GeneratedColumn<String>(
    'published_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _snapshotJsonMeta = const VerificationMeta(
    'snapshotJson',
  );
  late final GeneratedColumn<String> snapshotJson = GeneratedColumn<String>(
    'snapshot_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _sealedMeta = const VerificationMeta('sealed');
  late final GeneratedColumn<int> sealed = GeneratedColumn<int>(
    'sealed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (sealed IN (0, 1))',
    defaultValue: const CustomExpression('0'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    businessId,
    profileId,
    version,
    effectiveAt,
    expiresAt,
    publishedAt,
    publishedBy,
    snapshotJson,
    sealed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pricing_rate_card_versions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PricingRateCardVersion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('effective_at')) {
      context.handle(
        _effectiveAtMeta,
        effectiveAt.isAcceptableOrUnknown(
          data['effective_at']!,
          _effectiveAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_effectiveAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    }
    if (data.containsKey('published_at')) {
      context.handle(
        _publishedAtMeta,
        publishedAt.isAcceptableOrUnknown(
          data['published_at']!,
          _publishedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_publishedAtMeta);
    }
    if (data.containsKey('published_by')) {
      context.handle(
        _publishedByMeta,
        publishedBy.isAcceptableOrUnknown(
          data['published_by']!,
          _publishedByMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_publishedByMeta);
    }
    if (data.containsKey('snapshot_json')) {
      context.handle(
        _snapshotJsonMeta,
        snapshotJson.isAcceptableOrUnknown(
          data['snapshot_json']!,
          _snapshotJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_snapshotJsonMeta);
    }
    if (data.containsKey('sealed')) {
      context.handle(
        _sealedMeta,
        sealed.isAcceptableOrUnknown(data['sealed']!, _sealedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {businessId, profileId, version};
  @override
  PricingRateCardVersion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PricingRateCardVersion(
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      effectiveAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}effective_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expires_at'],
      ),
      publishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}published_at'],
      )!,
      publishedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}published_by'],
      )!,
      snapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_json'],
      )!,
      sealed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sealed'],
      )!,
    );
  }

  @override
  PricingRateCardVersions createAlias(String alias) {
    return PricingRateCardVersions(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(business_id, profile_id, version)',
    'FOREIGN KEY(business_id, profile_id)REFERENCES pricing_profiles(business_id, id)',
    'CHECK(expires_at IS NULL OR expires_at > effective_at)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class PricingRateCardVersion extends DataClass
    implements Insertable<PricingRateCardVersion> {
  final String businessId;
  final String profileId;
  final int version;
  final int effectiveAt;
  final int? expiresAt;
  final int publishedAt;
  final String publishedBy;
  final String snapshotJson;
  final int sealed;
  const PricingRateCardVersion({
    required this.businessId,
    required this.profileId,
    required this.version,
    required this.effectiveAt,
    this.expiresAt,
    required this.publishedAt,
    required this.publishedBy,
    required this.snapshotJson,
    required this.sealed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['business_id'] = Variable<String>(businessId);
    map['profile_id'] = Variable<String>(profileId);
    map['version'] = Variable<int>(version);
    map['effective_at'] = Variable<int>(effectiveAt);
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<int>(expiresAt);
    }
    map['published_at'] = Variable<int>(publishedAt);
    map['published_by'] = Variable<String>(publishedBy);
    map['snapshot_json'] = Variable<String>(snapshotJson);
    map['sealed'] = Variable<int>(sealed);
    return map;
  }

  PricingRateCardVersionsCompanion toCompanion(bool nullToAbsent) {
    return PricingRateCardVersionsCompanion(
      businessId: Value(businessId),
      profileId: Value(profileId),
      version: Value(version),
      effectiveAt: Value(effectiveAt),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
      publishedAt: Value(publishedAt),
      publishedBy: Value(publishedBy),
      snapshotJson: Value(snapshotJson),
      sealed: Value(sealed),
    );
  }

  factory PricingRateCardVersion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PricingRateCardVersion(
      businessId: serializer.fromJson<String>(json['business_id']),
      profileId: serializer.fromJson<String>(json['profile_id']),
      version: serializer.fromJson<int>(json['version']),
      effectiveAt: serializer.fromJson<int>(json['effective_at']),
      expiresAt: serializer.fromJson<int?>(json['expires_at']),
      publishedAt: serializer.fromJson<int>(json['published_at']),
      publishedBy: serializer.fromJson<String>(json['published_by']),
      snapshotJson: serializer.fromJson<String>(json['snapshot_json']),
      sealed: serializer.fromJson<int>(json['sealed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'business_id': serializer.toJson<String>(businessId),
      'profile_id': serializer.toJson<String>(profileId),
      'version': serializer.toJson<int>(version),
      'effective_at': serializer.toJson<int>(effectiveAt),
      'expires_at': serializer.toJson<int?>(expiresAt),
      'published_at': serializer.toJson<int>(publishedAt),
      'published_by': serializer.toJson<String>(publishedBy),
      'snapshot_json': serializer.toJson<String>(snapshotJson),
      'sealed': serializer.toJson<int>(sealed),
    };
  }

  PricingRateCardVersion copyWith({
    String? businessId,
    String? profileId,
    int? version,
    int? effectiveAt,
    Value<int?> expiresAt = const Value.absent(),
    int? publishedAt,
    String? publishedBy,
    String? snapshotJson,
    int? sealed,
  }) => PricingRateCardVersion(
    businessId: businessId ?? this.businessId,
    profileId: profileId ?? this.profileId,
    version: version ?? this.version,
    effectiveAt: effectiveAt ?? this.effectiveAt,
    expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
    publishedAt: publishedAt ?? this.publishedAt,
    publishedBy: publishedBy ?? this.publishedBy,
    snapshotJson: snapshotJson ?? this.snapshotJson,
    sealed: sealed ?? this.sealed,
  );
  PricingRateCardVersion copyWithCompanion(
    PricingRateCardVersionsCompanion data,
  ) {
    return PricingRateCardVersion(
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      version: data.version.present ? data.version.value : this.version,
      effectiveAt: data.effectiveAt.present
          ? data.effectiveAt.value
          : this.effectiveAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      publishedAt: data.publishedAt.present
          ? data.publishedAt.value
          : this.publishedAt,
      publishedBy: data.publishedBy.present
          ? data.publishedBy.value
          : this.publishedBy,
      snapshotJson: data.snapshotJson.present
          ? data.snapshotJson.value
          : this.snapshotJson,
      sealed: data.sealed.present ? data.sealed.value : this.sealed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PricingRateCardVersion(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('version: $version, ')
          ..write('effectiveAt: $effectiveAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('publishedBy: $publishedBy, ')
          ..write('snapshotJson: $snapshotJson, ')
          ..write('sealed: $sealed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    businessId,
    profileId,
    version,
    effectiveAt,
    expiresAt,
    publishedAt,
    publishedBy,
    snapshotJson,
    sealed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PricingRateCardVersion &&
          other.businessId == this.businessId &&
          other.profileId == this.profileId &&
          other.version == this.version &&
          other.effectiveAt == this.effectiveAt &&
          other.expiresAt == this.expiresAt &&
          other.publishedAt == this.publishedAt &&
          other.publishedBy == this.publishedBy &&
          other.snapshotJson == this.snapshotJson &&
          other.sealed == this.sealed);
}

class PricingRateCardVersionsCompanion
    extends UpdateCompanion<PricingRateCardVersion> {
  final Value<String> businessId;
  final Value<String> profileId;
  final Value<int> version;
  final Value<int> effectiveAt;
  final Value<int?> expiresAt;
  final Value<int> publishedAt;
  final Value<String> publishedBy;
  final Value<String> snapshotJson;
  final Value<int> sealed;
  final Value<int> rowid;
  const PricingRateCardVersionsCompanion({
    this.businessId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.version = const Value.absent(),
    this.effectiveAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.publishedBy = const Value.absent(),
    this.snapshotJson = const Value.absent(),
    this.sealed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PricingRateCardVersionsCompanion.insert({
    required String businessId,
    required String profileId,
    required int version,
    required int effectiveAt,
    this.expiresAt = const Value.absent(),
    required int publishedAt,
    required String publishedBy,
    required String snapshotJson,
    this.sealed = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : businessId = Value(businessId),
       profileId = Value(profileId),
       version = Value(version),
       effectiveAt = Value(effectiveAt),
       publishedAt = Value(publishedAt),
       publishedBy = Value(publishedBy),
       snapshotJson = Value(snapshotJson);
  static Insertable<PricingRateCardVersion> custom({
    Expression<String>? businessId,
    Expression<String>? profileId,
    Expression<int>? version,
    Expression<int>? effectiveAt,
    Expression<int>? expiresAt,
    Expression<int>? publishedAt,
    Expression<String>? publishedBy,
    Expression<String>? snapshotJson,
    Expression<int>? sealed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (businessId != null) 'business_id': businessId,
      if (profileId != null) 'profile_id': profileId,
      if (version != null) 'version': version,
      if (effectiveAt != null) 'effective_at': effectiveAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (publishedAt != null) 'published_at': publishedAt,
      if (publishedBy != null) 'published_by': publishedBy,
      if (snapshotJson != null) 'snapshot_json': snapshotJson,
      if (sealed != null) 'sealed': sealed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PricingRateCardVersionsCompanion copyWith({
    Value<String>? businessId,
    Value<String>? profileId,
    Value<int>? version,
    Value<int>? effectiveAt,
    Value<int?>? expiresAt,
    Value<int>? publishedAt,
    Value<String>? publishedBy,
    Value<String>? snapshotJson,
    Value<int>? sealed,
    Value<int>? rowid,
  }) {
    return PricingRateCardVersionsCompanion(
      businessId: businessId ?? this.businessId,
      profileId: profileId ?? this.profileId,
      version: version ?? this.version,
      effectiveAt: effectiveAt ?? this.effectiveAt,
      expiresAt: expiresAt ?? this.expiresAt,
      publishedAt: publishedAt ?? this.publishedAt,
      publishedBy: publishedBy ?? this.publishedBy,
      snapshotJson: snapshotJson ?? this.snapshotJson,
      sealed: sealed ?? this.sealed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (effectiveAt.present) {
      map['effective_at'] = Variable<int>(effectiveAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<int>(expiresAt.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<int>(publishedAt.value);
    }
    if (publishedBy.present) {
      map['published_by'] = Variable<String>(publishedBy.value);
    }
    if (snapshotJson.present) {
      map['snapshot_json'] = Variable<String>(snapshotJson.value);
    }
    if (sealed.present) {
      map['sealed'] = Variable<int>(sealed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PricingRateCardVersionsCompanion(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('version: $version, ')
          ..write('effectiveAt: $effectiveAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('publishedBy: $publishedBy, ')
          ..write('snapshotJson: $snapshotJson, ')
          ..write('sealed: $sealed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class PricingCategories extends Table
    with TableInfo<PricingCategories, PricingCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  PricingCategories(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _snapshotJsonMeta = const VerificationMeta(
    'snapshotJson',
  );
  late final GeneratedColumn<String> snapshotJson = GeneratedColumn<String>(
    'snapshot_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    businessId,
    profileId,
    version,
    id,
    parentId,
    name,
    sortOrder,
    snapshotJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pricing_categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<PricingCategory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
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
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('snapshot_json')) {
      context.handle(
        _snapshotJsonMeta,
        snapshotJson.isAcceptableOrUnknown(
          data['snapshot_json']!,
          _snapshotJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_snapshotJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {businessId, profileId, version, id};
  @override
  PricingCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PricingCategory(
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      snapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_json'],
      )!,
    );
  }

  @override
  PricingCategories createAlias(String alias) {
    return PricingCategories(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(business_id, profile_id, version, id)',
    'FOREIGN KEY(business_id, profile_id, version)REFERENCES pricing_rate_card_versions(business_id, profile_id, version)',
    'FOREIGN KEY(business_id, profile_id, version, parent_id)REFERENCES pricing_categories(business_id, profile_id, version, id)DEFERRABLE INITIALLY DEFERRED',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class PricingCategory extends DataClass implements Insertable<PricingCategory> {
  final String businessId;
  final String profileId;
  final int version;
  final String id;
  final String? parentId;
  final String name;
  final int sortOrder;
  final String snapshotJson;
  const PricingCategory({
    required this.businessId,
    required this.profileId,
    required this.version,
    required this.id,
    this.parentId,
    required this.name,
    required this.sortOrder,
    required this.snapshotJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['business_id'] = Variable<String>(businessId);
    map['profile_id'] = Variable<String>(profileId);
    map['version'] = Variable<int>(version);
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['name'] = Variable<String>(name);
    map['sort_order'] = Variable<int>(sortOrder);
    map['snapshot_json'] = Variable<String>(snapshotJson);
    return map;
  }

  PricingCategoriesCompanion toCompanion(bool nullToAbsent) {
    return PricingCategoriesCompanion(
      businessId: Value(businessId),
      profileId: Value(profileId),
      version: Value(version),
      id: Value(id),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      name: Value(name),
      sortOrder: Value(sortOrder),
      snapshotJson: Value(snapshotJson),
    );
  }

  factory PricingCategory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PricingCategory(
      businessId: serializer.fromJson<String>(json['business_id']),
      profileId: serializer.fromJson<String>(json['profile_id']),
      version: serializer.fromJson<int>(json['version']),
      id: serializer.fromJson<String>(json['id']),
      parentId: serializer.fromJson<String?>(json['parent_id']),
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sort_order']),
      snapshotJson: serializer.fromJson<String>(json['snapshot_json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'business_id': serializer.toJson<String>(businessId),
      'profile_id': serializer.toJson<String>(profileId),
      'version': serializer.toJson<int>(version),
      'id': serializer.toJson<String>(id),
      'parent_id': serializer.toJson<String?>(parentId),
      'name': serializer.toJson<String>(name),
      'sort_order': serializer.toJson<int>(sortOrder),
      'snapshot_json': serializer.toJson<String>(snapshotJson),
    };
  }

  PricingCategory copyWith({
    String? businessId,
    String? profileId,
    int? version,
    String? id,
    Value<String?> parentId = const Value.absent(),
    String? name,
    int? sortOrder,
    String? snapshotJson,
  }) => PricingCategory(
    businessId: businessId ?? this.businessId,
    profileId: profileId ?? this.profileId,
    version: version ?? this.version,
    id: id ?? this.id,
    parentId: parentId.present ? parentId.value : this.parentId,
    name: name ?? this.name,
    sortOrder: sortOrder ?? this.sortOrder,
    snapshotJson: snapshotJson ?? this.snapshotJson,
  );
  PricingCategory copyWithCompanion(PricingCategoriesCompanion data) {
    return PricingCategory(
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      version: data.version.present ? data.version.value : this.version,
      id: data.id.present ? data.id.value : this.id,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      snapshotJson: data.snapshotJson.present
          ? data.snapshotJson.value
          : this.snapshotJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PricingCategory(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('version: $version, ')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('snapshotJson: $snapshotJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    businessId,
    profileId,
    version,
    id,
    parentId,
    name,
    sortOrder,
    snapshotJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PricingCategory &&
          other.businessId == this.businessId &&
          other.profileId == this.profileId &&
          other.version == this.version &&
          other.id == this.id &&
          other.parentId == this.parentId &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder &&
          other.snapshotJson == this.snapshotJson);
}

class PricingCategoriesCompanion extends UpdateCompanion<PricingCategory> {
  final Value<String> businessId;
  final Value<String> profileId;
  final Value<int> version;
  final Value<String> id;
  final Value<String?> parentId;
  final Value<String> name;
  final Value<int> sortOrder;
  final Value<String> snapshotJson;
  final Value<int> rowid;
  const PricingCategoriesCompanion({
    this.businessId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.version = const Value.absent(),
    this.id = const Value.absent(),
    this.parentId = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.snapshotJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PricingCategoriesCompanion.insert({
    required String businessId,
    required String profileId,
    required int version,
    required String id,
    this.parentId = const Value.absent(),
    required String name,
    required int sortOrder,
    required String snapshotJson,
    this.rowid = const Value.absent(),
  }) : businessId = Value(businessId),
       profileId = Value(profileId),
       version = Value(version),
       id = Value(id),
       name = Value(name),
       sortOrder = Value(sortOrder),
       snapshotJson = Value(snapshotJson);
  static Insertable<PricingCategory> custom({
    Expression<String>? businessId,
    Expression<String>? profileId,
    Expression<int>? version,
    Expression<String>? id,
    Expression<String>? parentId,
    Expression<String>? name,
    Expression<int>? sortOrder,
    Expression<String>? snapshotJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (businessId != null) 'business_id': businessId,
      if (profileId != null) 'profile_id': profileId,
      if (version != null) 'version': version,
      if (id != null) 'id': id,
      if (parentId != null) 'parent_id': parentId,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (snapshotJson != null) 'snapshot_json': snapshotJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PricingCategoriesCompanion copyWith({
    Value<String>? businessId,
    Value<String>? profileId,
    Value<int>? version,
    Value<String>? id,
    Value<String?>? parentId,
    Value<String>? name,
    Value<int>? sortOrder,
    Value<String>? snapshotJson,
    Value<int>? rowid,
  }) {
    return PricingCategoriesCompanion(
      businessId: businessId ?? this.businessId,
      profileId: profileId ?? this.profileId,
      version: version ?? this.version,
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      snapshotJson: snapshotJson ?? this.snapshotJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (snapshotJson.present) {
      map['snapshot_json'] = Variable<String>(snapshotJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PricingCategoriesCompanion(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('version: $version, ')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('snapshotJson: $snapshotJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class PricingVariants extends Table
    with TableInfo<PricingVariants, PricingVariant> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  PricingVariants(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _snapshotJsonMeta = const VerificationMeta(
    'snapshotJson',
  );
  late final GeneratedColumn<String> snapshotJson = GeneratedColumn<String>(
    'snapshot_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    businessId,
    profileId,
    version,
    id,
    categoryId,
    snapshotJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pricing_variants';
  @override
  VerificationContext validateIntegrity(
    Insertable<PricingVariant> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('snapshot_json')) {
      context.handle(
        _snapshotJsonMeta,
        snapshotJson.isAcceptableOrUnknown(
          data['snapshot_json']!,
          _snapshotJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_snapshotJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {businessId, profileId, version, id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {businessId, profileId, version, categoryId, id},
  ];
  @override
  PricingVariant map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PricingVariant(
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      snapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_json'],
      )!,
    );
  }

  @override
  PricingVariants createAlias(String alias) {
    return PricingVariants(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(business_id, profile_id, version, id)',
    'UNIQUE(business_id, profile_id, version, category_id, id)',
    'FOREIGN KEY(business_id, profile_id, version, category_id)REFERENCES pricing_categories(business_id, profile_id, version, id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class PricingVariant extends DataClass implements Insertable<PricingVariant> {
  final String businessId;
  final String profileId;
  final int version;
  final String id;
  final String categoryId;
  final String snapshotJson;
  const PricingVariant({
    required this.businessId,
    required this.profileId,
    required this.version,
    required this.id,
    required this.categoryId,
    required this.snapshotJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['business_id'] = Variable<String>(businessId);
    map['profile_id'] = Variable<String>(profileId);
    map['version'] = Variable<int>(version);
    map['id'] = Variable<String>(id);
    map['category_id'] = Variable<String>(categoryId);
    map['snapshot_json'] = Variable<String>(snapshotJson);
    return map;
  }

  PricingVariantsCompanion toCompanion(bool nullToAbsent) {
    return PricingVariantsCompanion(
      businessId: Value(businessId),
      profileId: Value(profileId),
      version: Value(version),
      id: Value(id),
      categoryId: Value(categoryId),
      snapshotJson: Value(snapshotJson),
    );
  }

  factory PricingVariant.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PricingVariant(
      businessId: serializer.fromJson<String>(json['business_id']),
      profileId: serializer.fromJson<String>(json['profile_id']),
      version: serializer.fromJson<int>(json['version']),
      id: serializer.fromJson<String>(json['id']),
      categoryId: serializer.fromJson<String>(json['category_id']),
      snapshotJson: serializer.fromJson<String>(json['snapshot_json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'business_id': serializer.toJson<String>(businessId),
      'profile_id': serializer.toJson<String>(profileId),
      'version': serializer.toJson<int>(version),
      'id': serializer.toJson<String>(id),
      'category_id': serializer.toJson<String>(categoryId),
      'snapshot_json': serializer.toJson<String>(snapshotJson),
    };
  }

  PricingVariant copyWith({
    String? businessId,
    String? profileId,
    int? version,
    String? id,
    String? categoryId,
    String? snapshotJson,
  }) => PricingVariant(
    businessId: businessId ?? this.businessId,
    profileId: profileId ?? this.profileId,
    version: version ?? this.version,
    id: id ?? this.id,
    categoryId: categoryId ?? this.categoryId,
    snapshotJson: snapshotJson ?? this.snapshotJson,
  );
  PricingVariant copyWithCompanion(PricingVariantsCompanion data) {
    return PricingVariant(
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      version: data.version.present ? data.version.value : this.version,
      id: data.id.present ? data.id.value : this.id,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      snapshotJson: data.snapshotJson.present
          ? data.snapshotJson.value
          : this.snapshotJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PricingVariant(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('version: $version, ')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('snapshotJson: $snapshotJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(businessId, profileId, version, id, categoryId, snapshotJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PricingVariant &&
          other.businessId == this.businessId &&
          other.profileId == this.profileId &&
          other.version == this.version &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.snapshotJson == this.snapshotJson);
}

class PricingVariantsCompanion extends UpdateCompanion<PricingVariant> {
  final Value<String> businessId;
  final Value<String> profileId;
  final Value<int> version;
  final Value<String> id;
  final Value<String> categoryId;
  final Value<String> snapshotJson;
  final Value<int> rowid;
  const PricingVariantsCompanion({
    this.businessId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.version = const Value.absent(),
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.snapshotJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PricingVariantsCompanion.insert({
    required String businessId,
    required String profileId,
    required int version,
    required String id,
    required String categoryId,
    required String snapshotJson,
    this.rowid = const Value.absent(),
  }) : businessId = Value(businessId),
       profileId = Value(profileId),
       version = Value(version),
       id = Value(id),
       categoryId = Value(categoryId),
       snapshotJson = Value(snapshotJson);
  static Insertable<PricingVariant> custom({
    Expression<String>? businessId,
    Expression<String>? profileId,
    Expression<int>? version,
    Expression<String>? id,
    Expression<String>? categoryId,
    Expression<String>? snapshotJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (businessId != null) 'business_id': businessId,
      if (profileId != null) 'profile_id': profileId,
      if (version != null) 'version': version,
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (snapshotJson != null) 'snapshot_json': snapshotJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PricingVariantsCompanion copyWith({
    Value<String>? businessId,
    Value<String>? profileId,
    Value<int>? version,
    Value<String>? id,
    Value<String>? categoryId,
    Value<String>? snapshotJson,
    Value<int>? rowid,
  }) {
    return PricingVariantsCompanion(
      businessId: businessId ?? this.businessId,
      profileId: profileId ?? this.profileId,
      version: version ?? this.version,
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      snapshotJson: snapshotJson ?? this.snapshotJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (snapshotJson.present) {
      map['snapshot_json'] = Variable<String>(snapshotJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PricingVariantsCompanion(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('version: $version, ')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('snapshotJson: $snapshotJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class PricingRuleVersions extends Table
    with TableInfo<PricingRuleVersions, PricingRuleVersion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  PricingRuleVersions(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _variantIdMeta = const VerificationMeta(
    'variantId',
  );
  late final GeneratedColumn<String> variantId = GeneratedColumn<String>(
    'variant_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _pricingMethodMeta = const VerificationMeta(
    'pricingMethod',
  );
  late final GeneratedColumn<String> pricingMethod = GeneratedColumn<String>(
    'pricing_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _rateDecimalMeta = const VerificationMeta(
    'rateDecimal',
  );
  late final GeneratedColumn<String> rateDecimal = GeneratedColumn<String>(
    'rate_decimal',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _snapshotJsonMeta = const VerificationMeta(
    'snapshotJson',
  );
  late final GeneratedColumn<String> snapshotJson = GeneratedColumn<String>(
    'snapshot_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    businessId,
    profileId,
    version,
    id,
    categoryId,
    variantId,
    pricingMethod,
    rateDecimal,
    snapshotJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pricing_rule_versions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PricingRuleVersion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('variant_id')) {
      context.handle(
        _variantIdMeta,
        variantId.isAcceptableOrUnknown(data['variant_id']!, _variantIdMeta),
      );
    }
    if (data.containsKey('pricing_method')) {
      context.handle(
        _pricingMethodMeta,
        pricingMethod.isAcceptableOrUnknown(
          data['pricing_method']!,
          _pricingMethodMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pricingMethodMeta);
    }
    if (data.containsKey('rate_decimal')) {
      context.handle(
        _rateDecimalMeta,
        rateDecimal.isAcceptableOrUnknown(
          data['rate_decimal']!,
          _rateDecimalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rateDecimalMeta);
    }
    if (data.containsKey('snapshot_json')) {
      context.handle(
        _snapshotJsonMeta,
        snapshotJson.isAcceptableOrUnknown(
          data['snapshot_json']!,
          _snapshotJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_snapshotJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {businessId, profileId, version, id};
  @override
  PricingRuleVersion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PricingRuleVersion(
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      variantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variant_id'],
      ),
      pricingMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pricing_method'],
      )!,
      rateDecimal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rate_decimal'],
      )!,
      snapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_json'],
      )!,
    );
  }

  @override
  PricingRuleVersions createAlias(String alias) {
    return PricingRuleVersions(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(business_id, profile_id, version, id)',
    'FOREIGN KEY(business_id, profile_id, version, category_id)REFERENCES pricing_categories(business_id, profile_id, version, id)',
    'FOREIGN KEY(business_id, profile_id, version, category_id, variant_id)REFERENCES pricing_variants(business_id, profile_id, version, category_id, id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class PricingRuleVersion extends DataClass
    implements Insertable<PricingRuleVersion> {
  final String businessId;
  final String profileId;
  final int version;
  final String id;
  final String categoryId;
  final String? variantId;
  final String pricingMethod;
  final String rateDecimal;
  final String snapshotJson;
  const PricingRuleVersion({
    required this.businessId,
    required this.profileId,
    required this.version,
    required this.id,
    required this.categoryId,
    this.variantId,
    required this.pricingMethod,
    required this.rateDecimal,
    required this.snapshotJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['business_id'] = Variable<String>(businessId);
    map['profile_id'] = Variable<String>(profileId);
    map['version'] = Variable<int>(version);
    map['id'] = Variable<String>(id);
    map['category_id'] = Variable<String>(categoryId);
    if (!nullToAbsent || variantId != null) {
      map['variant_id'] = Variable<String>(variantId);
    }
    map['pricing_method'] = Variable<String>(pricingMethod);
    map['rate_decimal'] = Variable<String>(rateDecimal);
    map['snapshot_json'] = Variable<String>(snapshotJson);
    return map;
  }

  PricingRuleVersionsCompanion toCompanion(bool nullToAbsent) {
    return PricingRuleVersionsCompanion(
      businessId: Value(businessId),
      profileId: Value(profileId),
      version: Value(version),
      id: Value(id),
      categoryId: Value(categoryId),
      variantId: variantId == null && nullToAbsent
          ? const Value.absent()
          : Value(variantId),
      pricingMethod: Value(pricingMethod),
      rateDecimal: Value(rateDecimal),
      snapshotJson: Value(snapshotJson),
    );
  }

  factory PricingRuleVersion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PricingRuleVersion(
      businessId: serializer.fromJson<String>(json['business_id']),
      profileId: serializer.fromJson<String>(json['profile_id']),
      version: serializer.fromJson<int>(json['version']),
      id: serializer.fromJson<String>(json['id']),
      categoryId: serializer.fromJson<String>(json['category_id']),
      variantId: serializer.fromJson<String?>(json['variant_id']),
      pricingMethod: serializer.fromJson<String>(json['pricing_method']),
      rateDecimal: serializer.fromJson<String>(json['rate_decimal']),
      snapshotJson: serializer.fromJson<String>(json['snapshot_json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'business_id': serializer.toJson<String>(businessId),
      'profile_id': serializer.toJson<String>(profileId),
      'version': serializer.toJson<int>(version),
      'id': serializer.toJson<String>(id),
      'category_id': serializer.toJson<String>(categoryId),
      'variant_id': serializer.toJson<String?>(variantId),
      'pricing_method': serializer.toJson<String>(pricingMethod),
      'rate_decimal': serializer.toJson<String>(rateDecimal),
      'snapshot_json': serializer.toJson<String>(snapshotJson),
    };
  }

  PricingRuleVersion copyWith({
    String? businessId,
    String? profileId,
    int? version,
    String? id,
    String? categoryId,
    Value<String?> variantId = const Value.absent(),
    String? pricingMethod,
    String? rateDecimal,
    String? snapshotJson,
  }) => PricingRuleVersion(
    businessId: businessId ?? this.businessId,
    profileId: profileId ?? this.profileId,
    version: version ?? this.version,
    id: id ?? this.id,
    categoryId: categoryId ?? this.categoryId,
    variantId: variantId.present ? variantId.value : this.variantId,
    pricingMethod: pricingMethod ?? this.pricingMethod,
    rateDecimal: rateDecimal ?? this.rateDecimal,
    snapshotJson: snapshotJson ?? this.snapshotJson,
  );
  PricingRuleVersion copyWithCompanion(PricingRuleVersionsCompanion data) {
    return PricingRuleVersion(
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      version: data.version.present ? data.version.value : this.version,
      id: data.id.present ? data.id.value : this.id,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      variantId: data.variantId.present ? data.variantId.value : this.variantId,
      pricingMethod: data.pricingMethod.present
          ? data.pricingMethod.value
          : this.pricingMethod,
      rateDecimal: data.rateDecimal.present
          ? data.rateDecimal.value
          : this.rateDecimal,
      snapshotJson: data.snapshotJson.present
          ? data.snapshotJson.value
          : this.snapshotJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PricingRuleVersion(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('version: $version, ')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('variantId: $variantId, ')
          ..write('pricingMethod: $pricingMethod, ')
          ..write('rateDecimal: $rateDecimal, ')
          ..write('snapshotJson: $snapshotJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    businessId,
    profileId,
    version,
    id,
    categoryId,
    variantId,
    pricingMethod,
    rateDecimal,
    snapshotJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PricingRuleVersion &&
          other.businessId == this.businessId &&
          other.profileId == this.profileId &&
          other.version == this.version &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.variantId == this.variantId &&
          other.pricingMethod == this.pricingMethod &&
          other.rateDecimal == this.rateDecimal &&
          other.snapshotJson == this.snapshotJson);
}

class PricingRuleVersionsCompanion extends UpdateCompanion<PricingRuleVersion> {
  final Value<String> businessId;
  final Value<String> profileId;
  final Value<int> version;
  final Value<String> id;
  final Value<String> categoryId;
  final Value<String?> variantId;
  final Value<String> pricingMethod;
  final Value<String> rateDecimal;
  final Value<String> snapshotJson;
  final Value<int> rowid;
  const PricingRuleVersionsCompanion({
    this.businessId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.version = const Value.absent(),
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.variantId = const Value.absent(),
    this.pricingMethod = const Value.absent(),
    this.rateDecimal = const Value.absent(),
    this.snapshotJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PricingRuleVersionsCompanion.insert({
    required String businessId,
    required String profileId,
    required int version,
    required String id,
    required String categoryId,
    this.variantId = const Value.absent(),
    required String pricingMethod,
    required String rateDecimal,
    required String snapshotJson,
    this.rowid = const Value.absent(),
  }) : businessId = Value(businessId),
       profileId = Value(profileId),
       version = Value(version),
       id = Value(id),
       categoryId = Value(categoryId),
       pricingMethod = Value(pricingMethod),
       rateDecimal = Value(rateDecimal),
       snapshotJson = Value(snapshotJson);
  static Insertable<PricingRuleVersion> custom({
    Expression<String>? businessId,
    Expression<String>? profileId,
    Expression<int>? version,
    Expression<String>? id,
    Expression<String>? categoryId,
    Expression<String>? variantId,
    Expression<String>? pricingMethod,
    Expression<String>? rateDecimal,
    Expression<String>? snapshotJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (businessId != null) 'business_id': businessId,
      if (profileId != null) 'profile_id': profileId,
      if (version != null) 'version': version,
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (variantId != null) 'variant_id': variantId,
      if (pricingMethod != null) 'pricing_method': pricingMethod,
      if (rateDecimal != null) 'rate_decimal': rateDecimal,
      if (snapshotJson != null) 'snapshot_json': snapshotJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PricingRuleVersionsCompanion copyWith({
    Value<String>? businessId,
    Value<String>? profileId,
    Value<int>? version,
    Value<String>? id,
    Value<String>? categoryId,
    Value<String?>? variantId,
    Value<String>? pricingMethod,
    Value<String>? rateDecimal,
    Value<String>? snapshotJson,
    Value<int>? rowid,
  }) {
    return PricingRuleVersionsCompanion(
      businessId: businessId ?? this.businessId,
      profileId: profileId ?? this.profileId,
      version: version ?? this.version,
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      variantId: variantId ?? this.variantId,
      pricingMethod: pricingMethod ?? this.pricingMethod,
      rateDecimal: rateDecimal ?? this.rateDecimal,
      snapshotJson: snapshotJson ?? this.snapshotJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (variantId.present) {
      map['variant_id'] = Variable<String>(variantId.value);
    }
    if (pricingMethod.present) {
      map['pricing_method'] = Variable<String>(pricingMethod.value);
    }
    if (rateDecimal.present) {
      map['rate_decimal'] = Variable<String>(rateDecimal.value);
    }
    if (snapshotJson.present) {
      map['snapshot_json'] = Variable<String>(snapshotJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PricingRuleVersionsCompanion(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('version: $version, ')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('variantId: $variantId, ')
          ..write('pricingMethod: $pricingMethod, ')
          ..write('rateDecimal: $rateDecimal, ')
          ..write('snapshotJson: $snapshotJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class PricingAddons extends Table with TableInfo<PricingAddons, PricingAddon> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  PricingAddons(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _snapshotJsonMeta = const VerificationMeta(
    'snapshotJson',
  );
  late final GeneratedColumn<String> snapshotJson = GeneratedColumn<String>(
    'snapshot_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    businessId,
    profileId,
    version,
    id,
    name,
    snapshotJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pricing_addons';
  @override
  VerificationContext validateIntegrity(
    Insertable<PricingAddon> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
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
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('snapshot_json')) {
      context.handle(
        _snapshotJsonMeta,
        snapshotJson.isAcceptableOrUnknown(
          data['snapshot_json']!,
          _snapshotJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_snapshotJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {businessId, profileId, version, id};
  @override
  PricingAddon map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PricingAddon(
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      snapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_json'],
      )!,
    );
  }

  @override
  PricingAddons createAlias(String alias) {
    return PricingAddons(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(business_id, profile_id, version, id)',
    'FOREIGN KEY(business_id, profile_id, version)REFERENCES pricing_rate_card_versions(business_id, profile_id, version)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class PricingAddon extends DataClass implements Insertable<PricingAddon> {
  final String businessId;
  final String profileId;
  final int version;
  final String id;
  final String name;
  final String snapshotJson;
  const PricingAddon({
    required this.businessId,
    required this.profileId,
    required this.version,
    required this.id,
    required this.name,
    required this.snapshotJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['business_id'] = Variable<String>(businessId);
    map['profile_id'] = Variable<String>(profileId);
    map['version'] = Variable<int>(version);
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['snapshot_json'] = Variable<String>(snapshotJson);
    return map;
  }

  PricingAddonsCompanion toCompanion(bool nullToAbsent) {
    return PricingAddonsCompanion(
      businessId: Value(businessId),
      profileId: Value(profileId),
      version: Value(version),
      id: Value(id),
      name: Value(name),
      snapshotJson: Value(snapshotJson),
    );
  }

  factory PricingAddon.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PricingAddon(
      businessId: serializer.fromJson<String>(json['business_id']),
      profileId: serializer.fromJson<String>(json['profile_id']),
      version: serializer.fromJson<int>(json['version']),
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      snapshotJson: serializer.fromJson<String>(json['snapshot_json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'business_id': serializer.toJson<String>(businessId),
      'profile_id': serializer.toJson<String>(profileId),
      'version': serializer.toJson<int>(version),
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'snapshot_json': serializer.toJson<String>(snapshotJson),
    };
  }

  PricingAddon copyWith({
    String? businessId,
    String? profileId,
    int? version,
    String? id,
    String? name,
    String? snapshotJson,
  }) => PricingAddon(
    businessId: businessId ?? this.businessId,
    profileId: profileId ?? this.profileId,
    version: version ?? this.version,
    id: id ?? this.id,
    name: name ?? this.name,
    snapshotJson: snapshotJson ?? this.snapshotJson,
  );
  PricingAddon copyWithCompanion(PricingAddonsCompanion data) {
    return PricingAddon(
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      version: data.version.present ? data.version.value : this.version,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      snapshotJson: data.snapshotJson.present
          ? data.snapshotJson.value
          : this.snapshotJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PricingAddon(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('version: $version, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('snapshotJson: $snapshotJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(businessId, profileId, version, id, name, snapshotJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PricingAddon &&
          other.businessId == this.businessId &&
          other.profileId == this.profileId &&
          other.version == this.version &&
          other.id == this.id &&
          other.name == this.name &&
          other.snapshotJson == this.snapshotJson);
}

class PricingAddonsCompanion extends UpdateCompanion<PricingAddon> {
  final Value<String> businessId;
  final Value<String> profileId;
  final Value<int> version;
  final Value<String> id;
  final Value<String> name;
  final Value<String> snapshotJson;
  final Value<int> rowid;
  const PricingAddonsCompanion({
    this.businessId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.version = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.snapshotJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PricingAddonsCompanion.insert({
    required String businessId,
    required String profileId,
    required int version,
    required String id,
    required String name,
    required String snapshotJson,
    this.rowid = const Value.absent(),
  }) : businessId = Value(businessId),
       profileId = Value(profileId),
       version = Value(version),
       id = Value(id),
       name = Value(name),
       snapshotJson = Value(snapshotJson);
  static Insertable<PricingAddon> custom({
    Expression<String>? businessId,
    Expression<String>? profileId,
    Expression<int>? version,
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? snapshotJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (businessId != null) 'business_id': businessId,
      if (profileId != null) 'profile_id': profileId,
      if (version != null) 'version': version,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (snapshotJson != null) 'snapshot_json': snapshotJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PricingAddonsCompanion copyWith({
    Value<String>? businessId,
    Value<String>? profileId,
    Value<int>? version,
    Value<String>? id,
    Value<String>? name,
    Value<String>? snapshotJson,
    Value<int>? rowid,
  }) {
    return PricingAddonsCompanion(
      businessId: businessId ?? this.businessId,
      profileId: profileId ?? this.profileId,
      version: version ?? this.version,
      id: id ?? this.id,
      name: name ?? this.name,
      snapshotJson: snapshotJson ?? this.snapshotJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (snapshotJson.present) {
      map['snapshot_json'] = Variable<String>(snapshotJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PricingAddonsCompanion(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('version: $version, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('snapshotJson: $snapshotJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class PricingRuleAddons extends Table
    with TableInfo<PricingRuleAddons, PricingRuleAddon> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  PricingRuleAddons(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _ruleIdMeta = const VerificationMeta('ruleId');
  late final GeneratedColumn<String> ruleId = GeneratedColumn<String>(
    'rule_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _addonIdMeta = const VerificationMeta(
    'addonId',
  );
  late final GeneratedColumn<String> addonId = GeneratedColumn<String>(
    'addon_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    businessId,
    profileId,
    version,
    ruleId,
    addonId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pricing_rule_addons';
  @override
  VerificationContext validateIntegrity(
    Insertable<PricingRuleAddon> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('rule_id')) {
      context.handle(
        _ruleIdMeta,
        ruleId.isAcceptableOrUnknown(data['rule_id']!, _ruleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ruleIdMeta);
    }
    if (data.containsKey('addon_id')) {
      context.handle(
        _addonIdMeta,
        addonId.isAcceptableOrUnknown(data['addon_id']!, _addonIdMeta),
      );
    } else if (isInserting) {
      context.missing(_addonIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    businessId,
    profileId,
    version,
    ruleId,
    addonId,
  };
  @override
  PricingRuleAddon map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PricingRuleAddon(
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      ruleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rule_id'],
      )!,
      addonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}addon_id'],
      )!,
    );
  }

  @override
  PricingRuleAddons createAlias(String alias) {
    return PricingRuleAddons(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(business_id, profile_id, version, rule_id, addon_id)',
    'FOREIGN KEY(business_id, profile_id, version, rule_id)REFERENCES pricing_rule_versions(business_id, profile_id, version, id)',
    'FOREIGN KEY(business_id, profile_id, version, addon_id)REFERENCES pricing_addons(business_id, profile_id, version, id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class PricingRuleAddon extends DataClass
    implements Insertable<PricingRuleAddon> {
  final String businessId;
  final String profileId;
  final int version;
  final String ruleId;
  final String addonId;
  const PricingRuleAddon({
    required this.businessId,
    required this.profileId,
    required this.version,
    required this.ruleId,
    required this.addonId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['business_id'] = Variable<String>(businessId);
    map['profile_id'] = Variable<String>(profileId);
    map['version'] = Variable<int>(version);
    map['rule_id'] = Variable<String>(ruleId);
    map['addon_id'] = Variable<String>(addonId);
    return map;
  }

  PricingRuleAddonsCompanion toCompanion(bool nullToAbsent) {
    return PricingRuleAddonsCompanion(
      businessId: Value(businessId),
      profileId: Value(profileId),
      version: Value(version),
      ruleId: Value(ruleId),
      addonId: Value(addonId),
    );
  }

  factory PricingRuleAddon.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PricingRuleAddon(
      businessId: serializer.fromJson<String>(json['business_id']),
      profileId: serializer.fromJson<String>(json['profile_id']),
      version: serializer.fromJson<int>(json['version']),
      ruleId: serializer.fromJson<String>(json['rule_id']),
      addonId: serializer.fromJson<String>(json['addon_id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'business_id': serializer.toJson<String>(businessId),
      'profile_id': serializer.toJson<String>(profileId),
      'version': serializer.toJson<int>(version),
      'rule_id': serializer.toJson<String>(ruleId),
      'addon_id': serializer.toJson<String>(addonId),
    };
  }

  PricingRuleAddon copyWith({
    String? businessId,
    String? profileId,
    int? version,
    String? ruleId,
    String? addonId,
  }) => PricingRuleAddon(
    businessId: businessId ?? this.businessId,
    profileId: profileId ?? this.profileId,
    version: version ?? this.version,
    ruleId: ruleId ?? this.ruleId,
    addonId: addonId ?? this.addonId,
  );
  PricingRuleAddon copyWithCompanion(PricingRuleAddonsCompanion data) {
    return PricingRuleAddon(
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      version: data.version.present ? data.version.value : this.version,
      ruleId: data.ruleId.present ? data.ruleId.value : this.ruleId,
      addonId: data.addonId.present ? data.addonId.value : this.addonId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PricingRuleAddon(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('version: $version, ')
          ..write('ruleId: $ruleId, ')
          ..write('addonId: $addonId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(businessId, profileId, version, ruleId, addonId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PricingRuleAddon &&
          other.businessId == this.businessId &&
          other.profileId == this.profileId &&
          other.version == this.version &&
          other.ruleId == this.ruleId &&
          other.addonId == this.addonId);
}

class PricingRuleAddonsCompanion extends UpdateCompanion<PricingRuleAddon> {
  final Value<String> businessId;
  final Value<String> profileId;
  final Value<int> version;
  final Value<String> ruleId;
  final Value<String> addonId;
  final Value<int> rowid;
  const PricingRuleAddonsCompanion({
    this.businessId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.version = const Value.absent(),
    this.ruleId = const Value.absent(),
    this.addonId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PricingRuleAddonsCompanion.insert({
    required String businessId,
    required String profileId,
    required int version,
    required String ruleId,
    required String addonId,
    this.rowid = const Value.absent(),
  }) : businessId = Value(businessId),
       profileId = Value(profileId),
       version = Value(version),
       ruleId = Value(ruleId),
       addonId = Value(addonId);
  static Insertable<PricingRuleAddon> custom({
    Expression<String>? businessId,
    Expression<String>? profileId,
    Expression<int>? version,
    Expression<String>? ruleId,
    Expression<String>? addonId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (businessId != null) 'business_id': businessId,
      if (profileId != null) 'profile_id': profileId,
      if (version != null) 'version': version,
      if (ruleId != null) 'rule_id': ruleId,
      if (addonId != null) 'addon_id': addonId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PricingRuleAddonsCompanion copyWith({
    Value<String>? businessId,
    Value<String>? profileId,
    Value<int>? version,
    Value<String>? ruleId,
    Value<String>? addonId,
    Value<int>? rowid,
  }) {
    return PricingRuleAddonsCompanion(
      businessId: businessId ?? this.businessId,
      profileId: profileId ?? this.profileId,
      version: version ?? this.version,
      ruleId: ruleId ?? this.ruleId,
      addonId: addonId ?? this.addonId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (ruleId.present) {
      map['rule_id'] = Variable<String>(ruleId.value);
    }
    if (addonId.present) {
      map['addon_id'] = Variable<String>(addonId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PricingRuleAddonsCompanion(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('version: $version, ')
          ..write('ruleId: $ruleId, ')
          ..write('addonId: $addonId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class PricingAuditEvents extends Table
    with TableInfo<PricingAuditEvents, PricingAuditEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  PricingAuditEvents(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY AUTOINCREMENT',
  );
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _actorUidMeta = const VerificationMeta(
    'actorUid',
  );
  late final GeneratedColumn<String> actorUid = GeneratedColumn<String>(
    'actor_uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _beforeSnapshotMeta = const VerificationMeta(
    'beforeSnapshot',
  );
  late final GeneratedColumn<String> beforeSnapshot = GeneratedColumn<String>(
    'before_snapshot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _afterSnapshotMeta = const VerificationMeta(
    'afterSnapshot',
  );
  late final GeneratedColumn<String> afterSnapshot = GeneratedColumn<String>(
    'after_snapshot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    businessId,
    actorUid,
    action,
    profileId,
    beforeSnapshot,
    afterSnapshot,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pricing_audit_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<PricingAuditEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('actor_uid')) {
      context.handle(
        _actorUidMeta,
        actorUid.isAcceptableOrUnknown(data['actor_uid']!, _actorUidMeta),
      );
    } else if (isInserting) {
      context.missing(_actorUidMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('before_snapshot')) {
      context.handle(
        _beforeSnapshotMeta,
        beforeSnapshot.isAcceptableOrUnknown(
          data['before_snapshot']!,
          _beforeSnapshotMeta,
        ),
      );
    }
    if (data.containsKey('after_snapshot')) {
      context.handle(
        _afterSnapshotMeta,
        afterSnapshot.isAcceptableOrUnknown(
          data['after_snapshot']!,
          _afterSnapshotMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_afterSnapshotMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PricingAuditEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PricingAuditEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      actorUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_uid'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      beforeSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}before_snapshot'],
      ),
      afterSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}after_snapshot'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  PricingAuditEvents createAlias(String alias) {
    return PricingAuditEvents(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY(business_id, profile_id)REFERENCES pricing_profiles(business_id, id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class PricingAuditEvent extends DataClass
    implements Insertable<PricingAuditEvent> {
  final int id;
  final String businessId;
  final String actorUid;
  final String action;
  final String profileId;
  final String? beforeSnapshot;
  final String afterSnapshot;
  final int createdAt;
  const PricingAuditEvent({
    required this.id,
    required this.businessId,
    required this.actorUid,
    required this.action,
    required this.profileId,
    this.beforeSnapshot,
    required this.afterSnapshot,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['business_id'] = Variable<String>(businessId);
    map['actor_uid'] = Variable<String>(actorUid);
    map['action'] = Variable<String>(action);
    map['profile_id'] = Variable<String>(profileId);
    if (!nullToAbsent || beforeSnapshot != null) {
      map['before_snapshot'] = Variable<String>(beforeSnapshot);
    }
    map['after_snapshot'] = Variable<String>(afterSnapshot);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  PricingAuditEventsCompanion toCompanion(bool nullToAbsent) {
    return PricingAuditEventsCompanion(
      id: Value(id),
      businessId: Value(businessId),
      actorUid: Value(actorUid),
      action: Value(action),
      profileId: Value(profileId),
      beforeSnapshot: beforeSnapshot == null && nullToAbsent
          ? const Value.absent()
          : Value(beforeSnapshot),
      afterSnapshot: Value(afterSnapshot),
      createdAt: Value(createdAt),
    );
  }

  factory PricingAuditEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PricingAuditEvent(
      id: serializer.fromJson<int>(json['id']),
      businessId: serializer.fromJson<String>(json['business_id']),
      actorUid: serializer.fromJson<String>(json['actor_uid']),
      action: serializer.fromJson<String>(json['action']),
      profileId: serializer.fromJson<String>(json['profile_id']),
      beforeSnapshot: serializer.fromJson<String?>(json['before_snapshot']),
      afterSnapshot: serializer.fromJson<String>(json['after_snapshot']),
      createdAt: serializer.fromJson<int>(json['created_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'business_id': serializer.toJson<String>(businessId),
      'actor_uid': serializer.toJson<String>(actorUid),
      'action': serializer.toJson<String>(action),
      'profile_id': serializer.toJson<String>(profileId),
      'before_snapshot': serializer.toJson<String?>(beforeSnapshot),
      'after_snapshot': serializer.toJson<String>(afterSnapshot),
      'created_at': serializer.toJson<int>(createdAt),
    };
  }

  PricingAuditEvent copyWith({
    int? id,
    String? businessId,
    String? actorUid,
    String? action,
    String? profileId,
    Value<String?> beforeSnapshot = const Value.absent(),
    String? afterSnapshot,
    int? createdAt,
  }) => PricingAuditEvent(
    id: id ?? this.id,
    businessId: businessId ?? this.businessId,
    actorUid: actorUid ?? this.actorUid,
    action: action ?? this.action,
    profileId: profileId ?? this.profileId,
    beforeSnapshot: beforeSnapshot.present
        ? beforeSnapshot.value
        : this.beforeSnapshot,
    afterSnapshot: afterSnapshot ?? this.afterSnapshot,
    createdAt: createdAt ?? this.createdAt,
  );
  PricingAuditEvent copyWithCompanion(PricingAuditEventsCompanion data) {
    return PricingAuditEvent(
      id: data.id.present ? data.id.value : this.id,
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      actorUid: data.actorUid.present ? data.actorUid.value : this.actorUid,
      action: data.action.present ? data.action.value : this.action,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      beforeSnapshot: data.beforeSnapshot.present
          ? data.beforeSnapshot.value
          : this.beforeSnapshot,
      afterSnapshot: data.afterSnapshot.present
          ? data.afterSnapshot.value
          : this.afterSnapshot,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PricingAuditEvent(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('actorUid: $actorUid, ')
          ..write('action: $action, ')
          ..write('profileId: $profileId, ')
          ..write('beforeSnapshot: $beforeSnapshot, ')
          ..write('afterSnapshot: $afterSnapshot, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    businessId,
    actorUid,
    action,
    profileId,
    beforeSnapshot,
    afterSnapshot,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PricingAuditEvent &&
          other.id == this.id &&
          other.businessId == this.businessId &&
          other.actorUid == this.actorUid &&
          other.action == this.action &&
          other.profileId == this.profileId &&
          other.beforeSnapshot == this.beforeSnapshot &&
          other.afterSnapshot == this.afterSnapshot &&
          other.createdAt == this.createdAt);
}

class PricingAuditEventsCompanion extends UpdateCompanion<PricingAuditEvent> {
  final Value<int> id;
  final Value<String> businessId;
  final Value<String> actorUid;
  final Value<String> action;
  final Value<String> profileId;
  final Value<String?> beforeSnapshot;
  final Value<String> afterSnapshot;
  final Value<int> createdAt;
  const PricingAuditEventsCompanion({
    this.id = const Value.absent(),
    this.businessId = const Value.absent(),
    this.actorUid = const Value.absent(),
    this.action = const Value.absent(),
    this.profileId = const Value.absent(),
    this.beforeSnapshot = const Value.absent(),
    this.afterSnapshot = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PricingAuditEventsCompanion.insert({
    this.id = const Value.absent(),
    required String businessId,
    required String actorUid,
    required String action,
    required String profileId,
    this.beforeSnapshot = const Value.absent(),
    required String afterSnapshot,
    required int createdAt,
  }) : businessId = Value(businessId),
       actorUid = Value(actorUid),
       action = Value(action),
       profileId = Value(profileId),
       afterSnapshot = Value(afterSnapshot),
       createdAt = Value(createdAt);
  static Insertable<PricingAuditEvent> custom({
    Expression<int>? id,
    Expression<String>? businessId,
    Expression<String>? actorUid,
    Expression<String>? action,
    Expression<String>? profileId,
    Expression<String>? beforeSnapshot,
    Expression<String>? afterSnapshot,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (businessId != null) 'business_id': businessId,
      if (actorUid != null) 'actor_uid': actorUid,
      if (action != null) 'action': action,
      if (profileId != null) 'profile_id': profileId,
      if (beforeSnapshot != null) 'before_snapshot': beforeSnapshot,
      if (afterSnapshot != null) 'after_snapshot': afterSnapshot,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PricingAuditEventsCompanion copyWith({
    Value<int>? id,
    Value<String>? businessId,
    Value<String>? actorUid,
    Value<String>? action,
    Value<String>? profileId,
    Value<String?>? beforeSnapshot,
    Value<String>? afterSnapshot,
    Value<int>? createdAt,
  }) {
    return PricingAuditEventsCompanion(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      actorUid: actorUid ?? this.actorUid,
      action: action ?? this.action,
      profileId: profileId ?? this.profileId,
      beforeSnapshot: beforeSnapshot ?? this.beforeSnapshot,
      afterSnapshot: afterSnapshot ?? this.afterSnapshot,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (actorUid.present) {
      map['actor_uid'] = Variable<String>(actorUid.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (beforeSnapshot.present) {
      map['before_snapshot'] = Variable<String>(beforeSnapshot.value);
    }
    if (afterSnapshot.present) {
      map['after_snapshot'] = Variable<String>(afterSnapshot.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PricingAuditEventsCompanion(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('actorUid: $actorUid, ')
          ..write('action: $action, ')
          ..write('profileId: $profileId, ')
          ..write('beforeSnapshot: $beforeSnapshot, ')
          ..write('afterSnapshot: $afterSnapshot, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class UniversalPricingProfiles extends Table
    with TableInfo<UniversalPricingProfiles, UniversalPricingProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  UniversalPricingProfiles(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'draft\' CHECK (status IN (\'draft\', \'published\', \'archived\'))',
    defaultValue: const CustomExpression('\'draft\''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    businessId,
    id,
    name,
    status,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'universal_pricing_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<UniversalPricingProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
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
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
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
  Set<GeneratedColumn> get $primaryKey => {businessId, id};
  @override
  UniversalPricingProfile map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UniversalPricingProfile(
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  UniversalPricingProfiles createAlias(String alias) {
    return UniversalPricingProfiles(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(business_id, id)'];
  @override
  bool get dontWriteConstraints => true;
}

class UniversalPricingProfile extends DataClass
    implements Insertable<UniversalPricingProfile> {
  final String businessId;
  final String id;
  final String name;
  final String status;
  final int createdAt;
  final int updatedAt;
  const UniversalPricingProfile({
    required this.businessId,
    required this.id,
    required this.name,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['business_id'] = Variable<String>(businessId);
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  UniversalPricingProfilesCompanion toCompanion(bool nullToAbsent) {
    return UniversalPricingProfilesCompanion(
      businessId: Value(businessId),
      id: Value(id),
      name: Value(name),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory UniversalPricingProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UniversalPricingProfile(
      businessId: serializer.fromJson<String>(json['business_id']),
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'business_id': serializer.toJson<String>(businessId),
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'status': serializer.toJson<String>(status),
      'created_at': serializer.toJson<int>(createdAt),
      'updated_at': serializer.toJson<int>(updatedAt),
    };
  }

  UniversalPricingProfile copyWith({
    String? businessId,
    String? id,
    String? name,
    String? status,
    int? createdAt,
    int? updatedAt,
  }) => UniversalPricingProfile(
    businessId: businessId ?? this.businessId,
    id: id ?? this.id,
    name: name ?? this.name,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UniversalPricingProfile copyWithCompanion(
    UniversalPricingProfilesCompanion data,
  ) {
    return UniversalPricingProfile(
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UniversalPricingProfile(')
          ..write('businessId: $businessId, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(businessId, id, name, status, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UniversalPricingProfile &&
          other.businessId == this.businessId &&
          other.id == this.id &&
          other.name == this.name &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class UniversalPricingProfilesCompanion
    extends UpdateCompanion<UniversalPricingProfile> {
  final Value<String> businessId;
  final Value<String> id;
  final Value<String> name;
  final Value<String> status;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const UniversalPricingProfilesCompanion({
    this.businessId = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UniversalPricingProfilesCompanion.insert({
    required String businessId,
    required String id,
    required String name,
    this.status = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : businessId = Value(businessId),
       id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<UniversalPricingProfile> custom({
    Expression<String>? businessId,
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? status,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (businessId != null) 'business_id': businessId,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UniversalPricingProfilesCompanion copyWith({
    Value<String>? businessId,
    Value<String>? id,
    Value<String>? name,
    Value<String>? status,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return UniversalPricingProfilesCompanion(
      businessId: businessId ?? this.businessId,
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UniversalPricingProfilesCompanion(')
          ..write('businessId: $businessId, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class UniversalPricingDrafts extends Table
    with TableInfo<UniversalPricingDrafts, UniversalPricingDraft> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  UniversalPricingDrafts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (revision > 0)',
  );
  static const VerificationMeta _snapshotJsonMeta = const VerificationMeta(
    'snapshotJson',
  );
  late final GeneratedColumn<String> snapshotJson = GeneratedColumn<String>(
    'snapshot_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    businessId,
    profileId,
    revision,
    snapshotJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'universal_pricing_drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<UniversalPricingDraft> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('snapshot_json')) {
      context.handle(
        _snapshotJsonMeta,
        snapshotJson.isAcceptableOrUnknown(
          data['snapshot_json']!,
          _snapshotJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_snapshotJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {businessId, profileId};
  @override
  UniversalPricingDraft map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UniversalPricingDraft(
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      snapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_json'],
      )!,
    );
  }

  @override
  UniversalPricingDrafts createAlias(String alias) {
    return UniversalPricingDrafts(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(business_id, profile_id)',
    'FOREIGN KEY(business_id, profile_id)REFERENCES universal_pricing_profiles(business_id, id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class UniversalPricingDraft extends DataClass
    implements Insertable<UniversalPricingDraft> {
  final String businessId;
  final String profileId;
  final int revision;
  final String snapshotJson;
  const UniversalPricingDraft({
    required this.businessId,
    required this.profileId,
    required this.revision,
    required this.snapshotJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['business_id'] = Variable<String>(businessId);
    map['profile_id'] = Variable<String>(profileId);
    map['revision'] = Variable<int>(revision);
    map['snapshot_json'] = Variable<String>(snapshotJson);
    return map;
  }

  UniversalPricingDraftsCompanion toCompanion(bool nullToAbsent) {
    return UniversalPricingDraftsCompanion(
      businessId: Value(businessId),
      profileId: Value(profileId),
      revision: Value(revision),
      snapshotJson: Value(snapshotJson),
    );
  }

  factory UniversalPricingDraft.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UniversalPricingDraft(
      businessId: serializer.fromJson<String>(json['business_id']),
      profileId: serializer.fromJson<String>(json['profile_id']),
      revision: serializer.fromJson<int>(json['revision']),
      snapshotJson: serializer.fromJson<String>(json['snapshot_json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'business_id': serializer.toJson<String>(businessId),
      'profile_id': serializer.toJson<String>(profileId),
      'revision': serializer.toJson<int>(revision),
      'snapshot_json': serializer.toJson<String>(snapshotJson),
    };
  }

  UniversalPricingDraft copyWith({
    String? businessId,
    String? profileId,
    int? revision,
    String? snapshotJson,
  }) => UniversalPricingDraft(
    businessId: businessId ?? this.businessId,
    profileId: profileId ?? this.profileId,
    revision: revision ?? this.revision,
    snapshotJson: snapshotJson ?? this.snapshotJson,
  );
  UniversalPricingDraft copyWithCompanion(
    UniversalPricingDraftsCompanion data,
  ) {
    return UniversalPricingDraft(
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      revision: data.revision.present ? data.revision.value : this.revision,
      snapshotJson: data.snapshotJson.present
          ? data.snapshotJson.value
          : this.snapshotJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UniversalPricingDraft(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('revision: $revision, ')
          ..write('snapshotJson: $snapshotJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(businessId, profileId, revision, snapshotJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UniversalPricingDraft &&
          other.businessId == this.businessId &&
          other.profileId == this.profileId &&
          other.revision == this.revision &&
          other.snapshotJson == this.snapshotJson);
}

class UniversalPricingDraftsCompanion
    extends UpdateCompanion<UniversalPricingDraft> {
  final Value<String> businessId;
  final Value<String> profileId;
  final Value<int> revision;
  final Value<String> snapshotJson;
  final Value<int> rowid;
  const UniversalPricingDraftsCompanion({
    this.businessId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.revision = const Value.absent(),
    this.snapshotJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UniversalPricingDraftsCompanion.insert({
    required String businessId,
    required String profileId,
    required int revision,
    required String snapshotJson,
    this.rowid = const Value.absent(),
  }) : businessId = Value(businessId),
       profileId = Value(profileId),
       revision = Value(revision),
       snapshotJson = Value(snapshotJson);
  static Insertable<UniversalPricingDraft> custom({
    Expression<String>? businessId,
    Expression<String>? profileId,
    Expression<int>? revision,
    Expression<String>? snapshotJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (businessId != null) 'business_id': businessId,
      if (profileId != null) 'profile_id': profileId,
      if (revision != null) 'revision': revision,
      if (snapshotJson != null) 'snapshot_json': snapshotJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UniversalPricingDraftsCompanion copyWith({
    Value<String>? businessId,
    Value<String>? profileId,
    Value<int>? revision,
    Value<String>? snapshotJson,
    Value<int>? rowid,
  }) {
    return UniversalPricingDraftsCompanion(
      businessId: businessId ?? this.businessId,
      profileId: profileId ?? this.profileId,
      revision: revision ?? this.revision,
      snapshotJson: snapshotJson ?? this.snapshotJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (snapshotJson.present) {
      map['snapshot_json'] = Variable<String>(snapshotJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UniversalPricingDraftsCompanion(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('revision: $revision, ')
          ..write('snapshotJson: $snapshotJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class UniversalPricingVersions extends Table
    with TableInfo<UniversalPricingVersions, UniversalPricingVersion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  UniversalPricingVersions(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (version > 0)',
  );
  static const VerificationMeta _engineVersionMeta = const VerificationMeta(
    'engineVersion',
  );
  late final GeneratedColumn<String> engineVersion = GeneratedColumn<String>(
    'engine_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (engine_version = \'universal-1\')',
  );
  static const VerificationMeta _effectiveAtMeta = const VerificationMeta(
    'effectiveAt',
  );
  late final GeneratedColumn<int> effectiveAt = GeneratedColumn<int>(
    'effective_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  late final GeneratedColumn<int> expiresAt = GeneratedColumn<int>(
    'expires_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _publishedAtMeta = const VerificationMeta(
    'publishedAt',
  );
  late final GeneratedColumn<int> publishedAt = GeneratedColumn<int>(
    'published_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _publishedByMeta = const VerificationMeta(
    'publishedBy',
  );
  late final GeneratedColumn<String> publishedBy = GeneratedColumn<String>(
    'published_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _snapshotJsonMeta = const VerificationMeta(
    'snapshotJson',
  );
  late final GeneratedColumn<String> snapshotJson = GeneratedColumn<String>(
    'snapshot_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _sealedMeta = const VerificationMeta('sealed');
  late final GeneratedColumn<int> sealed = GeneratedColumn<int>(
    'sealed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (sealed IN (0, 1))',
    defaultValue: const CustomExpression('0'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    businessId,
    profileId,
    version,
    engineVersion,
    effectiveAt,
    expiresAt,
    publishedAt,
    publishedBy,
    snapshotJson,
    sealed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'universal_pricing_versions';
  @override
  VerificationContext validateIntegrity(
    Insertable<UniversalPricingVersion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('engine_version')) {
      context.handle(
        _engineVersionMeta,
        engineVersion.isAcceptableOrUnknown(
          data['engine_version']!,
          _engineVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_engineVersionMeta);
    }
    if (data.containsKey('effective_at')) {
      context.handle(
        _effectiveAtMeta,
        effectiveAt.isAcceptableOrUnknown(
          data['effective_at']!,
          _effectiveAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_effectiveAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    }
    if (data.containsKey('published_at')) {
      context.handle(
        _publishedAtMeta,
        publishedAt.isAcceptableOrUnknown(
          data['published_at']!,
          _publishedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_publishedAtMeta);
    }
    if (data.containsKey('published_by')) {
      context.handle(
        _publishedByMeta,
        publishedBy.isAcceptableOrUnknown(
          data['published_by']!,
          _publishedByMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_publishedByMeta);
    }
    if (data.containsKey('snapshot_json')) {
      context.handle(
        _snapshotJsonMeta,
        snapshotJson.isAcceptableOrUnknown(
          data['snapshot_json']!,
          _snapshotJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_snapshotJsonMeta);
    }
    if (data.containsKey('sealed')) {
      context.handle(
        _sealedMeta,
        sealed.isAcceptableOrUnknown(data['sealed']!, _sealedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {businessId, profileId, version};
  @override
  UniversalPricingVersion map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UniversalPricingVersion(
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      engineVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}engine_version'],
      )!,
      effectiveAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}effective_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expires_at'],
      ),
      publishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}published_at'],
      )!,
      publishedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}published_by'],
      )!,
      snapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_json'],
      )!,
      sealed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sealed'],
      )!,
    );
  }

  @override
  UniversalPricingVersions createAlias(String alias) {
    return UniversalPricingVersions(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(business_id, profile_id, version)',
    'FOREIGN KEY(business_id, profile_id)REFERENCES universal_pricing_profiles(business_id, id)',
    'CHECK(expires_at IS NULL OR expires_at > effective_at)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class UniversalPricingVersion extends DataClass
    implements Insertable<UniversalPricingVersion> {
  final String businessId;
  final String profileId;
  final int version;
  final String engineVersion;
  final int effectiveAt;
  final int? expiresAt;
  final int publishedAt;
  final String publishedBy;
  final String snapshotJson;
  final int sealed;
  const UniversalPricingVersion({
    required this.businessId,
    required this.profileId,
    required this.version,
    required this.engineVersion,
    required this.effectiveAt,
    this.expiresAt,
    required this.publishedAt,
    required this.publishedBy,
    required this.snapshotJson,
    required this.sealed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['business_id'] = Variable<String>(businessId);
    map['profile_id'] = Variable<String>(profileId);
    map['version'] = Variable<int>(version);
    map['engine_version'] = Variable<String>(engineVersion);
    map['effective_at'] = Variable<int>(effectiveAt);
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<int>(expiresAt);
    }
    map['published_at'] = Variable<int>(publishedAt);
    map['published_by'] = Variable<String>(publishedBy);
    map['snapshot_json'] = Variable<String>(snapshotJson);
    map['sealed'] = Variable<int>(sealed);
    return map;
  }

  UniversalPricingVersionsCompanion toCompanion(bool nullToAbsent) {
    return UniversalPricingVersionsCompanion(
      businessId: Value(businessId),
      profileId: Value(profileId),
      version: Value(version),
      engineVersion: Value(engineVersion),
      effectiveAt: Value(effectiveAt),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
      publishedAt: Value(publishedAt),
      publishedBy: Value(publishedBy),
      snapshotJson: Value(snapshotJson),
      sealed: Value(sealed),
    );
  }

  factory UniversalPricingVersion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UniversalPricingVersion(
      businessId: serializer.fromJson<String>(json['business_id']),
      profileId: serializer.fromJson<String>(json['profile_id']),
      version: serializer.fromJson<int>(json['version']),
      engineVersion: serializer.fromJson<String>(json['engine_version']),
      effectiveAt: serializer.fromJson<int>(json['effective_at']),
      expiresAt: serializer.fromJson<int?>(json['expires_at']),
      publishedAt: serializer.fromJson<int>(json['published_at']),
      publishedBy: serializer.fromJson<String>(json['published_by']),
      snapshotJson: serializer.fromJson<String>(json['snapshot_json']),
      sealed: serializer.fromJson<int>(json['sealed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'business_id': serializer.toJson<String>(businessId),
      'profile_id': serializer.toJson<String>(profileId),
      'version': serializer.toJson<int>(version),
      'engine_version': serializer.toJson<String>(engineVersion),
      'effective_at': serializer.toJson<int>(effectiveAt),
      'expires_at': serializer.toJson<int?>(expiresAt),
      'published_at': serializer.toJson<int>(publishedAt),
      'published_by': serializer.toJson<String>(publishedBy),
      'snapshot_json': serializer.toJson<String>(snapshotJson),
      'sealed': serializer.toJson<int>(sealed),
    };
  }

  UniversalPricingVersion copyWith({
    String? businessId,
    String? profileId,
    int? version,
    String? engineVersion,
    int? effectiveAt,
    Value<int?> expiresAt = const Value.absent(),
    int? publishedAt,
    String? publishedBy,
    String? snapshotJson,
    int? sealed,
  }) => UniversalPricingVersion(
    businessId: businessId ?? this.businessId,
    profileId: profileId ?? this.profileId,
    version: version ?? this.version,
    engineVersion: engineVersion ?? this.engineVersion,
    effectiveAt: effectiveAt ?? this.effectiveAt,
    expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
    publishedAt: publishedAt ?? this.publishedAt,
    publishedBy: publishedBy ?? this.publishedBy,
    snapshotJson: snapshotJson ?? this.snapshotJson,
    sealed: sealed ?? this.sealed,
  );
  UniversalPricingVersion copyWithCompanion(
    UniversalPricingVersionsCompanion data,
  ) {
    return UniversalPricingVersion(
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      version: data.version.present ? data.version.value : this.version,
      engineVersion: data.engineVersion.present
          ? data.engineVersion.value
          : this.engineVersion,
      effectiveAt: data.effectiveAt.present
          ? data.effectiveAt.value
          : this.effectiveAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      publishedAt: data.publishedAt.present
          ? data.publishedAt.value
          : this.publishedAt,
      publishedBy: data.publishedBy.present
          ? data.publishedBy.value
          : this.publishedBy,
      snapshotJson: data.snapshotJson.present
          ? data.snapshotJson.value
          : this.snapshotJson,
      sealed: data.sealed.present ? data.sealed.value : this.sealed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UniversalPricingVersion(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('version: $version, ')
          ..write('engineVersion: $engineVersion, ')
          ..write('effectiveAt: $effectiveAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('publishedBy: $publishedBy, ')
          ..write('snapshotJson: $snapshotJson, ')
          ..write('sealed: $sealed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    businessId,
    profileId,
    version,
    engineVersion,
    effectiveAt,
    expiresAt,
    publishedAt,
    publishedBy,
    snapshotJson,
    sealed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UniversalPricingVersion &&
          other.businessId == this.businessId &&
          other.profileId == this.profileId &&
          other.version == this.version &&
          other.engineVersion == this.engineVersion &&
          other.effectiveAt == this.effectiveAt &&
          other.expiresAt == this.expiresAt &&
          other.publishedAt == this.publishedAt &&
          other.publishedBy == this.publishedBy &&
          other.snapshotJson == this.snapshotJson &&
          other.sealed == this.sealed);
}

class UniversalPricingVersionsCompanion
    extends UpdateCompanion<UniversalPricingVersion> {
  final Value<String> businessId;
  final Value<String> profileId;
  final Value<int> version;
  final Value<String> engineVersion;
  final Value<int> effectiveAt;
  final Value<int?> expiresAt;
  final Value<int> publishedAt;
  final Value<String> publishedBy;
  final Value<String> snapshotJson;
  final Value<int> sealed;
  final Value<int> rowid;
  const UniversalPricingVersionsCompanion({
    this.businessId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.version = const Value.absent(),
    this.engineVersion = const Value.absent(),
    this.effectiveAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.publishedBy = const Value.absent(),
    this.snapshotJson = const Value.absent(),
    this.sealed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UniversalPricingVersionsCompanion.insert({
    required String businessId,
    required String profileId,
    required int version,
    required String engineVersion,
    required int effectiveAt,
    this.expiresAt = const Value.absent(),
    required int publishedAt,
    required String publishedBy,
    required String snapshotJson,
    this.sealed = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : businessId = Value(businessId),
       profileId = Value(profileId),
       version = Value(version),
       engineVersion = Value(engineVersion),
       effectiveAt = Value(effectiveAt),
       publishedAt = Value(publishedAt),
       publishedBy = Value(publishedBy),
       snapshotJson = Value(snapshotJson);
  static Insertable<UniversalPricingVersion> custom({
    Expression<String>? businessId,
    Expression<String>? profileId,
    Expression<int>? version,
    Expression<String>? engineVersion,
    Expression<int>? effectiveAt,
    Expression<int>? expiresAt,
    Expression<int>? publishedAt,
    Expression<String>? publishedBy,
    Expression<String>? snapshotJson,
    Expression<int>? sealed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (businessId != null) 'business_id': businessId,
      if (profileId != null) 'profile_id': profileId,
      if (version != null) 'version': version,
      if (engineVersion != null) 'engine_version': engineVersion,
      if (effectiveAt != null) 'effective_at': effectiveAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (publishedAt != null) 'published_at': publishedAt,
      if (publishedBy != null) 'published_by': publishedBy,
      if (snapshotJson != null) 'snapshot_json': snapshotJson,
      if (sealed != null) 'sealed': sealed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UniversalPricingVersionsCompanion copyWith({
    Value<String>? businessId,
    Value<String>? profileId,
    Value<int>? version,
    Value<String>? engineVersion,
    Value<int>? effectiveAt,
    Value<int?>? expiresAt,
    Value<int>? publishedAt,
    Value<String>? publishedBy,
    Value<String>? snapshotJson,
    Value<int>? sealed,
    Value<int>? rowid,
  }) {
    return UniversalPricingVersionsCompanion(
      businessId: businessId ?? this.businessId,
      profileId: profileId ?? this.profileId,
      version: version ?? this.version,
      engineVersion: engineVersion ?? this.engineVersion,
      effectiveAt: effectiveAt ?? this.effectiveAt,
      expiresAt: expiresAt ?? this.expiresAt,
      publishedAt: publishedAt ?? this.publishedAt,
      publishedBy: publishedBy ?? this.publishedBy,
      snapshotJson: snapshotJson ?? this.snapshotJson,
      sealed: sealed ?? this.sealed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (engineVersion.present) {
      map['engine_version'] = Variable<String>(engineVersion.value);
    }
    if (effectiveAt.present) {
      map['effective_at'] = Variable<int>(effectiveAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<int>(expiresAt.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<int>(publishedAt.value);
    }
    if (publishedBy.present) {
      map['published_by'] = Variable<String>(publishedBy.value);
    }
    if (snapshotJson.present) {
      map['snapshot_json'] = Variable<String>(snapshotJson.value);
    }
    if (sealed.present) {
      map['sealed'] = Variable<int>(sealed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UniversalPricingVersionsCompanion(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('version: $version, ')
          ..write('engineVersion: $engineVersion, ')
          ..write('effectiveAt: $effectiveAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('publishedBy: $publishedBy, ')
          ..write('snapshotJson: $snapshotJson, ')
          ..write('sealed: $sealed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class UniversalPricingCategories extends Table
    with TableInfo<UniversalPricingCategories, UniversalPricingCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  UniversalPricingCategories(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    businessId,
    profileId,
    version,
    id,
    parentId,
    name,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'universal_pricing_categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<UniversalPricingCategory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
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
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {businessId, profileId, version, id};
  @override
  UniversalPricingCategory map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UniversalPricingCategory(
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  UniversalPricingCategories createAlias(String alias) {
    return UniversalPricingCategories(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(business_id, profile_id, version, id)',
    'FOREIGN KEY(business_id, profile_id, version)REFERENCES universal_pricing_versions(business_id, profile_id, version)',
    'FOREIGN KEY(business_id, profile_id, version, parent_id)REFERENCES universal_pricing_categories(business_id, profile_id, version, id)DEFERRABLE INITIALLY DEFERRED',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class UniversalPricingCategory extends DataClass
    implements Insertable<UniversalPricingCategory> {
  final String businessId;
  final String profileId;
  final int version;
  final String id;
  final String? parentId;
  final String name;
  final int sortOrder;
  const UniversalPricingCategory({
    required this.businessId,
    required this.profileId,
    required this.version,
    required this.id,
    this.parentId,
    required this.name,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['business_id'] = Variable<String>(businessId);
    map['profile_id'] = Variable<String>(profileId);
    map['version'] = Variable<int>(version);
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['name'] = Variable<String>(name);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  UniversalPricingCategoriesCompanion toCompanion(bool nullToAbsent) {
    return UniversalPricingCategoriesCompanion(
      businessId: Value(businessId),
      profileId: Value(profileId),
      version: Value(version),
      id: Value(id),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      name: Value(name),
      sortOrder: Value(sortOrder),
    );
  }

  factory UniversalPricingCategory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UniversalPricingCategory(
      businessId: serializer.fromJson<String>(json['business_id']),
      profileId: serializer.fromJson<String>(json['profile_id']),
      version: serializer.fromJson<int>(json['version']),
      id: serializer.fromJson<String>(json['id']),
      parentId: serializer.fromJson<String?>(json['parent_id']),
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sort_order']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'business_id': serializer.toJson<String>(businessId),
      'profile_id': serializer.toJson<String>(profileId),
      'version': serializer.toJson<int>(version),
      'id': serializer.toJson<String>(id),
      'parent_id': serializer.toJson<String?>(parentId),
      'name': serializer.toJson<String>(name),
      'sort_order': serializer.toJson<int>(sortOrder),
    };
  }

  UniversalPricingCategory copyWith({
    String? businessId,
    String? profileId,
    int? version,
    String? id,
    Value<String?> parentId = const Value.absent(),
    String? name,
    int? sortOrder,
  }) => UniversalPricingCategory(
    businessId: businessId ?? this.businessId,
    profileId: profileId ?? this.profileId,
    version: version ?? this.version,
    id: id ?? this.id,
    parentId: parentId.present ? parentId.value : this.parentId,
    name: name ?? this.name,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  UniversalPricingCategory copyWithCompanion(
    UniversalPricingCategoriesCompanion data,
  ) {
    return UniversalPricingCategory(
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      version: data.version.present ? data.version.value : this.version,
      id: data.id.present ? data.id.value : this.id,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UniversalPricingCategory(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('version: $version, ')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    businessId,
    profileId,
    version,
    id,
    parentId,
    name,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UniversalPricingCategory &&
          other.businessId == this.businessId &&
          other.profileId == this.profileId &&
          other.version == this.version &&
          other.id == this.id &&
          other.parentId == this.parentId &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder);
}

class UniversalPricingCategoriesCompanion
    extends UpdateCompanion<UniversalPricingCategory> {
  final Value<String> businessId;
  final Value<String> profileId;
  final Value<int> version;
  final Value<String> id;
  final Value<String?> parentId;
  final Value<String> name;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const UniversalPricingCategoriesCompanion({
    this.businessId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.version = const Value.absent(),
    this.id = const Value.absent(),
    this.parentId = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UniversalPricingCategoriesCompanion.insert({
    required String businessId,
    required String profileId,
    required int version,
    required String id,
    this.parentId = const Value.absent(),
    required String name,
    required int sortOrder,
    this.rowid = const Value.absent(),
  }) : businessId = Value(businessId),
       profileId = Value(profileId),
       version = Value(version),
       id = Value(id),
       name = Value(name),
       sortOrder = Value(sortOrder);
  static Insertable<UniversalPricingCategory> custom({
    Expression<String>? businessId,
    Expression<String>? profileId,
    Expression<int>? version,
    Expression<String>? id,
    Expression<String>? parentId,
    Expression<String>? name,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (businessId != null) 'business_id': businessId,
      if (profileId != null) 'profile_id': profileId,
      if (version != null) 'version': version,
      if (id != null) 'id': id,
      if (parentId != null) 'parent_id': parentId,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UniversalPricingCategoriesCompanion copyWith({
    Value<String>? businessId,
    Value<String>? profileId,
    Value<int>? version,
    Value<String>? id,
    Value<String?>? parentId,
    Value<String>? name,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return UniversalPricingCategoriesCompanion(
      businessId: businessId ?? this.businessId,
      profileId: profileId ?? this.profileId,
      version: version ?? this.version,
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
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
    return (StringBuffer('UniversalPricingCategoriesCompanion(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('version: $version, ')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class UniversalPricingProducts extends Table
    with TableInfo<UniversalPricingProducts, UniversalPricingProduct> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  UniversalPricingProducts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _ruleIdMeta = const VerificationMeta('ruleId');
  late final GeneratedColumn<String> ruleId = GeneratedColumn<String>(
    'rule_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _strategyKindMeta = const VerificationMeta(
    'strategyKind',
  );
  late final GeneratedColumn<String> strategyKind = GeneratedColumn<String>(
    'strategy_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _attributesJsonMeta = const VerificationMeta(
    'attributesJson',
  );
  late final GeneratedColumn<String> attributesJson = GeneratedColumn<String>(
    'attributes_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _ruleJsonMeta = const VerificationMeta(
    'ruleJson',
  );
  late final GeneratedColumn<String> ruleJson = GeneratedColumn<String>(
    'rule_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    businessId,
    profileId,
    version,
    id,
    categoryId,
    name,
    ruleId,
    strategyKind,
    attributesJson,
    ruleJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'universal_pricing_products';
  @override
  VerificationContext validateIntegrity(
    Insertable<UniversalPricingProduct> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('rule_id')) {
      context.handle(
        _ruleIdMeta,
        ruleId.isAcceptableOrUnknown(data['rule_id']!, _ruleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ruleIdMeta);
    }
    if (data.containsKey('strategy_kind')) {
      context.handle(
        _strategyKindMeta,
        strategyKind.isAcceptableOrUnknown(
          data['strategy_kind']!,
          _strategyKindMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_strategyKindMeta);
    }
    if (data.containsKey('attributes_json')) {
      context.handle(
        _attributesJsonMeta,
        attributesJson.isAcceptableOrUnknown(
          data['attributes_json']!,
          _attributesJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_attributesJsonMeta);
    }
    if (data.containsKey('rule_json')) {
      context.handle(
        _ruleJsonMeta,
        ruleJson.isAcceptableOrUnknown(data['rule_json']!, _ruleJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_ruleJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {businessId, profileId, version, id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {businessId, profileId, version, ruleId},
  ];
  @override
  UniversalPricingProduct map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UniversalPricingProduct(
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      ruleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rule_id'],
      )!,
      strategyKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}strategy_kind'],
      )!,
      attributesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attributes_json'],
      )!,
      ruleJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rule_json'],
      )!,
    );
  }

  @override
  UniversalPricingProducts createAlias(String alias) {
    return UniversalPricingProducts(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(business_id, profile_id, version, id)',
    'UNIQUE(business_id, profile_id, version, rule_id)',
    'FOREIGN KEY(business_id, profile_id, version, category_id)REFERENCES universal_pricing_categories(business_id, profile_id, version, id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class UniversalPricingProduct extends DataClass
    implements Insertable<UniversalPricingProduct> {
  final String businessId;
  final String profileId;
  final int version;
  final String id;
  final String categoryId;
  final String name;
  final String ruleId;
  final String strategyKind;
  final String attributesJson;
  final String ruleJson;
  const UniversalPricingProduct({
    required this.businessId,
    required this.profileId,
    required this.version,
    required this.id,
    required this.categoryId,
    required this.name,
    required this.ruleId,
    required this.strategyKind,
    required this.attributesJson,
    required this.ruleJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['business_id'] = Variable<String>(businessId);
    map['profile_id'] = Variable<String>(profileId);
    map['version'] = Variable<int>(version);
    map['id'] = Variable<String>(id);
    map['category_id'] = Variable<String>(categoryId);
    map['name'] = Variable<String>(name);
    map['rule_id'] = Variable<String>(ruleId);
    map['strategy_kind'] = Variable<String>(strategyKind);
    map['attributes_json'] = Variable<String>(attributesJson);
    map['rule_json'] = Variable<String>(ruleJson);
    return map;
  }

  UniversalPricingProductsCompanion toCompanion(bool nullToAbsent) {
    return UniversalPricingProductsCompanion(
      businessId: Value(businessId),
      profileId: Value(profileId),
      version: Value(version),
      id: Value(id),
      categoryId: Value(categoryId),
      name: Value(name),
      ruleId: Value(ruleId),
      strategyKind: Value(strategyKind),
      attributesJson: Value(attributesJson),
      ruleJson: Value(ruleJson),
    );
  }

  factory UniversalPricingProduct.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UniversalPricingProduct(
      businessId: serializer.fromJson<String>(json['business_id']),
      profileId: serializer.fromJson<String>(json['profile_id']),
      version: serializer.fromJson<int>(json['version']),
      id: serializer.fromJson<String>(json['id']),
      categoryId: serializer.fromJson<String>(json['category_id']),
      name: serializer.fromJson<String>(json['name']),
      ruleId: serializer.fromJson<String>(json['rule_id']),
      strategyKind: serializer.fromJson<String>(json['strategy_kind']),
      attributesJson: serializer.fromJson<String>(json['attributes_json']),
      ruleJson: serializer.fromJson<String>(json['rule_json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'business_id': serializer.toJson<String>(businessId),
      'profile_id': serializer.toJson<String>(profileId),
      'version': serializer.toJson<int>(version),
      'id': serializer.toJson<String>(id),
      'category_id': serializer.toJson<String>(categoryId),
      'name': serializer.toJson<String>(name),
      'rule_id': serializer.toJson<String>(ruleId),
      'strategy_kind': serializer.toJson<String>(strategyKind),
      'attributes_json': serializer.toJson<String>(attributesJson),
      'rule_json': serializer.toJson<String>(ruleJson),
    };
  }

  UniversalPricingProduct copyWith({
    String? businessId,
    String? profileId,
    int? version,
    String? id,
    String? categoryId,
    String? name,
    String? ruleId,
    String? strategyKind,
    String? attributesJson,
    String? ruleJson,
  }) => UniversalPricingProduct(
    businessId: businessId ?? this.businessId,
    profileId: profileId ?? this.profileId,
    version: version ?? this.version,
    id: id ?? this.id,
    categoryId: categoryId ?? this.categoryId,
    name: name ?? this.name,
    ruleId: ruleId ?? this.ruleId,
    strategyKind: strategyKind ?? this.strategyKind,
    attributesJson: attributesJson ?? this.attributesJson,
    ruleJson: ruleJson ?? this.ruleJson,
  );
  UniversalPricingProduct copyWithCompanion(
    UniversalPricingProductsCompanion data,
  ) {
    return UniversalPricingProduct(
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      version: data.version.present ? data.version.value : this.version,
      id: data.id.present ? data.id.value : this.id,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      name: data.name.present ? data.name.value : this.name,
      ruleId: data.ruleId.present ? data.ruleId.value : this.ruleId,
      strategyKind: data.strategyKind.present
          ? data.strategyKind.value
          : this.strategyKind,
      attributesJson: data.attributesJson.present
          ? data.attributesJson.value
          : this.attributesJson,
      ruleJson: data.ruleJson.present ? data.ruleJson.value : this.ruleJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UniversalPricingProduct(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('version: $version, ')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('ruleId: $ruleId, ')
          ..write('strategyKind: $strategyKind, ')
          ..write('attributesJson: $attributesJson, ')
          ..write('ruleJson: $ruleJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    businessId,
    profileId,
    version,
    id,
    categoryId,
    name,
    ruleId,
    strategyKind,
    attributesJson,
    ruleJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UniversalPricingProduct &&
          other.businessId == this.businessId &&
          other.profileId == this.profileId &&
          other.version == this.version &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.name == this.name &&
          other.ruleId == this.ruleId &&
          other.strategyKind == this.strategyKind &&
          other.attributesJson == this.attributesJson &&
          other.ruleJson == this.ruleJson);
}

class UniversalPricingProductsCompanion
    extends UpdateCompanion<UniversalPricingProduct> {
  final Value<String> businessId;
  final Value<String> profileId;
  final Value<int> version;
  final Value<String> id;
  final Value<String> categoryId;
  final Value<String> name;
  final Value<String> ruleId;
  final Value<String> strategyKind;
  final Value<String> attributesJson;
  final Value<String> ruleJson;
  final Value<int> rowid;
  const UniversalPricingProductsCompanion({
    this.businessId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.version = const Value.absent(),
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.name = const Value.absent(),
    this.ruleId = const Value.absent(),
    this.strategyKind = const Value.absent(),
    this.attributesJson = const Value.absent(),
    this.ruleJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UniversalPricingProductsCompanion.insert({
    required String businessId,
    required String profileId,
    required int version,
    required String id,
    required String categoryId,
    required String name,
    required String ruleId,
    required String strategyKind,
    required String attributesJson,
    required String ruleJson,
    this.rowid = const Value.absent(),
  }) : businessId = Value(businessId),
       profileId = Value(profileId),
       version = Value(version),
       id = Value(id),
       categoryId = Value(categoryId),
       name = Value(name),
       ruleId = Value(ruleId),
       strategyKind = Value(strategyKind),
       attributesJson = Value(attributesJson),
       ruleJson = Value(ruleJson);
  static Insertable<UniversalPricingProduct> custom({
    Expression<String>? businessId,
    Expression<String>? profileId,
    Expression<int>? version,
    Expression<String>? id,
    Expression<String>? categoryId,
    Expression<String>? name,
    Expression<String>? ruleId,
    Expression<String>? strategyKind,
    Expression<String>? attributesJson,
    Expression<String>? ruleJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (businessId != null) 'business_id': businessId,
      if (profileId != null) 'profile_id': profileId,
      if (version != null) 'version': version,
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (name != null) 'name': name,
      if (ruleId != null) 'rule_id': ruleId,
      if (strategyKind != null) 'strategy_kind': strategyKind,
      if (attributesJson != null) 'attributes_json': attributesJson,
      if (ruleJson != null) 'rule_json': ruleJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UniversalPricingProductsCompanion copyWith({
    Value<String>? businessId,
    Value<String>? profileId,
    Value<int>? version,
    Value<String>? id,
    Value<String>? categoryId,
    Value<String>? name,
    Value<String>? ruleId,
    Value<String>? strategyKind,
    Value<String>? attributesJson,
    Value<String>? ruleJson,
    Value<int>? rowid,
  }) {
    return UniversalPricingProductsCompanion(
      businessId: businessId ?? this.businessId,
      profileId: profileId ?? this.profileId,
      version: version ?? this.version,
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      ruleId: ruleId ?? this.ruleId,
      strategyKind: strategyKind ?? this.strategyKind,
      attributesJson: attributesJson ?? this.attributesJson,
      ruleJson: ruleJson ?? this.ruleJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (ruleId.present) {
      map['rule_id'] = Variable<String>(ruleId.value);
    }
    if (strategyKind.present) {
      map['strategy_kind'] = Variable<String>(strategyKind.value);
    }
    if (attributesJson.present) {
      map['attributes_json'] = Variable<String>(attributesJson.value);
    }
    if (ruleJson.present) {
      map['rule_json'] = Variable<String>(ruleJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UniversalPricingProductsCompanion(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('version: $version, ')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('ruleId: $ruleId, ')
          ..write('strategyKind: $strategyKind, ')
          ..write('attributesJson: $attributesJson, ')
          ..write('ruleJson: $ruleJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class UniversalPricingInputs extends Table
    with TableInfo<UniversalPricingInputs, UniversalPricingInput> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  UniversalPricingInputs(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _definitionJsonMeta = const VerificationMeta(
    'definitionJson',
  );
  late final GeneratedColumn<String> definitionJson = GeneratedColumn<String>(
    'definition_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    businessId,
    profileId,
    version,
    productId,
    id,
    sortOrder,
    definitionJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'universal_pricing_inputs';
  @override
  VerificationContext validateIntegrity(
    Insertable<UniversalPricingInput> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('definition_json')) {
      context.handle(
        _definitionJsonMeta,
        definitionJson.isAcceptableOrUnknown(
          data['definition_json']!,
          _definitionJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_definitionJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    businessId,
    profileId,
    version,
    productId,
    id,
  };
  @override
  UniversalPricingInput map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UniversalPricingInput(
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      definitionJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}definition_json'],
      )!,
    );
  }

  @override
  UniversalPricingInputs createAlias(String alias) {
    return UniversalPricingInputs(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(business_id, profile_id, version, product_id, id)',
    'FOREIGN KEY(business_id, profile_id, version, product_id)REFERENCES universal_pricing_products(business_id, profile_id, version, id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class UniversalPricingInput extends DataClass
    implements Insertable<UniversalPricingInput> {
  final String businessId;
  final String profileId;
  final int version;
  final String productId;
  final String id;
  final int sortOrder;
  final String definitionJson;
  const UniversalPricingInput({
    required this.businessId,
    required this.profileId,
    required this.version,
    required this.productId,
    required this.id,
    required this.sortOrder,
    required this.definitionJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['business_id'] = Variable<String>(businessId);
    map['profile_id'] = Variable<String>(profileId);
    map['version'] = Variable<int>(version);
    map['product_id'] = Variable<String>(productId);
    map['id'] = Variable<String>(id);
    map['sort_order'] = Variable<int>(sortOrder);
    map['definition_json'] = Variable<String>(definitionJson);
    return map;
  }

  UniversalPricingInputsCompanion toCompanion(bool nullToAbsent) {
    return UniversalPricingInputsCompanion(
      businessId: Value(businessId),
      profileId: Value(profileId),
      version: Value(version),
      productId: Value(productId),
      id: Value(id),
      sortOrder: Value(sortOrder),
      definitionJson: Value(definitionJson),
    );
  }

  factory UniversalPricingInput.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UniversalPricingInput(
      businessId: serializer.fromJson<String>(json['business_id']),
      profileId: serializer.fromJson<String>(json['profile_id']),
      version: serializer.fromJson<int>(json['version']),
      productId: serializer.fromJson<String>(json['product_id']),
      id: serializer.fromJson<String>(json['id']),
      sortOrder: serializer.fromJson<int>(json['sort_order']),
      definitionJson: serializer.fromJson<String>(json['definition_json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'business_id': serializer.toJson<String>(businessId),
      'profile_id': serializer.toJson<String>(profileId),
      'version': serializer.toJson<int>(version),
      'product_id': serializer.toJson<String>(productId),
      'id': serializer.toJson<String>(id),
      'sort_order': serializer.toJson<int>(sortOrder),
      'definition_json': serializer.toJson<String>(definitionJson),
    };
  }

  UniversalPricingInput copyWith({
    String? businessId,
    String? profileId,
    int? version,
    String? productId,
    String? id,
    int? sortOrder,
    String? definitionJson,
  }) => UniversalPricingInput(
    businessId: businessId ?? this.businessId,
    profileId: profileId ?? this.profileId,
    version: version ?? this.version,
    productId: productId ?? this.productId,
    id: id ?? this.id,
    sortOrder: sortOrder ?? this.sortOrder,
    definitionJson: definitionJson ?? this.definitionJson,
  );
  UniversalPricingInput copyWithCompanion(
    UniversalPricingInputsCompanion data,
  ) {
    return UniversalPricingInput(
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      version: data.version.present ? data.version.value : this.version,
      productId: data.productId.present ? data.productId.value : this.productId,
      id: data.id.present ? data.id.value : this.id,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      definitionJson: data.definitionJson.present
          ? data.definitionJson.value
          : this.definitionJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UniversalPricingInput(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('version: $version, ')
          ..write('productId: $productId, ')
          ..write('id: $id, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('definitionJson: $definitionJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    businessId,
    profileId,
    version,
    productId,
    id,
    sortOrder,
    definitionJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UniversalPricingInput &&
          other.businessId == this.businessId &&
          other.profileId == this.profileId &&
          other.version == this.version &&
          other.productId == this.productId &&
          other.id == this.id &&
          other.sortOrder == this.sortOrder &&
          other.definitionJson == this.definitionJson);
}

class UniversalPricingInputsCompanion
    extends UpdateCompanion<UniversalPricingInput> {
  final Value<String> businessId;
  final Value<String> profileId;
  final Value<int> version;
  final Value<String> productId;
  final Value<String> id;
  final Value<int> sortOrder;
  final Value<String> definitionJson;
  final Value<int> rowid;
  const UniversalPricingInputsCompanion({
    this.businessId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.version = const Value.absent(),
    this.productId = const Value.absent(),
    this.id = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.definitionJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UniversalPricingInputsCompanion.insert({
    required String businessId,
    required String profileId,
    required int version,
    required String productId,
    required String id,
    required int sortOrder,
    required String definitionJson,
    this.rowid = const Value.absent(),
  }) : businessId = Value(businessId),
       profileId = Value(profileId),
       version = Value(version),
       productId = Value(productId),
       id = Value(id),
       sortOrder = Value(sortOrder),
       definitionJson = Value(definitionJson);
  static Insertable<UniversalPricingInput> custom({
    Expression<String>? businessId,
    Expression<String>? profileId,
    Expression<int>? version,
    Expression<String>? productId,
    Expression<String>? id,
    Expression<int>? sortOrder,
    Expression<String>? definitionJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (businessId != null) 'business_id': businessId,
      if (profileId != null) 'profile_id': profileId,
      if (version != null) 'version': version,
      if (productId != null) 'product_id': productId,
      if (id != null) 'id': id,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (definitionJson != null) 'definition_json': definitionJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UniversalPricingInputsCompanion copyWith({
    Value<String>? businessId,
    Value<String>? profileId,
    Value<int>? version,
    Value<String>? productId,
    Value<String>? id,
    Value<int>? sortOrder,
    Value<String>? definitionJson,
    Value<int>? rowid,
  }) {
    return UniversalPricingInputsCompanion(
      businessId: businessId ?? this.businessId,
      profileId: profileId ?? this.profileId,
      version: version ?? this.version,
      productId: productId ?? this.productId,
      id: id ?? this.id,
      sortOrder: sortOrder ?? this.sortOrder,
      definitionJson: definitionJson ?? this.definitionJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (definitionJson.present) {
      map['definition_json'] = Variable<String>(definitionJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UniversalPricingInputsCompanion(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('version: $version, ')
          ..write('productId: $productId, ')
          ..write('id: $id, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('definitionJson: $definitionJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class UniversalPricingRates extends Table
    with TableInfo<UniversalPricingRates, UniversalPricingRate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  UniversalPricingRates(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _rateKeyMeta = const VerificationMeta(
    'rateKey',
  );
  late final GeneratedColumn<String> rateKey = GeneratedColumn<String>(
    'rate_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _amountDecimalMeta = const VerificationMeta(
    'amountDecimal',
  );
  late final GeneratedColumn<String> amountDecimal = GeneratedColumn<String>(
    'amount_decimal',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _selectorsJsonMeta = const VerificationMeta(
    'selectorsJson',
  );
  late final GeneratedColumn<String> selectorsJson = GeneratedColumn<String>(
    'selectors_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    businessId,
    profileId,
    version,
    productId,
    id,
    rateKey,
    amountDecimal,
    unit,
    selectorsJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'universal_pricing_rates';
  @override
  VerificationContext validateIntegrity(
    Insertable<UniversalPricingRate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('rate_key')) {
      context.handle(
        _rateKeyMeta,
        rateKey.isAcceptableOrUnknown(data['rate_key']!, _rateKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_rateKeyMeta);
    }
    if (data.containsKey('amount_decimal')) {
      context.handle(
        _amountDecimalMeta,
        amountDecimal.isAcceptableOrUnknown(
          data['amount_decimal']!,
          _amountDecimalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountDecimalMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('selectors_json')) {
      context.handle(
        _selectorsJsonMeta,
        selectorsJson.isAcceptableOrUnknown(
          data['selectors_json']!,
          _selectorsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_selectorsJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    businessId,
    profileId,
    version,
    productId,
    id,
  };
  @override
  UniversalPricingRate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UniversalPricingRate(
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      rateKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rate_key'],
      )!,
      amountDecimal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}amount_decimal'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      selectorsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selectors_json'],
      )!,
    );
  }

  @override
  UniversalPricingRates createAlias(String alias) {
    return UniversalPricingRates(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(business_id, profile_id, version, product_id, id)',
    'FOREIGN KEY(business_id, profile_id, version, product_id)REFERENCES universal_pricing_products(business_id, profile_id, version, id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class UniversalPricingRate extends DataClass
    implements Insertable<UniversalPricingRate> {
  final String businessId;
  final String profileId;
  final int version;
  final String productId;
  final String id;
  final String rateKey;
  final String amountDecimal;
  final String unit;
  final String selectorsJson;
  const UniversalPricingRate({
    required this.businessId,
    required this.profileId,
    required this.version,
    required this.productId,
    required this.id,
    required this.rateKey,
    required this.amountDecimal,
    required this.unit,
    required this.selectorsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['business_id'] = Variable<String>(businessId);
    map['profile_id'] = Variable<String>(profileId);
    map['version'] = Variable<int>(version);
    map['product_id'] = Variable<String>(productId);
    map['id'] = Variable<String>(id);
    map['rate_key'] = Variable<String>(rateKey);
    map['amount_decimal'] = Variable<String>(amountDecimal);
    map['unit'] = Variable<String>(unit);
    map['selectors_json'] = Variable<String>(selectorsJson);
    return map;
  }

  UniversalPricingRatesCompanion toCompanion(bool nullToAbsent) {
    return UniversalPricingRatesCompanion(
      businessId: Value(businessId),
      profileId: Value(profileId),
      version: Value(version),
      productId: Value(productId),
      id: Value(id),
      rateKey: Value(rateKey),
      amountDecimal: Value(amountDecimal),
      unit: Value(unit),
      selectorsJson: Value(selectorsJson),
    );
  }

  factory UniversalPricingRate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UniversalPricingRate(
      businessId: serializer.fromJson<String>(json['business_id']),
      profileId: serializer.fromJson<String>(json['profile_id']),
      version: serializer.fromJson<int>(json['version']),
      productId: serializer.fromJson<String>(json['product_id']),
      id: serializer.fromJson<String>(json['id']),
      rateKey: serializer.fromJson<String>(json['rate_key']),
      amountDecimal: serializer.fromJson<String>(json['amount_decimal']),
      unit: serializer.fromJson<String>(json['unit']),
      selectorsJson: serializer.fromJson<String>(json['selectors_json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'business_id': serializer.toJson<String>(businessId),
      'profile_id': serializer.toJson<String>(profileId),
      'version': serializer.toJson<int>(version),
      'product_id': serializer.toJson<String>(productId),
      'id': serializer.toJson<String>(id),
      'rate_key': serializer.toJson<String>(rateKey),
      'amount_decimal': serializer.toJson<String>(amountDecimal),
      'unit': serializer.toJson<String>(unit),
      'selectors_json': serializer.toJson<String>(selectorsJson),
    };
  }

  UniversalPricingRate copyWith({
    String? businessId,
    String? profileId,
    int? version,
    String? productId,
    String? id,
    String? rateKey,
    String? amountDecimal,
    String? unit,
    String? selectorsJson,
  }) => UniversalPricingRate(
    businessId: businessId ?? this.businessId,
    profileId: profileId ?? this.profileId,
    version: version ?? this.version,
    productId: productId ?? this.productId,
    id: id ?? this.id,
    rateKey: rateKey ?? this.rateKey,
    amountDecimal: amountDecimal ?? this.amountDecimal,
    unit: unit ?? this.unit,
    selectorsJson: selectorsJson ?? this.selectorsJson,
  );
  UniversalPricingRate copyWithCompanion(UniversalPricingRatesCompanion data) {
    return UniversalPricingRate(
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      version: data.version.present ? data.version.value : this.version,
      productId: data.productId.present ? data.productId.value : this.productId,
      id: data.id.present ? data.id.value : this.id,
      rateKey: data.rateKey.present ? data.rateKey.value : this.rateKey,
      amountDecimal: data.amountDecimal.present
          ? data.amountDecimal.value
          : this.amountDecimal,
      unit: data.unit.present ? data.unit.value : this.unit,
      selectorsJson: data.selectorsJson.present
          ? data.selectorsJson.value
          : this.selectorsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UniversalPricingRate(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('version: $version, ')
          ..write('productId: $productId, ')
          ..write('id: $id, ')
          ..write('rateKey: $rateKey, ')
          ..write('amountDecimal: $amountDecimal, ')
          ..write('unit: $unit, ')
          ..write('selectorsJson: $selectorsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    businessId,
    profileId,
    version,
    productId,
    id,
    rateKey,
    amountDecimal,
    unit,
    selectorsJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UniversalPricingRate &&
          other.businessId == this.businessId &&
          other.profileId == this.profileId &&
          other.version == this.version &&
          other.productId == this.productId &&
          other.id == this.id &&
          other.rateKey == this.rateKey &&
          other.amountDecimal == this.amountDecimal &&
          other.unit == this.unit &&
          other.selectorsJson == this.selectorsJson);
}

class UniversalPricingRatesCompanion
    extends UpdateCompanion<UniversalPricingRate> {
  final Value<String> businessId;
  final Value<String> profileId;
  final Value<int> version;
  final Value<String> productId;
  final Value<String> id;
  final Value<String> rateKey;
  final Value<String> amountDecimal;
  final Value<String> unit;
  final Value<String> selectorsJson;
  final Value<int> rowid;
  const UniversalPricingRatesCompanion({
    this.businessId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.version = const Value.absent(),
    this.productId = const Value.absent(),
    this.id = const Value.absent(),
    this.rateKey = const Value.absent(),
    this.amountDecimal = const Value.absent(),
    this.unit = const Value.absent(),
    this.selectorsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UniversalPricingRatesCompanion.insert({
    required String businessId,
    required String profileId,
    required int version,
    required String productId,
    required String id,
    required String rateKey,
    required String amountDecimal,
    required String unit,
    required String selectorsJson,
    this.rowid = const Value.absent(),
  }) : businessId = Value(businessId),
       profileId = Value(profileId),
       version = Value(version),
       productId = Value(productId),
       id = Value(id),
       rateKey = Value(rateKey),
       amountDecimal = Value(amountDecimal),
       unit = Value(unit),
       selectorsJson = Value(selectorsJson);
  static Insertable<UniversalPricingRate> custom({
    Expression<String>? businessId,
    Expression<String>? profileId,
    Expression<int>? version,
    Expression<String>? productId,
    Expression<String>? id,
    Expression<String>? rateKey,
    Expression<String>? amountDecimal,
    Expression<String>? unit,
    Expression<String>? selectorsJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (businessId != null) 'business_id': businessId,
      if (profileId != null) 'profile_id': profileId,
      if (version != null) 'version': version,
      if (productId != null) 'product_id': productId,
      if (id != null) 'id': id,
      if (rateKey != null) 'rate_key': rateKey,
      if (amountDecimal != null) 'amount_decimal': amountDecimal,
      if (unit != null) 'unit': unit,
      if (selectorsJson != null) 'selectors_json': selectorsJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UniversalPricingRatesCompanion copyWith({
    Value<String>? businessId,
    Value<String>? profileId,
    Value<int>? version,
    Value<String>? productId,
    Value<String>? id,
    Value<String>? rateKey,
    Value<String>? amountDecimal,
    Value<String>? unit,
    Value<String>? selectorsJson,
    Value<int>? rowid,
  }) {
    return UniversalPricingRatesCompanion(
      businessId: businessId ?? this.businessId,
      profileId: profileId ?? this.profileId,
      version: version ?? this.version,
      productId: productId ?? this.productId,
      id: id ?? this.id,
      rateKey: rateKey ?? this.rateKey,
      amountDecimal: amountDecimal ?? this.amountDecimal,
      unit: unit ?? this.unit,
      selectorsJson: selectorsJson ?? this.selectorsJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (rateKey.present) {
      map['rate_key'] = Variable<String>(rateKey.value);
    }
    if (amountDecimal.present) {
      map['amount_decimal'] = Variable<String>(amountDecimal.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (selectorsJson.present) {
      map['selectors_json'] = Variable<String>(selectorsJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UniversalPricingRatesCompanion(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('version: $version, ')
          ..write('productId: $productId, ')
          ..write('id: $id, ')
          ..write('rateKey: $rateKey, ')
          ..write('amountDecimal: $amountDecimal, ')
          ..write('unit: $unit, ')
          ..write('selectorsJson: $selectorsJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class UniversalPricingUnitSystems extends Table
    with TableInfo<UniversalPricingUnitSystems, UniversalPricingUnitSystem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  UniversalPricingUnitSystems(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _snapshotJsonMeta = const VerificationMeta(
    'snapshotJson',
  );
  late final GeneratedColumn<String> snapshotJson = GeneratedColumn<String>(
    'snapshot_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    businessId,
    profileId,
    version,
    productId,
    snapshotJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'universal_pricing_unit_systems';
  @override
  VerificationContext validateIntegrity(
    Insertable<UniversalPricingUnitSystem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('snapshot_json')) {
      context.handle(
        _snapshotJsonMeta,
        snapshotJson.isAcceptableOrUnknown(
          data['snapshot_json']!,
          _snapshotJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_snapshotJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    businessId,
    profileId,
    version,
    productId,
  };
  @override
  UniversalPricingUnitSystem map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UniversalPricingUnitSystem(
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      snapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_json'],
      )!,
    );
  }

  @override
  UniversalPricingUnitSystems createAlias(String alias) {
    return UniversalPricingUnitSystems(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(business_id, profile_id, version, product_id)',
    'FOREIGN KEY(business_id, profile_id, version, product_id)REFERENCES universal_pricing_products(business_id, profile_id, version, id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class UniversalPricingUnitSystem extends DataClass
    implements Insertable<UniversalPricingUnitSystem> {
  final String businessId;
  final String profileId;
  final int version;
  final String productId;
  final String snapshotJson;
  const UniversalPricingUnitSystem({
    required this.businessId,
    required this.profileId,
    required this.version,
    required this.productId,
    required this.snapshotJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['business_id'] = Variable<String>(businessId);
    map['profile_id'] = Variable<String>(profileId);
    map['version'] = Variable<int>(version);
    map['product_id'] = Variable<String>(productId);
    map['snapshot_json'] = Variable<String>(snapshotJson);
    return map;
  }

  UniversalPricingUnitSystemsCompanion toCompanion(bool nullToAbsent) {
    return UniversalPricingUnitSystemsCompanion(
      businessId: Value(businessId),
      profileId: Value(profileId),
      version: Value(version),
      productId: Value(productId),
      snapshotJson: Value(snapshotJson),
    );
  }

  factory UniversalPricingUnitSystem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UniversalPricingUnitSystem(
      businessId: serializer.fromJson<String>(json['business_id']),
      profileId: serializer.fromJson<String>(json['profile_id']),
      version: serializer.fromJson<int>(json['version']),
      productId: serializer.fromJson<String>(json['product_id']),
      snapshotJson: serializer.fromJson<String>(json['snapshot_json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'business_id': serializer.toJson<String>(businessId),
      'profile_id': serializer.toJson<String>(profileId),
      'version': serializer.toJson<int>(version),
      'product_id': serializer.toJson<String>(productId),
      'snapshot_json': serializer.toJson<String>(snapshotJson),
    };
  }

  UniversalPricingUnitSystem copyWith({
    String? businessId,
    String? profileId,
    int? version,
    String? productId,
    String? snapshotJson,
  }) => UniversalPricingUnitSystem(
    businessId: businessId ?? this.businessId,
    profileId: profileId ?? this.profileId,
    version: version ?? this.version,
    productId: productId ?? this.productId,
    snapshotJson: snapshotJson ?? this.snapshotJson,
  );
  UniversalPricingUnitSystem copyWithCompanion(
    UniversalPricingUnitSystemsCompanion data,
  ) {
    return UniversalPricingUnitSystem(
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      version: data.version.present ? data.version.value : this.version,
      productId: data.productId.present ? data.productId.value : this.productId,
      snapshotJson: data.snapshotJson.present
          ? data.snapshotJson.value
          : this.snapshotJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UniversalPricingUnitSystem(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('version: $version, ')
          ..write('productId: $productId, ')
          ..write('snapshotJson: $snapshotJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(businessId, profileId, version, productId, snapshotJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UniversalPricingUnitSystem &&
          other.businessId == this.businessId &&
          other.profileId == this.profileId &&
          other.version == this.version &&
          other.productId == this.productId &&
          other.snapshotJson == this.snapshotJson);
}

class UniversalPricingUnitSystemsCompanion
    extends UpdateCompanion<UniversalPricingUnitSystem> {
  final Value<String> businessId;
  final Value<String> profileId;
  final Value<int> version;
  final Value<String> productId;
  final Value<String> snapshotJson;
  final Value<int> rowid;
  const UniversalPricingUnitSystemsCompanion({
    this.businessId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.version = const Value.absent(),
    this.productId = const Value.absent(),
    this.snapshotJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UniversalPricingUnitSystemsCompanion.insert({
    required String businessId,
    required String profileId,
    required int version,
    required String productId,
    required String snapshotJson,
    this.rowid = const Value.absent(),
  }) : businessId = Value(businessId),
       profileId = Value(profileId),
       version = Value(version),
       productId = Value(productId),
       snapshotJson = Value(snapshotJson);
  static Insertable<UniversalPricingUnitSystem> custom({
    Expression<String>? businessId,
    Expression<String>? profileId,
    Expression<int>? version,
    Expression<String>? productId,
    Expression<String>? snapshotJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (businessId != null) 'business_id': businessId,
      if (profileId != null) 'profile_id': profileId,
      if (version != null) 'version': version,
      if (productId != null) 'product_id': productId,
      if (snapshotJson != null) 'snapshot_json': snapshotJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UniversalPricingUnitSystemsCompanion copyWith({
    Value<String>? businessId,
    Value<String>? profileId,
    Value<int>? version,
    Value<String>? productId,
    Value<String>? snapshotJson,
    Value<int>? rowid,
  }) {
    return UniversalPricingUnitSystemsCompanion(
      businessId: businessId ?? this.businessId,
      profileId: profileId ?? this.profileId,
      version: version ?? this.version,
      productId: productId ?? this.productId,
      snapshotJson: snapshotJson ?? this.snapshotJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (snapshotJson.present) {
      map['snapshot_json'] = Variable<String>(snapshotJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UniversalPricingUnitSystemsCompanion(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('version: $version, ')
          ..write('productId: $productId, ')
          ..write('snapshotJson: $snapshotJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class UniversalPricingDimensionRules extends Table
    with
        TableInfo<
          UniversalPricingDimensionRules,
          UniversalPricingDimensionRule
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  UniversalPricingDimensionRules(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _fieldIdMeta = const VerificationMeta(
    'fieldId',
  );
  late final GeneratedColumn<String> fieldId = GeneratedColumn<String>(
    'field_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _snapshotJsonMeta = const VerificationMeta(
    'snapshotJson',
  );
  late final GeneratedColumn<String> snapshotJson = GeneratedColumn<String>(
    'snapshot_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    businessId,
    profileId,
    version,
    productId,
    fieldId,
    snapshotJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'universal_pricing_dimension_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<UniversalPricingDimensionRule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('field_id')) {
      context.handle(
        _fieldIdMeta,
        fieldId.isAcceptableOrUnknown(data['field_id']!, _fieldIdMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldIdMeta);
    }
    if (data.containsKey('snapshot_json')) {
      context.handle(
        _snapshotJsonMeta,
        snapshotJson.isAcceptableOrUnknown(
          data['snapshot_json']!,
          _snapshotJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_snapshotJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    businessId,
    profileId,
    version,
    productId,
    fieldId,
  };
  @override
  UniversalPricingDimensionRule map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UniversalPricingDimensionRule(
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      fieldId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_id'],
      )!,
      snapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_json'],
      )!,
    );
  }

  @override
  UniversalPricingDimensionRules createAlias(String alias) {
    return UniversalPricingDimensionRules(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(business_id, profile_id, version, product_id, field_id)',
    'FOREIGN KEY(business_id, profile_id, version, product_id, field_id)REFERENCES universal_pricing_inputs(business_id, profile_id, version, product_id, id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class UniversalPricingDimensionRule extends DataClass
    implements Insertable<UniversalPricingDimensionRule> {
  final String businessId;
  final String profileId;
  final int version;
  final String productId;
  final String fieldId;
  final String snapshotJson;
  const UniversalPricingDimensionRule({
    required this.businessId,
    required this.profileId,
    required this.version,
    required this.productId,
    required this.fieldId,
    required this.snapshotJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['business_id'] = Variable<String>(businessId);
    map['profile_id'] = Variable<String>(profileId);
    map['version'] = Variable<int>(version);
    map['product_id'] = Variable<String>(productId);
    map['field_id'] = Variable<String>(fieldId);
    map['snapshot_json'] = Variable<String>(snapshotJson);
    return map;
  }

  UniversalPricingDimensionRulesCompanion toCompanion(bool nullToAbsent) {
    return UniversalPricingDimensionRulesCompanion(
      businessId: Value(businessId),
      profileId: Value(profileId),
      version: Value(version),
      productId: Value(productId),
      fieldId: Value(fieldId),
      snapshotJson: Value(snapshotJson),
    );
  }

  factory UniversalPricingDimensionRule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UniversalPricingDimensionRule(
      businessId: serializer.fromJson<String>(json['business_id']),
      profileId: serializer.fromJson<String>(json['profile_id']),
      version: serializer.fromJson<int>(json['version']),
      productId: serializer.fromJson<String>(json['product_id']),
      fieldId: serializer.fromJson<String>(json['field_id']),
      snapshotJson: serializer.fromJson<String>(json['snapshot_json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'business_id': serializer.toJson<String>(businessId),
      'profile_id': serializer.toJson<String>(profileId),
      'version': serializer.toJson<int>(version),
      'product_id': serializer.toJson<String>(productId),
      'field_id': serializer.toJson<String>(fieldId),
      'snapshot_json': serializer.toJson<String>(snapshotJson),
    };
  }

  UniversalPricingDimensionRule copyWith({
    String? businessId,
    String? profileId,
    int? version,
    String? productId,
    String? fieldId,
    String? snapshotJson,
  }) => UniversalPricingDimensionRule(
    businessId: businessId ?? this.businessId,
    profileId: profileId ?? this.profileId,
    version: version ?? this.version,
    productId: productId ?? this.productId,
    fieldId: fieldId ?? this.fieldId,
    snapshotJson: snapshotJson ?? this.snapshotJson,
  );
  UniversalPricingDimensionRule copyWithCompanion(
    UniversalPricingDimensionRulesCompanion data,
  ) {
    return UniversalPricingDimensionRule(
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      version: data.version.present ? data.version.value : this.version,
      productId: data.productId.present ? data.productId.value : this.productId,
      fieldId: data.fieldId.present ? data.fieldId.value : this.fieldId,
      snapshotJson: data.snapshotJson.present
          ? data.snapshotJson.value
          : this.snapshotJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UniversalPricingDimensionRule(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('version: $version, ')
          ..write('productId: $productId, ')
          ..write('fieldId: $fieldId, ')
          ..write('snapshotJson: $snapshotJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    businessId,
    profileId,
    version,
    productId,
    fieldId,
    snapshotJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UniversalPricingDimensionRule &&
          other.businessId == this.businessId &&
          other.profileId == this.profileId &&
          other.version == this.version &&
          other.productId == this.productId &&
          other.fieldId == this.fieldId &&
          other.snapshotJson == this.snapshotJson);
}

class UniversalPricingDimensionRulesCompanion
    extends UpdateCompanion<UniversalPricingDimensionRule> {
  final Value<String> businessId;
  final Value<String> profileId;
  final Value<int> version;
  final Value<String> productId;
  final Value<String> fieldId;
  final Value<String> snapshotJson;
  final Value<int> rowid;
  const UniversalPricingDimensionRulesCompanion({
    this.businessId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.version = const Value.absent(),
    this.productId = const Value.absent(),
    this.fieldId = const Value.absent(),
    this.snapshotJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UniversalPricingDimensionRulesCompanion.insert({
    required String businessId,
    required String profileId,
    required int version,
    required String productId,
    required String fieldId,
    required String snapshotJson,
    this.rowid = const Value.absent(),
  }) : businessId = Value(businessId),
       profileId = Value(profileId),
       version = Value(version),
       productId = Value(productId),
       fieldId = Value(fieldId),
       snapshotJson = Value(snapshotJson);
  static Insertable<UniversalPricingDimensionRule> custom({
    Expression<String>? businessId,
    Expression<String>? profileId,
    Expression<int>? version,
    Expression<String>? productId,
    Expression<String>? fieldId,
    Expression<String>? snapshotJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (businessId != null) 'business_id': businessId,
      if (profileId != null) 'profile_id': profileId,
      if (version != null) 'version': version,
      if (productId != null) 'product_id': productId,
      if (fieldId != null) 'field_id': fieldId,
      if (snapshotJson != null) 'snapshot_json': snapshotJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UniversalPricingDimensionRulesCompanion copyWith({
    Value<String>? businessId,
    Value<String>? profileId,
    Value<int>? version,
    Value<String>? productId,
    Value<String>? fieldId,
    Value<String>? snapshotJson,
    Value<int>? rowid,
  }) {
    return UniversalPricingDimensionRulesCompanion(
      businessId: businessId ?? this.businessId,
      profileId: profileId ?? this.profileId,
      version: version ?? this.version,
      productId: productId ?? this.productId,
      fieldId: fieldId ?? this.fieldId,
      snapshotJson: snapshotJson ?? this.snapshotJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (fieldId.present) {
      map['field_id'] = Variable<String>(fieldId.value);
    }
    if (snapshotJson.present) {
      map['snapshot_json'] = Variable<String>(snapshotJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UniversalPricingDimensionRulesCompanion(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('version: $version, ')
          ..write('productId: $productId, ')
          ..write('fieldId: $fieldId, ')
          ..write('snapshotJson: $snapshotJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class UniversalPricingAddons extends Table
    with TableInfo<UniversalPricingAddons, UniversalPricingAddon> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  UniversalPricingAddons(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _snapshotJsonMeta = const VerificationMeta(
    'snapshotJson',
  );
  late final GeneratedColumn<String> snapshotJson = GeneratedColumn<String>(
    'snapshot_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    businessId,
    profileId,
    version,
    productId,
    id,
    snapshotJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'universal_pricing_addons';
  @override
  VerificationContext validateIntegrity(
    Insertable<UniversalPricingAddon> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('snapshot_json')) {
      context.handle(
        _snapshotJsonMeta,
        snapshotJson.isAcceptableOrUnknown(
          data['snapshot_json']!,
          _snapshotJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_snapshotJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    businessId,
    profileId,
    version,
    productId,
    id,
  };
  @override
  UniversalPricingAddon map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UniversalPricingAddon(
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      snapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_json'],
      )!,
    );
  }

  @override
  UniversalPricingAddons createAlias(String alias) {
    return UniversalPricingAddons(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(business_id, profile_id, version, product_id, id)',
    'FOREIGN KEY(business_id, profile_id, version, product_id)REFERENCES universal_pricing_products(business_id, profile_id, version, id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class UniversalPricingAddon extends DataClass
    implements Insertable<UniversalPricingAddon> {
  final String businessId;
  final String profileId;
  final int version;
  final String productId;
  final String id;
  final String snapshotJson;
  const UniversalPricingAddon({
    required this.businessId,
    required this.profileId,
    required this.version,
    required this.productId,
    required this.id,
    required this.snapshotJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['business_id'] = Variable<String>(businessId);
    map['profile_id'] = Variable<String>(profileId);
    map['version'] = Variable<int>(version);
    map['product_id'] = Variable<String>(productId);
    map['id'] = Variable<String>(id);
    map['snapshot_json'] = Variable<String>(snapshotJson);
    return map;
  }

  UniversalPricingAddonsCompanion toCompanion(bool nullToAbsent) {
    return UniversalPricingAddonsCompanion(
      businessId: Value(businessId),
      profileId: Value(profileId),
      version: Value(version),
      productId: Value(productId),
      id: Value(id),
      snapshotJson: Value(snapshotJson),
    );
  }

  factory UniversalPricingAddon.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UniversalPricingAddon(
      businessId: serializer.fromJson<String>(json['business_id']),
      profileId: serializer.fromJson<String>(json['profile_id']),
      version: serializer.fromJson<int>(json['version']),
      productId: serializer.fromJson<String>(json['product_id']),
      id: serializer.fromJson<String>(json['id']),
      snapshotJson: serializer.fromJson<String>(json['snapshot_json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'business_id': serializer.toJson<String>(businessId),
      'profile_id': serializer.toJson<String>(profileId),
      'version': serializer.toJson<int>(version),
      'product_id': serializer.toJson<String>(productId),
      'id': serializer.toJson<String>(id),
      'snapshot_json': serializer.toJson<String>(snapshotJson),
    };
  }

  UniversalPricingAddon copyWith({
    String? businessId,
    String? profileId,
    int? version,
    String? productId,
    String? id,
    String? snapshotJson,
  }) => UniversalPricingAddon(
    businessId: businessId ?? this.businessId,
    profileId: profileId ?? this.profileId,
    version: version ?? this.version,
    productId: productId ?? this.productId,
    id: id ?? this.id,
    snapshotJson: snapshotJson ?? this.snapshotJson,
  );
  UniversalPricingAddon copyWithCompanion(
    UniversalPricingAddonsCompanion data,
  ) {
    return UniversalPricingAddon(
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      version: data.version.present ? data.version.value : this.version,
      productId: data.productId.present ? data.productId.value : this.productId,
      id: data.id.present ? data.id.value : this.id,
      snapshotJson: data.snapshotJson.present
          ? data.snapshotJson.value
          : this.snapshotJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UniversalPricingAddon(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('version: $version, ')
          ..write('productId: $productId, ')
          ..write('id: $id, ')
          ..write('snapshotJson: $snapshotJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(businessId, profileId, version, productId, id, snapshotJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UniversalPricingAddon &&
          other.businessId == this.businessId &&
          other.profileId == this.profileId &&
          other.version == this.version &&
          other.productId == this.productId &&
          other.id == this.id &&
          other.snapshotJson == this.snapshotJson);
}

class UniversalPricingAddonsCompanion
    extends UpdateCompanion<UniversalPricingAddon> {
  final Value<String> businessId;
  final Value<String> profileId;
  final Value<int> version;
  final Value<String> productId;
  final Value<String> id;
  final Value<String> snapshotJson;
  final Value<int> rowid;
  const UniversalPricingAddonsCompanion({
    this.businessId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.version = const Value.absent(),
    this.productId = const Value.absent(),
    this.id = const Value.absent(),
    this.snapshotJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UniversalPricingAddonsCompanion.insert({
    required String businessId,
    required String profileId,
    required int version,
    required String productId,
    required String id,
    required String snapshotJson,
    this.rowid = const Value.absent(),
  }) : businessId = Value(businessId),
       profileId = Value(profileId),
       version = Value(version),
       productId = Value(productId),
       id = Value(id),
       snapshotJson = Value(snapshotJson);
  static Insertable<UniversalPricingAddon> custom({
    Expression<String>? businessId,
    Expression<String>? profileId,
    Expression<int>? version,
    Expression<String>? productId,
    Expression<String>? id,
    Expression<String>? snapshotJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (businessId != null) 'business_id': businessId,
      if (profileId != null) 'profile_id': profileId,
      if (version != null) 'version': version,
      if (productId != null) 'product_id': productId,
      if (id != null) 'id': id,
      if (snapshotJson != null) 'snapshot_json': snapshotJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UniversalPricingAddonsCompanion copyWith({
    Value<String>? businessId,
    Value<String>? profileId,
    Value<int>? version,
    Value<String>? productId,
    Value<String>? id,
    Value<String>? snapshotJson,
    Value<int>? rowid,
  }) {
    return UniversalPricingAddonsCompanion(
      businessId: businessId ?? this.businessId,
      profileId: profileId ?? this.profileId,
      version: version ?? this.version,
      productId: productId ?? this.productId,
      id: id ?? this.id,
      snapshotJson: snapshotJson ?? this.snapshotJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (snapshotJson.present) {
      map['snapshot_json'] = Variable<String>(snapshotJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UniversalPricingAddonsCompanion(')
          ..write('businessId: $businessId, ')
          ..write('profileId: $profileId, ')
          ..write('version: $version, ')
          ..write('productId: $productId, ')
          ..write('id: $id, ')
          ..write('snapshotJson: $snapshotJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class UniversalPricingAuditEvents extends Table
    with TableInfo<UniversalPricingAuditEvents, UniversalPricingAuditEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  UniversalPricingAuditEvents(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY AUTOINCREMENT',
  );
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _actorUidMeta = const VerificationMeta(
    'actorUid',
  );
  late final GeneratedColumn<String> actorUid = GeneratedColumn<String>(
    'actor_uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _beforeSnapshotMeta = const VerificationMeta(
    'beforeSnapshot',
  );
  late final GeneratedColumn<String> beforeSnapshot = GeneratedColumn<String>(
    'before_snapshot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _afterSnapshotMeta = const VerificationMeta(
    'afterSnapshot',
  );
  late final GeneratedColumn<String> afterSnapshot = GeneratedColumn<String>(
    'after_snapshot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    businessId,
    actorUid,
    action,
    profileId,
    beforeSnapshot,
    afterSnapshot,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'universal_pricing_audit_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<UniversalPricingAuditEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('actor_uid')) {
      context.handle(
        _actorUidMeta,
        actorUid.isAcceptableOrUnknown(data['actor_uid']!, _actorUidMeta),
      );
    } else if (isInserting) {
      context.missing(_actorUidMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('before_snapshot')) {
      context.handle(
        _beforeSnapshotMeta,
        beforeSnapshot.isAcceptableOrUnknown(
          data['before_snapshot']!,
          _beforeSnapshotMeta,
        ),
      );
    }
    if (data.containsKey('after_snapshot')) {
      context.handle(
        _afterSnapshotMeta,
        afterSnapshot.isAcceptableOrUnknown(
          data['after_snapshot']!,
          _afterSnapshotMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_afterSnapshotMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UniversalPricingAuditEvent map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UniversalPricingAuditEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      actorUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_uid'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      beforeSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}before_snapshot'],
      ),
      afterSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}after_snapshot'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  UniversalPricingAuditEvents createAlias(String alias) {
    return UniversalPricingAuditEvents(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY(business_id, profile_id)REFERENCES universal_pricing_profiles(business_id, id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class UniversalPricingAuditEvent extends DataClass
    implements Insertable<UniversalPricingAuditEvent> {
  final int id;
  final String businessId;
  final String actorUid;
  final String action;
  final String profileId;
  final String? beforeSnapshot;
  final String afterSnapshot;
  final int createdAt;
  const UniversalPricingAuditEvent({
    required this.id,
    required this.businessId,
    required this.actorUid,
    required this.action,
    required this.profileId,
    this.beforeSnapshot,
    required this.afterSnapshot,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['business_id'] = Variable<String>(businessId);
    map['actor_uid'] = Variable<String>(actorUid);
    map['action'] = Variable<String>(action);
    map['profile_id'] = Variable<String>(profileId);
    if (!nullToAbsent || beforeSnapshot != null) {
      map['before_snapshot'] = Variable<String>(beforeSnapshot);
    }
    map['after_snapshot'] = Variable<String>(afterSnapshot);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  UniversalPricingAuditEventsCompanion toCompanion(bool nullToAbsent) {
    return UniversalPricingAuditEventsCompanion(
      id: Value(id),
      businessId: Value(businessId),
      actorUid: Value(actorUid),
      action: Value(action),
      profileId: Value(profileId),
      beforeSnapshot: beforeSnapshot == null && nullToAbsent
          ? const Value.absent()
          : Value(beforeSnapshot),
      afterSnapshot: Value(afterSnapshot),
      createdAt: Value(createdAt),
    );
  }

  factory UniversalPricingAuditEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UniversalPricingAuditEvent(
      id: serializer.fromJson<int>(json['id']),
      businessId: serializer.fromJson<String>(json['business_id']),
      actorUid: serializer.fromJson<String>(json['actor_uid']),
      action: serializer.fromJson<String>(json['action']),
      profileId: serializer.fromJson<String>(json['profile_id']),
      beforeSnapshot: serializer.fromJson<String?>(json['before_snapshot']),
      afterSnapshot: serializer.fromJson<String>(json['after_snapshot']),
      createdAt: serializer.fromJson<int>(json['created_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'business_id': serializer.toJson<String>(businessId),
      'actor_uid': serializer.toJson<String>(actorUid),
      'action': serializer.toJson<String>(action),
      'profile_id': serializer.toJson<String>(profileId),
      'before_snapshot': serializer.toJson<String?>(beforeSnapshot),
      'after_snapshot': serializer.toJson<String>(afterSnapshot),
      'created_at': serializer.toJson<int>(createdAt),
    };
  }

  UniversalPricingAuditEvent copyWith({
    int? id,
    String? businessId,
    String? actorUid,
    String? action,
    String? profileId,
    Value<String?> beforeSnapshot = const Value.absent(),
    String? afterSnapshot,
    int? createdAt,
  }) => UniversalPricingAuditEvent(
    id: id ?? this.id,
    businessId: businessId ?? this.businessId,
    actorUid: actorUid ?? this.actorUid,
    action: action ?? this.action,
    profileId: profileId ?? this.profileId,
    beforeSnapshot: beforeSnapshot.present
        ? beforeSnapshot.value
        : this.beforeSnapshot,
    afterSnapshot: afterSnapshot ?? this.afterSnapshot,
    createdAt: createdAt ?? this.createdAt,
  );
  UniversalPricingAuditEvent copyWithCompanion(
    UniversalPricingAuditEventsCompanion data,
  ) {
    return UniversalPricingAuditEvent(
      id: data.id.present ? data.id.value : this.id,
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      actorUid: data.actorUid.present ? data.actorUid.value : this.actorUid,
      action: data.action.present ? data.action.value : this.action,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      beforeSnapshot: data.beforeSnapshot.present
          ? data.beforeSnapshot.value
          : this.beforeSnapshot,
      afterSnapshot: data.afterSnapshot.present
          ? data.afterSnapshot.value
          : this.afterSnapshot,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UniversalPricingAuditEvent(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('actorUid: $actorUid, ')
          ..write('action: $action, ')
          ..write('profileId: $profileId, ')
          ..write('beforeSnapshot: $beforeSnapshot, ')
          ..write('afterSnapshot: $afterSnapshot, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    businessId,
    actorUid,
    action,
    profileId,
    beforeSnapshot,
    afterSnapshot,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UniversalPricingAuditEvent &&
          other.id == this.id &&
          other.businessId == this.businessId &&
          other.actorUid == this.actorUid &&
          other.action == this.action &&
          other.profileId == this.profileId &&
          other.beforeSnapshot == this.beforeSnapshot &&
          other.afterSnapshot == this.afterSnapshot &&
          other.createdAt == this.createdAt);
}

class UniversalPricingAuditEventsCompanion
    extends UpdateCompanion<UniversalPricingAuditEvent> {
  final Value<int> id;
  final Value<String> businessId;
  final Value<String> actorUid;
  final Value<String> action;
  final Value<String> profileId;
  final Value<String?> beforeSnapshot;
  final Value<String> afterSnapshot;
  final Value<int> createdAt;
  const UniversalPricingAuditEventsCompanion({
    this.id = const Value.absent(),
    this.businessId = const Value.absent(),
    this.actorUid = const Value.absent(),
    this.action = const Value.absent(),
    this.profileId = const Value.absent(),
    this.beforeSnapshot = const Value.absent(),
    this.afterSnapshot = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  UniversalPricingAuditEventsCompanion.insert({
    this.id = const Value.absent(),
    required String businessId,
    required String actorUid,
    required String action,
    required String profileId,
    this.beforeSnapshot = const Value.absent(),
    required String afterSnapshot,
    required int createdAt,
  }) : businessId = Value(businessId),
       actorUid = Value(actorUid),
       action = Value(action),
       profileId = Value(profileId),
       afterSnapshot = Value(afterSnapshot),
       createdAt = Value(createdAt);
  static Insertable<UniversalPricingAuditEvent> custom({
    Expression<int>? id,
    Expression<String>? businessId,
    Expression<String>? actorUid,
    Expression<String>? action,
    Expression<String>? profileId,
    Expression<String>? beforeSnapshot,
    Expression<String>? afterSnapshot,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (businessId != null) 'business_id': businessId,
      if (actorUid != null) 'actor_uid': actorUid,
      if (action != null) 'action': action,
      if (profileId != null) 'profile_id': profileId,
      if (beforeSnapshot != null) 'before_snapshot': beforeSnapshot,
      if (afterSnapshot != null) 'after_snapshot': afterSnapshot,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  UniversalPricingAuditEventsCompanion copyWith({
    Value<int>? id,
    Value<String>? businessId,
    Value<String>? actorUid,
    Value<String>? action,
    Value<String>? profileId,
    Value<String?>? beforeSnapshot,
    Value<String>? afterSnapshot,
    Value<int>? createdAt,
  }) {
    return UniversalPricingAuditEventsCompanion(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      actorUid: actorUid ?? this.actorUid,
      action: action ?? this.action,
      profileId: profileId ?? this.profileId,
      beforeSnapshot: beforeSnapshot ?? this.beforeSnapshot,
      afterSnapshot: afterSnapshot ?? this.afterSnapshot,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (actorUid.present) {
      map['actor_uid'] = Variable<String>(actorUid.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (beforeSnapshot.present) {
      map['before_snapshot'] = Variable<String>(beforeSnapshot.value);
    }
    if (afterSnapshot.present) {
      map['after_snapshot'] = Variable<String>(afterSnapshot.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UniversalPricingAuditEventsCompanion(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('actorUid: $actorUid, ')
          ..write('action: $action, ')
          ..write('profileId: $profileId, ')
          ..write('beforeSnapshot: $beforeSnapshot, ')
          ..write('afterSnapshot: $afterSnapshot, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class PricingDeviceWorkspace extends Table
    with TableInfo<PricingDeviceWorkspace, PricingDeviceWorkspaceData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  PricingDeviceWorkspace(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _singletonMeta = const VerificationMeta(
    'singleton',
  );
  late final GeneratedColumn<int> singleton = GeneratedColumn<int>(
    'singleton',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY CHECK (singleton = 1)',
  );
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL UNIQUE',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [singleton, businessId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pricing_device_workspace';
  @override
  VerificationContext validateIntegrity(
    Insertable<PricingDeviceWorkspaceData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('singleton')) {
      context.handle(
        _singletonMeta,
        singleton.isAcceptableOrUnknown(data['singleton']!, _singletonMeta),
      );
    }
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {singleton};
  @override
  PricingDeviceWorkspaceData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PricingDeviceWorkspaceData(
      singleton: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}singleton'],
      )!,
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  PricingDeviceWorkspace createAlias(String alias) {
    return PricingDeviceWorkspace(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class PricingDeviceWorkspaceData extends DataClass
    implements Insertable<PricingDeviceWorkspaceData> {
  final int singleton;
  final String businessId;
  final int createdAt;
  const PricingDeviceWorkspaceData({
    required this.singleton,
    required this.businessId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['singleton'] = Variable<int>(singleton);
    map['business_id'] = Variable<String>(businessId);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  PricingDeviceWorkspaceCompanion toCompanion(bool nullToAbsent) {
    return PricingDeviceWorkspaceCompanion(
      singleton: Value(singleton),
      businessId: Value(businessId),
      createdAt: Value(createdAt),
    );
  }

  factory PricingDeviceWorkspaceData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PricingDeviceWorkspaceData(
      singleton: serializer.fromJson<int>(json['singleton']),
      businessId: serializer.fromJson<String>(json['business_id']),
      createdAt: serializer.fromJson<int>(json['created_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'singleton': serializer.toJson<int>(singleton),
      'business_id': serializer.toJson<String>(businessId),
      'created_at': serializer.toJson<int>(createdAt),
    };
  }

  PricingDeviceWorkspaceData copyWith({
    int? singleton,
    String? businessId,
    int? createdAt,
  }) => PricingDeviceWorkspaceData(
    singleton: singleton ?? this.singleton,
    businessId: businessId ?? this.businessId,
    createdAt: createdAt ?? this.createdAt,
  );
  PricingDeviceWorkspaceData copyWithCompanion(
    PricingDeviceWorkspaceCompanion data,
  ) {
    return PricingDeviceWorkspaceData(
      singleton: data.singleton.present ? data.singleton.value : this.singleton,
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PricingDeviceWorkspaceData(')
          ..write('singleton: $singleton, ')
          ..write('businessId: $businessId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(singleton, businessId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PricingDeviceWorkspaceData &&
          other.singleton == this.singleton &&
          other.businessId == this.businessId &&
          other.createdAt == this.createdAt);
}

class PricingDeviceWorkspaceCompanion
    extends UpdateCompanion<PricingDeviceWorkspaceData> {
  final Value<int> singleton;
  final Value<String> businessId;
  final Value<int> createdAt;
  const PricingDeviceWorkspaceCompanion({
    this.singleton = const Value.absent(),
    this.businessId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PricingDeviceWorkspaceCompanion.insert({
    this.singleton = const Value.absent(),
    required String businessId,
    required int createdAt,
  }) : businessId = Value(businessId),
       createdAt = Value(createdAt);
  static Insertable<PricingDeviceWorkspaceData> custom({
    Expression<int>? singleton,
    Expression<String>? businessId,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (singleton != null) 'singleton': singleton,
      if (businessId != null) 'business_id': businessId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PricingDeviceWorkspaceCompanion copyWith({
    Value<int>? singleton,
    Value<String>? businessId,
    Value<int>? createdAt,
  }) {
    return PricingDeviceWorkspaceCompanion(
      singleton: singleton ?? this.singleton,
      businessId: businessId ?? this.businessId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (singleton.present) {
      map['singleton'] = Variable<int>(singleton.value);
    }
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PricingDeviceWorkspaceCompanion(')
          ..write('singleton: $singleton, ')
          ..write('businessId: $businessId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class PricingWorkspaceValues extends Table
    with TableInfo<PricingWorkspaceValues, PricingWorkspaceValue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  PricingWorkspaceValues(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _snapshotJsonMeta = const VerificationMeta(
    'snapshotJson',
  );
  late final GeneratedColumn<String> snapshotJson = GeneratedColumn<String>(
    'snapshot_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [businessId, id, snapshotJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pricing_workspace_values';
  @override
  VerificationContext validateIntegrity(
    Insertable<PricingWorkspaceValue> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('snapshot_json')) {
      context.handle(
        _snapshotJsonMeta,
        snapshotJson.isAcceptableOrUnknown(
          data['snapshot_json']!,
          _snapshotJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_snapshotJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {businessId, id};
  @override
  PricingWorkspaceValue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PricingWorkspaceValue(
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      snapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_json'],
      )!,
    );
  }

  @override
  PricingWorkspaceValues createAlias(String alias) {
    return PricingWorkspaceValues(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(business_id, id)',
    'FOREIGN KEY(business_id)REFERENCES pricing_device_workspace(business_id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class PricingWorkspaceValue extends DataClass
    implements Insertable<PricingWorkspaceValue> {
  final String businessId;
  final String id;
  final String snapshotJson;
  const PricingWorkspaceValue({
    required this.businessId,
    required this.id,
    required this.snapshotJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['business_id'] = Variable<String>(businessId);
    map['id'] = Variable<String>(id);
    map['snapshot_json'] = Variable<String>(snapshotJson);
    return map;
  }

  PricingWorkspaceValuesCompanion toCompanion(bool nullToAbsent) {
    return PricingWorkspaceValuesCompanion(
      businessId: Value(businessId),
      id: Value(id),
      snapshotJson: Value(snapshotJson),
    );
  }

  factory PricingWorkspaceValue.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PricingWorkspaceValue(
      businessId: serializer.fromJson<String>(json['business_id']),
      id: serializer.fromJson<String>(json['id']),
      snapshotJson: serializer.fromJson<String>(json['snapshot_json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'business_id': serializer.toJson<String>(businessId),
      'id': serializer.toJson<String>(id),
      'snapshot_json': serializer.toJson<String>(snapshotJson),
    };
  }

  PricingWorkspaceValue copyWith({
    String? businessId,
    String? id,
    String? snapshotJson,
  }) => PricingWorkspaceValue(
    businessId: businessId ?? this.businessId,
    id: id ?? this.id,
    snapshotJson: snapshotJson ?? this.snapshotJson,
  );
  PricingWorkspaceValue copyWithCompanion(
    PricingWorkspaceValuesCompanion data,
  ) {
    return PricingWorkspaceValue(
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      id: data.id.present ? data.id.value : this.id,
      snapshotJson: data.snapshotJson.present
          ? data.snapshotJson.value
          : this.snapshotJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PricingWorkspaceValue(')
          ..write('businessId: $businessId, ')
          ..write('id: $id, ')
          ..write('snapshotJson: $snapshotJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(businessId, id, snapshotJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PricingWorkspaceValue &&
          other.businessId == this.businessId &&
          other.id == this.id &&
          other.snapshotJson == this.snapshotJson);
}

class PricingWorkspaceValuesCompanion
    extends UpdateCompanion<PricingWorkspaceValue> {
  final Value<String> businessId;
  final Value<String> id;
  final Value<String> snapshotJson;
  final Value<int> rowid;
  const PricingWorkspaceValuesCompanion({
    this.businessId = const Value.absent(),
    this.id = const Value.absent(),
    this.snapshotJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PricingWorkspaceValuesCompanion.insert({
    required String businessId,
    required String id,
    required String snapshotJson,
    this.rowid = const Value.absent(),
  }) : businessId = Value(businessId),
       id = Value(id),
       snapshotJson = Value(snapshotJson);
  static Insertable<PricingWorkspaceValue> custom({
    Expression<String>? businessId,
    Expression<String>? id,
    Expression<String>? snapshotJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (businessId != null) 'business_id': businessId,
      if (id != null) 'id': id,
      if (snapshotJson != null) 'snapshot_json': snapshotJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PricingWorkspaceValuesCompanion copyWith({
    Value<String>? businessId,
    Value<String>? id,
    Value<String>? snapshotJson,
    Value<int>? rowid,
  }) {
    return PricingWorkspaceValuesCompanion(
      businessId: businessId ?? this.businessId,
      id: id ?? this.id,
      snapshotJson: snapshotJson ?? this.snapshotJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (snapshotJson.present) {
      map['snapshot_json'] = Variable<String>(snapshotJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PricingWorkspaceValuesCompanion(')
          ..write('businessId: $businessId, ')
          ..write('id: $id, ')
          ..write('snapshotJson: $snapshotJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class PricingLocalTaxApprovals extends Table
    with TableInfo<PricingLocalTaxApprovals, PricingLocalTaxApproval> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  PricingLocalTaxApprovals(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _policyJsonMeta = const VerificationMeta(
    'policyJson',
  );
  late final GeneratedColumn<String> policyJson = GeneratedColumn<String>(
    'policy_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _approvedAtMeta = const VerificationMeta(
    'approvedAt',
  );
  late final GeneratedColumn<int> approvedAt = GeneratedColumn<int>(
    'approved_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [businessId, policyJson, approvedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pricing_local_tax_approvals';
  @override
  VerificationContext validateIntegrity(
    Insertable<PricingLocalTaxApproval> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('policy_json')) {
      context.handle(
        _policyJsonMeta,
        policyJson.isAcceptableOrUnknown(data['policy_json']!, _policyJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_policyJsonMeta);
    }
    if (data.containsKey('approved_at')) {
      context.handle(
        _approvedAtMeta,
        approvedAt.isAcceptableOrUnknown(data['approved_at']!, _approvedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_approvedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {businessId, policyJson};
  @override
  PricingLocalTaxApproval map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PricingLocalTaxApproval(
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      policyJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}policy_json'],
      )!,
      approvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}approved_at'],
      )!,
    );
  }

  @override
  PricingLocalTaxApprovals createAlias(String alias) {
    return PricingLocalTaxApprovals(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(business_id, policy_json)',
    'FOREIGN KEY(business_id)REFERENCES pricing_device_workspace(business_id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class PricingLocalTaxApproval extends DataClass
    implements Insertable<PricingLocalTaxApproval> {
  final String businessId;
  final String policyJson;
  final int approvedAt;
  const PricingLocalTaxApproval({
    required this.businessId,
    required this.policyJson,
    required this.approvedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['business_id'] = Variable<String>(businessId);
    map['policy_json'] = Variable<String>(policyJson);
    map['approved_at'] = Variable<int>(approvedAt);
    return map;
  }

  PricingLocalTaxApprovalsCompanion toCompanion(bool nullToAbsent) {
    return PricingLocalTaxApprovalsCompanion(
      businessId: Value(businessId),
      policyJson: Value(policyJson),
      approvedAt: Value(approvedAt),
    );
  }

  factory PricingLocalTaxApproval.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PricingLocalTaxApproval(
      businessId: serializer.fromJson<String>(json['business_id']),
      policyJson: serializer.fromJson<String>(json['policy_json']),
      approvedAt: serializer.fromJson<int>(json['approved_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'business_id': serializer.toJson<String>(businessId),
      'policy_json': serializer.toJson<String>(policyJson),
      'approved_at': serializer.toJson<int>(approvedAt),
    };
  }

  PricingLocalTaxApproval copyWith({
    String? businessId,
    String? policyJson,
    int? approvedAt,
  }) => PricingLocalTaxApproval(
    businessId: businessId ?? this.businessId,
    policyJson: policyJson ?? this.policyJson,
    approvedAt: approvedAt ?? this.approvedAt,
  );
  PricingLocalTaxApproval copyWithCompanion(
    PricingLocalTaxApprovalsCompanion data,
  ) {
    return PricingLocalTaxApproval(
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      policyJson: data.policyJson.present
          ? data.policyJson.value
          : this.policyJson,
      approvedAt: data.approvedAt.present
          ? data.approvedAt.value
          : this.approvedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PricingLocalTaxApproval(')
          ..write('businessId: $businessId, ')
          ..write('policyJson: $policyJson, ')
          ..write('approvedAt: $approvedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(businessId, policyJson, approvedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PricingLocalTaxApproval &&
          other.businessId == this.businessId &&
          other.policyJson == this.policyJson &&
          other.approvedAt == this.approvedAt);
}

class PricingLocalTaxApprovalsCompanion
    extends UpdateCompanion<PricingLocalTaxApproval> {
  final Value<String> businessId;
  final Value<String> policyJson;
  final Value<int> approvedAt;
  final Value<int> rowid;
  const PricingLocalTaxApprovalsCompanion({
    this.businessId = const Value.absent(),
    this.policyJson = const Value.absent(),
    this.approvedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PricingLocalTaxApprovalsCompanion.insert({
    required String businessId,
    required String policyJson,
    required int approvedAt,
    this.rowid = const Value.absent(),
  }) : businessId = Value(businessId),
       policyJson = Value(policyJson),
       approvedAt = Value(approvedAt);
  static Insertable<PricingLocalTaxApproval> custom({
    Expression<String>? businessId,
    Expression<String>? policyJson,
    Expression<int>? approvedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (businessId != null) 'business_id': businessId,
      if (policyJson != null) 'policy_json': policyJson,
      if (approvedAt != null) 'approved_at': approvedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PricingLocalTaxApprovalsCompanion copyWith({
    Value<String>? businessId,
    Value<String>? policyJson,
    Value<int>? approvedAt,
    Value<int>? rowid,
  }) {
    return PricingLocalTaxApprovalsCompanion(
      businessId: businessId ?? this.businessId,
      policyJson: policyJson ?? this.policyJson,
      approvedAt: approvedAt ?? this.approvedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (policyJson.present) {
      map['policy_json'] = Variable<String>(policyJson.value);
    }
    if (approvedAt.present) {
      map['approved_at'] = Variable<int>(approvedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PricingLocalTaxApprovalsCompanion(')
          ..write('businessId: $businessId, ')
          ..write('policyJson: $policyJson, ')
          ..write('approvedAt: $approvedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$PricingDatabase extends GeneratedDatabase {
  _$PricingDatabase(QueryExecutor e) : super(e);
  $PricingDatabaseManager get managers => $PricingDatabaseManager(this);
  late final PricingProfiles pricingProfiles = PricingProfiles(this);
  late final PricingDrafts pricingDrafts = PricingDrafts(this);
  late final PricingRateCardVersions pricingRateCardVersions =
      PricingRateCardVersions(this);
  late final Index pricingEffectiveIdx = Index(
    'pricing_effective_idx',
    'CREATE INDEX pricing_effective_idx ON pricing_rate_card_versions (business_id, profile_id, effective_at DESC, version DESC)',
  );
  late final PricingCategories pricingCategories = PricingCategories(this);
  late final PricingVariants pricingVariants = PricingVariants(this);
  late final PricingRuleVersions pricingRuleVersions = PricingRuleVersions(
    this,
  );
  late final Index pricingRuleTargetIdx = Index(
    'pricing_rule_target_idx',
    'CREATE UNIQUE INDEX pricing_rule_target_idx ON pricing_rule_versions (business_id, profile_id, version, category_id, IFNULL(variant_id, \'\'))',
  );
  late final PricingAddons pricingAddons = PricingAddons(this);
  late final PricingRuleAddons pricingRuleAddons = PricingRuleAddons(this);
  late final PricingAuditEvents pricingAuditEvents = PricingAuditEvents(this);
  late final Index pricingAuditBusinessIdx = Index(
    'pricing_audit_business_idx',
    'CREATE INDEX pricing_audit_business_idx ON pricing_audit_events (business_id, profile_id, id DESC)',
  );
  late final UniversalPricingProfiles universalPricingProfiles =
      UniversalPricingProfiles(this);
  late final UniversalPricingDrafts universalPricingDrafts =
      UniversalPricingDrafts(this);
  late final UniversalPricingVersions universalPricingVersions =
      UniversalPricingVersions(this);
  late final Index universalPricingEffectiveIdx = Index(
    'universal_pricing_effective_idx',
    'CREATE INDEX universal_pricing_effective_idx ON universal_pricing_versions (business_id, profile_id, effective_at DESC, version DESC)',
  );
  late final UniversalPricingCategories universalPricingCategories =
      UniversalPricingCategories(this);
  late final UniversalPricingProducts universalPricingProducts =
      UniversalPricingProducts(this);
  late final UniversalPricingInputs universalPricingInputs =
      UniversalPricingInputs(this);
  late final UniversalPricingRates universalPricingRates =
      UniversalPricingRates(this);
  late final Index universalPricingRateLookupIdx = Index(
    'universal_pricing_rate_lookup_idx',
    'CREATE INDEX universal_pricing_rate_lookup_idx ON universal_pricing_rates (business_id, profile_id, version, product_id, rate_key)',
  );
  late final UniversalPricingUnitSystems universalPricingUnitSystems =
      UniversalPricingUnitSystems(this);
  late final UniversalPricingDimensionRules universalPricingDimensionRules =
      UniversalPricingDimensionRules(this);
  late final UniversalPricingAddons universalPricingAddons =
      UniversalPricingAddons(this);
  late final UniversalPricingAuditEvents universalPricingAuditEvents =
      UniversalPricingAuditEvents(this);
  late final Index universalPricingAuditIdx = Index(
    'universal_pricing_audit_idx',
    'CREATE INDEX universal_pricing_audit_idx ON universal_pricing_audit_events (business_id, profile_id, id DESC)',
  );
  late final PricingDeviceWorkspace pricingDeviceWorkspace =
      PricingDeviceWorkspace(this);
  late final PricingWorkspaceValues pricingWorkspaceValues =
      PricingWorkspaceValues(this);
  late final PricingLocalTaxApprovals pricingLocalTaxApprovals =
      PricingLocalTaxApprovals(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    pricingProfiles,
    pricingDrafts,
    pricingRateCardVersions,
    pricingEffectiveIdx,
    pricingCategories,
    pricingVariants,
    pricingRuleVersions,
    pricingRuleTargetIdx,
    pricingAddons,
    pricingRuleAddons,
    pricingAuditEvents,
    pricingAuditBusinessIdx,
    universalPricingProfiles,
    universalPricingDrafts,
    universalPricingVersions,
    universalPricingEffectiveIdx,
    universalPricingCategories,
    universalPricingProducts,
    universalPricingInputs,
    universalPricingRates,
    universalPricingRateLookupIdx,
    universalPricingUnitSystems,
    universalPricingDimensionRules,
    universalPricingAddons,
    universalPricingAuditEvents,
    universalPricingAuditIdx,
    pricingDeviceWorkspace,
    pricingWorkspaceValues,
    pricingLocalTaxApprovals,
  ];
}

typedef $PricingProfilesCreateCompanionBuilder =
    PricingProfilesCompanion Function({
      required String businessId,
      required String id,
      required String name,
      Value<String> status,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $PricingProfilesUpdateCompanionBuilder =
    PricingProfilesCompanion Function({
      Value<String> businessId,
      Value<String> id,
      Value<String> name,
      Value<String> status,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $PricingProfilesFilterComposer
    extends Composer<_$PricingDatabase, PricingProfiles> {
  $PricingProfilesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $PricingProfilesOrderingComposer
    extends Composer<_$PricingDatabase, PricingProfiles> {
  $PricingProfilesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $PricingProfilesAnnotationComposer
    extends Composer<_$PricingDatabase, PricingProfiles> {
  $PricingProfilesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $PricingProfilesTableManager
    extends
        RootTableManager<
          _$PricingDatabase,
          PricingProfiles,
          PricingProfile,
          $PricingProfilesFilterComposer,
          $PricingProfilesOrderingComposer,
          $PricingProfilesAnnotationComposer,
          $PricingProfilesCreateCompanionBuilder,
          $PricingProfilesUpdateCompanionBuilder,
          (
            PricingProfile,
            BaseReferences<_$PricingDatabase, PricingProfiles, PricingProfile>,
          ),
          PricingProfile,
          PrefetchHooks Function()
        > {
  $PricingProfilesTableManager(_$PricingDatabase db, PricingProfiles table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $PricingProfilesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $PricingProfilesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $PricingProfilesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> businessId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PricingProfilesCompanion(
                businessId: businessId,
                id: id,
                name: name,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String businessId,
                required String id,
                required String name,
                Value<String> status = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PricingProfilesCompanion.insert(
                businessId: businessId,
                id: id,
                name: name,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<PricingProfiles, PricingProfile>(table),
                  BaseReferences<
                    _$PricingDatabase,
                    PricingProfiles,
                    PricingProfile
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $PricingProfilesProcessedTableManager =
    ProcessedTableManager<
      _$PricingDatabase,
      PricingProfiles,
      PricingProfile,
      $PricingProfilesFilterComposer,
      $PricingProfilesOrderingComposer,
      $PricingProfilesAnnotationComposer,
      $PricingProfilesCreateCompanionBuilder,
      $PricingProfilesUpdateCompanionBuilder,
      (
        PricingProfile,
        BaseReferences<_$PricingDatabase, PricingProfiles, PricingProfile>,
      ),
      PricingProfile,
      PrefetchHooks Function()
    >;
typedef $PricingDraftsCreateCompanionBuilder = PricingDraftsCompanion Function({
  required String businessId,
  required String profileId,
  required int revision,
  required String snapshotJson,
  Value<int> rowid,
});
typedef $PricingDraftsUpdateCompanionBuilder = PricingDraftsCompanion Function({
  Value<String> businessId,
  Value<String> profileId,
  Value<int> revision,
  Value<String> snapshotJson,
  Value<int> rowid,
});

class $PricingDraftsFilterComposer
    extends Composer<_$PricingDatabase, PricingDrafts> {
  $PricingDraftsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $PricingDraftsOrderingComposer
    extends Composer<_$PricingDatabase, PricingDrafts> {
  $PricingDraftsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $PricingDraftsAnnotationComposer
    extends Composer<_$PricingDatabase, PricingDrafts> {
  $PricingDraftsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => column,
  );
}

class $PricingDraftsTableManager
    extends
        RootTableManager<
          _$PricingDatabase,
          PricingDrafts,
          PricingDraft,
          $PricingDraftsFilterComposer,
          $PricingDraftsOrderingComposer,
          $PricingDraftsAnnotationComposer,
          $PricingDraftsCreateCompanionBuilder,
          $PricingDraftsUpdateCompanionBuilder,
          (
            PricingDraft,
            BaseReferences<_$PricingDatabase, PricingDrafts, PricingDraft>,
          ),
          PricingDraft,
          PrefetchHooks Function()
        > {
  $PricingDraftsTableManager(_$PricingDatabase db, PricingDrafts table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $PricingDraftsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $PricingDraftsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $PricingDraftsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> businessId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> snapshotJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PricingDraftsCompanion(
                businessId: businessId,
                profileId: profileId,
                revision: revision,
                snapshotJson: snapshotJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String businessId,
                required String profileId,
                required int revision,
                required String snapshotJson,
                Value<int> rowid = const Value.absent(),
              }) => PricingDraftsCompanion.insert(
                businessId: businessId,
                profileId: profileId,
                revision: revision,
                snapshotJson: snapshotJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<PricingDrafts, PricingDraft>(table),
                  BaseReferences<
                    _$PricingDatabase,
                    PricingDrafts,
                    PricingDraft
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $PricingDraftsProcessedTableManager =
    ProcessedTableManager<
      _$PricingDatabase,
      PricingDrafts,
      PricingDraft,
      $PricingDraftsFilterComposer,
      $PricingDraftsOrderingComposer,
      $PricingDraftsAnnotationComposer,
      $PricingDraftsCreateCompanionBuilder,
      $PricingDraftsUpdateCompanionBuilder,
      (
        PricingDraft,
        BaseReferences<_$PricingDatabase, PricingDrafts, PricingDraft>,
      ),
      PricingDraft,
      PrefetchHooks Function()
    >;
typedef $PricingRateCardVersionsCreateCompanionBuilder =
    PricingRateCardVersionsCompanion Function({
      required String businessId,
      required String profileId,
      required int version,
      required int effectiveAt,
      Value<int?> expiresAt,
      required int publishedAt,
      required String publishedBy,
      required String snapshotJson,
      Value<int> sealed,
      Value<int> rowid,
    });
typedef $PricingRateCardVersionsUpdateCompanionBuilder =
    PricingRateCardVersionsCompanion Function({
      Value<String> businessId,
      Value<String> profileId,
      Value<int> version,
      Value<int> effectiveAt,
      Value<int?> expiresAt,
      Value<int> publishedAt,
      Value<String> publishedBy,
      Value<String> snapshotJson,
      Value<int> sealed,
      Value<int> rowid,
    });

class $PricingRateCardVersionsFilterComposer
    extends Composer<_$PricingDatabase, PricingRateCardVersions> {
  $PricingRateCardVersionsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get effectiveAt => $composableBuilder(
    column: $table.effectiveAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publishedBy => $composableBuilder(
    column: $table.publishedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sealed => $composableBuilder(
    column: $table.sealed,
    builder: (column) => ColumnFilters(column),
  );
}

class $PricingRateCardVersionsOrderingComposer
    extends Composer<_$PricingDatabase, PricingRateCardVersions> {
  $PricingRateCardVersionsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get effectiveAt => $composableBuilder(
    column: $table.effectiveAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publishedBy => $composableBuilder(
    column: $table.publishedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sealed => $composableBuilder(
    column: $table.sealed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $PricingRateCardVersionsAnnotationComposer
    extends Composer<_$PricingDatabase, PricingRateCardVersions> {
  $PricingRateCardVersionsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get effectiveAt => $composableBuilder(
    column: $table.effectiveAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<int> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get publishedBy => $composableBuilder(
    column: $table.publishedBy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sealed =>
      $composableBuilder(column: $table.sealed, builder: (column) => column);
}

class $PricingRateCardVersionsTableManager
    extends
        RootTableManager<
          _$PricingDatabase,
          PricingRateCardVersions,
          PricingRateCardVersion,
          $PricingRateCardVersionsFilterComposer,
          $PricingRateCardVersionsOrderingComposer,
          $PricingRateCardVersionsAnnotationComposer,
          $PricingRateCardVersionsCreateCompanionBuilder,
          $PricingRateCardVersionsUpdateCompanionBuilder,
          (
            PricingRateCardVersion,
            BaseReferences<
              _$PricingDatabase,
              PricingRateCardVersions,
              PricingRateCardVersion
            >,
          ),
          PricingRateCardVersion,
          PrefetchHooks Function()
        > {
  $PricingRateCardVersionsTableManager(
    _$PricingDatabase db,
    PricingRateCardVersions table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $PricingRateCardVersionsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $PricingRateCardVersionsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $PricingRateCardVersionsAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> businessId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> effectiveAt = const Value.absent(),
                Value<int?> expiresAt = const Value.absent(),
                Value<int> publishedAt = const Value.absent(),
                Value<String> publishedBy = const Value.absent(),
                Value<String> snapshotJson = const Value.absent(),
                Value<int> sealed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PricingRateCardVersionsCompanion(
                businessId: businessId,
                profileId: profileId,
                version: version,
                effectiveAt: effectiveAt,
                expiresAt: expiresAt,
                publishedAt: publishedAt,
                publishedBy: publishedBy,
                snapshotJson: snapshotJson,
                sealed: sealed,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String businessId,
                required String profileId,
                required int version,
                required int effectiveAt,
                Value<int?> expiresAt = const Value.absent(),
                required int publishedAt,
                required String publishedBy,
                required String snapshotJson,
                Value<int> sealed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PricingRateCardVersionsCompanion.insert(
                businessId: businessId,
                profileId: profileId,
                version: version,
                effectiveAt: effectiveAt,
                expiresAt: expiresAt,
                publishedAt: publishedAt,
                publishedBy: publishedBy,
                snapshotJson: snapshotJson,
                sealed: sealed,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<PricingRateCardVersions, PricingRateCardVersion>(
                    table,
                  ),
                  BaseReferences<
                    _$PricingDatabase,
                    PricingRateCardVersions,
                    PricingRateCardVersion
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $PricingRateCardVersionsProcessedTableManager =
    ProcessedTableManager<
      _$PricingDatabase,
      PricingRateCardVersions,
      PricingRateCardVersion,
      $PricingRateCardVersionsFilterComposer,
      $PricingRateCardVersionsOrderingComposer,
      $PricingRateCardVersionsAnnotationComposer,
      $PricingRateCardVersionsCreateCompanionBuilder,
      $PricingRateCardVersionsUpdateCompanionBuilder,
      (
        PricingRateCardVersion,
        BaseReferences<
          _$PricingDatabase,
          PricingRateCardVersions,
          PricingRateCardVersion
        >,
      ),
      PricingRateCardVersion,
      PrefetchHooks Function()
    >;
typedef $PricingCategoriesCreateCompanionBuilder =
    PricingCategoriesCompanion Function({
      required String businessId,
      required String profileId,
      required int version,
      required String id,
      Value<String?> parentId,
      required String name,
      required int sortOrder,
      required String snapshotJson,
      Value<int> rowid,
    });
typedef $PricingCategoriesUpdateCompanionBuilder =
    PricingCategoriesCompanion Function({
      Value<String> businessId,
      Value<String> profileId,
      Value<int> version,
      Value<String> id,
      Value<String?> parentId,
      Value<String> name,
      Value<int> sortOrder,
      Value<String> snapshotJson,
      Value<int> rowid,
    });

class $PricingCategoriesFilterComposer
    extends Composer<_$PricingDatabase, PricingCategories> {
  $PricingCategoriesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $PricingCategoriesOrderingComposer
    extends Composer<_$PricingDatabase, PricingCategories> {
  $PricingCategoriesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $PricingCategoriesAnnotationComposer
    extends Composer<_$PricingDatabase, PricingCategories> {
  $PricingCategoriesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => column,
  );
}

class $PricingCategoriesTableManager
    extends
        RootTableManager<
          _$PricingDatabase,
          PricingCategories,
          PricingCategory,
          $PricingCategoriesFilterComposer,
          $PricingCategoriesOrderingComposer,
          $PricingCategoriesAnnotationComposer,
          $PricingCategoriesCreateCompanionBuilder,
          $PricingCategoriesUpdateCompanionBuilder,
          (
            PricingCategory,
            BaseReferences<
              _$PricingDatabase,
              PricingCategories,
              PricingCategory
            >,
          ),
          PricingCategory,
          PrefetchHooks Function()
        > {
  $PricingCategoriesTableManager(_$PricingDatabase db, PricingCategories table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $PricingCategoriesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $PricingCategoriesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $PricingCategoriesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> businessId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> snapshotJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PricingCategoriesCompanion(
                businessId: businessId,
                profileId: profileId,
                version: version,
                id: id,
                parentId: parentId,
                name: name,
                sortOrder: sortOrder,
                snapshotJson: snapshotJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String businessId,
                required String profileId,
                required int version,
                required String id,
                Value<String?> parentId = const Value.absent(),
                required String name,
                required int sortOrder,
                required String snapshotJson,
                Value<int> rowid = const Value.absent(),
              }) => PricingCategoriesCompanion.insert(
                businessId: businessId,
                profileId: profileId,
                version: version,
                id: id,
                parentId: parentId,
                name: name,
                sortOrder: sortOrder,
                snapshotJson: snapshotJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<PricingCategories, PricingCategory>(table),
                  BaseReferences<
                    _$PricingDatabase,
                    PricingCategories,
                    PricingCategory
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $PricingCategoriesProcessedTableManager =
    ProcessedTableManager<
      _$PricingDatabase,
      PricingCategories,
      PricingCategory,
      $PricingCategoriesFilterComposer,
      $PricingCategoriesOrderingComposer,
      $PricingCategoriesAnnotationComposer,
      $PricingCategoriesCreateCompanionBuilder,
      $PricingCategoriesUpdateCompanionBuilder,
      (
        PricingCategory,
        BaseReferences<_$PricingDatabase, PricingCategories, PricingCategory>,
      ),
      PricingCategory,
      PrefetchHooks Function()
    >;
typedef $PricingVariantsCreateCompanionBuilder =
    PricingVariantsCompanion Function({
      required String businessId,
      required String profileId,
      required int version,
      required String id,
      required String categoryId,
      required String snapshotJson,
      Value<int> rowid,
    });
typedef $PricingVariantsUpdateCompanionBuilder =
    PricingVariantsCompanion Function({
      Value<String> businessId,
      Value<String> profileId,
      Value<int> version,
      Value<String> id,
      Value<String> categoryId,
      Value<String> snapshotJson,
      Value<int> rowid,
    });

class $PricingVariantsFilterComposer
    extends Composer<_$PricingDatabase, PricingVariants> {
  $PricingVariantsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $PricingVariantsOrderingComposer
    extends Composer<_$PricingDatabase, PricingVariants> {
  $PricingVariantsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $PricingVariantsAnnotationComposer
    extends Composer<_$PricingDatabase, PricingVariants> {
  $PricingVariantsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => column,
  );
}

class $PricingVariantsTableManager
    extends
        RootTableManager<
          _$PricingDatabase,
          PricingVariants,
          PricingVariant,
          $PricingVariantsFilterComposer,
          $PricingVariantsOrderingComposer,
          $PricingVariantsAnnotationComposer,
          $PricingVariantsCreateCompanionBuilder,
          $PricingVariantsUpdateCompanionBuilder,
          (
            PricingVariant,
            BaseReferences<_$PricingDatabase, PricingVariants, PricingVariant>,
          ),
          PricingVariant,
          PrefetchHooks Function()
        > {
  $PricingVariantsTableManager(_$PricingDatabase db, PricingVariants table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $PricingVariantsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $PricingVariantsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $PricingVariantsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> businessId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<String> snapshotJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PricingVariantsCompanion(
                businessId: businessId,
                profileId: profileId,
                version: version,
                id: id,
                categoryId: categoryId,
                snapshotJson: snapshotJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String businessId,
                required String profileId,
                required int version,
                required String id,
                required String categoryId,
                required String snapshotJson,
                Value<int> rowid = const Value.absent(),
              }) => PricingVariantsCompanion.insert(
                businessId: businessId,
                profileId: profileId,
                version: version,
                id: id,
                categoryId: categoryId,
                snapshotJson: snapshotJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<PricingVariants, PricingVariant>(table),
                  BaseReferences<
                    _$PricingDatabase,
                    PricingVariants,
                    PricingVariant
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $PricingVariantsProcessedTableManager =
    ProcessedTableManager<
      _$PricingDatabase,
      PricingVariants,
      PricingVariant,
      $PricingVariantsFilterComposer,
      $PricingVariantsOrderingComposer,
      $PricingVariantsAnnotationComposer,
      $PricingVariantsCreateCompanionBuilder,
      $PricingVariantsUpdateCompanionBuilder,
      (
        PricingVariant,
        BaseReferences<_$PricingDatabase, PricingVariants, PricingVariant>,
      ),
      PricingVariant,
      PrefetchHooks Function()
    >;
typedef $PricingRuleVersionsCreateCompanionBuilder =
    PricingRuleVersionsCompanion Function({
      required String businessId,
      required String profileId,
      required int version,
      required String id,
      required String categoryId,
      Value<String?> variantId,
      required String pricingMethod,
      required String rateDecimal,
      required String snapshotJson,
      Value<int> rowid,
    });
typedef $PricingRuleVersionsUpdateCompanionBuilder =
    PricingRuleVersionsCompanion Function({
      Value<String> businessId,
      Value<String> profileId,
      Value<int> version,
      Value<String> id,
      Value<String> categoryId,
      Value<String?> variantId,
      Value<String> pricingMethod,
      Value<String> rateDecimal,
      Value<String> snapshotJson,
      Value<int> rowid,
    });

class $PricingRuleVersionsFilterComposer
    extends Composer<_$PricingDatabase, PricingRuleVersions> {
  $PricingRuleVersionsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get variantId => $composableBuilder(
    column: $table.variantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pricingMethod => $composableBuilder(
    column: $table.pricingMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rateDecimal => $composableBuilder(
    column: $table.rateDecimal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $PricingRuleVersionsOrderingComposer
    extends Composer<_$PricingDatabase, PricingRuleVersions> {
  $PricingRuleVersionsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get variantId => $composableBuilder(
    column: $table.variantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pricingMethod => $composableBuilder(
    column: $table.pricingMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rateDecimal => $composableBuilder(
    column: $table.rateDecimal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $PricingRuleVersionsAnnotationComposer
    extends Composer<_$PricingDatabase, PricingRuleVersions> {
  $PricingRuleVersionsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get variantId =>
      $composableBuilder(column: $table.variantId, builder: (column) => column);

  GeneratedColumn<String> get pricingMethod => $composableBuilder(
    column: $table.pricingMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rateDecimal => $composableBuilder(
    column: $table.rateDecimal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => column,
  );
}

class $PricingRuleVersionsTableManager
    extends
        RootTableManager<
          _$PricingDatabase,
          PricingRuleVersions,
          PricingRuleVersion,
          $PricingRuleVersionsFilterComposer,
          $PricingRuleVersionsOrderingComposer,
          $PricingRuleVersionsAnnotationComposer,
          $PricingRuleVersionsCreateCompanionBuilder,
          $PricingRuleVersionsUpdateCompanionBuilder,
          (
            PricingRuleVersion,
            BaseReferences<
              _$PricingDatabase,
              PricingRuleVersions,
              PricingRuleVersion
            >,
          ),
          PricingRuleVersion,
          PrefetchHooks Function()
        > {
  $PricingRuleVersionsTableManager(
    _$PricingDatabase db,
    PricingRuleVersions table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $PricingRuleVersionsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $PricingRuleVersionsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $PricingRuleVersionsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> businessId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<String?> variantId = const Value.absent(),
                Value<String> pricingMethod = const Value.absent(),
                Value<String> rateDecimal = const Value.absent(),
                Value<String> snapshotJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PricingRuleVersionsCompanion(
                businessId: businessId,
                profileId: profileId,
                version: version,
                id: id,
                categoryId: categoryId,
                variantId: variantId,
                pricingMethod: pricingMethod,
                rateDecimal: rateDecimal,
                snapshotJson: snapshotJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String businessId,
                required String profileId,
                required int version,
                required String id,
                required String categoryId,
                Value<String?> variantId = const Value.absent(),
                required String pricingMethod,
                required String rateDecimal,
                required String snapshotJson,
                Value<int> rowid = const Value.absent(),
              }) => PricingRuleVersionsCompanion.insert(
                businessId: businessId,
                profileId: profileId,
                version: version,
                id: id,
                categoryId: categoryId,
                variantId: variantId,
                pricingMethod: pricingMethod,
                rateDecimal: rateDecimal,
                snapshotJson: snapshotJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<PricingRuleVersions, PricingRuleVersion>(table),
                  BaseReferences<
                    _$PricingDatabase,
                    PricingRuleVersions,
                    PricingRuleVersion
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $PricingRuleVersionsProcessedTableManager =
    ProcessedTableManager<
      _$PricingDatabase,
      PricingRuleVersions,
      PricingRuleVersion,
      $PricingRuleVersionsFilterComposer,
      $PricingRuleVersionsOrderingComposer,
      $PricingRuleVersionsAnnotationComposer,
      $PricingRuleVersionsCreateCompanionBuilder,
      $PricingRuleVersionsUpdateCompanionBuilder,
      (
        PricingRuleVersion,
        BaseReferences<
          _$PricingDatabase,
          PricingRuleVersions,
          PricingRuleVersion
        >,
      ),
      PricingRuleVersion,
      PrefetchHooks Function()
    >;
typedef $PricingAddonsCreateCompanionBuilder = PricingAddonsCompanion Function({
  required String businessId,
  required String profileId,
  required int version,
  required String id,
  required String name,
  required String snapshotJson,
  Value<int> rowid,
});
typedef $PricingAddonsUpdateCompanionBuilder = PricingAddonsCompanion Function({
  Value<String> businessId,
  Value<String> profileId,
  Value<int> version,
  Value<String> id,
  Value<String> name,
  Value<String> snapshotJson,
  Value<int> rowid,
});

class $PricingAddonsFilterComposer
    extends Composer<_$PricingDatabase, PricingAddons> {
  $PricingAddonsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $PricingAddonsOrderingComposer
    extends Composer<_$PricingDatabase, PricingAddons> {
  $PricingAddonsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $PricingAddonsAnnotationComposer
    extends Composer<_$PricingDatabase, PricingAddons> {
  $PricingAddonsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => column,
  );
}

class $PricingAddonsTableManager
    extends
        RootTableManager<
          _$PricingDatabase,
          PricingAddons,
          PricingAddon,
          $PricingAddonsFilterComposer,
          $PricingAddonsOrderingComposer,
          $PricingAddonsAnnotationComposer,
          $PricingAddonsCreateCompanionBuilder,
          $PricingAddonsUpdateCompanionBuilder,
          (
            PricingAddon,
            BaseReferences<_$PricingDatabase, PricingAddons, PricingAddon>,
          ),
          PricingAddon,
          PrefetchHooks Function()
        > {
  $PricingAddonsTableManager(_$PricingDatabase db, PricingAddons table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $PricingAddonsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $PricingAddonsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $PricingAddonsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> businessId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> snapshotJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PricingAddonsCompanion(
                businessId: businessId,
                profileId: profileId,
                version: version,
                id: id,
                name: name,
                snapshotJson: snapshotJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String businessId,
                required String profileId,
                required int version,
                required String id,
                required String name,
                required String snapshotJson,
                Value<int> rowid = const Value.absent(),
              }) => PricingAddonsCompanion.insert(
                businessId: businessId,
                profileId: profileId,
                version: version,
                id: id,
                name: name,
                snapshotJson: snapshotJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<PricingAddons, PricingAddon>(table),
                  BaseReferences<
                    _$PricingDatabase,
                    PricingAddons,
                    PricingAddon
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $PricingAddonsProcessedTableManager =
    ProcessedTableManager<
      _$PricingDatabase,
      PricingAddons,
      PricingAddon,
      $PricingAddonsFilterComposer,
      $PricingAddonsOrderingComposer,
      $PricingAddonsAnnotationComposer,
      $PricingAddonsCreateCompanionBuilder,
      $PricingAddonsUpdateCompanionBuilder,
      (
        PricingAddon,
        BaseReferences<_$PricingDatabase, PricingAddons, PricingAddon>,
      ),
      PricingAddon,
      PrefetchHooks Function()
    >;
typedef $PricingRuleAddonsCreateCompanionBuilder =
    PricingRuleAddonsCompanion Function({
      required String businessId,
      required String profileId,
      required int version,
      required String ruleId,
      required String addonId,
      Value<int> rowid,
    });
typedef $PricingRuleAddonsUpdateCompanionBuilder =
    PricingRuleAddonsCompanion Function({
      Value<String> businessId,
      Value<String> profileId,
      Value<int> version,
      Value<String> ruleId,
      Value<String> addonId,
      Value<int> rowid,
    });

class $PricingRuleAddonsFilterComposer
    extends Composer<_$PricingDatabase, PricingRuleAddons> {
  $PricingRuleAddonsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ruleId => $composableBuilder(
    column: $table.ruleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addonId => $composableBuilder(
    column: $table.addonId,
    builder: (column) => ColumnFilters(column),
  );
}

class $PricingRuleAddonsOrderingComposer
    extends Composer<_$PricingDatabase, PricingRuleAddons> {
  $PricingRuleAddonsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ruleId => $composableBuilder(
    column: $table.ruleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addonId => $composableBuilder(
    column: $table.addonId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $PricingRuleAddonsAnnotationComposer
    extends Composer<_$PricingDatabase, PricingRuleAddons> {
  $PricingRuleAddonsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get ruleId =>
      $composableBuilder(column: $table.ruleId, builder: (column) => column);

  GeneratedColumn<String> get addonId =>
      $composableBuilder(column: $table.addonId, builder: (column) => column);
}

class $PricingRuleAddonsTableManager
    extends
        RootTableManager<
          _$PricingDatabase,
          PricingRuleAddons,
          PricingRuleAddon,
          $PricingRuleAddonsFilterComposer,
          $PricingRuleAddonsOrderingComposer,
          $PricingRuleAddonsAnnotationComposer,
          $PricingRuleAddonsCreateCompanionBuilder,
          $PricingRuleAddonsUpdateCompanionBuilder,
          (
            PricingRuleAddon,
            BaseReferences<
              _$PricingDatabase,
              PricingRuleAddons,
              PricingRuleAddon
            >,
          ),
          PricingRuleAddon,
          PrefetchHooks Function()
        > {
  $PricingRuleAddonsTableManager(_$PricingDatabase db, PricingRuleAddons table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $PricingRuleAddonsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $PricingRuleAddonsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $PricingRuleAddonsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> businessId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> ruleId = const Value.absent(),
                Value<String> addonId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PricingRuleAddonsCompanion(
                businessId: businessId,
                profileId: profileId,
                version: version,
                ruleId: ruleId,
                addonId: addonId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String businessId,
                required String profileId,
                required int version,
                required String ruleId,
                required String addonId,
                Value<int> rowid = const Value.absent(),
              }) => PricingRuleAddonsCompanion.insert(
                businessId: businessId,
                profileId: profileId,
                version: version,
                ruleId: ruleId,
                addonId: addonId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<PricingRuleAddons, PricingRuleAddon>(table),
                  BaseReferences<
                    _$PricingDatabase,
                    PricingRuleAddons,
                    PricingRuleAddon
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $PricingRuleAddonsProcessedTableManager =
    ProcessedTableManager<
      _$PricingDatabase,
      PricingRuleAddons,
      PricingRuleAddon,
      $PricingRuleAddonsFilterComposer,
      $PricingRuleAddonsOrderingComposer,
      $PricingRuleAddonsAnnotationComposer,
      $PricingRuleAddonsCreateCompanionBuilder,
      $PricingRuleAddonsUpdateCompanionBuilder,
      (
        PricingRuleAddon,
        BaseReferences<_$PricingDatabase, PricingRuleAddons, PricingRuleAddon>,
      ),
      PricingRuleAddon,
      PrefetchHooks Function()
    >;
typedef $PricingAuditEventsCreateCompanionBuilder =
    PricingAuditEventsCompanion Function({
      Value<int> id,
      required String businessId,
      required String actorUid,
      required String action,
      required String profileId,
      Value<String?> beforeSnapshot,
      required String afterSnapshot,
      required int createdAt,
    });
typedef $PricingAuditEventsUpdateCompanionBuilder =
    PricingAuditEventsCompanion Function({
      Value<int> id,
      Value<String> businessId,
      Value<String> actorUid,
      Value<String> action,
      Value<String> profileId,
      Value<String?> beforeSnapshot,
      Value<String> afterSnapshot,
      Value<int> createdAt,
    });

class $PricingAuditEventsFilterComposer
    extends Composer<_$PricingDatabase, PricingAuditEvents> {
  $PricingAuditEventsFilterComposer({
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

  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorUid => $composableBuilder(
    column: $table.actorUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get beforeSnapshot => $composableBuilder(
    column: $table.beforeSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get afterSnapshot => $composableBuilder(
    column: $table.afterSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $PricingAuditEventsOrderingComposer
    extends Composer<_$PricingDatabase, PricingAuditEvents> {
  $PricingAuditEventsOrderingComposer({
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

  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorUid => $composableBuilder(
    column: $table.actorUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get beforeSnapshot => $composableBuilder(
    column: $table.beforeSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get afterSnapshot => $composableBuilder(
    column: $table.afterSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $PricingAuditEventsAnnotationComposer
    extends Composer<_$PricingDatabase, PricingAuditEvents> {
  $PricingAuditEventsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actorUid =>
      $composableBuilder(column: $table.actorUid, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get beforeSnapshot => $composableBuilder(
    column: $table.beforeSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get afterSnapshot => $composableBuilder(
    column: $table.afterSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $PricingAuditEventsTableManager
    extends
        RootTableManager<
          _$PricingDatabase,
          PricingAuditEvents,
          PricingAuditEvent,
          $PricingAuditEventsFilterComposer,
          $PricingAuditEventsOrderingComposer,
          $PricingAuditEventsAnnotationComposer,
          $PricingAuditEventsCreateCompanionBuilder,
          $PricingAuditEventsUpdateCompanionBuilder,
          (
            PricingAuditEvent,
            BaseReferences<
              _$PricingDatabase,
              PricingAuditEvents,
              PricingAuditEvent
            >,
          ),
          PricingAuditEvent,
          PrefetchHooks Function()
        > {
  $PricingAuditEventsTableManager(
    _$PricingDatabase db,
    PricingAuditEvents table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $PricingAuditEventsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $PricingAuditEventsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $PricingAuditEventsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> businessId = const Value.absent(),
                Value<String> actorUid = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String?> beforeSnapshot = const Value.absent(),
                Value<String> afterSnapshot = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => PricingAuditEventsCompanion(
                id: id,
                businessId: businessId,
                actorUid: actorUid,
                action: action,
                profileId: profileId,
                beforeSnapshot: beforeSnapshot,
                afterSnapshot: afterSnapshot,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String businessId,
                required String actorUid,
                required String action,
                required String profileId,
                Value<String?> beforeSnapshot = const Value.absent(),
                required String afterSnapshot,
                required int createdAt,
              }) => PricingAuditEventsCompanion.insert(
                id: id,
                businessId: businessId,
                actorUid: actorUid,
                action: action,
                profileId: profileId,
                beforeSnapshot: beforeSnapshot,
                afterSnapshot: afterSnapshot,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<PricingAuditEvents, PricingAuditEvent>(table),
                  BaseReferences<
                    _$PricingDatabase,
                    PricingAuditEvents,
                    PricingAuditEvent
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $PricingAuditEventsProcessedTableManager =
    ProcessedTableManager<
      _$PricingDatabase,
      PricingAuditEvents,
      PricingAuditEvent,
      $PricingAuditEventsFilterComposer,
      $PricingAuditEventsOrderingComposer,
      $PricingAuditEventsAnnotationComposer,
      $PricingAuditEventsCreateCompanionBuilder,
      $PricingAuditEventsUpdateCompanionBuilder,
      (
        PricingAuditEvent,
        BaseReferences<
          _$PricingDatabase,
          PricingAuditEvents,
          PricingAuditEvent
        >,
      ),
      PricingAuditEvent,
      PrefetchHooks Function()
    >;
typedef $UniversalPricingProfilesCreateCompanionBuilder =
    UniversalPricingProfilesCompanion Function({
      required String businessId,
      required String id,
      required String name,
      Value<String> status,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $UniversalPricingProfilesUpdateCompanionBuilder =
    UniversalPricingProfilesCompanion Function({
      Value<String> businessId,
      Value<String> id,
      Value<String> name,
      Value<String> status,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $UniversalPricingProfilesFilterComposer
    extends Composer<_$PricingDatabase, UniversalPricingProfiles> {
  $UniversalPricingProfilesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $UniversalPricingProfilesOrderingComposer
    extends Composer<_$PricingDatabase, UniversalPricingProfiles> {
  $UniversalPricingProfilesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $UniversalPricingProfilesAnnotationComposer
    extends Composer<_$PricingDatabase, UniversalPricingProfiles> {
  $UniversalPricingProfilesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $UniversalPricingProfilesTableManager
    extends
        RootTableManager<
          _$PricingDatabase,
          UniversalPricingProfiles,
          UniversalPricingProfile,
          $UniversalPricingProfilesFilterComposer,
          $UniversalPricingProfilesOrderingComposer,
          $UniversalPricingProfilesAnnotationComposer,
          $UniversalPricingProfilesCreateCompanionBuilder,
          $UniversalPricingProfilesUpdateCompanionBuilder,
          (
            UniversalPricingProfile,
            BaseReferences<
              _$PricingDatabase,
              UniversalPricingProfiles,
              UniversalPricingProfile
            >,
          ),
          UniversalPricingProfile,
          PrefetchHooks Function()
        > {
  $UniversalPricingProfilesTableManager(
    _$PricingDatabase db,
    UniversalPricingProfiles table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $UniversalPricingProfilesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $UniversalPricingProfilesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $UniversalPricingProfilesAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> businessId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UniversalPricingProfilesCompanion(
                businessId: businessId,
                id: id,
                name: name,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String businessId,
                required String id,
                required String name,
                Value<String> status = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => UniversalPricingProfilesCompanion.insert(
                businessId: businessId,
                id: id,
                name: name,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    UniversalPricingProfiles,
                    UniversalPricingProfile
                  >(table),
                  BaseReferences<
                    _$PricingDatabase,
                    UniversalPricingProfiles,
                    UniversalPricingProfile
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $UniversalPricingProfilesProcessedTableManager =
    ProcessedTableManager<
      _$PricingDatabase,
      UniversalPricingProfiles,
      UniversalPricingProfile,
      $UniversalPricingProfilesFilterComposer,
      $UniversalPricingProfilesOrderingComposer,
      $UniversalPricingProfilesAnnotationComposer,
      $UniversalPricingProfilesCreateCompanionBuilder,
      $UniversalPricingProfilesUpdateCompanionBuilder,
      (
        UniversalPricingProfile,
        BaseReferences<
          _$PricingDatabase,
          UniversalPricingProfiles,
          UniversalPricingProfile
        >,
      ),
      UniversalPricingProfile,
      PrefetchHooks Function()
    >;
typedef $UniversalPricingDraftsCreateCompanionBuilder =
    UniversalPricingDraftsCompanion Function({
      required String businessId,
      required String profileId,
      required int revision,
      required String snapshotJson,
      Value<int> rowid,
    });
typedef $UniversalPricingDraftsUpdateCompanionBuilder =
    UniversalPricingDraftsCompanion Function({
      Value<String> businessId,
      Value<String> profileId,
      Value<int> revision,
      Value<String> snapshotJson,
      Value<int> rowid,
    });

class $UniversalPricingDraftsFilterComposer
    extends Composer<_$PricingDatabase, UniversalPricingDrafts> {
  $UniversalPricingDraftsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $UniversalPricingDraftsOrderingComposer
    extends Composer<_$PricingDatabase, UniversalPricingDrafts> {
  $UniversalPricingDraftsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $UniversalPricingDraftsAnnotationComposer
    extends Composer<_$PricingDatabase, UniversalPricingDrafts> {
  $UniversalPricingDraftsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => column,
  );
}

class $UniversalPricingDraftsTableManager
    extends
        RootTableManager<
          _$PricingDatabase,
          UniversalPricingDrafts,
          UniversalPricingDraft,
          $UniversalPricingDraftsFilterComposer,
          $UniversalPricingDraftsOrderingComposer,
          $UniversalPricingDraftsAnnotationComposer,
          $UniversalPricingDraftsCreateCompanionBuilder,
          $UniversalPricingDraftsUpdateCompanionBuilder,
          (
            UniversalPricingDraft,
            BaseReferences<
              _$PricingDatabase,
              UniversalPricingDrafts,
              UniversalPricingDraft
            >,
          ),
          UniversalPricingDraft,
          PrefetchHooks Function()
        > {
  $UniversalPricingDraftsTableManager(
    _$PricingDatabase db,
    UniversalPricingDrafts table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $UniversalPricingDraftsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $UniversalPricingDraftsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $UniversalPricingDraftsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> businessId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> snapshotJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UniversalPricingDraftsCompanion(
                businessId: businessId,
                profileId: profileId,
                revision: revision,
                snapshotJson: snapshotJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String businessId,
                required String profileId,
                required int revision,
                required String snapshotJson,
                Value<int> rowid = const Value.absent(),
              }) => UniversalPricingDraftsCompanion.insert(
                businessId: businessId,
                profileId: profileId,
                revision: revision,
                snapshotJson: snapshotJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<UniversalPricingDrafts, UniversalPricingDraft>(
                    table,
                  ),
                  BaseReferences<
                    _$PricingDatabase,
                    UniversalPricingDrafts,
                    UniversalPricingDraft
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $UniversalPricingDraftsProcessedTableManager =
    ProcessedTableManager<
      _$PricingDatabase,
      UniversalPricingDrafts,
      UniversalPricingDraft,
      $UniversalPricingDraftsFilterComposer,
      $UniversalPricingDraftsOrderingComposer,
      $UniversalPricingDraftsAnnotationComposer,
      $UniversalPricingDraftsCreateCompanionBuilder,
      $UniversalPricingDraftsUpdateCompanionBuilder,
      (
        UniversalPricingDraft,
        BaseReferences<
          _$PricingDatabase,
          UniversalPricingDrafts,
          UniversalPricingDraft
        >,
      ),
      UniversalPricingDraft,
      PrefetchHooks Function()
    >;
typedef $UniversalPricingVersionsCreateCompanionBuilder =
    UniversalPricingVersionsCompanion Function({
      required String businessId,
      required String profileId,
      required int version,
      required String engineVersion,
      required int effectiveAt,
      Value<int?> expiresAt,
      required int publishedAt,
      required String publishedBy,
      required String snapshotJson,
      Value<int> sealed,
      Value<int> rowid,
    });
typedef $UniversalPricingVersionsUpdateCompanionBuilder =
    UniversalPricingVersionsCompanion Function({
      Value<String> businessId,
      Value<String> profileId,
      Value<int> version,
      Value<String> engineVersion,
      Value<int> effectiveAt,
      Value<int?> expiresAt,
      Value<int> publishedAt,
      Value<String> publishedBy,
      Value<String> snapshotJson,
      Value<int> sealed,
      Value<int> rowid,
    });

class $UniversalPricingVersionsFilterComposer
    extends Composer<_$PricingDatabase, UniversalPricingVersions> {
  $UniversalPricingVersionsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get engineVersion => $composableBuilder(
    column: $table.engineVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get effectiveAt => $composableBuilder(
    column: $table.effectiveAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publishedBy => $composableBuilder(
    column: $table.publishedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sealed => $composableBuilder(
    column: $table.sealed,
    builder: (column) => ColumnFilters(column),
  );
}

class $UniversalPricingVersionsOrderingComposer
    extends Composer<_$PricingDatabase, UniversalPricingVersions> {
  $UniversalPricingVersionsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get engineVersion => $composableBuilder(
    column: $table.engineVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get effectiveAt => $composableBuilder(
    column: $table.effectiveAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publishedBy => $composableBuilder(
    column: $table.publishedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sealed => $composableBuilder(
    column: $table.sealed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $UniversalPricingVersionsAnnotationComposer
    extends Composer<_$PricingDatabase, UniversalPricingVersions> {
  $UniversalPricingVersionsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get engineVersion => $composableBuilder(
    column: $table.engineVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get effectiveAt => $composableBuilder(
    column: $table.effectiveAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<int> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get publishedBy => $composableBuilder(
    column: $table.publishedBy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sealed =>
      $composableBuilder(column: $table.sealed, builder: (column) => column);
}

class $UniversalPricingVersionsTableManager
    extends
        RootTableManager<
          _$PricingDatabase,
          UniversalPricingVersions,
          UniversalPricingVersion,
          $UniversalPricingVersionsFilterComposer,
          $UniversalPricingVersionsOrderingComposer,
          $UniversalPricingVersionsAnnotationComposer,
          $UniversalPricingVersionsCreateCompanionBuilder,
          $UniversalPricingVersionsUpdateCompanionBuilder,
          (
            UniversalPricingVersion,
            BaseReferences<
              _$PricingDatabase,
              UniversalPricingVersions,
              UniversalPricingVersion
            >,
          ),
          UniversalPricingVersion,
          PrefetchHooks Function()
        > {
  $UniversalPricingVersionsTableManager(
    _$PricingDatabase db,
    UniversalPricingVersions table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $UniversalPricingVersionsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $UniversalPricingVersionsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $UniversalPricingVersionsAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> businessId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> engineVersion = const Value.absent(),
                Value<int> effectiveAt = const Value.absent(),
                Value<int?> expiresAt = const Value.absent(),
                Value<int> publishedAt = const Value.absent(),
                Value<String> publishedBy = const Value.absent(),
                Value<String> snapshotJson = const Value.absent(),
                Value<int> sealed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UniversalPricingVersionsCompanion(
                businessId: businessId,
                profileId: profileId,
                version: version,
                engineVersion: engineVersion,
                effectiveAt: effectiveAt,
                expiresAt: expiresAt,
                publishedAt: publishedAt,
                publishedBy: publishedBy,
                snapshotJson: snapshotJson,
                sealed: sealed,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String businessId,
                required String profileId,
                required int version,
                required String engineVersion,
                required int effectiveAt,
                Value<int?> expiresAt = const Value.absent(),
                required int publishedAt,
                required String publishedBy,
                required String snapshotJson,
                Value<int> sealed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UniversalPricingVersionsCompanion.insert(
                businessId: businessId,
                profileId: profileId,
                version: version,
                engineVersion: engineVersion,
                effectiveAt: effectiveAt,
                expiresAt: expiresAt,
                publishedAt: publishedAt,
                publishedBy: publishedBy,
                snapshotJson: snapshotJson,
                sealed: sealed,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    UniversalPricingVersions,
                    UniversalPricingVersion
                  >(table),
                  BaseReferences<
                    _$PricingDatabase,
                    UniversalPricingVersions,
                    UniversalPricingVersion
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $UniversalPricingVersionsProcessedTableManager =
    ProcessedTableManager<
      _$PricingDatabase,
      UniversalPricingVersions,
      UniversalPricingVersion,
      $UniversalPricingVersionsFilterComposer,
      $UniversalPricingVersionsOrderingComposer,
      $UniversalPricingVersionsAnnotationComposer,
      $UniversalPricingVersionsCreateCompanionBuilder,
      $UniversalPricingVersionsUpdateCompanionBuilder,
      (
        UniversalPricingVersion,
        BaseReferences<
          _$PricingDatabase,
          UniversalPricingVersions,
          UniversalPricingVersion
        >,
      ),
      UniversalPricingVersion,
      PrefetchHooks Function()
    >;
typedef $UniversalPricingCategoriesCreateCompanionBuilder =
    UniversalPricingCategoriesCompanion Function({
      required String businessId,
      required String profileId,
      required int version,
      required String id,
      Value<String?> parentId,
      required String name,
      required int sortOrder,
      Value<int> rowid,
    });
typedef $UniversalPricingCategoriesUpdateCompanionBuilder =
    UniversalPricingCategoriesCompanion Function({
      Value<String> businessId,
      Value<String> profileId,
      Value<int> version,
      Value<String> id,
      Value<String?> parentId,
      Value<String> name,
      Value<int> sortOrder,
      Value<int> rowid,
    });

class $UniversalPricingCategoriesFilterComposer
    extends Composer<_$PricingDatabase, UniversalPricingCategories> {
  $UniversalPricingCategoriesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $UniversalPricingCategoriesOrderingComposer
    extends Composer<_$PricingDatabase, UniversalPricingCategories> {
  $UniversalPricingCategoriesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $UniversalPricingCategoriesAnnotationComposer
    extends Composer<_$PricingDatabase, UniversalPricingCategories> {
  $UniversalPricingCategoriesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $UniversalPricingCategoriesTableManager
    extends
        RootTableManager<
          _$PricingDatabase,
          UniversalPricingCategories,
          UniversalPricingCategory,
          $UniversalPricingCategoriesFilterComposer,
          $UniversalPricingCategoriesOrderingComposer,
          $UniversalPricingCategoriesAnnotationComposer,
          $UniversalPricingCategoriesCreateCompanionBuilder,
          $UniversalPricingCategoriesUpdateCompanionBuilder,
          (
            UniversalPricingCategory,
            BaseReferences<
              _$PricingDatabase,
              UniversalPricingCategories,
              UniversalPricingCategory
            >,
          ),
          UniversalPricingCategory,
          PrefetchHooks Function()
        > {
  $UniversalPricingCategoriesTableManager(
    _$PricingDatabase db,
    UniversalPricingCategories table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $UniversalPricingCategoriesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $UniversalPricingCategoriesOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $UniversalPricingCategoriesAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> businessId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UniversalPricingCategoriesCompanion(
                businessId: businessId,
                profileId: profileId,
                version: version,
                id: id,
                parentId: parentId,
                name: name,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String businessId,
                required String profileId,
                required int version,
                required String id,
                Value<String?> parentId = const Value.absent(),
                required String name,
                required int sortOrder,
                Value<int> rowid = const Value.absent(),
              }) => UniversalPricingCategoriesCompanion.insert(
                businessId: businessId,
                profileId: profileId,
                version: version,
                id: id,
                parentId: parentId,
                name: name,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    UniversalPricingCategories,
                    UniversalPricingCategory
                  >(table),
                  BaseReferences<
                    _$PricingDatabase,
                    UniversalPricingCategories,
                    UniversalPricingCategory
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $UniversalPricingCategoriesProcessedTableManager =
    ProcessedTableManager<
      _$PricingDatabase,
      UniversalPricingCategories,
      UniversalPricingCategory,
      $UniversalPricingCategoriesFilterComposer,
      $UniversalPricingCategoriesOrderingComposer,
      $UniversalPricingCategoriesAnnotationComposer,
      $UniversalPricingCategoriesCreateCompanionBuilder,
      $UniversalPricingCategoriesUpdateCompanionBuilder,
      (
        UniversalPricingCategory,
        BaseReferences<
          _$PricingDatabase,
          UniversalPricingCategories,
          UniversalPricingCategory
        >,
      ),
      UniversalPricingCategory,
      PrefetchHooks Function()
    >;
typedef $UniversalPricingProductsCreateCompanionBuilder =
    UniversalPricingProductsCompanion Function({
      required String businessId,
      required String profileId,
      required int version,
      required String id,
      required String categoryId,
      required String name,
      required String ruleId,
      required String strategyKind,
      required String attributesJson,
      required String ruleJson,
      Value<int> rowid,
    });
typedef $UniversalPricingProductsUpdateCompanionBuilder =
    UniversalPricingProductsCompanion Function({
      Value<String> businessId,
      Value<String> profileId,
      Value<int> version,
      Value<String> id,
      Value<String> categoryId,
      Value<String> name,
      Value<String> ruleId,
      Value<String> strategyKind,
      Value<String> attributesJson,
      Value<String> ruleJson,
      Value<int> rowid,
    });

class $UniversalPricingProductsFilterComposer
    extends Composer<_$PricingDatabase, UniversalPricingProducts> {
  $UniversalPricingProductsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ruleId => $composableBuilder(
    column: $table.ruleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get strategyKind => $composableBuilder(
    column: $table.strategyKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attributesJson => $composableBuilder(
    column: $table.attributesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ruleJson => $composableBuilder(
    column: $table.ruleJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $UniversalPricingProductsOrderingComposer
    extends Composer<_$PricingDatabase, UniversalPricingProducts> {
  $UniversalPricingProductsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ruleId => $composableBuilder(
    column: $table.ruleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get strategyKind => $composableBuilder(
    column: $table.strategyKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attributesJson => $composableBuilder(
    column: $table.attributesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ruleJson => $composableBuilder(
    column: $table.ruleJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $UniversalPricingProductsAnnotationComposer
    extends Composer<_$PricingDatabase, UniversalPricingProducts> {
  $UniversalPricingProductsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get ruleId =>
      $composableBuilder(column: $table.ruleId, builder: (column) => column);

  GeneratedColumn<String> get strategyKind => $composableBuilder(
    column: $table.strategyKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get attributesJson => $composableBuilder(
    column: $table.attributesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ruleJson =>
      $composableBuilder(column: $table.ruleJson, builder: (column) => column);
}

class $UniversalPricingProductsTableManager
    extends
        RootTableManager<
          _$PricingDatabase,
          UniversalPricingProducts,
          UniversalPricingProduct,
          $UniversalPricingProductsFilterComposer,
          $UniversalPricingProductsOrderingComposer,
          $UniversalPricingProductsAnnotationComposer,
          $UniversalPricingProductsCreateCompanionBuilder,
          $UniversalPricingProductsUpdateCompanionBuilder,
          (
            UniversalPricingProduct,
            BaseReferences<
              _$PricingDatabase,
              UniversalPricingProducts,
              UniversalPricingProduct
            >,
          ),
          UniversalPricingProduct,
          PrefetchHooks Function()
        > {
  $UniversalPricingProductsTableManager(
    _$PricingDatabase db,
    UniversalPricingProducts table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $UniversalPricingProductsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $UniversalPricingProductsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $UniversalPricingProductsAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> businessId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> ruleId = const Value.absent(),
                Value<String> strategyKind = const Value.absent(),
                Value<String> attributesJson = const Value.absent(),
                Value<String> ruleJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UniversalPricingProductsCompanion(
                businessId: businessId,
                profileId: profileId,
                version: version,
                id: id,
                categoryId: categoryId,
                name: name,
                ruleId: ruleId,
                strategyKind: strategyKind,
                attributesJson: attributesJson,
                ruleJson: ruleJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String businessId,
                required String profileId,
                required int version,
                required String id,
                required String categoryId,
                required String name,
                required String ruleId,
                required String strategyKind,
                required String attributesJson,
                required String ruleJson,
                Value<int> rowid = const Value.absent(),
              }) => UniversalPricingProductsCompanion.insert(
                businessId: businessId,
                profileId: profileId,
                version: version,
                id: id,
                categoryId: categoryId,
                name: name,
                ruleId: ruleId,
                strategyKind: strategyKind,
                attributesJson: attributesJson,
                ruleJson: ruleJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    UniversalPricingProducts,
                    UniversalPricingProduct
                  >(table),
                  BaseReferences<
                    _$PricingDatabase,
                    UniversalPricingProducts,
                    UniversalPricingProduct
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $UniversalPricingProductsProcessedTableManager =
    ProcessedTableManager<
      _$PricingDatabase,
      UniversalPricingProducts,
      UniversalPricingProduct,
      $UniversalPricingProductsFilterComposer,
      $UniversalPricingProductsOrderingComposer,
      $UniversalPricingProductsAnnotationComposer,
      $UniversalPricingProductsCreateCompanionBuilder,
      $UniversalPricingProductsUpdateCompanionBuilder,
      (
        UniversalPricingProduct,
        BaseReferences<
          _$PricingDatabase,
          UniversalPricingProducts,
          UniversalPricingProduct
        >,
      ),
      UniversalPricingProduct,
      PrefetchHooks Function()
    >;
typedef $UniversalPricingInputsCreateCompanionBuilder =
    UniversalPricingInputsCompanion Function({
      required String businessId,
      required String profileId,
      required int version,
      required String productId,
      required String id,
      required int sortOrder,
      required String definitionJson,
      Value<int> rowid,
    });
typedef $UniversalPricingInputsUpdateCompanionBuilder =
    UniversalPricingInputsCompanion Function({
      Value<String> businessId,
      Value<String> profileId,
      Value<int> version,
      Value<String> productId,
      Value<String> id,
      Value<int> sortOrder,
      Value<String> definitionJson,
      Value<int> rowid,
    });

class $UniversalPricingInputsFilterComposer
    extends Composer<_$PricingDatabase, UniversalPricingInputs> {
  $UniversalPricingInputsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get definitionJson => $composableBuilder(
    column: $table.definitionJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $UniversalPricingInputsOrderingComposer
    extends Composer<_$PricingDatabase, UniversalPricingInputs> {
  $UniversalPricingInputsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get definitionJson => $composableBuilder(
    column: $table.definitionJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $UniversalPricingInputsAnnotationComposer
    extends Composer<_$PricingDatabase, UniversalPricingInputs> {
  $UniversalPricingInputsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get definitionJson => $composableBuilder(
    column: $table.definitionJson,
    builder: (column) => column,
  );
}

class $UniversalPricingInputsTableManager
    extends
        RootTableManager<
          _$PricingDatabase,
          UniversalPricingInputs,
          UniversalPricingInput,
          $UniversalPricingInputsFilterComposer,
          $UniversalPricingInputsOrderingComposer,
          $UniversalPricingInputsAnnotationComposer,
          $UniversalPricingInputsCreateCompanionBuilder,
          $UniversalPricingInputsUpdateCompanionBuilder,
          (
            UniversalPricingInput,
            BaseReferences<
              _$PricingDatabase,
              UniversalPricingInputs,
              UniversalPricingInput
            >,
          ),
          UniversalPricingInput,
          PrefetchHooks Function()
        > {
  $UniversalPricingInputsTableManager(
    _$PricingDatabase db,
    UniversalPricingInputs table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $UniversalPricingInputsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $UniversalPricingInputsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $UniversalPricingInputsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> businessId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> productId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> definitionJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UniversalPricingInputsCompanion(
                businessId: businessId,
                profileId: profileId,
                version: version,
                productId: productId,
                id: id,
                sortOrder: sortOrder,
                definitionJson: definitionJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String businessId,
                required String profileId,
                required int version,
                required String productId,
                required String id,
                required int sortOrder,
                required String definitionJson,
                Value<int> rowid = const Value.absent(),
              }) => UniversalPricingInputsCompanion.insert(
                businessId: businessId,
                profileId: profileId,
                version: version,
                productId: productId,
                id: id,
                sortOrder: sortOrder,
                definitionJson: definitionJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<UniversalPricingInputs, UniversalPricingInput>(
                    table,
                  ),
                  BaseReferences<
                    _$PricingDatabase,
                    UniversalPricingInputs,
                    UniversalPricingInput
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $UniversalPricingInputsProcessedTableManager =
    ProcessedTableManager<
      _$PricingDatabase,
      UniversalPricingInputs,
      UniversalPricingInput,
      $UniversalPricingInputsFilterComposer,
      $UniversalPricingInputsOrderingComposer,
      $UniversalPricingInputsAnnotationComposer,
      $UniversalPricingInputsCreateCompanionBuilder,
      $UniversalPricingInputsUpdateCompanionBuilder,
      (
        UniversalPricingInput,
        BaseReferences<
          _$PricingDatabase,
          UniversalPricingInputs,
          UniversalPricingInput
        >,
      ),
      UniversalPricingInput,
      PrefetchHooks Function()
    >;
typedef $UniversalPricingRatesCreateCompanionBuilder =
    UniversalPricingRatesCompanion Function({
      required String businessId,
      required String profileId,
      required int version,
      required String productId,
      required String id,
      required String rateKey,
      required String amountDecimal,
      required String unit,
      required String selectorsJson,
      Value<int> rowid,
    });
typedef $UniversalPricingRatesUpdateCompanionBuilder =
    UniversalPricingRatesCompanion Function({
      Value<String> businessId,
      Value<String> profileId,
      Value<int> version,
      Value<String> productId,
      Value<String> id,
      Value<String> rateKey,
      Value<String> amountDecimal,
      Value<String> unit,
      Value<String> selectorsJson,
      Value<int> rowid,
    });

class $UniversalPricingRatesFilterComposer
    extends Composer<_$PricingDatabase, UniversalPricingRates> {
  $UniversalPricingRatesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rateKey => $composableBuilder(
    column: $table.rateKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get amountDecimal => $composableBuilder(
    column: $table.amountDecimal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectorsJson => $composableBuilder(
    column: $table.selectorsJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $UniversalPricingRatesOrderingComposer
    extends Composer<_$PricingDatabase, UniversalPricingRates> {
  $UniversalPricingRatesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rateKey => $composableBuilder(
    column: $table.rateKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amountDecimal => $composableBuilder(
    column: $table.amountDecimal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectorsJson => $composableBuilder(
    column: $table.selectorsJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $UniversalPricingRatesAnnotationComposer
    extends Composer<_$PricingDatabase, UniversalPricingRates> {
  $UniversalPricingRatesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get rateKey =>
      $composableBuilder(column: $table.rateKey, builder: (column) => column);

  GeneratedColumn<String> get amountDecimal => $composableBuilder(
    column: $table.amountDecimal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get selectorsJson => $composableBuilder(
    column: $table.selectorsJson,
    builder: (column) => column,
  );
}

class $UniversalPricingRatesTableManager
    extends
        RootTableManager<
          _$PricingDatabase,
          UniversalPricingRates,
          UniversalPricingRate,
          $UniversalPricingRatesFilterComposer,
          $UniversalPricingRatesOrderingComposer,
          $UniversalPricingRatesAnnotationComposer,
          $UniversalPricingRatesCreateCompanionBuilder,
          $UniversalPricingRatesUpdateCompanionBuilder,
          (
            UniversalPricingRate,
            BaseReferences<
              _$PricingDatabase,
              UniversalPricingRates,
              UniversalPricingRate
            >,
          ),
          UniversalPricingRate,
          PrefetchHooks Function()
        > {
  $UniversalPricingRatesTableManager(
    _$PricingDatabase db,
    UniversalPricingRates table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $UniversalPricingRatesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $UniversalPricingRatesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $UniversalPricingRatesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> businessId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> productId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> rateKey = const Value.absent(),
                Value<String> amountDecimal = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<String> selectorsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UniversalPricingRatesCompanion(
                businessId: businessId,
                profileId: profileId,
                version: version,
                productId: productId,
                id: id,
                rateKey: rateKey,
                amountDecimal: amountDecimal,
                unit: unit,
                selectorsJson: selectorsJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String businessId,
                required String profileId,
                required int version,
                required String productId,
                required String id,
                required String rateKey,
                required String amountDecimal,
                required String unit,
                required String selectorsJson,
                Value<int> rowid = const Value.absent(),
              }) => UniversalPricingRatesCompanion.insert(
                businessId: businessId,
                profileId: profileId,
                version: version,
                productId: productId,
                id: id,
                rateKey: rateKey,
                amountDecimal: amountDecimal,
                unit: unit,
                selectorsJson: selectorsJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<UniversalPricingRates, UniversalPricingRate>(
                    table,
                  ),
                  BaseReferences<
                    _$PricingDatabase,
                    UniversalPricingRates,
                    UniversalPricingRate
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $UniversalPricingRatesProcessedTableManager =
    ProcessedTableManager<
      _$PricingDatabase,
      UniversalPricingRates,
      UniversalPricingRate,
      $UniversalPricingRatesFilterComposer,
      $UniversalPricingRatesOrderingComposer,
      $UniversalPricingRatesAnnotationComposer,
      $UniversalPricingRatesCreateCompanionBuilder,
      $UniversalPricingRatesUpdateCompanionBuilder,
      (
        UniversalPricingRate,
        BaseReferences<
          _$PricingDatabase,
          UniversalPricingRates,
          UniversalPricingRate
        >,
      ),
      UniversalPricingRate,
      PrefetchHooks Function()
    >;
typedef $UniversalPricingUnitSystemsCreateCompanionBuilder =
    UniversalPricingUnitSystemsCompanion Function({
      required String businessId,
      required String profileId,
      required int version,
      required String productId,
      required String snapshotJson,
      Value<int> rowid,
    });
typedef $UniversalPricingUnitSystemsUpdateCompanionBuilder =
    UniversalPricingUnitSystemsCompanion Function({
      Value<String> businessId,
      Value<String> profileId,
      Value<int> version,
      Value<String> productId,
      Value<String> snapshotJson,
      Value<int> rowid,
    });

class $UniversalPricingUnitSystemsFilterComposer
    extends Composer<_$PricingDatabase, UniversalPricingUnitSystems> {
  $UniversalPricingUnitSystemsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $UniversalPricingUnitSystemsOrderingComposer
    extends Composer<_$PricingDatabase, UniversalPricingUnitSystems> {
  $UniversalPricingUnitSystemsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $UniversalPricingUnitSystemsAnnotationComposer
    extends Composer<_$PricingDatabase, UniversalPricingUnitSystems> {
  $UniversalPricingUnitSystemsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => column,
  );
}

class $UniversalPricingUnitSystemsTableManager
    extends
        RootTableManager<
          _$PricingDatabase,
          UniversalPricingUnitSystems,
          UniversalPricingUnitSystem,
          $UniversalPricingUnitSystemsFilterComposer,
          $UniversalPricingUnitSystemsOrderingComposer,
          $UniversalPricingUnitSystemsAnnotationComposer,
          $UniversalPricingUnitSystemsCreateCompanionBuilder,
          $UniversalPricingUnitSystemsUpdateCompanionBuilder,
          (
            UniversalPricingUnitSystem,
            BaseReferences<
              _$PricingDatabase,
              UniversalPricingUnitSystems,
              UniversalPricingUnitSystem
            >,
          ),
          UniversalPricingUnitSystem,
          PrefetchHooks Function()
        > {
  $UniversalPricingUnitSystemsTableManager(
    _$PricingDatabase db,
    UniversalPricingUnitSystems table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $UniversalPricingUnitSystemsFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $UniversalPricingUnitSystemsOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $UniversalPricingUnitSystemsAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> businessId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> productId = const Value.absent(),
                Value<String> snapshotJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UniversalPricingUnitSystemsCompanion(
                businessId: businessId,
                profileId: profileId,
                version: version,
                productId: productId,
                snapshotJson: snapshotJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String businessId,
                required String profileId,
                required int version,
                required String productId,
                required String snapshotJson,
                Value<int> rowid = const Value.absent(),
              }) => UniversalPricingUnitSystemsCompanion.insert(
                businessId: businessId,
                profileId: profileId,
                version: version,
                productId: productId,
                snapshotJson: snapshotJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    UniversalPricingUnitSystems,
                    UniversalPricingUnitSystem
                  >(table),
                  BaseReferences<
                    _$PricingDatabase,
                    UniversalPricingUnitSystems,
                    UniversalPricingUnitSystem
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $UniversalPricingUnitSystemsProcessedTableManager =
    ProcessedTableManager<
      _$PricingDatabase,
      UniversalPricingUnitSystems,
      UniversalPricingUnitSystem,
      $UniversalPricingUnitSystemsFilterComposer,
      $UniversalPricingUnitSystemsOrderingComposer,
      $UniversalPricingUnitSystemsAnnotationComposer,
      $UniversalPricingUnitSystemsCreateCompanionBuilder,
      $UniversalPricingUnitSystemsUpdateCompanionBuilder,
      (
        UniversalPricingUnitSystem,
        BaseReferences<
          _$PricingDatabase,
          UniversalPricingUnitSystems,
          UniversalPricingUnitSystem
        >,
      ),
      UniversalPricingUnitSystem,
      PrefetchHooks Function()
    >;
typedef $UniversalPricingDimensionRulesCreateCompanionBuilder =
    UniversalPricingDimensionRulesCompanion Function({
      required String businessId,
      required String profileId,
      required int version,
      required String productId,
      required String fieldId,
      required String snapshotJson,
      Value<int> rowid,
    });
typedef $UniversalPricingDimensionRulesUpdateCompanionBuilder =
    UniversalPricingDimensionRulesCompanion Function({
      Value<String> businessId,
      Value<String> profileId,
      Value<int> version,
      Value<String> productId,
      Value<String> fieldId,
      Value<String> snapshotJson,
      Value<int> rowid,
    });

class $UniversalPricingDimensionRulesFilterComposer
    extends Composer<_$PricingDatabase, UniversalPricingDimensionRules> {
  $UniversalPricingDimensionRulesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldId => $composableBuilder(
    column: $table.fieldId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $UniversalPricingDimensionRulesOrderingComposer
    extends Composer<_$PricingDatabase, UniversalPricingDimensionRules> {
  $UniversalPricingDimensionRulesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldId => $composableBuilder(
    column: $table.fieldId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $UniversalPricingDimensionRulesAnnotationComposer
    extends Composer<_$PricingDatabase, UniversalPricingDimensionRules> {
  $UniversalPricingDimensionRulesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get fieldId =>
      $composableBuilder(column: $table.fieldId, builder: (column) => column);

  GeneratedColumn<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => column,
  );
}

class $UniversalPricingDimensionRulesTableManager
    extends
        RootTableManager<
          _$PricingDatabase,
          UniversalPricingDimensionRules,
          UniversalPricingDimensionRule,
          $UniversalPricingDimensionRulesFilterComposer,
          $UniversalPricingDimensionRulesOrderingComposer,
          $UniversalPricingDimensionRulesAnnotationComposer,
          $UniversalPricingDimensionRulesCreateCompanionBuilder,
          $UniversalPricingDimensionRulesUpdateCompanionBuilder,
          (
            UniversalPricingDimensionRule,
            BaseReferences<
              _$PricingDatabase,
              UniversalPricingDimensionRules,
              UniversalPricingDimensionRule
            >,
          ),
          UniversalPricingDimensionRule,
          PrefetchHooks Function()
        > {
  $UniversalPricingDimensionRulesTableManager(
    _$PricingDatabase db,
    UniversalPricingDimensionRules table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $UniversalPricingDimensionRulesFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $UniversalPricingDimensionRulesOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $UniversalPricingDimensionRulesAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> businessId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> productId = const Value.absent(),
                Value<String> fieldId = const Value.absent(),
                Value<String> snapshotJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UniversalPricingDimensionRulesCompanion(
                businessId: businessId,
                profileId: profileId,
                version: version,
                productId: productId,
                fieldId: fieldId,
                snapshotJson: snapshotJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String businessId,
                required String profileId,
                required int version,
                required String productId,
                required String fieldId,
                required String snapshotJson,
                Value<int> rowid = const Value.absent(),
              }) => UniversalPricingDimensionRulesCompanion.insert(
                businessId: businessId,
                profileId: profileId,
                version: version,
                productId: productId,
                fieldId: fieldId,
                snapshotJson: snapshotJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    UniversalPricingDimensionRules,
                    UniversalPricingDimensionRule
                  >(table),
                  BaseReferences<
                    _$PricingDatabase,
                    UniversalPricingDimensionRules,
                    UniversalPricingDimensionRule
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $UniversalPricingDimensionRulesProcessedTableManager =
    ProcessedTableManager<
      _$PricingDatabase,
      UniversalPricingDimensionRules,
      UniversalPricingDimensionRule,
      $UniversalPricingDimensionRulesFilterComposer,
      $UniversalPricingDimensionRulesOrderingComposer,
      $UniversalPricingDimensionRulesAnnotationComposer,
      $UniversalPricingDimensionRulesCreateCompanionBuilder,
      $UniversalPricingDimensionRulesUpdateCompanionBuilder,
      (
        UniversalPricingDimensionRule,
        BaseReferences<
          _$PricingDatabase,
          UniversalPricingDimensionRules,
          UniversalPricingDimensionRule
        >,
      ),
      UniversalPricingDimensionRule,
      PrefetchHooks Function()
    >;
typedef $UniversalPricingAddonsCreateCompanionBuilder =
    UniversalPricingAddonsCompanion Function({
      required String businessId,
      required String profileId,
      required int version,
      required String productId,
      required String id,
      required String snapshotJson,
      Value<int> rowid,
    });
typedef $UniversalPricingAddonsUpdateCompanionBuilder =
    UniversalPricingAddonsCompanion Function({
      Value<String> businessId,
      Value<String> profileId,
      Value<int> version,
      Value<String> productId,
      Value<String> id,
      Value<String> snapshotJson,
      Value<int> rowid,
    });

class $UniversalPricingAddonsFilterComposer
    extends Composer<_$PricingDatabase, UniversalPricingAddons> {
  $UniversalPricingAddonsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $UniversalPricingAddonsOrderingComposer
    extends Composer<_$PricingDatabase, UniversalPricingAddons> {
  $UniversalPricingAddonsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $UniversalPricingAddonsAnnotationComposer
    extends Composer<_$PricingDatabase, UniversalPricingAddons> {
  $UniversalPricingAddonsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => column,
  );
}

class $UniversalPricingAddonsTableManager
    extends
        RootTableManager<
          _$PricingDatabase,
          UniversalPricingAddons,
          UniversalPricingAddon,
          $UniversalPricingAddonsFilterComposer,
          $UniversalPricingAddonsOrderingComposer,
          $UniversalPricingAddonsAnnotationComposer,
          $UniversalPricingAddonsCreateCompanionBuilder,
          $UniversalPricingAddonsUpdateCompanionBuilder,
          (
            UniversalPricingAddon,
            BaseReferences<
              _$PricingDatabase,
              UniversalPricingAddons,
              UniversalPricingAddon
            >,
          ),
          UniversalPricingAddon,
          PrefetchHooks Function()
        > {
  $UniversalPricingAddonsTableManager(
    _$PricingDatabase db,
    UniversalPricingAddons table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $UniversalPricingAddonsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $UniversalPricingAddonsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $UniversalPricingAddonsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> businessId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> productId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> snapshotJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UniversalPricingAddonsCompanion(
                businessId: businessId,
                profileId: profileId,
                version: version,
                productId: productId,
                id: id,
                snapshotJson: snapshotJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String businessId,
                required String profileId,
                required int version,
                required String productId,
                required String id,
                required String snapshotJson,
                Value<int> rowid = const Value.absent(),
              }) => UniversalPricingAddonsCompanion.insert(
                businessId: businessId,
                profileId: profileId,
                version: version,
                productId: productId,
                id: id,
                snapshotJson: snapshotJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<UniversalPricingAddons, UniversalPricingAddon>(
                    table,
                  ),
                  BaseReferences<
                    _$PricingDatabase,
                    UniversalPricingAddons,
                    UniversalPricingAddon
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $UniversalPricingAddonsProcessedTableManager =
    ProcessedTableManager<
      _$PricingDatabase,
      UniversalPricingAddons,
      UniversalPricingAddon,
      $UniversalPricingAddonsFilterComposer,
      $UniversalPricingAddonsOrderingComposer,
      $UniversalPricingAddonsAnnotationComposer,
      $UniversalPricingAddonsCreateCompanionBuilder,
      $UniversalPricingAddonsUpdateCompanionBuilder,
      (
        UniversalPricingAddon,
        BaseReferences<
          _$PricingDatabase,
          UniversalPricingAddons,
          UniversalPricingAddon
        >,
      ),
      UniversalPricingAddon,
      PrefetchHooks Function()
    >;
typedef $UniversalPricingAuditEventsCreateCompanionBuilder =
    UniversalPricingAuditEventsCompanion Function({
      Value<int> id,
      required String businessId,
      required String actorUid,
      required String action,
      required String profileId,
      Value<String?> beforeSnapshot,
      required String afterSnapshot,
      required int createdAt,
    });
typedef $UniversalPricingAuditEventsUpdateCompanionBuilder =
    UniversalPricingAuditEventsCompanion Function({
      Value<int> id,
      Value<String> businessId,
      Value<String> actorUid,
      Value<String> action,
      Value<String> profileId,
      Value<String?> beforeSnapshot,
      Value<String> afterSnapshot,
      Value<int> createdAt,
    });

class $UniversalPricingAuditEventsFilterComposer
    extends Composer<_$PricingDatabase, UniversalPricingAuditEvents> {
  $UniversalPricingAuditEventsFilterComposer({
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

  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorUid => $composableBuilder(
    column: $table.actorUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get beforeSnapshot => $composableBuilder(
    column: $table.beforeSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get afterSnapshot => $composableBuilder(
    column: $table.afterSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $UniversalPricingAuditEventsOrderingComposer
    extends Composer<_$PricingDatabase, UniversalPricingAuditEvents> {
  $UniversalPricingAuditEventsOrderingComposer({
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

  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorUid => $composableBuilder(
    column: $table.actorUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get beforeSnapshot => $composableBuilder(
    column: $table.beforeSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get afterSnapshot => $composableBuilder(
    column: $table.afterSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $UniversalPricingAuditEventsAnnotationComposer
    extends Composer<_$PricingDatabase, UniversalPricingAuditEvents> {
  $UniversalPricingAuditEventsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actorUid =>
      $composableBuilder(column: $table.actorUid, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get beforeSnapshot => $composableBuilder(
    column: $table.beforeSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get afterSnapshot => $composableBuilder(
    column: $table.afterSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $UniversalPricingAuditEventsTableManager
    extends
        RootTableManager<
          _$PricingDatabase,
          UniversalPricingAuditEvents,
          UniversalPricingAuditEvent,
          $UniversalPricingAuditEventsFilterComposer,
          $UniversalPricingAuditEventsOrderingComposer,
          $UniversalPricingAuditEventsAnnotationComposer,
          $UniversalPricingAuditEventsCreateCompanionBuilder,
          $UniversalPricingAuditEventsUpdateCompanionBuilder,
          (
            UniversalPricingAuditEvent,
            BaseReferences<
              _$PricingDatabase,
              UniversalPricingAuditEvents,
              UniversalPricingAuditEvent
            >,
          ),
          UniversalPricingAuditEvent,
          PrefetchHooks Function()
        > {
  $UniversalPricingAuditEventsTableManager(
    _$PricingDatabase db,
    UniversalPricingAuditEvents table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $UniversalPricingAuditEventsFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $UniversalPricingAuditEventsOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $UniversalPricingAuditEventsAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> businessId = const Value.absent(),
                Value<String> actorUid = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String?> beforeSnapshot = const Value.absent(),
                Value<String> afterSnapshot = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => UniversalPricingAuditEventsCompanion(
                id: id,
                businessId: businessId,
                actorUid: actorUid,
                action: action,
                profileId: profileId,
                beforeSnapshot: beforeSnapshot,
                afterSnapshot: afterSnapshot,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String businessId,
                required String actorUid,
                required String action,
                required String profileId,
                Value<String?> beforeSnapshot = const Value.absent(),
                required String afterSnapshot,
                required int createdAt,
              }) => UniversalPricingAuditEventsCompanion.insert(
                id: id,
                businessId: businessId,
                actorUid: actorUid,
                action: action,
                profileId: profileId,
                beforeSnapshot: beforeSnapshot,
                afterSnapshot: afterSnapshot,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    UniversalPricingAuditEvents,
                    UniversalPricingAuditEvent
                  >(table),
                  BaseReferences<
                    _$PricingDatabase,
                    UniversalPricingAuditEvents,
                    UniversalPricingAuditEvent
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $UniversalPricingAuditEventsProcessedTableManager =
    ProcessedTableManager<
      _$PricingDatabase,
      UniversalPricingAuditEvents,
      UniversalPricingAuditEvent,
      $UniversalPricingAuditEventsFilterComposer,
      $UniversalPricingAuditEventsOrderingComposer,
      $UniversalPricingAuditEventsAnnotationComposer,
      $UniversalPricingAuditEventsCreateCompanionBuilder,
      $UniversalPricingAuditEventsUpdateCompanionBuilder,
      (
        UniversalPricingAuditEvent,
        BaseReferences<
          _$PricingDatabase,
          UniversalPricingAuditEvents,
          UniversalPricingAuditEvent
        >,
      ),
      UniversalPricingAuditEvent,
      PrefetchHooks Function()
    >;
typedef $PricingDeviceWorkspaceCreateCompanionBuilder =
    PricingDeviceWorkspaceCompanion Function({
      Value<int> singleton,
      required String businessId,
      required int createdAt,
    });
typedef $PricingDeviceWorkspaceUpdateCompanionBuilder =
    PricingDeviceWorkspaceCompanion Function({
      Value<int> singleton,
      Value<String> businessId,
      Value<int> createdAt,
    });

class $PricingDeviceWorkspaceFilterComposer
    extends Composer<_$PricingDatabase, PricingDeviceWorkspace> {
  $PricingDeviceWorkspaceFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get singleton => $composableBuilder(
    column: $table.singleton,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $PricingDeviceWorkspaceOrderingComposer
    extends Composer<_$PricingDatabase, PricingDeviceWorkspace> {
  $PricingDeviceWorkspaceOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get singleton => $composableBuilder(
    column: $table.singleton,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $PricingDeviceWorkspaceAnnotationComposer
    extends Composer<_$PricingDatabase, PricingDeviceWorkspace> {
  $PricingDeviceWorkspaceAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get singleton =>
      $composableBuilder(column: $table.singleton, builder: (column) => column);

  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $PricingDeviceWorkspaceTableManager
    extends
        RootTableManager<
          _$PricingDatabase,
          PricingDeviceWorkspace,
          PricingDeviceWorkspaceData,
          $PricingDeviceWorkspaceFilterComposer,
          $PricingDeviceWorkspaceOrderingComposer,
          $PricingDeviceWorkspaceAnnotationComposer,
          $PricingDeviceWorkspaceCreateCompanionBuilder,
          $PricingDeviceWorkspaceUpdateCompanionBuilder,
          (
            PricingDeviceWorkspaceData,
            BaseReferences<
              _$PricingDatabase,
              PricingDeviceWorkspace,
              PricingDeviceWorkspaceData
            >,
          ),
          PricingDeviceWorkspaceData,
          PrefetchHooks Function()
        > {
  $PricingDeviceWorkspaceTableManager(
    _$PricingDatabase db,
    PricingDeviceWorkspace table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $PricingDeviceWorkspaceFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $PricingDeviceWorkspaceOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $PricingDeviceWorkspaceAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> singleton = const Value.absent(),
                Value<String> businessId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => PricingDeviceWorkspaceCompanion(
                singleton: singleton,
                businessId: businessId,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> singleton = const Value.absent(),
                required String businessId,
                required int createdAt,
              }) => PricingDeviceWorkspaceCompanion.insert(
                singleton: singleton,
                businessId: businessId,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    PricingDeviceWorkspace,
                    PricingDeviceWorkspaceData
                  >(table),
                  BaseReferences<
                    _$PricingDatabase,
                    PricingDeviceWorkspace,
                    PricingDeviceWorkspaceData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $PricingDeviceWorkspaceProcessedTableManager =
    ProcessedTableManager<
      _$PricingDatabase,
      PricingDeviceWorkspace,
      PricingDeviceWorkspaceData,
      $PricingDeviceWorkspaceFilterComposer,
      $PricingDeviceWorkspaceOrderingComposer,
      $PricingDeviceWorkspaceAnnotationComposer,
      $PricingDeviceWorkspaceCreateCompanionBuilder,
      $PricingDeviceWorkspaceUpdateCompanionBuilder,
      (
        PricingDeviceWorkspaceData,
        BaseReferences<
          _$PricingDatabase,
          PricingDeviceWorkspace,
          PricingDeviceWorkspaceData
        >,
      ),
      PricingDeviceWorkspaceData,
      PrefetchHooks Function()
    >;
typedef $PricingWorkspaceValuesCreateCompanionBuilder =
    PricingWorkspaceValuesCompanion Function({
      required String businessId,
      required String id,
      required String snapshotJson,
      Value<int> rowid,
    });
typedef $PricingWorkspaceValuesUpdateCompanionBuilder =
    PricingWorkspaceValuesCompanion Function({
      Value<String> businessId,
      Value<String> id,
      Value<String> snapshotJson,
      Value<int> rowid,
    });

class $PricingWorkspaceValuesFilterComposer
    extends Composer<_$PricingDatabase, PricingWorkspaceValues> {
  $PricingWorkspaceValuesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $PricingWorkspaceValuesOrderingComposer
    extends Composer<_$PricingDatabase, PricingWorkspaceValues> {
  $PricingWorkspaceValuesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $PricingWorkspaceValuesAnnotationComposer
    extends Composer<_$PricingDatabase, PricingWorkspaceValues> {
  $PricingWorkspaceValuesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => column,
  );
}

class $PricingWorkspaceValuesTableManager
    extends
        RootTableManager<
          _$PricingDatabase,
          PricingWorkspaceValues,
          PricingWorkspaceValue,
          $PricingWorkspaceValuesFilterComposer,
          $PricingWorkspaceValuesOrderingComposer,
          $PricingWorkspaceValuesAnnotationComposer,
          $PricingWorkspaceValuesCreateCompanionBuilder,
          $PricingWorkspaceValuesUpdateCompanionBuilder,
          (
            PricingWorkspaceValue,
            BaseReferences<
              _$PricingDatabase,
              PricingWorkspaceValues,
              PricingWorkspaceValue
            >,
          ),
          PricingWorkspaceValue,
          PrefetchHooks Function()
        > {
  $PricingWorkspaceValuesTableManager(
    _$PricingDatabase db,
    PricingWorkspaceValues table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $PricingWorkspaceValuesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $PricingWorkspaceValuesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $PricingWorkspaceValuesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> businessId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> snapshotJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PricingWorkspaceValuesCompanion(
                businessId: businessId,
                id: id,
                snapshotJson: snapshotJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String businessId,
                required String id,
                required String snapshotJson,
                Value<int> rowid = const Value.absent(),
              }) => PricingWorkspaceValuesCompanion.insert(
                businessId: businessId,
                id: id,
                snapshotJson: snapshotJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<PricingWorkspaceValues, PricingWorkspaceValue>(
                    table,
                  ),
                  BaseReferences<
                    _$PricingDatabase,
                    PricingWorkspaceValues,
                    PricingWorkspaceValue
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $PricingWorkspaceValuesProcessedTableManager =
    ProcessedTableManager<
      _$PricingDatabase,
      PricingWorkspaceValues,
      PricingWorkspaceValue,
      $PricingWorkspaceValuesFilterComposer,
      $PricingWorkspaceValuesOrderingComposer,
      $PricingWorkspaceValuesAnnotationComposer,
      $PricingWorkspaceValuesCreateCompanionBuilder,
      $PricingWorkspaceValuesUpdateCompanionBuilder,
      (
        PricingWorkspaceValue,
        BaseReferences<
          _$PricingDatabase,
          PricingWorkspaceValues,
          PricingWorkspaceValue
        >,
      ),
      PricingWorkspaceValue,
      PrefetchHooks Function()
    >;
typedef $PricingLocalTaxApprovalsCreateCompanionBuilder =
    PricingLocalTaxApprovalsCompanion Function({
      required String businessId,
      required String policyJson,
      required int approvedAt,
      Value<int> rowid,
    });
typedef $PricingLocalTaxApprovalsUpdateCompanionBuilder =
    PricingLocalTaxApprovalsCompanion Function({
      Value<String> businessId,
      Value<String> policyJson,
      Value<int> approvedAt,
      Value<int> rowid,
    });

class $PricingLocalTaxApprovalsFilterComposer
    extends Composer<_$PricingDatabase, PricingLocalTaxApprovals> {
  $PricingLocalTaxApprovalsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get policyJson => $composableBuilder(
    column: $table.policyJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get approvedAt => $composableBuilder(
    column: $table.approvedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $PricingLocalTaxApprovalsOrderingComposer
    extends Composer<_$PricingDatabase, PricingLocalTaxApprovals> {
  $PricingLocalTaxApprovalsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get policyJson => $composableBuilder(
    column: $table.policyJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get approvedAt => $composableBuilder(
    column: $table.approvedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $PricingLocalTaxApprovalsAnnotationComposer
    extends Composer<_$PricingDatabase, PricingLocalTaxApprovals> {
  $PricingLocalTaxApprovalsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get policyJson => $composableBuilder(
    column: $table.policyJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get approvedAt => $composableBuilder(
    column: $table.approvedAt,
    builder: (column) => column,
  );
}

class $PricingLocalTaxApprovalsTableManager
    extends
        RootTableManager<
          _$PricingDatabase,
          PricingLocalTaxApprovals,
          PricingLocalTaxApproval,
          $PricingLocalTaxApprovalsFilterComposer,
          $PricingLocalTaxApprovalsOrderingComposer,
          $PricingLocalTaxApprovalsAnnotationComposer,
          $PricingLocalTaxApprovalsCreateCompanionBuilder,
          $PricingLocalTaxApprovalsUpdateCompanionBuilder,
          (
            PricingLocalTaxApproval,
            BaseReferences<
              _$PricingDatabase,
              PricingLocalTaxApprovals,
              PricingLocalTaxApproval
            >,
          ),
          PricingLocalTaxApproval,
          PrefetchHooks Function()
        > {
  $PricingLocalTaxApprovalsTableManager(
    _$PricingDatabase db,
    PricingLocalTaxApprovals table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $PricingLocalTaxApprovalsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $PricingLocalTaxApprovalsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $PricingLocalTaxApprovalsAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> businessId = const Value.absent(),
                Value<String> policyJson = const Value.absent(),
                Value<int> approvedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PricingLocalTaxApprovalsCompanion(
                businessId: businessId,
                policyJson: policyJson,
                approvedAt: approvedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String businessId,
                required String policyJson,
                required int approvedAt,
                Value<int> rowid = const Value.absent(),
              }) => PricingLocalTaxApprovalsCompanion.insert(
                businessId: businessId,
                policyJson: policyJson,
                approvedAt: approvedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    PricingLocalTaxApprovals,
                    PricingLocalTaxApproval
                  >(table),
                  BaseReferences<
                    _$PricingDatabase,
                    PricingLocalTaxApprovals,
                    PricingLocalTaxApproval
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $PricingLocalTaxApprovalsProcessedTableManager =
    ProcessedTableManager<
      _$PricingDatabase,
      PricingLocalTaxApprovals,
      PricingLocalTaxApproval,
      $PricingLocalTaxApprovalsFilterComposer,
      $PricingLocalTaxApprovalsOrderingComposer,
      $PricingLocalTaxApprovalsAnnotationComposer,
      $PricingLocalTaxApprovalsCreateCompanionBuilder,
      $PricingLocalTaxApprovalsUpdateCompanionBuilder,
      (
        PricingLocalTaxApproval,
        BaseReferences<
          _$PricingDatabase,
          PricingLocalTaxApprovals,
          PricingLocalTaxApproval
        >,
      ),
      PricingLocalTaxApproval,
      PrefetchHooks Function()
    >;

class $PricingDatabaseManager {
  final _$PricingDatabase _db;
  $PricingDatabaseManager(this._db);
  $PricingProfilesTableManager get pricingProfiles =>
      $PricingProfilesTableManager(_db, _db.pricingProfiles);
  $PricingDraftsTableManager get pricingDrafts =>
      $PricingDraftsTableManager(_db, _db.pricingDrafts);
  $PricingRateCardVersionsTableManager get pricingRateCardVersions =>
      $PricingRateCardVersionsTableManager(_db, _db.pricingRateCardVersions);
  $PricingCategoriesTableManager get pricingCategories =>
      $PricingCategoriesTableManager(_db, _db.pricingCategories);
  $PricingVariantsTableManager get pricingVariants =>
      $PricingVariantsTableManager(_db, _db.pricingVariants);
  $PricingRuleVersionsTableManager get pricingRuleVersions =>
      $PricingRuleVersionsTableManager(_db, _db.pricingRuleVersions);
  $PricingAddonsTableManager get pricingAddons =>
      $PricingAddonsTableManager(_db, _db.pricingAddons);
  $PricingRuleAddonsTableManager get pricingRuleAddons =>
      $PricingRuleAddonsTableManager(_db, _db.pricingRuleAddons);
  $PricingAuditEventsTableManager get pricingAuditEvents =>
      $PricingAuditEventsTableManager(_db, _db.pricingAuditEvents);
  $UniversalPricingProfilesTableManager get universalPricingProfiles =>
      $UniversalPricingProfilesTableManager(_db, _db.universalPricingProfiles);
  $UniversalPricingDraftsTableManager get universalPricingDrafts =>
      $UniversalPricingDraftsTableManager(_db, _db.universalPricingDrafts);
  $UniversalPricingVersionsTableManager get universalPricingVersions =>
      $UniversalPricingVersionsTableManager(_db, _db.universalPricingVersions);
  $UniversalPricingCategoriesTableManager get universalPricingCategories =>
      $UniversalPricingCategoriesTableManager(
        _db,
        _db.universalPricingCategories,
      );
  $UniversalPricingProductsTableManager get universalPricingProducts =>
      $UniversalPricingProductsTableManager(_db, _db.universalPricingProducts);
  $UniversalPricingInputsTableManager get universalPricingInputs =>
      $UniversalPricingInputsTableManager(_db, _db.universalPricingInputs);
  $UniversalPricingRatesTableManager get universalPricingRates =>
      $UniversalPricingRatesTableManager(_db, _db.universalPricingRates);
  $UniversalPricingUnitSystemsTableManager get universalPricingUnitSystems =>
      $UniversalPricingUnitSystemsTableManager(
        _db,
        _db.universalPricingUnitSystems,
      );
  $UniversalPricingDimensionRulesTableManager
  get universalPricingDimensionRules =>
      $UniversalPricingDimensionRulesTableManager(
        _db,
        _db.universalPricingDimensionRules,
      );
  $UniversalPricingAddonsTableManager get universalPricingAddons =>
      $UniversalPricingAddonsTableManager(_db, _db.universalPricingAddons);
  $UniversalPricingAuditEventsTableManager get universalPricingAuditEvents =>
      $UniversalPricingAuditEventsTableManager(
        _db,
        _db.universalPricingAuditEvents,
      );
  $PricingDeviceWorkspaceTableManager get pricingDeviceWorkspace =>
      $PricingDeviceWorkspaceTableManager(_db, _db.pricingDeviceWorkspace);
  $PricingWorkspaceValuesTableManager get pricingWorkspaceValues =>
      $PricingWorkspaceValuesTableManager(_db, _db.pricingWorkspaceValues);
  $PricingLocalTaxApprovalsTableManager get pricingLocalTaxApprovals =>
      $PricingLocalTaxApprovalsTableManager(_db, _db.pricingLocalTaxApprovals);
}
