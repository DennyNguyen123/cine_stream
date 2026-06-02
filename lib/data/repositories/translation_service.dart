import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class TranslationService {
  final Dio _dio;
  // Google Translate Free Endpoint
  final String _baseUrl = 'https://translate.googleapis.com/translate_a/single';

  TranslationService(this._dio);

  Future<List<String>> translateBatch(List<String> texts, {String targetLang = 'vi'}) async {
    if (texts.isEmpty) return [];

    try {
      // Nối các câu lại bằng ký tự đặc biệt để dịch 1 lần (tiết kiệm request)
      // Google Translate hỗ trợ khoảng ~5000 ký tự mỗi request
      final separator = ' | ';
      final combinedText = texts.join(separator);

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
        List<String> results = fullTranslatedText.toString().split(separator);
        
        // Trim và chuẩn hóa lại (nếu Google dịch làm mất format spacer)
        return results.map((e) => e.trim()).toList();
      }
      return texts; // Fallback to original
    } catch (e) {
      debugPrint('TranslationService Error: $e');
      return texts; // Fallback to original on error
    }
  }
}
