import 'package:translate_reader/features/reader/domain/models/book_content.dart';

class ReadingSession {
  const ReadingSession({
    required this.book,
    required this.currentPage,
    required this.fontSize,
  });

  final BookContent book;
  final int currentPage;
  final double fontSize;

  ReadingSession copyWith({
    BookContent? book,
    int? currentPage,
    double? fontSize,
  }) {
    return ReadingSession(
      book: book ?? this.book,
      currentPage: currentPage ?? this.currentPage,
      fontSize: fontSize ?? this.fontSize,
    );
  }
}
