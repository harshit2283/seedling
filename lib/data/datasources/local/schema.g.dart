// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schema.dart';

// ignore_for_file: type=lint
class $EntriesTable extends Entries with TableInfo<$EntriesTable, EntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntriesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeIndexMeta = const VerificationMeta(
    'typeIndex',
  );
  @override
  late final GeneratedColumn<int> typeIndex = GeneratedColumn<int>(
    'type_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _textContentMeta = const VerificationMeta(
    'textContent',
  );
  @override
  late final GeneratedColumn<String> textContent = GeneratedColumn<String>(
    'text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaPathMeta = const VerificationMeta(
    'mediaPath',
  );
  @override
  late final GeneratedColumn<String> mediaPath = GeneratedColumn<String>(
    'media_path',
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contextMeta = const VerificationMeta(
    'context',
  );
  @override
  late final GeneratedColumn<String> context = GeneratedColumn<String>(
    'context',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _moodMeta = const VerificationMeta('mood');
  @override
  late final GeneratedColumn<String> mood = GeneratedColumn<String>(
    'mood',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isReleasedMeta = const VerificationMeta(
    'isReleased',
  );
  @override
  late final GeneratedColumn<bool> isReleased = GeneratedColumn<bool>(
    'is_released',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_released" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detectedThemeMeta = const VerificationMeta(
    'detectedTheme',
  );
  @override
  late final GeneratedColumn<String> detectedTheme = GeneratedColumn<String>(
    'detected_theme',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _manualLinkIdsMeta = const VerificationMeta(
    'manualLinkIds',
  );
  @override
  late final GeneratedColumn<String> manualLinkIds = GeneratedColumn<String>(
    'manual_link_ids',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _capsuleUnlockDateMeta = const VerificationMeta(
    'capsuleUnlockDate',
  );
  @override
  late final GeneratedColumn<int> capsuleUnlockDate = GeneratedColumn<int>(
    'capsule_unlock_date',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transcriptionMeta = const VerificationMeta(
    'transcription',
  );
  @override
  late final GeneratedColumn<String> transcription = GeneratedColumn<String>(
    'transcription',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncUuidMeta = const VerificationMeta(
    'syncUuid',
  );
  @override
  late final GeneratedColumn<String> syncUuid = GeneratedColumn<String>(
    'sync_uuid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _modifiedAtMeta = const VerificationMeta(
    'modifiedAt',
  );
  @override
  late final GeneratedColumn<int> modifiedAt = GeneratedColumn<int>(
    'modified_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaAssetIdMeta = const VerificationMeta(
    'mediaAssetId',
  );
  @override
  late final GeneratedColumn<String> mediaAssetId = GeneratedColumn<String>(
    'media_asset_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaKeyMeta = const VerificationMeta(
    'mediaKey',
  );
  @override
  late final GeneratedColumn<String> mediaKey = GeneratedColumn<String>(
    'media_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    typeIndex,
    textContent,
    mediaPath,
    title,
    context,
    mood,
    tags,
    isReleased,
    isDeleted,
    deletedAt,
    detectedTheme,
    manualLinkIds,
    capsuleUnlockDate,
    transcription,
    syncUuid,
    modifiedAt,
    deviceId,
    mediaAssetId,
    mediaKey,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<EntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('type_index')) {
      context.handle(
        _typeIndexMeta,
        typeIndex.isAcceptableOrUnknown(data['type_index']!, _typeIndexMeta),
      );
    }
    if (data.containsKey('text')) {
      context.handle(
        _textContentMeta,
        textContent.isAcceptableOrUnknown(data['text']!, _textContentMeta),
      );
    }
    if (data.containsKey('media_path')) {
      context.handle(
        _mediaPathMeta,
        mediaPath.isAcceptableOrUnknown(data['media_path']!, _mediaPathMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('context')) {
      context.handle(
        _contextMeta,
        this.context.isAcceptableOrUnknown(data['context']!, _contextMeta),
      );
    }
    if (data.containsKey('mood')) {
      context.handle(
        _moodMeta,
        mood.isAcceptableOrUnknown(data['mood']!, _moodMeta),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('is_released')) {
      context.handle(
        _isReleasedMeta,
        isReleased.isAcceptableOrUnknown(data['is_released']!, _isReleasedMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('detected_theme')) {
      context.handle(
        _detectedThemeMeta,
        detectedTheme.isAcceptableOrUnknown(
          data['detected_theme']!,
          _detectedThemeMeta,
        ),
      );
    }
    if (data.containsKey('manual_link_ids')) {
      context.handle(
        _manualLinkIdsMeta,
        manualLinkIds.isAcceptableOrUnknown(
          data['manual_link_ids']!,
          _manualLinkIdsMeta,
        ),
      );
    }
    if (data.containsKey('capsule_unlock_date')) {
      context.handle(
        _capsuleUnlockDateMeta,
        capsuleUnlockDate.isAcceptableOrUnknown(
          data['capsule_unlock_date']!,
          _capsuleUnlockDateMeta,
        ),
      );
    }
    if (data.containsKey('transcription')) {
      context.handle(
        _transcriptionMeta,
        transcription.isAcceptableOrUnknown(
          data['transcription']!,
          _transcriptionMeta,
        ),
      );
    }
    if (data.containsKey('sync_uuid')) {
      context.handle(
        _syncUuidMeta,
        syncUuid.isAcceptableOrUnknown(data['sync_uuid']!, _syncUuidMeta),
      );
    }
    if (data.containsKey('modified_at')) {
      context.handle(
        _modifiedAtMeta,
        modifiedAt.isAcceptableOrUnknown(data['modified_at']!, _modifiedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('media_asset_id')) {
      context.handle(
        _mediaAssetIdMeta,
        mediaAssetId.isAcceptableOrUnknown(
          data['media_asset_id']!,
          _mediaAssetIdMeta,
        ),
      );
    }
    if (data.containsKey('media_key')) {
      context.handle(
        _mediaKeyMeta,
        mediaKey.isAcceptableOrUnknown(data['media_key']!, _mediaKeyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      typeIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type_index'],
      )!,
      textContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      ),
      mediaPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_path'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      context: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}context'],
      ),
      mood: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mood'],
      ),
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      ),
      isReleased: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_released'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      detectedTheme: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detected_theme'],
      ),
      manualLinkIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manual_link_ids'],
      ),
      capsuleUnlockDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}capsule_unlock_date'],
      ),
      transcription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcription'],
      ),
      syncUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_uuid'],
      ),
      modifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}modified_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      ),
      mediaAssetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_asset_id'],
      ),
      mediaKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_key'],
      ),
    );
  }

  @override
  $EntriesTable createAlias(String alias) {
    return $EntriesTable(attachedDatabase, alias);
  }
}

class EntryRow extends DataClass implements Insertable<EntryRow> {
  final int id;
  final int createdAt;
  final int typeIndex;
  final String? textContent;
  final String? mediaPath;
  final String? title;
  final String? context;
  final String? mood;
  final String? tags;
  final bool isReleased;
  final bool isDeleted;
  final int? deletedAt;
  final String? detectedTheme;
  final String? manualLinkIds;
  final int? capsuleUnlockDate;
  final String? transcription;
  final String? syncUuid;
  final int? modifiedAt;
  final String? deviceId;
  final String? mediaAssetId;
  final String? mediaKey;
  const EntryRow({
    required this.id,
    required this.createdAt,
    required this.typeIndex,
    this.textContent,
    this.mediaPath,
    this.title,
    this.context,
    this.mood,
    this.tags,
    required this.isReleased,
    required this.isDeleted,
    this.deletedAt,
    this.detectedTheme,
    this.manualLinkIds,
    this.capsuleUnlockDate,
    this.transcription,
    this.syncUuid,
    this.modifiedAt,
    this.deviceId,
    this.mediaAssetId,
    this.mediaKey,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['type_index'] = Variable<int>(typeIndex);
    if (!nullToAbsent || textContent != null) {
      map['text'] = Variable<String>(textContent);
    }
    if (!nullToAbsent || mediaPath != null) {
      map['media_path'] = Variable<String>(mediaPath);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || context != null) {
      map['context'] = Variable<String>(context);
    }
    if (!nullToAbsent || mood != null) {
      map['mood'] = Variable<String>(mood);
    }
    if (!nullToAbsent || tags != null) {
      map['tags'] = Variable<String>(tags);
    }
    map['is_released'] = Variable<bool>(isReleased);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    if (!nullToAbsent || detectedTheme != null) {
      map['detected_theme'] = Variable<String>(detectedTheme);
    }
    if (!nullToAbsent || manualLinkIds != null) {
      map['manual_link_ids'] = Variable<String>(manualLinkIds);
    }
    if (!nullToAbsent || capsuleUnlockDate != null) {
      map['capsule_unlock_date'] = Variable<int>(capsuleUnlockDate);
    }
    if (!nullToAbsent || transcription != null) {
      map['transcription'] = Variable<String>(transcription);
    }
    if (!nullToAbsent || syncUuid != null) {
      map['sync_uuid'] = Variable<String>(syncUuid);
    }
    if (!nullToAbsent || modifiedAt != null) {
      map['modified_at'] = Variable<int>(modifiedAt);
    }
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    if (!nullToAbsent || mediaAssetId != null) {
      map['media_asset_id'] = Variable<String>(mediaAssetId);
    }
    if (!nullToAbsent || mediaKey != null) {
      map['media_key'] = Variable<String>(mediaKey);
    }
    return map;
  }

  EntriesCompanion toCompanion(bool nullToAbsent) {
    return EntriesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      typeIndex: Value(typeIndex),
      textContent: textContent == null && nullToAbsent
          ? const Value.absent()
          : Value(textContent),
      mediaPath: mediaPath == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaPath),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      context: context == null && nullToAbsent
          ? const Value.absent()
          : Value(context),
      mood: mood == null && nullToAbsent ? const Value.absent() : Value(mood),
      tags: tags == null && nullToAbsent ? const Value.absent() : Value(tags),
      isReleased: Value(isReleased),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      detectedTheme: detectedTheme == null && nullToAbsent
          ? const Value.absent()
          : Value(detectedTheme),
      manualLinkIds: manualLinkIds == null && nullToAbsent
          ? const Value.absent()
          : Value(manualLinkIds),
      capsuleUnlockDate: capsuleUnlockDate == null && nullToAbsent
          ? const Value.absent()
          : Value(capsuleUnlockDate),
      transcription: transcription == null && nullToAbsent
          ? const Value.absent()
          : Value(transcription),
      syncUuid: syncUuid == null && nullToAbsent
          ? const Value.absent()
          : Value(syncUuid),
      modifiedAt: modifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(modifiedAt),
      deviceId: deviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceId),
      mediaAssetId: mediaAssetId == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaAssetId),
      mediaKey: mediaKey == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaKey),
    );
  }

  factory EntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntryRow(
      id: serializer.fromJson<int>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      typeIndex: serializer.fromJson<int>(json['typeIndex']),
      textContent: serializer.fromJson<String?>(json['textContent']),
      mediaPath: serializer.fromJson<String?>(json['mediaPath']),
      title: serializer.fromJson<String?>(json['title']),
      context: serializer.fromJson<String?>(json['context']),
      mood: serializer.fromJson<String?>(json['mood']),
      tags: serializer.fromJson<String?>(json['tags']),
      isReleased: serializer.fromJson<bool>(json['isReleased']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      detectedTheme: serializer.fromJson<String?>(json['detectedTheme']),
      manualLinkIds: serializer.fromJson<String?>(json['manualLinkIds']),
      capsuleUnlockDate: serializer.fromJson<int?>(json['capsuleUnlockDate']),
      transcription: serializer.fromJson<String?>(json['transcription']),
      syncUuid: serializer.fromJson<String?>(json['syncUuid']),
      modifiedAt: serializer.fromJson<int?>(json['modifiedAt']),
      deviceId: serializer.fromJson<String?>(json['deviceId']),
      mediaAssetId: serializer.fromJson<String?>(json['mediaAssetId']),
      mediaKey: serializer.fromJson<String?>(json['mediaKey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'typeIndex': serializer.toJson<int>(typeIndex),
      'textContent': serializer.toJson<String?>(textContent),
      'mediaPath': serializer.toJson<String?>(mediaPath),
      'title': serializer.toJson<String?>(title),
      'context': serializer.toJson<String?>(context),
      'mood': serializer.toJson<String?>(mood),
      'tags': serializer.toJson<String?>(tags),
      'isReleased': serializer.toJson<bool>(isReleased),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'detectedTheme': serializer.toJson<String?>(detectedTheme),
      'manualLinkIds': serializer.toJson<String?>(manualLinkIds),
      'capsuleUnlockDate': serializer.toJson<int?>(capsuleUnlockDate),
      'transcription': serializer.toJson<String?>(transcription),
      'syncUuid': serializer.toJson<String?>(syncUuid),
      'modifiedAt': serializer.toJson<int?>(modifiedAt),
      'deviceId': serializer.toJson<String?>(deviceId),
      'mediaAssetId': serializer.toJson<String?>(mediaAssetId),
      'mediaKey': serializer.toJson<String?>(mediaKey),
    };
  }

  EntryRow copyWith({
    int? id,
    int? createdAt,
    int? typeIndex,
    Value<String?> textContent = const Value.absent(),
    Value<String?> mediaPath = const Value.absent(),
    Value<String?> title = const Value.absent(),
    Value<String?> context = const Value.absent(),
    Value<String?> mood = const Value.absent(),
    Value<String?> tags = const Value.absent(),
    bool? isReleased,
    bool? isDeleted,
    Value<int?> deletedAt = const Value.absent(),
    Value<String?> detectedTheme = const Value.absent(),
    Value<String?> manualLinkIds = const Value.absent(),
    Value<int?> capsuleUnlockDate = const Value.absent(),
    Value<String?> transcription = const Value.absent(),
    Value<String?> syncUuid = const Value.absent(),
    Value<int?> modifiedAt = const Value.absent(),
    Value<String?> deviceId = const Value.absent(),
    Value<String?> mediaAssetId = const Value.absent(),
    Value<String?> mediaKey = const Value.absent(),
  }) => EntryRow(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    typeIndex: typeIndex ?? this.typeIndex,
    textContent: textContent.present ? textContent.value : this.textContent,
    mediaPath: mediaPath.present ? mediaPath.value : this.mediaPath,
    title: title.present ? title.value : this.title,
    context: context.present ? context.value : this.context,
    mood: mood.present ? mood.value : this.mood,
    tags: tags.present ? tags.value : this.tags,
    isReleased: isReleased ?? this.isReleased,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    detectedTheme: detectedTheme.present
        ? detectedTheme.value
        : this.detectedTheme,
    manualLinkIds: manualLinkIds.present
        ? manualLinkIds.value
        : this.manualLinkIds,
    capsuleUnlockDate: capsuleUnlockDate.present
        ? capsuleUnlockDate.value
        : this.capsuleUnlockDate,
    transcription: transcription.present
        ? transcription.value
        : this.transcription,
    syncUuid: syncUuid.present ? syncUuid.value : this.syncUuid,
    modifiedAt: modifiedAt.present ? modifiedAt.value : this.modifiedAt,
    deviceId: deviceId.present ? deviceId.value : this.deviceId,
    mediaAssetId: mediaAssetId.present ? mediaAssetId.value : this.mediaAssetId,
    mediaKey: mediaKey.present ? mediaKey.value : this.mediaKey,
  );
  EntryRow copyWithCompanion(EntriesCompanion data) {
    return EntryRow(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      typeIndex: data.typeIndex.present ? data.typeIndex.value : this.typeIndex,
      textContent: data.textContent.present
          ? data.textContent.value
          : this.textContent,
      mediaPath: data.mediaPath.present ? data.mediaPath.value : this.mediaPath,
      title: data.title.present ? data.title.value : this.title,
      context: data.context.present ? data.context.value : this.context,
      mood: data.mood.present ? data.mood.value : this.mood,
      tags: data.tags.present ? data.tags.value : this.tags,
      isReleased: data.isReleased.present
          ? data.isReleased.value
          : this.isReleased,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      detectedTheme: data.detectedTheme.present
          ? data.detectedTheme.value
          : this.detectedTheme,
      manualLinkIds: data.manualLinkIds.present
          ? data.manualLinkIds.value
          : this.manualLinkIds,
      capsuleUnlockDate: data.capsuleUnlockDate.present
          ? data.capsuleUnlockDate.value
          : this.capsuleUnlockDate,
      transcription: data.transcription.present
          ? data.transcription.value
          : this.transcription,
      syncUuid: data.syncUuid.present ? data.syncUuid.value : this.syncUuid,
      modifiedAt: data.modifiedAt.present
          ? data.modifiedAt.value
          : this.modifiedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      mediaAssetId: data.mediaAssetId.present
          ? data.mediaAssetId.value
          : this.mediaAssetId,
      mediaKey: data.mediaKey.present ? data.mediaKey.value : this.mediaKey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntryRow(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('typeIndex: $typeIndex, ')
          ..write('textContent: $textContent, ')
          ..write('mediaPath: $mediaPath, ')
          ..write('title: $title, ')
          ..write('context: $context, ')
          ..write('mood: $mood, ')
          ..write('tags: $tags, ')
          ..write('isReleased: $isReleased, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('detectedTheme: $detectedTheme, ')
          ..write('manualLinkIds: $manualLinkIds, ')
          ..write('capsuleUnlockDate: $capsuleUnlockDate, ')
          ..write('transcription: $transcription, ')
          ..write('syncUuid: $syncUuid, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('mediaAssetId: $mediaAssetId, ')
          ..write('mediaKey: $mediaKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    createdAt,
    typeIndex,
    textContent,
    mediaPath,
    title,
    context,
    mood,
    tags,
    isReleased,
    isDeleted,
    deletedAt,
    detectedTheme,
    manualLinkIds,
    capsuleUnlockDate,
    transcription,
    syncUuid,
    modifiedAt,
    deviceId,
    mediaAssetId,
    mediaKey,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntryRow &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.typeIndex == this.typeIndex &&
          other.textContent == this.textContent &&
          other.mediaPath == this.mediaPath &&
          other.title == this.title &&
          other.context == this.context &&
          other.mood == this.mood &&
          other.tags == this.tags &&
          other.isReleased == this.isReleased &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt &&
          other.detectedTheme == this.detectedTheme &&
          other.manualLinkIds == this.manualLinkIds &&
          other.capsuleUnlockDate == this.capsuleUnlockDate &&
          other.transcription == this.transcription &&
          other.syncUuid == this.syncUuid &&
          other.modifiedAt == this.modifiedAt &&
          other.deviceId == this.deviceId &&
          other.mediaAssetId == this.mediaAssetId &&
          other.mediaKey == this.mediaKey);
}

class EntriesCompanion extends UpdateCompanion<EntryRow> {
  final Value<int> id;
  final Value<int> createdAt;
  final Value<int> typeIndex;
  final Value<String?> textContent;
  final Value<String?> mediaPath;
  final Value<String?> title;
  final Value<String?> context;
  final Value<String?> mood;
  final Value<String?> tags;
  final Value<bool> isReleased;
  final Value<bool> isDeleted;
  final Value<int?> deletedAt;
  final Value<String?> detectedTheme;
  final Value<String?> manualLinkIds;
  final Value<int?> capsuleUnlockDate;
  final Value<String?> transcription;
  final Value<String?> syncUuid;
  final Value<int?> modifiedAt;
  final Value<String?> deviceId;
  final Value<String?> mediaAssetId;
  final Value<String?> mediaKey;
  const EntriesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.typeIndex = const Value.absent(),
    this.textContent = const Value.absent(),
    this.mediaPath = const Value.absent(),
    this.title = const Value.absent(),
    this.context = const Value.absent(),
    this.mood = const Value.absent(),
    this.tags = const Value.absent(),
    this.isReleased = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.detectedTheme = const Value.absent(),
    this.manualLinkIds = const Value.absent(),
    this.capsuleUnlockDate = const Value.absent(),
    this.transcription = const Value.absent(),
    this.syncUuid = const Value.absent(),
    this.modifiedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.mediaAssetId = const Value.absent(),
    this.mediaKey = const Value.absent(),
  });
  EntriesCompanion.insert({
    this.id = const Value.absent(),
    required int createdAt,
    this.typeIndex = const Value.absent(),
    this.textContent = const Value.absent(),
    this.mediaPath = const Value.absent(),
    this.title = const Value.absent(),
    this.context = const Value.absent(),
    this.mood = const Value.absent(),
    this.tags = const Value.absent(),
    this.isReleased = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.detectedTheme = const Value.absent(),
    this.manualLinkIds = const Value.absent(),
    this.capsuleUnlockDate = const Value.absent(),
    this.transcription = const Value.absent(),
    this.syncUuid = const Value.absent(),
    this.modifiedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.mediaAssetId = const Value.absent(),
    this.mediaKey = const Value.absent(),
  }) : createdAt = Value(createdAt);
  static Insertable<EntryRow> custom({
    Expression<int>? id,
    Expression<int>? createdAt,
    Expression<int>? typeIndex,
    Expression<String>? textContent,
    Expression<String>? mediaPath,
    Expression<String>? title,
    Expression<String>? context,
    Expression<String>? mood,
    Expression<String>? tags,
    Expression<bool>? isReleased,
    Expression<bool>? isDeleted,
    Expression<int>? deletedAt,
    Expression<String>? detectedTheme,
    Expression<String>? manualLinkIds,
    Expression<int>? capsuleUnlockDate,
    Expression<String>? transcription,
    Expression<String>? syncUuid,
    Expression<int>? modifiedAt,
    Expression<String>? deviceId,
    Expression<String>? mediaAssetId,
    Expression<String>? mediaKey,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (typeIndex != null) 'type_index': typeIndex,
      if (textContent != null) 'text': textContent,
      if (mediaPath != null) 'media_path': mediaPath,
      if (title != null) 'title': title,
      if (context != null) 'context': context,
      if (mood != null) 'mood': mood,
      if (tags != null) 'tags': tags,
      if (isReleased != null) 'is_released': isReleased,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (detectedTheme != null) 'detected_theme': detectedTheme,
      if (manualLinkIds != null) 'manual_link_ids': manualLinkIds,
      if (capsuleUnlockDate != null) 'capsule_unlock_date': capsuleUnlockDate,
      if (transcription != null) 'transcription': transcription,
      if (syncUuid != null) 'sync_uuid': syncUuid,
      if (modifiedAt != null) 'modified_at': modifiedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (mediaAssetId != null) 'media_asset_id': mediaAssetId,
      if (mediaKey != null) 'media_key': mediaKey,
    });
  }

  EntriesCompanion copyWith({
    Value<int>? id,
    Value<int>? createdAt,
    Value<int>? typeIndex,
    Value<String?>? textContent,
    Value<String?>? mediaPath,
    Value<String?>? title,
    Value<String?>? context,
    Value<String?>? mood,
    Value<String?>? tags,
    Value<bool>? isReleased,
    Value<bool>? isDeleted,
    Value<int?>? deletedAt,
    Value<String?>? detectedTheme,
    Value<String?>? manualLinkIds,
    Value<int?>? capsuleUnlockDate,
    Value<String?>? transcription,
    Value<String?>? syncUuid,
    Value<int?>? modifiedAt,
    Value<String?>? deviceId,
    Value<String?>? mediaAssetId,
    Value<String?>? mediaKey,
  }) {
    return EntriesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      typeIndex: typeIndex ?? this.typeIndex,
      textContent: textContent ?? this.textContent,
      mediaPath: mediaPath ?? this.mediaPath,
      title: title ?? this.title,
      context: context ?? this.context,
      mood: mood ?? this.mood,
      tags: tags ?? this.tags,
      isReleased: isReleased ?? this.isReleased,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      detectedTheme: detectedTheme ?? this.detectedTheme,
      manualLinkIds: manualLinkIds ?? this.manualLinkIds,
      capsuleUnlockDate: capsuleUnlockDate ?? this.capsuleUnlockDate,
      transcription: transcription ?? this.transcription,
      syncUuid: syncUuid ?? this.syncUuid,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      deviceId: deviceId ?? this.deviceId,
      mediaAssetId: mediaAssetId ?? this.mediaAssetId,
      mediaKey: mediaKey ?? this.mediaKey,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (typeIndex.present) {
      map['type_index'] = Variable<int>(typeIndex.value);
    }
    if (textContent.present) {
      map['text'] = Variable<String>(textContent.value);
    }
    if (mediaPath.present) {
      map['media_path'] = Variable<String>(mediaPath.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (context.present) {
      map['context'] = Variable<String>(context.value);
    }
    if (mood.present) {
      map['mood'] = Variable<String>(mood.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (isReleased.present) {
      map['is_released'] = Variable<bool>(isReleased.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (detectedTheme.present) {
      map['detected_theme'] = Variable<String>(detectedTheme.value);
    }
    if (manualLinkIds.present) {
      map['manual_link_ids'] = Variable<String>(manualLinkIds.value);
    }
    if (capsuleUnlockDate.present) {
      map['capsule_unlock_date'] = Variable<int>(capsuleUnlockDate.value);
    }
    if (transcription.present) {
      map['transcription'] = Variable<String>(transcription.value);
    }
    if (syncUuid.present) {
      map['sync_uuid'] = Variable<String>(syncUuid.value);
    }
    if (modifiedAt.present) {
      map['modified_at'] = Variable<int>(modifiedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (mediaAssetId.present) {
      map['media_asset_id'] = Variable<String>(mediaAssetId.value);
    }
    if (mediaKey.present) {
      map['media_key'] = Variable<String>(mediaKey.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntriesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('typeIndex: $typeIndex, ')
          ..write('textContent: $textContent, ')
          ..write('mediaPath: $mediaPath, ')
          ..write('title: $title, ')
          ..write('context: $context, ')
          ..write('mood: $mood, ')
          ..write('tags: $tags, ')
          ..write('isReleased: $isReleased, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('detectedTheme: $detectedTheme, ')
          ..write('manualLinkIds: $manualLinkIds, ')
          ..write('capsuleUnlockDate: $capsuleUnlockDate, ')
          ..write('transcription: $transcription, ')
          ..write('syncUuid: $syncUuid, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('mediaAssetId: $mediaAssetId, ')
          ..write('mediaKey: $mediaKey')
          ..write(')'))
        .toString();
  }
}

class $TreesTable extends Trees with TableInfo<$TreesTable, TreeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TreesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _entryCountMeta = const VerificationMeta(
    'entryCount',
  );
  @override
  late final GeneratedColumn<int> entryCount = GeneratedColumn<int>(
    'entry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateIndexMeta = const VerificationMeta(
    'stateIndex',
  );
  @override
  late final GeneratedColumn<int> stateIndex = GeneratedColumn<int>(
    'state_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    year,
    entryCount,
    createdAt,
    stateIndex,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trees';
  @override
  VerificationContext validateIntegrity(
    Insertable<TreeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    } else if (isInserting) {
      context.missing(_yearMeta);
    }
    if (data.containsKey('entry_count')) {
      context.handle(
        _entryCountMeta,
        entryCount.isAcceptableOrUnknown(data['entry_count']!, _entryCountMeta),
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
    if (data.containsKey('state_index')) {
      context.handle(
        _stateIndexMeta,
        stateIndex.isAcceptableOrUnknown(data['state_index']!, _stateIndexMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TreeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TreeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      )!,
      entryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}entry_count'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      stateIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}state_index'],
      )!,
    );
  }

  @override
  $TreesTable createAlias(String alias) {
    return $TreesTable(attachedDatabase, alias);
  }
}

class TreeRow extends DataClass implements Insertable<TreeRow> {
  final int id;
  final int year;
  final int entryCount;
  final int createdAt;
  final int stateIndex;
  const TreeRow({
    required this.id,
    required this.year,
    required this.entryCount,
    required this.createdAt,
    required this.stateIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['year'] = Variable<int>(year);
    map['entry_count'] = Variable<int>(entryCount);
    map['created_at'] = Variable<int>(createdAt);
    map['state_index'] = Variable<int>(stateIndex);
    return map;
  }

  TreesCompanion toCompanion(bool nullToAbsent) {
    return TreesCompanion(
      id: Value(id),
      year: Value(year),
      entryCount: Value(entryCount),
      createdAt: Value(createdAt),
      stateIndex: Value(stateIndex),
    );
  }

  factory TreeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TreeRow(
      id: serializer.fromJson<int>(json['id']),
      year: serializer.fromJson<int>(json['year']),
      entryCount: serializer.fromJson<int>(json['entryCount']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      stateIndex: serializer.fromJson<int>(json['stateIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'year': serializer.toJson<int>(year),
      'entryCount': serializer.toJson<int>(entryCount),
      'createdAt': serializer.toJson<int>(createdAt),
      'stateIndex': serializer.toJson<int>(stateIndex),
    };
  }

  TreeRow copyWith({
    int? id,
    int? year,
    int? entryCount,
    int? createdAt,
    int? stateIndex,
  }) => TreeRow(
    id: id ?? this.id,
    year: year ?? this.year,
    entryCount: entryCount ?? this.entryCount,
    createdAt: createdAt ?? this.createdAt,
    stateIndex: stateIndex ?? this.stateIndex,
  );
  TreeRow copyWithCompanion(TreesCompanion data) {
    return TreeRow(
      id: data.id.present ? data.id.value : this.id,
      year: data.year.present ? data.year.value : this.year,
      entryCount: data.entryCount.present
          ? data.entryCount.value
          : this.entryCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      stateIndex: data.stateIndex.present
          ? data.stateIndex.value
          : this.stateIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TreeRow(')
          ..write('id: $id, ')
          ..write('year: $year, ')
          ..write('entryCount: $entryCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('stateIndex: $stateIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, year, entryCount, createdAt, stateIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TreeRow &&
          other.id == this.id &&
          other.year == this.year &&
          other.entryCount == this.entryCount &&
          other.createdAt == this.createdAt &&
          other.stateIndex == this.stateIndex);
}

class TreesCompanion extends UpdateCompanion<TreeRow> {
  final Value<int> id;
  final Value<int> year;
  final Value<int> entryCount;
  final Value<int> createdAt;
  final Value<int> stateIndex;
  const TreesCompanion({
    this.id = const Value.absent(),
    this.year = const Value.absent(),
    this.entryCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.stateIndex = const Value.absent(),
  });
  TreesCompanion.insert({
    this.id = const Value.absent(),
    required int year,
    this.entryCount = const Value.absent(),
    required int createdAt,
    this.stateIndex = const Value.absent(),
  }) : year = Value(year),
       createdAt = Value(createdAt);
  static Insertable<TreeRow> custom({
    Expression<int>? id,
    Expression<int>? year,
    Expression<int>? entryCount,
    Expression<int>? createdAt,
    Expression<int>? stateIndex,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (year != null) 'year': year,
      if (entryCount != null) 'entry_count': entryCount,
      if (createdAt != null) 'created_at': createdAt,
      if (stateIndex != null) 'state_index': stateIndex,
    });
  }

  TreesCompanion copyWith({
    Value<int>? id,
    Value<int>? year,
    Value<int>? entryCount,
    Value<int>? createdAt,
    Value<int>? stateIndex,
  }) {
    return TreesCompanion(
      id: id ?? this.id,
      year: year ?? this.year,
      entryCount: entryCount ?? this.entryCount,
      createdAt: createdAt ?? this.createdAt,
      stateIndex: stateIndex ?? this.stateIndex,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (entryCount.present) {
      map['entry_count'] = Variable<int>(entryCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (stateIndex.present) {
      map['state_index'] = Variable<int>(stateIndex.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TreesCompanion(')
          ..write('id: $id, ')
          ..write('year: $year, ')
          ..write('entryCount: $entryCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('stateIndex: $stateIndex')
          ..write(')'))
        .toString();
  }
}

class $RitualsTable extends Rituals with TableInfo<$RitualsTable, RitualRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RitualsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
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
  static const VerificationMeta _signatureMeta = const VerificationMeta(
    'signature',
  );
  @override
  late final GeneratedColumn<String> signature = GeneratedColumn<String>(
    'signature',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _statusIndexMeta = const VerificationMeta(
    'statusIndex',
  );
  @override
  late final GeneratedColumn<int> statusIndex = GeneratedColumn<int>(
    'status_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _cadenceDaysMeta = const VerificationMeta(
    'cadenceDays',
  );
  @override
  late final GeneratedColumn<int> cadenceDays = GeneratedColumn<int>(
    'cadence_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(7),
  );
  static const VerificationMeta _preferredHourMeta = const VerificationMeta(
    'preferredHour',
  );
  @override
  late final GeneratedColumn<int> preferredHour = GeneratedColumn<int>(
    'preferred_hour',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastObservedAtMeta = const VerificationMeta(
    'lastObservedAt',
  );
  @override
  late final GeneratedColumn<int> lastObservedAt = GeneratedColumn<int>(
    'last_observed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextDueAtMeta = const VerificationMeta(
    'nextDueAt',
  );
  @override
  late final GeneratedColumn<int> nextDueAt = GeneratedColumn<int>(
    'next_due_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurrenceCountMeta = const VerificationMeta(
    'occurrenceCount',
  );
  @override
  late final GeneratedColumn<int> occurrenceCount = GeneratedColumn<int>(
    'occurrence_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    name,
    signature,
    statusIndex,
    cadenceDays,
    preferredHour,
    createdAt,
    lastObservedAt,
    nextDueAt,
    occurrenceCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rituals';
  @override
  VerificationContext validateIntegrity(
    Insertable<RitualRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('signature')) {
      context.handle(
        _signatureMeta,
        signature.isAcceptableOrUnknown(data['signature']!, _signatureMeta),
      );
    }
    if (data.containsKey('status_index')) {
      context.handle(
        _statusIndexMeta,
        statusIndex.isAcceptableOrUnknown(
          data['status_index']!,
          _statusIndexMeta,
        ),
      );
    }
    if (data.containsKey('cadence_days')) {
      context.handle(
        _cadenceDaysMeta,
        cadenceDays.isAcceptableOrUnknown(
          data['cadence_days']!,
          _cadenceDaysMeta,
        ),
      );
    }
    if (data.containsKey('preferred_hour')) {
      context.handle(
        _preferredHourMeta,
        preferredHour.isAcceptableOrUnknown(
          data['preferred_hour']!,
          _preferredHourMeta,
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
    if (data.containsKey('last_observed_at')) {
      context.handle(
        _lastObservedAtMeta,
        lastObservedAt.isAcceptableOrUnknown(
          data['last_observed_at']!,
          _lastObservedAtMeta,
        ),
      );
    }
    if (data.containsKey('next_due_at')) {
      context.handle(
        _nextDueAtMeta,
        nextDueAt.isAcceptableOrUnknown(data['next_due_at']!, _nextDueAtMeta),
      );
    }
    if (data.containsKey('occurrence_count')) {
      context.handle(
        _occurrenceCountMeta,
        occurrenceCount.isAcceptableOrUnknown(
          data['occurrence_count']!,
          _occurrenceCountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RitualRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RitualRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      signature: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}signature'],
      )!,
      statusIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status_index'],
      )!,
      cadenceDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cadence_days'],
      )!,
      preferredHour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}preferred_hour'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      lastObservedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_observed_at'],
      ),
      nextDueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_due_at'],
      ),
      occurrenceCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}occurrence_count'],
      )!,
    );
  }

  @override
  $RitualsTable createAlias(String alias) {
    return $RitualsTable(attachedDatabase, alias);
  }
}

class RitualRow extends DataClass implements Insertable<RitualRow> {
  final int id;
  final String uuid;
  final String name;
  final String signature;
  final int statusIndex;
  final int cadenceDays;
  final int? preferredHour;
  final int createdAt;
  final int? lastObservedAt;
  final int? nextDueAt;
  final int occurrenceCount;
  const RitualRow({
    required this.id,
    required this.uuid,
    required this.name,
    required this.signature,
    required this.statusIndex,
    required this.cadenceDays,
    this.preferredHour,
    required this.createdAt,
    this.lastObservedAt,
    this.nextDueAt,
    required this.occurrenceCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['name'] = Variable<String>(name);
    map['signature'] = Variable<String>(signature);
    map['status_index'] = Variable<int>(statusIndex);
    map['cadence_days'] = Variable<int>(cadenceDays);
    if (!nullToAbsent || preferredHour != null) {
      map['preferred_hour'] = Variable<int>(preferredHour);
    }
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || lastObservedAt != null) {
      map['last_observed_at'] = Variable<int>(lastObservedAt);
    }
    if (!nullToAbsent || nextDueAt != null) {
      map['next_due_at'] = Variable<int>(nextDueAt);
    }
    map['occurrence_count'] = Variable<int>(occurrenceCount);
    return map;
  }

  RitualsCompanion toCompanion(bool nullToAbsent) {
    return RitualsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      name: Value(name),
      signature: Value(signature),
      statusIndex: Value(statusIndex),
      cadenceDays: Value(cadenceDays),
      preferredHour: preferredHour == null && nullToAbsent
          ? const Value.absent()
          : Value(preferredHour),
      createdAt: Value(createdAt),
      lastObservedAt: lastObservedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastObservedAt),
      nextDueAt: nextDueAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextDueAt),
      occurrenceCount: Value(occurrenceCount),
    );
  }

  factory RitualRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RitualRow(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      name: serializer.fromJson<String>(json['name']),
      signature: serializer.fromJson<String>(json['signature']),
      statusIndex: serializer.fromJson<int>(json['statusIndex']),
      cadenceDays: serializer.fromJson<int>(json['cadenceDays']),
      preferredHour: serializer.fromJson<int?>(json['preferredHour']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      lastObservedAt: serializer.fromJson<int?>(json['lastObservedAt']),
      nextDueAt: serializer.fromJson<int?>(json['nextDueAt']),
      occurrenceCount: serializer.fromJson<int>(json['occurrenceCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'name': serializer.toJson<String>(name),
      'signature': serializer.toJson<String>(signature),
      'statusIndex': serializer.toJson<int>(statusIndex),
      'cadenceDays': serializer.toJson<int>(cadenceDays),
      'preferredHour': serializer.toJson<int?>(preferredHour),
      'createdAt': serializer.toJson<int>(createdAt),
      'lastObservedAt': serializer.toJson<int?>(lastObservedAt),
      'nextDueAt': serializer.toJson<int?>(nextDueAt),
      'occurrenceCount': serializer.toJson<int>(occurrenceCount),
    };
  }

  RitualRow copyWith({
    int? id,
    String? uuid,
    String? name,
    String? signature,
    int? statusIndex,
    int? cadenceDays,
    Value<int?> preferredHour = const Value.absent(),
    int? createdAt,
    Value<int?> lastObservedAt = const Value.absent(),
    Value<int?> nextDueAt = const Value.absent(),
    int? occurrenceCount,
  }) => RitualRow(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    name: name ?? this.name,
    signature: signature ?? this.signature,
    statusIndex: statusIndex ?? this.statusIndex,
    cadenceDays: cadenceDays ?? this.cadenceDays,
    preferredHour: preferredHour.present
        ? preferredHour.value
        : this.preferredHour,
    createdAt: createdAt ?? this.createdAt,
    lastObservedAt: lastObservedAt.present
        ? lastObservedAt.value
        : this.lastObservedAt,
    nextDueAt: nextDueAt.present ? nextDueAt.value : this.nextDueAt,
    occurrenceCount: occurrenceCount ?? this.occurrenceCount,
  );
  RitualRow copyWithCompanion(RitualsCompanion data) {
    return RitualRow(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      name: data.name.present ? data.name.value : this.name,
      signature: data.signature.present ? data.signature.value : this.signature,
      statusIndex: data.statusIndex.present
          ? data.statusIndex.value
          : this.statusIndex,
      cadenceDays: data.cadenceDays.present
          ? data.cadenceDays.value
          : this.cadenceDays,
      preferredHour: data.preferredHour.present
          ? data.preferredHour.value
          : this.preferredHour,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastObservedAt: data.lastObservedAt.present
          ? data.lastObservedAt.value
          : this.lastObservedAt,
      nextDueAt: data.nextDueAt.present ? data.nextDueAt.value : this.nextDueAt,
      occurrenceCount: data.occurrenceCount.present
          ? data.occurrenceCount.value
          : this.occurrenceCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RitualRow(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('signature: $signature, ')
          ..write('statusIndex: $statusIndex, ')
          ..write('cadenceDays: $cadenceDays, ')
          ..write('preferredHour: $preferredHour, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastObservedAt: $lastObservedAt, ')
          ..write('nextDueAt: $nextDueAt, ')
          ..write('occurrenceCount: $occurrenceCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    name,
    signature,
    statusIndex,
    cadenceDays,
    preferredHour,
    createdAt,
    lastObservedAt,
    nextDueAt,
    occurrenceCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RitualRow &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.name == this.name &&
          other.signature == this.signature &&
          other.statusIndex == this.statusIndex &&
          other.cadenceDays == this.cadenceDays &&
          other.preferredHour == this.preferredHour &&
          other.createdAt == this.createdAt &&
          other.lastObservedAt == this.lastObservedAt &&
          other.nextDueAt == this.nextDueAt &&
          other.occurrenceCount == this.occurrenceCount);
}

class RitualsCompanion extends UpdateCompanion<RitualRow> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> name;
  final Value<String> signature;
  final Value<int> statusIndex;
  final Value<int> cadenceDays;
  final Value<int?> preferredHour;
  final Value<int> createdAt;
  final Value<int?> lastObservedAt;
  final Value<int?> nextDueAt;
  final Value<int> occurrenceCount;
  const RitualsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.name = const Value.absent(),
    this.signature = const Value.absent(),
    this.statusIndex = const Value.absent(),
    this.cadenceDays = const Value.absent(),
    this.preferredHour = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastObservedAt = const Value.absent(),
    this.nextDueAt = const Value.absent(),
    this.occurrenceCount = const Value.absent(),
  });
  RitualsCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    this.name = const Value.absent(),
    this.signature = const Value.absent(),
    this.statusIndex = const Value.absent(),
    this.cadenceDays = const Value.absent(),
    this.preferredHour = const Value.absent(),
    required int createdAt,
    this.lastObservedAt = const Value.absent(),
    this.nextDueAt = const Value.absent(),
    this.occurrenceCount = const Value.absent(),
  }) : uuid = Value(uuid),
       createdAt = Value(createdAt);
  static Insertable<RitualRow> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? name,
    Expression<String>? signature,
    Expression<int>? statusIndex,
    Expression<int>? cadenceDays,
    Expression<int>? preferredHour,
    Expression<int>? createdAt,
    Expression<int>? lastObservedAt,
    Expression<int>? nextDueAt,
    Expression<int>? occurrenceCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (name != null) 'name': name,
      if (signature != null) 'signature': signature,
      if (statusIndex != null) 'status_index': statusIndex,
      if (cadenceDays != null) 'cadence_days': cadenceDays,
      if (preferredHour != null) 'preferred_hour': preferredHour,
      if (createdAt != null) 'created_at': createdAt,
      if (lastObservedAt != null) 'last_observed_at': lastObservedAt,
      if (nextDueAt != null) 'next_due_at': nextDueAt,
      if (occurrenceCount != null) 'occurrence_count': occurrenceCount,
    });
  }

  RitualsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<String>? name,
    Value<String>? signature,
    Value<int>? statusIndex,
    Value<int>? cadenceDays,
    Value<int?>? preferredHour,
    Value<int>? createdAt,
    Value<int?>? lastObservedAt,
    Value<int?>? nextDueAt,
    Value<int>? occurrenceCount,
  }) {
    return RitualsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      signature: signature ?? this.signature,
      statusIndex: statusIndex ?? this.statusIndex,
      cadenceDays: cadenceDays ?? this.cadenceDays,
      preferredHour: preferredHour ?? this.preferredHour,
      createdAt: createdAt ?? this.createdAt,
      lastObservedAt: lastObservedAt ?? this.lastObservedAt,
      nextDueAt: nextDueAt ?? this.nextDueAt,
      occurrenceCount: occurrenceCount ?? this.occurrenceCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (signature.present) {
      map['signature'] = Variable<String>(signature.value);
    }
    if (statusIndex.present) {
      map['status_index'] = Variable<int>(statusIndex.value);
    }
    if (cadenceDays.present) {
      map['cadence_days'] = Variable<int>(cadenceDays.value);
    }
    if (preferredHour.present) {
      map['preferred_hour'] = Variable<int>(preferredHour.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (lastObservedAt.present) {
      map['last_observed_at'] = Variable<int>(lastObservedAt.value);
    }
    if (nextDueAt.present) {
      map['next_due_at'] = Variable<int>(nextDueAt.value);
    }
    if (occurrenceCount.present) {
      map['occurrence_count'] = Variable<int>(occurrenceCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RitualsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('signature: $signature, ')
          ..write('statusIndex: $statusIndex, ')
          ..write('cadenceDays: $cadenceDays, ')
          ..write('preferredHour: $preferredHour, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastObservedAt: $lastObservedAt, ')
          ..write('nextDueAt: $nextDueAt, ')
          ..write('occurrenceCount: $occurrenceCount')
          ..write(')'))
        .toString();
  }
}

abstract class _$SeedlingSchema extends GeneratedDatabase {
  _$SeedlingSchema(QueryExecutor e) : super(e);
  $SeedlingSchemaManager get managers => $SeedlingSchemaManager(this);
  late final $EntriesTable entries = $EntriesTable(this);
  late final $TreesTable trees = $TreesTable(this);
  late final $RitualsTable rituals = $RitualsTable(this);
  late final Index entriesCreatedAt = Index(
    'entries_created_at',
    'CREATE INDEX entries_created_at ON entries (created_at)',
  );
  late final Index entriesModifiedAt = Index(
    'entries_modified_at',
    'CREATE INDEX entries_modified_at ON entries (modified_at)',
  );
  late final Index entriesIsDeletedCreatedAt = Index(
    'entries_is_deleted_created_at',
    'CREATE INDEX entries_is_deleted_created_at ON entries (is_deleted, created_at)',
  );
  late final Index entriesCapsuleUnlockDate = Index(
    'entries_capsule_unlock_date',
    'CREATE INDEX entries_capsule_unlock_date ON entries (capsule_unlock_date)',
  );
  late final Index entriesTypeIndex = Index(
    'entries_type_index',
    'CREATE INDEX entries_type_index ON entries (type_index)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    entries,
    trees,
    rituals,
    entriesCreatedAt,
    entriesModifiedAt,
    entriesIsDeletedCreatedAt,
    entriesCapsuleUnlockDate,
    entriesTypeIndex,
  ];
}

typedef $$EntriesTableCreateCompanionBuilder =
    EntriesCompanion Function({
      Value<int> id,
      required int createdAt,
      Value<int> typeIndex,
      Value<String?> textContent,
      Value<String?> mediaPath,
      Value<String?> title,
      Value<String?> context,
      Value<String?> mood,
      Value<String?> tags,
      Value<bool> isReleased,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      Value<String?> detectedTheme,
      Value<String?> manualLinkIds,
      Value<int?> capsuleUnlockDate,
      Value<String?> transcription,
      Value<String?> syncUuid,
      Value<int?> modifiedAt,
      Value<String?> deviceId,
      Value<String?> mediaAssetId,
      Value<String?> mediaKey,
    });
typedef $$EntriesTableUpdateCompanionBuilder =
    EntriesCompanion Function({
      Value<int> id,
      Value<int> createdAt,
      Value<int> typeIndex,
      Value<String?> textContent,
      Value<String?> mediaPath,
      Value<String?> title,
      Value<String?> context,
      Value<String?> mood,
      Value<String?> tags,
      Value<bool> isReleased,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      Value<String?> detectedTheme,
      Value<String?> manualLinkIds,
      Value<int?> capsuleUnlockDate,
      Value<String?> transcription,
      Value<String?> syncUuid,
      Value<int?> modifiedAt,
      Value<String?> deviceId,
      Value<String?> mediaAssetId,
      Value<String?> mediaKey,
    });

class $$EntriesTableFilterComposer
    extends Composer<_$SeedlingSchema, $EntriesTable> {
  $$EntriesTableFilterComposer({
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

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get typeIndex => $composableBuilder(
    column: $table.typeIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaPath => $composableBuilder(
    column: $table.mediaPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get context => $composableBuilder(
    column: $table.context,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isReleased => $composableBuilder(
    column: $table.isReleased,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detectedTheme => $composableBuilder(
    column: $table.detectedTheme,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manualLinkIds => $composableBuilder(
    column: $table.manualLinkIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capsuleUnlockDate => $composableBuilder(
    column: $table.capsuleUnlockDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcription => $composableBuilder(
    column: $table.transcription,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncUuid => $composableBuilder(
    column: $table.syncUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaAssetId => $composableBuilder(
    column: $table.mediaAssetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaKey => $composableBuilder(
    column: $table.mediaKey,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EntriesTableOrderingComposer
    extends Composer<_$SeedlingSchema, $EntriesTable> {
  $$EntriesTableOrderingComposer({
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

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get typeIndex => $composableBuilder(
    column: $table.typeIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaPath => $composableBuilder(
    column: $table.mediaPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get context => $composableBuilder(
    column: $table.context,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isReleased => $composableBuilder(
    column: $table.isReleased,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detectedTheme => $composableBuilder(
    column: $table.detectedTheme,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manualLinkIds => $composableBuilder(
    column: $table.manualLinkIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capsuleUnlockDate => $composableBuilder(
    column: $table.capsuleUnlockDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcription => $composableBuilder(
    column: $table.transcription,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncUuid => $composableBuilder(
    column: $table.syncUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaAssetId => $composableBuilder(
    column: $table.mediaAssetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaKey => $composableBuilder(
    column: $table.mediaKey,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EntriesTableAnnotationComposer
    extends Composer<_$SeedlingSchema, $EntriesTable> {
  $$EntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get typeIndex =>
      $composableBuilder(column: $table.typeIndex, builder: (column) => column);

  GeneratedColumn<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mediaPath =>
      $composableBuilder(column: $table.mediaPath, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get context =>
      $composableBuilder(column: $table.context, builder: (column) => column);

  GeneratedColumn<String> get mood =>
      $composableBuilder(column: $table.mood, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<bool> get isReleased => $composableBuilder(
    column: $table.isReleased,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get detectedTheme => $composableBuilder(
    column: $table.detectedTheme,
    builder: (column) => column,
  );

  GeneratedColumn<String> get manualLinkIds => $composableBuilder(
    column: $table.manualLinkIds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get capsuleUnlockDate => $composableBuilder(
    column: $table.capsuleUnlockDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transcription => $composableBuilder(
    column: $table.transcription,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncUuid =>
      $composableBuilder(column: $table.syncUuid, builder: (column) => column);

  GeneratedColumn<int> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get mediaAssetId => $composableBuilder(
    column: $table.mediaAssetId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mediaKey =>
      $composableBuilder(column: $table.mediaKey, builder: (column) => column);
}

class $$EntriesTableTableManager
    extends
        RootTableManager<
          _$SeedlingSchema,
          $EntriesTable,
          EntryRow,
          $$EntriesTableFilterComposer,
          $$EntriesTableOrderingComposer,
          $$EntriesTableAnnotationComposer,
          $$EntriesTableCreateCompanionBuilder,
          $$EntriesTableUpdateCompanionBuilder,
          (EntryRow, BaseReferences<_$SeedlingSchema, $EntriesTable, EntryRow>),
          EntryRow,
          PrefetchHooks Function()
        > {
  $$EntriesTableTableManager(_$SeedlingSchema db, $EntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> typeIndex = const Value.absent(),
                Value<String?> textContent = const Value.absent(),
                Value<String?> mediaPath = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> context = const Value.absent(),
                Value<String?> mood = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<bool> isReleased = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String?> detectedTheme = const Value.absent(),
                Value<String?> manualLinkIds = const Value.absent(),
                Value<int?> capsuleUnlockDate = const Value.absent(),
                Value<String?> transcription = const Value.absent(),
                Value<String?> syncUuid = const Value.absent(),
                Value<int?> modifiedAt = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<String?> mediaAssetId = const Value.absent(),
                Value<String?> mediaKey = const Value.absent(),
              }) => EntriesCompanion(
                id: id,
                createdAt: createdAt,
                typeIndex: typeIndex,
                textContent: textContent,
                mediaPath: mediaPath,
                title: title,
                context: context,
                mood: mood,
                tags: tags,
                isReleased: isReleased,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                detectedTheme: detectedTheme,
                manualLinkIds: manualLinkIds,
                capsuleUnlockDate: capsuleUnlockDate,
                transcription: transcription,
                syncUuid: syncUuid,
                modifiedAt: modifiedAt,
                deviceId: deviceId,
                mediaAssetId: mediaAssetId,
                mediaKey: mediaKey,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int createdAt,
                Value<int> typeIndex = const Value.absent(),
                Value<String?> textContent = const Value.absent(),
                Value<String?> mediaPath = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> context = const Value.absent(),
                Value<String?> mood = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<bool> isReleased = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String?> detectedTheme = const Value.absent(),
                Value<String?> manualLinkIds = const Value.absent(),
                Value<int?> capsuleUnlockDate = const Value.absent(),
                Value<String?> transcription = const Value.absent(),
                Value<String?> syncUuid = const Value.absent(),
                Value<int?> modifiedAt = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<String?> mediaAssetId = const Value.absent(),
                Value<String?> mediaKey = const Value.absent(),
              }) => EntriesCompanion.insert(
                id: id,
                createdAt: createdAt,
                typeIndex: typeIndex,
                textContent: textContent,
                mediaPath: mediaPath,
                title: title,
                context: context,
                mood: mood,
                tags: tags,
                isReleased: isReleased,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                detectedTheme: detectedTheme,
                manualLinkIds: manualLinkIds,
                capsuleUnlockDate: capsuleUnlockDate,
                transcription: transcription,
                syncUuid: syncUuid,
                modifiedAt: modifiedAt,
                deviceId: deviceId,
                mediaAssetId: mediaAssetId,
                mediaKey: mediaKey,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EntriesTable, EntryRow>(table),
                  BaseReferences<_$SeedlingSchema, $EntriesTable, EntryRow>(
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

typedef $$EntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$SeedlingSchema,
      $EntriesTable,
      EntryRow,
      $$EntriesTableFilterComposer,
      $$EntriesTableOrderingComposer,
      $$EntriesTableAnnotationComposer,
      $$EntriesTableCreateCompanionBuilder,
      $$EntriesTableUpdateCompanionBuilder,
      (EntryRow, BaseReferences<_$SeedlingSchema, $EntriesTable, EntryRow>),
      EntryRow,
      PrefetchHooks Function()
    >;
typedef $$TreesTableCreateCompanionBuilder =
    TreesCompanion Function({
      Value<int> id,
      required int year,
      Value<int> entryCount,
      required int createdAt,
      Value<int> stateIndex,
    });
typedef $$TreesTableUpdateCompanionBuilder =
    TreesCompanion Function({
      Value<int> id,
      Value<int> year,
      Value<int> entryCount,
      Value<int> createdAt,
      Value<int> stateIndex,
    });

class $$TreesTableFilterComposer
    extends Composer<_$SeedlingSchema, $TreesTable> {
  $$TreesTableFilterComposer({
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

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get entryCount => $composableBuilder(
    column: $table.entryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stateIndex => $composableBuilder(
    column: $table.stateIndex,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TreesTableOrderingComposer
    extends Composer<_$SeedlingSchema, $TreesTable> {
  $$TreesTableOrderingComposer({
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

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get entryCount => $composableBuilder(
    column: $table.entryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stateIndex => $composableBuilder(
    column: $table.stateIndex,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TreesTableAnnotationComposer
    extends Composer<_$SeedlingSchema, $TreesTable> {
  $$TreesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<int> get entryCount => $composableBuilder(
    column: $table.entryCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get stateIndex => $composableBuilder(
    column: $table.stateIndex,
    builder: (column) => column,
  );
}

class $$TreesTableTableManager
    extends
        RootTableManager<
          _$SeedlingSchema,
          $TreesTable,
          TreeRow,
          $$TreesTableFilterComposer,
          $$TreesTableOrderingComposer,
          $$TreesTableAnnotationComposer,
          $$TreesTableCreateCompanionBuilder,
          $$TreesTableUpdateCompanionBuilder,
          (TreeRow, BaseReferences<_$SeedlingSchema, $TreesTable, TreeRow>),
          TreeRow,
          PrefetchHooks Function()
        > {
  $$TreesTableTableManager(_$SeedlingSchema db, $TreesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TreesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TreesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TreesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> year = const Value.absent(),
                Value<int> entryCount = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> stateIndex = const Value.absent(),
              }) => TreesCompanion(
                id: id,
                year: year,
                entryCount: entryCount,
                createdAt: createdAt,
                stateIndex: stateIndex,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int year,
                Value<int> entryCount = const Value.absent(),
                required int createdAt,
                Value<int> stateIndex = const Value.absent(),
              }) => TreesCompanion.insert(
                id: id,
                year: year,
                entryCount: entryCount,
                createdAt: createdAt,
                stateIndex: stateIndex,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TreesTable, TreeRow>(table),
                  BaseReferences<_$SeedlingSchema, $TreesTable, TreeRow>(
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

typedef $$TreesTableProcessedTableManager =
    ProcessedTableManager<
      _$SeedlingSchema,
      $TreesTable,
      TreeRow,
      $$TreesTableFilterComposer,
      $$TreesTableOrderingComposer,
      $$TreesTableAnnotationComposer,
      $$TreesTableCreateCompanionBuilder,
      $$TreesTableUpdateCompanionBuilder,
      (TreeRow, BaseReferences<_$SeedlingSchema, $TreesTable, TreeRow>),
      TreeRow,
      PrefetchHooks Function()
    >;
typedef $$RitualsTableCreateCompanionBuilder =
    RitualsCompanion Function({
      Value<int> id,
      required String uuid,
      Value<String> name,
      Value<String> signature,
      Value<int> statusIndex,
      Value<int> cadenceDays,
      Value<int?> preferredHour,
      required int createdAt,
      Value<int?> lastObservedAt,
      Value<int?> nextDueAt,
      Value<int> occurrenceCount,
    });
typedef $$RitualsTableUpdateCompanionBuilder =
    RitualsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<String> name,
      Value<String> signature,
      Value<int> statusIndex,
      Value<int> cadenceDays,
      Value<int?> preferredHour,
      Value<int> createdAt,
      Value<int?> lastObservedAt,
      Value<int?> nextDueAt,
      Value<int> occurrenceCount,
    });

class $$RitualsTableFilterComposer
    extends Composer<_$SeedlingSchema, $RitualsTable> {
  $$RitualsTableFilterComposer({
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

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signature => $composableBuilder(
    column: $table.signature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get statusIndex => $composableBuilder(
    column: $table.statusIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cadenceDays => $composableBuilder(
    column: $table.cadenceDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get preferredHour => $composableBuilder(
    column: $table.preferredHour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastObservedAt => $composableBuilder(
    column: $table.lastObservedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextDueAt => $composableBuilder(
    column: $table.nextDueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get occurrenceCount => $composableBuilder(
    column: $table.occurrenceCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RitualsTableOrderingComposer
    extends Composer<_$SeedlingSchema, $RitualsTable> {
  $$RitualsTableOrderingComposer({
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

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signature => $composableBuilder(
    column: $table.signature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get statusIndex => $composableBuilder(
    column: $table.statusIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cadenceDays => $composableBuilder(
    column: $table.cadenceDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get preferredHour => $composableBuilder(
    column: $table.preferredHour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastObservedAt => $composableBuilder(
    column: $table.lastObservedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextDueAt => $composableBuilder(
    column: $table.nextDueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get occurrenceCount => $composableBuilder(
    column: $table.occurrenceCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RitualsTableAnnotationComposer
    extends Composer<_$SeedlingSchema, $RitualsTable> {
  $$RitualsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get signature =>
      $composableBuilder(column: $table.signature, builder: (column) => column);

  GeneratedColumn<int> get statusIndex => $composableBuilder(
    column: $table.statusIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cadenceDays => $composableBuilder(
    column: $table.cadenceDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get preferredHour => $composableBuilder(
    column: $table.preferredHour,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get lastObservedAt => $composableBuilder(
    column: $table.lastObservedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nextDueAt =>
      $composableBuilder(column: $table.nextDueAt, builder: (column) => column);

  GeneratedColumn<int> get occurrenceCount => $composableBuilder(
    column: $table.occurrenceCount,
    builder: (column) => column,
  );
}

class $$RitualsTableTableManager
    extends
        RootTableManager<
          _$SeedlingSchema,
          $RitualsTable,
          RitualRow,
          $$RitualsTableFilterComposer,
          $$RitualsTableOrderingComposer,
          $$RitualsTableAnnotationComposer,
          $$RitualsTableCreateCompanionBuilder,
          $$RitualsTableUpdateCompanionBuilder,
          (
            RitualRow,
            BaseReferences<_$SeedlingSchema, $RitualsTable, RitualRow>,
          ),
          RitualRow,
          PrefetchHooks Function()
        > {
  $$RitualsTableTableManager(_$SeedlingSchema db, $RitualsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RitualsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RitualsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RitualsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> signature = const Value.absent(),
                Value<int> statusIndex = const Value.absent(),
                Value<int> cadenceDays = const Value.absent(),
                Value<int?> preferredHour = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> lastObservedAt = const Value.absent(),
                Value<int?> nextDueAt = const Value.absent(),
                Value<int> occurrenceCount = const Value.absent(),
              }) => RitualsCompanion(
                id: id,
                uuid: uuid,
                name: name,
                signature: signature,
                statusIndex: statusIndex,
                cadenceDays: cadenceDays,
                preferredHour: preferredHour,
                createdAt: createdAt,
                lastObservedAt: lastObservedAt,
                nextDueAt: nextDueAt,
                occurrenceCount: occurrenceCount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                Value<String> name = const Value.absent(),
                Value<String> signature = const Value.absent(),
                Value<int> statusIndex = const Value.absent(),
                Value<int> cadenceDays = const Value.absent(),
                Value<int?> preferredHour = const Value.absent(),
                required int createdAt,
                Value<int?> lastObservedAt = const Value.absent(),
                Value<int?> nextDueAt = const Value.absent(),
                Value<int> occurrenceCount = const Value.absent(),
              }) => RitualsCompanion.insert(
                id: id,
                uuid: uuid,
                name: name,
                signature: signature,
                statusIndex: statusIndex,
                cadenceDays: cadenceDays,
                preferredHour: preferredHour,
                createdAt: createdAt,
                lastObservedAt: lastObservedAt,
                nextDueAt: nextDueAt,
                occurrenceCount: occurrenceCount,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RitualsTable, RitualRow>(table),
                  BaseReferences<_$SeedlingSchema, $RitualsTable, RitualRow>(
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

typedef $$RitualsTableProcessedTableManager =
    ProcessedTableManager<
      _$SeedlingSchema,
      $RitualsTable,
      RitualRow,
      $$RitualsTableFilterComposer,
      $$RitualsTableOrderingComposer,
      $$RitualsTableAnnotationComposer,
      $$RitualsTableCreateCompanionBuilder,
      $$RitualsTableUpdateCompanionBuilder,
      (RitualRow, BaseReferences<_$SeedlingSchema, $RitualsTable, RitualRow>),
      RitualRow,
      PrefetchHooks Function()
    >;

class $SeedlingSchemaManager {
  final _$SeedlingSchema _db;
  $SeedlingSchemaManager(this._db);
  $$EntriesTableTableManager get entries =>
      $$EntriesTableTableManager(_db, _db.entries);
  $$TreesTableTableManager get trees =>
      $$TreesTableTableManager(_db, _db.trees);
  $$RitualsTableTableManager get rituals =>
      $$RitualsTableTableManager(_db, _db.rituals);
}
