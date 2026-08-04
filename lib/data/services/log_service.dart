import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../di/injection.dart';
import 'webdav_service.dart';

class LogService {
  final List<String> _logs = [];

  void log(String message) {
    final time = DateTime.now().toIso8601String();
    final logMessage = '[$time] $message';
    debugPrint(logMessage);
    _logs.add(logMessage);
    if (_logs.length > 500) _logs.removeAt(0);
  }

  void error(String message, [dynamic error, StackTrace? stack]) {
    final time = DateTime.now().toIso8601String();
    final logMessage =
        '[$time] ERROR: $message\n${error ?? ''}\n${stack ?? ''}';
    debugPrint(logMessage);
    _logs.add(logMessage);
    if (_logs.length > 500) _logs.removeAt(0);
    _uploadLogsToWebDAV();
  }

  Future<void> _uploadLogsToWebDAV() async {
    try {
      final webdav = getIt<WebDAVService>();
      if (webdav.isConfigured) {
        final os = Platform.operatingSystem;
        final deviceName = Platform.localHostname.replaceAll(
          RegExp(r'[^a-zA-Z0-9_\-]'),
          '_',
        );
        final fileName = '${os}_${deviceName}_logs.txt';
        await webdav.uploadLog(_logs.join('\n'), fileName);
      }
    } catch (e) {
      debugPrint('Failed to auto-upload logs: $e');
    }
  }

  Future<bool> uploadManual() async {
    try {
      final webdav = getIt<WebDAVService>();
      if (webdav.isConfigured) {
        final os = Platform.operatingSystem;
        final deviceName = Platform.localHostname.replaceAll(
          RegExp(r'[^a-zA-Z0-9_\-]'),
          '_',
        );
        final fileName = '${os}_${deviceName}_logs.txt';
        return await webdav.uploadLog(_logs.join('\n'), fileName);
      }
      return false;
    } catch (e) {
      debugPrint('Failed to manually upload logs: $e');
      return false;
    }
  }
}
