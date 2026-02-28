abstract class TranslationGateway {
  Future<String> translate({
    required String text,
    required String fromLanguage,
    required String toLanguage,
  });
}
