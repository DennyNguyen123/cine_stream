import 'dart:io';
import 'dart:convert';
void main() async {
  final res = await HttpClient().getUrl(Uri.parse('https://kisskh.co/api/DramaList/List?page=1&type=1&sub=0&country=0&status=0&order=1'));
  final resp = await res.close();
  final body = await resp.transform(utf8.decoder).join();
  final json = jsonDecode(body);
  print(json['data'][0]);
}
