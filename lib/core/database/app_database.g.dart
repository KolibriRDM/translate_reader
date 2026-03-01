// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $VocabularyEntriesTable extends VocabularyEntries
    with TableInfo<$VocabularyEntriesTable, VocabularyEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VocabularyEntriesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _wordMeta = const VerificationMeta('word');
  @override
  late final GeneratedColumn<String> word = GeneratedColumn<String>(
    'word',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _translationMeta = const VerificationMeta(
    'translation',
  );
  @override
  late final GeneratedColumn<String> translation = GeneratedColumn<String>(
    'translation',
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, word, translation, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vocabulary_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<VocabularyEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('word')) {
      context.handle(
        _wordMeta,
        word.isAcceptableOrUnknown(data['word']!, _wordMeta),
      );
    } else if (isInserting) {
      context.missing(_wordMeta);
    }
    if (data.containsKey('translation')) {
      context.handle(
        _translationMeta,
        translation.isAcceptableOrUnknown(
          data['translation']!,
          _translationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_translationMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VocabularyEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VocabularyEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      word: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word'],
      )!,
      translation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translation'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $VocabularyEntriesTable createAlias(String alias) {
    return $VocabularyEntriesTable(attachedDatabase, alias);
  }
}

class VocabularyEntry extends DataClass implements Insertable<VocabularyEntry> {
  final int id;
  final String word;
  final String translation;
  final DateTime createdAt;
  const VocabularyEntry({
    required this.id,
    required this.word,
    required this.translation,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['word'] = Variable<String>(word);
    map['translation'] = Variable<String>(translation);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  VocabularyEntriesCompanion toCompanion(bool nullToAbsent) {
    return VocabularyEntriesCompanion(
      id: Value(id),
      word: Value(word),
      translation: Value(translation),
      createdAt: Value(createdAt),
    );
  }

  factory VocabularyEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VocabularyEntry(
      id: serializer.fromJson<int>(json['id']),
      word: serializer.fromJson<String>(json['word']),
      translation: serializer.fromJson<String>(json['translation']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'word': serializer.toJson<String>(word),
      'translation': serializer.toJson<String>(translation),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  VocabularyEntry copyWith({
    int? id,
    String? word,
    String? translation,
    DateTime? createdAt,
  }) => VocabularyEntry(
    id: id ?? this.id,
    word: word ?? this.word,
    translation: translation ?? this.translation,
    createdAt: createdAt ?? this.createdAt,
  );
  VocabularyEntry copyWithCompanion(VocabularyEntriesCompanion data) {
    return VocabularyEntry(
      id: data.id.present ? data.id.value : this.id,
      word: data.word.present ? data.word.value : this.word,
      translation: data.translation.present
          ? data.translation.value
          : this.translation,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VocabularyEntry(')
          ..write('id: $id, ')
          ..write('word: $word, ')
          ..write('translation: $translation, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, word, translation, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VocabularyEntry &&
          other.id == this.id &&
          other.word == this.word &&
          other.translation == this.translation &&
          other.createdAt == this.createdAt);
}

class VocabularyEntriesCompanion extends UpdateCompanion<VocabularyEntry> {
  final Value<int> id;
  final Value<String> word;
  final Value<String> translation;
  final Value<DateTime> createdAt;
  const VocabularyEntriesCompanion({
    this.id = const Value.absent(),
    this.word = const Value.absent(),
    this.translation = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  VocabularyEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String word,
    required String translation,
    this.createdAt = const Value.absent(),
  }) : word = Value(word),
       translation = Value(translation);
  static Insertable<VocabularyEntry> custom({
    Expression<int>? id,
    Expression<String>? word,
    Expression<String>? translation,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (word != null) 'word': word,
      if (translation != null) 'translation': translation,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  VocabularyEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? word,
    Value<String>? translation,
    Value<DateTime>? createdAt,
  }) {
    return VocabularyEntriesCompanion(
      id: id ?? this.id,
      word: word ?? this.word,
      translation: translation ?? this.translation,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (word.present) {
      map['word'] = Variable<String>(word.value);
    }
    if (translation.present) {
      map['translation'] = Variable<String>(translation.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VocabularyEntriesCompanion(')
          ..write('id: $id, ')
          ..write('word: $word, ')
          ..write('translation: $translation, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $RecentBooksTable extends RecentBooks
    with TableInfo<$RecentBooksTable, RecentBook> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecentBooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentPageMeta = const VerificationMeta(
    'currentPage',
  );
  @override
  late final GeneratedColumn<int> currentPage = GeneratedColumn<int>(
    'current_page',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fontSizeMeta = const VerificationMeta(
    'fontSize',
  );
  @override
  late final GeneratedColumn<double> fontSize = GeneratedColumn<double>(
    'font_size',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(22),
  );
  static const VerificationMeta _appearancePresetMeta = const VerificationMeta(
    'appearancePreset',
  );
  @override
  late final GeneratedColumn<String> appearancePreset = GeneratedColumn<String>(
    'appearance_preset',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('paper'),
  );
  static const VerificationMeta _layoutModeMeta = const VerificationMeta(
    'layoutMode',
  );
  @override
  late final GeneratedColumn<String> layoutMode = GeneratedColumn<String>(
    'layout_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pagedHorizontal'),
  );
  static const VerificationMeta _lastOpenedAtMeta = const VerificationMeta(
    'lastOpenedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastOpenedAt = GeneratedColumn<DateTime>(
    'last_opened_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    path,
    fileName,
    format,
    currentPage,
    fontSize,
    appearancePreset,
    layoutMode,
    lastOpenedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recent_books';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecentBook> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('current_page')) {
      context.handle(
        _currentPageMeta,
        currentPage.isAcceptableOrUnknown(
          data['current_page']!,
          _currentPageMeta,
        ),
      );
    }
    if (data.containsKey('font_size')) {
      context.handle(
        _fontSizeMeta,
        fontSize.isAcceptableOrUnknown(data['font_size']!, _fontSizeMeta),
      );
    }
    if (data.containsKey('appearance_preset')) {
      context.handle(
        _appearancePresetMeta,
        appearancePreset.isAcceptableOrUnknown(
          data['appearance_preset']!,
          _appearancePresetMeta,
        ),
      );
    }
    if (data.containsKey('layout_mode')) {
      context.handle(
        _layoutModeMeta,
        layoutMode.isAcceptableOrUnknown(data['layout_mode']!, _layoutModeMeta),
      );
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  RecentBook map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecentBook(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      currentPage: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_page'],
      )!,
      fontSize: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}font_size'],
      )!,
      appearancePreset: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}appearance_preset'],
      )!,
      layoutMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}layout_mode'],
      )!,
      lastOpenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_opened_at'],
      )!,
    );
  }

  @override
  $RecentBooksTable createAlias(String alias) {
    return $RecentBooksTable(attachedDatabase, alias);
  }
}

class RecentBook extends DataClass implements Insertable<RecentBook> {
  final String path;
  final String fileName;
  final String format;
  final int currentPage;
  final double fontSize;
  final String appearancePreset;
  final String layoutMode;
  final DateTime lastOpenedAt;
  const RecentBook({
    required this.path,
    required this.fileName,
    required this.format,
    required this.currentPage,
    required this.fontSize,
    required this.appearancePreset,
    required this.layoutMode,
    required this.lastOpenedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['file_name'] = Variable<String>(fileName);
    map['format'] = Variable<String>(format);
    map['current_page'] = Variable<int>(currentPage);
    map['font_size'] = Variable<double>(fontSize);
    map['appearance_preset'] = Variable<String>(appearancePreset);
    map['layout_mode'] = Variable<String>(layoutMode);
    map['last_opened_at'] = Variable<DateTime>(lastOpenedAt);
    return map;
  }

  RecentBooksCompanion toCompanion(bool nullToAbsent) {
    return RecentBooksCompanion(
      path: Value(path),
      fileName: Value(fileName),
      format: Value(format),
      currentPage: Value(currentPage),
      fontSize: Value(fontSize),
      appearancePreset: Value(appearancePreset),
      layoutMode: Value(layoutMode),
      lastOpenedAt: Value(lastOpenedAt),
    );
  }

  factory RecentBook.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecentBook(
      path: serializer.fromJson<String>(json['path']),
      fileName: serializer.fromJson<String>(json['fileName']),
      format: serializer.fromJson<String>(json['format']),
      currentPage: serializer.fromJson<int>(json['currentPage']),
      fontSize: serializer.fromJson<double>(json['fontSize']),
      appearancePreset: serializer.fromJson<String>(json['appearancePreset']),
      layoutMode: serializer.fromJson<String>(json['layoutMode']),
      lastOpenedAt: serializer.fromJson<DateTime>(json['lastOpenedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'fileName': serializer.toJson<String>(fileName),
      'format': serializer.toJson<String>(format),
      'currentPage': serializer.toJson<int>(currentPage),
      'fontSize': serializer.toJson<double>(fontSize),
      'appearancePreset': serializer.toJson<String>(appearancePreset),
      'layoutMode': serializer.toJson<String>(layoutMode),
      'lastOpenedAt': serializer.toJson<DateTime>(lastOpenedAt),
    };
  }

  RecentBook copyWith({
    String? path,
    String? fileName,
    String? format,
    int? currentPage,
    double? fontSize,
    String? appearancePreset,
    String? layoutMode,
    DateTime? lastOpenedAt,
  }) => RecentBook(
    path: path ?? this.path,
    fileName: fileName ?? this.fileName,
    format: format ?? this.format,
    currentPage: currentPage ?? this.currentPage,
    fontSize: fontSize ?? this.fontSize,
    appearancePreset: appearancePreset ?? this.appearancePreset,
    layoutMode: layoutMode ?? this.layoutMode,
    lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
  );
  RecentBook copyWithCompanion(RecentBooksCompanion data) {
    return RecentBook(
      path: data.path.present ? data.path.value : this.path,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      format: data.format.present ? data.format.value : this.format,
      currentPage: data.currentPage.present
          ? data.currentPage.value
          : this.currentPage,
      fontSize: data.fontSize.present ? data.fontSize.value : this.fontSize,
      appearancePreset: data.appearancePreset.present
          ? data.appearancePreset.value
          : this.appearancePreset,
      layoutMode: data.layoutMode.present
          ? data.layoutMode.value
          : this.layoutMode,
      lastOpenedAt: data.lastOpenedAt.present
          ? data.lastOpenedAt.value
          : this.lastOpenedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecentBook(')
          ..write('path: $path, ')
          ..write('fileName: $fileName, ')
          ..write('format: $format, ')
          ..write('currentPage: $currentPage, ')
          ..write('fontSize: $fontSize, ')
          ..write('appearancePreset: $appearancePreset, ')
          ..write('layoutMode: $layoutMode, ')
          ..write('lastOpenedAt: $lastOpenedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    path,
    fileName,
    format,
    currentPage,
    fontSize,
    appearancePreset,
    layoutMode,
    lastOpenedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecentBook &&
          other.path == this.path &&
          other.fileName == this.fileName &&
          other.format == this.format &&
          other.currentPage == this.currentPage &&
          other.fontSize == this.fontSize &&
          other.appearancePreset == this.appearancePreset &&
          other.layoutMode == this.layoutMode &&
          other.lastOpenedAt == this.lastOpenedAt);
}

class RecentBooksCompanion extends UpdateCompanion<RecentBook> {
  final Value<String> path;
  final Value<String> fileName;
  final Value<String> format;
  final Value<int> currentPage;
  final Value<double> fontSize;
  final Value<String> appearancePreset;
  final Value<String> layoutMode;
  final Value<DateTime> lastOpenedAt;
  final Value<int> rowid;
  const RecentBooksCompanion({
    this.path = const Value.absent(),
    this.fileName = const Value.absent(),
    this.format = const Value.absent(),
    this.currentPage = const Value.absent(),
    this.fontSize = const Value.absent(),
    this.appearancePreset = const Value.absent(),
    this.layoutMode = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecentBooksCompanion.insert({
    required String path,
    required String fileName,
    required String format,
    this.currentPage = const Value.absent(),
    this.fontSize = const Value.absent(),
    this.appearancePreset = const Value.absent(),
    this.layoutMode = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       fileName = Value(fileName),
       format = Value(format);
  static Insertable<RecentBook> custom({
    Expression<String>? path,
    Expression<String>? fileName,
    Expression<String>? format,
    Expression<int>? currentPage,
    Expression<double>? fontSize,
    Expression<String>? appearancePreset,
    Expression<String>? layoutMode,
    Expression<DateTime>? lastOpenedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (fileName != null) 'file_name': fileName,
      if (format != null) 'format': format,
      if (currentPage != null) 'current_page': currentPage,
      if (fontSize != null) 'font_size': fontSize,
      if (appearancePreset != null) 'appearance_preset': appearancePreset,
      if (layoutMode != null) 'layout_mode': layoutMode,
      if (lastOpenedAt != null) 'last_opened_at': lastOpenedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecentBooksCompanion copyWith({
    Value<String>? path,
    Value<String>? fileName,
    Value<String>? format,
    Value<int>? currentPage,
    Value<double>? fontSize,
    Value<String>? appearancePreset,
    Value<String>? layoutMode,
    Value<DateTime>? lastOpenedAt,
    Value<int>? rowid,
  }) {
    return RecentBooksCompanion(
      path: path ?? this.path,
      fileName: fileName ?? this.fileName,
      format: format ?? this.format,
      currentPage: currentPage ?? this.currentPage,
      fontSize: fontSize ?? this.fontSize,
      appearancePreset: appearancePreset ?? this.appearancePreset,
      layoutMode: layoutMode ?? this.layoutMode,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (currentPage.present) {
      map['current_page'] = Variable<int>(currentPage.value);
    }
    if (fontSize.present) {
      map['font_size'] = Variable<double>(fontSize.value);
    }
    if (appearancePreset.present) {
      map['appearance_preset'] = Variable<String>(appearancePreset.value);
    }
    if (layoutMode.present) {
      map['layout_mode'] = Variable<String>(layoutMode.value);
    }
    if (lastOpenedAt.present) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecentBooksCompanion(')
          ..write('path: $path, ')
          ..write('fileName: $fileName, ')
          ..write('format: $format, ')
          ..write('currentPage: $currentPage, ')
          ..write('fontSize: $fontSize, ')
          ..write('appearancePreset: $appearancePreset, ')
          ..write('layoutMode: $layoutMode, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $VocabularyEntriesTable vocabularyEntries =
      $VocabularyEntriesTable(this);
  late final $RecentBooksTable recentBooks = $RecentBooksTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    vocabularyEntries,
    recentBooks,
  ];
}

typedef $$VocabularyEntriesTableCreateCompanionBuilder =
    VocabularyEntriesCompanion Function({
      Value<int> id,
      required String word,
      required String translation,
      Value<DateTime> createdAt,
    });
typedef $$VocabularyEntriesTableUpdateCompanionBuilder =
    VocabularyEntriesCompanion Function({
      Value<int> id,
      Value<String> word,
      Value<String> translation,
      Value<DateTime> createdAt,
    });

class $$VocabularyEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $VocabularyEntriesTable> {
  $$VocabularyEntriesTableFilterComposer({
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

  ColumnFilters<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VocabularyEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $VocabularyEntriesTable> {
  $$VocabularyEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VocabularyEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $VocabularyEntriesTable> {
  $$VocabularyEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get word =>
      $composableBuilder(column: $table.word, builder: (column) => column);

  GeneratedColumn<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$VocabularyEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VocabularyEntriesTable,
          VocabularyEntry,
          $$VocabularyEntriesTableFilterComposer,
          $$VocabularyEntriesTableOrderingComposer,
          $$VocabularyEntriesTableAnnotationComposer,
          $$VocabularyEntriesTableCreateCompanionBuilder,
          $$VocabularyEntriesTableUpdateCompanionBuilder,
          (
            VocabularyEntry,
            BaseReferences<
              _$AppDatabase,
              $VocabularyEntriesTable,
              VocabularyEntry
            >,
          ),
          VocabularyEntry,
          PrefetchHooks Function()
        > {
  $$VocabularyEntriesTableTableManager(
    _$AppDatabase db,
    $VocabularyEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VocabularyEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VocabularyEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VocabularyEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> word = const Value.absent(),
                Value<String> translation = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => VocabularyEntriesCompanion(
                id: id,
                word: word,
                translation: translation,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String word,
                required String translation,
                Value<DateTime> createdAt = const Value.absent(),
              }) => VocabularyEntriesCompanion.insert(
                id: id,
                word: word,
                translation: translation,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VocabularyEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VocabularyEntriesTable,
      VocabularyEntry,
      $$VocabularyEntriesTableFilterComposer,
      $$VocabularyEntriesTableOrderingComposer,
      $$VocabularyEntriesTableAnnotationComposer,
      $$VocabularyEntriesTableCreateCompanionBuilder,
      $$VocabularyEntriesTableUpdateCompanionBuilder,
      (
        VocabularyEntry,
        BaseReferences<_$AppDatabase, $VocabularyEntriesTable, VocabularyEntry>,
      ),
      VocabularyEntry,
      PrefetchHooks Function()
    >;
typedef $$RecentBooksTableCreateCompanionBuilder =
    RecentBooksCompanion Function({
      required String path,
      required String fileName,
      required String format,
      Value<int> currentPage,
      Value<double> fontSize,
      Value<String> appearancePreset,
      Value<String> layoutMode,
      Value<DateTime> lastOpenedAt,
      Value<int> rowid,
    });
typedef $$RecentBooksTableUpdateCompanionBuilder =
    RecentBooksCompanion Function({
      Value<String> path,
      Value<String> fileName,
      Value<String> format,
      Value<int> currentPage,
      Value<double> fontSize,
      Value<String> appearancePreset,
      Value<String> layoutMode,
      Value<DateTime> lastOpenedAt,
      Value<int> rowid,
    });

class $$RecentBooksTableFilterComposer
    extends Composer<_$AppDatabase, $RecentBooksTable> {
  $$RecentBooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentPage => $composableBuilder(
    column: $table.currentPage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fontSize => $composableBuilder(
    column: $table.fontSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get appearancePreset => $composableBuilder(
    column: $table.appearancePreset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get layoutMode => $composableBuilder(
    column: $table.layoutMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecentBooksTableOrderingComposer
    extends Composer<_$AppDatabase, $RecentBooksTable> {
  $$RecentBooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentPage => $composableBuilder(
    column: $table.currentPage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fontSize => $composableBuilder(
    column: $table.fontSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get appearancePreset => $composableBuilder(
    column: $table.appearancePreset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get layoutMode => $composableBuilder(
    column: $table.layoutMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecentBooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecentBooksTable> {
  $$RecentBooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<int> get currentPage => $composableBuilder(
    column: $table.currentPage,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fontSize =>
      $composableBuilder(column: $table.fontSize, builder: (column) => column);

  GeneratedColumn<String> get appearancePreset => $composableBuilder(
    column: $table.appearancePreset,
    builder: (column) => column,
  );

  GeneratedColumn<String> get layoutMode => $composableBuilder(
    column: $table.layoutMode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => column,
  );
}

class $$RecentBooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecentBooksTable,
          RecentBook,
          $$RecentBooksTableFilterComposer,
          $$RecentBooksTableOrderingComposer,
          $$RecentBooksTableAnnotationComposer,
          $$RecentBooksTableCreateCompanionBuilder,
          $$RecentBooksTableUpdateCompanionBuilder,
          (
            RecentBook,
            BaseReferences<_$AppDatabase, $RecentBooksTable, RecentBook>,
          ),
          RecentBook,
          PrefetchHooks Function()
        > {
  $$RecentBooksTableTableManager(_$AppDatabase db, $RecentBooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecentBooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecentBooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecentBooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<int> currentPage = const Value.absent(),
                Value<double> fontSize = const Value.absent(),
                Value<String> appearancePreset = const Value.absent(),
                Value<String> layoutMode = const Value.absent(),
                Value<DateTime> lastOpenedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecentBooksCompanion(
                path: path,
                fileName: fileName,
                format: format,
                currentPage: currentPage,
                fontSize: fontSize,
                appearancePreset: appearancePreset,
                layoutMode: layoutMode,
                lastOpenedAt: lastOpenedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                required String fileName,
                required String format,
                Value<int> currentPage = const Value.absent(),
                Value<double> fontSize = const Value.absent(),
                Value<String> appearancePreset = const Value.absent(),
                Value<String> layoutMode = const Value.absent(),
                Value<DateTime> lastOpenedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecentBooksCompanion.insert(
                path: path,
                fileName: fileName,
                format: format,
                currentPage: currentPage,
                fontSize: fontSize,
                appearancePreset: appearancePreset,
                layoutMode: layoutMode,
                lastOpenedAt: lastOpenedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecentBooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecentBooksTable,
      RecentBook,
      $$RecentBooksTableFilterComposer,
      $$RecentBooksTableOrderingComposer,
      $$RecentBooksTableAnnotationComposer,
      $$RecentBooksTableCreateCompanionBuilder,
      $$RecentBooksTableUpdateCompanionBuilder,
      (
        RecentBook,
        BaseReferences<_$AppDatabase, $RecentBooksTable, RecentBook>,
      ),
      RecentBook,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$VocabularyEntriesTableTableManager get vocabularyEntries =>
      $$VocabularyEntriesTableTableManager(_db, _db.vocabularyEntries);
  $$RecentBooksTableTableManager get recentBooks =>
      $$RecentBooksTableTableManager(_db, _db.recentBooks);
}
