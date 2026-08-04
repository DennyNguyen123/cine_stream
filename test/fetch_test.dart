import 'dart:io';

void main() async {
  final url =
      'https://i-arch-400.keymi417exx.com/stream2/i-arch-400/8ad0fd4fdc29dcff1265ea074c04973e/MJTMsp1RshGTygnMNRUR2N2MSlnWXZEdMNDZzQWe5MDZzMmdZJTO1R2RWVHZDljekhkSsl1VwYnWtx2cihVT290RWtmT6FENNpHaq5ERs1WTtZVaNdVRx4kaJNTTEJFbNdUR41UbapmTUFUP:1780652137:64.118.155.102:edbd0f1a88b2f76a0b3aef25d2be8f2e7170558e45524a09a059f8c475aa81f4:=4kaRVXTUVENMpWRx40U0gXTElUP/index.m3u8';
  final headers = {
    'Referer': 'https://vidnest.fun/',
    'Origin': 'https://vidnest.fun',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  };

  final client = HttpClient();

  try {
    var uri = Uri.parse(url);
    var request = await client.getUrl(uri);
    headers.forEach((k, v) => request.headers.set(k, v));
    request.followRedirects = false; // Do not follow redirects automatically

    var response = await request.close();
    print('Status Code: \${response.statusCode}');

    if (response.isRedirect) {
      final location = response.headers.value(HttpHeaders.locationHeader);
      print('Redirected to: $location');

      if (location != null) {
        var req2 = await client.getUrl(Uri.parse(location));
        headers.forEach((k, v) => req2.headers.set(k, v));
        var res2 = await req2.close();
        print('Final Status Code: \${res2.statusCode}');
      }
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}
