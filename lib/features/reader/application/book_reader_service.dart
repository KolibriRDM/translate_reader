import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:epubx/epubx.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:translate_reader/core/models/book_format.dart';
import 'package:translate_reader/features/reader/domain/models/book_content.dart';
import 'package:xml/xml.dart' as xml;

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
      final _StoredBookFile storedFile = await _storePickedBook(file);
      return _loadBook(
        fileName: storedFile.fileName,
        filePath: storedFile.filePath,
        format: format,
        loadBook: () => _readBookContentFromFile(File(storedFile.filePath), format),
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
        loadBook: () => _readBookContentFromFile(file, format),
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
    required Future<_ParsedBookData> Function() loadBook,
  }) async {
    final _ParsedBookData parsedBook = await loadBook();
    if (parsedBook.blocks.isEmpty) {
      return const BookLoadResult(
        message: 'В выбранной книге не найден текст.',
      );
    }

    return BookLoadResult(
      book: BookContent(
        fileName: fileName,
        filePath: filePath,
        format: format,
        blocks: parsedBook.blocks,
        tocEntries: parsedBook.tocEntries,
      ),
    );
  }

  Future<_ParsedBookData> _readBookContentFromFile(
    File file,
    BookFormat format,
  ) async {
    if (format == BookFormat.txt) {
      final String rawText = utf8.decode(
        await file.readAsBytes(),
        allowMalformed: true,
      );
      return _parseTxtDocument(rawText);
    }

    if (format == BookFormat.fb2) {
      final String xmlContent = utf8.decode(
        await file.readAsBytes(),
        allowMalformed: true,
      );
      return _parseFb2Document(xmlContent);
    }

    return _buildEpubBook(await file.readAsBytes());
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

  Future<_StoredBookFile> _storePickedBook(PlatformFile file) async {
    final Directory booksDirectory = await _bookStorageDirectory();
    final String extension = p.extension(file.name).toLowerCase();
    final String safeBaseName = _sanitizeFileName(
      p.basenameWithoutExtension(file.name),
    );
    final String? sourcePath = file.path;

    if (sourcePath != null) {
      final File sourceFile = File(sourcePath);
      final FileStat stat = await sourceFile.stat();
      if (stat.type == FileSystemEntityType.notFound) {
        throw const FileSystemException('Picked file is not available.');
      }

      final String fingerprint = _stableStringHash(
        '$sourcePath|${stat.size}|${stat.modified.millisecondsSinceEpoch}',
      );
      final File storedFile = File(
        p.join(booksDirectory.path, '${safeBaseName}_$fingerprint$extension'),
      );

      if (!await storedFile.exists()) {
        await sourceFile.copy(storedFile.path);
      }

      return _StoredBookFile(fileName: file.name, filePath: storedFile.path);
    }

    final List<int>? bytes = await _readFileBytes(file);
    if (bytes == null) {
      throw const FileSystemException('Picked file has no readable bytes.');
    }

    final String fingerprint = _stableBytesHash(bytes);
    final File storedFile = File(
      p.join(booksDirectory.path, '${safeBaseName}_$fingerprint$extension'),
    );

    if (!await storedFile.exists()) {
      await storedFile.writeAsBytes(bytes, flush: true);
    }

    return _StoredBookFile(fileName: file.name, filePath: storedFile.path);
  }

  Future<Directory> _bookStorageDirectory() async {
    final Directory appDirectory = await getApplicationDocumentsDirectory();
    final Directory booksDirectory = Directory(
      p.join(appDirectory.path, 'books'),
    );
    if (!await booksDirectory.exists()) {
      await booksDirectory.create(recursive: true);
    }
    return booksDirectory;
  }

  String _sanitizeFileName(String value) {
    final String sanitized = value
        .replaceAll(RegExp(r'[^\w\s-]+'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    return sanitized.isEmpty ? 'book' : sanitized;
  }

  String _stableStringHash(String value) {
    return _stableBytesHash(utf8.encode(value));
  }

  String _stableBytesHash(List<int> bytes) {
    var hash = 0x811C9DC5;
    for (final int byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  Future<_ParsedBookData> _buildEpubBook(List<int> bytes) async {
    final EpubBook book = await EpubReader.readBook(bytes);
    final List<BookBlock> blocks = <BookBlock>[];
    final List<BookTocEntry> tocEntries = <BookTocEntry>[];

    _appendEpubChapterBlocks(
      chapters: book.Chapters,
      blocks: blocks,
      tocEntries: tocEntries,
      depth: 1,
    );

    if (blocks.isNotEmpty) {
      return _ParsedBookData(blocks: blocks, tocEntries: tocEntries);
    }

    final htmlMap = book.Content?.Html;
    if (htmlMap == null || htmlMap.isEmpty) {
      return const _ParsedBookData();
    }

    for (final MapEntry<String, EpubTextContentFile> entry in htmlMap.entries) {
      final String? html = entry.value.Content;
      if (html == null || html.trim().isEmpty) {
        continue;
      }

      _appendParsedBlocks(
        _extractHtmlBlocks(html, baseLevel: 1),
        blocks: blocks,
        tocEntries: tocEntries,
      );
    }

    return _ParsedBookData(blocks: blocks, tocEntries: tocEntries);
  }

  void _appendEpubChapterBlocks({
    required List<EpubChapter>? chapters,
    required List<BookBlock> blocks,
    required List<BookTocEntry> tocEntries,
    required int depth,
  }) {
    if (chapters == null || chapters.isEmpty) {
      return;
    }

    for (final EpubChapter chapter in chapters) {
      final String chapterTitle = _normalizeBlockText(chapter.Title ?? '');

      final List<BookBlock> chapterBlocks = _extractHtmlBlocks(
        chapter.HtmlContent ?? '',
        baseLevel: depth,
      );

      // Убираем дублирующиеся заголовки из начала главы
      _removeLeadingDuplicateHeadings(chapterBlocks, chapterTitle);

      if (chapterTitle.isNotEmpty &&
          (chapterBlocks.isEmpty ||
              !chapterBlocks.first.isHeading ||
              !_sameNormalizedText(chapterBlocks.first.text, chapterTitle))) {
        _addBookBlock(
          blocks: blocks,
          tocEntries: tocEntries,
          text: chapterTitle,
          type: BookBlockType.heading,
          level: depth,
        );
      }

      _appendParsedBlocks(
        chapterBlocks,
        blocks: blocks,
        tocEntries: tocEntries,
      );

      _appendEpubChapterBlocks(
        chapters: chapter.SubChapters,
        blocks: blocks,
        tocEntries: tocEntries,
        depth: depth + 1,
      );
    }
  }

  _ParsedBookData _parseTxtDocument(String rawText) {
    final String normalizedText = _normalizeNewlines(rawText).trim();
    if (normalizedText.isEmpty) {
      return const _ParsedBookData();
    }

    final List<BookBlock> blocks = <BookBlock>[];
    final List<BookTocEntry> tocEntries = <BookTocEntry>[];
    final List<String> chunks = normalizedText
        .split(RegExp(r'\n\s*\n+'))
        .map((String chunk) => chunk.trim())
        .where((String chunk) => chunk.isNotEmpty)
        .toList(growable: false);

    for (final String chunk in chunks) {
      final List<String> lines = chunk
          .split('\n')
          .map(_normalizeBlockText)
          .where((String line) => line.isNotEmpty)
          .toList(growable: false);
      if (lines.isEmpty) {
        continue;
      }

      final String text = lines.join(' ');
      final bool isHeading = _looksLikeTxtHeading(lines, text);
      _addBookBlock(
        blocks: blocks,
        tocEntries: tocEntries,
        text: text,
        type: isHeading ? BookBlockType.heading : BookBlockType.paragraph,
        level: isHeading ? 1 : 0,
      );
    }

    if (blocks.isEmpty) {
      _addBookBlock(
        blocks: blocks,
        tocEntries: tocEntries,
        text: normalizedText,
      );
    }

    return _ParsedBookData(blocks: blocks, tocEntries: tocEntries);
  }

  _ParsedBookData _parseFb2Document(String xmlContent) {
    if (xmlContent.trim().isEmpty) {
      return const _ParsedBookData();
    }

    final List<BookBlock> blocks = <BookBlock>[];
    final List<BookTocEntry> tocEntries = <BookTocEntry>[];

    try {
      final xml.XmlDocument document = xml.XmlDocument.parse(xmlContent);
      final Iterable<xml.XmlElement> bodies = document.descendants
          .whereType<xml.XmlElement>()
          .where((xml.XmlElement element) => _xmlName(element) == 'body');

      for (final xml.XmlElement body in bodies) {
        for (final xml.XmlElement child
            in body.children.whereType<xml.XmlElement>()) {
          _appendFb2BlocksFromElement(
            child,
            blocks: blocks,
            tocEntries: tocEntries,
            depth: 0,
          );
        }
      }
    } catch (_) {
      return _parseTxtDocument(_stripMarkup(xmlContent));
    }

    if (blocks.isEmpty) {
      _addBookBlock(
        blocks: blocks,
        tocEntries: tocEntries,
        text: _stripMarkup(xmlContent),
      );
    }

    return _ParsedBookData(blocks: blocks, tocEntries: tocEntries);
  }

  void _appendFb2BlocksFromElement(
    xml.XmlElement element, {
    required List<BookBlock> blocks,
    required List<BookTocEntry> tocEntries,
    required int depth,
    BookBlockType? parentBlockType,
  }) {
    final String name = _xmlName(element);
    switch (name) {
      case 'section':
        for (final xml.XmlElement child
            in element.children.whereType<xml.XmlElement>()) {
          _appendFb2BlocksFromElement(
            child,
            blocks: blocks,
            tocEntries: tocEntries,
            depth: depth + 1,
            parentBlockType: parentBlockType,
          );
        }
        return;
      case 'title':
        final String titleText = _fb2TitleText(element);
        _addBookBlock(
          blocks: blocks,
          tocEntries: tocEntries,
          text: titleText,
          type: BookBlockType.heading,
          level: math.max(1, depth),
        );
        return;
      case 'subtitle':
        _addBookBlock(
          blocks: blocks,
          tocEntries: tocEntries,
          text: element.innerText,
          type: BookBlockType.heading,
          level: math.max(1, depth + 1),
        );
        return;
      case 'p':
      case 'v':
      case 'text-author':
        final _InlineExtraction extraction = _extractInlineContent(element);
        final String text = _normalizeBlockText(extraction.text);
        if (text.isEmpty) return;
        _addBookBlock(
          blocks: blocks,
          tocEntries: tocEntries,
          text: text,
          type: parentBlockType ?? BookBlockType.paragraph,
          inlineSpans: _remapInlineSpans(extraction, text),
        );
        return;
      case 'epigraph':
        for (final xml.XmlElement child
            in element.children.whereType<xml.XmlElement>()) {
          _appendFb2BlocksFromElement(
            child,
            blocks: blocks,
            tocEntries: tocEntries,
            depth: depth,
            parentBlockType: BookBlockType.epigraph,
          );
        }
        return;
      case 'cite':
        for (final xml.XmlElement child
            in element.children.whereType<xml.XmlElement>()) {
          _appendFb2BlocksFromElement(
            child,
            blocks: blocks,
            tocEntries: tocEntries,
            depth: depth,
            parentBlockType: BookBlockType.cite,
          );
        }
        return;
      case 'poem':
      case 'stanza':
        for (final xml.XmlElement child
            in element.children.whereType<xml.XmlElement>()) {
          _appendFb2BlocksFromElement(
            child,
            blocks: blocks,
            tocEntries: tocEntries,
            depth: depth,
            parentBlockType: parentBlockType,
          );
        }
        return;
      default:
        for (final xml.XmlElement child
            in element.children.whereType<xml.XmlElement>()) {
          _appendFb2BlocksFromElement(
            child,
            blocks: blocks,
            tocEntries: tocEntries,
            depth: depth,
            parentBlockType: parentBlockType,
          );
        }
    }
  }

  String _fb2TitleText(xml.XmlElement element) {
    final List<String> lines = element.descendants
        .whereType<xml.XmlElement>()
        .where((xml.XmlElement child) => _xmlName(child) == 'p')
        .map(
          (xml.XmlElement paragraph) =>
              _normalizeBlockText(paragraph.innerText),
        )
        .where((String text) => text.isNotEmpty)
        .toList(growable: false);

    if (lines.isNotEmpty) {
      return lines.join(' ');
    }

    return element.innerText;
  }

  List<BookBlock> _extractHtmlBlocks(String html, {required int baseLevel}) {
    if (html.trim().isEmpty) {
      return const <BookBlock>[];
    }

    final List<BookBlock> blocks = <BookBlock>[];
    final xml.XmlElement? root = _parseMarkupRoot(html);
    if (root != null) {
      _appendHtmlBlocksFromElement(root, blocks: blocks, baseLevel: baseLevel);
    }

    if (blocks.isNotEmpty) {
      return blocks;
    }

    final String fallbackText = _stripMarkup(html);
    if (fallbackText.isEmpty) {
      return const <BookBlock>[];
    }

    return <BookBlock>[BookBlock(text: fallbackText)];
  }

  void _appendHtmlBlocksFromElement(
    xml.XmlElement element, {
    required List<BookBlock> blocks,
    required int baseLevel,
  }) {
    final String name = _xmlName(element);
    if (name == 'head' ||
        name == 'script' ||
        name == 'style') {
      return;
    }

    if (_isHtmlHeadingTag(name)) {
      final _InlineExtraction extraction = _extractInlineContent(element);
      final String text = _normalizeBlockText(extraction.text);
      if (text.isEmpty) {
        return;
      }

      blocks.add(
        BookBlock(
          text: text,
          type: BookBlockType.heading,
          level: math.max(baseLevel, _htmlHeadingLevel(name)),
          inlineSpans: _remapInlineSpans(extraction, text),
        ),
      );
      return;
    }

    if (name == 'blockquote') {
      final _InlineExtraction extraction = _extractInlineContent(element);
      final String text = _normalizeBlockText(extraction.text);
      if (text.isEmpty) {
        return;
      }

      blocks.add(
        BookBlock(
          text: text,
          type: BookBlockType.cite,
          inlineSpans: _remapInlineSpans(extraction, text),
        ),
      );
      return;
    }

    if (name == 'table') {
      _appendHtmlTableBlocks(element, blocks: blocks);
      return;
    }

    if (_isHtmlParagraphTag(name)) {
      final _InlineExtraction extraction = _extractInlineContent(element);
      final String text = _normalizeBlockText(extraction.text);
      if (text.isEmpty) {
        return;
      }

      blocks.add(
        BookBlock(
          text: text,
          inlineSpans: _remapInlineSpans(extraction, text),
        ),
      );
      return;
    }

    if (_isHtmlContainerTag(name) && !_hasRecognizedHtmlBlockChild(element)) {
      final _InlineExtraction extraction = _extractInlineContent(element);
      final String text = _normalizeBlockText(extraction.text);
      if (text.isNotEmpty) {
        blocks.add(
          BookBlock(
            text: text,
            inlineSpans: _remapInlineSpans(extraction, text),
          ),
        );
      }
      return;
    }

    for (final xml.XmlElement child
        in element.children.whereType<xml.XmlElement>()) {
      _appendHtmlBlocksFromElement(child, blocks: blocks, baseLevel: baseLevel);
    }
  }

  void _appendHtmlTableBlocks(
    xml.XmlElement tableElement, {
    required List<BookBlock> blocks,
  }) {
    final Iterable<xml.XmlElement> rows = tableElement.descendants
        .whereType<xml.XmlElement>()
        .where((xml.XmlElement e) => _xmlName(e) == 'tr');

    for (final xml.XmlElement row in rows) {
      final List<String> cells = row.children
          .whereType<xml.XmlElement>()
          .where((xml.XmlElement e) {
            final String n = _xmlName(e);
            return n == 'td' || n == 'th';
          })
          .map((xml.XmlElement cell) => _normalizeBlockText(cell.innerText))
          .where((String text) => text.isNotEmpty)
          .toList(growable: false);
      if (cells.isEmpty) {
        continue;
      }

      blocks.add(BookBlock(text: cells.join('\t')));
    }
  }

  bool _hasRecognizedHtmlBlockChild(xml.XmlElement element) {
    for (final xml.XmlElement child
        in element.children.whereType<xml.XmlElement>()) {
      final String name = _xmlName(child);
      if (_isHtmlHeadingTag(name) ||
          _isHtmlParagraphTag(name) ||
          _isHtmlContainerTag(name) ||
          name == 'table' ||
          name == 'blockquote') {
        return true;
      }
    }

    return false;
  }

  bool _isHtmlHeadingTag(String name) {
    return name == 'h1' ||
        name == 'h2' ||
        name == 'h3' ||
        name == 'h4' ||
        name == 'h5' ||
        name == 'h6';
  }

  bool _isHtmlParagraphTag(String name) {
    return name == 'p' ||
        name == 'li' ||
        name == 'pre' ||
        name == 'dt' ||
        name == 'dd';
  }

  bool _isHtmlContainerTag(String name) {
    return name == 'html' ||
        name == 'body' ||
        name == 'main' ||
        name == 'article' ||
        name == 'section' ||
        name == 'div';
  }

  int _htmlHeadingLevel(String name) {
    return int.tryParse(name.substring(1)) ?? 1;
  }

  void _appendParsedBlocks(
    List<BookBlock> parsedBlocks, {
    required List<BookBlock> blocks,
    required List<BookTocEntry> tocEntries,
  }) {
    for (final BookBlock block in parsedBlocks) {
      _addBookBlock(
        blocks: blocks,
        tocEntries: tocEntries,
        text: block.text,
        type: block.type,
        level: block.level,
        inlineSpans: block.inlineSpans,
      );
    }
  }

  void _addBookBlock({
    required List<BookBlock> blocks,
    required List<BookTocEntry> tocEntries,
    required String text,
    BookBlockType type = BookBlockType.paragraph,
    int level = 0,
    List<BookInlineSpan> inlineSpans = const <BookInlineSpan>[],
  }) {
    final String normalizedText = _normalizeBlockText(text);
    if (normalizedText.isEmpty) {
      return;
    }

    final BookBlock block = BookBlock(
      text: normalizedText,
      type: type,
      level: type == BookBlockType.heading ? _clampHeadingLevel(level) : 0,
      inlineSpans: inlineSpans,
    );
    final int blockIndex = blocks.length;
    blocks.add(block);

    if (block.isHeading) {
      tocEntries.add(
        BookTocEntry(
          title: block.text,
          level: block.level,
          targetBlockIndex: blockIndex,
        ),
      );
    }
  }

  int _clampHeadingLevel(int level) {
    return level.clamp(1, 6).toInt();
  }

  /// Удаляет из начала списка блоков заголовки, дублирующие название главы.
  void _removeLeadingDuplicateHeadings(
    List<BookBlock> blocks,
    String chapterTitle,
  ) {
    if (chapterTitle.isEmpty || blocks.isEmpty) return;
    // Ищем дубликат среди первых нескольких блоков
    for (int i = 0; i < blocks.length && i < 5; i++) {
      if (blocks[i].isHeading &&
          _sameNormalizedText(blocks[i].text, chapterTitle)) {
        blocks.removeAt(i);
        return;
      }
    }
  }



  bool _looksLikeTxtHeading(List<String> lines, String text) {
    if (lines.length > 3 || text.length < 2 || text.length > 96) {
      return false;
    }

    final List<String> words = text
        .split(RegExp(r'\s+'))
        .where((String word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty || words.length > 12) {
      return false;
    }

    if (RegExp(r'[.!?]').hasMatch(text)) {
      return false;
    }

    final String lower = text.toLowerCase();
    if (RegExp(
      r'^(chapter|глава|part|часть|section|раздел|book|книга|prologue|пролог|epilogue|эпилог)\b',
    ).hasMatch(lower)) {
      return true;
    }

    final int letterCount = _countLetters(text);
    if (letterCount > 0 &&
        _countUppercaseLetters(text) >= (letterCount * 0.7)) {
      return true;
    }

    return _isMostlyTitleCase(words);
  }

  bool _isMostlyTitleCase(List<String> words) {
    var checkedWords = 0;
    var titledWords = 0;

    for (final String word in words) {
      final String cleaned = word.replaceAll(
        RegExp(r'[^A-Za-zА-Яа-яЁё0-9-]'),
        '',
      );
      if (cleaned.isEmpty) {
        continue;
      }

      checkedWords += 1;
      final String firstChar = cleaned[0];
      if (_isUppercaseLetter(firstChar) || _isDigit(firstChar)) {
        titledWords += 1;
      }
    }

    return checkedWords > 0 && titledWords >= (checkedWords * 0.8).ceil();
  }

  int _countLetters(String text) {
    var count = 0;
    for (int index = 0; index < text.length; index += 1) {
      if (_isLetter(text[index])) {
        count += 1;
      }
    }
    return count;
  }

  int _countUppercaseLetters(String text) {
    var count = 0;
    for (int index = 0; index < text.length; index += 1) {
      if (_isUppercaseLetter(text[index])) {
        count += 1;
      }
    }
    return count;
  }

  bool _isLetter(String char) {
    return _isUppercaseLetter(char) || _isLowercaseLetter(char);
  }

  bool _isUppercaseLetter(String char) {
    final int code = char.codeUnitAt(0);
    return (code >= 65 && code <= 90) ||
        (code >= 0x0410 && code <= 0x042F) ||
        code == 0x0401;
  }

  bool _isLowercaseLetter(String char) {
    final int code = char.codeUnitAt(0);
    return (code >= 97 && code <= 122) ||
        (code >= 0x0430 && code <= 0x044F) ||
        code == 0x0451;
  }

  bool _isDigit(String char) {
    final int code = char.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }

  bool _sameNormalizedText(String left, String right) {
    return _normalizeComparableText(left) == _normalizeComparableText(right);
  }

  String _normalizeComparableText(String value) {
    return _normalizeBlockText(value).toLowerCase();
  }

  String _normalizeBlockText(String value) {
    return _normalizeNewlines(
      value,
    ).replaceAll(RegExp(r'[ \t]+'), ' ').replaceAll(RegExp(r'\n+'), ' ').trim();
  }

  String _normalizeNewlines(String value) {
    return value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }

  xml.XmlElement? _parseMarkupRoot(String markup) {
    final String sanitized = markup
        .replaceFirst(RegExp(r'^\s*<\?xml[^>]*\?>\s*'), '')
        .trim();
    if (sanitized.isEmpty) {
      return null;
    }

    try {
      return xml.XmlDocument.parse(sanitized).rootElement;
    } catch (_) {
      try {
        return xml.XmlDocument.parse('<root>$sanitized</root>').rootElement;
      } catch (_) {
        return null;
      }
    }
  }

  String _xmlName(xml.XmlElement element) {
    return element.name.local.toLowerCase();
  }

  String _stripMarkup(String value) {
    return value
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Извлекает текст и позиции inline-стилей (курсив, жирный) из XML-элемента.
  _InlineExtraction _extractInlineContent(xml.XmlElement element) {
    final StringBuffer buffer = StringBuffer();
    final List<BookInlineSpan> spans = <BookInlineSpan>[];
    _walkInlineNodes(
      element,
      buffer: buffer,
      spans: spans,
      activeStyles: const <BookInlineStyle>{},
    );
    return _InlineExtraction(text: buffer.toString(), spans: spans);
  }

  void _walkInlineNodes(
    xml.XmlNode node, {
    required StringBuffer buffer,
    required List<BookInlineSpan> spans,
    required Set<BookInlineStyle> activeStyles,
  }) {
    if (node is xml.XmlText) {
      buffer.write(node.value);
      return;
    }

    if (node is xml.XmlElement) {
      final String name = _xmlName(node);
      final BookInlineStyle? style = _inlineStyleForTag(name);

      if (style != null && !activeStyles.contains(style)) {
        final int start = buffer.length;
        final Set<BookInlineStyle> newActive = <BookInlineStyle>{
          ...activeStyles,
          style,
        };
        for (final xml.XmlNode child in node.children) {
          _walkInlineNodes(
            child,
            buffer: buffer,
            spans: spans,
            activeStyles: newActive,
          );
        }
        final int end = buffer.length;
        if (end > start) {
          spans.add(
            BookInlineSpan(start: start, end: end, style: style),
          );
        }
      } else {
        for (final xml.XmlNode child in node.children) {
          _walkInlineNodes(
            child,
            buffer: buffer,
            spans: spans,
            activeStyles: activeStyles,
          );
        }
      }
    }
  }

  BookInlineStyle? _inlineStyleForTag(String name) {
    switch (name) {
      case 'em':
      case 'i':
      case 'emphasis':
        return BookInlineStyle.emphasis;
      case 'strong':
      case 'b':
        return BookInlineStyle.strong;
      default:
        return null;
    }
  }

  /// Пересчитывает позиции inline-спанов после нормализации текста.
  List<BookInlineSpan> _remapInlineSpans(
    _InlineExtraction extraction,
    String normalizedText,
  ) {
    if (extraction.spans.isEmpty) {
      return const <BookInlineSpan>[];
    }

    final String rawText = extraction.text;
    // Строим карту: позиция в raw -> позиция в normalized.
    // Нормализация: \r\n->\n, \n->space, multi-space->single-space, trim.
    final List<int> rawToNorm = List<int>.filled(rawText.length + 1, -1);
    final String preNorm = rawText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'\n+'), ' ');

    int normPos = 0;
    bool lastWasSpace = true; // Для trim слева
    for (int i = 0; i < preNorm.length; i++) {
      final int rawIndex = i < rawText.length ? i : rawText.length;
      final String ch = preNorm[i];
      if (ch == ' ' || ch == '\t') {
        if (!lastWasSpace) {
          rawToNorm[rawIndex] = normPos;
          normPos++;
          lastWasSpace = true;
        } else {
          rawToNorm[rawIndex] = normPos;
        }
      } else {
        rawToNorm[rawIndex] = normPos;
        normPos++;
        lastWasSpace = false;
      }
    }
    rawToNorm[rawText.length] = normalizedText.length;

    final List<BookInlineSpan> result = <BookInlineSpan>[];
    for (final BookInlineSpan span in extraction.spans) {
      final int clampedStart = span.start.clamp(0, rawText.length);
      final int clampedEnd = span.end.clamp(0, rawText.length);
      final int newStart = rawToNorm[clampedStart];
      int newEnd = rawToNorm[clampedEnd];
      if (newStart < 0 || newEnd < 0 || newStart >= newEnd) {
        continue;
      }
      // Ограничиваем нормализованным текстом
      if (newEnd > normalizedText.length) {
        newEnd = normalizedText.length;
      }
      if (newStart >= newEnd) continue;
      result.add(
        BookInlineSpan(start: newStart, end: newEnd, style: span.style),
      );
    }

    return result;
  }
}

class _InlineExtraction {
  const _InlineExtraction({
    required this.text,
    this.spans = const <BookInlineSpan>[],
  });

  final String text;
  final List<BookInlineSpan> spans;
}

class _ParsedBookData {
  const _ParsedBookData({
    this.blocks = const <BookBlock>[],
    this.tocEntries = const <BookTocEntry>[],
  });

  final List<BookBlock> blocks;
  final List<BookTocEntry> tocEntries;
}

class _StoredBookFile {
  const _StoredBookFile({required this.fileName, required this.filePath});

  final String fileName;
  final String filePath;
}
