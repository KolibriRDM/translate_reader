import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:translate_reader/core/database/app_database.dart';
import 'package:translate_reader/features/reader/application/book_reader_service.dart';
import 'package:translate_reader/features/reader/application/reading_session_store.dart';
import 'package:translate_reader/features/reader/domain/models/book_content.dart';
import 'package:translate_reader/features/reader/domain/models/reading_session.dart';
import 'package:translate_reader/features/reader/presentation/reader_book_page.dart';
import 'package:translate_reader/features/translation/presentation/vocabulary_page.dart';

class ReaderHomePage extends StatefulWidget {
  const ReaderHomePage({
    required this.themeMode,
    required this.onThemeModeChanged,
    super.key,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<ReaderHomePage> createState() => _ReaderHomePageState();
}

class _ReaderHomePageState extends State<ReaderHomePage> {
  final BookReaderService _readerService = const BookReaderService();
  final ReadingSessionStore _sessionStore = ReadingSessionStore.instance;

  BookContent? _lastOpenedBook;
  List<RecentBook> _recentBooks = const <RecentBook>[];
  String _statusMessage = 'Выберите книгу для открытия.';
  bool _isLoading = false;
  bool _isRestoring = true;

  @override
  void initState() {
    super.initState();
    _restoreSavedSession();
  }

  Future<void> _restoreSavedSession() async {
    final ReadingSessionRestoreResult restoreResult = await _sessionStore
        .restoreLastSession(readerService: _readerService);
    final List<RecentBook> recentBooks = await _sessionStore.loadRecentBooks();
    if (!mounted) {
      return;
    }

    setState(() {
      _isRestoring = false;
      _recentBooks = recentBooks;
      final ReadingSession? session =
          restoreResult.session ?? _sessionStore.session;
      if (session != null) {
        _lastOpenedBook = session.book;
        _statusMessage =
            restoreResult.message ??
            'Можно продолжить чтение с сохранённой страницы.';
      } else if (restoreResult.message != null) {
        _statusMessage = restoreResult.message!;
      }
    });
  }

  Future<void> _refreshRecentBooks() async {
    final List<RecentBook> recentBooks = await _sessionStore.loadRecentBooks();
    if (!mounted) {
      return;
    }

    setState(() {
      _recentBooks = recentBooks;
      _lastOpenedBook = _sessionStore.session?.book;
    });
  }

  Future<void> _openBook() async {
    if (_isLoading || _isRestoring) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await _readerService.pickAndLoadBook();
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _statusMessage = result.message ?? 'Книга успешно открыта.';
      if (result.book != null) {
        _lastOpenedBook = result.book;
      }
    });

    if (result.book == null) {
      return;
    }

    _sessionStore.startSession(book: result.book!);
    await _pushCurrentSession();
  }

  Future<void> _continueReading() async {
    final ReadingSession? session = _sessionStore.session;
    if (session == null) {
      return;
    }

    await _pushCurrentSession();
  }

  Future<void> _openRecentBook(RecentBook recentBook) async {
    if (_isLoading || _isRestoring) {
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Открываю ${recentBook.fileName}...';
    });

    final ReadingSessionRestoreResult restoreResult = await _sessionStore
        .restoreRecentBook(
          recentBook: recentBook,
          readerService: _readerService,
        );
    final List<RecentBook> recentBooks = await _sessionStore.loadRecentBooks();
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _recentBooks = recentBooks;
      final ReadingSession? session =
          restoreResult.session ?? _sessionStore.session;
      if (session != null) {
        _lastOpenedBook = session.book;
        _statusMessage =
            'Восстановлена книга ${session.book.fileName} с сохранённой страницы.';
      } else {
        _statusMessage =
            restoreResult.message ?? 'Не удалось открыть сохранённую книгу.';
      }
    });

    if (restoreResult.session == null) {
      return;
    }

    await _pushCurrentSession();
  }

  Future<void> _pushCurrentSession() async {
    final ReadingSession? session = _sessionStore.session;
    if (session == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            ReaderBookPage(book: session.book, sessionStore: _sessionStore),
      ),
    );

    if (!mounted) {
      return;
    }

    await _refreshRecentBooks();
    if (!mounted) {
      return;
    }

    setState(() {
      _lastOpenedBook = _sessionStore.session?.book;
      _statusMessage = 'Прогресс чтения сохранён.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final ReadingSession? session = _sessionStore.session;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              colorScheme.surface,
              colorScheme.primaryContainer.withValues(alpha: 0.42),
              colorScheme.surface,
            ],
            stops: const <double>[0, 0.35, 1],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: <Widget>[
              _HomeHeader(
                themeMode: widget.themeMode,
                onThemeModeChanged: widget.onThemeModeChanged,
              ),
              const SizedBox(height: 24),
              _HeroSection(
                isLoading: _isLoading || _isRestoring,
                hasSession: session != null,
                onOpenBook: _openBook,
                onContinueReading: session == null ? null : _continueReading,
              ),
              const SizedBox(height: 20),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _BookInfoPanel(
                    book: _lastOpenedBook,
                    session: session,
                    statusMessage: _statusMessage,
                  ),
                ),
              ),
              if (_recentBooks.isNotEmpty) const SizedBox(height: 20),
              if (_recentBooks.isNotEmpty)
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _RecentBooksPanel(
                      recentBooks: _recentBooks,
                      currentBookPath: session?.book.filePath,
                      onOpenRecentBook: _openRecentBook,
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              _VocabularyButton(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => const VocabularyPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: const <Widget>[
                  _FeatureBadge(
                    icon: 'assets/icons/book.svg',
                    label: 'Удобное чтение',
                  ),
                  _FeatureBadge(
                    icon: 'assets/icons/tap_translate.svg',
                    label: 'Перевод по тапу',
                  ),
                  _FeatureBadge(
                    icon: 'assets/icons/font.svg',
                    label: 'Гибкий размер шрифта',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookInfoPanel extends StatelessWidget {
  const _BookInfoPanel({
    required this.book,
    required this.session,
    required this.statusMessage,
  });

  final BookContent? book;
  final ReadingSession? session;
  final String statusMessage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    if (book == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Библиотека пуста',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Откройте файл, и приложение запомнит текущую книгу и позицию чтения.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          _StatusPill(message: statusMessage),
        ],
      );
    }

    final List<_MetaItem> items = <_MetaItem>[
      _MetaItem(label: 'Формат', value: book!.format.label),
      if (session != null)
        _MetaItem(label: 'Страница', value: '${session!.currentPage + 1}'),
      if (session != null)
        _MetaItem(label: 'Режим', value: session!.layoutMode.label),
      if (session != null)
        _MetaItem(
          label: 'Шрифт',
          value: '${session!.fontSize.toStringAsFixed(0)} pt',
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Текущая книга',
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          book!.fileName,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items.map((item) => _MetaChip(item: item)).toList(),
        ),
        const SizedBox(height: 18),
        _StatusPill(message: statusMessage),
      ],
    );
  }
}

class _RecentBooksPanel extends StatelessWidget {
  const _RecentBooksPanel({
    required this.recentBooks,
    required this.currentBookPath,
    required this.onOpenRecentBook,
  });

  final List<RecentBook> recentBooks;
  final String? currentBookPath;
  final ValueChanged<RecentBook> onOpenRecentBook;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Последние книги',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Можно быстро вернуться к последним открытым книгам и сохранённым страницам.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        for (final RecentBook book in recentBooks) ...<Widget>[
          _RecentBookTile(
            book: book,
            isCurrent: book.path == currentBookPath,
            onTap: () => onOpenRecentBook(book),
          ),
          if (book != recentBooks.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Translate Reader',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Спокойный экран для чтения книг и быстрого перевода незнакомых слов.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        _ThemeSwitcher(
          themeMode: themeMode,
          onThemeModeChanged: onThemeModeChanged,
        ),
      ],
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.isLoading,
    required this.hasSession,
    required this.onOpenBook,
    required this.onContinueReading,
  });

  final bool isLoading;
  final bool hasSession;
  final VoidCallback onOpenBook;
  final VoidCallback? onContinueReading;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            colorScheme.primaryContainer.withValues(alpha: 0.95),
            colorScheme.secondaryContainer.withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.14),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: SvgPicture.asset(
              'assets/icons/start_reading.svg',
              width: 28,
              height: 28,
              colorFilter: ColorFilter.mode(
                colorScheme.onPrimaryContainer,
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            hasSession
                ? 'Продолжайте с того места, где остановились'
                : 'Откройте книгу и начните чтение',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Поддерживается постраничное чтение, перевод выделения и быстрый просмотр перевода по касанию.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.86),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: isLoading ? null : onOpenBook,
            icon: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : SvgPicture.asset(
                    'assets/icons/import_book.svg',
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      colorScheme.onPrimaryContainer,
                      BlendMode.srcIn,
                    ),
                  ),
            label: Text(isLoading ? 'Открываю...' : 'Открыть книгу'),
          ),
          if (hasSession) const SizedBox(height: 12),
          if (hasSession)
            OutlinedButton.icon(
              onPressed: onContinueReading,
              icon: SvgPicture.asset(
                'assets/icons/continue.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  colorScheme.onPrimaryContainer,
                  BlendMode.srcIn,
                ),
              ),
              label: const Text('Продолжить чтение'),
            ),
        ],
      ),
    );
  }
}

class _ThemeSwitcher extends StatelessWidget {
  const _ThemeSwitcher({
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: SegmentedButton<ThemeMode>(
          showSelectedIcon: false,
          segments: const <ButtonSegment<ThemeMode>>[
            ButtonSegment<ThemeMode>(
              value: ThemeMode.light,
              icon: Icon(Icons.wb_sunny_outlined),
              label: Text('День'),
            ),
            ButtonSegment<ThemeMode>(
              value: ThemeMode.dark,
              icon: Icon(Icons.nights_stay_outlined),
              label: Text('Вечер'),
            ),
          ],
          selected: <ThemeMode>{themeMode},
          onSelectionChanged: (Set<ThemeMode> selection) {
            onThemeModeChanged(selection.first);
          },
        ),
      ),
    );
  }
}

class _RecentBookTile extends StatelessWidget {
  const _RecentBookTile({
    required this.book,
    required this.isCurrent,
    required this.onTap,
  });

  final RecentBook book;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCurrent
              ? colorScheme.primaryContainer.withValues(alpha: 0.74)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.56),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCurrent
                ? colorScheme.primary.withValues(alpha: 0.26)
                : colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(14),
              ),
              child: SvgPicture.asset(
                'assets/icons/book.svg',
                colorFilter: ColorFilter.mode(
                  colorScheme.primary,
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    book.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Страница ${book.currentPage + 1} • ${book.format.toUpperCase()}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              isCurrent ? Icons.play_circle_fill_rounded : Icons.chevron_right,
              color: isCurrent
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureBadge extends StatelessWidget {
  const _FeatureBadge({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SvgPicture.asset(
            icon,
            width: 18,
            height: 18,
            colorFilter: ColorFilter.mode(colorScheme.primary, BlendMode.srcIn),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.item});

  final _MetaItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            item.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          SvgPicture.asset(
            'assets/icons/bookmark.svg',
            width: 18,
            height: 18,
            colorFilter: ColorFilter.mode(
              colorScheme.onTertiaryContainer,
              BlendMode.srcIn,
            ),
          ),

          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaItem {
  const _MetaItem({required this.label, required this.value});

  final String label;
  final String value;
}

class _VocabularyButton extends StatelessWidget {
  const _VocabularyButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: colorScheme.secondary.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: EdgeInsets.all(10),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.secondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: SvgPicture.asset(
                'assets/icons/vocabulary.svg',
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  colorScheme.secondary,
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Мой словарик',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Сохранённые слова и переводы',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSecondaryContainer.withValues(
                        alpha: 0.72,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSecondaryContainer.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
