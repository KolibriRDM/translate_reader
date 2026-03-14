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

  /// Добавляет фразу в словарик. Возвращает true, если фраза добавлена.
  Future<bool> addPhrase({
    required String phrase,
    required String translation,
  }) async {
    final String normalized = phrase.toLowerCase();
    final bool alreadySaved = await _db.isPhraseSaved(normalized);
    if (alreadySaved) {
      return false;
    }

    await _db.addPhrase(phrase: normalized, translation: translation);
    return true;
  }

  /// Удаляет фразу из словарика по тексту.
  Future<void> removePhrase(String phrase) async {
    await _db.removePhraseByText(phrase.toLowerCase());
  }

  /// Удаляет фразу из словарика по id.
  Future<void> removePhraseById(int id) async {
    await _db.removePhraseById(id);
  }

  /// Проверяет, сохранена ли фраза в словарике.
  Future<bool> isPhraseSaved(String phrase) {
    return _db.isPhraseSaved(phrase.toLowerCase());
  }

  /// Поток всех фраз из словарика.
  Stream<List<SavedPhrase>> watchAllPhrases() {
    return _db.watchAllPhrases();
  }
}
