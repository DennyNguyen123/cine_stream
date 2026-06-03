import 'package:dio/dio.dart';
void main() async {
  final dio = Dio(BaseOptions(followRedirects: false, validateStatus: (s) => true));
  try {
    var res = await dio.get('https://vidnest.fun/tv/1396/1/1?autostart=true');
    print('Vidnest TV status: ' + res.statusCode.toString());
    res = await dio.get('https://peachify.top/embed/tv/1396/1/1?autostart=true');
    print('Vidplay TV status: ' + res.statusCode.toString());
  } catch (e) {
    print(e);
  }
}
