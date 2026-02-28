import 'package:translate_reader/features/reader/domain/models/book_content.dart';
import 'package:translate_reader/features/reader/domain/models/reading_session.dart';

class ReadingSessionStore {
  ReadingSessionStore._();

  static final ReadingSessionStore instance = ReadingSessionStore._();

  ReadingSession? _session;

  ReadingSession? get session => _session;

  void startSession({
    required BookContent book,
    double defaultFontSize = 22,
  }) {
    final savedFontSize = _session?.fontSize;
    _session = ReadingSession(
      book: book,
      currentPage: 0,
      fontSize: savedFontSize ?? defaultFontSize,
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
}
