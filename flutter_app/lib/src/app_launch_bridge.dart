import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppLaunchBridge {
  static const String voiceAssistantAction = 'voice_assistant';
  static const EventChannel _events = EventChannel(
    'neoagent/app_launch/events',
  );

  static Stream<String>? _launchRequests;

  Stream<String> get launchRequests {
    if (!_isAndroid) {
      return const Stream<String>.empty();
    }
    return _launchRequests ??= _events
        .receiveBroadcastStream()
        .map((dynamic event) {
          if (event is Map) {
            return event['action']?.toString() ?? '';
          }
          return event?.toString() ?? '';
        })
        .where((action) => action.trim().isNotEmpty);
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
