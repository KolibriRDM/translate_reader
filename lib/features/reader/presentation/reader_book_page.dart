import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  static const double _readerFramePadding = 12;
  static const double _navigationAreaHeight = 64;
  static const double _navigationTopSpacing = 8;
  static const Duration _tapMaxDuration = Duration(milliseconds: 250);
  static const double _tapMaxDistance = 12;

  final TranslatorService _translatorService = TranslatorService();
  final BookTextFormatter _formatter = BookTextFormatter();
  final BookPaginator _paginator = BookPaginator();

  late final PageController _pageController;
  late final ScrollController _verticalScrollController;
  late final String _bookText;
  late double _fontSize;
  late ReaderAppearancePreset _appearancePreset;
  late ReaderLayoutMode _layoutMode;

  List<PageSpan> _pages = const [];
  int _currentPage = 0;
  bool _isTranslationSheetOpen = false;
  bool _needsRepagination = true;
  Size _lastLayoutSize = Size.zero;
  double _verticalItemExtent = 0;
  String? _selectedText;
  _TapTranslationState? _tapTranslationState;
  int _tapTranslationRequestId = 0;
  final Map<String, String> _translationCache = <String, String>{};
  int? _activePointer;
  Offset? _pointerDownPosition;
  Duration? _pointerDownTimestamp;
  bool _pointerMovedTooFar = false;

  @override
  void initState() {
    super.initState();

    final ReadingSession? session = widget.sessionStore.session;
    _fontSize = _resolveInitialFontSize(session);
    _appearancePreset = _resolveInitialAppearancePreset(session);
    _layoutMode = _resolveInitialLayoutMode(session);
    _currentPage = session?.currentPage ?? 0;

    // Форматируем текст сразу при загрузке
    _bookText = _formatter.format(widget.book.text);

    _pageController = PageController(initialPage: _currentPage);
    _verticalScrollController = ScrollController();

    widget.sessionStore.updateFontSize(_fontSize);
    widget.sessionStore.updateAppearancePreset(_appearancePreset);
    widget.sessionStore.updateLayoutMode(_layoutMode);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  double _resolveInitialFontSize(ReadingSession? session) {
    if (session == null) {
      return 24;
    }

    return session.fontSize.clamp(_minFontSize, _maxFontSize).toDouble();
  }

  ReaderAppearancePreset _resolveInitialAppearancePreset(
    ReadingSession? session,
  ) {
    return session?.appearancePreset ?? ReaderAppearancePreset.paper;
  }

  ReaderLayoutMode _resolveInitialLayoutMode(ReadingSession? session) {
    return session?.layoutMode ?? ReaderLayoutMode.pagedHorizontal;
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
      _tapTranslationState = null;
    });

    widget.sessionStore.updateFontSize(_fontSize);
  }

  void _applyAppearancePreset(ReaderAppearancePreset preset) {
    if (_appearancePreset == preset) {
      return;
    }

    setState(() {
      _appearancePreset = preset;
      _tapTranslationState = null;
    });

    widget.sessionStore.updateAppearancePreset(preset);
  }

  void _applyLayoutMode(ReaderLayoutMode mode) {
    if (_layoutMode == mode) {
      return;
    }

    setState(() {
      _layoutMode = mode;
      _needsRepagination = true;
      _tapTranslationState = null;
    });

    widget.sessionStore.updateLayoutMode(mode);
  }

  void _goToPage(int page) {
    if (page < 0 || page >= _pages.length) {
      return;
    }

    if (_layoutMode == ReaderLayoutMode.pagedHorizontal) {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
      return;
    }

    if (!_verticalScrollController.hasClients || _verticalItemExtent <= 0) {
      return;
    }

    final double targetOffset = (page * _verticalItemExtent).clamp(
      0,
      _verticalScrollController.position.maxScrollExtent,
    );
    _verticalScrollController.animateTo(
      targetOffset,
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
    _tapTranslationState = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      if (_layoutMode == ReaderLayoutMode.pagedHorizontal &&
          _pageController.hasClients) {
        _pageController.jumpToPage(_currentPage);
      } else if (_layoutMode == ReaderLayoutMode.scrollVertical) {
        _restoreVerticalScrollPosition();
      }

      widget.sessionStore.updateCurrentPage(_currentPage);
    });
  }

  void _restoreVerticalScrollPosition() {
    if (!_verticalScrollController.hasClients || _verticalItemExtent <= 0) {
      return;
    }

    final double targetOffset = (_currentPage * _verticalItemExtent).clamp(
      0,
      _verticalScrollController.position.maxScrollExtent,
    );
    final double currentOffset = _verticalScrollController.offset;

    if ((currentOffset - targetOffset).abs() < 1) {
      return;
    }

    _verticalScrollController.jumpTo(targetOffset);
  }

  void _handleCurrentPageChanged(int page) {
    if (page == _currentPage && _tapTranslationState == null) {
      return;
    }

    setState(() {
      _currentPage = page;
      _tapTranslationState = null;
    });
    _tapTranslationRequestId += 1;
    widget.sessionStore.updateCurrentPage(page);
  }

  bool _handleVerticalScrollNotification({
    required ScrollNotification notification,
    required int pageCount,
  }) {
    if (notification.metrics.axis != Axis.vertical ||
        _verticalItemExtent <= 0 ||
        pageCount <= 0) {
      return false;
    }

    final int page = (notification.metrics.pixels / _verticalItemExtent)
        .round()
        .clamp(0, pageCount - 1);
    _handleCurrentPageChanged(page);
    return false;
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

  _WordHit? _extractWordAt(String text, int index) {
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

    int startInclusive = pointer;
    while (startInclusive > 0 && _isWordChar(text[startInclusive - 1])) {
      startInclusive -= 1;
    }

    int endInclusive = pointer;
    while (endInclusive + 1 < text.length &&
        _isWordChar(text[endInclusive + 1])) {
      endInclusive += 1;
    }

    while (startInclusive <= endInclusive &&
        (text[startInclusive] == '-' || text[startInclusive] == '\'')) {
      startInclusive += 1;
    }
    while (endInclusive >= startInclusive &&
        (text[endInclusive] == '-' || text[endInclusive] == '\'')) {
      endInclusive -= 1;
    }

    if (startInclusive > endInclusive) {
      return null;
    }

    final String word = text.substring(startInclusive, endInclusive + 1);
    if (word.isEmpty) {
      return null;
    }

    return _WordHit(word: word, start: startInclusive, end: endInclusive + 1);
  }

  Future<void> _onTextTap({
    required int pageIndex,
    required String pageText,
    required Offset localOffset,
    required double maxWidth,
    required double maxHeight,
    required TextStyle textStyle,
    required TextDirection textDirection,
    required TextScaler textScaler,
  }) async {
    if (localOffset.dx < 0 || localOffset.dx > maxWidth || localOffset.dy < 0) {
      _clearTapTranslation();
      return;
    }

    final TextPainter painter = _buildTextPainter(
      pageText: pageText,
      textStyle: textStyle,
      textDirection: textDirection,
      textScaler: textScaler,
    );
    painter.layout(maxWidth: maxWidth);

    if (localOffset.dy > painter.height) {
      _clearTapTranslation();
      return;
    }

    final TextPosition position = painter.getPositionForOffset(localOffset);
    final _WordHit? wordHit = _extractWordAt(pageText, position.offset);
    if (wordHit == null || wordHit.word.trim().isEmpty) {
      _clearTapTranslation();
      return;
    }

    final List<TextBox> boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: wordHit.start, extentOffset: wordHit.end),
    );
    if (boxes.isEmpty) {
      _clearTapTranslation();
      return;
    }

    final List<Rect> highlightRects = boxes
        .map(
          (TextBox box) => Rect.fromLTRB(
            box.left - 2,
            box.top - 2,
            box.right + 2,
            box.bottom + 2,
          ),
        )
        .toList(growable: false);
    final Rect firstRect = highlightRects.first;
    final Offset popupAnchor = Offset(
      (firstRect.left + firstRect.right) / 2,
      firstRect.top,
    );
    final int requestId = ++_tapTranslationRequestId;
    final String cacheKey = wordHit.word.toLowerCase();
    final String? cachedTranslation = _translationCache[cacheKey];

    setState(() {
      _tapTranslationState = _TapTranslationState(
        pageIndex: pageIndex,
        word: wordHit.word,
        highlightRects: highlightRects,
        popupAnchor: popupAnchor,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        translation: cachedTranslation,
        isLoading: cachedTranslation == null,
      );
    });

    if (cachedTranslation != null) {
      return;
    }

    final String translation = await _translatorService
        .translateText(wordHit.word)
        .then((String value) => value.isEmpty ? 'Перевод пустой.' : value)
        .catchError(
          (_) => 'Не удалось выполнить перевод. Проверьте подключение к сети.',
        );

    if (!mounted || requestId != _tapTranslationRequestId) {
      return;
    }

    _translationCache[cacheKey] = translation;
    setState(() {
      final _TapTranslationState? currentState = _tapTranslationState;
      if (currentState == null ||
          currentState.pageIndex != pageIndex ||
          currentState.word != wordHit.word) {
        return;
      }

      _tapTranslationState = currentState.copyWith(
        translation: translation,
        isLoading: false,
      );
    });
  }

  TextPainter _buildTextPainter({
    required String pageText,
    required TextStyle textStyle,
    required TextDirection textDirection,
    required TextScaler textScaler,
  }) {
    return TextPainter(
      text: TextSpan(text: pageText, style: textStyle),
      textDirection: textDirection,
      textScaler: textScaler,
    );
  }

  void _clearTapTranslation() {
    _tapTranslationRequestId += 1;
    if (_tapTranslationState == null || !mounted) {
      return;
    }

    setState(() {
      _tapTranslationState = null;
    });
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointer = event.pointer;
    _pointerDownPosition = event.localPosition;
    _pointerDownTimestamp = event.timeStamp;
    _pointerMovedTooFar = false;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_activePointer != event.pointer || _pointerDownPosition == null) {
      return;
    }

    if ((event.localPosition - _pointerDownPosition!).distance >
        _tapMaxDistance) {
      _pointerMovedTooFar = true;
    }
  }

  void _resetPointerTracking() {
    _activePointer = null;
    _pointerDownPosition = null;
    _pointerDownTimestamp = null;
    _pointerMovedTooFar = false;
  }

  Future<void> _handlePointerUp({
    required PointerUpEvent event,
    required int pageIndex,
    required String pageText,
    required double maxWidth,
    required double maxHeight,
    required TextStyle textStyle,
    required TextDirection textDirection,
    required TextScaler textScaler,
  }) async {
    if (_activePointer != event.pointer || _pointerDownPosition == null) {
      _resetPointerTracking();
      return;
    }

    final Duration elapsed =
        event.timeStamp - (_pointerDownTimestamp ?? Duration.zero);
    final bool shouldHandleTap =
        !_pointerMovedTooFar && elapsed <= _tapMaxDuration;
    final Offset localPosition = event.localPosition;

    _resetPointerTracking();

    if (!shouldHandleTap) {
      return;
    }

    await _onTextTap(
      pageIndex: pageIndex,
      pageText: pageText,
      localOffset: localPosition,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      textStyle: textStyle,
      textDirection: textDirection,
      textScaler: textScaler,
    );
  }

  void _handleSelectionChanged(SelectedContent? selectedContent) {
    final String normalizedSelection = selectedContent == null
        ? ''
        : selectedContent.plainText.replaceAll(RegExp(r'\s+'), ' ').trim();

    _selectedText = normalizedSelection.isEmpty ? null : normalizedSelection;
    if (_selectedText != null && _tapTranslationState != null) {
      _clearTapTranslation();
    }
  }

  Widget _buildSelectionContextMenu(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    final List<ContextMenuButtonItem> buttonItems =
        List<ContextMenuButtonItem>.of(
          selectableRegionState.contextMenuButtonItems,
        );
    final String? selectedText = _selectedText;

    if (selectedText != null) {
      final ContextMenuButtonItem translateButton = ContextMenuButtonItem(
        label: 'Перевести',
        onPressed: () {
          selectableRegionState.hideToolbar();
          selectableRegionState.clearSelection();
          _selectedText = null;
          unawaited(_translateAndShow(sourceText: selectedText));
        },
      );
      final int copyIndex = buttonItems.indexWhere(
        (ContextMenuButtonItem item) => item.type == ContextMenuButtonType.copy,
      );

      if (copyIndex >= 0) {
        buttonItems.insert(copyIndex, translateButton);
      } else {
        buttonItems.add(translateButton);
      }
    }

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: selectableRegionState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  List<Widget> _buildTapTranslationOverlay({
    required BuildContext context,
    required _TapTranslationState state,
  }) {
    final _ReaderAppearance appearance = _appearanceFor(_appearancePreset);
    const double popupMaxWidth = 240;
    const double horizontalPadding = 8;
    const double verticalPadding = 8;

    final double popupWidth = state.maxWidth < popupMaxWidth
        ? (state.maxWidth - (horizontalPadding * 2)).clamp(120, popupMaxWidth)
        : popupMaxWidth;
    final double left = (state.popupAnchor.dx - (popupWidth / 2)).clamp(
      horizontalPadding,
      state.maxWidth - popupWidth - horizontalPadding,
    );
    final double preferredTop = state.popupAnchor.dy - 86;
    final double fallbackTop = state.highlightRects.last.bottom + 10;
    final double top =
        (preferredTop >= verticalPadding ? preferredTop : fallbackTop).clamp(
          verticalPadding,
          state.maxHeight - 72,
        );

    return <Widget>[
      for (final Rect rect in state.highlightRects)
        Positioned(
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: appearance.accentColor.withValues(alpha: 0.12),
                border: Border.all(color: appearance.accentColor, width: 1.4),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      Positioned(
        left: left,
        top: top,
        width: popupWidth,
        child: IgnorePointer(
          child: Material(
            elevation: 10,
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: appearance.chromeColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: appearance.borderColor),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    state.word,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: appearance.textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.isLoading
                        ? 'Перевод...'
                        : (state.translation ??
                              'Не удалось выполнить перевод.'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: appearance.textColor.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
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
            appearance: _appearanceFor(_appearancePreset),
          );
        },
      );
    } finally {
      _isTranslationSheetOpen = false;
    }
  }

  Future<void> _showAppearancePicker() async {
    final ReaderAppearancePreset? selectedPreset =
        await showModalBottomSheet<ReaderAppearancePreset>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (BuildContext sheetContext) {
            return _ReaderAppearanceSheet(
              selectedPreset: _appearancePreset,
              options: ReaderAppearancePreset.values
                  .map(_appearanceFor)
                  .toList(growable: false),
            );
          },
        );

    if (selectedPreset == null || !mounted) {
      return;
    }

    _applyAppearancePreset(selectedPreset);
  }

  Future<void> _showLayoutModePicker() async {
    final ReaderLayoutMode? selectedMode =
        await showModalBottomSheet<ReaderLayoutMode>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (BuildContext sheetContext) {
            return _ReaderLayoutModeSheet(
              selectedMode: _layoutMode,
              appearance: _appearanceFor(_appearancePreset),
            );
          },
        );

    if (selectedMode == null || !mounted) {
      return;
    }

    _applyLayoutMode(selectedMode);
  }

  Widget _buildReaderPage({
    required BuildContext context,
    required int index,
    required double textWidth,
    required double textHeight,
    required TextStyle textStyle,
    required TextDirection textDirection,
    required TextScaler textScaler,
    required _ReaderAppearance appearance,
  }) {
    final String pageText = _pages.isEmpty
        ? 'Текст книги пуст.'
        : _pages[index].read(_bookText);

    return Padding(
      padding: const EdgeInsets.all(_readerFramePadding),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: appearance.pageColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: appearance.borderColor),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SizedBox.expand(
          child: Padding(
            padding: const EdgeInsets.all(_pagePadding),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _handlePointerDown,
                  onPointerMove: _handlePointerMove,
                  onPointerCancel: (_) => _resetPointerTracking(),
                  onPointerUp: (PointerUpEvent event) {
                    _handlePointerUp(
                      event: event,
                      pageIndex: index,
                      pageText: pageText,
                      maxWidth: textWidth,
                      maxHeight: textHeight,
                      textStyle: textStyle,
                      textDirection: textDirection,
                      textScaler: textScaler,
                    );
                  },
                  child: SelectionArea(
                    onSelectionChanged: _handleSelectionChanged,
                    contextMenuBuilder: _buildSelectionContextMenu,
                    child: ClipRect(
                      child: SizedBox.expand(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Builder(
                            builder: (BuildContext context) {
                              return RichText(
                                text: TextSpan(text: pageText, style: textStyle),
                                textDirection: textDirection,
                                textScaler: textScaler,
                                selectionRegistrar:
                                    SelectionContainer.maybeOf(context),
                                selectionColor: appearance.accentColor
                                    .withValues(alpha: 0.28),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_tapTranslationState?.pageIndex == index)
                  ..._buildTapTranslationOverlay(
                    context: context,
                    state: _tapTranslationState!,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalProgressBadge({
    required _ReaderAppearance appearance,
    required int pageCount,
  }) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: appearance.chromeColor.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: appearance.borderColor),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            '${_currentPage + 1} / $pageCount',
            style: TextStyle(
              color: appearance.textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation({
    required _ReaderAppearance appearance,
    required int pageCount,
  }) {
    return SizedBox(
      height: _navigationAreaHeight,
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: _currentPage > 0
                ? () => _goToPage(_currentPage - 1)
                : null,
            color: appearance.textColor,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Center(
              child: Text(
                '${_currentPage + 1} / $pageCount',
                style: TextStyle(
                  color: appearance.textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _currentPage < pageCount - 1
                ? () => _goToPage(_currentPage + 1)
                : null,
            color: appearance.textColor,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextDirection textDirection = Directionality.of(context);
    final TextScaler textScaler = MediaQuery.textScalerOf(context);
    final _ReaderAppearance appearance = _appearanceFor(_appearancePreset);

    return Scaffold(
      backgroundColor: appearance.scaffoldColor,
      appBar: AppBar(
        backgroundColor: appearance.scaffoldColor,
        foregroundColor: appearance.textColor,
        surfaceTintColor: Colors.transparent,
        title: Text(widget.book.fileName),
        actions: <Widget>[
          IconButton(
            onPressed: _showLayoutModePicker,
            tooltip: 'Режим чтения',
            icon: Icon(_layoutModeIcon(_layoutMode)),
          ),
          IconButton(
            onPressed: _showAppearancePicker,
            tooltip: 'Цвет фона',
            icon: const Icon(Icons.palette_outlined),
          ),
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
          final double textWidth =
              constraints.maxWidth -
              (_readerFramePadding * 2) -
              (_pagePadding * 2);
          final double textHeight =
              constraints.maxHeight -
              (_readerFramePadding * 2) -
              (_pagePadding * 2) -
              (_layoutMode == ReaderLayoutMode.pagedHorizontal
                  ? _navigationAreaHeight + _navigationTopSpacing
                  : 0);
          final Size layoutSize = Size(textWidth, textHeight);
          _verticalItemExtent =
              textHeight + (_pagePadding * 2) + (_readerFramePadding * 2);
          final TextStyle textStyle = TextStyle(
            fontSize: _fontSize,
            height: 1.55,
            color: appearance.textColor,
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
              return Center(
                child: CircularProgressIndicator(color: appearance.accentColor),
              );
            }
          }

          final int pageCount = _pages.isEmpty ? 1 : _pages.length;

          if (_layoutMode == ReaderLayoutMode.scrollVertical) {
            return Stack(
              children: <Widget>[
                NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification notification) {
                    return _handleVerticalScrollNotification(
                      notification: notification,
                      pageCount: pageCount,
                    );
                  },
                  child: ListView.builder(
                    controller: _verticalScrollController,
                    itemCount: pageCount,
                    itemExtent: _verticalItemExtent,
                    itemBuilder: (BuildContext context, int index) {
                      return _buildReaderPage(
                        context: context,
                        index: index,
                        textWidth: textWidth,
                        textHeight: textHeight,
                        textStyle: textStyle,
                        textDirection: textDirection,
                        textScaler: textScaler,
                        appearance: appearance,
                      );
                    },
                  ),
                ),
                Positioned(
                  right: _readerFramePadding + _pagePadding,
                  bottom: _readerFramePadding + _pagePadding,
                  child: _buildVerticalProgressBadge(
                    appearance: appearance,
                    pageCount: pageCount,
                  ),
                ),
              ],
            );
          }

          return Stack(
            children: <Widget>[
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.horizontal,
                itemCount: pageCount,
                onPageChanged: _handleCurrentPageChanged,
                itemBuilder: (BuildContext context, int index) {
                  return _buildReaderPage(
                    context: context,
                    index: index,
                    textWidth: textWidth,
                    textHeight: textHeight,
                    textStyle: textStyle,
                    textDirection: textDirection,
                    textScaler: textScaler,
                    appearance: appearance,
                  );
                },
              ),
              Positioned(
                left: _readerFramePadding + _pagePadding,
                right: _readerFramePadding + _pagePadding,
                bottom: _readerFramePadding + _pagePadding,
                child: _buildBottomNavigation(
                  appearance: appearance,
                  pageCount: pageCount,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WordHit {
  const _WordHit({required this.word, required this.start, required this.end});

  final String word;
  final int start;
  final int end;
}

class _TapTranslationState {
  const _TapTranslationState({
    required this.pageIndex,
    required this.word,
    required this.highlightRects,
    required this.popupAnchor,
    required this.maxWidth,
    required this.maxHeight,
    required this.translation,
    required this.isLoading,
  });

  final int pageIndex;
  final String word;
  final List<Rect> highlightRects;
  final Offset popupAnchor;
  final double maxWidth;
  final double maxHeight;
  final String? translation;
  final bool isLoading;

  _TapTranslationState copyWith({String? translation, bool? isLoading}) {
    return _TapTranslationState(
      pageIndex: pageIndex,
      word: word,
      highlightRects: highlightRects,
      popupAnchor: popupAnchor,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      translation: translation ?? this.translation,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class _TranslationSheet extends StatelessWidget {
  const _TranslationSheet({
    required this.sourceText,
    required this.translationFuture,
    required this.appearance,
  });

  final String sourceText;
  final Future<String> translationFuture;
  final _ReaderAppearance appearance;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[appearance.pageColor, appearance.chromeColor],
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
                    color: appearance.borderColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Перевод слова',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: appearance.textColor),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: appearance.scaffoldColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: appearance.borderColor),
                ),
                child: Text(
                  sourceText,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: appearance.textColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<String>(
                future: translationFuture,
                builder:
                    (BuildContext context, AsyncSnapshot<String> snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return Row(
                          children: <Widget>[
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: appearance.accentColor,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Перевожу...',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: appearance.textColor),
                            ),
                          ],
                        );
                      }

                      return Text(
                        snapshot.data ?? 'Не удалось выполнить перевод.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: appearance.textColor,
                        ),
                      );
                    },
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Закрыть',
                  style: TextStyle(color: appearance.accentColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReaderLayoutModeSheet extends StatelessWidget {
  const _ReaderLayoutModeSheet({
    required this.selectedMode,
    required this.appearance,
  });

  final ReaderLayoutMode selectedMode;
  final _ReaderAppearance appearance;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: appearance.pageColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: appearance.borderColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Режим чтения',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: appearance.textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Можно листать страницы горизонтально или читать книгу вертикальным скроллом.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: appearance.textColor.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 18),
              ...ReaderLayoutMode.values.map((ReaderLayoutMode mode) {
                final bool isSelected = mode == selectedMode;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(mode),
                    borderRadius: BorderRadius.circular(18),
                    child: Ink(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: appearance.chromeColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? appearance.accentColor
                              : appearance.borderColor,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: appearance.pageColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: appearance.borderColor),
                            ),
                            child: Icon(
                              _layoutModeIcon(mode),
                              color: appearance.textColor,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  mode.label,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium?.copyWith(
                                    color: appearance.textColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _layoutModeDescription(mode),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
                                    color: appearance.textColor.withValues(
                                      alpha: 0.72,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: isSelected
                                ? appearance.accentColor
                                : appearance.borderColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReaderAppearanceSheet extends StatelessWidget {
  const _ReaderAppearanceSheet({
    required this.selectedPreset,
    required this.options,
  });

  final ReaderAppearancePreset selectedPreset;
  final List<_ReaderAppearance> options;

  @override
  Widget build(BuildContext context) {
    final _ReaderAppearance activeAppearance = _appearanceFor(selectedPreset);

    return Container(
      decoration: BoxDecoration(
        color: activeAppearance.pageColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: activeAppearance.borderColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Оформление чтения',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: activeAppearance.textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Выберите фон и контраст текста прямо для читалки.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: activeAppearance.textColor.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: options
                      .map((option) {
                        return _ReaderAppearanceCard(
                          appearance: option,
                          isSelected: option.preset == selectedPreset,
                          onTap: () => Navigator.of(context).pop(option.preset),
                        );
                      })
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderAppearanceCard extends StatelessWidget {
  const _ReaderAppearanceCard({
    required this.appearance,
    required this.isSelected,
    required this.onTap,
  });

  final _ReaderAppearance appearance;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        width: 156,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: appearance.chromeColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? appearance.accentColor : appearance.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              height: 74,
              decoration: BoxDecoration(
                color: appearance.pageColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: appearance.borderColor),
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 6,
                    decoration: BoxDecoration(
                      color: appearance.textColor.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 4,
                    decoration: BoxDecoration(
                      color: appearance.textColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 88,
                    height: 4,
                    decoration: BoxDecoration(
                      color: appearance.textColor.withValues(alpha: 0.32),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              appearance.label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: appearance.textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              appearance.description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: appearance.textColor.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderAppearance {
  const _ReaderAppearance({
    required this.preset,
    required this.label,
    required this.description,
    required this.scaffoldColor,
    required this.pageColor,
    required this.chromeColor,
    required this.textColor,
    required this.borderColor,
    required this.accentColor,
  });

  final ReaderAppearancePreset preset;
  final String label;
  final String description;
  final Color scaffoldColor;
  final Color pageColor;
  final Color chromeColor;
  final Color textColor;
  final Color borderColor;
  final Color accentColor;
}

IconData _layoutModeIcon(ReaderLayoutMode mode) {
  switch (mode) {
    case ReaderLayoutMode.pagedHorizontal:
      return Icons.menu_book_outlined;
    case ReaderLayoutMode.scrollVertical:
      return Icons.view_agenda_outlined;
  }
}

String _layoutModeDescription(ReaderLayoutMode mode) {
  switch (mode) {
    case ReaderLayoutMode.pagedHorizontal:
      return 'Классическое перелистывание страниц по горизонтали.';
    case ReaderLayoutMode.scrollVertical:
      return 'Непрерывное чтение с вертикальной прокруткой вниз.';
  }
}

_ReaderAppearance _appearanceFor(ReaderAppearancePreset preset) {
  switch (preset) {
    case ReaderAppearancePreset.paper:
      return const _ReaderAppearance(
        preset: ReaderAppearancePreset.paper,
        label: 'Молочный',
        description: 'Мягкий светлый фон без резкого белого.',
        scaffoldColor: Color(0xFFF2ECE1),
        pageColor: Color(0xFFFBF7EF),
        chromeColor: Color(0xFFE8DDCC),
        textColor: Color(0xFF2A241E),
        borderColor: Color(0xFFD3C5B0),
        accentColor: Color(0xFF9C6D47),
      );
    case ReaderAppearancePreset.mist:
      return const _ReaderAppearance(
        preset: ReaderAppearancePreset.mist,
        label: 'Серый',
        description: 'Нейтральный холодный серый для долгого чтения.',
        scaffoldColor: Color(0xFFE6EAED),
        pageColor: Color(0xFFF4F6F7),
        chromeColor: Color(0xFFD8E0E4),
        textColor: Color(0xFF29343A),
        borderColor: Color(0xFFBFCBD1),
        accentColor: Color(0xFF607987),
      );
    case ReaderAppearancePreset.sepia:
      return const _ReaderAppearance(
        preset: ReaderAppearancePreset.sepia,
        label: 'Сепия',
        description: 'Тёплый бумажный оттенок без яркой желтизны.',
        scaffoldColor: Color(0xFFF0E5D4),
        pageColor: Color(0xFFF8F1E4),
        chromeColor: Color(0xFFE5D4BC),
        textColor: Color(0xFF4A3926),
        borderColor: Color(0xFFD2BA97),
        accentColor: Color(0xFFA26C39),
      );
    case ReaderAppearancePreset.sage:
      return const _ReaderAppearance(
        preset: ReaderAppearancePreset.sage,
        label: 'Шалфей',
        description: 'Спокойный зелёно-серый фон с мягким контрастом.',
        scaffoldColor: Color(0xFFE1E7DE),
        pageColor: Color(0xFFF0F4EC),
        chromeColor: Color(0xFFD4DDD0),
        textColor: Color(0xFF273028),
        borderColor: Color(0xFFBBC7B8),
        accentColor: Color(0xFF667D69),
      );
    case ReaderAppearancePreset.graphite:
      return const _ReaderAppearance(
        preset: ReaderAppearancePreset.graphite,
        label: 'Графит',
        description: 'Тёмно-серый фон с мягким светлым текстом.',
        scaffoldColor: Color(0xFF202427),
        pageColor: Color(0xFF2A2F33),
        chromeColor: Color(0xFF343B40),
        textColor: Color(0xFFE8E8E2),
        borderColor: Color(0xFF4C575E),
        accentColor: Color(0xFF8CA7B2),
      );
    case ReaderAppearancePreset.night:
      return const _ReaderAppearance(
        preset: ReaderAppearancePreset.night,
        label: 'Ночь',
        description: 'Белый на чёрном для чтения в темноте.',
        scaffoldColor: Color(0xFF0D0F12),
        pageColor: Color(0xFF14171B),
        chromeColor: Color(0xFF1D2329),
        textColor: Color(0xFFF4F5F7),
        borderColor: Color(0xFF313942),
        accentColor: Color(0xFFA4B9CA),
      );
  }
}
