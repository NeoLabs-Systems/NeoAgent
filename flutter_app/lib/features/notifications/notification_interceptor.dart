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

  bool _isListening = false;
  String _backendUrl = '';
  String _token = '';

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
      // Filter out noisy system notifications or ongoing foreground services
      if (event.packageName == null ||
          event.packageName!.contains('android.system')) {
        return;
      }

      // We only want to intercept newly posted notifications, not removed ones
      if (event.hasRemoved == true) return;

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
