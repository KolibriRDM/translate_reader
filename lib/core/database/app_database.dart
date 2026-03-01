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

@DriftDatabase(tables: [VocabularyEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase._() : super(_openConnection());

  static AppDatabase? _instance;

  static AppDatabase get instance {
    _instance ??= AppDatabase._();
    return _instance!;
  }

  @override
  int get schemaVersion => 1;

  /// Добавляет слово и перевод в словарик.
  Future<int> addWord({
    required String word,
    required String translation,
  }) {
    return into(vocabularyEntries).insert(
      VocabularyEntriesCompanion.insert(
        word: word,
        translation: translation,
      ),
    );
  }

  /// Удаляет слово из словарика по id.
  Future<int> removeWord(int id) {
    return (delete(vocabularyEntries)..where((t) => t.id.equals(id))).go();
  }

  /// Удаляет слово из словарика по тексту слова.
  Future<int> removeWordByText(String word) {
    return (delete(vocabularyEntries)
          ..where((t) => t.word.equals(word)))
        .go();
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
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final Directory dbFolder = await getApplicationDocumentsDirectory();
    final File file = File(p.join(dbFolder.path, 'translate_reader.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
