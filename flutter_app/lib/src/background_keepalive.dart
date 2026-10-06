import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const _channelId = 'neoagent_keepalive';

// The service has no work of its own: running as a foreground service keeps
// the app process, and with it the Socket.IO connection, alive in the
// background so agent calls and approvals can still arrive.
@pragma('vm:entry-point')
void _onServiceStart(ServiceInstance service) {}

class BackgroundKeepAlive {
  static bool _configured = false;

  static bool get supported => !kIsWeb && Platform.isAndroid;

  static Future<void> start({
    required String title,
    required String body,
  }) async {
    if (!supported) return;
    try {
      final service = FlutterBackgroundService();
      if (!_configured) {
        await FlutterLocalNotificationsPlugin()
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(
              AndroidNotificationChannel(
                _channelId,
                title,
                importance: Importance.low,
              ),
            );
        await service.configure(
          androidConfiguration: AndroidConfiguration(
            onStart: _onServiceStart,
            autoStart: false,
            isForegroundMode: true,
            notificationChannelId: _channelId,
            initialNotificationTitle: title,
            initialNotificationContent: body,
            foregroundServiceNotificationId: 7412,
            foregroundServiceTypes: <AndroidForegroundType>[
              AndroidForegroundType.dataSync,
            ],
          ),
          iosConfiguration: IosConfiguration(),
        );
        _configured = true;
      }
      if (!await service.isRunning()) await service.startService();
    } catch (error) {
      debugPrint('Background keep-alive unavailable: $error');
    }
  }

  static Future<void> stop() async {
    if (!supported || !_configured) return;
    try {
      final service = FlutterBackgroundService();
      if (await service.isRunning()) service.invoke('stopService');
    } catch (_) {}
  }
}
