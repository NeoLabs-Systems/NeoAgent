import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppLaunchRequest {
  const AppLaunchRequest({
    required this.action,
    this.text,
    this.subject,
    this.files = const <Map<String, dynamic>>[],
  });

  factory AppLaunchRequest.fromEvent(dynamic event) {
    if (event is Map) {
      final map = Map<String, dynamic>.from(event);
      final files = (map['files'] is List)
          ? (map['files'] as List)
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : const <Map<String, dynamic>>[];
      return AppLaunchRequest(
        action: map['action']?.toString() ?? '',
        text: map['text']?.toString(),
        subject: map['subject']?.toString(),
        files: files,
      );
    }
    return AppLaunchRequest(action: event?.toString() ?? '');
  }

  final String action;
  final String? text;
  final String? subject;
  final List<Map<String, dynamic>> files;
}

class AppLaunchBridge {
  static const String voiceAssistantAction = 'voice_assistant';
  static const String shareToChatAction = 'share_to_chat';
  static const EventChannel _events = EventChannel(
    'neoagent/app_launch/events',
  );

  static Stream<AppLaunchRequest>? _launchRequests;

  Stream<AppLaunchRequest> get launchRequests {
    if (!_isAndroid) {
      return const Stream<AppLaunchRequest>.empty();
    }
    return _launchRequests ??= _events
        .receiveBroadcastStream()
        .map(AppLaunchRequest.fromEvent)
        .where((request) => request.action.trim().isNotEmpty);
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
