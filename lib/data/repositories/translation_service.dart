import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

class TranslationService {
  final Dio _dio;
  // Google Translate Free Endpoint
  final String _baseUrl = 'https://translate.googleapis.com/translate_a/single';

  TranslationService(this._dio);

  Future<List<String>> translateBatch(List<String> texts, {String targetLang = 'vi'}) async {
    if (texts.isEmpty) return [];

    try {
      // Thay thế \n bằng thẻ <br> để tránh nhầm lẫn với dấu ngắt câu của batch
      final preparedTexts = texts.map((t) => t.replaceAll('\n', '<br>')).toList();
      final separator = '\n\n';
      final combinedText = preparedTexts.join(separator);

      final response = await _dio.get(
        _baseUrl,
        queryParameters: {
          'client': 'gtx',
          'sl': 'auto',
          'tl': targetLang,
          'dt': 't',
          'q': combinedText,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as List;
        final translatedBlocks = data[0] as List;
        
        StringBuffer fullTranslatedText = StringBuffer();
        for (var block in translatedBlocks) {
          fullTranslatedText.write(block[0].toString());
        }

        // Tách lại thành các câu
        List<String> results = fullTranslatedText.toString().split(RegExp(r'\n+'));
        
        // Trim và khôi phục lại thẻ <br> thành \n
        return results.map((e) => e.replaceAll(RegExp(r'<\s*br\s*>|<\s*/\s*br\s*>|&lt;br&gt;', caseSensitive: false), '\n').trim()).toList();
      }
      return texts; // Fallback to original
    } catch (e) {
      debugPrint('TranslationService Error: $e');
      return texts; // Fallback to original on error
    }
  }
}

