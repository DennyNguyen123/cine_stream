import 'dart:io';
import 'dart:convert';
void main() async {
  final res = await HttpClient().getUrl(Uri.parse('https://v3-cinemeta.strem.io/catalog/series/top.json'));
  final resp = await res.close();
  final body = await resp.transform(utf8.decoder).join();
  final json = jsonDecode(body);
  print(json['metas'][0]);
}
