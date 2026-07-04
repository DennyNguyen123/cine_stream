import 'dart:typed_data';
import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  print('1. Lấy token từ Bing Translator...');
  String? cachedKey;
  String? cachedToken;
  String? cachedCookie;

  try {
    final response = await dio.get<String>(
      'https://www.bing.com/translator',
      options: Options(
        headers: {
          'User-Agent': userAgent,
          'Accept-Language': 'vi,en-US;q=0.9,en;q=0.8',
        },
      ),
    );

    if (response.statusCode != 200 || response.data == null) {
      print('FAILED to fetch page, status: ${response.statusCode}');
      return;
    }

    final rawCookies = response.headers['set-cookie'] ?? [];
    final cookieString = rawCookies.map((c) => c.split(';').first).join('; ');

    final html = response.data!;
    final regExp = RegExp(
      r'params_AbusePreventionHelper\s*=\s*\[([^,]+),([^,]+),',
    );
    final match = regExp.firstMatch(html);

    if (match == null) {
      print('FAILED: params_AbusePreventionHelper not found in HTML!');
      return;
    }

    cachedKey = match.group(1)?.replaceAll('"', '').trim();
    cachedToken = match.group(2)?.replaceAll('"', '').trim();
    cachedCookie = cookieString;

    print('SUCCESS: Lấy được Key=$cachedKey, Token=$cachedToken');
    print('Cookie: $cachedCookie');
  } catch (e) {
    print('Lỗi lấy token: $e');
    return;
  }

  print('\n2. Gửi request TTS...');
  try {
    const text = 'Xin chào, đây là thử nghiệm giọng nói từ Microsoft Edge.';
    const voiceId = 'vi-VN-HoaiMyNeural';

    final parts = voiceId.split('-');
    final xmlLang = parts.length >= 2 ? parts.sublist(0, 2).join('-') : 'vi-VN';
    final gender = voiceId.toLowerCase().contains('male') ? 'Male' : 'Female';
    const prosodyRate = '+0.00%';

    final ssml =
        "<speak version='1.0' xml:lang='$xmlLang'><voice xml:lang='$xmlLang' xml:gender='$gender' name='$voiceId'><prosody rate='$prosodyRate'>$text</prosody></voice></speak>";

    final headers = {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Accept': '*/*',
      'Origin': 'https://www.bing.com',
      'Referer': 'https://www.bing.com/translator',
      'User-Agent': userAgent,
    };
    if (cachedCookie.isNotEmpty) {
      headers['Cookie'] = cachedCookie;
    }

    final body =
        'ssml=${Uri.encodeComponent(ssml)}'
        '&token=${Uri.encodeComponent(cachedToken ?? '')}'
        '&key=${Uri.encodeComponent(cachedKey ?? '')}';

    final response = await dio.post<List<int>>(
      'https://www.bing.com/tfettts?isVertical=1&&IG=1&IID=translator.5023&SFX=1',
      data: body,
      options: Options(headers: headers, responseType: ResponseType.bytes),
    );

    print('TTS Status Code: ${response.statusCode}');
    print('TTS Response Headers: ${response.headers}');
    if (response.data != null) {
      final bytes = Uint8List.fromList(response.data!);
      print('SUCCESS: Lấy được file audio có dung lượng ${bytes.length} bytes');
      if (bytes.length < 1024) {
        print(
          'Cảnh báo: Dung lượng file quá nhỏ, có khả năng bị lỗi hoặc rỗng.',
        );
      }
    } else {
      print('FAILED: Response data is null');
    }
  } catch (e) {
    print('Lỗi gửi request TTS: $e');
  }
}
