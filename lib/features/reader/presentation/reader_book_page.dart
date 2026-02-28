import 'package:flutter/material.dart';
import 'package:translate_reader/features/reader/application/reading_session_store.dart';
import 'package:translate_reader/features/reader/domain/models/book_content.dart';
import 'package:translate_reader/features/reader/domain/models/reading_session.dart';
import 'package:translate_reader/features/translation/application/translator_service.dart';

class ReaderBookPage extends StatefulWidget {
  const ReaderBookPage({
    required this.book,
    required this.sessionStore,
    super.key,
  });

  final BookContent book;
  final ReadingSessionStore sessionStore;

  @override
  State<ReaderBookPage> createState() => _ReaderBookPageState();
}

class _ReaderBookPageState extends State<ReaderBookPage> {
  static const double _minFontSize = 18;
  static const double _maxFontSize = 32;
  static const double _pagePadding = 16;
  static const double _navigationAreaHeight = 64;
  static const double _pageHeightSafetyMargin = 8;

  final TranslatorService _translatorService = TranslatorService();

  late final PageController _pageController;
  late final String _bookText;
  late double _fontSize;

  List<_PageSlice> _pages = const [];
  int _currentPage = 0;
  bool _isTranslationSheetOpen = false;
  bool _needsRepagination = true;
  Size _lastLayoutSize = Size.zero;

  @override
  void initState() {
    super.initState();

    final ReadingSession? session = widget.sessionStore.session;
    _fontSize = _resolveInitialFontSize(session);
    _currentPage = session?.currentPage ?? 0;
    _bookText = widget.book.text;
    _pageController = PageController(initialPage: _currentPage);

    widget.sessionStore.updateFontSize(_fontSize);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  double _resolveInitialFontSize(ReadingSession? session) {
    if (session == null) {
      return 24;
    }

    return session.fontSize.clamp(_minFontSize, _maxFontSize).toDouble();
  }

  void _changeFontSize(double delta) {
    final double newFontSize = (_fontSize + delta)
        .clamp(_minFontSize, _maxFontSize)
        .toDouble();
    if (newFontSize == _fontSize) {
      return;
    }

    setState(() {
      _fontSize = newFontSize;
      _needsRepagination = true;
    });

    widget.sessionStore.updateFontSize(_fontSize);
  }

  void _goToPage(int page) {
    if (page < 0 || page >= _pages.length) {
      return;
    }

    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  int _estimateCharsPerPage({
    required double width,
    required double height,
    required TextStyle style,
    required TextScaler textScaler,
  }) {
    final double fontSize = textScaler.scale(style.fontSize ?? 24);
    final double lineHeight = fontSize * (style.height ?? 1.0);
    final int estimatedLines = (height / lineHeight).floor().clamp(4, 200);
    final int estimatedCharsPerLine = (width / (fontSize * 0.58))
        .floor()
        .clamp(12, 120);
    return (estimatedLines * estimatedCharsPerLine).clamp(300, 5000);
  }

  bool _fitsPage({
    required String text,
    required int start,
    required int length,
    required double width,
    required double height,
    required TextStyle style,
    required TextDirection textDirection,
    required TextScaler textScaler,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text.substring(start, start + length),
        style: style,
      ),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout(maxWidth: width);

    return painter.height <= height - _pageHeightSafetyMargin;
  }

  int _adjustSplitToWordBoundary({
    required String text,
    required int start,
    required int length,
  }) {
    if (start + length >= text.length) {
      return text.length - start;
    }

    int split = length.clamp(1, text.length - start);
    final int minSplit = (split * 0.7).floor();
    while (split > minSplit) {
      final String char = text[start + split - 1];
      if (char == ' ' || char == '\n' || char == '\t') {
        break;
      }
      split -= 1;
    }

    return split == 0 ? length : split;
  }

  int _skipLeadingWhitespace(String text, int start) {
    int index = start;
    while (index < text.length) {
      final String char = text[index];
      if (char != ' ' && char != '\n' && char != '\t') {
        break;
      }
      index += 1;
    }
    return index;
  }

  List<_PageSlice> _paginateByLayout({
    required String text,
    required double width,
    required double height,
    required TextStyle style,
    required TextDirection textDirection,
    required TextScaler textScaler,
  }) {
    if (text.isEmpty) {
      return const <_PageSlice>[];
    }

    final List<_PageSlice> pages = <_PageSlice>[];
    final int estimatedLength = _estimateCharsPerPage(
      width: width,
      height: height,
      style: style,
      textScaler: textScaler,
    );
    int start = 0;

    while (start < text.length) {
      final int remainingLength = text.length - start;
      if (remainingLength <= estimatedLength) {
        pages.add(_PageSlice(start: start, end: text.length));
        break;
      }

      int low = 1;
      int high = estimatedLength.clamp(1, remainingLength);

      if (_fitsPage(
        text: text,
        start: start,
        length: high,
        width: width,
        height: height,
        style: style,
        textDirection: textDirection,
        textScaler: textScaler,
      )) {
        low = high;
        while (high < remainingLength) {
          final int next = (high * 2).clamp(high + 1, remainingLength);
          if (!_fitsPage(
            text: text,
            start: start,
            length: next,
            width: width,
            height: height,
            style: style,
            textDirection: textDirection,
            textScaler: textScaler,
          )) {
            high = next;
            break;
          }
          low = next;
          high = next;
        }

        if (high == remainingLength && low == remainingLength) {
          pages.add(_PageSlice(start: start, end: text.length));
          break;
        }
      } else {
        while (low < high) {
          final int mid = low + ((high - low) ~/ 2);
          if (_fitsPage(
            text: text,
            start: start,
            length: mid,
            width: width,
            height: height,
            style: style,
            textDirection: textDirection,
            textScaler: textScaler,
          )) {
            low = mid + 1;
          } else {
            high = mid;
          }
        }

        final int minimalLength = (low - 1).clamp(1, remainingLength);
        final int splitLength = _adjustSplitToWordBoundary(
          text: text,
          start: start,
          length: minimalLength,
        );
        pages.add(_PageSlice(start: start, end: start + splitLength));
        start = _skipLeadingWhitespace(text, start + splitLength);
        continue;
      }

      while (high - low > 1) {
        final int mid = low + ((high - low) ~/ 2);
        if (_fitsPage(
          text: text,
          start: start,
          length: mid,
          width: width,
          height: height,
          style: style,
          textDirection: textDirection,
          textScaler: textScaler,
        )) {
          low = mid;
        } else {
          high = mid;
        }
      }

      final int splitLength = _adjustSplitToWordBoundary(
        text: text,
        start: start,
        length: low,
      );
      pages.add(_PageSlice(start: start, end: start + splitLength));
      start = _skipLeadingWhitespace(text, start + splitLength);
    }

    return pages;
  }

  void _repaginate({
    required double width,
    required double height,
    required TextStyle style,
    required TextDirection textDirection,
    required TextScaler textScaler,
  }) {
    final int oldPageCount = _pages.length;
    final double progress = oldPageCount <= 1
        ? 0.0
        : _currentPage / (oldPageCount - 1);

    _pages = _paginateByLayout(
      text: _bookText,
      width: width,
      height: height,
      style: style,
      textDirection: textDirection,
      textScaler: textScaler,
    );
    _lastLayoutSize = Size(width, height);
    _needsRepagination = false;

    final int newPage = _pages.length <= 1
        ? 0
        : (((_pages.length - 1) * progress).round()).clamp(0, _pages.length - 1);

    if (_currentPage != newPage || oldPageCount == 0) {
      _currentPage = newPage;
      widget.sessionStore.updateCurrentPage(_currentPage);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_currentPage);
        }
      });
    }
  }

  bool _isWordChar(String char) {
    if (char.isEmpty) {
      return false;
    }

    final int code = char.codeUnitAt(0);
    final bool isDigit = code >= 48 && code <= 57;
    final bool isLatinUpper = code >= 65 && code <= 90;
    final bool isLatinLower = code >= 97 && code <= 122;
    final bool isCyrillicBasic = code >= 0x0410 && code <= 0x044F;
    final bool isYo = code == 0x0401 || code == 0x0451;

    return isDigit ||
        isLatinUpper ||
        isLatinLower ||
        isCyrillicBasic ||
        isYo ||
        char == '-' ||
        char == '\'';
  }

  String? _extractWordAt(String text, int index) {
    if (text.isEmpty) {
      return null;
    }

    int pointer = index.clamp(0, text.length - 1).toInt();
    if (!_isWordChar(text[pointer])) {
      if (pointer > 0 && _isWordChar(text[pointer - 1])) {
        pointer -= 1;
      } else if (pointer + 1 < text.length && _isWordChar(text[pointer + 1])) {
        pointer += 1;
      } else {
        return null;
      }
    }

    int start = pointer;
    while (start > 0 && _isWordChar(text[start - 1])) {
      start -= 1;
    }

    int end = pointer;
    while (end + 1 < text.length && _isWordChar(text[end + 1])) {
      end += 1;
    }

    String word = text.substring(start, end + 1);
    word = word.replaceAll(RegExp(r"^[-']+"), '');
    word = word.replaceAll(RegExp(r"[-']+$"), '');

    if (word.isEmpty) {
      return null;
    }

    return word;
  }

  Future<void> _onTextTap({
    required String pageText,
    required Offset localOffset,
    required double maxWidth,
    required TextStyle textStyle,
    required TextDirection textDirection,
    required TextScaler textScaler,
  }) async {
    if (localOffset.dx < 0 || localOffset.dx > maxWidth || localOffset.dy < 0) {
      return;
    }

    final TextPainter painter = TextPainter(
      text: TextSpan(text: pageText, style: textStyle),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout(maxWidth: maxWidth);

    if (localOffset.dy > painter.height) {
      return;
    }

    final TextPosition position = painter.getPositionForOffset(localOffset);
    final String? word = _extractWordAt(pageText, position.offset);
    if (word == null || word.trim().isEmpty) {
      return;
    }

    await _translateAndShow(sourceText: word);
  }

  Future<void> _translateAndShow({required String sourceText}) async {
    if (_isTranslationSheetOpen || !mounted) {
      return;
    }

    _isTranslationSheetOpen = true;
    final Future<String> translationFuture = _translatorService
        .translateText(sourceText)
        .then((String value) => value.isEmpty ? 'Перевод пустой.' : value)
        .catchError(
          (_) => 'Не удалось выполнить перевод. Проверьте подключение к сети.',
        );

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext sheetContext) {
          return _TranslationSheet(
            sourceText: sourceText,
            translationFuture: translationFuture,
          );
        },
      );
    } finally {
      _isTranslationSheetOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextDirection textDirection = Directionality.of(context);
    final TextScaler textScaler = MediaQuery.textScalerOf(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.fileName),
        actions: <Widget>[
          IconButton(
            onPressed: () => _changeFontSize(-2),
            tooltip: 'Уменьшить шрифт',
            icon: const Icon(Icons.text_decrease),
          ),
          IconButton(
            onPressed: () => _changeFontSize(2),
            tooltip: 'Увеличить шрифт',
            icon: const Icon(Icons.text_increase),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double textWidth = constraints.maxWidth - (_pagePadding * 2);
          final double textHeight = constraints.maxHeight -
              (_pagePadding * 2) -
              _navigationAreaHeight;
          final Size layoutSize = Size(textWidth, textHeight);
          final TextStyle textStyle = TextStyle(
            fontSize: _fontSize,
            height: 1.55,
          );

          if (_needsRepagination || _lastLayoutSize != layoutSize) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }

              setState(() {
                _repaginate(
                  width: textWidth,
                  height: textHeight,
                  style: textStyle,
                  textDirection: textDirection,
                  textScaler: textScaler,
                );
              });
            });

            if (_pages.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
          }

          final int pageCount = _pages.isEmpty ? 1 : _pages.length;

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.horizontal,
            itemCount: pageCount,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
              widget.sessionStore.updateCurrentPage(page);
            },
            itemBuilder: (BuildContext context, int index) {
              final String pageText = _pages.isEmpty
                  ? 'Текст книги пуст.'
                  : _pages[index].read(_bookText);

              return Padding(
                padding: const EdgeInsets.all(_pagePadding),
                child: Column(
                  children: <Widget>[
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (TapUpDetails details) {
                          _onTextTap(
                            pageText: pageText,
                            localOffset: details.localPosition,
                            maxWidth: textWidth,
                            textStyle: textStyle,
                            textDirection: textDirection,
                            textScaler: textScaler,
                          );
                        },
                        child: ClipRect(
                          child: SizedBox.expand(
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Text(
                                pageText,
                                style: textStyle,
                                textDirection: textDirection,
                                textScaler: textScaler,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: _navigationAreaHeight,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        child: Row(
                          children: <Widget>[
                            IconButton(
                              onPressed: _currentPage > 0
                                  ? () => _goToPage(_currentPage - 1)
                                  : null,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  'Страница ${_currentPage + 1} / $pageCount',
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _currentPage < pageCount - 1
                                  ? () => _goToPage(_currentPage + 1)
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _TranslationSheet extends StatelessWidget {
  const _TranslationSheet({
    required this.sourceText,
    required this.translationFuture,
  });

  final String sourceText;
  final Future<String> translationFuture;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerHigh,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Перевод слова',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  sourceText,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<String>(
                future: translationFuture,
                builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Row(
                      children: <Widget>[
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Перевожу...',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                    );
                  }

                  return Text(
                    snapshot.data ?? 'Не удалось выполнить перевод.',
                    style: theme.textTheme.bodyLarge,
                  );
                },
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageSlice {
  const _PageSlice({
    required this.start,
    required this.end,
  });

  final int start;
  final int end;

  String read(String source) {
    return source.substring(start, end);
  }
}
