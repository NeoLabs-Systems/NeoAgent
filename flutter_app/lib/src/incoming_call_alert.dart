import 'incoming_call_alert_stub.dart'
    if (dart.library.html) 'incoming_call_alert_web.dart';

void showIncomingCallBrowserAlert(String callId, String agentName) {
  showPlatformIncomingCallBrowserAlert(callId, agentName);
}

void cancelIncomingCallBrowserAlert(String callId) {
  cancelPlatformIncomingCallBrowserAlert(callId);
}
