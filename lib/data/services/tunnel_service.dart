import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:dartssh2/dartssh2.dart';

class TunnelService {
  HttpServer? _httpServer;
  SSHClient? _sshClient;
  String? publicUrl;

  // Hàm callback khi nhận được cấu hình, trả về true nếu thành công (đúng PIN), false nếu sai PIN
  Future<bool> Function(Map<String, dynamic>)? onConfigReceived;

  Future<String?> startTunnel() async {
    // 1. Khởi tạo Local Server
    final handler = const Pipeline().addHandler(_handleRequest);
    _httpServer = await shelf_io.serve(
      handler,
      InternetAddress.loopbackIPv4,
      0,
    );
    final localPort = _httpServer!.port;

    // 2. Mở SSH Tunnel tới localhost.run
    try {
      print('TunnelService: Bắt đầu kết nối SSH tới localhost.run...');
      final socket = await SSHSocket.connect(
        'localhost.run',
        22,
        timeout: const Duration(seconds: 10),
      );
      print('TunnelService: Đã mở socket, đang khởi tạo SSH Client...');

      _sshClient = SSHClient(
        socket,
        username: 'nokey',
        onPasswordRequest: () => '',
      );

      // Khởi tạo shell session để lấy public URL
      final session = await _sshClient!.shell();

      print('TunnelService: Đang request forwardRemote...');
      final forward = await _sshClient!.forwardRemote(port: 80);
      print('TunnelService: forwardRemote thành công!');

      final completer = Completer<String?>();

      // Lắng nghe stdout để lấy URL
      session.stdout.listen((event) {
        final out = utf8.decode(event);
        print('TunnelService STDOUT: $out');
        final RegExp urlRegex = RegExp(r'https:\/\/[a-zA-Z0-9-]+\.lhr\.life');
        final match = urlRegex.firstMatch(out);
        if (match != null && !completer.isCompleted) {
          completer.complete(match.group(0));
        }
      });

      // Nếu sau 5s không tìm thấy URL thì lỗi
      Future.delayed(const Duration(seconds: 5), () {
        if (!completer.isCompleted) completer.complete(null);
      });

      publicUrl = await completer.future;
      if (publicUrl == null)
        throw Exception('Không lấy được URL từ localhost.run');
      print('TunnelService: Đã lấy được publicUrl: $publicUrl');

      // Thực hiện forwarding dữ liệu
      forward!.connections.listen((socket) async {
        try {
          print(
            'TunnelService: Có kết nối mới từ bên ngoài, đang pipe dữ liệu...',
          );
          final localSocket = await Socket.connect('127.0.0.1', localPort);
          socket.stream.cast<List<int>>().pipe(localSocket);
          localSocket.cast<List<int>>().pipe(socket.sink);
        } catch (e) {
          print('TunnelService: Lỗi pipe dữ liệu: $e');
        }
      });

      return publicUrl;
    } catch (e) {
      print('TunnelService: Lỗi kết nối tunnel: $e');
      stopTunnel();
      return null;
    }
  }

  Future<Response> _handleRequest(Request request) async {
    if (request.method == 'POST') {
      try {
        final payload = await request.readAsString();
        final data = jsonDecode(payload);
        if (onConfigReceived != null) {
          final success = await onConfigReceived!(data);
          if (!success) {
            return Response.internalServerError();
          }
        }
        return Response.ok('Success');
      } catch (e) {
        return Response.internalServerError();
      }
    }
    return Response.notFound('Not found');
  }

  void stopTunnel() {
    _httpServer?.close(force: true);
    _sshClient?.close();
  }
}
