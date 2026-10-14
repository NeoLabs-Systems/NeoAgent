// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'package:neoagent_flutter/src/l10n/app_language.dart';

final Map<String, html.Notification> _incomingCallNotifications =
    <String, html.Notification>{};

void showPlatformIncomingCallBrowserAlert(String callId, String agentName) {
  if (html.Notification.permission != 'granted') return;
  cancelPlatformIncomingCallBrowserAlert(callId);
  final notification = html.Notification(
    appStrings.incomingNeoagentCall,
    body: appStrings.arg1WantsToTalkWithYou(agentName),
    icon: '/icons/Icon-192.png',
    tag: 'agent-call-$callId',
  );
  notification.onClick.listen((_) {
    notification.close();
  });
  _incomingCallNotifications[callId] = notification;
}

void cancelPlatformIncomingCallBrowserAlert(String callId) {
  _incomingCallNotifications.remove(callId)?.close();
}
