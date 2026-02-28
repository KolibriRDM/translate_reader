enum BookFormat {
  epub('epub'),
  fb2('fb2'),
  txt('txt');

  const BookFormat(this.extension);

  final String extension;

  String get label {
    return switch (this) {
      BookFormat.epub => 'EPUB',
      BookFormat.fb2 => 'FB2',
      BookFormat.txt => 'TXT',
    };
  }

  static BookFormat? fromPath(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == path.length - 1) {
      return null;
    }

    final extension = path.substring(dotIndex + 1).toLowerCase();
    for (final format in BookFormat.values) {
      if (format.extension == extension) {
        return format;
      }
    }
    return null;
  }
}
