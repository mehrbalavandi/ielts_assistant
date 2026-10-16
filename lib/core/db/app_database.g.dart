// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $StudyItemsTable extends StudyItems
    with TableInfo<$StudyItemsTable, StudyItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudyItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _bookTitleMeta = const VerificationMeta(
    'bookTitle',
  );
  @override
  late final GeneratedColumn<String> bookTitle = GeneratedColumn<String>(
    'book_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _pageNumberMeta = const VerificationMeta(
    'pageNumber',
  );
  @override
  late final GeneratedColumn<int> pageNumber = GeneratedColumn<int>(
    'page_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paraIndexMeta = const VerificationMeta(
    'paraIndex',
  );
  @override
  late final GeneratedColumn<int> paraIndex = GeneratedColumn<int>(
    'para_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _itemTextMeta = const VerificationMeta(
    'itemText',
  );
  @override
  late final GeneratedColumn<String> itemText = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _translationFaMeta = const VerificationMeta(
    'translationFa',
  );
  @override
  late final GeneratedColumn<String> translationFa = GeneratedColumn<String>(
    'translation_fa',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _translationArMeta = const VerificationMeta(
    'translationAr',
  );
  @override
  late final GeneratedColumn<String> translationAr = GeneratedColumn<String>(
    'translation_ar',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _pronounceFaMeta = const VerificationMeta(
    'pronounceFa',
  );
  @override
  late final GeneratedColumn<String> pronounceFa = GeneratedColumn<String>(
    'pronounce_fa',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _pronounceArMeta = const VerificationMeta(
    'pronounceAr',
  );
  @override
  late final GeneratedColumn<String> pronounceAr = GeneratedColumn<String>(
    'pronounce_ar',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _explanationFaMeta = const VerificationMeta(
    'explanationFa',
  );
  @override
  late final GeneratedColumn<String> explanationFa = GeneratedColumn<String>(
    'explanation_fa',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _explanationArMeta = const VerificationMeta(
    'explanationAr',
  );
  @override
  late final GeneratedColumn<String> explanationAr = GeneratedColumn<String>(
    'explanation_ar',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _cefrLevelMeta = const VerificationMeta(
    'cefrLevel',
  );
  @override
  late final GeneratedColumn<String> cefrLevel = GeneratedColumn<String>(
    'cefr_level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _importanceMeta = const VerificationMeta(
    'importance',
  );
  @override
  late final GeneratedColumn<int> importance = GeneratedColumn<int>(
    'importance',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(2),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('fresh'),
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
  static const VerificationMeta _extraMeta = const VerificationMeta('extra');
  @override
  late final GeneratedColumn<String> extra = GeneratedColumn<String>(
    'extra',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdMsMeta = const VerificationMeta(
    'createdMs',
  );
  @override
  late final GeneratedColumn<int> createdMs = GeneratedColumn<int>(
    'created_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedMsMeta = const VerificationMeta(
    'updatedMs',
  );
  @override
  late final GeneratedColumn<int> updatedMs = GeneratedColumn<int>(
    'updated_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    bookId,
    bookTitle,
    pageNumber,
    paraIndex,
    itemText,
    translationFa,
    translationAr,
    pronounceFa,
    pronounceAr,
    explanationFa,
    explanationAr,
    cefrLevel,
    importance,
    status,
    note,
    extra,
    createdMs,
    updatedMs,
    deleted,
    dirty,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'study_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<StudyItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    }
    if (data.containsKey('book_title')) {
      context.handle(
        _bookTitleMeta,
        bookTitle.isAcceptableOrUnknown(data['book_title']!, _bookTitleMeta),
      );
    }
    if (data.containsKey('page_number')) {
      context.handle(
        _pageNumberMeta,
        pageNumber.isAcceptableOrUnknown(data['page_number']!, _pageNumberMeta),
      );
    }
    if (data.containsKey('para_index')) {
      context.handle(
        _paraIndexMeta,
        paraIndex.isAcceptableOrUnknown(data['para_index']!, _paraIndexMeta),
      );
    }
    if (data.containsKey('text')) {
      context.handle(
        _itemTextMeta,
        itemText.isAcceptableOrUnknown(data['text']!, _itemTextMeta),
      );
    } else if (isInserting) {
      context.missing(_itemTextMeta);
    }
    if (data.containsKey('translation_fa')) {
      context.handle(
        _translationFaMeta,
        translationFa.isAcceptableOrUnknown(
          data['translation_fa']!,
          _translationFaMeta,
        ),
      );
    }
    if (data.containsKey('translation_ar')) {
      context.handle(
        _translationArMeta,
        translationAr.isAcceptableOrUnknown(
          data['translation_ar']!,
          _translationArMeta,
        ),
      );
    }
    if (data.containsKey('pronounce_fa')) {
      context.handle(
        _pronounceFaMeta,
        pronounceFa.isAcceptableOrUnknown(
          data['pronounce_fa']!,
          _pronounceFaMeta,
        ),
      );
    }
    if (data.containsKey('pronounce_ar')) {
      context.handle(
        _pronounceArMeta,
        pronounceAr.isAcceptableOrUnknown(
          data['pronounce_ar']!,
          _pronounceArMeta,
        ),
      );
    }
    if (data.containsKey('explanation_fa')) {
      context.handle(
        _explanationFaMeta,
        explanationFa.isAcceptableOrUnknown(
          data['explanation_fa']!,
          _explanationFaMeta,
        ),
      );
    }
    if (data.containsKey('explanation_ar')) {
      context.handle(
        _explanationArMeta,
        explanationAr.isAcceptableOrUnknown(
          data['explanation_ar']!,
          _explanationArMeta,
        ),
      );
    }
    if (data.containsKey('cefr_level')) {
      context.handle(
        _cefrLevelMeta,
        cefrLevel.isAcceptableOrUnknown(data['cefr_level']!, _cefrLevelMeta),
      );
    }
    if (data.containsKey('importance')) {
      context.handle(
        _importanceMeta,
        importance.isAcceptableOrUnknown(data['importance']!, _importanceMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('extra')) {
      context.handle(
        _extraMeta,
        extra.isAcceptableOrUnknown(data['extra']!, _extraMeta),
      );
    }
    if (data.containsKey('created_ms')) {
      context.handle(
        _createdMsMeta,
        createdMs.isAcceptableOrUnknown(data['created_ms']!, _createdMsMeta),
      );
    } else if (isInserting) {
      context.missing(_createdMsMeta);
    }
    if (data.containsKey('updated_ms')) {
      context.handle(
        _updatedMsMeta,
        updatedMs.isAcceptableOrUnknown(data['updated_ms']!, _updatedMsMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedMsMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StudyItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StudyItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      bookTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_title'],
      )!,
      pageNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_number'],
      ),
      paraIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}para_index'],
      ),
      itemText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      translationFa: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translation_fa'],
      )!,
      translationAr: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translation_ar'],
      )!,
      pronounceFa: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pronounce_fa'],
      )!,
      pronounceAr: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pronounce_ar'],
      )!,
      explanationFa: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}explanation_fa'],
      )!,
      explanationAr: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}explanation_ar'],
      )!,
      cefrLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cefr_level'],
      )!,
      importance: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}importance'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      extra: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extra'],
      )!,
      createdMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_ms'],
      )!,
      updatedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_ms'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
    );
  }

  @override
  $StudyItemsTable createAlias(String alias) {
    return $StudyItemsTable(attachedDatabase, alias);
  }
}

class StudyItemRow extends DataClass implements Insertable<StudyItemRow> {
  final String id;
  final String kind;
  final String bookId;
  final String bookTitle;
  final int? pageNumber;
  final int? paraIndex;
  final String itemText;
  final String translationFa;
  final String translationAr;
  final String pronounceFa;
  final String pronounceAr;
  final String explanationFa;
  final String explanationAr;
  final String cefrLevel;
  final int importance;
  final String status;
  final String note;
  final String extra;
  final int createdMs;
  final int updatedMs;
  final bool deleted;
  final bool dirty;
  const StudyItemRow({
    required this.id,
    required this.kind,
    required this.bookId,
    required this.bookTitle,
    this.pageNumber,
    this.paraIndex,
    required this.itemText,
    required this.translationFa,
    required this.translationAr,
    required this.pronounceFa,
    required this.pronounceAr,
    required this.explanationFa,
    required this.explanationAr,
    required this.cefrLevel,
    required this.importance,
    required this.status,
    required this.note,
    required this.extra,
    required this.createdMs,
    required this.updatedMs,
    required this.deleted,
    required this.dirty,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['book_id'] = Variable<String>(bookId);
    map['book_title'] = Variable<String>(bookTitle);
    if (!nullToAbsent || pageNumber != null) {
      map['page_number'] = Variable<int>(pageNumber);
    }
    if (!nullToAbsent || paraIndex != null) {
      map['para_index'] = Variable<int>(paraIndex);
    }
    map['text'] = Variable<String>(itemText);
    map['translation_fa'] = Variable<String>(translationFa);
    map['translation_ar'] = Variable<String>(translationAr);
    map['pronounce_fa'] = Variable<String>(pronounceFa);
    map['pronounce_ar'] = Variable<String>(pronounceAr);
    map['explanation_fa'] = Variable<String>(explanationFa);
    map['explanation_ar'] = Variable<String>(explanationAr);
    map['cefr_level'] = Variable<String>(cefrLevel);
    map['importance'] = Variable<int>(importance);
    map['status'] = Variable<String>(status);
    map['note'] = Variable<String>(note);
    map['extra'] = Variable<String>(extra);
    map['created_ms'] = Variable<int>(createdMs);
    map['updated_ms'] = Variable<int>(updatedMs);
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    return map;
  }

  StudyItemsCompanion toCompanion(bool nullToAbsent) {
    return StudyItemsCompanion(
      id: Value(id),
      kind: Value(kind),
      bookId: Value(bookId),
      bookTitle: Value(bookTitle),
      pageNumber: pageNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(pageNumber),
      paraIndex: paraIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(paraIndex),
      itemText: Value(itemText),
      translationFa: Value(translationFa),
      translationAr: Value(translationAr),
      pronounceFa: Value(pronounceFa),
      pronounceAr: Value(pronounceAr),
      explanationFa: Value(explanationFa),
      explanationAr: Value(explanationAr),
      cefrLevel: Value(cefrLevel),
      importance: Value(importance),
      status: Value(status),
      note: Value(note),
      extra: Value(extra),
      createdMs: Value(createdMs),
      updatedMs: Value(updatedMs),
      deleted: Value(deleted),
      dirty: Value(dirty),
    );
  }

  factory StudyItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StudyItemRow(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      bookId: serializer.fromJson<String>(json['bookId']),
      bookTitle: serializer.fromJson<String>(json['bookTitle']),
      pageNumber: serializer.fromJson<int?>(json['pageNumber']),
      paraIndex: serializer.fromJson<int?>(json['paraIndex']),
      itemText: serializer.fromJson<String>(json['itemText']),
      translationFa: serializer.fromJson<String>(json['translationFa']),
      translationAr: serializer.fromJson<String>(json['translationAr']),
      pronounceFa: serializer.fromJson<String>(json['pronounceFa']),
      pronounceAr: serializer.fromJson<String>(json['pronounceAr']),
      explanationFa: serializer.fromJson<String>(json['explanationFa']),
      explanationAr: serializer.fromJson<String>(json['explanationAr']),
      cefrLevel: serializer.fromJson<String>(json['cefrLevel']),
      importance: serializer.fromJson<int>(json['importance']),
      status: serializer.fromJson<String>(json['status']),
      note: serializer.fromJson<String>(json['note']),
      extra: serializer.fromJson<String>(json['extra']),
      createdMs: serializer.fromJson<int>(json['createdMs']),
      updatedMs: serializer.fromJson<int>(json['updatedMs']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'bookId': serializer.toJson<String>(bookId),
      'bookTitle': serializer.toJson<String>(bookTitle),
      'pageNumber': serializer.toJson<int?>(pageNumber),
      'paraIndex': serializer.toJson<int?>(paraIndex),
      'itemText': serializer.toJson<String>(itemText),
      'translationFa': serializer.toJson<String>(translationFa),
      'translationAr': serializer.toJson<String>(translationAr),
      'pronounceFa': serializer.toJson<String>(pronounceFa),
      'pronounceAr': serializer.toJson<String>(pronounceAr),
      'explanationFa': serializer.toJson<String>(explanationFa),
      'explanationAr': serializer.toJson<String>(explanationAr),
      'cefrLevel': serializer.toJson<String>(cefrLevel),
      'importance': serializer.toJson<int>(importance),
      'status': serializer.toJson<String>(status),
      'note': serializer.toJson<String>(note),
      'extra': serializer.toJson<String>(extra),
      'createdMs': serializer.toJson<int>(createdMs),
      'updatedMs': serializer.toJson<int>(updatedMs),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
    };
  }

  StudyItemRow copyWith({
    String? id,
    String? kind,
    String? bookId,
    String? bookTitle,
    Value<int?> pageNumber = const Value.absent(),
    Value<int?> paraIndex = const Value.absent(),
    String? itemText,
    String? translationFa,
    String? translationAr,
    String? pronounceFa,
    String? pronounceAr,
    String? explanationFa,
    String? explanationAr,
    String? cefrLevel,
    int? importance,
    String? status,
    String? note,
    String? extra,
    int? createdMs,
    int? updatedMs,
    bool? deleted,
    bool? dirty,
  }) => StudyItemRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    bookId: bookId ?? this.bookId,
    bookTitle: bookTitle ?? this.bookTitle,
    pageNumber: pageNumber.present ? pageNumber.value : this.pageNumber,
    paraIndex: paraIndex.present ? paraIndex.value : this.paraIndex,
    itemText: itemText ?? this.itemText,
    translationFa: translationFa ?? this.translationFa,
    translationAr: translationAr ?? this.translationAr,
    pronounceFa: pronounceFa ?? this.pronounceFa,
    pronounceAr: pronounceAr ?? this.pronounceAr,
    explanationFa: explanationFa ?? this.explanationFa,
    explanationAr: explanationAr ?? this.explanationAr,
    cefrLevel: cefrLevel ?? this.cefrLevel,
    importance: importance ?? this.importance,
    status: status ?? this.status,
    note: note ?? this.note,
    extra: extra ?? this.extra,
    createdMs: createdMs ?? this.createdMs,
    updatedMs: updatedMs ?? this.updatedMs,
    deleted: deleted ?? this.deleted,
    dirty: dirty ?? this.dirty,
  );
  StudyItemRow copyWithCompanion(StudyItemsCompanion data) {
    return StudyItemRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      bookTitle: data.bookTitle.present ? data.bookTitle.value : this.bookTitle,
      pageNumber: data.pageNumber.present
          ? data.pageNumber.value
          : this.pageNumber,
      paraIndex: data.paraIndex.present ? data.paraIndex.value : this.paraIndex,
      itemText: data.itemText.present ? data.itemText.value : this.itemText,
      translationFa: data.translationFa.present
          ? data.translationFa.value
          : this.translationFa,
      translationAr: data.translationAr.present
          ? data.translationAr.value
          : this.translationAr,
      pronounceFa: data.pronounceFa.present
          ? data.pronounceFa.value
          : this.pronounceFa,
      pronounceAr: data.pronounceAr.present
          ? data.pronounceAr.value
          : this.pronounceAr,
      explanationFa: data.explanationFa.present
          ? data.explanationFa.value
          : this.explanationFa,
      explanationAr: data.explanationAr.present
          ? data.explanationAr.value
          : this.explanationAr,
      cefrLevel: data.cefrLevel.present ? data.cefrLevel.value : this.cefrLevel,
      importance: data.importance.present
          ? data.importance.value
          : this.importance,
      status: data.status.present ? data.status.value : this.status,
      note: data.note.present ? data.note.value : this.note,
      extra: data.extra.present ? data.extra.value : this.extra,
      createdMs: data.createdMs.present ? data.createdMs.value : this.createdMs,
      updatedMs: data.updatedMs.present ? data.updatedMs.value : this.updatedMs,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StudyItemRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('bookId: $bookId, ')
          ..write('bookTitle: $bookTitle, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('paraIndex: $paraIndex, ')
          ..write('itemText: $itemText, ')
          ..write('translationFa: $translationFa, ')
          ..write('translationAr: $translationAr, ')
          ..write('pronounceFa: $pronounceFa, ')
          ..write('pronounceAr: $pronounceAr, ')
          ..write('explanationFa: $explanationFa, ')
          ..write('explanationAr: $explanationAr, ')
          ..write('cefrLevel: $cefrLevel, ')
          ..write('importance: $importance, ')
          ..write('status: $status, ')
          ..write('note: $note, ')
          ..write('extra: $extra, ')
          ..write('createdMs: $createdMs, ')
          ..write('updatedMs: $updatedMs, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    kind,
    bookId,
    bookTitle,
    pageNumber,
    paraIndex,
    itemText,
    translationFa,
    translationAr,
    pronounceFa,
    pronounceAr,
    explanationFa,
    explanationAr,
    cefrLevel,
    importance,
    status,
    note,
    extra,
    createdMs,
    updatedMs,
    deleted,
    dirty,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudyItemRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.bookId == this.bookId &&
          other.bookTitle == this.bookTitle &&
          other.pageNumber == this.pageNumber &&
          other.paraIndex == this.paraIndex &&
          other.itemText == this.itemText &&
          other.translationFa == this.translationFa &&
          other.translationAr == this.translationAr &&
          other.pronounceFa == this.pronounceFa &&
          other.pronounceAr == this.pronounceAr &&
          other.explanationFa == this.explanationFa &&
          other.explanationAr == this.explanationAr &&
          other.cefrLevel == this.cefrLevel &&
          other.importance == this.importance &&
          other.status == this.status &&
          other.note == this.note &&
          other.extra == this.extra &&
          other.createdMs == this.createdMs &&
          other.updatedMs == this.updatedMs &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty);
}

class StudyItemsCompanion extends UpdateCompanion<StudyItemRow> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> bookId;
  final Value<String> bookTitle;
  final Value<int?> pageNumber;
  final Value<int?> paraIndex;
  final Value<String> itemText;
  final Value<String> translationFa;
  final Value<String> translationAr;
  final Value<String> pronounceFa;
  final Value<String> pronounceAr;
  final Value<String> explanationFa;
  final Value<String> explanationAr;
  final Value<String> cefrLevel;
  final Value<int> importance;
  final Value<String> status;
  final Value<String> note;
  final Value<String> extra;
  final Value<int> createdMs;
  final Value<int> updatedMs;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<int> rowid;
  const StudyItemsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.bookId = const Value.absent(),
    this.bookTitle = const Value.absent(),
    this.pageNumber = const Value.absent(),
    this.paraIndex = const Value.absent(),
    this.itemText = const Value.absent(),
    this.translationFa = const Value.absent(),
    this.translationAr = const Value.absent(),
    this.pronounceFa = const Value.absent(),
    this.pronounceAr = const Value.absent(),
    this.explanationFa = const Value.absent(),
    this.explanationAr = const Value.absent(),
    this.cefrLevel = const Value.absent(),
    this.importance = const Value.absent(),
    this.status = const Value.absent(),
    this.note = const Value.absent(),
    this.extra = const Value.absent(),
    this.createdMs = const Value.absent(),
    this.updatedMs = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StudyItemsCompanion.insert({
    required String id,
    required String kind,
    this.bookId = const Value.absent(),
    this.bookTitle = const Value.absent(),
    this.pageNumber = const Value.absent(),
    this.paraIndex = const Value.absent(),
    required String itemText,
    this.translationFa = const Value.absent(),
    this.translationAr = const Value.absent(),
    this.pronounceFa = const Value.absent(),
    this.pronounceAr = const Value.absent(),
    this.explanationFa = const Value.absent(),
    this.explanationAr = const Value.absent(),
    this.cefrLevel = const Value.absent(),
    this.importance = const Value.absent(),
    this.status = const Value.absent(),
    this.note = const Value.absent(),
    this.extra = const Value.absent(),
    required int createdMs,
    required int updatedMs,
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       itemText = Value(itemText),
       createdMs = Value(createdMs),
       updatedMs = Value(updatedMs);
  static Insertable<StudyItemRow> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? bookId,
    Expression<String>? bookTitle,
    Expression<int>? pageNumber,
    Expression<int>? paraIndex,
    Expression<String>? itemText,
    Expression<String>? translationFa,
    Expression<String>? translationAr,
    Expression<String>? pronounceFa,
    Expression<String>? pronounceAr,
    Expression<String>? explanationFa,
    Expression<String>? explanationAr,
    Expression<String>? cefrLevel,
    Expression<int>? importance,
    Expression<String>? status,
    Expression<String>? note,
    Expression<String>? extra,
    Expression<int>? createdMs,
    Expression<int>? updatedMs,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (bookId != null) 'book_id': bookId,
      if (bookTitle != null) 'book_title': bookTitle,
      if (pageNumber != null) 'page_number': pageNumber,
      if (paraIndex != null) 'para_index': paraIndex,
      if (itemText != null) 'text': itemText,
      if (translationFa != null) 'translation_fa': translationFa,
      if (translationAr != null) 'translation_ar': translationAr,
      if (pronounceFa != null) 'pronounce_fa': pronounceFa,
      if (pronounceAr != null) 'pronounce_ar': pronounceAr,
      if (explanationFa != null) 'explanation_fa': explanationFa,
      if (explanationAr != null) 'explanation_ar': explanationAr,
      if (cefrLevel != null) 'cefr_level': cefrLevel,
      if (importance != null) 'importance': importance,
      if (status != null) 'status': status,
      if (note != null) 'note': note,
      if (extra != null) 'extra': extra,
      if (createdMs != null) 'created_ms': createdMs,
      if (updatedMs != null) 'updated_ms': updatedMs,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StudyItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? bookId,
    Value<String>? bookTitle,
    Value<int?>? pageNumber,
    Value<int?>? paraIndex,
    Value<String>? itemText,
    Value<String>? translationFa,
    Value<String>? translationAr,
    Value<String>? pronounceFa,
    Value<String>? pronounceAr,
    Value<String>? explanationFa,
    Value<String>? explanationAr,
    Value<String>? cefrLevel,
    Value<int>? importance,
    Value<String>? status,
    Value<String>? note,
    Value<String>? extra,
    Value<int>? createdMs,
    Value<int>? updatedMs,
    Value<bool>? deleted,
    Value<bool>? dirty,
    Value<int>? rowid,
  }) {
    return StudyItemsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      bookId: bookId ?? this.bookId,
      bookTitle: bookTitle ?? this.bookTitle,
      pageNumber: pageNumber ?? this.pageNumber,
      paraIndex: paraIndex ?? this.paraIndex,
      itemText: itemText ?? this.itemText,
      translationFa: translationFa ?? this.translationFa,
      translationAr: translationAr ?? this.translationAr,
      pronounceFa: pronounceFa ?? this.pronounceFa,
      pronounceAr: pronounceAr ?? this.pronounceAr,
      explanationFa: explanationFa ?? this.explanationFa,
      explanationAr: explanationAr ?? this.explanationAr,
      cefrLevel: cefrLevel ?? this.cefrLevel,
      importance: importance ?? this.importance,
      status: status ?? this.status,
      note: note ?? this.note,
      extra: extra ?? this.extra,
      createdMs: createdMs ?? this.createdMs,
      updatedMs: updatedMs ?? this.updatedMs,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (bookTitle.present) {
      map['book_title'] = Variable<String>(bookTitle.value);
    }
    if (pageNumber.present) {
      map['page_number'] = Variable<int>(pageNumber.value);
    }
    if (paraIndex.present) {
      map['para_index'] = Variable<int>(paraIndex.value);
    }
    if (itemText.present) {
      map['text'] = Variable<String>(itemText.value);
    }
    if (translationFa.present) {
      map['translation_fa'] = Variable<String>(translationFa.value);
    }
    if (translationAr.present) {
      map['translation_ar'] = Variable<String>(translationAr.value);
    }
    if (pronounceFa.present) {
      map['pronounce_fa'] = Variable<String>(pronounceFa.value);
    }
    if (pronounceAr.present) {
      map['pronounce_ar'] = Variable<String>(pronounceAr.value);
    }
    if (explanationFa.present) {
      map['explanation_fa'] = Variable<String>(explanationFa.value);
    }
    if (explanationAr.present) {
      map['explanation_ar'] = Variable<String>(explanationAr.value);
    }
    if (cefrLevel.present) {
      map['cefr_level'] = Variable<String>(cefrLevel.value);
    }
    if (importance.present) {
      map['importance'] = Variable<int>(importance.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (extra.present) {
      map['extra'] = Variable<String>(extra.value);
    }
    if (createdMs.present) {
      map['created_ms'] = Variable<int>(createdMs.value);
    }
    if (updatedMs.present) {
      map['updated_ms'] = Variable<int>(updatedMs.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudyItemsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('bookId: $bookId, ')
          ..write('bookTitle: $bookTitle, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('paraIndex: $paraIndex, ')
          ..write('itemText: $itemText, ')
          ..write('translationFa: $translationFa, ')
          ..write('translationAr: $translationAr, ')
          ..write('pronounceFa: $pronounceFa, ')
          ..write('pronounceAr: $pronounceAr, ')
          ..write('explanationFa: $explanationFa, ')
          ..write('explanationAr: $explanationAr, ')
          ..write('cefrLevel: $cefrLevel, ')
          ..write('importance: $importance, ')
          ..write('status: $status, ')
          ..write('note: $note, ')
          ..write('extra: $extra, ')
          ..write('createdMs: $createdMs, ')
          ..write('updatedMs: $updatedMs, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $StudyItemsTable studyItems = $StudyItemsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [studyItems];
}

typedef $$StudyItemsTableCreateCompanionBuilder =
    StudyItemsCompanion Function({
      required String id,
      required String kind,
      Value<String> bookId,
      Value<String> bookTitle,
      Value<int?> pageNumber,
      Value<int?> paraIndex,
      required String itemText,
      Value<String> translationFa,
      Value<String> translationAr,
      Value<String> pronounceFa,
      Value<String> pronounceAr,
      Value<String> explanationFa,
      Value<String> explanationAr,
      Value<String> cefrLevel,
      Value<int> importance,
      Value<String> status,
      Value<String> note,
      Value<String> extra,
      required int createdMs,
      required int updatedMs,
      Value<bool> deleted,
      Value<bool> dirty,
      Value<int> rowid,
    });
typedef $$StudyItemsTableUpdateCompanionBuilder =
    StudyItemsCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> bookId,
      Value<String> bookTitle,
      Value<int?> pageNumber,
      Value<int?> paraIndex,
      Value<String> itemText,
      Value<String> translationFa,
      Value<String> translationAr,
      Value<String> pronounceFa,
      Value<String> pronounceAr,
      Value<String> explanationFa,
      Value<String> explanationAr,
      Value<String> cefrLevel,
      Value<int> importance,
      Value<String> status,
      Value<String> note,
      Value<String> extra,
      Value<int> createdMs,
      Value<int> updatedMs,
      Value<bool> deleted,
      Value<bool> dirty,
      Value<int> rowid,
    });

class $$StudyItemsTableFilterComposer
    extends Composer<_$AppDatabase, $StudyItemsTable> {
  $$StudyItemsTableFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookTitle => $composableBuilder(
    column: $table.bookTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paraIndex => $composableBuilder(
    column: $table.paraIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemText => $composableBuilder(
    column: $table.itemText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translationFa => $composableBuilder(
    column: $table.translationFa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translationAr => $composableBuilder(
    column: $table.translationAr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pronounceFa => $composableBuilder(
    column: $table.pronounceFa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pronounceAr => $composableBuilder(
    column: $table.pronounceAr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get explanationFa => $composableBuilder(
    column: $table.explanationFa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get explanationAr => $composableBuilder(
    column: $table.explanationAr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cefrLevel => $composableBuilder(
    column: $table.cefrLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get importance => $composableBuilder(
    column: $table.importance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extra => $composableBuilder(
    column: $table.extra,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdMs => $composableBuilder(
    column: $table.createdMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedMs => $composableBuilder(
    column: $table.updatedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StudyItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $StudyItemsTable> {
  $$StudyItemsTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookTitle => $composableBuilder(
    column: $table.bookTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paraIndex => $composableBuilder(
    column: $table.paraIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemText => $composableBuilder(
    column: $table.itemText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translationFa => $composableBuilder(
    column: $table.translationFa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translationAr => $composableBuilder(
    column: $table.translationAr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pronounceFa => $composableBuilder(
    column: $table.pronounceFa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pronounceAr => $composableBuilder(
    column: $table.pronounceAr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get explanationFa => $composableBuilder(
    column: $table.explanationFa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get explanationAr => $composableBuilder(
    column: $table.explanationAr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cefrLevel => $composableBuilder(
    column: $table.cefrLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get importance => $composableBuilder(
    column: $table.importance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extra => $composableBuilder(
    column: $table.extra,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdMs => $composableBuilder(
    column: $table.createdMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedMs => $composableBuilder(
    column: $table.updatedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StudyItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StudyItemsTable> {
  $$StudyItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get bookTitle =>
      $composableBuilder(column: $table.bookTitle, builder: (column) => column);

  GeneratedColumn<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get paraIndex =>
      $composableBuilder(column: $table.paraIndex, builder: (column) => column);

  GeneratedColumn<String> get itemText =>
      $composableBuilder(column: $table.itemText, builder: (column) => column);

  GeneratedColumn<String> get translationFa => $composableBuilder(
    column: $table.translationFa,
    builder: (column) => column,
  );

  GeneratedColumn<String> get translationAr => $composableBuilder(
    column: $table.translationAr,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pronounceFa => $composableBuilder(
    column: $table.pronounceFa,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pronounceAr => $composableBuilder(
    column: $table.pronounceAr,
    builder: (column) => column,
  );

  GeneratedColumn<String> get explanationFa => $composableBuilder(
    column: $table.explanationFa,
    builder: (column) => column,
  );

  GeneratedColumn<String> get explanationAr => $composableBuilder(
    column: $table.explanationAr,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cefrLevel =>
      $composableBuilder(column: $table.cefrLevel, builder: (column) => column);

  GeneratedColumn<int> get importance => $composableBuilder(
    column: $table.importance,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get extra =>
      $composableBuilder(column: $table.extra, builder: (column) => column);

  GeneratedColumn<int> get createdMs =>
      $composableBuilder(column: $table.createdMs, builder: (column) => column);

  GeneratedColumn<int> get updatedMs =>
      $composableBuilder(column: $table.updatedMs, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);
}

class $$StudyItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StudyItemsTable,
          StudyItemRow,
          $$StudyItemsTableFilterComposer,
          $$StudyItemsTableOrderingComposer,
          $$StudyItemsTableAnnotationComposer,
          $$StudyItemsTableCreateCompanionBuilder,
          $$StudyItemsTableUpdateCompanionBuilder,
          (
            StudyItemRow,
            BaseReferences<_$AppDatabase, $StudyItemsTable, StudyItemRow>,
          ),
          StudyItemRow,
          PrefetchHooks Function()
        > {
  $$StudyItemsTableTableManager(_$AppDatabase db, $StudyItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StudyItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StudyItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StudyItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> bookTitle = const Value.absent(),
                Value<int?> pageNumber = const Value.absent(),
                Value<int?> paraIndex = const Value.absent(),
                Value<String> itemText = const Value.absent(),
                Value<String> translationFa = const Value.absent(),
                Value<String> translationAr = const Value.absent(),
                Value<String> pronounceFa = const Value.absent(),
                Value<String> pronounceAr = const Value.absent(),
                Value<String> explanationFa = const Value.absent(),
                Value<String> explanationAr = const Value.absent(),
                Value<String> cefrLevel = const Value.absent(),
                Value<int> importance = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String> extra = const Value.absent(),
                Value<int> createdMs = const Value.absent(),
                Value<int> updatedMs = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StudyItemsCompanion(
                id: id,
                kind: kind,
                bookId: bookId,
                bookTitle: bookTitle,
                pageNumber: pageNumber,
                paraIndex: paraIndex,
                itemText: itemText,
                translationFa: translationFa,
                translationAr: translationAr,
                pronounceFa: pronounceFa,
                pronounceAr: pronounceAr,
                explanationFa: explanationFa,
                explanationAr: explanationAr,
                cefrLevel: cefrLevel,
                importance: importance,
                status: status,
                note: note,
                extra: extra,
                createdMs: createdMs,
                updatedMs: updatedMs,
                deleted: deleted,
                dirty: dirty,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                Value<String> bookId = const Value.absent(),
                Value<String> bookTitle = const Value.absent(),
                Value<int?> pageNumber = const Value.absent(),
                Value<int?> paraIndex = const Value.absent(),
                required String itemText,
                Value<String> translationFa = const Value.absent(),
                Value<String> translationAr = const Value.absent(),
                Value<String> pronounceFa = const Value.absent(),
                Value<String> pronounceAr = const Value.absent(),
                Value<String> explanationFa = const Value.absent(),
                Value<String> explanationAr = const Value.absent(),
                Value<String> cefrLevel = const Value.absent(),
                Value<int> importance = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String> extra = const Value.absent(),
                required int createdMs,
                required int updatedMs,
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StudyItemsCompanion.insert(
                id: id,
                kind: kind,
                bookId: bookId,
                bookTitle: bookTitle,
                pageNumber: pageNumber,
                paraIndex: paraIndex,
                itemText: itemText,
                translationFa: translationFa,
                translationAr: translationAr,
                pronounceFa: pronounceFa,
                pronounceAr: pronounceAr,
                explanationFa: explanationFa,
                explanationAr: explanationAr,
                cefrLevel: cefrLevel,
                importance: importance,
                status: status,
                note: note,
                extra: extra,
                createdMs: createdMs,
                updatedMs: updatedMs,
                deleted: deleted,
                dirty: dirty,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StudyItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StudyItemsTable,
      StudyItemRow,
      $$StudyItemsTableFilterComposer,
      $$StudyItemsTableOrderingComposer,
      $$StudyItemsTableAnnotationComposer,
      $$StudyItemsTableCreateCompanionBuilder,
      $$StudyItemsTableUpdateCompanionBuilder,
      (
        StudyItemRow,
        BaseReferences<_$AppDatabase, $StudyItemsTable, StudyItemRow>,
      ),
      StudyItemRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$StudyItemsTableTableManager get studyItems =>
      $$StudyItemsTableTableManager(_db, _db.studyItems);
}
