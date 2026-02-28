import 'package:translator/translator.dart';

class TranslatorService {
  TranslatorService({GoogleTranslator? translator})
      : _translator = translator ?? GoogleTranslator();

  final GoogleTranslator _translator;
  final Map<String, String> _cache = <String, String>{};

  Future<String> translateText(
    String text, {
    String toLanguage = 'ru',
  }) async {
    final source = text.trim();
    if (source.isEmpty) {
      return '';
    }

    final cacheKey = '$toLanguage::$source';
    final cached = _cache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final result = await _translator.translate(source, to: toLanguage);
    final translated = result.text.trim();
    _cache[cacheKey] = translated;
    return translated;
  }
}
