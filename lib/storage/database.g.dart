// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $LibraryItemsTable extends LibraryItems
    with TableInfo<$LibraryItemsTable, LibraryItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _userTitleMeta = const VerificationMeta(
    'userTitle',
  );
  @override
  late final GeneratedColumn<String> userTitle = GeneratedColumn<String>(
    'user_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hostMeta = const VerificationMeta('host');
  @override
  late final GeneratedColumn<String> host = GeneratedColumn<String>(
    'host',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seriesKeyMeta = const VerificationMeta(
    'seriesKey',
  );
  @override
  late final GeneratedColumn<String> seriesKey = GeneratedColumn<String>(
    'series_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seriesUrlMeta = const VerificationMeta(
    'seriesUrl',
  );
  @override
  late final GeneratedColumn<String> seriesUrl = GeneratedColumn<String>(
    'series_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _identityBasisMeta = const VerificationMeta(
    'identityBasis',
  );
  @override
  late final GeneratedColumn<String> identityBasis = GeneratedColumn<String>(
    'identity_basis',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _identityConfidenceMeta =
      const VerificationMeta('identityConfidence');
  @override
  late final GeneratedColumn<String> identityConfidence =
      GeneratedColumn<String>(
        'identity_confidence',
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
  static const VerificationMeta _lastOpenedAtMeta = const VerificationMeta(
    'lastOpenedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastOpenedAt = GeneratedColumn<DateTime>(
    'last_opened_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastCapturedAtMeta = const VerificationMeta(
    'lastCapturedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastCapturedAt =
      GeneratedColumn<DateTime>(
        'last_captured_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastOpenedChapterIdMeta =
      const VerificationMeta('lastOpenedChapterId');
  @override
  late final GeneratedColumn<String> lastOpenedChapterId =
      GeneratedColumn<String>(
        'last_opened_chapter_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastCompletedChapterIdMeta =
      const VerificationMeta('lastCompletedChapterId');
  @override
  late final GeneratedColumn<String> lastCompletedChapterId =
      GeneratedColumn<String>(
        'last_completed_chapter_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastReadAtMeta = const VerificationMeta(
    'lastReadAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastReadAt = GeneratedColumn<DateTime>(
    'last_read_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastCheckAtMeta = const VerificationMeta(
    'lastCheckAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastCheckAt = GeneratedColumn<DateTime>(
    'last_check_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastCheckSuccessAtMeta =
      const VerificationMeta('lastCheckSuccessAt');
  @override
  late final GeneratedColumn<DateTime> lastCheckSuccessAt =
      GeneratedColumn<DateTime>(
        'last_check_success_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastCheckErrorMeta = const VerificationMeta(
    'lastCheckError',
  );
  @override
  late final GeneratedColumn<String> lastCheckError = GeneratedColumn<String>(
    'last_check_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastCheckResultMeta = const VerificationMeta(
    'lastCheckResult',
  );
  @override
  late final GeneratedColumn<String> lastCheckResult = GeneratedColumn<String>(
    'last_check_result',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lifecycleMeta = const VerificationMeta(
    'lifecycle',
  );
  @override
  late final GeneratedColumn<String> lifecycle = GeneratedColumn<String>(
    'lifecycle',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
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
    title,
    userTitle,
    sourceUrl,
    host,
    seriesKey,
    seriesUrl,
    identityBasis,
    identityConfidence,
    createdAt,
    lastOpenedAt,
    lastCapturedAt,
    lastOpenedChapterId,
    lastCompletedChapterId,
    lastReadAt,
    lastCheckAt,
    lastCheckSuccessAt,
    lastCheckError,
    lastCheckResult,
    lifecycle,
    archivedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('user_title')) {
      context.handle(
        _userTitleMeta,
        userTitle.isAcceptableOrUnknown(data['user_title']!, _userTitleMeta),
      );
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceUrlMeta);
    }
    if (data.containsKey('host')) {
      context.handle(
        _hostMeta,
        host.isAcceptableOrUnknown(data['host']!, _hostMeta),
      );
    } else if (isInserting) {
      context.missing(_hostMeta);
    }
    if (data.containsKey('series_key')) {
      context.handle(
        _seriesKeyMeta,
        seriesKey.isAcceptableOrUnknown(data['series_key']!, _seriesKeyMeta),
      );
    }
    if (data.containsKey('series_url')) {
      context.handle(
        _seriesUrlMeta,
        seriesUrl.isAcceptableOrUnknown(data['series_url']!, _seriesUrlMeta),
      );
    }
    if (data.containsKey('identity_basis')) {
      context.handle(
        _identityBasisMeta,
        identityBasis.isAcceptableOrUnknown(
          data['identity_basis']!,
          _identityBasisMeta,
        ),
      );
    }
    if (data.containsKey('identity_confidence')) {
      context.handle(
        _identityConfidenceMeta,
        identityConfidence.isAcceptableOrUnknown(
          data['identity_confidence']!,
          _identityConfidenceMeta,
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
    if (data.containsKey('last_opened_at')) {
      context.handle(
        _lastOpenedAtMeta,
        lastOpenedAt.isAcceptableOrUnknown(
          data['last_opened_at']!,
          _lastOpenedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_captured_at')) {
      context.handle(
        _lastCapturedAtMeta,
        lastCapturedAt.isAcceptableOrUnknown(
          data['last_captured_at']!,
          _lastCapturedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_opened_chapter_id')) {
      context.handle(
        _lastOpenedChapterIdMeta,
        lastOpenedChapterId.isAcceptableOrUnknown(
          data['last_opened_chapter_id']!,
          _lastOpenedChapterIdMeta,
        ),
      );
    }
    if (data.containsKey('last_completed_chapter_id')) {
      context.handle(
        _lastCompletedChapterIdMeta,
        lastCompletedChapterId.isAcceptableOrUnknown(
          data['last_completed_chapter_id']!,
          _lastCompletedChapterIdMeta,
        ),
      );
    }
    if (data.containsKey('last_read_at')) {
      context.handle(
        _lastReadAtMeta,
        lastReadAt.isAcceptableOrUnknown(
          data['last_read_at']!,
          _lastReadAtMeta,
        ),
      );
    }
    if (data.containsKey('last_check_at')) {
      context.handle(
        _lastCheckAtMeta,
        lastCheckAt.isAcceptableOrUnknown(
          data['last_check_at']!,
          _lastCheckAtMeta,
        ),
      );
    }
    if (data.containsKey('last_check_success_at')) {
      context.handle(
        _lastCheckSuccessAtMeta,
        lastCheckSuccessAt.isAcceptableOrUnknown(
          data['last_check_success_at']!,
          _lastCheckSuccessAtMeta,
        ),
      );
    }
    if (data.containsKey('last_check_error')) {
      context.handle(
        _lastCheckErrorMeta,
        lastCheckError.isAcceptableOrUnknown(
          data['last_check_error']!,
          _lastCheckErrorMeta,
        ),
      );
    }
    if (data.containsKey('last_check_result')) {
      context.handle(
        _lastCheckResultMeta,
        lastCheckResult.isAcceptableOrUnknown(
          data['last_check_result']!,
          _lastCheckResultMeta,
        ),
      );
    }
    if (data.containsKey('lifecycle')) {
      context.handle(
        _lifecycleMeta,
        lifecycle.isAcceptableOrUnknown(data['lifecycle']!, _lifecycleMeta),
      );
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
  LibraryItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      userTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_title'],
      ),
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      )!,
      host: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host'],
      )!,
      seriesKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_key'],
      ),
      seriesUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_url'],
      ),
      identityBasis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}identity_basis'],
      ),
      identityConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}identity_confidence'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastOpenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_opened_at'],
      ),
      lastCapturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_captured_at'],
      ),
      lastOpenedChapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_opened_chapter_id'],
      ),
      lastCompletedChapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_completed_chapter_id'],
      ),
      lastReadAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_read_at'],
      ),
      lastCheckAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_check_at'],
      ),
      lastCheckSuccessAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_check_success_at'],
      ),
      lastCheckError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_check_error'],
      ),
      lastCheckResult: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_check_result'],
      ),
      lifecycle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lifecycle'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
    );
  }

  @override
  $LibraryItemsTable createAlias(String alias) {
    return $LibraryItemsTable(attachedDatabase, alias);
  }
}

class LibraryItem extends DataClass implements Insertable<LibraryItem> {
  final String id;

  /// Automatically detected series title. `title` keeps its original column
  /// name so existing rows migrate in place.
  final String title;

  /// User-chosen display name. Presentation only — never part of matching,
  /// never part of a storage path.
  final String? userTitle;
  final String sourceUrl;
  final String host;

  /// Series-path fingerprint, or a `title:`/`host:` fallback key. Unique per
  /// host: this is what future captures match against.
  final String? seriesKey;

  /// A stable URL for the series index page, when the page offered one.
  final String? seriesUrl;

  /// How the key was derived, kept so a bad grouping is explainable.
  final String? identityBasis;
  final String? identityConfidence;
  final DateTime createdAt;
  final DateTime? lastOpenedAt;
  final DateTime? lastCapturedAt;

  /// Denormalised reading pointers. Derivable, but every library query orders
  /// on them, and recomputing a per-series aggregate for each row on every
  /// stream emission is the difference between a snappy list and a stuttery
  /// one. Written in the same transaction as the chapter change that causes
  /// them, and rebuildable by `repairSeriesReadingState`.
  final String? lastOpenedChapterId;
  final String? lastCompletedChapterId;
  final DateTime? lastReadAt;

  /// When a check last ran, successful or not.
  final DateTime? lastCheckAt;

  /// When a check last finished successfully.
  final DateTime? lastCheckSuccessAt;

  /// Why the last check failed, when it did.
  final String? lastCheckError;

  /// Terminal state of the last check: upToDate / updatesAvailable / failed /
  /// cancelled / needsUserInput.
  final String? lastCheckResult;

  /// `active` | `archived`. Archiving hides a series from the library and
  /// excludes it from checks; it never touches chapters or files — restore
  /// brings everything back exactly as it was.
  final String lifecycle;

  /// When the series was archived; null while active. Presentation only
  /// ("archived 2 weeks ago") — [lifecycle] is the source of truth.
  final DateTime? archivedAt;
  const LibraryItem({
    required this.id,
    required this.title,
    this.userTitle,
    required this.sourceUrl,
    required this.host,
    this.seriesKey,
    this.seriesUrl,
    this.identityBasis,
    this.identityConfidence,
    required this.createdAt,
    this.lastOpenedAt,
    this.lastCapturedAt,
    this.lastOpenedChapterId,
    this.lastCompletedChapterId,
    this.lastReadAt,
    this.lastCheckAt,
    this.lastCheckSuccessAt,
    this.lastCheckError,
    this.lastCheckResult,
    required this.lifecycle,
    this.archivedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || userTitle != null) {
      map['user_title'] = Variable<String>(userTitle);
    }
    map['source_url'] = Variable<String>(sourceUrl);
    map['host'] = Variable<String>(host);
    if (!nullToAbsent || seriesKey != null) {
      map['series_key'] = Variable<String>(seriesKey);
    }
    if (!nullToAbsent || seriesUrl != null) {
      map['series_url'] = Variable<String>(seriesUrl);
    }
    if (!nullToAbsent || identityBasis != null) {
      map['identity_basis'] = Variable<String>(identityBasis);
    }
    if (!nullToAbsent || identityConfidence != null) {
      map['identity_confidence'] = Variable<String>(identityConfidence);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastOpenedAt != null) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt);
    }
    if (!nullToAbsent || lastCapturedAt != null) {
      map['last_captured_at'] = Variable<DateTime>(lastCapturedAt);
    }
    if (!nullToAbsent || lastOpenedChapterId != null) {
      map['last_opened_chapter_id'] = Variable<String>(lastOpenedChapterId);
    }
    if (!nullToAbsent || lastCompletedChapterId != null) {
      map['last_completed_chapter_id'] = Variable<String>(
        lastCompletedChapterId,
      );
    }
    if (!nullToAbsent || lastReadAt != null) {
      map['last_read_at'] = Variable<DateTime>(lastReadAt);
    }
    if (!nullToAbsent || lastCheckAt != null) {
      map['last_check_at'] = Variable<DateTime>(lastCheckAt);
    }
    if (!nullToAbsent || lastCheckSuccessAt != null) {
      map['last_check_success_at'] = Variable<DateTime>(lastCheckSuccessAt);
    }
    if (!nullToAbsent || lastCheckError != null) {
      map['last_check_error'] = Variable<String>(lastCheckError);
    }
    if (!nullToAbsent || lastCheckResult != null) {
      map['last_check_result'] = Variable<String>(lastCheckResult);
    }
    map['lifecycle'] = Variable<String>(lifecycle);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    return map;
  }

  LibraryItemsCompanion toCompanion(bool nullToAbsent) {
    return LibraryItemsCompanion(
      id: Value(id),
      title: Value(title),
      userTitle: userTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(userTitle),
      sourceUrl: Value(sourceUrl),
      host: Value(host),
      seriesKey: seriesKey == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesKey),
      seriesUrl: seriesUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesUrl),
      identityBasis: identityBasis == null && nullToAbsent
          ? const Value.absent()
          : Value(identityBasis),
      identityConfidence: identityConfidence == null && nullToAbsent
          ? const Value.absent()
          : Value(identityConfidence),
      createdAt: Value(createdAt),
      lastOpenedAt: lastOpenedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastOpenedAt),
      lastCapturedAt: lastCapturedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCapturedAt),
      lastOpenedChapterId: lastOpenedChapterId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastOpenedChapterId),
      lastCompletedChapterId: lastCompletedChapterId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCompletedChapterId),
      lastReadAt: lastReadAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReadAt),
      lastCheckAt: lastCheckAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCheckAt),
      lastCheckSuccessAt: lastCheckSuccessAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCheckSuccessAt),
      lastCheckError: lastCheckError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCheckError),
      lastCheckResult: lastCheckResult == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCheckResult),
      lifecycle: Value(lifecycle),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
    );
  }

  factory LibraryItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryItem(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      userTitle: serializer.fromJson<String?>(json['userTitle']),
      sourceUrl: serializer.fromJson<String>(json['sourceUrl']),
      host: serializer.fromJson<String>(json['host']),
      seriesKey: serializer.fromJson<String?>(json['seriesKey']),
      seriesUrl: serializer.fromJson<String?>(json['seriesUrl']),
      identityBasis: serializer.fromJson<String?>(json['identityBasis']),
      identityConfidence: serializer.fromJson<String?>(
        json['identityConfidence'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastOpenedAt: serializer.fromJson<DateTime?>(json['lastOpenedAt']),
      lastCapturedAt: serializer.fromJson<DateTime?>(json['lastCapturedAt']),
      lastOpenedChapterId: serializer.fromJson<String?>(
        json['lastOpenedChapterId'],
      ),
      lastCompletedChapterId: serializer.fromJson<String?>(
        json['lastCompletedChapterId'],
      ),
      lastReadAt: serializer.fromJson<DateTime?>(json['lastReadAt']),
      lastCheckAt: serializer.fromJson<DateTime?>(json['lastCheckAt']),
      lastCheckSuccessAt: serializer.fromJson<DateTime?>(
        json['lastCheckSuccessAt'],
      ),
      lastCheckError: serializer.fromJson<String?>(json['lastCheckError']),
      lastCheckResult: serializer.fromJson<String?>(json['lastCheckResult']),
      lifecycle: serializer.fromJson<String>(json['lifecycle']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'userTitle': serializer.toJson<String?>(userTitle),
      'sourceUrl': serializer.toJson<String>(sourceUrl),
      'host': serializer.toJson<String>(host),
      'seriesKey': serializer.toJson<String?>(seriesKey),
      'seriesUrl': serializer.toJson<String?>(seriesUrl),
      'identityBasis': serializer.toJson<String?>(identityBasis),
      'identityConfidence': serializer.toJson<String?>(identityConfidence),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastOpenedAt': serializer.toJson<DateTime?>(lastOpenedAt),
      'lastCapturedAt': serializer.toJson<DateTime?>(lastCapturedAt),
      'lastOpenedChapterId': serializer.toJson<String?>(lastOpenedChapterId),
      'lastCompletedChapterId': serializer.toJson<String?>(
        lastCompletedChapterId,
      ),
      'lastReadAt': serializer.toJson<DateTime?>(lastReadAt),
      'lastCheckAt': serializer.toJson<DateTime?>(lastCheckAt),
      'lastCheckSuccessAt': serializer.toJson<DateTime?>(lastCheckSuccessAt),
      'lastCheckError': serializer.toJson<String?>(lastCheckError),
      'lastCheckResult': serializer.toJson<String?>(lastCheckResult),
      'lifecycle': serializer.toJson<String>(lifecycle),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
    };
  }

  LibraryItem copyWith({
    String? id,
    String? title,
    Value<String?> userTitle = const Value.absent(),
    String? sourceUrl,
    String? host,
    Value<String?> seriesKey = const Value.absent(),
    Value<String?> seriesUrl = const Value.absent(),
    Value<String?> identityBasis = const Value.absent(),
    Value<String?> identityConfidence = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> lastOpenedAt = const Value.absent(),
    Value<DateTime?> lastCapturedAt = const Value.absent(),
    Value<String?> lastOpenedChapterId = const Value.absent(),
    Value<String?> lastCompletedChapterId = const Value.absent(),
    Value<DateTime?> lastReadAt = const Value.absent(),
    Value<DateTime?> lastCheckAt = const Value.absent(),
    Value<DateTime?> lastCheckSuccessAt = const Value.absent(),
    Value<String?> lastCheckError = const Value.absent(),
    Value<String?> lastCheckResult = const Value.absent(),
    String? lifecycle,
    Value<DateTime?> archivedAt = const Value.absent(),
  }) => LibraryItem(
    id: id ?? this.id,
    title: title ?? this.title,
    userTitle: userTitle.present ? userTitle.value : this.userTitle,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    host: host ?? this.host,
    seriesKey: seriesKey.present ? seriesKey.value : this.seriesKey,
    seriesUrl: seriesUrl.present ? seriesUrl.value : this.seriesUrl,
    identityBasis: identityBasis.present
        ? identityBasis.value
        : this.identityBasis,
    identityConfidence: identityConfidence.present
        ? identityConfidence.value
        : this.identityConfidence,
    createdAt: createdAt ?? this.createdAt,
    lastOpenedAt: lastOpenedAt.present ? lastOpenedAt.value : this.lastOpenedAt,
    lastCapturedAt: lastCapturedAt.present
        ? lastCapturedAt.value
        : this.lastCapturedAt,
    lastOpenedChapterId: lastOpenedChapterId.present
        ? lastOpenedChapterId.value
        : this.lastOpenedChapterId,
    lastCompletedChapterId: lastCompletedChapterId.present
        ? lastCompletedChapterId.value
        : this.lastCompletedChapterId,
    lastReadAt: lastReadAt.present ? lastReadAt.value : this.lastReadAt,
    lastCheckAt: lastCheckAt.present ? lastCheckAt.value : this.lastCheckAt,
    lastCheckSuccessAt: lastCheckSuccessAt.present
        ? lastCheckSuccessAt.value
        : this.lastCheckSuccessAt,
    lastCheckError: lastCheckError.present
        ? lastCheckError.value
        : this.lastCheckError,
    lastCheckResult: lastCheckResult.present
        ? lastCheckResult.value
        : this.lastCheckResult,
    lifecycle: lifecycle ?? this.lifecycle,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
  );
  LibraryItem copyWithCompanion(LibraryItemsCompanion data) {
    return LibraryItem(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      userTitle: data.userTitle.present ? data.userTitle.value : this.userTitle,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      host: data.host.present ? data.host.value : this.host,
      seriesKey: data.seriesKey.present ? data.seriesKey.value : this.seriesKey,
      seriesUrl: data.seriesUrl.present ? data.seriesUrl.value : this.seriesUrl,
      identityBasis: data.identityBasis.present
          ? data.identityBasis.value
          : this.identityBasis,
      identityConfidence: data.identityConfidence.present
          ? data.identityConfidence.value
          : this.identityConfidence,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastOpenedAt: data.lastOpenedAt.present
          ? data.lastOpenedAt.value
          : this.lastOpenedAt,
      lastCapturedAt: data.lastCapturedAt.present
          ? data.lastCapturedAt.value
          : this.lastCapturedAt,
      lastOpenedChapterId: data.lastOpenedChapterId.present
          ? data.lastOpenedChapterId.value
          : this.lastOpenedChapterId,
      lastCompletedChapterId: data.lastCompletedChapterId.present
          ? data.lastCompletedChapterId.value
          : this.lastCompletedChapterId,
      lastReadAt: data.lastReadAt.present
          ? data.lastReadAt.value
          : this.lastReadAt,
      lastCheckAt: data.lastCheckAt.present
          ? data.lastCheckAt.value
          : this.lastCheckAt,
      lastCheckSuccessAt: data.lastCheckSuccessAt.present
          ? data.lastCheckSuccessAt.value
          : this.lastCheckSuccessAt,
      lastCheckError: data.lastCheckError.present
          ? data.lastCheckError.value
          : this.lastCheckError,
      lastCheckResult: data.lastCheckResult.present
          ? data.lastCheckResult.value
          : this.lastCheckResult,
      lifecycle: data.lifecycle.present ? data.lifecycle.value : this.lifecycle,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryItem(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('userTitle: $userTitle, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('host: $host, ')
          ..write('seriesKey: $seriesKey, ')
          ..write('seriesUrl: $seriesUrl, ')
          ..write('identityBasis: $identityBasis, ')
          ..write('identityConfidence: $identityConfidence, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('lastCapturedAt: $lastCapturedAt, ')
          ..write('lastOpenedChapterId: $lastOpenedChapterId, ')
          ..write('lastCompletedChapterId: $lastCompletedChapterId, ')
          ..write('lastReadAt: $lastReadAt, ')
          ..write('lastCheckAt: $lastCheckAt, ')
          ..write('lastCheckSuccessAt: $lastCheckSuccessAt, ')
          ..write('lastCheckError: $lastCheckError, ')
          ..write('lastCheckResult: $lastCheckResult, ')
          ..write('lifecycle: $lifecycle, ')
          ..write('archivedAt: $archivedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    title,
    userTitle,
    sourceUrl,
    host,
    seriesKey,
    seriesUrl,
    identityBasis,
    identityConfidence,
    createdAt,
    lastOpenedAt,
    lastCapturedAt,
    lastOpenedChapterId,
    lastCompletedChapterId,
    lastReadAt,
    lastCheckAt,
    lastCheckSuccessAt,
    lastCheckError,
    lastCheckResult,
    lifecycle,
    archivedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryItem &&
          other.id == this.id &&
          other.title == this.title &&
          other.userTitle == this.userTitle &&
          other.sourceUrl == this.sourceUrl &&
          other.host == this.host &&
          other.seriesKey == this.seriesKey &&
          other.seriesUrl == this.seriesUrl &&
          other.identityBasis == this.identityBasis &&
          other.identityConfidence == this.identityConfidence &&
          other.createdAt == this.createdAt &&
          other.lastOpenedAt == this.lastOpenedAt &&
          other.lastCapturedAt == this.lastCapturedAt &&
          other.lastOpenedChapterId == this.lastOpenedChapterId &&
          other.lastCompletedChapterId == this.lastCompletedChapterId &&
          other.lastReadAt == this.lastReadAt &&
          other.lastCheckAt == this.lastCheckAt &&
          other.lastCheckSuccessAt == this.lastCheckSuccessAt &&
          other.lastCheckError == this.lastCheckError &&
          other.lastCheckResult == this.lastCheckResult &&
          other.lifecycle == this.lifecycle &&
          other.archivedAt == this.archivedAt);
}

class LibraryItemsCompanion extends UpdateCompanion<LibraryItem> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> userTitle;
  final Value<String> sourceUrl;
  final Value<String> host;
  final Value<String?> seriesKey;
  final Value<String?> seriesUrl;
  final Value<String?> identityBasis;
  final Value<String?> identityConfidence;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastOpenedAt;
  final Value<DateTime?> lastCapturedAt;
  final Value<String?> lastOpenedChapterId;
  final Value<String?> lastCompletedChapterId;
  final Value<DateTime?> lastReadAt;
  final Value<DateTime?> lastCheckAt;
  final Value<DateTime?> lastCheckSuccessAt;
  final Value<String?> lastCheckError;
  final Value<String?> lastCheckResult;
  final Value<String> lifecycle;
  final Value<DateTime?> archivedAt;
  final Value<int> rowid;
  const LibraryItemsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.userTitle = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.host = const Value.absent(),
    this.seriesKey = const Value.absent(),
    this.seriesUrl = const Value.absent(),
    this.identityBasis = const Value.absent(),
    this.identityConfidence = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.lastCapturedAt = const Value.absent(),
    this.lastOpenedChapterId = const Value.absent(),
    this.lastCompletedChapterId = const Value.absent(),
    this.lastReadAt = const Value.absent(),
    this.lastCheckAt = const Value.absent(),
    this.lastCheckSuccessAt = const Value.absent(),
    this.lastCheckError = const Value.absent(),
    this.lastCheckResult = const Value.absent(),
    this.lifecycle = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibraryItemsCompanion.insert({
    required String id,
    required String title,
    this.userTitle = const Value.absent(),
    required String sourceUrl,
    required String host,
    this.seriesKey = const Value.absent(),
    this.seriesUrl = const Value.absent(),
    this.identityBasis = const Value.absent(),
    this.identityConfidence = const Value.absent(),
    required DateTime createdAt,
    this.lastOpenedAt = const Value.absent(),
    this.lastCapturedAt = const Value.absent(),
    this.lastOpenedChapterId = const Value.absent(),
    this.lastCompletedChapterId = const Value.absent(),
    this.lastReadAt = const Value.absent(),
    this.lastCheckAt = const Value.absent(),
    this.lastCheckSuccessAt = const Value.absent(),
    this.lastCheckError = const Value.absent(),
    this.lastCheckResult = const Value.absent(),
    this.lifecycle = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       sourceUrl = Value(sourceUrl),
       host = Value(host),
       createdAt = Value(createdAt);
  static Insertable<LibraryItem> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? userTitle,
    Expression<String>? sourceUrl,
    Expression<String>? host,
    Expression<String>? seriesKey,
    Expression<String>? seriesUrl,
    Expression<String>? identityBasis,
    Expression<String>? identityConfidence,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastOpenedAt,
    Expression<DateTime>? lastCapturedAt,
    Expression<String>? lastOpenedChapterId,
    Expression<String>? lastCompletedChapterId,
    Expression<DateTime>? lastReadAt,
    Expression<DateTime>? lastCheckAt,
    Expression<DateTime>? lastCheckSuccessAt,
    Expression<String>? lastCheckError,
    Expression<String>? lastCheckResult,
    Expression<String>? lifecycle,
    Expression<DateTime>? archivedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (userTitle != null) 'user_title': userTitle,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (host != null) 'host': host,
      if (seriesKey != null) 'series_key': seriesKey,
      if (seriesUrl != null) 'series_url': seriesUrl,
      if (identityBasis != null) 'identity_basis': identityBasis,
      if (identityConfidence != null) 'identity_confidence': identityConfidence,
      if (createdAt != null) 'created_at': createdAt,
      if (lastOpenedAt != null) 'last_opened_at': lastOpenedAt,
      if (lastCapturedAt != null) 'last_captured_at': lastCapturedAt,
      if (lastOpenedChapterId != null)
        'last_opened_chapter_id': lastOpenedChapterId,
      if (lastCompletedChapterId != null)
        'last_completed_chapter_id': lastCompletedChapterId,
      if (lastReadAt != null) 'last_read_at': lastReadAt,
      if (lastCheckAt != null) 'last_check_at': lastCheckAt,
      if (lastCheckSuccessAt != null)
        'last_check_success_at': lastCheckSuccessAt,
      if (lastCheckError != null) 'last_check_error': lastCheckError,
      if (lastCheckResult != null) 'last_check_result': lastCheckResult,
      if (lifecycle != null) 'lifecycle': lifecycle,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LibraryItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? userTitle,
    Value<String>? sourceUrl,
    Value<String>? host,
    Value<String?>? seriesKey,
    Value<String?>? seriesUrl,
    Value<String?>? identityBasis,
    Value<String?>? identityConfidence,
    Value<DateTime>? createdAt,
    Value<DateTime?>? lastOpenedAt,
    Value<DateTime?>? lastCapturedAt,
    Value<String?>? lastOpenedChapterId,
    Value<String?>? lastCompletedChapterId,
    Value<DateTime?>? lastReadAt,
    Value<DateTime?>? lastCheckAt,
    Value<DateTime?>? lastCheckSuccessAt,
    Value<String?>? lastCheckError,
    Value<String?>? lastCheckResult,
    Value<String>? lifecycle,
    Value<DateTime?>? archivedAt,
    Value<int>? rowid,
  }) {
    return LibraryItemsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      userTitle: userTitle ?? this.userTitle,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      host: host ?? this.host,
      seriesKey: seriesKey ?? this.seriesKey,
      seriesUrl: seriesUrl ?? this.seriesUrl,
      identityBasis: identityBasis ?? this.identityBasis,
      identityConfidence: identityConfidence ?? this.identityConfidence,
      createdAt: createdAt ?? this.createdAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      lastCapturedAt: lastCapturedAt ?? this.lastCapturedAt,
      lastOpenedChapterId: lastOpenedChapterId ?? this.lastOpenedChapterId,
      lastCompletedChapterId:
          lastCompletedChapterId ?? this.lastCompletedChapterId,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      lastCheckAt: lastCheckAt ?? this.lastCheckAt,
      lastCheckSuccessAt: lastCheckSuccessAt ?? this.lastCheckSuccessAt,
      lastCheckError: lastCheckError ?? this.lastCheckError,
      lastCheckResult: lastCheckResult ?? this.lastCheckResult,
      lifecycle: lifecycle ?? this.lifecycle,
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
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (userTitle.present) {
      map['user_title'] = Variable<String>(userTitle.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (host.present) {
      map['host'] = Variable<String>(host.value);
    }
    if (seriesKey.present) {
      map['series_key'] = Variable<String>(seriesKey.value);
    }
    if (seriesUrl.present) {
      map['series_url'] = Variable<String>(seriesUrl.value);
    }
    if (identityBasis.present) {
      map['identity_basis'] = Variable<String>(identityBasis.value);
    }
    if (identityConfidence.present) {
      map['identity_confidence'] = Variable<String>(identityConfidence.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastOpenedAt.present) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt.value);
    }
    if (lastCapturedAt.present) {
      map['last_captured_at'] = Variable<DateTime>(lastCapturedAt.value);
    }
    if (lastOpenedChapterId.present) {
      map['last_opened_chapter_id'] = Variable<String>(
        lastOpenedChapterId.value,
      );
    }
    if (lastCompletedChapterId.present) {
      map['last_completed_chapter_id'] = Variable<String>(
        lastCompletedChapterId.value,
      );
    }
    if (lastReadAt.present) {
      map['last_read_at'] = Variable<DateTime>(lastReadAt.value);
    }
    if (lastCheckAt.present) {
      map['last_check_at'] = Variable<DateTime>(lastCheckAt.value);
    }
    if (lastCheckSuccessAt.present) {
      map['last_check_success_at'] = Variable<DateTime>(
        lastCheckSuccessAt.value,
      );
    }
    if (lastCheckError.present) {
      map['last_check_error'] = Variable<String>(lastCheckError.value);
    }
    if (lastCheckResult.present) {
      map['last_check_result'] = Variable<String>(lastCheckResult.value);
    }
    if (lifecycle.present) {
      map['lifecycle'] = Variable<String>(lifecycle.value);
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
    return (StringBuffer('LibraryItemsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('userTitle: $userTitle, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('host: $host, ')
          ..write('seriesKey: $seriesKey, ')
          ..write('seriesUrl: $seriesUrl, ')
          ..write('identityBasis: $identityBasis, ')
          ..write('identityConfidence: $identityConfidence, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('lastCapturedAt: $lastCapturedAt, ')
          ..write('lastOpenedChapterId: $lastOpenedChapterId, ')
          ..write('lastCompletedChapterId: $lastCompletedChapterId, ')
          ..write('lastReadAt: $lastReadAt, ')
          ..write('lastCheckAt: $lastCheckAt, ')
          ..write('lastCheckSuccessAt: $lastCheckSuccessAt, ')
          ..write('lastCheckError: $lastCheckError, ')
          ..write('lastCheckResult: $lastCheckResult, ')
          ..write('lifecycle: $lifecycle, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChaptersTable extends Chapters with TableInfo<$ChaptersTable, Chapter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChaptersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _libraryItemIdMeta = const VerificationMeta(
    'libraryItemId',
  );
  @override
  late final GeneratedColumn<String> libraryItemId = GeneratedColumn<String>(
    'library_item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES library_items (id)',
    ),
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
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlKeyMeta = const VerificationMeta('urlKey');
  @override
  late final GeneratedColumn<String> urlKey = GeneratedColumn<String>(
    'url_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _captureStatusMeta = const VerificationMeta(
    'captureStatus',
  );
  @override
  late final GeneratedColumn<String> captureStatus = GeneratedColumn<String>(
    'capture_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentPathMeta = const VerificationMeta(
    'contentPath',
  );
  @override
  late final GeneratedColumn<String> contentPath = GeneratedColumn<String>(
    'content_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<DateTime> capturedAt = GeneratedColumn<DateTime>(
    'captured_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detectedImageCountMeta =
      const VerificationMeta('detectedImageCount');
  @override
  late final GeneratedColumn<int> detectedImageCount = GeneratedColumn<int>(
    'detected_image_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _storedImageCountMeta = const VerificationMeta(
    'storedImageCount',
  );
  @override
  late final GeneratedColumn<int> storedImageCount = GeneratedColumn<int>(
    'stored_image_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextSourceUrlMeta = const VerificationMeta(
    'nextSourceUrl',
  );
  @override
  late final GeneratedColumn<String> nextSourceUrl = GeneratedColumn<String>(
    'next_source_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _captureErrorMeta = const VerificationMeta(
    'captureError',
  );
  @override
  late final GeneratedColumn<String> captureError = GeneratedColumn<String>(
    'capture_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _byteSizeMeta = const VerificationMeta(
    'byteSize',
  );
  @override
  late final GeneratedColumn<int> byteSize = GeneratedColumn<int>(
    'byte_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _chapterNumberMeta = const VerificationMeta(
    'chapterNumber',
  );
  @override
  late final GeneratedColumn<double> chapterNumber = GeneratedColumn<double>(
    'chapter_number',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _chapterLabelMeta = const VerificationMeta(
    'chapterLabel',
  );
  @override
  late final GeneratedColumn<String> chapterLabel = GeneratedColumn<String>(
    'chapter_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _readStatusMeta = const VerificationMeta(
    'readStatus',
  );
  @override
  late final GeneratedColumn<String> readStatus = GeneratedColumn<String>(
    'read_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unread'),
  );
  static const VerificationMeta _progressFractionMeta = const VerificationMeta(
    'progressFraction',
  );
  @override
  late final GeneratedColumn<double> progressFraction = GeneratedColumn<double>(
    'progress_fraction',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _progressImageIndexMeta =
      const VerificationMeta('progressImageIndex');
  @override
  late final GeneratedColumn<int> progressImageIndex = GeneratedColumn<int>(
    'progress_image_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _progressOffsetInImageMeta =
      const VerificationMeta('progressOffsetInImage');
  @override
  late final GeneratedColumn<double> progressOffsetInImage =
      GeneratedColumn<double>(
        'progress_offset_in_image',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _firstOpenedAtMeta = const VerificationMeta(
    'firstOpenedAt',
  );
  @override
  late final GeneratedColumn<DateTime> firstOpenedAt =
      GeneratedColumn<DateTime>(
        'first_opened_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastReadAtMeta = const VerificationMeta(
    'lastReadAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastReadAt = GeneratedColumn<DateTime>(
    'last_read_at',
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
  static const VerificationMeta _progressUpdatedAtMeta = const VerificationMeta(
    'progressUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> progressUpdatedAt =
      GeneratedColumn<DateTime>(
        'progress_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _discoveredAtMeta = const VerificationMeta(
    'discoveredAt',
  );
  @override
  late final GeneratedColumn<DateTime> discoveredAt = GeneratedColumn<DateTime>(
    'discovered_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _discoveryBasisMeta = const VerificationMeta(
    'discoveryBasis',
  );
  @override
  late final GeneratedColumn<String> discoveryBasis = GeneratedColumn<String>(
    'discovery_basis',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _discoveryConfidenceMeta =
      const VerificationMeta('discoveryConfidence');
  @override
  late final GeneratedColumn<String> discoveryConfidence =
      GeneratedColumn<String>(
        'discovery_confidence',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _offlineRemovedAtMeta = const VerificationMeta(
    'offlineRemovedAt',
  );
  @override
  late final GeneratedColumn<DateTime> offlineRemovedAt =
      GeneratedColumn<DateTime>(
        'offline_removed_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    libraryItemId,
    title,
    sourceUrl,
    urlKey,
    captureStatus,
    contentPath,
    capturedAt,
    detectedImageCount,
    storedImageCount,
    nextSourceUrl,
    sequence,
    captureError,
    byteSize,
    chapterNumber,
    chapterLabel,
    readStatus,
    progressFraction,
    progressImageIndex,
    progressOffsetInImage,
    firstOpenedAt,
    lastReadAt,
    completedAt,
    progressUpdatedAt,
    discoveredAt,
    discoveryBasis,
    discoveryConfidence,
    offlineRemovedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chapters';
  @override
  VerificationContext validateIntegrity(
    Insertable<Chapter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('library_item_id')) {
      context.handle(
        _libraryItemIdMeta,
        libraryItemId.isAcceptableOrUnknown(
          data['library_item_id']!,
          _libraryItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_libraryItemIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceUrlMeta);
    }
    if (data.containsKey('url_key')) {
      context.handle(
        _urlKeyMeta,
        urlKey.isAcceptableOrUnknown(data['url_key']!, _urlKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_urlKeyMeta);
    }
    if (data.containsKey('capture_status')) {
      context.handle(
        _captureStatusMeta,
        captureStatus.isAcceptableOrUnknown(
          data['capture_status']!,
          _captureStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_captureStatusMeta);
    }
    if (data.containsKey('content_path')) {
      context.handle(
        _contentPathMeta,
        contentPath.isAcceptableOrUnknown(
          data['content_path']!,
          _contentPathMeta,
        ),
      );
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    }
    if (data.containsKey('detected_image_count')) {
      context.handle(
        _detectedImageCountMeta,
        detectedImageCount.isAcceptableOrUnknown(
          data['detected_image_count']!,
          _detectedImageCountMeta,
        ),
      );
    }
    if (data.containsKey('stored_image_count')) {
      context.handle(
        _storedImageCountMeta,
        storedImageCount.isAcceptableOrUnknown(
          data['stored_image_count']!,
          _storedImageCountMeta,
        ),
      );
    }
    if (data.containsKey('next_source_url')) {
      context.handle(
        _nextSourceUrlMeta,
        nextSourceUrl.isAcceptableOrUnknown(
          data['next_source_url']!,
          _nextSourceUrlMeta,
        ),
      );
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    }
    if (data.containsKey('capture_error')) {
      context.handle(
        _captureErrorMeta,
        captureError.isAcceptableOrUnknown(
          data['capture_error']!,
          _captureErrorMeta,
        ),
      );
    }
    if (data.containsKey('byte_size')) {
      context.handle(
        _byteSizeMeta,
        byteSize.isAcceptableOrUnknown(data['byte_size']!, _byteSizeMeta),
      );
    }
    if (data.containsKey('chapter_number')) {
      context.handle(
        _chapterNumberMeta,
        chapterNumber.isAcceptableOrUnknown(
          data['chapter_number']!,
          _chapterNumberMeta,
        ),
      );
    }
    if (data.containsKey('chapter_label')) {
      context.handle(
        _chapterLabelMeta,
        chapterLabel.isAcceptableOrUnknown(
          data['chapter_label']!,
          _chapterLabelMeta,
        ),
      );
    }
    if (data.containsKey('read_status')) {
      context.handle(
        _readStatusMeta,
        readStatus.isAcceptableOrUnknown(data['read_status']!, _readStatusMeta),
      );
    }
    if (data.containsKey('progress_fraction')) {
      context.handle(
        _progressFractionMeta,
        progressFraction.isAcceptableOrUnknown(
          data['progress_fraction']!,
          _progressFractionMeta,
        ),
      );
    }
    if (data.containsKey('progress_image_index')) {
      context.handle(
        _progressImageIndexMeta,
        progressImageIndex.isAcceptableOrUnknown(
          data['progress_image_index']!,
          _progressImageIndexMeta,
        ),
      );
    }
    if (data.containsKey('progress_offset_in_image')) {
      context.handle(
        _progressOffsetInImageMeta,
        progressOffsetInImage.isAcceptableOrUnknown(
          data['progress_offset_in_image']!,
          _progressOffsetInImageMeta,
        ),
      );
    }
    if (data.containsKey('first_opened_at')) {
      context.handle(
        _firstOpenedAtMeta,
        firstOpenedAt.isAcceptableOrUnknown(
          data['first_opened_at']!,
          _firstOpenedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_read_at')) {
      context.handle(
        _lastReadAtMeta,
        lastReadAt.isAcceptableOrUnknown(
          data['last_read_at']!,
          _lastReadAtMeta,
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
    if (data.containsKey('progress_updated_at')) {
      context.handle(
        _progressUpdatedAtMeta,
        progressUpdatedAt.isAcceptableOrUnknown(
          data['progress_updated_at']!,
          _progressUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('discovered_at')) {
      context.handle(
        _discoveredAtMeta,
        discoveredAt.isAcceptableOrUnknown(
          data['discovered_at']!,
          _discoveredAtMeta,
        ),
      );
    }
    if (data.containsKey('discovery_basis')) {
      context.handle(
        _discoveryBasisMeta,
        discoveryBasis.isAcceptableOrUnknown(
          data['discovery_basis']!,
          _discoveryBasisMeta,
        ),
      );
    }
    if (data.containsKey('discovery_confidence')) {
      context.handle(
        _discoveryConfidenceMeta,
        discoveryConfidence.isAcceptableOrUnknown(
          data['discovery_confidence']!,
          _discoveryConfidenceMeta,
        ),
      );
    }
    if (data.containsKey('offline_removed_at')) {
      context.handle(
        _offlineRemovedAtMeta,
        offlineRemovedAt.isAcceptableOrUnknown(
          data['offline_removed_at']!,
          _offlineRemovedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {libraryItemId, urlKey},
  ];
  @override
  Chapter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Chapter(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      libraryItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}library_item_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      )!,
      urlKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url_key'],
      )!,
      captureStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capture_status'],
      )!,
      contentPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_path'],
      ),
      capturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}captured_at'],
      ),
      detectedImageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}detected_image_count'],
      )!,
      storedImageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stored_image_count'],
      )!,
      nextSourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}next_source_url'],
      ),
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      )!,
      captureError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capture_error'],
      ),
      byteSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_size'],
      )!,
      chapterNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}chapter_number'],
      ),
      chapterLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_label'],
      ),
      readStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}read_status'],
      )!,
      progressFraction: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress_fraction'],
      )!,
      progressImageIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}progress_image_index'],
      )!,
      progressOffsetInImage: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress_offset_in_image'],
      )!,
      firstOpenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}first_opened_at'],
      ),
      lastReadAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_read_at'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      progressUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}progress_updated_at'],
      ),
      discoveredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}discovered_at'],
      ),
      discoveryBasis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}discovery_basis'],
      ),
      discoveryConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}discovery_confidence'],
      ),
      offlineRemovedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}offline_removed_at'],
      ),
    );
  }

  @override
  $ChaptersTable createAlias(String alias) {
    return $ChaptersTable(attachedDatabase, alias);
  }
}

class Chapter extends DataClass implements Insertable<Chapter> {
  final String id;
  final String libraryItemId;
  final String title;
  final String sourceUrl;

  /// Normalised URL — identity. Unique per library item, which is what makes
  /// duplicate chapters impossible rather than merely unlikely.
  final String urlKey;
  final String captureStatus;

  /// Relative to the FileStore root. Never absolute.
  final String? contentPath;
  final DateTime? capturedAt;
  final int detectedImageCount;
  final int storedImageCount;
  final String? nextSourceUrl;
  final int sequence;
  final String? captureError;
  final int byteSize;

  /// Parsed chapter number. `REAL` so `12.5` works; null for identifiers that
  /// are not numeric at all, which fall back to capture order.
  final double? chapterNumber;

  /// Short display identifier: "Bölüm 883", "Chapter 101".
  final String? chapterLabel;
  final String readStatus;

  /// 0..1 through the chapter. The durable half of the position — content
  /// independent, so it still means something after a re-download.
  final double progressFraction;

  /// Anchor: panel index plus how far down it. Precise but goes stale if the
  /// panel count changes, which is what the fraction covers.
  final int progressImageIndex;
  final double progressOffsetInImage;
  final DateTime? firstOpenedAt;
  final DateTime? lastReadAt;
  final DateTime? completedAt;
  final DateTime? progressUpdatedAt;

  /// When an update check first saw this chapter on the source.
  final DateTime? discoveredAt;

  /// Which discovery strategy found it (chapterList / nextChain / savedRule).
  final String? discoveryBasis;

  /// Confidence of that discovery (high / medium / low).
  final String? discoveryConfidence;

  /// When the USER removed this chapter's offline files ("free up space").
  /// Distinct from files the system lost: a removed chapter renders as
  /// "not available offline — capture again", never as an error. Cleared on
  /// re-capture.
  final DateTime? offlineRemovedAt;
  const Chapter({
    required this.id,
    required this.libraryItemId,
    required this.title,
    required this.sourceUrl,
    required this.urlKey,
    required this.captureStatus,
    this.contentPath,
    this.capturedAt,
    required this.detectedImageCount,
    required this.storedImageCount,
    this.nextSourceUrl,
    required this.sequence,
    this.captureError,
    required this.byteSize,
    this.chapterNumber,
    this.chapterLabel,
    required this.readStatus,
    required this.progressFraction,
    required this.progressImageIndex,
    required this.progressOffsetInImage,
    this.firstOpenedAt,
    this.lastReadAt,
    this.completedAt,
    this.progressUpdatedAt,
    this.discoveredAt,
    this.discoveryBasis,
    this.discoveryConfidence,
    this.offlineRemovedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['library_item_id'] = Variable<String>(libraryItemId);
    map['title'] = Variable<String>(title);
    map['source_url'] = Variable<String>(sourceUrl);
    map['url_key'] = Variable<String>(urlKey);
    map['capture_status'] = Variable<String>(captureStatus);
    if (!nullToAbsent || contentPath != null) {
      map['content_path'] = Variable<String>(contentPath);
    }
    if (!nullToAbsent || capturedAt != null) {
      map['captured_at'] = Variable<DateTime>(capturedAt);
    }
    map['detected_image_count'] = Variable<int>(detectedImageCount);
    map['stored_image_count'] = Variable<int>(storedImageCount);
    if (!nullToAbsent || nextSourceUrl != null) {
      map['next_source_url'] = Variable<String>(nextSourceUrl);
    }
    map['sequence'] = Variable<int>(sequence);
    if (!nullToAbsent || captureError != null) {
      map['capture_error'] = Variable<String>(captureError);
    }
    map['byte_size'] = Variable<int>(byteSize);
    if (!nullToAbsent || chapterNumber != null) {
      map['chapter_number'] = Variable<double>(chapterNumber);
    }
    if (!nullToAbsent || chapterLabel != null) {
      map['chapter_label'] = Variable<String>(chapterLabel);
    }
    map['read_status'] = Variable<String>(readStatus);
    map['progress_fraction'] = Variable<double>(progressFraction);
    map['progress_image_index'] = Variable<int>(progressImageIndex);
    map['progress_offset_in_image'] = Variable<double>(progressOffsetInImage);
    if (!nullToAbsent || firstOpenedAt != null) {
      map['first_opened_at'] = Variable<DateTime>(firstOpenedAt);
    }
    if (!nullToAbsent || lastReadAt != null) {
      map['last_read_at'] = Variable<DateTime>(lastReadAt);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || progressUpdatedAt != null) {
      map['progress_updated_at'] = Variable<DateTime>(progressUpdatedAt);
    }
    if (!nullToAbsent || discoveredAt != null) {
      map['discovered_at'] = Variable<DateTime>(discoveredAt);
    }
    if (!nullToAbsent || discoveryBasis != null) {
      map['discovery_basis'] = Variable<String>(discoveryBasis);
    }
    if (!nullToAbsent || discoveryConfidence != null) {
      map['discovery_confidence'] = Variable<String>(discoveryConfidence);
    }
    if (!nullToAbsent || offlineRemovedAt != null) {
      map['offline_removed_at'] = Variable<DateTime>(offlineRemovedAt);
    }
    return map;
  }

  ChaptersCompanion toCompanion(bool nullToAbsent) {
    return ChaptersCompanion(
      id: Value(id),
      libraryItemId: Value(libraryItemId),
      title: Value(title),
      sourceUrl: Value(sourceUrl),
      urlKey: Value(urlKey),
      captureStatus: Value(captureStatus),
      contentPath: contentPath == null && nullToAbsent
          ? const Value.absent()
          : Value(contentPath),
      capturedAt: capturedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(capturedAt),
      detectedImageCount: Value(detectedImageCount),
      storedImageCount: Value(storedImageCount),
      nextSourceUrl: nextSourceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(nextSourceUrl),
      sequence: Value(sequence),
      captureError: captureError == null && nullToAbsent
          ? const Value.absent()
          : Value(captureError),
      byteSize: Value(byteSize),
      chapterNumber: chapterNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(chapterNumber),
      chapterLabel: chapterLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(chapterLabel),
      readStatus: Value(readStatus),
      progressFraction: Value(progressFraction),
      progressImageIndex: Value(progressImageIndex),
      progressOffsetInImage: Value(progressOffsetInImage),
      firstOpenedAt: firstOpenedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(firstOpenedAt),
      lastReadAt: lastReadAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReadAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      progressUpdatedAt: progressUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(progressUpdatedAt),
      discoveredAt: discoveredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(discoveredAt),
      discoveryBasis: discoveryBasis == null && nullToAbsent
          ? const Value.absent()
          : Value(discoveryBasis),
      discoveryConfidence: discoveryConfidence == null && nullToAbsent
          ? const Value.absent()
          : Value(discoveryConfidence),
      offlineRemovedAt: offlineRemovedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(offlineRemovedAt),
    );
  }

  factory Chapter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Chapter(
      id: serializer.fromJson<String>(json['id']),
      libraryItemId: serializer.fromJson<String>(json['libraryItemId']),
      title: serializer.fromJson<String>(json['title']),
      sourceUrl: serializer.fromJson<String>(json['sourceUrl']),
      urlKey: serializer.fromJson<String>(json['urlKey']),
      captureStatus: serializer.fromJson<String>(json['captureStatus']),
      contentPath: serializer.fromJson<String?>(json['contentPath']),
      capturedAt: serializer.fromJson<DateTime?>(json['capturedAt']),
      detectedImageCount: serializer.fromJson<int>(json['detectedImageCount']),
      storedImageCount: serializer.fromJson<int>(json['storedImageCount']),
      nextSourceUrl: serializer.fromJson<String?>(json['nextSourceUrl']),
      sequence: serializer.fromJson<int>(json['sequence']),
      captureError: serializer.fromJson<String?>(json['captureError']),
      byteSize: serializer.fromJson<int>(json['byteSize']),
      chapterNumber: serializer.fromJson<double?>(json['chapterNumber']),
      chapterLabel: serializer.fromJson<String?>(json['chapterLabel']),
      readStatus: serializer.fromJson<String>(json['readStatus']),
      progressFraction: serializer.fromJson<double>(json['progressFraction']),
      progressImageIndex: serializer.fromJson<int>(json['progressImageIndex']),
      progressOffsetInImage: serializer.fromJson<double>(
        json['progressOffsetInImage'],
      ),
      firstOpenedAt: serializer.fromJson<DateTime?>(json['firstOpenedAt']),
      lastReadAt: serializer.fromJson<DateTime?>(json['lastReadAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      progressUpdatedAt: serializer.fromJson<DateTime?>(
        json['progressUpdatedAt'],
      ),
      discoveredAt: serializer.fromJson<DateTime?>(json['discoveredAt']),
      discoveryBasis: serializer.fromJson<String?>(json['discoveryBasis']),
      discoveryConfidence: serializer.fromJson<String?>(
        json['discoveryConfidence'],
      ),
      offlineRemovedAt: serializer.fromJson<DateTime?>(
        json['offlineRemovedAt'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'libraryItemId': serializer.toJson<String>(libraryItemId),
      'title': serializer.toJson<String>(title),
      'sourceUrl': serializer.toJson<String>(sourceUrl),
      'urlKey': serializer.toJson<String>(urlKey),
      'captureStatus': serializer.toJson<String>(captureStatus),
      'contentPath': serializer.toJson<String?>(contentPath),
      'capturedAt': serializer.toJson<DateTime?>(capturedAt),
      'detectedImageCount': serializer.toJson<int>(detectedImageCount),
      'storedImageCount': serializer.toJson<int>(storedImageCount),
      'nextSourceUrl': serializer.toJson<String?>(nextSourceUrl),
      'sequence': serializer.toJson<int>(sequence),
      'captureError': serializer.toJson<String?>(captureError),
      'byteSize': serializer.toJson<int>(byteSize),
      'chapterNumber': serializer.toJson<double?>(chapterNumber),
      'chapterLabel': serializer.toJson<String?>(chapterLabel),
      'readStatus': serializer.toJson<String>(readStatus),
      'progressFraction': serializer.toJson<double>(progressFraction),
      'progressImageIndex': serializer.toJson<int>(progressImageIndex),
      'progressOffsetInImage': serializer.toJson<double>(progressOffsetInImage),
      'firstOpenedAt': serializer.toJson<DateTime?>(firstOpenedAt),
      'lastReadAt': serializer.toJson<DateTime?>(lastReadAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'progressUpdatedAt': serializer.toJson<DateTime?>(progressUpdatedAt),
      'discoveredAt': serializer.toJson<DateTime?>(discoveredAt),
      'discoveryBasis': serializer.toJson<String?>(discoveryBasis),
      'discoveryConfidence': serializer.toJson<String?>(discoveryConfidence),
      'offlineRemovedAt': serializer.toJson<DateTime?>(offlineRemovedAt),
    };
  }

  Chapter copyWith({
    String? id,
    String? libraryItemId,
    String? title,
    String? sourceUrl,
    String? urlKey,
    String? captureStatus,
    Value<String?> contentPath = const Value.absent(),
    Value<DateTime?> capturedAt = const Value.absent(),
    int? detectedImageCount,
    int? storedImageCount,
    Value<String?> nextSourceUrl = const Value.absent(),
    int? sequence,
    Value<String?> captureError = const Value.absent(),
    int? byteSize,
    Value<double?> chapterNumber = const Value.absent(),
    Value<String?> chapterLabel = const Value.absent(),
    String? readStatus,
    double? progressFraction,
    int? progressImageIndex,
    double? progressOffsetInImage,
    Value<DateTime?> firstOpenedAt = const Value.absent(),
    Value<DateTime?> lastReadAt = const Value.absent(),
    Value<DateTime?> completedAt = const Value.absent(),
    Value<DateTime?> progressUpdatedAt = const Value.absent(),
    Value<DateTime?> discoveredAt = const Value.absent(),
    Value<String?> discoveryBasis = const Value.absent(),
    Value<String?> discoveryConfidence = const Value.absent(),
    Value<DateTime?> offlineRemovedAt = const Value.absent(),
  }) => Chapter(
    id: id ?? this.id,
    libraryItemId: libraryItemId ?? this.libraryItemId,
    title: title ?? this.title,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    urlKey: urlKey ?? this.urlKey,
    captureStatus: captureStatus ?? this.captureStatus,
    contentPath: contentPath.present ? contentPath.value : this.contentPath,
    capturedAt: capturedAt.present ? capturedAt.value : this.capturedAt,
    detectedImageCount: detectedImageCount ?? this.detectedImageCount,
    storedImageCount: storedImageCount ?? this.storedImageCount,
    nextSourceUrl: nextSourceUrl.present
        ? nextSourceUrl.value
        : this.nextSourceUrl,
    sequence: sequence ?? this.sequence,
    captureError: captureError.present ? captureError.value : this.captureError,
    byteSize: byteSize ?? this.byteSize,
    chapterNumber: chapterNumber.present
        ? chapterNumber.value
        : this.chapterNumber,
    chapterLabel: chapterLabel.present ? chapterLabel.value : this.chapterLabel,
    readStatus: readStatus ?? this.readStatus,
    progressFraction: progressFraction ?? this.progressFraction,
    progressImageIndex: progressImageIndex ?? this.progressImageIndex,
    progressOffsetInImage: progressOffsetInImage ?? this.progressOffsetInImage,
    firstOpenedAt: firstOpenedAt.present
        ? firstOpenedAt.value
        : this.firstOpenedAt,
    lastReadAt: lastReadAt.present ? lastReadAt.value : this.lastReadAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    progressUpdatedAt: progressUpdatedAt.present
        ? progressUpdatedAt.value
        : this.progressUpdatedAt,
    discoveredAt: discoveredAt.present ? discoveredAt.value : this.discoveredAt,
    discoveryBasis: discoveryBasis.present
        ? discoveryBasis.value
        : this.discoveryBasis,
    discoveryConfidence: discoveryConfidence.present
        ? discoveryConfidence.value
        : this.discoveryConfidence,
    offlineRemovedAt: offlineRemovedAt.present
        ? offlineRemovedAt.value
        : this.offlineRemovedAt,
  );
  Chapter copyWithCompanion(ChaptersCompanion data) {
    return Chapter(
      id: data.id.present ? data.id.value : this.id,
      libraryItemId: data.libraryItemId.present
          ? data.libraryItemId.value
          : this.libraryItemId,
      title: data.title.present ? data.title.value : this.title,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      urlKey: data.urlKey.present ? data.urlKey.value : this.urlKey,
      captureStatus: data.captureStatus.present
          ? data.captureStatus.value
          : this.captureStatus,
      contentPath: data.contentPath.present
          ? data.contentPath.value
          : this.contentPath,
      capturedAt: data.capturedAt.present
          ? data.capturedAt.value
          : this.capturedAt,
      detectedImageCount: data.detectedImageCount.present
          ? data.detectedImageCount.value
          : this.detectedImageCount,
      storedImageCount: data.storedImageCount.present
          ? data.storedImageCount.value
          : this.storedImageCount,
      nextSourceUrl: data.nextSourceUrl.present
          ? data.nextSourceUrl.value
          : this.nextSourceUrl,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      captureError: data.captureError.present
          ? data.captureError.value
          : this.captureError,
      byteSize: data.byteSize.present ? data.byteSize.value : this.byteSize,
      chapterNumber: data.chapterNumber.present
          ? data.chapterNumber.value
          : this.chapterNumber,
      chapterLabel: data.chapterLabel.present
          ? data.chapterLabel.value
          : this.chapterLabel,
      readStatus: data.readStatus.present
          ? data.readStatus.value
          : this.readStatus,
      progressFraction: data.progressFraction.present
          ? data.progressFraction.value
          : this.progressFraction,
      progressImageIndex: data.progressImageIndex.present
          ? data.progressImageIndex.value
          : this.progressImageIndex,
      progressOffsetInImage: data.progressOffsetInImage.present
          ? data.progressOffsetInImage.value
          : this.progressOffsetInImage,
      firstOpenedAt: data.firstOpenedAt.present
          ? data.firstOpenedAt.value
          : this.firstOpenedAt,
      lastReadAt: data.lastReadAt.present
          ? data.lastReadAt.value
          : this.lastReadAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      progressUpdatedAt: data.progressUpdatedAt.present
          ? data.progressUpdatedAt.value
          : this.progressUpdatedAt,
      discoveredAt: data.discoveredAt.present
          ? data.discoveredAt.value
          : this.discoveredAt,
      discoveryBasis: data.discoveryBasis.present
          ? data.discoveryBasis.value
          : this.discoveryBasis,
      discoveryConfidence: data.discoveryConfidence.present
          ? data.discoveryConfidence.value
          : this.discoveryConfidence,
      offlineRemovedAt: data.offlineRemovedAt.present
          ? data.offlineRemovedAt.value
          : this.offlineRemovedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Chapter(')
          ..write('id: $id, ')
          ..write('libraryItemId: $libraryItemId, ')
          ..write('title: $title, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('urlKey: $urlKey, ')
          ..write('captureStatus: $captureStatus, ')
          ..write('contentPath: $contentPath, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('detectedImageCount: $detectedImageCount, ')
          ..write('storedImageCount: $storedImageCount, ')
          ..write('nextSourceUrl: $nextSourceUrl, ')
          ..write('sequence: $sequence, ')
          ..write('captureError: $captureError, ')
          ..write('byteSize: $byteSize, ')
          ..write('chapterNumber: $chapterNumber, ')
          ..write('chapterLabel: $chapterLabel, ')
          ..write('readStatus: $readStatus, ')
          ..write('progressFraction: $progressFraction, ')
          ..write('progressImageIndex: $progressImageIndex, ')
          ..write('progressOffsetInImage: $progressOffsetInImage, ')
          ..write('firstOpenedAt: $firstOpenedAt, ')
          ..write('lastReadAt: $lastReadAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('progressUpdatedAt: $progressUpdatedAt, ')
          ..write('discoveredAt: $discoveredAt, ')
          ..write('discoveryBasis: $discoveryBasis, ')
          ..write('discoveryConfidence: $discoveryConfidence, ')
          ..write('offlineRemovedAt: $offlineRemovedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    libraryItemId,
    title,
    sourceUrl,
    urlKey,
    captureStatus,
    contentPath,
    capturedAt,
    detectedImageCount,
    storedImageCount,
    nextSourceUrl,
    sequence,
    captureError,
    byteSize,
    chapterNumber,
    chapterLabel,
    readStatus,
    progressFraction,
    progressImageIndex,
    progressOffsetInImage,
    firstOpenedAt,
    lastReadAt,
    completedAt,
    progressUpdatedAt,
    discoveredAt,
    discoveryBasis,
    discoveryConfidence,
    offlineRemovedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Chapter &&
          other.id == this.id &&
          other.libraryItemId == this.libraryItemId &&
          other.title == this.title &&
          other.sourceUrl == this.sourceUrl &&
          other.urlKey == this.urlKey &&
          other.captureStatus == this.captureStatus &&
          other.contentPath == this.contentPath &&
          other.capturedAt == this.capturedAt &&
          other.detectedImageCount == this.detectedImageCount &&
          other.storedImageCount == this.storedImageCount &&
          other.nextSourceUrl == this.nextSourceUrl &&
          other.sequence == this.sequence &&
          other.captureError == this.captureError &&
          other.byteSize == this.byteSize &&
          other.chapterNumber == this.chapterNumber &&
          other.chapterLabel == this.chapterLabel &&
          other.readStatus == this.readStatus &&
          other.progressFraction == this.progressFraction &&
          other.progressImageIndex == this.progressImageIndex &&
          other.progressOffsetInImage == this.progressOffsetInImage &&
          other.firstOpenedAt == this.firstOpenedAt &&
          other.lastReadAt == this.lastReadAt &&
          other.completedAt == this.completedAt &&
          other.progressUpdatedAt == this.progressUpdatedAt &&
          other.discoveredAt == this.discoveredAt &&
          other.discoveryBasis == this.discoveryBasis &&
          other.discoveryConfidence == this.discoveryConfidence &&
          other.offlineRemovedAt == this.offlineRemovedAt);
}

class ChaptersCompanion extends UpdateCompanion<Chapter> {
  final Value<String> id;
  final Value<String> libraryItemId;
  final Value<String> title;
  final Value<String> sourceUrl;
  final Value<String> urlKey;
  final Value<String> captureStatus;
  final Value<String?> contentPath;
  final Value<DateTime?> capturedAt;
  final Value<int> detectedImageCount;
  final Value<int> storedImageCount;
  final Value<String?> nextSourceUrl;
  final Value<int> sequence;
  final Value<String?> captureError;
  final Value<int> byteSize;
  final Value<double?> chapterNumber;
  final Value<String?> chapterLabel;
  final Value<String> readStatus;
  final Value<double> progressFraction;
  final Value<int> progressImageIndex;
  final Value<double> progressOffsetInImage;
  final Value<DateTime?> firstOpenedAt;
  final Value<DateTime?> lastReadAt;
  final Value<DateTime?> completedAt;
  final Value<DateTime?> progressUpdatedAt;
  final Value<DateTime?> discoveredAt;
  final Value<String?> discoveryBasis;
  final Value<String?> discoveryConfidence;
  final Value<DateTime?> offlineRemovedAt;
  final Value<int> rowid;
  const ChaptersCompanion({
    this.id = const Value.absent(),
    this.libraryItemId = const Value.absent(),
    this.title = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.urlKey = const Value.absent(),
    this.captureStatus = const Value.absent(),
    this.contentPath = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.detectedImageCount = const Value.absent(),
    this.storedImageCount = const Value.absent(),
    this.nextSourceUrl = const Value.absent(),
    this.sequence = const Value.absent(),
    this.captureError = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.chapterNumber = const Value.absent(),
    this.chapterLabel = const Value.absent(),
    this.readStatus = const Value.absent(),
    this.progressFraction = const Value.absent(),
    this.progressImageIndex = const Value.absent(),
    this.progressOffsetInImage = const Value.absent(),
    this.firstOpenedAt = const Value.absent(),
    this.lastReadAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.progressUpdatedAt = const Value.absent(),
    this.discoveredAt = const Value.absent(),
    this.discoveryBasis = const Value.absent(),
    this.discoveryConfidence = const Value.absent(),
    this.offlineRemovedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChaptersCompanion.insert({
    required String id,
    required String libraryItemId,
    required String title,
    required String sourceUrl,
    required String urlKey,
    required String captureStatus,
    this.contentPath = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.detectedImageCount = const Value.absent(),
    this.storedImageCount = const Value.absent(),
    this.nextSourceUrl = const Value.absent(),
    this.sequence = const Value.absent(),
    this.captureError = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.chapterNumber = const Value.absent(),
    this.chapterLabel = const Value.absent(),
    this.readStatus = const Value.absent(),
    this.progressFraction = const Value.absent(),
    this.progressImageIndex = const Value.absent(),
    this.progressOffsetInImage = const Value.absent(),
    this.firstOpenedAt = const Value.absent(),
    this.lastReadAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.progressUpdatedAt = const Value.absent(),
    this.discoveredAt = const Value.absent(),
    this.discoveryBasis = const Value.absent(),
    this.discoveryConfidence = const Value.absent(),
    this.offlineRemovedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       libraryItemId = Value(libraryItemId),
       title = Value(title),
       sourceUrl = Value(sourceUrl),
       urlKey = Value(urlKey),
       captureStatus = Value(captureStatus);
  static Insertable<Chapter> custom({
    Expression<String>? id,
    Expression<String>? libraryItemId,
    Expression<String>? title,
    Expression<String>? sourceUrl,
    Expression<String>? urlKey,
    Expression<String>? captureStatus,
    Expression<String>? contentPath,
    Expression<DateTime>? capturedAt,
    Expression<int>? detectedImageCount,
    Expression<int>? storedImageCount,
    Expression<String>? nextSourceUrl,
    Expression<int>? sequence,
    Expression<String>? captureError,
    Expression<int>? byteSize,
    Expression<double>? chapterNumber,
    Expression<String>? chapterLabel,
    Expression<String>? readStatus,
    Expression<double>? progressFraction,
    Expression<int>? progressImageIndex,
    Expression<double>? progressOffsetInImage,
    Expression<DateTime>? firstOpenedAt,
    Expression<DateTime>? lastReadAt,
    Expression<DateTime>? completedAt,
    Expression<DateTime>? progressUpdatedAt,
    Expression<DateTime>? discoveredAt,
    Expression<String>? discoveryBasis,
    Expression<String>? discoveryConfidence,
    Expression<DateTime>? offlineRemovedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (libraryItemId != null) 'library_item_id': libraryItemId,
      if (title != null) 'title': title,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (urlKey != null) 'url_key': urlKey,
      if (captureStatus != null) 'capture_status': captureStatus,
      if (contentPath != null) 'content_path': contentPath,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (detectedImageCount != null)
        'detected_image_count': detectedImageCount,
      if (storedImageCount != null) 'stored_image_count': storedImageCount,
      if (nextSourceUrl != null) 'next_source_url': nextSourceUrl,
      if (sequence != null) 'sequence': sequence,
      if (captureError != null) 'capture_error': captureError,
      if (byteSize != null) 'byte_size': byteSize,
      if (chapterNumber != null) 'chapter_number': chapterNumber,
      if (chapterLabel != null) 'chapter_label': chapterLabel,
      if (readStatus != null) 'read_status': readStatus,
      if (progressFraction != null) 'progress_fraction': progressFraction,
      if (progressImageIndex != null)
        'progress_image_index': progressImageIndex,
      if (progressOffsetInImage != null)
        'progress_offset_in_image': progressOffsetInImage,
      if (firstOpenedAt != null) 'first_opened_at': firstOpenedAt,
      if (lastReadAt != null) 'last_read_at': lastReadAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (progressUpdatedAt != null) 'progress_updated_at': progressUpdatedAt,
      if (discoveredAt != null) 'discovered_at': discoveredAt,
      if (discoveryBasis != null) 'discovery_basis': discoveryBasis,
      if (discoveryConfidence != null)
        'discovery_confidence': discoveryConfidence,
      if (offlineRemovedAt != null) 'offline_removed_at': offlineRemovedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChaptersCompanion copyWith({
    Value<String>? id,
    Value<String>? libraryItemId,
    Value<String>? title,
    Value<String>? sourceUrl,
    Value<String>? urlKey,
    Value<String>? captureStatus,
    Value<String?>? contentPath,
    Value<DateTime?>? capturedAt,
    Value<int>? detectedImageCount,
    Value<int>? storedImageCount,
    Value<String?>? nextSourceUrl,
    Value<int>? sequence,
    Value<String?>? captureError,
    Value<int>? byteSize,
    Value<double?>? chapterNumber,
    Value<String?>? chapterLabel,
    Value<String>? readStatus,
    Value<double>? progressFraction,
    Value<int>? progressImageIndex,
    Value<double>? progressOffsetInImage,
    Value<DateTime?>? firstOpenedAt,
    Value<DateTime?>? lastReadAt,
    Value<DateTime?>? completedAt,
    Value<DateTime?>? progressUpdatedAt,
    Value<DateTime?>? discoveredAt,
    Value<String?>? discoveryBasis,
    Value<String?>? discoveryConfidence,
    Value<DateTime?>? offlineRemovedAt,
    Value<int>? rowid,
  }) {
    return ChaptersCompanion(
      id: id ?? this.id,
      libraryItemId: libraryItemId ?? this.libraryItemId,
      title: title ?? this.title,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      urlKey: urlKey ?? this.urlKey,
      captureStatus: captureStatus ?? this.captureStatus,
      contentPath: contentPath ?? this.contentPath,
      capturedAt: capturedAt ?? this.capturedAt,
      detectedImageCount: detectedImageCount ?? this.detectedImageCount,
      storedImageCount: storedImageCount ?? this.storedImageCount,
      nextSourceUrl: nextSourceUrl ?? this.nextSourceUrl,
      sequence: sequence ?? this.sequence,
      captureError: captureError ?? this.captureError,
      byteSize: byteSize ?? this.byteSize,
      chapterNumber: chapterNumber ?? this.chapterNumber,
      chapterLabel: chapterLabel ?? this.chapterLabel,
      readStatus: readStatus ?? this.readStatus,
      progressFraction: progressFraction ?? this.progressFraction,
      progressImageIndex: progressImageIndex ?? this.progressImageIndex,
      progressOffsetInImage:
          progressOffsetInImage ?? this.progressOffsetInImage,
      firstOpenedAt: firstOpenedAt ?? this.firstOpenedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      completedAt: completedAt ?? this.completedAt,
      progressUpdatedAt: progressUpdatedAt ?? this.progressUpdatedAt,
      discoveredAt: discoveredAt ?? this.discoveredAt,
      discoveryBasis: discoveryBasis ?? this.discoveryBasis,
      discoveryConfidence: discoveryConfidence ?? this.discoveryConfidence,
      offlineRemovedAt: offlineRemovedAt ?? this.offlineRemovedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (libraryItemId.present) {
      map['library_item_id'] = Variable<String>(libraryItemId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (urlKey.present) {
      map['url_key'] = Variable<String>(urlKey.value);
    }
    if (captureStatus.present) {
      map['capture_status'] = Variable<String>(captureStatus.value);
    }
    if (contentPath.present) {
      map['content_path'] = Variable<String>(contentPath.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<DateTime>(capturedAt.value);
    }
    if (detectedImageCount.present) {
      map['detected_image_count'] = Variable<int>(detectedImageCount.value);
    }
    if (storedImageCount.present) {
      map['stored_image_count'] = Variable<int>(storedImageCount.value);
    }
    if (nextSourceUrl.present) {
      map['next_source_url'] = Variable<String>(nextSourceUrl.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (captureError.present) {
      map['capture_error'] = Variable<String>(captureError.value);
    }
    if (byteSize.present) {
      map['byte_size'] = Variable<int>(byteSize.value);
    }
    if (chapterNumber.present) {
      map['chapter_number'] = Variable<double>(chapterNumber.value);
    }
    if (chapterLabel.present) {
      map['chapter_label'] = Variable<String>(chapterLabel.value);
    }
    if (readStatus.present) {
      map['read_status'] = Variable<String>(readStatus.value);
    }
    if (progressFraction.present) {
      map['progress_fraction'] = Variable<double>(progressFraction.value);
    }
    if (progressImageIndex.present) {
      map['progress_image_index'] = Variable<int>(progressImageIndex.value);
    }
    if (progressOffsetInImage.present) {
      map['progress_offset_in_image'] = Variable<double>(
        progressOffsetInImage.value,
      );
    }
    if (firstOpenedAt.present) {
      map['first_opened_at'] = Variable<DateTime>(firstOpenedAt.value);
    }
    if (lastReadAt.present) {
      map['last_read_at'] = Variable<DateTime>(lastReadAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (progressUpdatedAt.present) {
      map['progress_updated_at'] = Variable<DateTime>(progressUpdatedAt.value);
    }
    if (discoveredAt.present) {
      map['discovered_at'] = Variable<DateTime>(discoveredAt.value);
    }
    if (discoveryBasis.present) {
      map['discovery_basis'] = Variable<String>(discoveryBasis.value);
    }
    if (discoveryConfidence.present) {
      map['discovery_confidence'] = Variable<String>(discoveryConfidence.value);
    }
    if (offlineRemovedAt.present) {
      map['offline_removed_at'] = Variable<DateTime>(offlineRemovedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChaptersCompanion(')
          ..write('id: $id, ')
          ..write('libraryItemId: $libraryItemId, ')
          ..write('title: $title, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('urlKey: $urlKey, ')
          ..write('captureStatus: $captureStatus, ')
          ..write('contentPath: $contentPath, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('detectedImageCount: $detectedImageCount, ')
          ..write('storedImageCount: $storedImageCount, ')
          ..write('nextSourceUrl: $nextSourceUrl, ')
          ..write('sequence: $sequence, ')
          ..write('captureError: $captureError, ')
          ..write('byteSize: $byteSize, ')
          ..write('chapterNumber: $chapterNumber, ')
          ..write('chapterLabel: $chapterLabel, ')
          ..write('readStatus: $readStatus, ')
          ..write('progressFraction: $progressFraction, ')
          ..write('progressImageIndex: $progressImageIndex, ')
          ..write('progressOffsetInImage: $progressOffsetInImage, ')
          ..write('firstOpenedAt: $firstOpenedAt, ')
          ..write('lastReadAt: $lastReadAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('progressUpdatedAt: $progressUpdatedAt, ')
          ..write('discoveredAt: $discoveredAt, ')
          ..write('discoveryBasis: $discoveryBasis, ')
          ..write('discoveryConfidence: $discoveryConfidence, ')
          ..write('offlineRemovedAt: $offlineRemovedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CaptureJobsTable extends CaptureJobs
    with TableInfo<$CaptureJobsTable, CaptureJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CaptureJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _libraryItemIdMeta = const VerificationMeta(
    'libraryItemId',
  );
  @override
  late final GeneratedColumn<String> libraryItemId = GeneratedColumn<String>(
    'library_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startUrlMeta = const VerificationMeta(
    'startUrl',
  );
  @override
  late final GeneratedColumn<String> startUrl = GeneratedColumn<String>(
    'start_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentUrlMeta = const VerificationMeta(
    'currentUrl',
  );
  @override
  late final GeneratedColumn<String> currentUrl = GeneratedColumn<String>(
    'current_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _requestedChaptersMeta = const VerificationMeta(
    'requestedChapters',
  );
  @override
  late final GeneratedColumn<int> requestedChapters = GeneratedColumn<int>(
    'requested_chapters',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedChaptersMeta = const VerificationMeta(
    'completedChapters',
  );
  @override
  late final GeneratedColumn<int> completedChapters = GeneratedColumn<int>(
    'completed_chapters',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _visitedUrlsMeta = const VerificationMeta(
    'visitedUrls',
  );
  @override
  late final GeneratedColumn<String> visitedUrls = GeneratedColumn<String>(
    'visited_urls',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _duplicatePolicyMeta = const VerificationMeta(
    'duplicatePolicy',
  );
  @override
  late final GeneratedColumn<String> duplicatePolicy = GeneratedColumn<String>(
    'duplicate_policy',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sessionDuplicateDecisionMeta =
      const VerificationMeta('sessionDuplicateDecision');
  @override
  late final GeneratedColumn<String> sessionDuplicateDecision =
      GeneratedColumn<String>(
        'session_duplicate_decision',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _sessionPartialDecisionMeta =
      const VerificationMeta('sessionPartialDecision');
  @override
  late final GeneratedColumn<String> sessionPartialDecision =
      GeneratedColumn<String>(
        'session_partial_decision',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _rangeModeMeta = const VerificationMeta(
    'rangeMode',
  );
  @override
  late final GeneratedColumn<String> rangeMode = GeneratedColumn<String>(
    'range_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('fixedCount'),
  );
  static const VerificationMeta _pauseReasonMeta = const VerificationMeta(
    'pauseReason',
  );
  @override
  late final GeneratedColumn<String> pauseReason = GeneratedColumn<String>(
    'pause_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
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
    libraryItemId,
    startUrl,
    currentUrl,
    requestedChapters,
    completedChapters,
    state,
    lastError,
    visitedUrls,
    duplicatePolicy,
    sessionDuplicateDecision,
    sessionPartialDecision,
    rangeMode,
    pauseReason,
    origin,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'capture_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<CaptureJob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('library_item_id')) {
      context.handle(
        _libraryItemIdMeta,
        libraryItemId.isAcceptableOrUnknown(
          data['library_item_id']!,
          _libraryItemIdMeta,
        ),
      );
    }
    if (data.containsKey('start_url')) {
      context.handle(
        _startUrlMeta,
        startUrl.isAcceptableOrUnknown(data['start_url']!, _startUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_startUrlMeta);
    }
    if (data.containsKey('current_url')) {
      context.handle(
        _currentUrlMeta,
        currentUrl.isAcceptableOrUnknown(data['current_url']!, _currentUrlMeta),
      );
    }
    if (data.containsKey('requested_chapters')) {
      context.handle(
        _requestedChaptersMeta,
        requestedChapters.isAcceptableOrUnknown(
          data['requested_chapters']!,
          _requestedChaptersMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_requestedChaptersMeta);
    }
    if (data.containsKey('completed_chapters')) {
      context.handle(
        _completedChaptersMeta,
        completedChapters.isAcceptableOrUnknown(
          data['completed_chapters']!,
          _completedChaptersMeta,
        ),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('visited_urls')) {
      context.handle(
        _visitedUrlsMeta,
        visitedUrls.isAcceptableOrUnknown(
          data['visited_urls']!,
          _visitedUrlsMeta,
        ),
      );
    }
    if (data.containsKey('duplicate_policy')) {
      context.handle(
        _duplicatePolicyMeta,
        duplicatePolicy.isAcceptableOrUnknown(
          data['duplicate_policy']!,
          _duplicatePolicyMeta,
        ),
      );
    }
    if (data.containsKey('session_duplicate_decision')) {
      context.handle(
        _sessionDuplicateDecisionMeta,
        sessionDuplicateDecision.isAcceptableOrUnknown(
          data['session_duplicate_decision']!,
          _sessionDuplicateDecisionMeta,
        ),
      );
    }
    if (data.containsKey('session_partial_decision')) {
      context.handle(
        _sessionPartialDecisionMeta,
        sessionPartialDecision.isAcceptableOrUnknown(
          data['session_partial_decision']!,
          _sessionPartialDecisionMeta,
        ),
      );
    }
    if (data.containsKey('range_mode')) {
      context.handle(
        _rangeModeMeta,
        rangeMode.isAcceptableOrUnknown(data['range_mode']!, _rangeModeMeta),
      );
    }
    if (data.containsKey('pause_reason')) {
      context.handle(
        _pauseReasonMeta,
        pauseReason.isAcceptableOrUnknown(
          data['pause_reason']!,
          _pauseReasonMeta,
        ),
      );
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
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
  CaptureJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CaptureJob(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      libraryItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}library_item_id'],
      ),
      startUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_url'],
      )!,
      currentUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_url'],
      ),
      requestedChapters: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}requested_chapters'],
      )!,
      completedChapters: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_chapters'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      visitedUrls: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}visited_urls'],
      )!,
      duplicatePolicy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}duplicate_policy'],
      ),
      sessionDuplicateDecision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_duplicate_decision'],
      ),
      sessionPartialDecision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_partial_decision'],
      ),
      rangeMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}range_mode'],
      )!,
      pauseReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pause_reason'],
      ),
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
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
  $CaptureJobsTable createAlias(String alias) {
    return $CaptureJobsTable(attachedDatabase, alias);
  }
}

class CaptureJob extends DataClass implements Insertable<CaptureJob> {
  final String id;
  final String? libraryItemId;
  final String startUrl;
  final String? currentUrl;
  final int requestedChapters;
  final int completedChapters;
  final String state;
  final String? lastError;

  /// Newline-separated normalised URLs already walked in this job.
  final String visitedUrls;

  /// The duplicate policy the job was started with, so a resume applies the
  /// same one instead of silently reverting to the default.
  final String? duplicatePolicy;

  /// Session-scoped answers to "this chapter is already saved". Persisted on
  /// the job — they survive an interrupted-session resume — and reset when a
  /// new job starts. Never a global preference.
  final String? sessionDuplicateDecision;
  final String? sessionPartialDecision;

  /// currentChapter | fixedCount | untilEnd — how the range was chosen, so a
  /// resume continues the same mode (an interrupted until-end run must not
  /// come back as "capture 1 chapter").
  final String rangeMode;

  /// Why a running job is paused (`browserHidden` today; null otherwise).
  /// Lets Activity say "paused — Browser required" instead of a bare
  /// "paused", and survives a restart.
  final String? pauseReason;

  /// `direct` | `queue` — how this run was launched (D58). Persisted so an
  /// interrupted **direct** capture resumes as a direct capture rather than
  /// being quietly turned into a pending queue task. Null on rows written
  /// before v11, which read as `queue` because that was the only way then.
  final String? origin;
  final DateTime createdAt;
  final DateTime updatedAt;
  const CaptureJob({
    required this.id,
    this.libraryItemId,
    required this.startUrl,
    this.currentUrl,
    required this.requestedChapters,
    required this.completedChapters,
    required this.state,
    this.lastError,
    required this.visitedUrls,
    this.duplicatePolicy,
    this.sessionDuplicateDecision,
    this.sessionPartialDecision,
    required this.rangeMode,
    this.pauseReason,
    this.origin,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || libraryItemId != null) {
      map['library_item_id'] = Variable<String>(libraryItemId);
    }
    map['start_url'] = Variable<String>(startUrl);
    if (!nullToAbsent || currentUrl != null) {
      map['current_url'] = Variable<String>(currentUrl);
    }
    map['requested_chapters'] = Variable<int>(requestedChapters);
    map['completed_chapters'] = Variable<int>(completedChapters);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['visited_urls'] = Variable<String>(visitedUrls);
    if (!nullToAbsent || duplicatePolicy != null) {
      map['duplicate_policy'] = Variable<String>(duplicatePolicy);
    }
    if (!nullToAbsent || sessionDuplicateDecision != null) {
      map['session_duplicate_decision'] = Variable<String>(
        sessionDuplicateDecision,
      );
    }
    if (!nullToAbsent || sessionPartialDecision != null) {
      map['session_partial_decision'] = Variable<String>(
        sessionPartialDecision,
      );
    }
    map['range_mode'] = Variable<String>(rangeMode);
    if (!nullToAbsent || pauseReason != null) {
      map['pause_reason'] = Variable<String>(pauseReason);
    }
    if (!nullToAbsent || origin != null) {
      map['origin'] = Variable<String>(origin);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CaptureJobsCompanion toCompanion(bool nullToAbsent) {
    return CaptureJobsCompanion(
      id: Value(id),
      libraryItemId: libraryItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(libraryItemId),
      startUrl: Value(startUrl),
      currentUrl: currentUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(currentUrl),
      requestedChapters: Value(requestedChapters),
      completedChapters: Value(completedChapters),
      state: Value(state),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      visitedUrls: Value(visitedUrls),
      duplicatePolicy: duplicatePolicy == null && nullToAbsent
          ? const Value.absent()
          : Value(duplicatePolicy),
      sessionDuplicateDecision: sessionDuplicateDecision == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionDuplicateDecision),
      sessionPartialDecision: sessionPartialDecision == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionPartialDecision),
      rangeMode: Value(rangeMode),
      pauseReason: pauseReason == null && nullToAbsent
          ? const Value.absent()
          : Value(pauseReason),
      origin: origin == null && nullToAbsent
          ? const Value.absent()
          : Value(origin),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CaptureJob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CaptureJob(
      id: serializer.fromJson<String>(json['id']),
      libraryItemId: serializer.fromJson<String?>(json['libraryItemId']),
      startUrl: serializer.fromJson<String>(json['startUrl']),
      currentUrl: serializer.fromJson<String?>(json['currentUrl']),
      requestedChapters: serializer.fromJson<int>(json['requestedChapters']),
      completedChapters: serializer.fromJson<int>(json['completedChapters']),
      state: serializer.fromJson<String>(json['state']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      visitedUrls: serializer.fromJson<String>(json['visitedUrls']),
      duplicatePolicy: serializer.fromJson<String?>(json['duplicatePolicy']),
      sessionDuplicateDecision: serializer.fromJson<String?>(
        json['sessionDuplicateDecision'],
      ),
      sessionPartialDecision: serializer.fromJson<String?>(
        json['sessionPartialDecision'],
      ),
      rangeMode: serializer.fromJson<String>(json['rangeMode']),
      pauseReason: serializer.fromJson<String?>(json['pauseReason']),
      origin: serializer.fromJson<String?>(json['origin']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'libraryItemId': serializer.toJson<String?>(libraryItemId),
      'startUrl': serializer.toJson<String>(startUrl),
      'currentUrl': serializer.toJson<String?>(currentUrl),
      'requestedChapters': serializer.toJson<int>(requestedChapters),
      'completedChapters': serializer.toJson<int>(completedChapters),
      'state': serializer.toJson<String>(state),
      'lastError': serializer.toJson<String?>(lastError),
      'visitedUrls': serializer.toJson<String>(visitedUrls),
      'duplicatePolicy': serializer.toJson<String?>(duplicatePolicy),
      'sessionDuplicateDecision': serializer.toJson<String?>(
        sessionDuplicateDecision,
      ),
      'sessionPartialDecision': serializer.toJson<String?>(
        sessionPartialDecision,
      ),
      'rangeMode': serializer.toJson<String>(rangeMode),
      'pauseReason': serializer.toJson<String?>(pauseReason),
      'origin': serializer.toJson<String?>(origin),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CaptureJob copyWith({
    String? id,
    Value<String?> libraryItemId = const Value.absent(),
    String? startUrl,
    Value<String?> currentUrl = const Value.absent(),
    int? requestedChapters,
    int? completedChapters,
    String? state,
    Value<String?> lastError = const Value.absent(),
    String? visitedUrls,
    Value<String?> duplicatePolicy = const Value.absent(),
    Value<String?> sessionDuplicateDecision = const Value.absent(),
    Value<String?> sessionPartialDecision = const Value.absent(),
    String? rangeMode,
    Value<String?> pauseReason = const Value.absent(),
    Value<String?> origin = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CaptureJob(
    id: id ?? this.id,
    libraryItemId: libraryItemId.present
        ? libraryItemId.value
        : this.libraryItemId,
    startUrl: startUrl ?? this.startUrl,
    currentUrl: currentUrl.present ? currentUrl.value : this.currentUrl,
    requestedChapters: requestedChapters ?? this.requestedChapters,
    completedChapters: completedChapters ?? this.completedChapters,
    state: state ?? this.state,
    lastError: lastError.present ? lastError.value : this.lastError,
    visitedUrls: visitedUrls ?? this.visitedUrls,
    duplicatePolicy: duplicatePolicy.present
        ? duplicatePolicy.value
        : this.duplicatePolicy,
    sessionDuplicateDecision: sessionDuplicateDecision.present
        ? sessionDuplicateDecision.value
        : this.sessionDuplicateDecision,
    sessionPartialDecision: sessionPartialDecision.present
        ? sessionPartialDecision.value
        : this.sessionPartialDecision,
    rangeMode: rangeMode ?? this.rangeMode,
    pauseReason: pauseReason.present ? pauseReason.value : this.pauseReason,
    origin: origin.present ? origin.value : this.origin,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CaptureJob copyWithCompanion(CaptureJobsCompanion data) {
    return CaptureJob(
      id: data.id.present ? data.id.value : this.id,
      libraryItemId: data.libraryItemId.present
          ? data.libraryItemId.value
          : this.libraryItemId,
      startUrl: data.startUrl.present ? data.startUrl.value : this.startUrl,
      currentUrl: data.currentUrl.present
          ? data.currentUrl.value
          : this.currentUrl,
      requestedChapters: data.requestedChapters.present
          ? data.requestedChapters.value
          : this.requestedChapters,
      completedChapters: data.completedChapters.present
          ? data.completedChapters.value
          : this.completedChapters,
      state: data.state.present ? data.state.value : this.state,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      visitedUrls: data.visitedUrls.present
          ? data.visitedUrls.value
          : this.visitedUrls,
      duplicatePolicy: data.duplicatePolicy.present
          ? data.duplicatePolicy.value
          : this.duplicatePolicy,
      sessionDuplicateDecision: data.sessionDuplicateDecision.present
          ? data.sessionDuplicateDecision.value
          : this.sessionDuplicateDecision,
      sessionPartialDecision: data.sessionPartialDecision.present
          ? data.sessionPartialDecision.value
          : this.sessionPartialDecision,
      rangeMode: data.rangeMode.present ? data.rangeMode.value : this.rangeMode,
      pauseReason: data.pauseReason.present
          ? data.pauseReason.value
          : this.pauseReason,
      origin: data.origin.present ? data.origin.value : this.origin,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CaptureJob(')
          ..write('id: $id, ')
          ..write('libraryItemId: $libraryItemId, ')
          ..write('startUrl: $startUrl, ')
          ..write('currentUrl: $currentUrl, ')
          ..write('requestedChapters: $requestedChapters, ')
          ..write('completedChapters: $completedChapters, ')
          ..write('state: $state, ')
          ..write('lastError: $lastError, ')
          ..write('visitedUrls: $visitedUrls, ')
          ..write('duplicatePolicy: $duplicatePolicy, ')
          ..write('sessionDuplicateDecision: $sessionDuplicateDecision, ')
          ..write('sessionPartialDecision: $sessionPartialDecision, ')
          ..write('rangeMode: $rangeMode, ')
          ..write('pauseReason: $pauseReason, ')
          ..write('origin: $origin, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    libraryItemId,
    startUrl,
    currentUrl,
    requestedChapters,
    completedChapters,
    state,
    lastError,
    visitedUrls,
    duplicatePolicy,
    sessionDuplicateDecision,
    sessionPartialDecision,
    rangeMode,
    pauseReason,
    origin,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CaptureJob &&
          other.id == this.id &&
          other.libraryItemId == this.libraryItemId &&
          other.startUrl == this.startUrl &&
          other.currentUrl == this.currentUrl &&
          other.requestedChapters == this.requestedChapters &&
          other.completedChapters == this.completedChapters &&
          other.state == this.state &&
          other.lastError == this.lastError &&
          other.visitedUrls == this.visitedUrls &&
          other.duplicatePolicy == this.duplicatePolicy &&
          other.sessionDuplicateDecision == this.sessionDuplicateDecision &&
          other.sessionPartialDecision == this.sessionPartialDecision &&
          other.rangeMode == this.rangeMode &&
          other.pauseReason == this.pauseReason &&
          other.origin == this.origin &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CaptureJobsCompanion extends UpdateCompanion<CaptureJob> {
  final Value<String> id;
  final Value<String?> libraryItemId;
  final Value<String> startUrl;
  final Value<String?> currentUrl;
  final Value<int> requestedChapters;
  final Value<int> completedChapters;
  final Value<String> state;
  final Value<String?> lastError;
  final Value<String> visitedUrls;
  final Value<String?> duplicatePolicy;
  final Value<String?> sessionDuplicateDecision;
  final Value<String?> sessionPartialDecision;
  final Value<String> rangeMode;
  final Value<String?> pauseReason;
  final Value<String?> origin;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CaptureJobsCompanion({
    this.id = const Value.absent(),
    this.libraryItemId = const Value.absent(),
    this.startUrl = const Value.absent(),
    this.currentUrl = const Value.absent(),
    this.requestedChapters = const Value.absent(),
    this.completedChapters = const Value.absent(),
    this.state = const Value.absent(),
    this.lastError = const Value.absent(),
    this.visitedUrls = const Value.absent(),
    this.duplicatePolicy = const Value.absent(),
    this.sessionDuplicateDecision = const Value.absent(),
    this.sessionPartialDecision = const Value.absent(),
    this.rangeMode = const Value.absent(),
    this.pauseReason = const Value.absent(),
    this.origin = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CaptureJobsCompanion.insert({
    required String id,
    this.libraryItemId = const Value.absent(),
    required String startUrl,
    this.currentUrl = const Value.absent(),
    required int requestedChapters,
    this.completedChapters = const Value.absent(),
    required String state,
    this.lastError = const Value.absent(),
    this.visitedUrls = const Value.absent(),
    this.duplicatePolicy = const Value.absent(),
    this.sessionDuplicateDecision = const Value.absent(),
    this.sessionPartialDecision = const Value.absent(),
    this.rangeMode = const Value.absent(),
    this.pauseReason = const Value.absent(),
    this.origin = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startUrl = Value(startUrl),
       requestedChapters = Value(requestedChapters),
       state = Value(state),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<CaptureJob> custom({
    Expression<String>? id,
    Expression<String>? libraryItemId,
    Expression<String>? startUrl,
    Expression<String>? currentUrl,
    Expression<int>? requestedChapters,
    Expression<int>? completedChapters,
    Expression<String>? state,
    Expression<String>? lastError,
    Expression<String>? visitedUrls,
    Expression<String>? duplicatePolicy,
    Expression<String>? sessionDuplicateDecision,
    Expression<String>? sessionPartialDecision,
    Expression<String>? rangeMode,
    Expression<String>? pauseReason,
    Expression<String>? origin,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (libraryItemId != null) 'library_item_id': libraryItemId,
      if (startUrl != null) 'start_url': startUrl,
      if (currentUrl != null) 'current_url': currentUrl,
      if (requestedChapters != null) 'requested_chapters': requestedChapters,
      if (completedChapters != null) 'completed_chapters': completedChapters,
      if (state != null) 'state': state,
      if (lastError != null) 'last_error': lastError,
      if (visitedUrls != null) 'visited_urls': visitedUrls,
      if (duplicatePolicy != null) 'duplicate_policy': duplicatePolicy,
      if (sessionDuplicateDecision != null)
        'session_duplicate_decision': sessionDuplicateDecision,
      if (sessionPartialDecision != null)
        'session_partial_decision': sessionPartialDecision,
      if (rangeMode != null) 'range_mode': rangeMode,
      if (pauseReason != null) 'pause_reason': pauseReason,
      if (origin != null) 'origin': origin,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CaptureJobsCompanion copyWith({
    Value<String>? id,
    Value<String?>? libraryItemId,
    Value<String>? startUrl,
    Value<String?>? currentUrl,
    Value<int>? requestedChapters,
    Value<int>? completedChapters,
    Value<String>? state,
    Value<String?>? lastError,
    Value<String>? visitedUrls,
    Value<String?>? duplicatePolicy,
    Value<String?>? sessionDuplicateDecision,
    Value<String?>? sessionPartialDecision,
    Value<String>? rangeMode,
    Value<String?>? pauseReason,
    Value<String?>? origin,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CaptureJobsCompanion(
      id: id ?? this.id,
      libraryItemId: libraryItemId ?? this.libraryItemId,
      startUrl: startUrl ?? this.startUrl,
      currentUrl: currentUrl ?? this.currentUrl,
      requestedChapters: requestedChapters ?? this.requestedChapters,
      completedChapters: completedChapters ?? this.completedChapters,
      state: state ?? this.state,
      lastError: lastError ?? this.lastError,
      visitedUrls: visitedUrls ?? this.visitedUrls,
      duplicatePolicy: duplicatePolicy ?? this.duplicatePolicy,
      sessionDuplicateDecision:
          sessionDuplicateDecision ?? this.sessionDuplicateDecision,
      sessionPartialDecision:
          sessionPartialDecision ?? this.sessionPartialDecision,
      rangeMode: rangeMode ?? this.rangeMode,
      pauseReason: pauseReason ?? this.pauseReason,
      origin: origin ?? this.origin,
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
    if (libraryItemId.present) {
      map['library_item_id'] = Variable<String>(libraryItemId.value);
    }
    if (startUrl.present) {
      map['start_url'] = Variable<String>(startUrl.value);
    }
    if (currentUrl.present) {
      map['current_url'] = Variable<String>(currentUrl.value);
    }
    if (requestedChapters.present) {
      map['requested_chapters'] = Variable<int>(requestedChapters.value);
    }
    if (completedChapters.present) {
      map['completed_chapters'] = Variable<int>(completedChapters.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (visitedUrls.present) {
      map['visited_urls'] = Variable<String>(visitedUrls.value);
    }
    if (duplicatePolicy.present) {
      map['duplicate_policy'] = Variable<String>(duplicatePolicy.value);
    }
    if (sessionDuplicateDecision.present) {
      map['session_duplicate_decision'] = Variable<String>(
        sessionDuplicateDecision.value,
      );
    }
    if (sessionPartialDecision.present) {
      map['session_partial_decision'] = Variable<String>(
        sessionPartialDecision.value,
      );
    }
    if (rangeMode.present) {
      map['range_mode'] = Variable<String>(rangeMode.value);
    }
    if (pauseReason.present) {
      map['pause_reason'] = Variable<String>(pauseReason.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
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
    return (StringBuffer('CaptureJobsCompanion(')
          ..write('id: $id, ')
          ..write('libraryItemId: $libraryItemId, ')
          ..write('startUrl: $startUrl, ')
          ..write('currentUrl: $currentUrl, ')
          ..write('requestedChapters: $requestedChapters, ')
          ..write('completedChapters: $completedChapters, ')
          ..write('state: $state, ')
          ..write('lastError: $lastError, ')
          ..write('visitedUrls: $visitedUrls, ')
          ..write('duplicatePolicy: $duplicatePolicy, ')
          ..write('sessionDuplicateDecision: $sessionDuplicateDecision, ')
          ..write('sessionPartialDecision: $sessionPartialDecision, ')
          ..write('rangeMode: $rangeMode, ')
          ..write('pauseReason: $pauseReason, ')
          ..write('origin: $origin, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SiteRuleRowsTable extends SiteRuleRows
    with TableInfo<$SiteRuleRowsTable, SiteRuleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SiteRuleRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hostMeta = const VerificationMeta('host');
  @override
  late final GeneratedColumn<String> host = GeneratedColumn<String>(
    'host',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seriesPathMeta = const VerificationMeta(
    'seriesPath',
  );
  @override
  late final GeneratedColumn<String> seriesPath = GeneratedColumn<String>(
    'series_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locatorJsonMeta = const VerificationMeta(
    'locatorJson',
  );
  @override
  late final GeneratedColumn<String> locatorJson = GeneratedColumn<String>(
    'locator_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exampleSourceUrlMeta = const VerificationMeta(
    'exampleSourceUrl',
  );
  @override
  late final GeneratedColumn<String> exampleSourceUrl = GeneratedColumn<String>(
    'example_source_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exampleTargetUrlMeta = const VerificationMeta(
    'exampleTargetUrl',
  );
  @override
  late final GeneratedColumn<String> exampleTargetUrl = GeneratedColumn<String>(
    'example_target_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sameHostOnlyMeta = const VerificationMeta(
    'sameHostOnly',
  );
  @override
  late final GeneratedColumn<bool> sameHostOnly = GeneratedColumn<bool>(
    'same_host_only',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("same_host_only" IN (0, 1))',
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
  static const VerificationMeta _successCountMeta = const VerificationMeta(
    'successCount',
  );
  @override
  late final GeneratedColumn<int> successCount = GeneratedColumn<int>(
    'success_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _failureCountMeta = const VerificationMeta(
    'failureCount',
  );
  @override
  late final GeneratedColumn<int> failureCount = GeneratedColumn<int>(
    'failure_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    host,
    seriesPath,
    scope,
    kind,
    locatorJson,
    exampleSourceUrl,
    exampleTargetUrl,
    sameHostOnly,
    createdAt,
    lastUsedAt,
    successCount,
    failureCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'site_rule_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<SiteRuleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('host')) {
      context.handle(
        _hostMeta,
        host.isAcceptableOrUnknown(data['host']!, _hostMeta),
      );
    } else if (isInserting) {
      context.missing(_hostMeta);
    }
    if (data.containsKey('series_path')) {
      context.handle(
        _seriesPathMeta,
        seriesPath.isAcceptableOrUnknown(data['series_path']!, _seriesPathMeta),
      );
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('locator_json')) {
      context.handle(
        _locatorJsonMeta,
        locatorJson.isAcceptableOrUnknown(
          data['locator_json']!,
          _locatorJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_locatorJsonMeta);
    }
    if (data.containsKey('example_source_url')) {
      context.handle(
        _exampleSourceUrlMeta,
        exampleSourceUrl.isAcceptableOrUnknown(
          data['example_source_url']!,
          _exampleSourceUrlMeta,
        ),
      );
    }
    if (data.containsKey('example_target_url')) {
      context.handle(
        _exampleTargetUrlMeta,
        exampleTargetUrl.isAcceptableOrUnknown(
          data['example_target_url']!,
          _exampleTargetUrlMeta,
        ),
      );
    }
    if (data.containsKey('same_host_only')) {
      context.handle(
        _sameHostOnlyMeta,
        sameHostOnly.isAcceptableOrUnknown(
          data['same_host_only']!,
          _sameHostOnlyMeta,
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
    if (data.containsKey('last_used_at')) {
      context.handle(
        _lastUsedAtMeta,
        lastUsedAt.isAcceptableOrUnknown(
          data['last_used_at']!,
          _lastUsedAtMeta,
        ),
      );
    }
    if (data.containsKey('success_count')) {
      context.handle(
        _successCountMeta,
        successCount.isAcceptableOrUnknown(
          data['success_count']!,
          _successCountMeta,
        ),
      );
    }
    if (data.containsKey('failure_count')) {
      context.handle(
        _failureCountMeta,
        failureCount.isAcceptableOrUnknown(
          data['failure_count']!,
          _failureCountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SiteRuleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SiteRuleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      host: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host'],
      )!,
      seriesPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_path'],
      ),
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      locatorJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locator_json'],
      )!,
      exampleSourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}example_source_url'],
      ),
      exampleTargetUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}example_target_url'],
      ),
      sameHostOnly: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}same_host_only'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastUsedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_used_at'],
      ),
      successCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}success_count'],
      )!,
      failureCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}failure_count'],
      )!,
    );
  }

  @override
  $SiteRuleRowsTable createAlias(String alias) {
    return $SiteRuleRowsTable(attachedDatabase, alias);
  }
}

class SiteRuleRow extends DataClass implements Insertable<SiteRuleRow> {
  final String id;
  final String host;

  /// Series fingerprint, or a path shape for `pathPattern` scope.
  /// Null only for host-wide rules.
  final String? seriesPath;
  final String scope;
  final String kind;

  /// Serialised [DomLocator] — a bag of independent signals, not one selector.
  final String locatorJson;
  final String? exampleSourceUrl;
  final String? exampleTargetUrl;
  final bool sameHostOnly;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final int successCount;
  final int failureCount;
  const SiteRuleRow({
    required this.id,
    required this.host,
    this.seriesPath,
    required this.scope,
    required this.kind,
    required this.locatorJson,
    this.exampleSourceUrl,
    this.exampleTargetUrl,
    required this.sameHostOnly,
    required this.createdAt,
    this.lastUsedAt,
    required this.successCount,
    required this.failureCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['host'] = Variable<String>(host);
    if (!nullToAbsent || seriesPath != null) {
      map['series_path'] = Variable<String>(seriesPath);
    }
    map['scope'] = Variable<String>(scope);
    map['kind'] = Variable<String>(kind);
    map['locator_json'] = Variable<String>(locatorJson);
    if (!nullToAbsent || exampleSourceUrl != null) {
      map['example_source_url'] = Variable<String>(exampleSourceUrl);
    }
    if (!nullToAbsent || exampleTargetUrl != null) {
      map['example_target_url'] = Variable<String>(exampleTargetUrl);
    }
    map['same_host_only'] = Variable<bool>(sameHostOnly);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastUsedAt != null) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt);
    }
    map['success_count'] = Variable<int>(successCount);
    map['failure_count'] = Variable<int>(failureCount);
    return map;
  }

  SiteRuleRowsCompanion toCompanion(bool nullToAbsent) {
    return SiteRuleRowsCompanion(
      id: Value(id),
      host: Value(host),
      seriesPath: seriesPath == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesPath),
      scope: Value(scope),
      kind: Value(kind),
      locatorJson: Value(locatorJson),
      exampleSourceUrl: exampleSourceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(exampleSourceUrl),
      exampleTargetUrl: exampleTargetUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(exampleTargetUrl),
      sameHostOnly: Value(sameHostOnly),
      createdAt: Value(createdAt),
      lastUsedAt: lastUsedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUsedAt),
      successCount: Value(successCount),
      failureCount: Value(failureCount),
    );
  }

  factory SiteRuleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SiteRuleRow(
      id: serializer.fromJson<String>(json['id']),
      host: serializer.fromJson<String>(json['host']),
      seriesPath: serializer.fromJson<String?>(json['seriesPath']),
      scope: serializer.fromJson<String>(json['scope']),
      kind: serializer.fromJson<String>(json['kind']),
      locatorJson: serializer.fromJson<String>(json['locatorJson']),
      exampleSourceUrl: serializer.fromJson<String?>(json['exampleSourceUrl']),
      exampleTargetUrl: serializer.fromJson<String?>(json['exampleTargetUrl']),
      sameHostOnly: serializer.fromJson<bool>(json['sameHostOnly']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastUsedAt: serializer.fromJson<DateTime?>(json['lastUsedAt']),
      successCount: serializer.fromJson<int>(json['successCount']),
      failureCount: serializer.fromJson<int>(json['failureCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'host': serializer.toJson<String>(host),
      'seriesPath': serializer.toJson<String?>(seriesPath),
      'scope': serializer.toJson<String>(scope),
      'kind': serializer.toJson<String>(kind),
      'locatorJson': serializer.toJson<String>(locatorJson),
      'exampleSourceUrl': serializer.toJson<String?>(exampleSourceUrl),
      'exampleTargetUrl': serializer.toJson<String?>(exampleTargetUrl),
      'sameHostOnly': serializer.toJson<bool>(sameHostOnly),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastUsedAt': serializer.toJson<DateTime?>(lastUsedAt),
      'successCount': serializer.toJson<int>(successCount),
      'failureCount': serializer.toJson<int>(failureCount),
    };
  }

  SiteRuleRow copyWith({
    String? id,
    String? host,
    Value<String?> seriesPath = const Value.absent(),
    String? scope,
    String? kind,
    String? locatorJson,
    Value<String?> exampleSourceUrl = const Value.absent(),
    Value<String?> exampleTargetUrl = const Value.absent(),
    bool? sameHostOnly,
    DateTime? createdAt,
    Value<DateTime?> lastUsedAt = const Value.absent(),
    int? successCount,
    int? failureCount,
  }) => SiteRuleRow(
    id: id ?? this.id,
    host: host ?? this.host,
    seriesPath: seriesPath.present ? seriesPath.value : this.seriesPath,
    scope: scope ?? this.scope,
    kind: kind ?? this.kind,
    locatorJson: locatorJson ?? this.locatorJson,
    exampleSourceUrl: exampleSourceUrl.present
        ? exampleSourceUrl.value
        : this.exampleSourceUrl,
    exampleTargetUrl: exampleTargetUrl.present
        ? exampleTargetUrl.value
        : this.exampleTargetUrl,
    sameHostOnly: sameHostOnly ?? this.sameHostOnly,
    createdAt: createdAt ?? this.createdAt,
    lastUsedAt: lastUsedAt.present ? lastUsedAt.value : this.lastUsedAt,
    successCount: successCount ?? this.successCount,
    failureCount: failureCount ?? this.failureCount,
  );
  SiteRuleRow copyWithCompanion(SiteRuleRowsCompanion data) {
    return SiteRuleRow(
      id: data.id.present ? data.id.value : this.id,
      host: data.host.present ? data.host.value : this.host,
      seriesPath: data.seriesPath.present
          ? data.seriesPath.value
          : this.seriesPath,
      scope: data.scope.present ? data.scope.value : this.scope,
      kind: data.kind.present ? data.kind.value : this.kind,
      locatorJson: data.locatorJson.present
          ? data.locatorJson.value
          : this.locatorJson,
      exampleSourceUrl: data.exampleSourceUrl.present
          ? data.exampleSourceUrl.value
          : this.exampleSourceUrl,
      exampleTargetUrl: data.exampleTargetUrl.present
          ? data.exampleTargetUrl.value
          : this.exampleTargetUrl,
      sameHostOnly: data.sameHostOnly.present
          ? data.sameHostOnly.value
          : this.sameHostOnly,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastUsedAt: data.lastUsedAt.present
          ? data.lastUsedAt.value
          : this.lastUsedAt,
      successCount: data.successCount.present
          ? data.successCount.value
          : this.successCount,
      failureCount: data.failureCount.present
          ? data.failureCount.value
          : this.failureCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SiteRuleRow(')
          ..write('id: $id, ')
          ..write('host: $host, ')
          ..write('seriesPath: $seriesPath, ')
          ..write('scope: $scope, ')
          ..write('kind: $kind, ')
          ..write('locatorJson: $locatorJson, ')
          ..write('exampleSourceUrl: $exampleSourceUrl, ')
          ..write('exampleTargetUrl: $exampleTargetUrl, ')
          ..write('sameHostOnly: $sameHostOnly, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('successCount: $successCount, ')
          ..write('failureCount: $failureCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    host,
    seriesPath,
    scope,
    kind,
    locatorJson,
    exampleSourceUrl,
    exampleTargetUrl,
    sameHostOnly,
    createdAt,
    lastUsedAt,
    successCount,
    failureCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SiteRuleRow &&
          other.id == this.id &&
          other.host == this.host &&
          other.seriesPath == this.seriesPath &&
          other.scope == this.scope &&
          other.kind == this.kind &&
          other.locatorJson == this.locatorJson &&
          other.exampleSourceUrl == this.exampleSourceUrl &&
          other.exampleTargetUrl == this.exampleTargetUrl &&
          other.sameHostOnly == this.sameHostOnly &&
          other.createdAt == this.createdAt &&
          other.lastUsedAt == this.lastUsedAt &&
          other.successCount == this.successCount &&
          other.failureCount == this.failureCount);
}

class SiteRuleRowsCompanion extends UpdateCompanion<SiteRuleRow> {
  final Value<String> id;
  final Value<String> host;
  final Value<String?> seriesPath;
  final Value<String> scope;
  final Value<String> kind;
  final Value<String> locatorJson;
  final Value<String?> exampleSourceUrl;
  final Value<String?> exampleTargetUrl;
  final Value<bool> sameHostOnly;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastUsedAt;
  final Value<int> successCount;
  final Value<int> failureCount;
  final Value<int> rowid;
  const SiteRuleRowsCompanion({
    this.id = const Value.absent(),
    this.host = const Value.absent(),
    this.seriesPath = const Value.absent(),
    this.scope = const Value.absent(),
    this.kind = const Value.absent(),
    this.locatorJson = const Value.absent(),
    this.exampleSourceUrl = const Value.absent(),
    this.exampleTargetUrl = const Value.absent(),
    this.sameHostOnly = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    this.successCount = const Value.absent(),
    this.failureCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SiteRuleRowsCompanion.insert({
    required String id,
    required String host,
    this.seriesPath = const Value.absent(),
    required String scope,
    required String kind,
    required String locatorJson,
    this.exampleSourceUrl = const Value.absent(),
    this.exampleTargetUrl = const Value.absent(),
    this.sameHostOnly = const Value.absent(),
    required DateTime createdAt,
    this.lastUsedAt = const Value.absent(),
    this.successCount = const Value.absent(),
    this.failureCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       host = Value(host),
       scope = Value(scope),
       kind = Value(kind),
       locatorJson = Value(locatorJson),
       createdAt = Value(createdAt);
  static Insertable<SiteRuleRow> custom({
    Expression<String>? id,
    Expression<String>? host,
    Expression<String>? seriesPath,
    Expression<String>? scope,
    Expression<String>? kind,
    Expression<String>? locatorJson,
    Expression<String>? exampleSourceUrl,
    Expression<String>? exampleTargetUrl,
    Expression<bool>? sameHostOnly,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastUsedAt,
    Expression<int>? successCount,
    Expression<int>? failureCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (host != null) 'host': host,
      if (seriesPath != null) 'series_path': seriesPath,
      if (scope != null) 'scope': scope,
      if (kind != null) 'kind': kind,
      if (locatorJson != null) 'locator_json': locatorJson,
      if (exampleSourceUrl != null) 'example_source_url': exampleSourceUrl,
      if (exampleTargetUrl != null) 'example_target_url': exampleTargetUrl,
      if (sameHostOnly != null) 'same_host_only': sameHostOnly,
      if (createdAt != null) 'created_at': createdAt,
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
      if (successCount != null) 'success_count': successCount,
      if (failureCount != null) 'failure_count': failureCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SiteRuleRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? host,
    Value<String?>? seriesPath,
    Value<String>? scope,
    Value<String>? kind,
    Value<String>? locatorJson,
    Value<String?>? exampleSourceUrl,
    Value<String?>? exampleTargetUrl,
    Value<bool>? sameHostOnly,
    Value<DateTime>? createdAt,
    Value<DateTime?>? lastUsedAt,
    Value<int>? successCount,
    Value<int>? failureCount,
    Value<int>? rowid,
  }) {
    return SiteRuleRowsCompanion(
      id: id ?? this.id,
      host: host ?? this.host,
      seriesPath: seriesPath ?? this.seriesPath,
      scope: scope ?? this.scope,
      kind: kind ?? this.kind,
      locatorJson: locatorJson ?? this.locatorJson,
      exampleSourceUrl: exampleSourceUrl ?? this.exampleSourceUrl,
      exampleTargetUrl: exampleTargetUrl ?? this.exampleTargetUrl,
      sameHostOnly: sameHostOnly ?? this.sameHostOnly,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      successCount: successCount ?? this.successCount,
      failureCount: failureCount ?? this.failureCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (host.present) {
      map['host'] = Variable<String>(host.value);
    }
    if (seriesPath.present) {
      map['series_path'] = Variable<String>(seriesPath.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (locatorJson.present) {
      map['locator_json'] = Variable<String>(locatorJson.value);
    }
    if (exampleSourceUrl.present) {
      map['example_source_url'] = Variable<String>(exampleSourceUrl.value);
    }
    if (exampleTargetUrl.present) {
      map['example_target_url'] = Variable<String>(exampleTargetUrl.value);
    }
    if (sameHostOnly.present) {
      map['same_host_only'] = Variable<bool>(sameHostOnly.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastUsedAt.present) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt.value);
    }
    if (successCount.present) {
      map['success_count'] = Variable<int>(successCount.value);
    }
    if (failureCount.present) {
      map['failure_count'] = Variable<int>(failureCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SiteRuleRowsCompanion(')
          ..write('id: $id, ')
          ..write('host: $host, ')
          ..write('seriesPath: $seriesPath, ')
          ..write('scope: $scope, ')
          ..write('kind: $kind, ')
          ..write('locatorJson: $locatorJson, ')
          ..write('exampleSourceUrl: $exampleSourceUrl, ')
          ..write('exampleTargetUrl: $exampleTargetUrl, ')
          ..write('sameHostOnly: $sameHostOnly, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('successCount: $successCount, ')
          ..write('failureCount: $failureCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
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
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QueueTasksTable extends QueueTasks
    with TableInfo<$QueueTasksTable, QueueTask> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QueueTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskTypeMeta = const VerificationMeta(
    'taskType',
  );
  @override
  late final GeneratedColumn<String> taskType = GeneratedColumn<String>(
    'task_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _libraryItemIdMeta = const VerificationMeta(
    'libraryItemId',
  );
  @override
  late final GeneratedColumn<String> libraryItemId = GeneratedColumn<String>(
    'library_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startUrlMeta = const VerificationMeta(
    'startUrl',
  );
  @override
  late final GeneratedColumn<String> startUrl = GeneratedColumn<String>(
    'start_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _chapterLimitMeta = const VerificationMeta(
    'chapterLimit',
  );
  @override
  late final GeneratedColumn<int> chapterLimit = GeneratedColumn<int>(
    'chapter_limit',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _duplicatePolicyMeta = const VerificationMeta(
    'duplicatePolicy',
  );
  @override
  late final GeneratedColumn<String> duplicatePolicy = GeneratedColumn<String>(
    'duplicate_policy',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rangeModeMeta = const VerificationMeta(
    'rangeMode',
  );
  @override
  late final GeneratedColumn<String> rangeMode = GeneratedColumn<String>(
    'range_mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('queued'),
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _outcomeMeta = const VerificationMeta(
    'outcome',
  );
  @override
  late final GeneratedColumn<String> outcome = GeneratedColumn<String>(
    'outcome',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _queuedAtMeta = const VerificationMeta(
    'queuedAt',
  );
  @override
  late final GeneratedColumn<DateTime> queuedAt = GeneratedColumn<DateTime>(
    'queued_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> finishedAt = GeneratedColumn<DateTime>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskType,
    libraryItemId,
    startUrl,
    chapterLimit,
    duplicatePolicy,
    rangeMode,
    state,
    origin,
    outcome,
    lastError,
    orderIndex,
    queuedAt,
    startedAt,
    finishedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'queue_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<QueueTask> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_type')) {
      context.handle(
        _taskTypeMeta,
        taskType.isAcceptableOrUnknown(data['task_type']!, _taskTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_taskTypeMeta);
    }
    if (data.containsKey('library_item_id')) {
      context.handle(
        _libraryItemIdMeta,
        libraryItemId.isAcceptableOrUnknown(
          data['library_item_id']!,
          _libraryItemIdMeta,
        ),
      );
    }
    if (data.containsKey('start_url')) {
      context.handle(
        _startUrlMeta,
        startUrl.isAcceptableOrUnknown(data['start_url']!, _startUrlMeta),
      );
    }
    if (data.containsKey('chapter_limit')) {
      context.handle(
        _chapterLimitMeta,
        chapterLimit.isAcceptableOrUnknown(
          data['chapter_limit']!,
          _chapterLimitMeta,
        ),
      );
    }
    if (data.containsKey('duplicate_policy')) {
      context.handle(
        _duplicatePolicyMeta,
        duplicatePolicy.isAcceptableOrUnknown(
          data['duplicate_policy']!,
          _duplicatePolicyMeta,
        ),
      );
    }
    if (data.containsKey('range_mode')) {
      context.handle(
        _rangeModeMeta,
        rangeMode.isAcceptableOrUnknown(data['range_mode']!, _rangeModeMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    }
    if (data.containsKey('outcome')) {
      context.handle(
        _outcomeMeta,
        outcome.isAcceptableOrUnknown(data['outcome']!, _outcomeMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    }
    if (data.containsKey('queued_at')) {
      context.handle(
        _queuedAtMeta,
        queuedAt.isAcceptableOrUnknown(data['queued_at']!, _queuedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_queuedAtMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QueueTask map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QueueTask(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_type'],
      )!,
      libraryItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}library_item_id'],
      ),
      startUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_url'],
      ),
      chapterLimit: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_limit'],
      ),
      duplicatePolicy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}duplicate_policy'],
      ),
      rangeMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}range_mode'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      ),
      outcome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outcome'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      queuedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}queued_at'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      ),
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finished_at'],
      ),
    );
  }

  @override
  $QueueTasksTable createAlias(String alias) {
    return $QueueTasksTable(attachedDatabase, alias);
  }
}

class QueueTask extends DataClass implements Insertable<QueueTask> {
  final String id;

  /// chapterCapture | multiChapterCapture | seriesCheck | checkAllSeries
  final String taskType;
  final String? libraryItemId;
  final String? startUrl;
  final int? chapterLimit;
  final String? duplicatePolicy;

  /// currentChapter | fixedCount | untilEnd (null on rows from before v8 —
  /// read as fixedCount).
  final String? rangeMode;

  /// queued | running | completed | failed | cancelled
  final String state;

  /// `queue` | `direct` — whether this row is queued work or the record of a
  /// capture the user started straight from the Browser (D58).
  ///
  /// A `direct` row is **only ever terminal**: a direct capture creates no
  /// pending entry, so nothing here can be released by the queue pump. It
  /// exists for Activity history and error reporting.
  final String? origin;

  /// Short human summary of how it ended ("3 captured, 1 skipped").
  final String? outcome;
  final String? lastError;

  /// FIFO order within the queue.
  final int orderIndex;
  final DateTime queuedAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  const QueueTask({
    required this.id,
    required this.taskType,
    this.libraryItemId,
    this.startUrl,
    this.chapterLimit,
    this.duplicatePolicy,
    this.rangeMode,
    required this.state,
    this.origin,
    this.outcome,
    this.lastError,
    required this.orderIndex,
    required this.queuedAt,
    this.startedAt,
    this.finishedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['task_type'] = Variable<String>(taskType);
    if (!nullToAbsent || libraryItemId != null) {
      map['library_item_id'] = Variable<String>(libraryItemId);
    }
    if (!nullToAbsent || startUrl != null) {
      map['start_url'] = Variable<String>(startUrl);
    }
    if (!nullToAbsent || chapterLimit != null) {
      map['chapter_limit'] = Variable<int>(chapterLimit);
    }
    if (!nullToAbsent || duplicatePolicy != null) {
      map['duplicate_policy'] = Variable<String>(duplicatePolicy);
    }
    if (!nullToAbsent || rangeMode != null) {
      map['range_mode'] = Variable<String>(rangeMode);
    }
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || origin != null) {
      map['origin'] = Variable<String>(origin);
    }
    if (!nullToAbsent || outcome != null) {
      map['outcome'] = Variable<String>(outcome);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['order_index'] = Variable<int>(orderIndex);
    map['queued_at'] = Variable<DateTime>(queuedAt);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<DateTime>(startedAt);
    }
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<DateTime>(finishedAt);
    }
    return map;
  }

  QueueTasksCompanion toCompanion(bool nullToAbsent) {
    return QueueTasksCompanion(
      id: Value(id),
      taskType: Value(taskType),
      libraryItemId: libraryItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(libraryItemId),
      startUrl: startUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(startUrl),
      chapterLimit: chapterLimit == null && nullToAbsent
          ? const Value.absent()
          : Value(chapterLimit),
      duplicatePolicy: duplicatePolicy == null && nullToAbsent
          ? const Value.absent()
          : Value(duplicatePolicy),
      rangeMode: rangeMode == null && nullToAbsent
          ? const Value.absent()
          : Value(rangeMode),
      state: Value(state),
      origin: origin == null && nullToAbsent
          ? const Value.absent()
          : Value(origin),
      outcome: outcome == null && nullToAbsent
          ? const Value.absent()
          : Value(outcome),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      orderIndex: Value(orderIndex),
      queuedAt: Value(queuedAt),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
    );
  }

  factory QueueTask.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QueueTask(
      id: serializer.fromJson<String>(json['id']),
      taskType: serializer.fromJson<String>(json['taskType']),
      libraryItemId: serializer.fromJson<String?>(json['libraryItemId']),
      startUrl: serializer.fromJson<String?>(json['startUrl']),
      chapterLimit: serializer.fromJson<int?>(json['chapterLimit']),
      duplicatePolicy: serializer.fromJson<String?>(json['duplicatePolicy']),
      rangeMode: serializer.fromJson<String?>(json['rangeMode']),
      state: serializer.fromJson<String>(json['state']),
      origin: serializer.fromJson<String?>(json['origin']),
      outcome: serializer.fromJson<String?>(json['outcome']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      queuedAt: serializer.fromJson<DateTime>(json['queuedAt']),
      startedAt: serializer.fromJson<DateTime?>(json['startedAt']),
      finishedAt: serializer.fromJson<DateTime?>(json['finishedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'taskType': serializer.toJson<String>(taskType),
      'libraryItemId': serializer.toJson<String?>(libraryItemId),
      'startUrl': serializer.toJson<String?>(startUrl),
      'chapterLimit': serializer.toJson<int?>(chapterLimit),
      'duplicatePolicy': serializer.toJson<String?>(duplicatePolicy),
      'rangeMode': serializer.toJson<String?>(rangeMode),
      'state': serializer.toJson<String>(state),
      'origin': serializer.toJson<String?>(origin),
      'outcome': serializer.toJson<String?>(outcome),
      'lastError': serializer.toJson<String?>(lastError),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'queuedAt': serializer.toJson<DateTime>(queuedAt),
      'startedAt': serializer.toJson<DateTime?>(startedAt),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
    };
  }

  QueueTask copyWith({
    String? id,
    String? taskType,
    Value<String?> libraryItemId = const Value.absent(),
    Value<String?> startUrl = const Value.absent(),
    Value<int?> chapterLimit = const Value.absent(),
    Value<String?> duplicatePolicy = const Value.absent(),
    Value<String?> rangeMode = const Value.absent(),
    String? state,
    Value<String?> origin = const Value.absent(),
    Value<String?> outcome = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    int? orderIndex,
    DateTime? queuedAt,
    Value<DateTime?> startedAt = const Value.absent(),
    Value<DateTime?> finishedAt = const Value.absent(),
  }) => QueueTask(
    id: id ?? this.id,
    taskType: taskType ?? this.taskType,
    libraryItemId: libraryItemId.present
        ? libraryItemId.value
        : this.libraryItemId,
    startUrl: startUrl.present ? startUrl.value : this.startUrl,
    chapterLimit: chapterLimit.present ? chapterLimit.value : this.chapterLimit,
    duplicatePolicy: duplicatePolicy.present
        ? duplicatePolicy.value
        : this.duplicatePolicy,
    rangeMode: rangeMode.present ? rangeMode.value : this.rangeMode,
    state: state ?? this.state,
    origin: origin.present ? origin.value : this.origin,
    outcome: outcome.present ? outcome.value : this.outcome,
    lastError: lastError.present ? lastError.value : this.lastError,
    orderIndex: orderIndex ?? this.orderIndex,
    queuedAt: queuedAt ?? this.queuedAt,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
  );
  QueueTask copyWithCompanion(QueueTasksCompanion data) {
    return QueueTask(
      id: data.id.present ? data.id.value : this.id,
      taskType: data.taskType.present ? data.taskType.value : this.taskType,
      libraryItemId: data.libraryItemId.present
          ? data.libraryItemId.value
          : this.libraryItemId,
      startUrl: data.startUrl.present ? data.startUrl.value : this.startUrl,
      chapterLimit: data.chapterLimit.present
          ? data.chapterLimit.value
          : this.chapterLimit,
      duplicatePolicy: data.duplicatePolicy.present
          ? data.duplicatePolicy.value
          : this.duplicatePolicy,
      rangeMode: data.rangeMode.present ? data.rangeMode.value : this.rangeMode,
      state: data.state.present ? data.state.value : this.state,
      origin: data.origin.present ? data.origin.value : this.origin,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      queuedAt: data.queuedAt.present ? data.queuedAt.value : this.queuedAt,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QueueTask(')
          ..write('id: $id, ')
          ..write('taskType: $taskType, ')
          ..write('libraryItemId: $libraryItemId, ')
          ..write('startUrl: $startUrl, ')
          ..write('chapterLimit: $chapterLimit, ')
          ..write('duplicatePolicy: $duplicatePolicy, ')
          ..write('rangeMode: $rangeMode, ')
          ..write('state: $state, ')
          ..write('origin: $origin, ')
          ..write('outcome: $outcome, ')
          ..write('lastError: $lastError, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskType,
    libraryItemId,
    startUrl,
    chapterLimit,
    duplicatePolicy,
    rangeMode,
    state,
    origin,
    outcome,
    lastError,
    orderIndex,
    queuedAt,
    startedAt,
    finishedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueueTask &&
          other.id == this.id &&
          other.taskType == this.taskType &&
          other.libraryItemId == this.libraryItemId &&
          other.startUrl == this.startUrl &&
          other.chapterLimit == this.chapterLimit &&
          other.duplicatePolicy == this.duplicatePolicy &&
          other.rangeMode == this.rangeMode &&
          other.state == this.state &&
          other.origin == this.origin &&
          other.outcome == this.outcome &&
          other.lastError == this.lastError &&
          other.orderIndex == this.orderIndex &&
          other.queuedAt == this.queuedAt &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt);
}

class QueueTasksCompanion extends UpdateCompanion<QueueTask> {
  final Value<String> id;
  final Value<String> taskType;
  final Value<String?> libraryItemId;
  final Value<String?> startUrl;
  final Value<int?> chapterLimit;
  final Value<String?> duplicatePolicy;
  final Value<String?> rangeMode;
  final Value<String> state;
  final Value<String?> origin;
  final Value<String?> outcome;
  final Value<String?> lastError;
  final Value<int> orderIndex;
  final Value<DateTime> queuedAt;
  final Value<DateTime?> startedAt;
  final Value<DateTime?> finishedAt;
  final Value<int> rowid;
  const QueueTasksCompanion({
    this.id = const Value.absent(),
    this.taskType = const Value.absent(),
    this.libraryItemId = const Value.absent(),
    this.startUrl = const Value.absent(),
    this.chapterLimit = const Value.absent(),
    this.duplicatePolicy = const Value.absent(),
    this.rangeMode = const Value.absent(),
    this.state = const Value.absent(),
    this.origin = const Value.absent(),
    this.outcome = const Value.absent(),
    this.lastError = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.queuedAt = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QueueTasksCompanion.insert({
    required String id,
    required String taskType,
    this.libraryItemId = const Value.absent(),
    this.startUrl = const Value.absent(),
    this.chapterLimit = const Value.absent(),
    this.duplicatePolicy = const Value.absent(),
    this.rangeMode = const Value.absent(),
    this.state = const Value.absent(),
    this.origin = const Value.absent(),
    this.outcome = const Value.absent(),
    this.lastError = const Value.absent(),
    this.orderIndex = const Value.absent(),
    required DateTime queuedAt,
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       taskType = Value(taskType),
       queuedAt = Value(queuedAt);
  static Insertable<QueueTask> custom({
    Expression<String>? id,
    Expression<String>? taskType,
    Expression<String>? libraryItemId,
    Expression<String>? startUrl,
    Expression<int>? chapterLimit,
    Expression<String>? duplicatePolicy,
    Expression<String>? rangeMode,
    Expression<String>? state,
    Expression<String>? origin,
    Expression<String>? outcome,
    Expression<String>? lastError,
    Expression<int>? orderIndex,
    Expression<DateTime>? queuedAt,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? finishedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskType != null) 'task_type': taskType,
      if (libraryItemId != null) 'library_item_id': libraryItemId,
      if (startUrl != null) 'start_url': startUrl,
      if (chapterLimit != null) 'chapter_limit': chapterLimit,
      if (duplicatePolicy != null) 'duplicate_policy': duplicatePolicy,
      if (rangeMode != null) 'range_mode': rangeMode,
      if (state != null) 'state': state,
      if (origin != null) 'origin': origin,
      if (outcome != null) 'outcome': outcome,
      if (lastError != null) 'last_error': lastError,
      if (orderIndex != null) 'order_index': orderIndex,
      if (queuedAt != null) 'queued_at': queuedAt,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QueueTasksCompanion copyWith({
    Value<String>? id,
    Value<String>? taskType,
    Value<String?>? libraryItemId,
    Value<String?>? startUrl,
    Value<int?>? chapterLimit,
    Value<String?>? duplicatePolicy,
    Value<String?>? rangeMode,
    Value<String>? state,
    Value<String?>? origin,
    Value<String?>? outcome,
    Value<String?>? lastError,
    Value<int>? orderIndex,
    Value<DateTime>? queuedAt,
    Value<DateTime?>? startedAt,
    Value<DateTime?>? finishedAt,
    Value<int>? rowid,
  }) {
    return QueueTasksCompanion(
      id: id ?? this.id,
      taskType: taskType ?? this.taskType,
      libraryItemId: libraryItemId ?? this.libraryItemId,
      startUrl: startUrl ?? this.startUrl,
      chapterLimit: chapterLimit ?? this.chapterLimit,
      duplicatePolicy: duplicatePolicy ?? this.duplicatePolicy,
      rangeMode: rangeMode ?? this.rangeMode,
      state: state ?? this.state,
      origin: origin ?? this.origin,
      outcome: outcome ?? this.outcome,
      lastError: lastError ?? this.lastError,
      orderIndex: orderIndex ?? this.orderIndex,
      queuedAt: queuedAt ?? this.queuedAt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskType.present) {
      map['task_type'] = Variable<String>(taskType.value);
    }
    if (libraryItemId.present) {
      map['library_item_id'] = Variable<String>(libraryItemId.value);
    }
    if (startUrl.present) {
      map['start_url'] = Variable<String>(startUrl.value);
    }
    if (chapterLimit.present) {
      map['chapter_limit'] = Variable<int>(chapterLimit.value);
    }
    if (duplicatePolicy.present) {
      map['duplicate_policy'] = Variable<String>(duplicatePolicy.value);
    }
    if (rangeMode.present) {
      map['range_mode'] = Variable<String>(rangeMode.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(outcome.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (queuedAt.present) {
      map['queued_at'] = Variable<DateTime>(queuedAt.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(finishedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QueueTasksCompanion(')
          ..write('id: $id, ')
          ..write('taskType: $taskType, ')
          ..write('libraryItemId: $libraryItemId, ')
          ..write('startUrl: $startUrl, ')
          ..write('chapterLimit: $chapterLimit, ')
          ..write('duplicatePolicy: $duplicatePolicy, ')
          ..write('rangeMode: $rangeMode, ')
          ..write('state: $state, ')
          ..write('origin: $origin, ')
          ..write('outcome: $outcome, ')
          ..write('lastError: $lastError, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BrowsingHistoryTable extends BrowsingHistory
    with TableInfo<$BrowsingHistoryTable, BrowsingHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BrowsingHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlKeyMeta = const VerificationMeta('urlKey');
  @override
  late final GeneratedColumn<String> urlKey = GeneratedColumn<String>(
    'url_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hostMeta = const VerificationMeta('host');
  @override
  late final GeneratedColumn<String> host = GeneratedColumn<String>(
    'host',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _finalUrlMeta = const VerificationMeta(
    'finalUrl',
  );
  @override
  late final GeneratedColumn<String> finalUrl = GeneratedColumn<String>(
    'final_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _visitedAtMeta = const VerificationMeta(
    'visitedAt',
  );
  @override
  late final GeneratedColumn<DateTime> visitedAt = GeneratedColumn<DateTime>(
    'visited_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    url,
    urlKey,
    host,
    title,
    source,
    finalUrl,
    completed,
    visitedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'browsing_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<BrowsingHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('url_key')) {
      context.handle(
        _urlKeyMeta,
        urlKey.isAcceptableOrUnknown(data['url_key']!, _urlKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_urlKeyMeta);
    }
    if (data.containsKey('host')) {
      context.handle(
        _hostMeta,
        host.isAcceptableOrUnknown(data['host']!, _hostMeta),
      );
    } else if (isInserting) {
      context.missing(_hostMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('final_url')) {
      context.handle(
        _finalUrlMeta,
        finalUrl.isAcceptableOrUnknown(data['final_url']!, _finalUrlMeta),
      );
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('visited_at')) {
      context.handle(
        _visitedAtMeta,
        visitedAt.isAcceptableOrUnknown(data['visited_at']!, _visitedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_visitedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BrowsingHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BrowsingHistoryData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      urlKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url_key'],
      )!,
      host: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      finalUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}final_url'],
      ),
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      visitedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}visited_at'],
      )!,
    );
  }

  @override
  $BrowsingHistoryTable createAlias(String alias) {
    return $BrowsingHistoryTable(attachedDatabase, alias);
  }
}

class BrowsingHistoryData extends DataClass
    implements Insertable<BrowsingHistoryData> {
  final String id;

  /// The address as the user would read it back.
  final String url;

  /// [normalizeUrl] of [url]. Grouping, dedup-within-a-window and
  /// "remove every visit to this page" all key off this, never the raw text.
  final String urlKey;
  final String host;
  final String title;

  /// Where the visit came from. Persisted even though the UI only ever shows
  /// `manual`: a row that says how it got here is debuggable, and a filter is
  /// cheaper to widen than a lost column is to reconstruct.
  final String source;

  /// The address the load actually settled on, when a redirect moved it.
  /// Null when nothing redirected.
  final String? finalUrl;

  /// Only completed, user-visible destinations are recorded, so this is true
  /// for every row written today. Kept because "the load finished" is the
  /// property the recording rule turns on, and an explicit column is what
  /// makes that rule inspectable rather than implied by absence.
  final bool completed;
  final DateTime visitedAt;
  const BrowsingHistoryData({
    required this.id,
    required this.url,
    required this.urlKey,
    required this.host,
    required this.title,
    required this.source,
    this.finalUrl,
    required this.completed,
    required this.visitedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['url'] = Variable<String>(url);
    map['url_key'] = Variable<String>(urlKey);
    map['host'] = Variable<String>(host);
    map['title'] = Variable<String>(title);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || finalUrl != null) {
      map['final_url'] = Variable<String>(finalUrl);
    }
    map['completed'] = Variable<bool>(completed);
    map['visited_at'] = Variable<DateTime>(visitedAt);
    return map;
  }

  BrowsingHistoryCompanion toCompanion(bool nullToAbsent) {
    return BrowsingHistoryCompanion(
      id: Value(id),
      url: Value(url),
      urlKey: Value(urlKey),
      host: Value(host),
      title: Value(title),
      source: Value(source),
      finalUrl: finalUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(finalUrl),
      completed: Value(completed),
      visitedAt: Value(visitedAt),
    );
  }

  factory BrowsingHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BrowsingHistoryData(
      id: serializer.fromJson<String>(json['id']),
      url: serializer.fromJson<String>(json['url']),
      urlKey: serializer.fromJson<String>(json['urlKey']),
      host: serializer.fromJson<String>(json['host']),
      title: serializer.fromJson<String>(json['title']),
      source: serializer.fromJson<String>(json['source']),
      finalUrl: serializer.fromJson<String?>(json['finalUrl']),
      completed: serializer.fromJson<bool>(json['completed']),
      visitedAt: serializer.fromJson<DateTime>(json['visitedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'url': serializer.toJson<String>(url),
      'urlKey': serializer.toJson<String>(urlKey),
      'host': serializer.toJson<String>(host),
      'title': serializer.toJson<String>(title),
      'source': serializer.toJson<String>(source),
      'finalUrl': serializer.toJson<String?>(finalUrl),
      'completed': serializer.toJson<bool>(completed),
      'visitedAt': serializer.toJson<DateTime>(visitedAt),
    };
  }

  BrowsingHistoryData copyWith({
    String? id,
    String? url,
    String? urlKey,
    String? host,
    String? title,
    String? source,
    Value<String?> finalUrl = const Value.absent(),
    bool? completed,
    DateTime? visitedAt,
  }) => BrowsingHistoryData(
    id: id ?? this.id,
    url: url ?? this.url,
    urlKey: urlKey ?? this.urlKey,
    host: host ?? this.host,
    title: title ?? this.title,
    source: source ?? this.source,
    finalUrl: finalUrl.present ? finalUrl.value : this.finalUrl,
    completed: completed ?? this.completed,
    visitedAt: visitedAt ?? this.visitedAt,
  );
  BrowsingHistoryData copyWithCompanion(BrowsingHistoryCompanion data) {
    return BrowsingHistoryData(
      id: data.id.present ? data.id.value : this.id,
      url: data.url.present ? data.url.value : this.url,
      urlKey: data.urlKey.present ? data.urlKey.value : this.urlKey,
      host: data.host.present ? data.host.value : this.host,
      title: data.title.present ? data.title.value : this.title,
      source: data.source.present ? data.source.value : this.source,
      finalUrl: data.finalUrl.present ? data.finalUrl.value : this.finalUrl,
      completed: data.completed.present ? data.completed.value : this.completed,
      visitedAt: data.visitedAt.present ? data.visitedAt.value : this.visitedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BrowsingHistoryData(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('urlKey: $urlKey, ')
          ..write('host: $host, ')
          ..write('title: $title, ')
          ..write('source: $source, ')
          ..write('finalUrl: $finalUrl, ')
          ..write('completed: $completed, ')
          ..write('visitedAt: $visitedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    url,
    urlKey,
    host,
    title,
    source,
    finalUrl,
    completed,
    visitedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BrowsingHistoryData &&
          other.id == this.id &&
          other.url == this.url &&
          other.urlKey == this.urlKey &&
          other.host == this.host &&
          other.title == this.title &&
          other.source == this.source &&
          other.finalUrl == this.finalUrl &&
          other.completed == this.completed &&
          other.visitedAt == this.visitedAt);
}

class BrowsingHistoryCompanion extends UpdateCompanion<BrowsingHistoryData> {
  final Value<String> id;
  final Value<String> url;
  final Value<String> urlKey;
  final Value<String> host;
  final Value<String> title;
  final Value<String> source;
  final Value<String?> finalUrl;
  final Value<bool> completed;
  final Value<DateTime> visitedAt;
  final Value<int> rowid;
  const BrowsingHistoryCompanion({
    this.id = const Value.absent(),
    this.url = const Value.absent(),
    this.urlKey = const Value.absent(),
    this.host = const Value.absent(),
    this.title = const Value.absent(),
    this.source = const Value.absent(),
    this.finalUrl = const Value.absent(),
    this.completed = const Value.absent(),
    this.visitedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BrowsingHistoryCompanion.insert({
    required String id,
    required String url,
    required String urlKey,
    required String host,
    required String title,
    this.source = const Value.absent(),
    this.finalUrl = const Value.absent(),
    this.completed = const Value.absent(),
    required DateTime visitedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       url = Value(url),
       urlKey = Value(urlKey),
       host = Value(host),
       title = Value(title),
       visitedAt = Value(visitedAt);
  static Insertable<BrowsingHistoryData> custom({
    Expression<String>? id,
    Expression<String>? url,
    Expression<String>? urlKey,
    Expression<String>? host,
    Expression<String>? title,
    Expression<String>? source,
    Expression<String>? finalUrl,
    Expression<bool>? completed,
    Expression<DateTime>? visitedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (url != null) 'url': url,
      if (urlKey != null) 'url_key': urlKey,
      if (host != null) 'host': host,
      if (title != null) 'title': title,
      if (source != null) 'source': source,
      if (finalUrl != null) 'final_url': finalUrl,
      if (completed != null) 'completed': completed,
      if (visitedAt != null) 'visited_at': visitedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BrowsingHistoryCompanion copyWith({
    Value<String>? id,
    Value<String>? url,
    Value<String>? urlKey,
    Value<String>? host,
    Value<String>? title,
    Value<String>? source,
    Value<String?>? finalUrl,
    Value<bool>? completed,
    Value<DateTime>? visitedAt,
    Value<int>? rowid,
  }) {
    return BrowsingHistoryCompanion(
      id: id ?? this.id,
      url: url ?? this.url,
      urlKey: urlKey ?? this.urlKey,
      host: host ?? this.host,
      title: title ?? this.title,
      source: source ?? this.source,
      finalUrl: finalUrl ?? this.finalUrl,
      completed: completed ?? this.completed,
      visitedAt: visitedAt ?? this.visitedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (urlKey.present) {
      map['url_key'] = Variable<String>(urlKey.value);
    }
    if (host.present) {
      map['host'] = Variable<String>(host.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (finalUrl.present) {
      map['final_url'] = Variable<String>(finalUrl.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (visitedAt.present) {
      map['visited_at'] = Variable<DateTime>(visitedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BrowsingHistoryCompanion(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('urlKey: $urlKey, ')
          ..write('host: $host, ')
          ..write('title: $title, ')
          ..write('source: $source, ')
          ..write('finalUrl: $finalUrl, ')
          ..write('completed: $completed, ')
          ..write('visitedAt: $visitedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SavedSitesTable extends SavedSites
    with TableInfo<$SavedSitesTable, SavedSite> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedSitesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlKeyMeta = const VerificationMeta('urlKey');
  @override
  late final GeneratedColumn<String> urlKey = GeneratedColumn<String>(
    'url_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hostMeta = const VerificationMeta('host');
  @override
  late final GeneratedColumn<String> host = GeneratedColumn<String>(
    'host',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _userTitleMeta = const VerificationMeta(
    'userTitle',
  );
  @override
  late final GeneratedColumn<String> userTitle = GeneratedColumn<String>(
    'user_title',
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
  static const VerificationMeta _lastOpenedAtMeta = const VerificationMeta(
    'lastOpenedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastOpenedAt = GeneratedColumn<DateTime>(
    'last_opened_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    url,
    urlKey,
    host,
    title,
    userTitle,
    createdAt,
    updatedAt,
    lastOpenedAt,
    orderIndex,
    isDefault,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_sites';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedSite> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('url_key')) {
      context.handle(
        _urlKeyMeta,
        urlKey.isAcceptableOrUnknown(data['url_key']!, _urlKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_urlKeyMeta);
    }
    if (data.containsKey('host')) {
      context.handle(
        _hostMeta,
        host.isAcceptableOrUnknown(data['host']!, _hostMeta),
      );
    } else if (isInserting) {
      context.missing(_hostMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('user_title')) {
      context.handle(
        _userTitleMeta,
        userTitle.isAcceptableOrUnknown(data['user_title']!, _userTitleMeta),
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
    if (data.containsKey('last_opened_at')) {
      context.handle(
        _lastOpenedAtMeta,
        lastOpenedAt.isAcceptableOrUnknown(
          data['last_opened_at']!,
          _lastOpenedAtMeta,
        ),
      );
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedSite map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedSite(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      urlKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url_key'],
      )!,
      host: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      userTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_title'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      lastOpenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_opened_at'],
      ),
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
    );
  }

  @override
  $SavedSitesTable createAlias(String alias) {
    return $SavedSitesTable(attachedDatabase, alias);
  }
}

class SavedSite extends DataClass implements Insertable<SavedSite> {
  final String id;
  final String url;

  /// Identity for duplicate detection. Two saved sites may share a host; they
  /// may not share a normalised URL.
  final String urlKey;
  final String host;

  /// The title as captured from the page (or derived from the host).
  final String title;

  /// What the user typed instead. Presentation only — [title] is kept so
  /// clearing a rename falls back to something real.
  final String? userTitle;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastOpenedAt;

  /// Hand-ordered position. Ties fall back to [createdAt], so a row that was
  /// never reordered still has a stable place.
  final int orderIndex;

  /// True for the Google row seeded on a clean install. Only meaningful to
  /// the seeder: the user may rename, re-point, reorder or remove it exactly
  /// like any other row, and it is never recreated afterwards (D54).
  final bool isDefault;
  const SavedSite({
    required this.id,
    required this.url,
    required this.urlKey,
    required this.host,
    required this.title,
    this.userTitle,
    required this.createdAt,
    required this.updatedAt,
    this.lastOpenedAt,
    required this.orderIndex,
    required this.isDefault,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['url'] = Variable<String>(url);
    map['url_key'] = Variable<String>(urlKey);
    map['host'] = Variable<String>(host);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || userTitle != null) {
      map['user_title'] = Variable<String>(userTitle);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || lastOpenedAt != null) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt);
    }
    map['order_index'] = Variable<int>(orderIndex);
    map['is_default'] = Variable<bool>(isDefault);
    return map;
  }

  SavedSitesCompanion toCompanion(bool nullToAbsent) {
    return SavedSitesCompanion(
      id: Value(id),
      url: Value(url),
      urlKey: Value(urlKey),
      host: Value(host),
      title: Value(title),
      userTitle: userTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(userTitle),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      lastOpenedAt: lastOpenedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastOpenedAt),
      orderIndex: Value(orderIndex),
      isDefault: Value(isDefault),
    );
  }

  factory SavedSite.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedSite(
      id: serializer.fromJson<String>(json['id']),
      url: serializer.fromJson<String>(json['url']),
      urlKey: serializer.fromJson<String>(json['urlKey']),
      host: serializer.fromJson<String>(json['host']),
      title: serializer.fromJson<String>(json['title']),
      userTitle: serializer.fromJson<String?>(json['userTitle']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      lastOpenedAt: serializer.fromJson<DateTime?>(json['lastOpenedAt']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'url': serializer.toJson<String>(url),
      'urlKey': serializer.toJson<String>(urlKey),
      'host': serializer.toJson<String>(host),
      'title': serializer.toJson<String>(title),
      'userTitle': serializer.toJson<String?>(userTitle),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'lastOpenedAt': serializer.toJson<DateTime?>(lastOpenedAt),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'isDefault': serializer.toJson<bool>(isDefault),
    };
  }

  SavedSite copyWith({
    String? id,
    String? url,
    String? urlKey,
    String? host,
    String? title,
    Value<String?> userTitle = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> lastOpenedAt = const Value.absent(),
    int? orderIndex,
    bool? isDefault,
  }) => SavedSite(
    id: id ?? this.id,
    url: url ?? this.url,
    urlKey: urlKey ?? this.urlKey,
    host: host ?? this.host,
    title: title ?? this.title,
    userTitle: userTitle.present ? userTitle.value : this.userTitle,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastOpenedAt: lastOpenedAt.present ? lastOpenedAt.value : this.lastOpenedAt,
    orderIndex: orderIndex ?? this.orderIndex,
    isDefault: isDefault ?? this.isDefault,
  );
  SavedSite copyWithCompanion(SavedSitesCompanion data) {
    return SavedSite(
      id: data.id.present ? data.id.value : this.id,
      url: data.url.present ? data.url.value : this.url,
      urlKey: data.urlKey.present ? data.urlKey.value : this.urlKey,
      host: data.host.present ? data.host.value : this.host,
      title: data.title.present ? data.title.value : this.title,
      userTitle: data.userTitle.present ? data.userTitle.value : this.userTitle,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastOpenedAt: data.lastOpenedAt.present
          ? data.lastOpenedAt.value
          : this.lastOpenedAt,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedSite(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('urlKey: $urlKey, ')
          ..write('host: $host, ')
          ..write('title: $title, ')
          ..write('userTitle: $userTitle, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('isDefault: $isDefault')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    url,
    urlKey,
    host,
    title,
    userTitle,
    createdAt,
    updatedAt,
    lastOpenedAt,
    orderIndex,
    isDefault,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedSite &&
          other.id == this.id &&
          other.url == this.url &&
          other.urlKey == this.urlKey &&
          other.host == this.host &&
          other.title == this.title &&
          other.userTitle == this.userTitle &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.lastOpenedAt == this.lastOpenedAt &&
          other.orderIndex == this.orderIndex &&
          other.isDefault == this.isDefault);
}

class SavedSitesCompanion extends UpdateCompanion<SavedSite> {
  final Value<String> id;
  final Value<String> url;
  final Value<String> urlKey;
  final Value<String> host;
  final Value<String> title;
  final Value<String?> userTitle;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> lastOpenedAt;
  final Value<int> orderIndex;
  final Value<bool> isDefault;
  final Value<int> rowid;
  const SavedSitesCompanion({
    this.id = const Value.absent(),
    this.url = const Value.absent(),
    this.urlKey = const Value.absent(),
    this.host = const Value.absent(),
    this.title = const Value.absent(),
    this.userTitle = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedSitesCompanion.insert({
    required String id,
    required String url,
    required String urlKey,
    required String host,
    required String title,
    this.userTitle = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.lastOpenedAt = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       url = Value(url),
       urlKey = Value(urlKey),
       host = Value(host),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SavedSite> custom({
    Expression<String>? id,
    Expression<String>? url,
    Expression<String>? urlKey,
    Expression<String>? host,
    Expression<String>? title,
    Expression<String>? userTitle,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? lastOpenedAt,
    Expression<int>? orderIndex,
    Expression<bool>? isDefault,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (url != null) 'url': url,
      if (urlKey != null) 'url_key': urlKey,
      if (host != null) 'host': host,
      if (title != null) 'title': title,
      if (userTitle != null) 'user_title': userTitle,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastOpenedAt != null) 'last_opened_at': lastOpenedAt,
      if (orderIndex != null) 'order_index': orderIndex,
      if (isDefault != null) 'is_default': isDefault,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedSitesCompanion copyWith({
    Value<String>? id,
    Value<String>? url,
    Value<String>? urlKey,
    Value<String>? host,
    Value<String>? title,
    Value<String?>? userTitle,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? lastOpenedAt,
    Value<int>? orderIndex,
    Value<bool>? isDefault,
    Value<int>? rowid,
  }) {
    return SavedSitesCompanion(
      id: id ?? this.id,
      url: url ?? this.url,
      urlKey: urlKey ?? this.urlKey,
      host: host ?? this.host,
      title: title ?? this.title,
      userTitle: userTitle ?? this.userTitle,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      orderIndex: orderIndex ?? this.orderIndex,
      isDefault: isDefault ?? this.isDefault,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (urlKey.present) {
      map['url_key'] = Variable<String>(urlKey.value);
    }
    if (host.present) {
      map['host'] = Variable<String>(host.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (userTitle.present) {
      map['user_title'] = Variable<String>(userTitle.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (lastOpenedAt.present) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedSitesCompanion(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('urlKey: $urlKey, ')
          ..write('host: $host, ')
          ..write('title: $title, ')
          ..write('userTitle: $userTitle, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('isDefault: $isDefault, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FaviconCacheTable extends FaviconCache
    with TableInfo<$FaviconCacheTable, FaviconCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FaviconCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _hostMeta = const VerificationMeta('host');
  @override
  late final GeneratedColumn<String> host = GeneratedColumn<String>(
    'host',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<Uint8List> bytes = GeneratedColumn<Uint8List>(
    'bytes',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  List<GeneratedColumn> get $columns => [host, bytes, sourceUrl, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favicon_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<FaviconCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('host')) {
      context.handle(
        _hostMeta,
        host.isAcceptableOrUnknown(data['host']!, _hostMeta),
      );
    } else if (isInserting) {
      context.missing(_hostMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
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
  Set<GeneratedColumn> get $primaryKey => {host};
  @override
  FaviconCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FaviconCacheData(
      host: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}bytes'],
      ),
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      ),
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $FaviconCacheTable createAlias(String alias) {
    return $FaviconCacheTable(attachedDatabase, alias);
  }
}

class FaviconCacheData extends DataClass
    implements Insertable<FaviconCacheData> {
  final String host;

  /// The icon bytes, or null when the last attempt failed. A null row is a
  /// *negative* cache entry — it stops every list rebuild from re-requesting
  /// an icon the site does not have.
  final Uint8List? bytes;

  /// Where the bytes came from, for debugging a wrong icon.
  final String? sourceUrl;
  final DateTime fetchedAt;
  const FaviconCacheData({
    required this.host,
    this.bytes,
    this.sourceUrl,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['host'] = Variable<String>(host);
    if (!nullToAbsent || bytes != null) {
      map['bytes'] = Variable<Uint8List>(bytes);
    }
    if (!nullToAbsent || sourceUrl != null) {
      map['source_url'] = Variable<String>(sourceUrl);
    }
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  FaviconCacheCompanion toCompanion(bool nullToAbsent) {
    return FaviconCacheCompanion(
      host: Value(host),
      bytes: bytes == null && nullToAbsent
          ? const Value.absent()
          : Value(bytes),
      sourceUrl: sourceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUrl),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory FaviconCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FaviconCacheData(
      host: serializer.fromJson<String>(json['host']),
      bytes: serializer.fromJson<Uint8List?>(json['bytes']),
      sourceUrl: serializer.fromJson<String?>(json['sourceUrl']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'host': serializer.toJson<String>(host),
      'bytes': serializer.toJson<Uint8List?>(bytes),
      'sourceUrl': serializer.toJson<String?>(sourceUrl),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  FaviconCacheData copyWith({
    String? host,
    Value<Uint8List?> bytes = const Value.absent(),
    Value<String?> sourceUrl = const Value.absent(),
    DateTime? fetchedAt,
  }) => FaviconCacheData(
    host: host ?? this.host,
    bytes: bytes.present ? bytes.value : this.bytes,
    sourceUrl: sourceUrl.present ? sourceUrl.value : this.sourceUrl,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  FaviconCacheData copyWithCompanion(FaviconCacheCompanion data) {
    return FaviconCacheData(
      host: data.host.present ? data.host.value : this.host,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FaviconCacheData(')
          ..write('host: $host, ')
          ..write('bytes: $bytes, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(host, $driftBlobEquality.hash(bytes), sourceUrl, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FaviconCacheData &&
          other.host == this.host &&
          $driftBlobEquality.equals(other.bytes, this.bytes) &&
          other.sourceUrl == this.sourceUrl &&
          other.fetchedAt == this.fetchedAt);
}

class FaviconCacheCompanion extends UpdateCompanion<FaviconCacheData> {
  final Value<String> host;
  final Value<Uint8List?> bytes;
  final Value<String?> sourceUrl;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const FaviconCacheCompanion({
    this.host = const Value.absent(),
    this.bytes = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FaviconCacheCompanion.insert({
    required String host,
    this.bytes = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  }) : host = Value(host),
       fetchedAt = Value(fetchedAt);
  static Insertable<FaviconCacheData> custom({
    Expression<String>? host,
    Expression<Uint8List>? bytes,
    Expression<String>? sourceUrl,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (host != null) 'host': host,
      if (bytes != null) 'bytes': bytes,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FaviconCacheCompanion copyWith({
    Value<String>? host,
    Value<Uint8List?>? bytes,
    Value<String?>? sourceUrl,
    Value<DateTime>? fetchedAt,
    Value<int>? rowid,
  }) {
    return FaviconCacheCompanion(
      host: host ?? this.host,
      bytes: bytes ?? this.bytes,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (host.present) {
      map['host'] = Variable<String>(host.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<Uint8List>(bytes.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
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
    return (StringBuffer('FaviconCacheCompanion(')
          ..write('host: $host, ')
          ..write('bytes: $bytes, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LibraryItemsTable libraryItems = $LibraryItemsTable(this);
  late final $ChaptersTable chapters = $ChaptersTable(this);
  late final $CaptureJobsTable captureJobs = $CaptureJobsTable(this);
  late final $SiteRuleRowsTable siteRuleRows = $SiteRuleRowsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $QueueTasksTable queueTasks = $QueueTasksTable(this);
  late final $BrowsingHistoryTable browsingHistory = $BrowsingHistoryTable(
    this,
  );
  late final $SavedSitesTable savedSites = $SavedSitesTable(this);
  late final $FaviconCacheTable faviconCache = $FaviconCacheTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    libraryItems,
    chapters,
    captureJobs,
    siteRuleRows,
    settings,
    queueTasks,
    browsingHistory,
    savedSites,
    faviconCache,
  ];
}

typedef $$LibraryItemsTableCreateCompanionBuilder =
    LibraryItemsCompanion Function({
      required String id,
      required String title,
      Value<String?> userTitle,
      required String sourceUrl,
      required String host,
      Value<String?> seriesKey,
      Value<String?> seriesUrl,
      Value<String?> identityBasis,
      Value<String?> identityConfidence,
      required DateTime createdAt,
      Value<DateTime?> lastOpenedAt,
      Value<DateTime?> lastCapturedAt,
      Value<String?> lastOpenedChapterId,
      Value<String?> lastCompletedChapterId,
      Value<DateTime?> lastReadAt,
      Value<DateTime?> lastCheckAt,
      Value<DateTime?> lastCheckSuccessAt,
      Value<String?> lastCheckError,
      Value<String?> lastCheckResult,
      Value<String> lifecycle,
      Value<DateTime?> archivedAt,
      Value<int> rowid,
    });
typedef $$LibraryItemsTableUpdateCompanionBuilder =
    LibraryItemsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> userTitle,
      Value<String> sourceUrl,
      Value<String> host,
      Value<String?> seriesKey,
      Value<String?> seriesUrl,
      Value<String?> identityBasis,
      Value<String?> identityConfidence,
      Value<DateTime> createdAt,
      Value<DateTime?> lastOpenedAt,
      Value<DateTime?> lastCapturedAt,
      Value<String?> lastOpenedChapterId,
      Value<String?> lastCompletedChapterId,
      Value<DateTime?> lastReadAt,
      Value<DateTime?> lastCheckAt,
      Value<DateTime?> lastCheckSuccessAt,
      Value<String?> lastCheckError,
      Value<String?> lastCheckResult,
      Value<String> lifecycle,
      Value<DateTime?> archivedAt,
      Value<int> rowid,
    });

final class $$LibraryItemsTableReferences
    extends BaseReferences<_$AppDatabase, $LibraryItemsTable, LibraryItem> {
  $$LibraryItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ChaptersTable, List<Chapter>> _chaptersRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.chapters,
    aliasName: 'library_items__id__chapters__library_item_id',
  );

  $$ChaptersTableProcessedTableManager get chaptersRefs {
    final manager = $$ChaptersTableTableManager(
      $_db,
      $_db.chapters,
    ).filter((f) => f.libraryItemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_chaptersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LibraryItemsTableFilterComposer
    extends Composer<_$AppDatabase, $LibraryItemsTable> {
  $$LibraryItemsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userTitle => $composableBuilder(
    column: $table.userTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seriesKey => $composableBuilder(
    column: $table.seriesKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seriesUrl => $composableBuilder(
    column: $table.seriesUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get identityBasis => $composableBuilder(
    column: $table.identityBasis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get identityConfidence => $composableBuilder(
    column: $table.identityConfidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastCapturedAt => $composableBuilder(
    column: $table.lastCapturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastOpenedChapterId => $composableBuilder(
    column: $table.lastOpenedChapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastCompletedChapterId => $composableBuilder(
    column: $table.lastCompletedChapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastCheckAt => $composableBuilder(
    column: $table.lastCheckAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastCheckSuccessAt => $composableBuilder(
    column: $table.lastCheckSuccessAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastCheckError => $composableBuilder(
    column: $table.lastCheckError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastCheckResult => $composableBuilder(
    column: $table.lastCheckResult,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lifecycle => $composableBuilder(
    column: $table.lifecycle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> chaptersRefs(
    Expression<bool> Function($$ChaptersTableFilterComposer f) f,
  ) {
    final $$ChaptersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.libraryItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableFilterComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibraryItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $LibraryItemsTable> {
  $$LibraryItemsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userTitle => $composableBuilder(
    column: $table.userTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seriesKey => $composableBuilder(
    column: $table.seriesKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seriesUrl => $composableBuilder(
    column: $table.seriesUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get identityBasis => $composableBuilder(
    column: $table.identityBasis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get identityConfidence => $composableBuilder(
    column: $table.identityConfidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastCapturedAt => $composableBuilder(
    column: $table.lastCapturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastOpenedChapterId => $composableBuilder(
    column: $table.lastOpenedChapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastCompletedChapterId => $composableBuilder(
    column: $table.lastCompletedChapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastCheckAt => $composableBuilder(
    column: $table.lastCheckAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastCheckSuccessAt => $composableBuilder(
    column: $table.lastCheckSuccessAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastCheckError => $composableBuilder(
    column: $table.lastCheckError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastCheckResult => $composableBuilder(
    column: $table.lastCheckResult,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lifecycle => $composableBuilder(
    column: $table.lifecycle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LibraryItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LibraryItemsTable> {
  $$LibraryItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get userTitle =>
      $composableBuilder(column: $table.userTitle, builder: (column) => column);

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get host =>
      $composableBuilder(column: $table.host, builder: (column) => column);

  GeneratedColumn<String> get seriesKey =>
      $composableBuilder(column: $table.seriesKey, builder: (column) => column);

  GeneratedColumn<String> get seriesUrl =>
      $composableBuilder(column: $table.seriesUrl, builder: (column) => column);

  GeneratedColumn<String> get identityBasis => $composableBuilder(
    column: $table.identityBasis,
    builder: (column) => column,
  );

  GeneratedColumn<String> get identityConfidence => $composableBuilder(
    column: $table.identityConfidence,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastCapturedAt => $composableBuilder(
    column: $table.lastCapturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastOpenedChapterId => $composableBuilder(
    column: $table.lastOpenedChapterId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastCompletedChapterId => $composableBuilder(
    column: $table.lastCompletedChapterId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastCheckAt => $composableBuilder(
    column: $table.lastCheckAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastCheckSuccessAt => $composableBuilder(
    column: $table.lastCheckSuccessAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastCheckError => $composableBuilder(
    column: $table.lastCheckError,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastCheckResult => $composableBuilder(
    column: $table.lastCheckResult,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lifecycle =>
      $composableBuilder(column: $table.lifecycle, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  Expression<T> chaptersRefs<T extends Object>(
    Expression<T> Function($$ChaptersTableAnnotationComposer a) f,
  ) {
    final $$ChaptersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.libraryItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableAnnotationComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibraryItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LibraryItemsTable,
          LibraryItem,
          $$LibraryItemsTableFilterComposer,
          $$LibraryItemsTableOrderingComposer,
          $$LibraryItemsTableAnnotationComposer,
          $$LibraryItemsTableCreateCompanionBuilder,
          $$LibraryItemsTableUpdateCompanionBuilder,
          (LibraryItem, $$LibraryItemsTableReferences),
          LibraryItem,
          PrefetchHooks Function({bool chaptersRefs})
        > {
  $$LibraryItemsTableTableManager(_$AppDatabase db, $LibraryItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> userTitle = const Value.absent(),
                Value<String> sourceUrl = const Value.absent(),
                Value<String> host = const Value.absent(),
                Value<String?> seriesKey = const Value.absent(),
                Value<String?> seriesUrl = const Value.absent(),
                Value<String?> identityBasis = const Value.absent(),
                Value<String?> identityConfidence = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastOpenedAt = const Value.absent(),
                Value<DateTime?> lastCapturedAt = const Value.absent(),
                Value<String?> lastOpenedChapterId = const Value.absent(),
                Value<String?> lastCompletedChapterId = const Value.absent(),
                Value<DateTime?> lastReadAt = const Value.absent(),
                Value<DateTime?> lastCheckAt = const Value.absent(),
                Value<DateTime?> lastCheckSuccessAt = const Value.absent(),
                Value<String?> lastCheckError = const Value.absent(),
                Value<String?> lastCheckResult = const Value.absent(),
                Value<String> lifecycle = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryItemsCompanion(
                id: id,
                title: title,
                userTitle: userTitle,
                sourceUrl: sourceUrl,
                host: host,
                seriesKey: seriesKey,
                seriesUrl: seriesUrl,
                identityBasis: identityBasis,
                identityConfidence: identityConfidence,
                createdAt: createdAt,
                lastOpenedAt: lastOpenedAt,
                lastCapturedAt: lastCapturedAt,
                lastOpenedChapterId: lastOpenedChapterId,
                lastCompletedChapterId: lastCompletedChapterId,
                lastReadAt: lastReadAt,
                lastCheckAt: lastCheckAt,
                lastCheckSuccessAt: lastCheckSuccessAt,
                lastCheckError: lastCheckError,
                lastCheckResult: lastCheckResult,
                lifecycle: lifecycle,
                archivedAt: archivedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> userTitle = const Value.absent(),
                required String sourceUrl,
                required String host,
                Value<String?> seriesKey = const Value.absent(),
                Value<String?> seriesUrl = const Value.absent(),
                Value<String?> identityBasis = const Value.absent(),
                Value<String?> identityConfidence = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> lastOpenedAt = const Value.absent(),
                Value<DateTime?> lastCapturedAt = const Value.absent(),
                Value<String?> lastOpenedChapterId = const Value.absent(),
                Value<String?> lastCompletedChapterId = const Value.absent(),
                Value<DateTime?> lastReadAt = const Value.absent(),
                Value<DateTime?> lastCheckAt = const Value.absent(),
                Value<DateTime?> lastCheckSuccessAt = const Value.absent(),
                Value<String?> lastCheckError = const Value.absent(),
                Value<String?> lastCheckResult = const Value.absent(),
                Value<String> lifecycle = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryItemsCompanion.insert(
                id: id,
                title: title,
                userTitle: userTitle,
                sourceUrl: sourceUrl,
                host: host,
                seriesKey: seriesKey,
                seriesUrl: seriesUrl,
                identityBasis: identityBasis,
                identityConfidence: identityConfidence,
                createdAt: createdAt,
                lastOpenedAt: lastOpenedAt,
                lastCapturedAt: lastCapturedAt,
                lastOpenedChapterId: lastOpenedChapterId,
                lastCompletedChapterId: lastCompletedChapterId,
                lastReadAt: lastReadAt,
                lastCheckAt: lastCheckAt,
                lastCheckSuccessAt: lastCheckSuccessAt,
                lastCheckError: lastCheckError,
                lastCheckResult: lastCheckResult,
                lifecycle: lifecycle,
                archivedAt: archivedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LibraryItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({chaptersRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (chaptersRefs) db.chapters],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (chaptersRefs)
                    await $_getPrefetchedData<
                      LibraryItem,
                      $LibraryItemsTable,
                      Chapter
                    >(
                      currentTable: table,
                      referencedTable: $$LibraryItemsTableReferences
                          ._chaptersRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LibraryItemsTableReferences(
                            db,
                            table,
                            p0,
                          ).chaptersRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.libraryItemId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LibraryItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LibraryItemsTable,
      LibraryItem,
      $$LibraryItemsTableFilterComposer,
      $$LibraryItemsTableOrderingComposer,
      $$LibraryItemsTableAnnotationComposer,
      $$LibraryItemsTableCreateCompanionBuilder,
      $$LibraryItemsTableUpdateCompanionBuilder,
      (LibraryItem, $$LibraryItemsTableReferences),
      LibraryItem,
      PrefetchHooks Function({bool chaptersRefs})
    >;
typedef $$ChaptersTableCreateCompanionBuilder =
    ChaptersCompanion Function({
      required String id,
      required String libraryItemId,
      required String title,
      required String sourceUrl,
      required String urlKey,
      required String captureStatus,
      Value<String?> contentPath,
      Value<DateTime?> capturedAt,
      Value<int> detectedImageCount,
      Value<int> storedImageCount,
      Value<String?> nextSourceUrl,
      Value<int> sequence,
      Value<String?> captureError,
      Value<int> byteSize,
      Value<double?> chapterNumber,
      Value<String?> chapterLabel,
      Value<String> readStatus,
      Value<double> progressFraction,
      Value<int> progressImageIndex,
      Value<double> progressOffsetInImage,
      Value<DateTime?> firstOpenedAt,
      Value<DateTime?> lastReadAt,
      Value<DateTime?> completedAt,
      Value<DateTime?> progressUpdatedAt,
      Value<DateTime?> discoveredAt,
      Value<String?> discoveryBasis,
      Value<String?> discoveryConfidence,
      Value<DateTime?> offlineRemovedAt,
      Value<int> rowid,
    });
typedef $$ChaptersTableUpdateCompanionBuilder =
    ChaptersCompanion Function({
      Value<String> id,
      Value<String> libraryItemId,
      Value<String> title,
      Value<String> sourceUrl,
      Value<String> urlKey,
      Value<String> captureStatus,
      Value<String?> contentPath,
      Value<DateTime?> capturedAt,
      Value<int> detectedImageCount,
      Value<int> storedImageCount,
      Value<String?> nextSourceUrl,
      Value<int> sequence,
      Value<String?> captureError,
      Value<int> byteSize,
      Value<double?> chapterNumber,
      Value<String?> chapterLabel,
      Value<String> readStatus,
      Value<double> progressFraction,
      Value<int> progressImageIndex,
      Value<double> progressOffsetInImage,
      Value<DateTime?> firstOpenedAt,
      Value<DateTime?> lastReadAt,
      Value<DateTime?> completedAt,
      Value<DateTime?> progressUpdatedAt,
      Value<DateTime?> discoveredAt,
      Value<String?> discoveryBasis,
      Value<String?> discoveryConfidence,
      Value<DateTime?> offlineRemovedAt,
      Value<int> rowid,
    });

final class $$ChaptersTableReferences
    extends BaseReferences<_$AppDatabase, $ChaptersTable, Chapter> {
  $$ChaptersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LibraryItemsTable _libraryItemIdTable(_$AppDatabase db) => db
      .libraryItems
      .createAlias('chapters__library_item_id__library_items__id');

  $$LibraryItemsTableProcessedTableManager get libraryItemId {
    final $_column = $_itemColumn<String>('library_item_id')!;

    final manager = $$LibraryItemsTableTableManager(
      $_db,
      $_db.libraryItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_libraryItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ChaptersTableFilterComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get urlKey => $composableBuilder(
    column: $table.urlKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get captureStatus => $composableBuilder(
    column: $table.captureStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentPath => $composableBuilder(
    column: $table.contentPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get detectedImageCount => $composableBuilder(
    column: $table.detectedImageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get storedImageCount => $composableBuilder(
    column: $table.storedImageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nextSourceUrl => $composableBuilder(
    column: $table.nextSourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get captureError => $composableBuilder(
    column: $table.captureError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get chapterNumber => $composableBuilder(
    column: $table.chapterNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterLabel => $composableBuilder(
    column: $table.chapterLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get readStatus => $composableBuilder(
    column: $table.readStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progressFraction => $composableBuilder(
    column: $table.progressFraction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get progressImageIndex => $composableBuilder(
    column: $table.progressImageIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progressOffsetInImage => $composableBuilder(
    column: $table.progressOffsetInImage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get firstOpenedAt => $composableBuilder(
    column: $table.firstOpenedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get progressUpdatedAt => $composableBuilder(
    column: $table.progressUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get discoveredAt => $composableBuilder(
    column: $table.discoveredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get discoveryBasis => $composableBuilder(
    column: $table.discoveryBasis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get discoveryConfidence => $composableBuilder(
    column: $table.discoveryConfidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get offlineRemovedAt => $composableBuilder(
    column: $table.offlineRemovedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LibraryItemsTableFilterComposer get libraryItemId {
    final $$LibraryItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.libraryItemId,
      referencedTable: $db.libraryItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryItemsTableFilterComposer(
            $db: $db,
            $table: $db.libraryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChaptersTableOrderingComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get urlKey => $composableBuilder(
    column: $table.urlKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get captureStatus => $composableBuilder(
    column: $table.captureStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentPath => $composableBuilder(
    column: $table.contentPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get detectedImageCount => $composableBuilder(
    column: $table.detectedImageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get storedImageCount => $composableBuilder(
    column: $table.storedImageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nextSourceUrl => $composableBuilder(
    column: $table.nextSourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get captureError => $composableBuilder(
    column: $table.captureError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get chapterNumber => $composableBuilder(
    column: $table.chapterNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterLabel => $composableBuilder(
    column: $table.chapterLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get readStatus => $composableBuilder(
    column: $table.readStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progressFraction => $composableBuilder(
    column: $table.progressFraction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get progressImageIndex => $composableBuilder(
    column: $table.progressImageIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progressOffsetInImage => $composableBuilder(
    column: $table.progressOffsetInImage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firstOpenedAt => $composableBuilder(
    column: $table.firstOpenedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get progressUpdatedAt => $composableBuilder(
    column: $table.progressUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get discoveredAt => $composableBuilder(
    column: $table.discoveredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get discoveryBasis => $composableBuilder(
    column: $table.discoveryBasis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get discoveryConfidence => $composableBuilder(
    column: $table.discoveryConfidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get offlineRemovedAt => $composableBuilder(
    column: $table.offlineRemovedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LibraryItemsTableOrderingComposer get libraryItemId {
    final $$LibraryItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.libraryItemId,
      referencedTable: $db.libraryItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryItemsTableOrderingComposer(
            $db: $db,
            $table: $db.libraryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChaptersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get urlKey =>
      $composableBuilder(column: $table.urlKey, builder: (column) => column);

  GeneratedColumn<String> get captureStatus => $composableBuilder(
    column: $table.captureStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentPath => $composableBuilder(
    column: $table.contentPath,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get detectedImageCount => $composableBuilder(
    column: $table.detectedImageCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get storedImageCount => $composableBuilder(
    column: $table.storedImageCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nextSourceUrl => $composableBuilder(
    column: $table.nextSourceUrl,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<String> get captureError => $composableBuilder(
    column: $table.captureError,
    builder: (column) => column,
  );

  GeneratedColumn<int> get byteSize =>
      $composableBuilder(column: $table.byteSize, builder: (column) => column);

  GeneratedColumn<double> get chapterNumber => $composableBuilder(
    column: $table.chapterNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chapterLabel => $composableBuilder(
    column: $table.chapterLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get readStatus => $composableBuilder(
    column: $table.readStatus,
    builder: (column) => column,
  );

  GeneratedColumn<double> get progressFraction => $composableBuilder(
    column: $table.progressFraction,
    builder: (column) => column,
  );

  GeneratedColumn<int> get progressImageIndex => $composableBuilder(
    column: $table.progressImageIndex,
    builder: (column) => column,
  );

  GeneratedColumn<double> get progressOffsetInImage => $composableBuilder(
    column: $table.progressOffsetInImage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get firstOpenedAt => $composableBuilder(
    column: $table.firstOpenedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get progressUpdatedAt => $composableBuilder(
    column: $table.progressUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get discoveredAt => $composableBuilder(
    column: $table.discoveredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get discoveryBasis => $composableBuilder(
    column: $table.discoveryBasis,
    builder: (column) => column,
  );

  GeneratedColumn<String> get discoveryConfidence => $composableBuilder(
    column: $table.discoveryConfidence,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get offlineRemovedAt => $composableBuilder(
    column: $table.offlineRemovedAt,
    builder: (column) => column,
  );

  $$LibraryItemsTableAnnotationComposer get libraryItemId {
    final $$LibraryItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.libraryItemId,
      referencedTable: $db.libraryItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChaptersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChaptersTable,
          Chapter,
          $$ChaptersTableFilterComposer,
          $$ChaptersTableOrderingComposer,
          $$ChaptersTableAnnotationComposer,
          $$ChaptersTableCreateCompanionBuilder,
          $$ChaptersTableUpdateCompanionBuilder,
          (Chapter, $$ChaptersTableReferences),
          Chapter,
          PrefetchHooks Function({bool libraryItemId})
        > {
  $$ChaptersTableTableManager(_$AppDatabase db, $ChaptersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChaptersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChaptersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChaptersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> libraryItemId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> sourceUrl = const Value.absent(),
                Value<String> urlKey = const Value.absent(),
                Value<String> captureStatus = const Value.absent(),
                Value<String?> contentPath = const Value.absent(),
                Value<DateTime?> capturedAt = const Value.absent(),
                Value<int> detectedImageCount = const Value.absent(),
                Value<int> storedImageCount = const Value.absent(),
                Value<String?> nextSourceUrl = const Value.absent(),
                Value<int> sequence = const Value.absent(),
                Value<String?> captureError = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<double?> chapterNumber = const Value.absent(),
                Value<String?> chapterLabel = const Value.absent(),
                Value<String> readStatus = const Value.absent(),
                Value<double> progressFraction = const Value.absent(),
                Value<int> progressImageIndex = const Value.absent(),
                Value<double> progressOffsetInImage = const Value.absent(),
                Value<DateTime?> firstOpenedAt = const Value.absent(),
                Value<DateTime?> lastReadAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<DateTime?> progressUpdatedAt = const Value.absent(),
                Value<DateTime?> discoveredAt = const Value.absent(),
                Value<String?> discoveryBasis = const Value.absent(),
                Value<String?> discoveryConfidence = const Value.absent(),
                Value<DateTime?> offlineRemovedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChaptersCompanion(
                id: id,
                libraryItemId: libraryItemId,
                title: title,
                sourceUrl: sourceUrl,
                urlKey: urlKey,
                captureStatus: captureStatus,
                contentPath: contentPath,
                capturedAt: capturedAt,
                detectedImageCount: detectedImageCount,
                storedImageCount: storedImageCount,
                nextSourceUrl: nextSourceUrl,
                sequence: sequence,
                captureError: captureError,
                byteSize: byteSize,
                chapterNumber: chapterNumber,
                chapterLabel: chapterLabel,
                readStatus: readStatus,
                progressFraction: progressFraction,
                progressImageIndex: progressImageIndex,
                progressOffsetInImage: progressOffsetInImage,
                firstOpenedAt: firstOpenedAt,
                lastReadAt: lastReadAt,
                completedAt: completedAt,
                progressUpdatedAt: progressUpdatedAt,
                discoveredAt: discoveredAt,
                discoveryBasis: discoveryBasis,
                discoveryConfidence: discoveryConfidence,
                offlineRemovedAt: offlineRemovedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String libraryItemId,
                required String title,
                required String sourceUrl,
                required String urlKey,
                required String captureStatus,
                Value<String?> contentPath = const Value.absent(),
                Value<DateTime?> capturedAt = const Value.absent(),
                Value<int> detectedImageCount = const Value.absent(),
                Value<int> storedImageCount = const Value.absent(),
                Value<String?> nextSourceUrl = const Value.absent(),
                Value<int> sequence = const Value.absent(),
                Value<String?> captureError = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<double?> chapterNumber = const Value.absent(),
                Value<String?> chapterLabel = const Value.absent(),
                Value<String> readStatus = const Value.absent(),
                Value<double> progressFraction = const Value.absent(),
                Value<int> progressImageIndex = const Value.absent(),
                Value<double> progressOffsetInImage = const Value.absent(),
                Value<DateTime?> firstOpenedAt = const Value.absent(),
                Value<DateTime?> lastReadAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<DateTime?> progressUpdatedAt = const Value.absent(),
                Value<DateTime?> discoveredAt = const Value.absent(),
                Value<String?> discoveryBasis = const Value.absent(),
                Value<String?> discoveryConfidence = const Value.absent(),
                Value<DateTime?> offlineRemovedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChaptersCompanion.insert(
                id: id,
                libraryItemId: libraryItemId,
                title: title,
                sourceUrl: sourceUrl,
                urlKey: urlKey,
                captureStatus: captureStatus,
                contentPath: contentPath,
                capturedAt: capturedAt,
                detectedImageCount: detectedImageCount,
                storedImageCount: storedImageCount,
                nextSourceUrl: nextSourceUrl,
                sequence: sequence,
                captureError: captureError,
                byteSize: byteSize,
                chapterNumber: chapterNumber,
                chapterLabel: chapterLabel,
                readStatus: readStatus,
                progressFraction: progressFraction,
                progressImageIndex: progressImageIndex,
                progressOffsetInImage: progressOffsetInImage,
                firstOpenedAt: firstOpenedAt,
                lastReadAt: lastReadAt,
                completedAt: completedAt,
                progressUpdatedAt: progressUpdatedAt,
                discoveredAt: discoveredAt,
                discoveryBasis: discoveryBasis,
                discoveryConfidence: discoveryConfidence,
                offlineRemovedAt: offlineRemovedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ChaptersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({libraryItemId = false}) {
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
                    if (libraryItemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.libraryItemId,
                                referencedTable: $$ChaptersTableReferences
                                    ._libraryItemIdTable(db),
                                referencedColumn: $$ChaptersTableReferences
                                    ._libraryItemIdTable(db)
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

typedef $$ChaptersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChaptersTable,
      Chapter,
      $$ChaptersTableFilterComposer,
      $$ChaptersTableOrderingComposer,
      $$ChaptersTableAnnotationComposer,
      $$ChaptersTableCreateCompanionBuilder,
      $$ChaptersTableUpdateCompanionBuilder,
      (Chapter, $$ChaptersTableReferences),
      Chapter,
      PrefetchHooks Function({bool libraryItemId})
    >;
typedef $$CaptureJobsTableCreateCompanionBuilder =
    CaptureJobsCompanion Function({
      required String id,
      Value<String?> libraryItemId,
      required String startUrl,
      Value<String?> currentUrl,
      required int requestedChapters,
      Value<int> completedChapters,
      required String state,
      Value<String?> lastError,
      Value<String> visitedUrls,
      Value<String?> duplicatePolicy,
      Value<String?> sessionDuplicateDecision,
      Value<String?> sessionPartialDecision,
      Value<String> rangeMode,
      Value<String?> pauseReason,
      Value<String?> origin,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CaptureJobsTableUpdateCompanionBuilder =
    CaptureJobsCompanion Function({
      Value<String> id,
      Value<String?> libraryItemId,
      Value<String> startUrl,
      Value<String?> currentUrl,
      Value<int> requestedChapters,
      Value<int> completedChapters,
      Value<String> state,
      Value<String?> lastError,
      Value<String> visitedUrls,
      Value<String?> duplicatePolicy,
      Value<String?> sessionDuplicateDecision,
      Value<String?> sessionPartialDecision,
      Value<String> rangeMode,
      Value<String?> pauseReason,
      Value<String?> origin,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CaptureJobsTableFilterComposer
    extends Composer<_$AppDatabase, $CaptureJobsTable> {
  $$CaptureJobsTableFilterComposer({
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

  ColumnFilters<String> get libraryItemId => $composableBuilder(
    column: $table.libraryItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startUrl => $composableBuilder(
    column: $table.startUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentUrl => $composableBuilder(
    column: $table.currentUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get requestedChapters => $composableBuilder(
    column: $table.requestedChapters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedChapters => $composableBuilder(
    column: $table.completedChapters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get visitedUrls => $composableBuilder(
    column: $table.visitedUrls,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get duplicatePolicy => $composableBuilder(
    column: $table.duplicatePolicy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionDuplicateDecision => $composableBuilder(
    column: $table.sessionDuplicateDecision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionPartialDecision => $composableBuilder(
    column: $table.sessionPartialDecision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rangeMode => $composableBuilder(
    column: $table.rangeMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pauseReason => $composableBuilder(
    column: $table.pauseReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
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

class $$CaptureJobsTableOrderingComposer
    extends Composer<_$AppDatabase, $CaptureJobsTable> {
  $$CaptureJobsTableOrderingComposer({
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

  ColumnOrderings<String> get libraryItemId => $composableBuilder(
    column: $table.libraryItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startUrl => $composableBuilder(
    column: $table.startUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentUrl => $composableBuilder(
    column: $table.currentUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get requestedChapters => $composableBuilder(
    column: $table.requestedChapters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedChapters => $composableBuilder(
    column: $table.completedChapters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get visitedUrls => $composableBuilder(
    column: $table.visitedUrls,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get duplicatePolicy => $composableBuilder(
    column: $table.duplicatePolicy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionDuplicateDecision => $composableBuilder(
    column: $table.sessionDuplicateDecision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionPartialDecision => $composableBuilder(
    column: $table.sessionPartialDecision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rangeMode => $composableBuilder(
    column: $table.rangeMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pauseReason => $composableBuilder(
    column: $table.pauseReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
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

class $$CaptureJobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CaptureJobsTable> {
  $$CaptureJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get libraryItemId => $composableBuilder(
    column: $table.libraryItemId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startUrl =>
      $composableBuilder(column: $table.startUrl, builder: (column) => column);

  GeneratedColumn<String> get currentUrl => $composableBuilder(
    column: $table.currentUrl,
    builder: (column) => column,
  );

  GeneratedColumn<int> get requestedChapters => $composableBuilder(
    column: $table.requestedChapters,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedChapters => $composableBuilder(
    column: $table.completedChapters,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<String> get visitedUrls => $composableBuilder(
    column: $table.visitedUrls,
    builder: (column) => column,
  );

  GeneratedColumn<String> get duplicatePolicy => $composableBuilder(
    column: $table.duplicatePolicy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sessionDuplicateDecision => $composableBuilder(
    column: $table.sessionDuplicateDecision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sessionPartialDecision => $composableBuilder(
    column: $table.sessionPartialDecision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rangeMode =>
      $composableBuilder(column: $table.rangeMode, builder: (column) => column);

  GeneratedColumn<String> get pauseReason => $composableBuilder(
    column: $table.pauseReason,
    builder: (column) => column,
  );

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CaptureJobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CaptureJobsTable,
          CaptureJob,
          $$CaptureJobsTableFilterComposer,
          $$CaptureJobsTableOrderingComposer,
          $$CaptureJobsTableAnnotationComposer,
          $$CaptureJobsTableCreateCompanionBuilder,
          $$CaptureJobsTableUpdateCompanionBuilder,
          (
            CaptureJob,
            BaseReferences<_$AppDatabase, $CaptureJobsTable, CaptureJob>,
          ),
          CaptureJob,
          PrefetchHooks Function()
        > {
  $$CaptureJobsTableTableManager(_$AppDatabase db, $CaptureJobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CaptureJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CaptureJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CaptureJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> libraryItemId = const Value.absent(),
                Value<String> startUrl = const Value.absent(),
                Value<String?> currentUrl = const Value.absent(),
                Value<int> requestedChapters = const Value.absent(),
                Value<int> completedChapters = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String> visitedUrls = const Value.absent(),
                Value<String?> duplicatePolicy = const Value.absent(),
                Value<String?> sessionDuplicateDecision = const Value.absent(),
                Value<String?> sessionPartialDecision = const Value.absent(),
                Value<String> rangeMode = const Value.absent(),
                Value<String?> pauseReason = const Value.absent(),
                Value<String?> origin = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CaptureJobsCompanion(
                id: id,
                libraryItemId: libraryItemId,
                startUrl: startUrl,
                currentUrl: currentUrl,
                requestedChapters: requestedChapters,
                completedChapters: completedChapters,
                state: state,
                lastError: lastError,
                visitedUrls: visitedUrls,
                duplicatePolicy: duplicatePolicy,
                sessionDuplicateDecision: sessionDuplicateDecision,
                sessionPartialDecision: sessionPartialDecision,
                rangeMode: rangeMode,
                pauseReason: pauseReason,
                origin: origin,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> libraryItemId = const Value.absent(),
                required String startUrl,
                Value<String?> currentUrl = const Value.absent(),
                required int requestedChapters,
                Value<int> completedChapters = const Value.absent(),
                required String state,
                Value<String?> lastError = const Value.absent(),
                Value<String> visitedUrls = const Value.absent(),
                Value<String?> duplicatePolicy = const Value.absent(),
                Value<String?> sessionDuplicateDecision = const Value.absent(),
                Value<String?> sessionPartialDecision = const Value.absent(),
                Value<String> rangeMode = const Value.absent(),
                Value<String?> pauseReason = const Value.absent(),
                Value<String?> origin = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CaptureJobsCompanion.insert(
                id: id,
                libraryItemId: libraryItemId,
                startUrl: startUrl,
                currentUrl: currentUrl,
                requestedChapters: requestedChapters,
                completedChapters: completedChapters,
                state: state,
                lastError: lastError,
                visitedUrls: visitedUrls,
                duplicatePolicy: duplicatePolicy,
                sessionDuplicateDecision: sessionDuplicateDecision,
                sessionPartialDecision: sessionPartialDecision,
                rangeMode: rangeMode,
                pauseReason: pauseReason,
                origin: origin,
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

typedef $$CaptureJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CaptureJobsTable,
      CaptureJob,
      $$CaptureJobsTableFilterComposer,
      $$CaptureJobsTableOrderingComposer,
      $$CaptureJobsTableAnnotationComposer,
      $$CaptureJobsTableCreateCompanionBuilder,
      $$CaptureJobsTableUpdateCompanionBuilder,
      (
        CaptureJob,
        BaseReferences<_$AppDatabase, $CaptureJobsTable, CaptureJob>,
      ),
      CaptureJob,
      PrefetchHooks Function()
    >;
typedef $$SiteRuleRowsTableCreateCompanionBuilder =
    SiteRuleRowsCompanion Function({
      required String id,
      required String host,
      Value<String?> seriesPath,
      required String scope,
      required String kind,
      required String locatorJson,
      Value<String?> exampleSourceUrl,
      Value<String?> exampleTargetUrl,
      Value<bool> sameHostOnly,
      required DateTime createdAt,
      Value<DateTime?> lastUsedAt,
      Value<int> successCount,
      Value<int> failureCount,
      Value<int> rowid,
    });
typedef $$SiteRuleRowsTableUpdateCompanionBuilder =
    SiteRuleRowsCompanion Function({
      Value<String> id,
      Value<String> host,
      Value<String?> seriesPath,
      Value<String> scope,
      Value<String> kind,
      Value<String> locatorJson,
      Value<String?> exampleSourceUrl,
      Value<String?> exampleTargetUrl,
      Value<bool> sameHostOnly,
      Value<DateTime> createdAt,
      Value<DateTime?> lastUsedAt,
      Value<int> successCount,
      Value<int> failureCount,
      Value<int> rowid,
    });

class $$SiteRuleRowsTableFilterComposer
    extends Composer<_$AppDatabase, $SiteRuleRowsTable> {
  $$SiteRuleRowsTableFilterComposer({
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

  ColumnFilters<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seriesPath => $composableBuilder(
    column: $table.seriesPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locatorJson => $composableBuilder(
    column: $table.locatorJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exampleSourceUrl => $composableBuilder(
    column: $table.exampleSourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exampleTargetUrl => $composableBuilder(
    column: $table.exampleTargetUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get sameHostOnly => $composableBuilder(
    column: $table.sameHostOnly,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get successCount => $composableBuilder(
    column: $table.successCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get failureCount => $composableBuilder(
    column: $table.failureCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SiteRuleRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $SiteRuleRowsTable> {
  $$SiteRuleRowsTableOrderingComposer({
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

  ColumnOrderings<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seriesPath => $composableBuilder(
    column: $table.seriesPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locatorJson => $composableBuilder(
    column: $table.locatorJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exampleSourceUrl => $composableBuilder(
    column: $table.exampleSourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exampleTargetUrl => $composableBuilder(
    column: $table.exampleTargetUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get sameHostOnly => $composableBuilder(
    column: $table.sameHostOnly,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get successCount => $composableBuilder(
    column: $table.successCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get failureCount => $composableBuilder(
    column: $table.failureCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SiteRuleRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SiteRuleRowsTable> {
  $$SiteRuleRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get host =>
      $composableBuilder(column: $table.host, builder: (column) => column);

  GeneratedColumn<String> get seriesPath => $composableBuilder(
    column: $table.seriesPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get locatorJson => $composableBuilder(
    column: $table.locatorJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get exampleSourceUrl => $composableBuilder(
    column: $table.exampleSourceUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get exampleTargetUrl => $composableBuilder(
    column: $table.exampleTargetUrl,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get sameHostOnly => $composableBuilder(
    column: $table.sameHostOnly,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get successCount => $composableBuilder(
    column: $table.successCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get failureCount => $composableBuilder(
    column: $table.failureCount,
    builder: (column) => column,
  );
}

class $$SiteRuleRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SiteRuleRowsTable,
          SiteRuleRow,
          $$SiteRuleRowsTableFilterComposer,
          $$SiteRuleRowsTableOrderingComposer,
          $$SiteRuleRowsTableAnnotationComposer,
          $$SiteRuleRowsTableCreateCompanionBuilder,
          $$SiteRuleRowsTableUpdateCompanionBuilder,
          (
            SiteRuleRow,
            BaseReferences<_$AppDatabase, $SiteRuleRowsTable, SiteRuleRow>,
          ),
          SiteRuleRow,
          PrefetchHooks Function()
        > {
  $$SiteRuleRowsTableTableManager(_$AppDatabase db, $SiteRuleRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SiteRuleRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SiteRuleRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SiteRuleRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> host = const Value.absent(),
                Value<String?> seriesPath = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> locatorJson = const Value.absent(),
                Value<String?> exampleSourceUrl = const Value.absent(),
                Value<String?> exampleTargetUrl = const Value.absent(),
                Value<bool> sameHostOnly = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastUsedAt = const Value.absent(),
                Value<int> successCount = const Value.absent(),
                Value<int> failureCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SiteRuleRowsCompanion(
                id: id,
                host: host,
                seriesPath: seriesPath,
                scope: scope,
                kind: kind,
                locatorJson: locatorJson,
                exampleSourceUrl: exampleSourceUrl,
                exampleTargetUrl: exampleTargetUrl,
                sameHostOnly: sameHostOnly,
                createdAt: createdAt,
                lastUsedAt: lastUsedAt,
                successCount: successCount,
                failureCount: failureCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String host,
                Value<String?> seriesPath = const Value.absent(),
                required String scope,
                required String kind,
                required String locatorJson,
                Value<String?> exampleSourceUrl = const Value.absent(),
                Value<String?> exampleTargetUrl = const Value.absent(),
                Value<bool> sameHostOnly = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> lastUsedAt = const Value.absent(),
                Value<int> successCount = const Value.absent(),
                Value<int> failureCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SiteRuleRowsCompanion.insert(
                id: id,
                host: host,
                seriesPath: seriesPath,
                scope: scope,
                kind: kind,
                locatorJson: locatorJson,
                exampleSourceUrl: exampleSourceUrl,
                exampleTargetUrl: exampleTargetUrl,
                sameHostOnly: sameHostOnly,
                createdAt: createdAt,
                lastUsedAt: lastUsedAt,
                successCount: successCount,
                failureCount: failureCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SiteRuleRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SiteRuleRowsTable,
      SiteRuleRow,
      $$SiteRuleRowsTableFilterComposer,
      $$SiteRuleRowsTableOrderingComposer,
      $$SiteRuleRowsTableAnnotationComposer,
      $$SiteRuleRowsTableCreateCompanionBuilder,
      $$SiteRuleRowsTableUpdateCompanionBuilder,
      (
        SiteRuleRow,
        BaseReferences<_$AppDatabase, $SiteRuleRowsTable, SiteRuleRow>,
      ),
      SiteRuleRow,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
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

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
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

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$QueueTasksTableCreateCompanionBuilder =
    QueueTasksCompanion Function({
      required String id,
      required String taskType,
      Value<String?> libraryItemId,
      Value<String?> startUrl,
      Value<int?> chapterLimit,
      Value<String?> duplicatePolicy,
      Value<String?> rangeMode,
      Value<String> state,
      Value<String?> origin,
      Value<String?> outcome,
      Value<String?> lastError,
      Value<int> orderIndex,
      required DateTime queuedAt,
      Value<DateTime?> startedAt,
      Value<DateTime?> finishedAt,
      Value<int> rowid,
    });
typedef $$QueueTasksTableUpdateCompanionBuilder =
    QueueTasksCompanion Function({
      Value<String> id,
      Value<String> taskType,
      Value<String?> libraryItemId,
      Value<String?> startUrl,
      Value<int?> chapterLimit,
      Value<String?> duplicatePolicy,
      Value<String?> rangeMode,
      Value<String> state,
      Value<String?> origin,
      Value<String?> outcome,
      Value<String?> lastError,
      Value<int> orderIndex,
      Value<DateTime> queuedAt,
      Value<DateTime?> startedAt,
      Value<DateTime?> finishedAt,
      Value<int> rowid,
    });

class $$QueueTasksTableFilterComposer
    extends Composer<_$AppDatabase, $QueueTasksTable> {
  $$QueueTasksTableFilterComposer({
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

  ColumnFilters<String> get taskType => $composableBuilder(
    column: $table.taskType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get libraryItemId => $composableBuilder(
    column: $table.libraryItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startUrl => $composableBuilder(
    column: $table.startUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterLimit => $composableBuilder(
    column: $table.chapterLimit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get duplicatePolicy => $composableBuilder(
    column: $table.duplicatePolicy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rangeMode => $composableBuilder(
    column: $table.rangeMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get queuedAt => $composableBuilder(
    column: $table.queuedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QueueTasksTableOrderingComposer
    extends Composer<_$AppDatabase, $QueueTasksTable> {
  $$QueueTasksTableOrderingComposer({
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

  ColumnOrderings<String> get taskType => $composableBuilder(
    column: $table.taskType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get libraryItemId => $composableBuilder(
    column: $table.libraryItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startUrl => $composableBuilder(
    column: $table.startUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterLimit => $composableBuilder(
    column: $table.chapterLimit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get duplicatePolicy => $composableBuilder(
    column: $table.duplicatePolicy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rangeMode => $composableBuilder(
    column: $table.rangeMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get queuedAt => $composableBuilder(
    column: $table.queuedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QueueTasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $QueueTasksTable> {
  $$QueueTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get taskType =>
      $composableBuilder(column: $table.taskType, builder: (column) => column);

  GeneratedColumn<String> get libraryItemId => $composableBuilder(
    column: $table.libraryItemId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startUrl =>
      $composableBuilder(column: $table.startUrl, builder: (column) => column);

  GeneratedColumn<int> get chapterLimit => $composableBuilder(
    column: $table.chapterLimit,
    builder: (column) => column,
  );

  GeneratedColumn<String> get duplicatePolicy => $composableBuilder(
    column: $table.duplicatePolicy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rangeMode =>
      $composableBuilder(column: $table.rangeMode, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get queuedAt =>
      $composableBuilder(column: $table.queuedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );
}

class $$QueueTasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QueueTasksTable,
          QueueTask,
          $$QueueTasksTableFilterComposer,
          $$QueueTasksTableOrderingComposer,
          $$QueueTasksTableAnnotationComposer,
          $$QueueTasksTableCreateCompanionBuilder,
          $$QueueTasksTableUpdateCompanionBuilder,
          (
            QueueTask,
            BaseReferences<_$AppDatabase, $QueueTasksTable, QueueTask>,
          ),
          QueueTask,
          PrefetchHooks Function()
        > {
  $$QueueTasksTableTableManager(_$AppDatabase db, $QueueTasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QueueTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QueueTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QueueTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> taskType = const Value.absent(),
                Value<String?> libraryItemId = const Value.absent(),
                Value<String?> startUrl = const Value.absent(),
                Value<int?> chapterLimit = const Value.absent(),
                Value<String?> duplicatePolicy = const Value.absent(),
                Value<String?> rangeMode = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> origin = const Value.absent(),
                Value<String?> outcome = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<DateTime> queuedAt = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QueueTasksCompanion(
                id: id,
                taskType: taskType,
                libraryItemId: libraryItemId,
                startUrl: startUrl,
                chapterLimit: chapterLimit,
                duplicatePolicy: duplicatePolicy,
                rangeMode: rangeMode,
                state: state,
                origin: origin,
                outcome: outcome,
                lastError: lastError,
                orderIndex: orderIndex,
                queuedAt: queuedAt,
                startedAt: startedAt,
                finishedAt: finishedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String taskType,
                Value<String?> libraryItemId = const Value.absent(),
                Value<String?> startUrl = const Value.absent(),
                Value<int?> chapterLimit = const Value.absent(),
                Value<String?> duplicatePolicy = const Value.absent(),
                Value<String?> rangeMode = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> origin = const Value.absent(),
                Value<String?> outcome = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                required DateTime queuedAt,
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QueueTasksCompanion.insert(
                id: id,
                taskType: taskType,
                libraryItemId: libraryItemId,
                startUrl: startUrl,
                chapterLimit: chapterLimit,
                duplicatePolicy: duplicatePolicy,
                rangeMode: rangeMode,
                state: state,
                origin: origin,
                outcome: outcome,
                lastError: lastError,
                orderIndex: orderIndex,
                queuedAt: queuedAt,
                startedAt: startedAt,
                finishedAt: finishedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QueueTasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QueueTasksTable,
      QueueTask,
      $$QueueTasksTableFilterComposer,
      $$QueueTasksTableOrderingComposer,
      $$QueueTasksTableAnnotationComposer,
      $$QueueTasksTableCreateCompanionBuilder,
      $$QueueTasksTableUpdateCompanionBuilder,
      (QueueTask, BaseReferences<_$AppDatabase, $QueueTasksTable, QueueTask>),
      QueueTask,
      PrefetchHooks Function()
    >;
typedef $$BrowsingHistoryTableCreateCompanionBuilder =
    BrowsingHistoryCompanion Function({
      required String id,
      required String url,
      required String urlKey,
      required String host,
      required String title,
      Value<String> source,
      Value<String?> finalUrl,
      Value<bool> completed,
      required DateTime visitedAt,
      Value<int> rowid,
    });
typedef $$BrowsingHistoryTableUpdateCompanionBuilder =
    BrowsingHistoryCompanion Function({
      Value<String> id,
      Value<String> url,
      Value<String> urlKey,
      Value<String> host,
      Value<String> title,
      Value<String> source,
      Value<String?> finalUrl,
      Value<bool> completed,
      Value<DateTime> visitedAt,
      Value<int> rowid,
    });

class $$BrowsingHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $BrowsingHistoryTable> {
  $$BrowsingHistoryTableFilterComposer({
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

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get urlKey => $composableBuilder(
    column: $table.urlKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get finalUrl => $composableBuilder(
    column: $table.finalUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get visitedAt => $composableBuilder(
    column: $table.visitedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BrowsingHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $BrowsingHistoryTable> {
  $$BrowsingHistoryTableOrderingComposer({
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

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get urlKey => $composableBuilder(
    column: $table.urlKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get finalUrl => $composableBuilder(
    column: $table.finalUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get visitedAt => $composableBuilder(
    column: $table.visitedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BrowsingHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $BrowsingHistoryTable> {
  $$BrowsingHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get urlKey =>
      $composableBuilder(column: $table.urlKey, builder: (column) => column);

  GeneratedColumn<String> get host =>
      $composableBuilder(column: $table.host, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get finalUrl =>
      $composableBuilder(column: $table.finalUrl, builder: (column) => column);

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<DateTime> get visitedAt =>
      $composableBuilder(column: $table.visitedAt, builder: (column) => column);
}

class $$BrowsingHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BrowsingHistoryTable,
          BrowsingHistoryData,
          $$BrowsingHistoryTableFilterComposer,
          $$BrowsingHistoryTableOrderingComposer,
          $$BrowsingHistoryTableAnnotationComposer,
          $$BrowsingHistoryTableCreateCompanionBuilder,
          $$BrowsingHistoryTableUpdateCompanionBuilder,
          (
            BrowsingHistoryData,
            BaseReferences<
              _$AppDatabase,
              $BrowsingHistoryTable,
              BrowsingHistoryData
            >,
          ),
          BrowsingHistoryData,
          PrefetchHooks Function()
        > {
  $$BrowsingHistoryTableTableManager(
    _$AppDatabase db,
    $BrowsingHistoryTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BrowsingHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BrowsingHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BrowsingHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> urlKey = const Value.absent(),
                Value<String> host = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> finalUrl = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<DateTime> visitedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BrowsingHistoryCompanion(
                id: id,
                url: url,
                urlKey: urlKey,
                host: host,
                title: title,
                source: source,
                finalUrl: finalUrl,
                completed: completed,
                visitedAt: visitedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String url,
                required String urlKey,
                required String host,
                required String title,
                Value<String> source = const Value.absent(),
                Value<String?> finalUrl = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                required DateTime visitedAt,
                Value<int> rowid = const Value.absent(),
              }) => BrowsingHistoryCompanion.insert(
                id: id,
                url: url,
                urlKey: urlKey,
                host: host,
                title: title,
                source: source,
                finalUrl: finalUrl,
                completed: completed,
                visitedAt: visitedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BrowsingHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BrowsingHistoryTable,
      BrowsingHistoryData,
      $$BrowsingHistoryTableFilterComposer,
      $$BrowsingHistoryTableOrderingComposer,
      $$BrowsingHistoryTableAnnotationComposer,
      $$BrowsingHistoryTableCreateCompanionBuilder,
      $$BrowsingHistoryTableUpdateCompanionBuilder,
      (
        BrowsingHistoryData,
        BaseReferences<
          _$AppDatabase,
          $BrowsingHistoryTable,
          BrowsingHistoryData
        >,
      ),
      BrowsingHistoryData,
      PrefetchHooks Function()
    >;
typedef $$SavedSitesTableCreateCompanionBuilder =
    SavedSitesCompanion Function({
      required String id,
      required String url,
      required String urlKey,
      required String host,
      required String title,
      Value<String?> userTitle,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> lastOpenedAt,
      Value<int> orderIndex,
      Value<bool> isDefault,
      Value<int> rowid,
    });
typedef $$SavedSitesTableUpdateCompanionBuilder =
    SavedSitesCompanion Function({
      Value<String> id,
      Value<String> url,
      Value<String> urlKey,
      Value<String> host,
      Value<String> title,
      Value<String?> userTitle,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> lastOpenedAt,
      Value<int> orderIndex,
      Value<bool> isDefault,
      Value<int> rowid,
    });

class $$SavedSitesTableFilterComposer
    extends Composer<_$AppDatabase, $SavedSitesTable> {
  $$SavedSitesTableFilterComposer({
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

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get urlKey => $composableBuilder(
    column: $table.urlKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userTitle => $composableBuilder(
    column: $table.userTitle,
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

  ColumnFilters<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SavedSitesTableOrderingComposer
    extends Composer<_$AppDatabase, $SavedSitesTable> {
  $$SavedSitesTableOrderingComposer({
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

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get urlKey => $composableBuilder(
    column: $table.urlKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userTitle => $composableBuilder(
    column: $table.userTitle,
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

  ColumnOrderings<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavedSitesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SavedSitesTable> {
  $$SavedSitesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get urlKey =>
      $composableBuilder(column: $table.urlKey, builder: (column) => column);

  GeneratedColumn<String> get host =>
      $composableBuilder(column: $table.host, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get userTitle =>
      $composableBuilder(column: $table.userTitle, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);
}

class $$SavedSitesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SavedSitesTable,
          SavedSite,
          $$SavedSitesTableFilterComposer,
          $$SavedSitesTableOrderingComposer,
          $$SavedSitesTableAnnotationComposer,
          $$SavedSitesTableCreateCompanionBuilder,
          $$SavedSitesTableUpdateCompanionBuilder,
          (
            SavedSite,
            BaseReferences<_$AppDatabase, $SavedSitesTable, SavedSite>,
          ),
          SavedSite,
          PrefetchHooks Function()
        > {
  $$SavedSitesTableTableManager(_$AppDatabase db, $SavedSitesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedSitesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedSitesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedSitesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> urlKey = const Value.absent(),
                Value<String> host = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> userTitle = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> lastOpenedAt = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedSitesCompanion(
                id: id,
                url: url,
                urlKey: urlKey,
                host: host,
                title: title,
                userTitle: userTitle,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastOpenedAt: lastOpenedAt,
                orderIndex: orderIndex,
                isDefault: isDefault,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String url,
                required String urlKey,
                required String host,
                required String title,
                Value<String?> userTitle = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> lastOpenedAt = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedSitesCompanion.insert(
                id: id,
                url: url,
                urlKey: urlKey,
                host: host,
                title: title,
                userTitle: userTitle,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastOpenedAt: lastOpenedAt,
                orderIndex: orderIndex,
                isDefault: isDefault,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SavedSitesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SavedSitesTable,
      SavedSite,
      $$SavedSitesTableFilterComposer,
      $$SavedSitesTableOrderingComposer,
      $$SavedSitesTableAnnotationComposer,
      $$SavedSitesTableCreateCompanionBuilder,
      $$SavedSitesTableUpdateCompanionBuilder,
      (SavedSite, BaseReferences<_$AppDatabase, $SavedSitesTable, SavedSite>),
      SavedSite,
      PrefetchHooks Function()
    >;
typedef $$FaviconCacheTableCreateCompanionBuilder =
    FaviconCacheCompanion Function({
      required String host,
      Value<Uint8List?> bytes,
      Value<String?> sourceUrl,
      required DateTime fetchedAt,
      Value<int> rowid,
    });
typedef $$FaviconCacheTableUpdateCompanionBuilder =
    FaviconCacheCompanion Function({
      Value<String> host,
      Value<Uint8List?> bytes,
      Value<String?> sourceUrl,
      Value<DateTime> fetchedAt,
      Value<int> rowid,
    });

class $$FaviconCacheTableFilterComposer
    extends Composer<_$AppDatabase, $FaviconCacheTable> {
  $$FaviconCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FaviconCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $FaviconCacheTable> {
  $$FaviconCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FaviconCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $FaviconCacheTable> {
  $$FaviconCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get host =>
      $composableBuilder(column: $table.host, builder: (column) => column);

  GeneratedColumn<Uint8List> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$FaviconCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FaviconCacheTable,
          FaviconCacheData,
          $$FaviconCacheTableFilterComposer,
          $$FaviconCacheTableOrderingComposer,
          $$FaviconCacheTableAnnotationComposer,
          $$FaviconCacheTableCreateCompanionBuilder,
          $$FaviconCacheTableUpdateCompanionBuilder,
          (
            FaviconCacheData,
            BaseReferences<_$AppDatabase, $FaviconCacheTable, FaviconCacheData>,
          ),
          FaviconCacheData,
          PrefetchHooks Function()
        > {
  $$FaviconCacheTableTableManager(_$AppDatabase db, $FaviconCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FaviconCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FaviconCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FaviconCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> host = const Value.absent(),
                Value<Uint8List?> bytes = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FaviconCacheCompanion(
                host: host,
                bytes: bytes,
                sourceUrl: sourceUrl,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String host,
                Value<Uint8List?> bytes = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                required DateTime fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => FaviconCacheCompanion.insert(
                host: host,
                bytes: bytes,
                sourceUrl: sourceUrl,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FaviconCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FaviconCacheTable,
      FaviconCacheData,
      $$FaviconCacheTableFilterComposer,
      $$FaviconCacheTableOrderingComposer,
      $$FaviconCacheTableAnnotationComposer,
      $$FaviconCacheTableCreateCompanionBuilder,
      $$FaviconCacheTableUpdateCompanionBuilder,
      (
        FaviconCacheData,
        BaseReferences<_$AppDatabase, $FaviconCacheTable, FaviconCacheData>,
      ),
      FaviconCacheData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LibraryItemsTableTableManager get libraryItems =>
      $$LibraryItemsTableTableManager(_db, _db.libraryItems);
  $$ChaptersTableTableManager get chapters =>
      $$ChaptersTableTableManager(_db, _db.chapters);
  $$CaptureJobsTableTableManager get captureJobs =>
      $$CaptureJobsTableTableManager(_db, _db.captureJobs);
  $$SiteRuleRowsTableTableManager get siteRuleRows =>
      $$SiteRuleRowsTableTableManager(_db, _db.siteRuleRows);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$QueueTasksTableTableManager get queueTasks =>
      $$QueueTasksTableTableManager(_db, _db.queueTasks);
  $$BrowsingHistoryTableTableManager get browsingHistory =>
      $$BrowsingHistoryTableTableManager(_db, _db.browsingHistory);
  $$SavedSitesTableTableManager get savedSites =>
      $$SavedSitesTableTableManager(_db, _db.savedSites);
  $$FaviconCacheTableTableManager get faviconCache =>
      $$FaviconCacheTableTableManager(_db, _db.faviconCache);
}
