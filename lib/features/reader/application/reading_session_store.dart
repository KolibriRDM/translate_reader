import 'package:translate_reader/features/reader/domain/models/book_content.dart';
import 'package:translate_reader/features/reader/domain/models/reading_session.dart';

class ReadingSessionStore {
  ReadingSessionStore._();

  static final ReadingSessionStore instance = ReadingSessionStore._();

  ReadingSession? _session;

  ReadingSession? get session => _session;

  void startSession({required BookContent book, double defaultFontSize = 22}) {
    final double? savedFontSize = _session?.fontSize;
    final ReaderAppearancePreset savedAppearancePreset =
        _session?.appearancePreset ?? ReaderAppearancePreset.paper;
    final ReaderLayoutMode savedLayoutMode =
        _session?.layoutMode ?? ReaderLayoutMode.pagedHorizontal;
    _session = ReadingSession(
      book: book,
      currentPage: 0,
      fontSize: savedFontSize ?? defaultFontSize,
      appearancePreset: savedAppearancePreset,
      layoutMode: savedLayoutMode,
    );
  }

  void updateCurrentPage(int page) {
    final current = _session;
    if (current == null) {
      return;
    }

    _session = current.copyWith(currentPage: page);
  }

  void updateFontSize(double fontSize) {
    final current = _session;
    if (current == null) {
      return;
    }

    _session = current.copyWith(fontSize: fontSize);
  }

  void updateAppearancePreset(ReaderAppearancePreset appearancePreset) {
    final ReadingSession? current = _session;
    if (current == null) {
      return;
    }

    _session = current.copyWith(appearancePreset: appearancePreset);
  }

  void updateLayoutMode(ReaderLayoutMode layoutMode) {
    final ReadingSession? current = _session;
    if (current == null) {
      return;
    }

    _session = current.copyWith(layoutMode: layoutMode);
  }
}
