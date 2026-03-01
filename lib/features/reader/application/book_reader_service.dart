import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:epubx/epubx.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:translate_reader/core/models/book_format.dart';
import 'package:translate_reader/features/reader/domain/models/book_content.dart';
import 'package:xml/xml_events.dart';

class BookReaderService {
  const BookReaderService();

  Future<BookLoadResult> pickAndLoadBook() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'fb2', 'epub'],
    );

    if (picked == null || picked.files.isEmpty) {
      return const BookLoadResult(
        isCancelled: true,
        message: 'Выбор файла отменён.',
      );
    }

    final file = picked.files.single;
    final format = BookFormat.fromPath(file.name);
    if (format == null) {
      return const BookLoadResult(message: 'Неподдерживаемый формат файла.');
    }

    try {
      return _loadBook(
        fileName: file.name,
        filePath: file.path,
        format: format,
        loadText: () => _readBookTextFromPlatformFile(file, format),
      );
    } catch (_) {
      return const BookLoadResult(
        message: 'Не удалось открыть выбранную книгу.',
      );
    }
  }

  Future<BookLoadResult> loadBookFromPath(String path) async {
    final File file = File(path);
    if (!await file.exists()) {
      return const BookLoadResult(
        message: 'Файл последней книги больше недоступен.',
      );
    }

    final String fileName = p.basename(path);
    final BookFormat? format = BookFormat.fromPath(fileName);
    if (format == null) {
      return const BookLoadResult(message: 'Неподдерживаемый формат файла.');
    }

    try {
      return _loadBook(
        fileName: fileName,
        filePath: path,
        format: format,
        loadText: () => _readBookTextFromFile(file, format),
      );
    } catch (_) {
      return const BookLoadResult(
        message: 'Не удалось открыть сохранённую книгу.',
      );
    }
  }

  Future<BookLoadResult> _loadBook({
    required String fileName,
    required String? filePath,
    required BookFormat format,
    required Future<String> Function() loadText,
  }) async {
    final String normalizedText = _normalizeText(await loadText());
    if (normalizedText.isEmpty) {
      return const BookLoadResult(
        message: 'В выбранной книге не найден текст.',
      );
    }

    return BookLoadResult(
      book: BookContent(
        fileName: fileName,
        filePath: filePath,
        format: format,
        text: normalizedText,
      ),
    );
  }

  Future<String> _readBookTextFromPlatformFile(
    PlatformFile file,
    BookFormat format,
  ) async {
    if (format == BookFormat.txt) {
      return _buildTxtText(file);
    }

    if (format == BookFormat.fb2) {
      return _buildFb2Text(file);
    }

    final List<int>? bytes = await _readFileBytes(file);
    if (bytes == null) {
      return '';
    }

    return _buildEpubText(bytes);
  }

  Future<String> _readBookTextFromFile(File file, BookFormat format) async {
    if (format == BookFormat.txt) {
      return utf8.decode(await file.readAsBytes(), allowMalformed: true);
    }

    if (format == BookFormat.fb2) {
      final StringBuffer buffer = StringBuffer();
      await _appendFb2TextFromStream(
        file.openRead().transform(const Utf8Decoder(allowMalformed: true)),
        buffer,
      );
      return buffer.toString();
    }

    return _buildEpubText(await file.readAsBytes());
  }

  Future<List<int>?> _readFileBytes(PlatformFile file) async {
    final path = file.path;
    if (path != null) {
      return File(path).readAsBytes();
    }

    if (file.bytes != null) {
      return file.bytes!;
    }

    final stream = file.readStream;
    if (stream == null) {
      return null;
    }

    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      builder.add(chunk);
    }

    return builder.takeBytes();
  }

  Future<String> _buildTxtText(PlatformFile file) async {
    final bytes = await _readFileBytes(file);
    if (bytes == null) {
      return '';
    }

    return utf8.decode(bytes, allowMalformed: true);
  }

  Future<String> _buildFb2Text(PlatformFile file) async {
    final buffer = StringBuffer();
    final path = file.path;

    if (path != null) {
      await _appendFb2TextFromStream(
        File(
          path,
        ).openRead().transform(const Utf8Decoder(allowMalformed: true)),
        buffer,
      );
      return buffer.toString();
    }

    final bytes = await _readFileBytes(file);
    if (bytes == null) {
      return '';
    }

    _appendFb2TextFromString(utf8.decode(bytes, allowMalformed: true), buffer);
    return buffer.toString();
  }

  Future<String> _buildEpubText(List<int> bytes) async {
    final book = await EpubReader.readBook(bytes);
    final chunks = <String>[];

    _appendChapterText(chapters: book.Chapters, chunks: chunks);

    if (chunks.isNotEmpty) {
      return chunks.join('\n\n');
    }

    final htmlMap = book.Content?.Html;
    if (htmlMap == null || htmlMap.isEmpty) {
      return '';
    }

    final fallbackChunks = <String>[];
    for (final entry in htmlMap.entries) {
      final fileName = entry.key.toLowerCase();
      final isNavigationFile =
          fileName.contains('toc') || fileName.contains('nav');
      if (isNavigationFile) {
        continue;
      }

      final html = entry.value.Content;
      if (html == null || html.trim().isEmpty) {
        continue;
      }

      final text = _stripMarkup(html);
      if (text.isNotEmpty) {
        fallbackChunks.add(text);
      }
    }

    return fallbackChunks.join('\n\n');
  }

  void _appendChapterText({
    required List<EpubChapter>? chapters,
    required List<String> chunks,
  }) {
    if (chapters == null || chapters.isEmpty) {
      return;
    }

    for (final chapter in chapters) {
      final html = chapter.HtmlContent;
      if (html != null && html.trim().isNotEmpty) {
        final text = _stripMarkup(html);
        if (text.isNotEmpty) {
          chunks.add(text);
        }
      }

      _appendChapterText(chapters: chapter.SubChapters, chunks: chunks);
    }
  }

  Future<void> _appendFb2TextFromStream(
    Stream<String> xmlStream,
    StringBuffer buffer,
  ) async {
    var bodyDepth = 0;
    var paragraphBreakPending = false;

    await xmlStream.toXmlEvents().normalizeEvents().forEachEvent(
      onStartElement: (XmlStartElementEvent event) {
        final name = event.name.toLowerCase();
        if (name == 'body') {
          bodyDepth += 1;
        }

        if (bodyDepth > 0 && _isFb2BlockElement(name) && buffer.isNotEmpty) {
          paragraphBreakPending = true;
        }
      },
      onText: (XmlTextEvent event) {
        if (bodyDepth == 0) {
          return;
        }

        final value = event.value.trim();
        if (value.isEmpty) {
          return;
        }

        if (paragraphBreakPending && buffer.isNotEmpty) {
          buffer.write('\n\n');
          paragraphBreakPending = false;
        } else if (buffer.isNotEmpty) {
          buffer.write(' ');
        }
        buffer.write(value);
      },
      onEndElement: (XmlEndElementEvent event) {
        if (event.name.toLowerCase() == 'body' && bodyDepth > 0) {
          bodyDepth -= 1;
        }
      },
    );
  }

  void _appendFb2TextFromString(String xmlContent, StringBuffer buffer) {
    var bodyDepth = 0;
    var paragraphBreakPending = false;

    for (final event in parseEvents(xmlContent)) {
      if (event is XmlStartElementEvent) {
        final name = event.name.toLowerCase();
        if (name == 'body') {
          bodyDepth += 1;
        }

        if (bodyDepth > 0 && _isFb2BlockElement(name) && buffer.isNotEmpty) {
          paragraphBreakPending = true;
        }
        continue;
      }

      if (event is XmlTextEvent) {
        if (bodyDepth == 0) {
          continue;
        }

        final value = event.value.trim();
        if (value.isEmpty) {
          continue;
        }

        if (paragraphBreakPending && buffer.isNotEmpty) {
          buffer.write('\n\n');
          paragraphBreakPending = false;
        } else if (buffer.isNotEmpty) {
          buffer.write(' ');
        }
        buffer.write(value);
        continue;
      }

      if (event is XmlEndElementEvent &&
          event.name.toLowerCase() == 'body' &&
          bodyDepth > 0) {
        bodyDepth -= 1;
      }
    }
  }

  bool _isFb2BlockElement(String name) {
    return name == 'title' ||
        name == 'subtitle' ||
        name == 'p' ||
        name == 'v' ||
        name == 'stanza' ||
        name == 'epigraph' ||
        name == 'cite' ||
        name == 'text-author';
  }

  String _stripMarkup(String value) {
    return value
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }

  String _normalizeText(String value) {
    final normalized = value
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    return normalized;
  }
}
