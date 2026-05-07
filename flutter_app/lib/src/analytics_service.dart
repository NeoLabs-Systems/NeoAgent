import 'package:mixpanel_flutter/mixpanel_flutter.dart';

class AppAnalytics {
  Mixpanel? _mixpanel;
  bool _initialized = false;
  bool _enabled = false;
  String? _currentToken;
  bool _consentGranted = false;
  final List<_QueuedEvent> _queue = <_QueuedEvent>[];

  bool get enabled => _enabled && _consentGranted;
  bool get consentGranted => _consentGranted;
  bool get isConfigured => (_currentToken ?? '').isNotEmpty;

  Future<void> initialize({
    required String? token,
    required bool consentGranted,
  }) async {
    final normalizedToken = token?.trim() ?? '';
    final shouldEnable = normalizedToken.isNotEmpty;
    if (_initialized &&
        normalizedToken == _currentToken &&
        shouldEnable == _enabled &&
        consentGranted == _consentGranted) {
      return;
    }

    _consentGranted = consentGranted;
    _initialized = false;
    _enabled = false;
    _currentToken = normalizedToken.isEmpty ? null : normalizedToken;
    _mixpanel = null;

    if (!shouldEnable) {
      _queue.clear();
      _initialized = true;
      return;
    }

    if (!consentGranted) {
      _queue.clear();
      _initialized = true;
      return;
    }

    try {
      _mixpanel = await Mixpanel.init(
        normalizedToken,
        trackAutomaticEvents: false,
      );
      _enabled = true;
      _initialized = true;
      await _flushQueue();
    } catch (_) {
      _queue.clear();
      _mixpanel = null;
      _enabled = false;
      _initialized = true;
    }
  }

  Future<void> setConsentGranted(bool consentGranted) async {
    if (_consentGranted == consentGranted && _initialized) {
      return;
    }

    _consentGranted = consentGranted;
    if (!consentGranted) {
      _mixpanel = null;
      _enabled = false;
      _initialized = true;
      _queue.clear();
      return;
    }

    await initialize(token: _currentToken, consentGranted: true);
  }

  Future<void> track(
    String eventName, {
    Map<String, Object?> properties = const <String, Object?>{},
  }) async {
    final event = _QueuedEvent(
      eventName: eventName,
      properties: _cleanProperties(properties),
    );

    if (!_initialized) {
      _queue.add(event);
      return;
    }

    if (!enabled || _mixpanel == null) {
      return;
    }

    await _sendEvent(event);
  }

  Future<void> trackAppOpened({
    required String appMode,
    required String platform,
    required String backendMode,
    required String selectedSection,
    required String deploymentProfile,
    required bool authenticated,
  }) {
    return track(
      'app_opened',
      properties: <String, Object?>{
        'app_mode': appMode,
        'platform': platform,
        'backend_mode': backendMode,
        'selected_section': selectedSection,
        'deployment_profile': deploymentProfile,
        'authenticated': authenticated,
      },
    );
  }

  Future<void> trackBackendUrlSaved({
    required String backendMode,
  }) {
    return track(
      'backend_url_saved',
      properties: <String, Object?>{
        'backend_mode': backendMode,
      },
    );
  }

  Future<void> trackSectionChanged({
    required String section,
    required String previousSection,
  }) {
    return track(
      'section_changed',
      properties: <String, Object?>{
        'section': section,
        'previous_section': previousSection,
      },
    );
  }

  Future<void> trackChatMessageSent({
    required int length,
    required bool steeringLiveRun,
  }) {
    return track(
      'chat_message_sent',
      properties: <String, Object?>{
        'length': length,
        'steering_live_run': steeringLiveRun,
      },
    );
  }

  Future<void> trackRecordingStarted({
    required String kind,
  }) {
    return track(
      'recording_started',
      properties: <String, Object?>{
        'kind': kind,
      },
    );
  }

  Future<void> trackRecordingStopped({
    required String kind,
    required String stopReason,
  }) {
    return track(
      'recording_stopped',
      properties: <String, Object?>{
        'kind': kind,
        'stop_reason': stopReason,
      },
    );
  }

  Future<void> trackAppUpdateCheck({
    required bool silent,
  }) {
    return track(
      'app_update_check',
      properties: <String, Object?>{
        'silent': silent,
      },
    );
  }

  Future<void> trackTaskRunRequested({
    required int taskId,
  }) {
    return track(
      'task_run_requested',
      properties: <String, Object?>{
        'task_id': taskId,
      },
    );
  }

  Future<void> trackWidgetRefreshRequested({
    required bool all,
  }) {
    return track(
      'widget_refresh_requested',
      properties: <String, Object?>{
        'all': all,
      },
    );
  }

  Future<void> trackAppUpdateTriggered() {
    return track('app_update_triggered');
  }

  Future<void> trackSignedIn({
    required String authMethod,
    required bool isRegistration,
  }) {
    return track(
      'signed_in',
      properties: <String, Object?>{
        'auth_method': authMethod,
        'is_registration': isRegistration,
      },
    );
  }

  Future<void> trackSignedOut() {
    return track('signed_out');
  }

  Future<void> trackOnboardingDismissed() {
    return track('onboarding_dismissed');
  }

  Future<void> dispose() async {
    try {
      await _flushQueue();
    } catch (_) {}
    _queue.clear();
    _mixpanel = null;
    _initialized = false;
    _enabled = false;
    _currentToken = null;
    _consentGranted = false;
  }

  Future<void> _flushQueue() async {
    if (!enabled || _mixpanel == null || _queue.isEmpty) {
      return;
    }

    final pending = List<_QueuedEvent>.from(_queue);
    _queue.clear();
    for (final event in pending) {
      await _sendEvent(event);
    }
  }

  Future<void> _sendEvent(_QueuedEvent event) async {
    final mixpanel = _mixpanel;
    if (mixpanel == null) {
      return;
    }

    try {
      await mixpanel.track(event.eventName, properties: event.properties);
    } catch (_) {}
  }

  Map<String, Object?> _cleanProperties(Map<String, Object?> properties) {
    final cleaned = <String, Object?>{};
    for (final entry in properties.entries) {
      final value = entry.value;
      if (value == null) continue;
      cleaned[entry.key] = value;
    }
    return cleaned;
  }
}

class _QueuedEvent {
  const _QueuedEvent({
    required this.eventName,
    required this.properties,
  });

  final String eventName;
  final Map<String, Object?> properties;
}
