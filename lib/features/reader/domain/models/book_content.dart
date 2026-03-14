import 'package:translate_reader/core/models/book_format.dart';

enum BookBlockType { paragraph, heading, epigraph, cite }

enum BookInlineStyle { emphasis, strong }

class BookInlineSpan {
  const BookInlineSpan({
    required this.start,
    required this.end,
    required this.style,
  });

  final int start;
  final int end;
  final BookInlineStyle style;
}

class BookBlock {
  const BookBlock({
    required this.text,
    this.type = BookBlockType.paragraph,
    this.level = 0,
    this.inlineSpans = const <BookInlineSpan>[],
  });

  final String text;
  final BookBlockType type;
  final int level;
  final List<BookInlineSpan> inlineSpans;

  bool get isHeading => type == BookBlockType.heading;
}

class BookTocEntry {
  const BookTocEntry({
    required this.title,
    required this.level,
    required this.targetBlockIndex,
  });

  final String title;
  final int level;
  final int targetBlockIndex;
}

class BookContent {
  const BookContent({
    required this.fileName,
    required this.filePath,
    required this.format,
    required this.blocks,
    this.tocEntries = const <BookTocEntry>[],
  });

  final String fileName;
  final String? filePath;
  final BookFormat format;
  final List<BookBlock> blocks;
  final List<BookTocEntry> tocEntries;
}

class FormattedBookContent {
  const FormattedBookContent({
    required this.text,
    required this.blocks,
    required this.tocEntries,
  });

  final String text;
  final List<FormattedBookBlock> blocks;
  final List<FormattedBookTocEntry> tocEntries;
}

class FormattedBookBlock {
  const FormattedBookBlock({
    required this.text,
    required this.start,
    required this.end,
    required this.type,
    required this.level,
    this.inlineSpans = const <BookInlineSpan>[],
  });

  final String text;
  final int start;
  final int end;
  final BookBlockType type;
  final int level;
  final List<BookInlineSpan> inlineSpans;

  bool get isHeading => type == BookBlockType.heading;
}

class FormattedBookTocEntry {
  const FormattedBookTocEntry({
    required this.title,
    required this.level,
    required this.textOffset,
  });

  final String title;
  final int level;
  final int textOffset;
}

class BookLoadResult {
  const BookLoadResult({this.book, this.message, this.isCancelled = false});

  final BookContent? book;
  final String? message;
  final bool isCancelled;
}
