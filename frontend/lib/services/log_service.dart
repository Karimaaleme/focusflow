import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import 'api_service.dart';

class LogService {
  static Future<void> error(String message, [Object? error, StackTrace? stack]) async {
    final detail = [
      if (error != null) 'Exception: $error',
      if (stack != null) 'Stack: $stack',
    ].join('\n');
    dev.log('ERROR: $message\n$detail', name: 'APP');
    await _send('error', message, detail);
  }

  static Future<void> info(String message) async {
    dev.log('INFO: $message', name: 'APP');
    await _send('info', message, '');
  }

  static Future<void> warn(String message) async {
    dev.log('WARN: $message', name: 'APP');
    await _send('warn', message, '');
  }

  static Future<void> _send(String level, String message, String detail) async {
    try {
      await http.post(
        Uri.parse('${ApiService.baseUrl}/logs'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'level': level, 'message': message, 'detail': detail}),
      ).timeout(const Duration(seconds: 3));
    } catch (_) {
      // Never crash the app because logging failed
    }
  }
}
