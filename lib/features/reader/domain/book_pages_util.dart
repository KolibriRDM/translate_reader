import 'package:flutter/widgets.dart';

/// Класс, представляющий диапазон текста для одной страницы.
class PageSpan {
  const PageSpan({required this.start, required this.end});

  /// Индекс начала текста страницы (включительно).
  final int start;

  /// Индекс конца текста страницы (исключительно).
  final int end;

  /// Извлекает текст страницы из полного текста книги.
  String read(String fullText) {
    if (fullText.isEmpty || start >= fullText.length) {
      return '';
    }
    final int safeEnd = end.clamp(start, fullText.length);
    return fullText.substring(start, safeEnd);
  }
}

/// Утилита для разбиения текста на страницы с учетом размеров экрана.
class BookPaginator {
  /// Разбивает текст на страницы с учетом стиля текста и доступного размера.
  List<PageSpan> paginate({
    required String text,
    required TextStyle style,
    required Size pageSize,
    required TextDirection textDirection,
    required TextScaler textScaler,
    double safetyMargin = 0,
  }) {
    if (text.isEmpty) {
      return const <PageSpan>[];
    }
    
    final double effectiveHeight = pageSize.height - 4.0;
    
    final List<PageSpan> pages = <PageSpan>[];
    final TextPainter textPainter = TextPainter(
      textDirection: textDirection,
      textScaler: textScaler,
    );

    int start = 0;
    final int contentLength = text.length;

    final double fontSize = textScaler.scale(style.fontSize ?? 14);
    final double lineHeight = fontSize * (style.height ?? 1.2);
    final int maxLines = ((effectiveHeight - safetyMargin) / lineHeight)
        .floor();

    final int charsPerLine = (pageSize.width / (fontSize * 0.5)).floor();

    final int estimatedPageChars = (maxLines * charsPerLine * 0.8)
        .floor()
        .clamp(100, 5000);

    while (start < contentLength) {
      final int remaining = contentLength - start;

      if (remaining <= estimatedPageChars) {
        if (_doesFit(
          textPainter,
          text,
          start,
          remaining,
          style,
          pageSize,
          safetyMargin,
          effectiveHeight, // Передаем безопасную высоту
        )) {
          pages.add(PageSpan(start: start, end: contentLength));
          break;
        }
      }

      // Бинарный поиск оптимальной длины страницы.
      // Ищем максимальную длину `len`, такую что text.substring(start, start + len) влезает.

      int low = 1;
      // В качестве верхней границы берем estimatedPageChars * 2, но не больше remaining.
      int high = (estimatedPageChars * 1.5).floor().clamp(low, remaining);

      if (!_doesFit(
        textPainter,
        text,
        start,
        high,
        style,
        pageSize,
        safetyMargin,
        effectiveHeight,
      )) {
        // Бинарный поиск в [low, high]
      } else {
        // High влезает, попробуем найти границу выше.
        low = high;
        while (high < remaining) {
          final int nextHigh = (high * 2).clamp(high + 1, remaining);
          if (!_doesFit(
            textPainter,
            text,
            start,
            nextHigh,
            style,
            pageSize,
            safetyMargin,
            effectiveHeight,
          )) {
            high = nextHigh;
            break;
          }
          low = high;
          high = nextHigh;
        }
      }

      // Теперь low - влезает (возможно), high - не влезает (точно).
      // Уточняем границу бинарным поиском между low и high.
      while (low < high) {
        final int mid = (low + high + 1) ~/ 2; // ceiling division
        if (_doesFit(
          textPainter,
          text,
          start,
          mid,
          style,
          pageSize,
          safetyMargin,
          effectiveHeight,
        )) {
          low = mid;
        } else {
          high = mid - 1;
        }
      }

      // low - максимальная длина, которая влезает.
      // Теперь нужно найти границу слова, чтобы не обрывать на полуслове.
      int splitLength = low;

      // Если это не конец текста, ищем пробел для переноса.
      if (start + splitLength < contentLength) {
        final int boundary = _findWordBoundary(text, start, splitLength);
        // Если не нашли границу слова (огромное слово), рубим как есть, или уменьшаем посимвольно.
        if (boundary > 0) {
          splitLength = boundary;
        }
      }

      // Защита от зацикливания: если splitLength == 0 (например, слово не влезает по ширине),
      // берем хотя бы 1 символ или сколько влезет по ширине.
      if (splitLength <= 0) {
        // Fallback: берем посимвольно, пока влезает по ширине
        int charCount = 1;
        while (charCount < remaining &&
            _doesFit(
              textPainter,
              text,
              start,
              charCount + 1,
              style,
              pageSize,
              safetyMargin,
              effectiveHeight,
            )) {
          charCount++;
        }
        splitLength = charCount;
      }

      pages.add(PageSpan(start: start, end: start + splitLength));
      start += splitLength;

      while (start < contentLength) {
        final String ch = text[start];
        if (ch == ' ' || ch == '\t') {
          // Обычные пробелы/табы — пропускаем
          start++;
        } else if (ch == '\n') {
          // Пустая строка в начале страницы — пропускаем
          start++;
        } else {
          break;
        }
      }
    }

    return pages;
  }

  bool _doesFit(
    TextPainter painter,
    String text,
    int start,
    int length,
    TextStyle style,
    Size boxSize,
    double safetyMargin,
    double effectiveHeight,
  ) {
    if (length <= 0) return true;

    painter.text = TextSpan(
      text: text.substring(start, start + length),
      style: style,
    );
    
    // Используем максимально точный layout
    painter.layout(maxWidth: boxSize.width);

    return painter.height <= effectiveHeight && 
           painter.width <= boxSize.width &&
           !painter.didExceedMaxLines;
  }

  /// Ищет подходящее место для разрыва страницы (пробел, конец предложения).
  /// Возвращает длину от start до границы разрыва.
  int _findWordBoundary(String text, int start, int initialLength) {
    // Идем назад от конца предполагаемого блока
    int offset = initialLength;
    final int hardLimit = (initialLength * 0.7)
        .floor(); // Не отступать более чем на 30%

    while (offset > hardLimit) {
      final int index = start + offset;
      if (index >= text.length) return offset;

      final String char = text[index];
      // Ищем пробельные символы, по которым можно перенести
      if (char == ' ' || char == '\n' || char == '\t') {
        return offset; // Возвращаем длину, ВКЛЮЧАЯ этот пробел в текущую страницу (или исключая, но он невидим в конце)
      }

      // Также можно переносить после знаков препинания, но лучше по пробелам.
      offset--;
    }

    return initialLength; // Не нашли (очень длинное слово), режем как есть.
  }
}
