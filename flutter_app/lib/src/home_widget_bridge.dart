import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'diagnostics_logger.dart';

/// What the Android home-screen widgets show. The app publishes one whenever
/// the agent's state changes. Faces and labels live in the Android
/// resources, so the widgets animate and can refresh from the server while
/// the app is closed.
class HomeWidgetStatus {
  const HomeWidgetStatus({
    required this.mood,
    required this.detail,
    required this.live,
    required this.backendUrl,
    required this.sessionCookie,
    required this.agentId,
    this.callStartedAt,
  });

  /// `MascotMood.name`.
  final String mood;

  /// The work the agent is on, or empty.
  final String detail;

  /// The app is in the foreground and following the agent right now.
  final bool live;

  /// When the open voice call connected, or null without a call.
  final DateTime? callStartedAt;

  /// The sign-in the widgets refresh with while the app is closed; the
  /// cookie is empty when signed out.
  final String backendUrl;
  final String sessionCookie;
  final String agentId;

  Object get signature =>
      (mood, detail, live, callStartedAt, backendUrl, sessionCookie, agentId);
}

class HomeWidgetBridge {
  static const MethodChannel _channel = MethodChannel('neoagent/home_widgets');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> publish(HomeWidgetStatus status) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('publish', <String, Object?>{
        'mood': status.mood,
        'detail': status.detail,
        'live': status.live,
        'callStartedAtMs': status.callStartedAt?.millisecondsSinceEpoch,
        'backendUrl': status.backendUrl,
        'sessionCookie': status.sessionCookie,
        'agentId': status.agentId,
      });
    } catch (error) {
      AppDiagnostics.log('home_widgets', 'publish.failed', error: error);
    }
  }

  /// Sends the app to the background, back to the home screen the call
  /// widget was tapped on. The app keeps running, so the next call is quick.
  Future<void> returnToHomeScreen() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('returnToHomeScreen');
    } catch (error) {
      AppDiagnostics.log('home_widgets', 'return_home.failed', error: error);
    }
  }
}
