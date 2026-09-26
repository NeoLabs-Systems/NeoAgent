import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'diagnostics_logger.dart';

/// What the Android home-screen widgets show. The app publishes one whenever
/// the agent's state changes; the widgets keep the last one while the app is
/// away.
class HomeWidgetStatus {
  const HomeWidgetStatus({
    required this.mood,
    required this.label,
    required this.detail,
    required this.face,
    required this.live,
    this.callStartedAt,
  });

  /// `MascotMood.name`; the widgets tint alert moods.
  final String mood;
  final String label;

  /// The work the agent is on, or empty.
  final String detail;

  /// The mascot's face for [mood] as PNG bytes.
  final Uint8List face;

  /// The app is in the foreground and following the agent right now.
  final bool live;

  /// When the open voice call connected, or null without a call.
  final DateTime? callStartedAt;

  /// Identity of what is on screen; [face] follows [mood].
  Object get signature => (mood, label, detail, live, callStartedAt);
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
        'label': status.label,
        'detail': status.detail,
        'face': status.face,
        'live': status.live,
        'callStartedAtMs': status.callStartedAt?.millisecondsSinceEpoch,
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
