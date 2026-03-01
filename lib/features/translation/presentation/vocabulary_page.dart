import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:translate_reader/core/database/app_database.dart';
import 'package:translate_reader/features/translation/application/vocabulary_service.dart';

/// Русские названия месяцев (сокращённые — первые 3 буквы).
const List<String> _monthShort = <String>[
  'янв',
  'фев',
  'мар',
  'апр',
  'май',
  'июн',
  'июл',
  'авг',
  'сен',
  'окт',
  'ноя',
  'дек',
];

/// Алфавит для боковой линейки (латиница + кириллица).
const String _alphabet =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZАБВГДЕЖЗИКЛМНОПРСТУФХЦЧШЩЭЮЯ';

/// Цвета-акценты для аватарок букв.
const List<Color> _avatarColors = <Color>[
  Color(0xFF3F6E6A),
  Color(0xFFBF7A54),
  Color(0xFF7B8F5C),
  Color(0xFF607987),
  Color(0xFFA26C39),
  Color(0xFF667D69),
  Color(0xFF8CA7B2),
  Color(0xFF9C6D47),
];

/// Форматирует дату добавления слова.
String _formatDate(DateTime date) {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime entryDay = DateTime(date.year, date.month, date.day);
  final int diff = today.difference(entryDay).inDays;

  if (diff == 0) {
    return 'Сегодня';
  }
  if (diff == 1) {
    return 'Вчера';
  }
  if (date.year == now.year) {
    final String day = date.day.toString();
    final String month = _monthShort[date.month - 1];
    return '$day $month';
  }

  final String day = date.day.toString().padLeft(2, '0');
  final String month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

/// Экран словарика сохранённых слов.
class VocabularyPage extends StatefulWidget {
  const VocabularyPage({super.key});

  @override
  State<VocabularyPage> createState() => _VocabularyPageState();
}

class _VocabularyPageState extends State<VocabularyPage> {
  final VocabularyService _vocabularyService = VocabularyService.instance;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  String? _activeLetter;
  List<_ListItem> _currentItems = const [];
  bool _isScrollingToLetter = false;
  bool _isSearching = false;
  Timer? _searchTimer;

  /// Индекс найденного элемента для подсветки.
  int _highlightedIndex = -1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  /// Определяет текущую видимую букву по позиции скролла.
  void _onScroll() {
    if (_isScrollingToLetter || _currentItems.isEmpty) {
      return;
    }

    final double offset = _scrollController.offset;
    double accumulated = 0;
    String? visibleLetter;

    for (final _ListItem item in _currentItems) {
      final double height = item is _LetterHeaderItem ? 64 : 76;
      if (accumulated + height > offset) {
        if (item is _LetterHeaderItem) {
          visibleLetter = item.letter;
        }
        break;
      }
      if (item is _LetterHeaderItem) {
        visibleLetter = item.letter;
      }
      accumulated += height;
    }

    if (visibleLetter != null && visibleLetter != _activeLetter) {
      setState(() {
        _activeLetter = visibleLetter;
      });
    }
  }

  /// Прокручивает список к заголовку секции для заданной буквы.
  void _scrollToLetter(String letter) {
    if (_currentItems.isEmpty) {
      return;
    }

    final int targetIndex = _currentItems.indexWhere((_ListItem item) {
      return item is _LetterHeaderItem && item.letter == letter;
    });

    if (targetIndex == -1) {
      return;
    }

    setState(() {
      _activeLetter = letter;
      _isScrollingToLetter = true;
    });

    // Приблизительные высоты: заголовок ~64, карточка ~76.
    double offset = 0;
    for (int i = 0; i < targetIndex; i++) {
      offset += _currentItems[i] is _LetterHeaderItem ? 64 : 76;
    }
    final double maxOffset = _scrollController.position.maxScrollExtent;

    _scrollController
        .animateTo(
          offset.clamp(0, maxOffset),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        )
        .then((_) {
          _isScrollingToLetter = false;
        });
  }

  /// Собирает множество букв, на которые начинаются слова.
  Set<String> _availableLetters(List<VocabularyEntry> words) {
    final Set<String> letters = <String>{};
    for (final VocabularyEntry entry in words) {
      if (entry.word.isNotEmpty) {
        letters.add(entry.word[0].toUpperCase());
      }
    }
    return letters;
  }

  /// Обработчик ввода в поле поиска с дебаунсом 200 мс.
  void _onSearchChanged(String query) {
    _searchTimer?.cancel();
    if (query.isEmpty) {
      setState(() {
        _highlightedIndex = -1;
      });
      return;
    }
    _searchTimer = Timer(const Duration(milliseconds: 200), () {
      _scrollToSearchResult(query);
    });
  }

  /// Ищет слово, начинающееся с [query], и прокручивает к нему.
  void _scrollToSearchResult(String query) {
    final String lowerQuery = query.toLowerCase();
    int targetIndex = -1;

    for (int i = 0; i < _currentItems.length; i++) {
      final _ListItem item = _currentItems[i];
      if (item is _WordItem &&
          item.entry.word.toLowerCase().startsWith(lowerQuery)) {
        targetIndex = i;
        break;
      }
    }

    if (targetIndex == -1) {
      setState(() {
        _highlightedIndex = -1;
      });
      return;
    }

    setState(() {
      _highlightedIndex = targetIndex;
      _isScrollingToLetter = true;
    });

    double offset = 0;
    for (int i = 0; i < targetIndex; i++) {
      offset += _currentItems[i] is _LetterHeaderItem ? 64 : 76;
    }
    final double maxOffset = _scrollController.position.maxScrollExtent;

    _scrollController
        .animateTo(
          offset.clamp(0, maxOffset),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        )
        .then((_) {
          _isScrollingToLetter = false;
        });
  }

  /// Закрывает режим поиска.
  void _closeSearch() {
    _searchTimer?.cancel();
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _highlightedIndex = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        leading: _isSearching
            ? IconButton(
                onPressed: _closeSearch,
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onSearchChanged,
                style: theme.textTheme.titleMedium,
                decoration: InputDecoration(
                  hintText: 'Поиск слова…',
                  hintStyle: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  border: InputBorder.none,
                ),
              )
            : const Text('Мой словарик'),
        actions: <Widget>[
          if (!_isSearching)
            StreamBuilder<List<VocabularyEntry>>(
              stream: _vocabularyService.watchAllWords(),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<VocabularyEntry>> snapshot,
                  ) {
                    final int count = snapshot.data?.length ?? 0;
                    if (count == 0) {
                      return const SizedBox.shrink();
                    }

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _isSearching = true;
                            });
                          },
                          icon: SvgPicture.asset(
                            'assets/icons/search.svg',
                            width: 24,
                            height: 24,
                            colorFilter: ColorFilter.mode(
                              colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.8,
                              ),
                              BlendMode.srcIn,
                            ),
                          ),
                          tooltip: 'Поиск',
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$count',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
            ),
          if (_isSearching)
            IconButton(
              onPressed: _closeSearch,
              icon: SvgPicture.asset(
                'assets/icons/close.svg',
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                  BlendMode.srcIn,
                ),
              ),
              tooltip: 'Закрыть поиск',
            ),
        ],
      ),
      body: StreamBuilder<List<VocabularyEntry>>(
        stream: _vocabularyService.watchAllWords(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<VocabularyEntry>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return Center(
                  child: CircularProgressIndicator(color: colorScheme.primary),
                );
              }

              final List<VocabularyEntry> words = snapshot.data ?? const [];

              if (words.isEmpty) {
                return _buildEmptyState(context);
              }

              // Сортируем по алфавиту для навигации (основной стрим — по дате).
              final List<VocabularyEntry> sorted = List<VocabularyEntry>.of(
                words,
              );
              sorted.sort(
                (VocabularyEntry a, VocabularyEntry b) =>
                    a.word.toLowerCase().compareTo(b.word.toLowerCase()),
              );

              final Set<String> available = _availableLetters(sorted);

              // Строим плоский список с заголовками секций.
              final List<_ListItem> items = _buildGroupedItems(sorted);
              _currentItems = items;

              return Row(
                children: <Widget>[
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 4, 24),
                      itemCount: items.length,
                      itemBuilder: (BuildContext context, int index) {
                        final _ListItem item = items[index];
                        if (item is _LetterHeaderItem) {
                          return _LetterHeader(
                            letter: item.letter,
                            color: item.color,
                          );
                        }
                        final _WordItem wordItem = item as _WordItem;
                        return _VocabularyCard(
                          entry: wordItem.entry,
                          isHighlighted: index == _highlightedIndex,
                          onDelete: () => _deleteWord(wordItem.entry),
                        );
                      },
                    ),
                  ),
                  _DockAlphabetBar(
                    activeLetter: _activeLetter,
                    availableLetters: available,
                    onLetterTap: _scrollToLetter,
                  ),
                ],
              );
            },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                Icons.collections_bookmark_outlined,
                size: 36,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Словарик пуст',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Нажимайте на слова при чтении книги и сохраняйте их для запоминания.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Строит плоский список из заголовков букв и слов.
  List<_ListItem> _buildGroupedItems(List<VocabularyEntry> sorted) {
    final List<_ListItem> items = <_ListItem>[];
    String? currentLetter;

    for (final VocabularyEntry entry in sorted) {
      final String letter = entry.word.isNotEmpty
          ? entry.word[0].toUpperCase()
          : '?';

      if (letter != currentLetter) {
        currentLetter = letter;
        final Color color =
            _avatarColors[entry.word.isNotEmpty
                ? entry.word.codeUnitAt(0) % _avatarColors.length
                : 0];
        items.add(_LetterHeaderItem(letter: letter, color: color));
      }

      items.add(_WordItem(entry: entry));
    }

    return items;
  }

  Future<void> _deleteWord(VocabularyEntry entry) async {
    await _vocabularyService.removeWordById(entry.id);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('«${entry.word}» удалено из словарика'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// Элементы плоского списка.

sealed class _ListItem {}

class _LetterHeaderItem extends _ListItem {
  _LetterHeaderItem({required this.letter, required this.color});

  final String letter;
  final Color color;
}

class _WordItem extends _ListItem {
  _WordItem({required this.entry});

  final VocabularyEntry entry;
}

// Линейка алфавита с анимацией.
class _DockAlphabetBar extends StatefulWidget {
  const _DockAlphabetBar({
    required this.activeLetter,
    required this.availableLetters,
    required this.onLetterTap,
  });

  final String? activeLetter;
  final Set<String> availableLetters;
  final ValueChanged<String> onLetterTap;

  @override
  State<_DockAlphabetBar> createState() => _DockAlphabetBarState();
}

class _DockAlphabetBarState extends State<_DockAlphabetBar> {
  /// Индекс буквы, на которую наведён палец (-1 = нет).
  int _hoverIndex = -1;

  /// Буквы, которые реально есть в словарике.
  late List<String> _letters;

  @override
  void initState() {
    super.initState();
    _rebuildLetters();
  }

  @override
  void didUpdateWidget(covariant _DockAlphabetBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.availableLetters != widget.availableLetters) {
      _rebuildLetters();
    }
  }

  void _rebuildLetters() {
    _letters = <String>[];
    for (int i = 0; i < _alphabet.length; i++) {
      final String ch = _alphabet[i];
      if (widget.availableLetters.contains(ch)) {
        _letters.add(ch);
      }
    }
  }

  void _handleVerticalDrag(Offset localPosition, double itemExtent) {
    final int index = (localPosition.dy / itemExtent).floor().clamp(
      0,
      _letters.length - 1,
    );
    if (index != _hoverIndex) {
      setState(() {
        _hoverIndex = index;
      });
      widget.onLetterTap(_letters[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    if (_letters.isEmpty) {
      return const SizedBox(width: 28);
    }

    const double baseSize = 14;
    const double maxSize = 26;
    // Радиус волны — сколько соседних букв увеличиваются.
    const int waveRadius = 3;
    const double itemExtent = 22;

    return GestureDetector(
      onVerticalDragStart: (DragStartDetails details) {
        _handleVerticalDrag(details.localPosition, itemExtent);
      },
      onVerticalDragUpdate: (DragUpdateDetails details) {
        _handleVerticalDrag(details.localPosition, itemExtent);
      },
      onVerticalDragEnd: (_) {
        setState(() {
          _hoverIndex = -1;
        });
      },
      onVerticalDragCancel: () {
        setState(() {
          _hoverIndex = -1;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: SizedBox(
          width: 38,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(_letters.length, (int index) {
              final String letter = _letters[index];
              final bool isActive =
                  letter == widget.activeLetter && _hoverIndex == -1;
              final bool isHovered = index == _hoverIndex;

              // Рассчитываем масштаб волны.
              double fontSize = baseSize;
              double extraPadding = 0;
              if (_hoverIndex >= 0) {
                final int distance = (index - _hoverIndex).abs();
                if (distance <= waveRadius) {
                  // Плавная кривая: чем ближе к hoverIndex, тем больше.
                  final double t = 1.0 - (distance / (waveRadius + 1));
                  final double curve = math.sin(t * math.pi / 2);
                  fontSize = baseSize + (maxSize - baseSize) * curve;
                  extraPadding = 2 * curve;
                }
              }

              return GestureDetector(
                onTap: () => widget.onLetterTap(letter),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  height: itemExtent + extraPadding,
                  alignment: Alignment.center,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    width: isHovered ? 32 : (isActive ? 28 : 22),
                    height: isHovered ? 32 : (isActive ? 28 : 22),
                    decoration: BoxDecoration(
                      color: isHovered
                          ? colorScheme.primary
                          : isActive
                          ? colorScheme.primaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(isHovered ? 8 : 6),
                    ),
                    alignment: Alignment.center,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: (isHovered || isActive)
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: isHovered
                            ? colorScheme.onPrimary
                            : isActive
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.7,
                              ),
                        height: 1,
                      ),
                      child: Text(letter),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// Заголовок секции буквы.
class _LetterHeader extends StatelessWidget {
  const _LetterHeader({required this.letter, required this.color});

  final String letter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  color.withValues(alpha: 0.85),
                  color.withValues(alpha: 0.55),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                letter,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

// Карточка слова (без аватара буквы).
class _VocabularyCard extends StatelessWidget {
  const _VocabularyCard({
    required this.entry,
    required this.onDelete,
    this.isHighlighted = false,
  });

  final VocabularyEntry entry;
  final VoidCallback onDelete;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String dateLabel = _formatDate(entry.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isHighlighted
              ? colorScheme.primaryContainer.withValues(alpha: 0.45)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isHighlighted
                ? colorScheme.primary.withValues(alpha: 0.5)
                : colorScheme.outlineVariant.withValues(alpha: 0.35),
            width: isHighlighted ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            entry.word,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            dateLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.7,
                              ),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(
                          alpha: 0.22,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        entry.translation,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 2),
              IconButton(
                onPressed: onDelete,
                icon: SvgPicture.asset(
                  'assets/icons/delete.svg',
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    colorScheme.secondary.withValues(alpha: 0.6),
                    BlendMode.srcIn,
                  ),
                ),
                tooltip: 'Удалить',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
