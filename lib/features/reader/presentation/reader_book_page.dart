import 'package:flutter/material.dart';
import 'package:translate_reader/features/reader/application/reading_session_store.dart';
import 'package:translate_reader/features/reader/domain/book_pages_util.dart';
import 'package:translate_reader/features/reader/domain/book_text_formatter.dart';
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

  final TranslatorService _translatorService = TranslatorService();
  final BookTextFormatter _formatter = BookTextFormatter();
  final BookPaginator _paginator = BookPaginator();

  late final PageController _pageController;
  late final String _bookText;
  late double _fontSize;

  List<PageSpan> _pages = const [];
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

    // Форматируем текст сразу при загрузке
    _bookText = _formatter.format(widget.book.text);

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

  void _repaginate({
    required double width,
    required double height,
    required TextStyle style,
    required TextDirection textDirection,
    required TextScaler textScaler,
  }) {
    if (_pages.isNotEmpty) {
      // Сохраняем примерный прогресс
      final int oldTotal = _pages.length;
      final double progress = _currentPage / (oldTotal > 0 ? oldTotal : 1);

      _pages = _paginator.paginate(
        text: _bookText,
        style: style,
        textDirection: textDirection,
        textScaler: textScaler,
        pageSize: Size(width, height),
      );

      // Восстанавливаем страницу по прогрессу
      final int newTotal = _pages.length;
      _currentPage = (progress * newTotal).floor().clamp(
        0,
        newTotal > 0 ? newTotal - 1 : 0,
      );
    } else {
      _pages = _paginator.paginate(
        text: _bookText,
        style: style,
        textDirection: textDirection,
        textScaler: textScaler,
        pageSize: Size(width, height),
      );
      // Если страниц не было, остаемся на 0 или на сохраненной?
      // _currentPage уже инициализирован в initState
      if (_currentPage >= _pages.length) {
        _currentPage = 0;
      }
    }

    _lastLayoutSize = Size(width, height);
    _needsRepagination = false;

    // Обновляем UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        _pageController.jumpToPage(_currentPage);
      }
      widget.sessionStore.updateCurrentPage(_currentPage);
    });
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
    );
    
    painter.layout(maxWidth: maxWidth);

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
          final double textHeight =
              constraints.maxHeight -
              (_pagePadding * 2) -
              _navigationAreaHeight;
          final Size layoutSize = Size(textWidth, textHeight);
          final TextStyle textStyle = TextStyle(
            fontSize: _fontSize,
            height: 1.55,
            color: Theme.of(context).textTheme.bodyLarge?.color,
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
                              child: RichText(
                                text: TextSpan(
                                  text: pageText,
                                  style: textStyle,
                                ),
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
              Text('Перевод слова', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(sourceText, style: theme.textTheme.titleMedium),
              ),
              const SizedBox(height: 12),
              FutureBuilder<String>(
                future: translationFuture,
                builder:
                    (BuildContext context, AsyncSnapshot<String> snapshot) {
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
