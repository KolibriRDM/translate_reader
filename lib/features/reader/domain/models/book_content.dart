import 'package:translate_reader/core/models/book_format.dart';

class BookContent {
  const BookContent({
    required this.fileName,
    required this.filePath,
    required this.format,
    required this.text,
  });

  final String fileName;
  final String? filePath;
  final BookFormat format;
  final String text;
}

class BookLoadResult {
  const BookLoadResult({this.book, this.message, this.isCancelled = false});

  final BookContent? book;
  final String? message;
  final bool isCancelled;
}
