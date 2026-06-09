import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  try {
    final res = await dio.get('https://vidapi.xyz/embed/tv/tt13875494/2/18');
    final html = res.data.toString();
    final regex = RegExp(r'tmdb=(\d+)');
    final match = regex.firstMatch(html);
    if (match != null) {
      print('TMDB ID Extracted from vidapi EPISODE tv page: ${match.group(1)}');
    } else {
      print('No tmdb parameter found in vidapi EPISODE tv page');
    }
  } catch (e) {
    print('Error: $e');
  }
}
