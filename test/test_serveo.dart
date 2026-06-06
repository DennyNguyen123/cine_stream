import 'dart:io';
import 'package:dartssh2/dartssh2.dart';

void main() async {
  try {
    final socket = await SSHSocket.connect('localhost.run', 22);
    final client = SSHClient(
      socket,
      username: 'nokey',
      onPasswordRequest: () => '',
    );
    
    // We can listen to stdout/stderr of the connection, or maybe shell?
    final session = await client.shell();
    session.stdout.listen((event) {
      print('STDOUT: ${String.fromCharCodes(event)}');
    });
    session.stderr.listen((event) {
      print('STDERR: ${String.fromCharCodes(event)}');
    });

    final forward = await client.forwardRemote(port: 80);
    print('Success localhost.run!');
    
    await Future.delayed(Duration(seconds: 5));
    exit(0);
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}
