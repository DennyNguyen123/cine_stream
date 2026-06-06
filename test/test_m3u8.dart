import 'dart:io';
import 'package:cine_stream/data/sources/cinemeta/cinemeta_source.dart';
import 'package:cine_stream/data/sources/cinemeta/extractors/vidsrcme_extractor.dart';
import 'package:flutter/widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('Running test...');
  // Let's use the URL from cinemeta for a movie: 'https://vidsrcme.ru/embed/movie?imdb=tt30825738&autoplay=1'
  final url = 'https://vidsrcme.ru/embed/movie?imdb=tt30825738&autoplay=1';
  final stream = await VidsrcmeExtractor.extractStream(url, []);
  
  if (stream != null) {
    print('STREAM FOUND: ${stream.videoUrl}');
    print('HEADERS: ${stream.headers}');
    
    // Now fetch the actual m3u8
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(stream.videoUrl));
      stream.headers?.forEach((k, v) => request.headers.set(k, v));
      final response = await request.close();
      print('HTTP STATUS: ${response.statusCode}');
      final body = await response.map((chunk) => chunk).toList();
      final bodyString = String.fromCharCodes(body.expand((x) => x));
      print('BODY: ${bodyString.substring(0, bodyString.length > 500 ? 500 : bodyString.length)}');
    } catch (e) {
      print('HTTP ERROR: $e');
    }
  } else {
    print('STREAM NOT FOUND');
  }
  exit(0);
}
