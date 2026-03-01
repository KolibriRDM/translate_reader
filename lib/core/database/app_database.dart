import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Таблица сохранённых слов для словарика.
class VocabularyEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get word => text()();
  TextColumn get translation => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Таблица последних открытых книг и сохранённой позиции чтения.
class RecentBooks extends Table {
  TextColumn get path => text()();
  TextColumn get fileName => text()();
  TextColumn get format => text()();
  IntColumn get currentPage => integer().withDefault(const Constant(0))();
  RealColumn get fontSize => real().withDefault(const Constant(22))();
  TextColumn get appearancePreset =>
      text().withDefault(const Constant('paper'))();
  TextColumn get layoutMode =>
      text().withDefault(const Constant('pagedHorizontal'))();
  DateTimeColumn get lastOpenedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{path};
}

@DriftDatabase(tables: [VocabularyEntries, RecentBooks])
class AppDatabase extends _$AppDatabase {
  AppDatabase._() : super(_openConnection());

  static AppDatabase? _instance;

  static AppDatabase get instance {
    _instance ??= AppDatabase._();
    return _instance!;
  }

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(recentBooks);
      }
    },
  );

  /// Добавляет слово и перевод в словарик.
  Future<int> addWord({required String word, required String translation}) {
    return into(vocabularyEntries).insert(
      VocabularyEntriesCompanion.insert(word: word, translation: translation),
    );
  }

  /// Удаляет слово из словарика по id.
  Future<int> removeWord(int id) {
    return (delete(vocabularyEntries)..where((t) => t.id.equals(id))).go();
  }

  /// Удаляет слово из словарика по тексту слова.
  Future<int> removeWordByText(String word) {
    return (delete(vocabularyEntries)..where((t) => t.word.equals(word))).go();
  }

  /// Проверяет, есть ли слово в словарике.
  Future<bool> isWordSaved(String word) async {
    final query = select(vocabularyEntries)
      ..where((t) => t.word.equals(word))
      ..limit(1);
    final results = await query.get();
    return results.isNotEmpty;
  }

  /// Возвращает поток всех слов в словарике, отсортированных по дате добавления.
  Stream<List<VocabularyEntry>> watchAllWords() {
    final query = select(vocabularyEntries)
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    return query.watch();
  }

  /// Возвращает все слова из словарика.
  Future<List<VocabularyEntry>> getAllWords() {
    final query = select(vocabularyEntries)
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    return query.get();
  }

  /// Создаёт или обновляет запись о последней прочитанной книге.
  Future<void> saveRecentBook({
    required String path,
    required String fileName,
    required String format,
    required int currentPage,
    required double fontSize,
    required String appearancePreset,
    required String layoutMode,
  }) {
    return into(recentBooks).insertOnConflictUpdate(
      RecentBooksCompanion(
        path: Value(path),
        fileName: Value(fileName),
        format: Value(format),
        currentPage: Value(currentPage),
        fontSize: Value(fontSize),
        appearancePreset: Value(appearancePreset),
        layoutMode: Value(layoutMode),
        lastOpenedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Возвращает последнюю открытую книгу.
  Future<RecentBook?> getMostRecentBook() {
    final query = select(recentBooks)
      ..orderBy([
        (t) =>
            OrderingTerm(expression: t.lastOpenedAt, mode: OrderingMode.desc),
      ])
      ..limit(1);
    return query.getSingleOrNull();
  }

  /// Возвращает несколько последних книг для домашнего экрана.
  Future<List<RecentBook>> getRecentBooks({int limit = 5}) {
    final query = select(recentBooks)
      ..orderBy([
        (t) =>
            OrderingTerm(expression: t.lastOpenedAt, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    return query.get();
  }

  /// Удаляет книгу из истории, если файл больше недоступен.
  Future<int> removeRecentBook(String path) {
    return (delete(recentBooks)..where((t) => t.path.equals(path))).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final Directory dbFolder = await getApplicationDocumentsDirectory();
    final File file = File(p.join(dbFolder.path, 'translate_reader.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
