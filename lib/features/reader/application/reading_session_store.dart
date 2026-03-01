import 'dart:async';

import 'package:translate_reader/core/database/app_database.dart';
import 'package:translate_reader/features/reader/application/book_reader_service.dart';
import 'package:translate_reader/features/reader/domain/models/book_content.dart';
import 'package:translate_reader/features/reader/domain/models/reading_session.dart';

class ReadingSessionRestoreResult {
  const ReadingSessionRestoreResult({this.session, this.message});

  final ReadingSession? session;
  final String? message;
}

class ReadingSessionStore {
  ReadingSessionStore._();

  static final ReadingSessionStore instance = ReadingSessionStore._();
  static const Duration _persistDebounce = Duration(milliseconds: 350);

  final AppDatabase _database = AppDatabase.instance;
  ReadingSession? _session;
  Timer? _persistTimer;

  ReadingSession? get session => _session;

  void startSession({
    required BookContent book,
    int initialPage = 0,
    double defaultFontSize = 22,
    double? initialFontSize,
    ReaderAppearancePreset? initialAppearancePreset,
    ReaderLayoutMode? initialLayoutMode,
  }) {
    final double savedFontSize =
        initialFontSize ?? _session?.fontSize ?? defaultFontSize;
    final ReaderAppearancePreset savedAppearancePreset =
        initialAppearancePreset ??
        _session?.appearancePreset ??
        ReaderAppearancePreset.paper;
    final ReaderLayoutMode savedLayoutMode =
        initialLayoutMode ??
        _session?.layoutMode ??
        ReaderLayoutMode.pagedHorizontal;
    _session = ReadingSession(
      book: book,
      currentPage: initialPage,
      fontSize: savedFontSize,
      appearancePreset: savedAppearancePreset,
      layoutMode: savedLayoutMode,
    );

    _persistSession(immediate: true);
  }

  void updateCurrentPage(int page) {
    final current = _session;
    if (current == null || current.currentPage == page) {
      return;
    }

    _session = current.copyWith(currentPage: page);
    _persistSession();
  }

  void updateFontSize(double fontSize) {
    final current = _session;
    if (current == null || current.fontSize == fontSize) {
      return;
    }

    _session = current.copyWith(fontSize: fontSize);
    _persistSession();
  }

  void updateAppearancePreset(ReaderAppearancePreset appearancePreset) {
    final ReadingSession? current = _session;
    if (current == null || current.appearancePreset == appearancePreset) {
      return;
    }

    _session = current.copyWith(appearancePreset: appearancePreset);
    _persistSession();
  }

  void updateLayoutMode(ReaderLayoutMode layoutMode) {
    final ReadingSession? current = _session;
    if (current == null || current.layoutMode == layoutMode) {
      return;
    }

    _session = current.copyWith(layoutMode: layoutMode);
    _persistSession();
  }

  Future<ReadingSessionRestoreResult> restoreLastSession({
    required BookReaderService readerService,
  }) async {
    final RecentBook? recentBook = await _database.getMostRecentBook();
    if (recentBook == null) {
      return const ReadingSessionRestoreResult();
    }

    return restoreRecentBook(
      recentBook: recentBook,
      readerService: readerService,
    );
  }

  Future<ReadingSessionRestoreResult> restoreRecentBook({
    required RecentBook recentBook,
    required BookReaderService readerService,
  }) async {
    final BookLoadResult result = await readerService.loadBookFromPath(
      recentBook.path,
    );
    if (result.book == null) {
      await _database.removeRecentBook(recentBook.path);
      return ReadingSessionRestoreResult(
        message: result.message ?? 'Не удалось восстановить сохранённую книгу.',
      );
    }

    startSession(
      book: result.book!,
      initialPage: recentBook.currentPage,
      initialFontSize: recentBook.fontSize,
      initialAppearancePreset: parseReaderAppearancePreset(
        recentBook.appearancePreset,
      ),
      initialLayoutMode: parseReaderLayoutMode(recentBook.layoutMode),
    );

    return ReadingSessionRestoreResult(
      session: _session,
      message: 'Можно продолжить чтение с сохранённой страницы.',
    );
  }

  Future<List<RecentBook>> loadRecentBooks({int limit = 5}) {
    return _database.getRecentBooks(limit: limit);
  }

  void _persistSession({bool immediate = false}) {
    _persistTimer?.cancel();
    if (immediate) {
      unawaited(_saveSessionToDatabase());
      return;
    }

    _persistTimer = Timer(_persistDebounce, () {
      unawaited(_saveSessionToDatabase());
    });
  }

  Future<void> _saveSessionToDatabase() async {
    final ReadingSession? current = _session;
    final String? filePath = current?.book.filePath;
    if (current == null || filePath == null) {
      return;
    }

    await _database.saveRecentBook(
      path: filePath,
      fileName: current.book.fileName,
      format: current.book.format.extension,
      currentPage: current.currentPage,
      fontSize: current.fontSize,
      appearancePreset: current.appearancePreset.name,
      layoutMode: current.layoutMode.name,
    );
  }
}
