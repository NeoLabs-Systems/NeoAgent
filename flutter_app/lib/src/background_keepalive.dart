import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Android insists a foreground service shows a notification. On a minimum
// importance channel it has no status bar icon, stays off the lock screen and
// sits collapsed at the bottom of the shade. Channel importance cannot change
// once created, hence a new id; the old louder channel is removed.
const _channelId = 'neoagent_background';
const _legacyChannelId = 'neoagent_keepalive';

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
        final notifications = FlutterLocalNotificationsPlugin()
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await notifications?.deleteNotificationChannel(_legacyChannelId);
        await notifications?.createNotificationChannel(
          AndroidNotificationChannel(
            _channelId,
            title,
            importance: Importance.min,
            showBadge: false,
            playSound: false,
            enableVibration: false,
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
