
/// Класс для форматирования текста книги.
class BookTextFormatter {
  String format(String rawText) {
    if (rawText.isEmpty) {
      return '';
    }

    String text = rawText;

    // 1. Нормализация переводов строк.
    // Заменяем Windows/Mac окончания строк на \n.
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // 2. Удаление номеров страниц.
    text = text.replaceAll(RegExp(r'\n\s*\[?\d+\]?\s*\n'), '\n');

    // 3. Удаление лишних пробелов между абзацами.
    text = text.replaceAll(RegExp(r'\n{2,}'), '\n');

    // 4. Добавление красной строки (отступа) для каждого абзаца.
    const String indent = '\u2003\u2003'; // Три широких пробела для заметного абзацного отступа
    text = text.replaceAll('\n', '\n$indent');

    // Также добавляем отступ для самого первого абзаца, если текст не пустой.
    if (!text.startsWith(indent)) {
      text = '$indent$text';
    }

    return text;
  }
}
