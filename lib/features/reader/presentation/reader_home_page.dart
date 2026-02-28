import 'package:flutter/material.dart';
import 'package:translate_reader/features/reader/application/book_reader_service.dart';
import 'package:translate_reader/features/reader/application/reading_session_store.dart';
import 'package:translate_reader/features/reader/domain/models/book_content.dart';
import 'package:translate_reader/features/reader/domain/models/reading_session.dart';
import 'package:translate_reader/features/reader/presentation/reader_book_page.dart';

class ReaderHomePage extends StatefulWidget {
  const ReaderHomePage({super.key});

  @override
  State<ReaderHomePage> createState() => _ReaderHomePageState();
}

class _ReaderHomePageState extends State<ReaderHomePage> {
  final BookReaderService _readerService = const BookReaderService();
  final ReadingSessionStore _sessionStore = ReadingSessionStore.instance;

  BookContent? _lastOpenedBook;
  String _statusMessage = 'Выберите книгу для открытия.';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final session = _sessionStore.session;
    if (session != null) {
      _lastOpenedBook = session.book;
      _statusMessage = 'Можно продолжить чтение с сохранённой страницы.';
    }
  }

  Future<void> _openBook() async {
    if (_isLoading) {
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

    if (result.book != null) {
      _sessionStore.startSession(book: result.book!);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => ReaderBookPage(
            book: result.book!,
            sessionStore: _sessionStore,
          ),
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _lastOpenedBook = _sessionStore.session?.book;
        _statusMessage = 'Чтение можно продолжить в рамках текущей сессии.';
      });
    }
  }

  Future<void> _continueReading() async {
    final session = _sessionStore.session;
    if (session == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ReaderBookPage(
          book: session.book,
          sessionStore: _sessionStore,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _lastOpenedBook = _sessionStore.session?.book;
      _statusMessage = 'Чтение можно продолжить в рамках текущей сессии.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Читалка с переводом')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Этап 2: выбор файла и просмотр книги.',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'Откройте файл и читайте полный текст книги.',
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _BookInfoPanel(
                book: _lastOpenedBook,
                session: _sessionStore.session,
                statusMessage: _statusMessage,
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_sessionStore.session != null)
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _continueReading,
                child: const Text('Продолжить чтение'),
              ),
            ),
          if (_sessionStore.session != null) const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _openBook,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Открыть книгу'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'В книге выделяйте одно или несколько слов: после выделения доступны кнопки «Копировать» и «Перевести».',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
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
    if (book == null) {
      return Text(statusMessage);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Последняя открытая книга: ${book!.fileName}'),
        const SizedBox(height: 4),
        Text('Формат: ${book!.format.label}'),
        if (session != null) const SizedBox(height: 4),
        if (session != null) Text('Сохранённая страница: ${session!.currentPage + 1}'),
        if (session != null) const SizedBox(height: 4),
        if (session != null)
          Text('Размер шрифта: ${session!.fontSize.toStringAsFixed(0)}'),
        const SizedBox(height: 12),
        Text(
          'Текущий режим: постраничный просмотр',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}
