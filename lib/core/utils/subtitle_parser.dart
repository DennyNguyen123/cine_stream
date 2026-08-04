import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import '../../domain/entities/subtitle.dart';

class SubtitleParser {
  static final List<List<String>> _knownKeys = [
    ['AmSmZVcH93UQUezi', 'ReBKWW8cqdjPEnF6'], // Newest key (txt1)
    ['8056483646328763', '6852612370185273'], // Older key (txt)
    ['sWODXX04QRTkHdlZ', '8pwhapJeC4hrS9hO'], // Default/Alternative key
  ];

  static List<SubtitleCue> parse(String content) {
    List<SubtitleCue> cues = [];
    final lines = const LineSplitter().convert(content);

    int state = 0; // 0: index or timestamp, 1: text
    String currentTimestamp = '';
    StringBuffer currentText = StringBuffer();

    for (String line in lines) {
      String trimmedLine = line.trim();

      if (trimmedLine.isEmpty) {
        if (currentTimestamp.isNotEmpty) {
          final times = _parseTimestamp(currentTimestamp);
          if (times != null) {
            String text = currentText.toString().trim();
            String decryptedText = _decryptSubtitleText(text);
            cues.add(
              SubtitleCue(
                startMs: times[0],
                endMs: times[1],
                text: decryptedText,
              ),
            );
          }
          currentTimestamp = '';
          currentText.clear();
          state = 0;
        }
        continue;
      }

      if (trimmedLine == 'WEBVTT') continue;

      if (state == 0) {
        if (trimmedLine.contains('-->')) {
          currentTimestamp = trimmedLine;
          state = 1;
        }
      } else if (state == 1) {
        if (currentText.isNotEmpty) {
          currentText.write('\n');
        }
        currentText.write(trimmedLine);
      }
    }

    // Add the last block if it wasn't followed by an empty line
    if (currentTimestamp.isNotEmpty) {
      final times = _parseTimestamp(currentTimestamp);
      if (times != null) {
        String text = currentText.toString().trim();
        String decryptedText = _decryptSubtitleText(text);
        cues.add(
          SubtitleCue(startMs: times[0], endMs: times[1], text: decryptedText),
        );
      }
    }

    return cues;
  }

  static String _decryptSubtitleText(String encryptedText) {
    if (encryptedText.contains('-->') ||
        encryptedText.contains('<i') ||
        encryptedText.contains('<b') ||
        encryptedText.contains('<i>')) {
      return encryptedText; // Probably not encrypted
    }

    try {
      final decodedBase64 = base64Decode(
        encryptedText.replaceAll('\n', '').replaceAll('\r', ''),
      );
      for (var pair in _knownKeys) {
        try {
          final key = Key.fromUtf8(pair[0]);
          final iv = IV.fromUtf8(pair[1]);
          final encrypter = Encrypter(
            AES(key, mode: AESMode.cbc, padding: 'PKCS7'),
          ); // PKCS7 is same as PKCS5

          final decrypted = encrypter.decrypt(Encrypted(decodedBase64), iv: iv);
          return decrypted;
        } catch (e) {
          // ignore and try next key
        }
      }
    } catch (e) {
      return encryptedText;
    }

    return encryptedText;
  }

  static List<int>? _parseTimestamp(String timestamp) {
    try {
      final parts = timestamp.split('-->');
      if (parts.length != 2) return null;
      int startMs = _timeToMs(parts[0].trim());
      int endMs = _timeToMs(parts[1].trim());
      return [startMs, endMs];
    } catch (e) {
      return null;
    }
  }

  static int _timeToMs(String timeStr) {
    final formatted = timeStr.replaceAll(',', '.');
    final parts = formatted.split(':');
    int hours = 0;
    int minutes = 0;
    String secondsAndMs = '';

    if (parts.length == 3) {
      hours = int.parse(parts[0]);
      minutes = int.parse(parts[1]);
      secondsAndMs = parts[2];
    } else if (parts.length == 2) {
      minutes = int.parse(parts[0]);
      secondsAndMs = parts[1];
    } else {
      secondsAndMs = parts[0];
    }

    final secParts = secondsAndMs.split('.');
    int seconds = int.parse(secParts[0]);
    int ms = 0;
    if (secParts.length == 2) {
      String rawMs = secParts[1];
      if (rawMs.length == 1) {
        ms = int.parse(rawMs) * 100;
      } else if (rawMs.length == 2) {
        ms = int.parse(rawMs) * 10;
      } else if (rawMs.length >= 3) {
        ms = int.parse(rawMs.substring(0, 3));
      }
    }

    return (hours * 3600 + minutes * 60 + seconds) * 1000 + ms;
  }
}
