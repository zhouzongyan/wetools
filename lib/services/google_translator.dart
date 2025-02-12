import 'package:translator/translator.dart' as google_trans;

class GoogleTranslator {
  final translator = google_trans.GoogleTranslator();

  Future<String> translate(
    String text, {
    String from = 'auto',
    required String to,
  }) async {
    if (text.isEmpty) return '';

    try {
      final translation = await translator.translate(text, from: from, to: to);
      return translation.text;
    } catch (e) {
      throw Exception('Google翻译出错: $e');
    }
  }
}
