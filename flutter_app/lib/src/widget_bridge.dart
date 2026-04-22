import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WidgetBridge {
  static const MethodChannel _channel = MethodChannel('neoagent/widgets');
  static const EventChannel _events = EventChannel('neoagent/widgets/events');

  static Stream<String>? _openWidgetRequests;

  Future<void> configureHomeWidgets({
    required bool enabled,
    required String backendUrl,
    required String sessionCookie,
  }) async {
    if (!_isAndroid) {
      return;
    }
    await _channel.invokeMethod('configureHomeWidgets', <String, dynamic>{
      'enabled': enabled,
      'backendUrl': backendUrl,
      'sessionCookie': sessionCookie,
    });
  }

  Future<void> syncNow() async {
    if (!_isAndroid) {
      return;
    }
    await _channel.invokeMethod('syncHomeWidgetsNow');
  }

  Stream<String> get openWidgetRequests {
    if (!_isAndroid) {
      return const Stream<String>.empty();
    }
    return _openWidgetRequests ??= _events
        .receiveBroadcastStream()
        .map((dynamic event) {
          if (event is Map) {
            return event['widgetId']?.toString() ?? '';
          }
          return event?.toString() ?? '';
        })
        .where((widgetId) => widgetId.trim().isNotEmpty);
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
