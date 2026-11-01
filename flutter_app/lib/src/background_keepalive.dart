import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android's background service: it keeps the app, and with it the
/// Socket.IO connection, alive in the background so agent calls and
/// approvals can still arrive. Android insists it shows a notification; it
/// sits on a minimum importance channel.
class BackgroundKeepAlive {
  static const MethodChannel _channel = MethodChannel('neoagent/background');

  static bool get supported => !kIsWeb && Platform.isAndroid;

  static Future<void> start({
    required String title,
    required String body,
  }) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('start', <String, Object?>{
        'title': title,
        'body': body,
      });
    } on PlatformException catch (error) {
      debugPrint('Background keep-alive unavailable: ${error.message}');
    }
  }

  static Future<void> stop() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException catch (_) {}
  }
}
