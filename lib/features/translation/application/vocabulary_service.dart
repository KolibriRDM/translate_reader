import 'package:translate_reader/core/database/app_database.dart';

/// Сервис для работы со словариком сохранённых слов.
class VocabularyService {
  VocabularyService._();

  static final VocabularyService instance = VocabularyService._();

  final AppDatabase _db = AppDatabase.instance;

  /// Добавляет слово в словарик. Возвращает true, если слово добавлено.
  Future<bool> addWord({
    required String word,
    required String translation,
  }) async {
    final String normalized = word.toLowerCase();
    final bool alreadySaved = await _db.isWordSaved(normalized);
    if (alreadySaved) {
      return false;
    }

    await _db.addWord(word: normalized, translation: translation);
    return true;
  }

  /// Удаляет слово из словарика по тексту.
  Future<void> removeWord(String word) async {
    await _db.removeWordByText(word.toLowerCase());
  }

  /// Удаляет слово из словарика по id.
  Future<void> removeWordById(int id) async {
    await _db.removeWord(id);
  }

  /// Проверяет, сохранено ли слово в словарике.
  Future<bool> isWordSaved(String word) {
    return _db.isWordSaved(word.toLowerCase());
  }

  /// Поток всех слов из словарика.
  Stream<List<VocabularyEntry>> watchAllWords() {
    return _db.watchAllWords();
  }

  /// Все слова из словарика.
  Future<List<VocabularyEntry>> getAllWords() {
    return _db.getAllWords();
  }
}
