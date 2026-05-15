import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:notification_listener_service/notification_event.dart';

class NotificationInterceptor {
  static final NotificationInterceptor _instance =
      NotificationInterceptor._internal();
  factory NotificationInterceptor() => _instance;
  NotificationInterceptor._internal();

  static const Duration _perAppCooldown = Duration(seconds: 60);

  bool _isListening = false;
  String _backendUrl = '';
  String _token = '';
  final Map<String, DateTime> _lastTriggerTimes = {};

  Future<void> initialize(String backendUrl, String token) async {
    _backendUrl = backendUrl;
    _token = token;

    final isGranted = await NotificationListenerService.isPermissionGranted();
    if (isGranted && !_isListening) {
      _startListening();
    }
  }

  void _startListening() {
    _isListening = true;
    NotificationListenerService.notificationsStream.listen((
      ServiceNotificationEvent event,
    ) {
      if (event.packageName == null ||
          event.packageName!.contains('android.system')) {
        return;
      }

      // Skip removed notifications and persistent ongoing ones
      if (event.hasRemoved == true) return;
      if (event.onGoing == true) return;

      // Per-app cooldown to avoid flooding the backend
      final pkg = event.packageName!;
      final now = DateTime.now();
      final last = _lastTriggerTimes[pkg];
      if (last != null && now.difference(last) < _perAppCooldown) return;
      _lastTriggerTimes[pkg] = now;

      _sendToBackend(event);
    });
  }

  Future<void> _sendToBackend(ServiceNotificationEvent event) async {
    if (_backendUrl.isEmpty || _token.isEmpty) return;

    try {
      await http.post(
        Uri.parse('$_backendUrl/api/triggers/notification'),
        headers: {'Content-Type': 'application/json', 'Cookie': _token},
        body: jsonEncode({
          'app_package': event.packageName ?? 'unknown',
          'title': event.title ?? '',
          'body': event.content ?? '',
          'action_taken': 'intercepted',
        }),
      );
    } catch (e) {
      debugPrint('Failed to send notification to backend: $e');
    }
  }
}
