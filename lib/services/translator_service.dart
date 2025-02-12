import 'deepl_translator.dart';
import 'google_translator.dart';

abstract class TranslatorService {
  Future<String> translate(String text,
      {String from = 'auto', required String to});
}

class GoogleTranslatorService implements TranslatorService {
  final translator = GoogleTranslator();

  @override
  Future<String> translate(String text,
      {String from = 'auto', required String to}) async {
    return await translator.translate(text, from: from, to: to);
  }
}

class DeepLTranslatorService implements TranslatorService {
  final translator = DeepLTranslator();

  @override
  Future<String> translate(String text,
      {String from = 'auto', required String to}) async {
    return await translator.translate(text, from: from, to: to);
  }
}
