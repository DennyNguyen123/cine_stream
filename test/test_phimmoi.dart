import 'dart:io';
import 'dart:convert';

void main() async {
  final client = HttpClient();
  
  // Test APIs
  final apis = [
    'https://phimmoi.cc',
    'https://cdn.phimmoi.cc/api/v1/filter/movies',
    'https://api.phimmoi.cc/api/v1/filter/movies',
    'https://phimmoi.cc/api/v1/filter/movies',
  ];
  
  for (var api in apis) {
    try {
      final req = await client.getUrl(Uri.parse(api)).timeout(Duration(seconds: 5));
      req.followRedirects = true;
      final res = await req.close().timeout(Duration(seconds: 5));
      print('[$api] Status: ${res.statusCode}');
      if (res.statusCode == 200 && api == 'https://phimmoi.cc') {
        final body = await res.transform(utf8.decoder).join();
        print('Body length: ${body.length}');
        if (body.contains('cdn.')) {
          final matches = RegExp(r'https://cdn\.[a-zA-Z0-9-.]+/api/[a-zA-Z0-9-/]+').allMatches(body);
          print('Found CDN API: ${matches.map((m) => m.group(0)).toSet()}');
        }
        if (body.contains('__NEXT_DATA__')) {
          print('Contains __NEXT_DATA__');
        }
      }
    } catch (e) {
      print('[$api] Error: $e');
    }
  }
}
