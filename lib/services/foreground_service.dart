import 'package:flutter/services.dart';

/// Обёртка над нативным foreground-сервисом TCP-сервера.
class TcpForegroundService {
  static const _channel = MethodChannel('tcp_foreground');

  static Future<void> start({
    required String title,
    required String text,
    String? bigText,
  }) async {
    await _channel.invokeMethod('start', {
      'title': title,
      'text': text,
      'bigText': bigText ?? text,
    });
  }

  static Future<void> stop() async {
    await _channel.invokeMethod('stop');
  }

  static Future<void> update({
    required String title,
    required String text,
    String? bigText,
  }) async {
    await _channel.invokeMethod('update', {
      'title': title,
      'text': text,
      'bigText': bigText ?? text,
    });
  }
}