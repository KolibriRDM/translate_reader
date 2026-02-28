import 'package:translate_reader/features/reader/domain/models/book_content.dart';

enum ReaderAppearancePreset { paper, mist, sepia, sage, graphite, night }

enum ReaderLayoutMode { pagedHorizontal, scrollVertical }

extension ReaderLayoutModeX on ReaderLayoutMode {
  String get label {
    switch (this) {
      case ReaderLayoutMode.pagedHorizontal:
        return 'Страницы';
      case ReaderLayoutMode.scrollVertical:
        return 'Вертикально';
    }
  }
}

class ReadingSession {
  const ReadingSession({
    required this.book,
    required this.currentPage,
    required this.fontSize,
    required this.appearancePreset,
    required this.layoutMode,
  });

  final BookContent book;
  final int currentPage;
  final double fontSize;
  final ReaderAppearancePreset appearancePreset;
  final ReaderLayoutMode layoutMode;

  ReadingSession copyWith({
    BookContent? book,
    int? currentPage,
    double? fontSize,
    ReaderAppearancePreset? appearancePreset,
    ReaderLayoutMode? layoutMode,
  }) {
    return ReadingSession(
      book: book ?? this.book,
      currentPage: currentPage ?? this.currentPage,
      fontSize: fontSize ?? this.fontSize,
      appearancePreset: appearancePreset ?? this.appearancePreset,
      layoutMode: layoutMode ?? this.layoutMode,
    );
  }
}
