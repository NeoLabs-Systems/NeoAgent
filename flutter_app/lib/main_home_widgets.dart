part of 'main.dart';

/// Keeps the Android home-screen widgets on what the in-app mascot shows.
///
/// The controller notifies many times a second while a run streams, so
/// publishing is coalesced and skipped when nothing visible changed. Leaving
/// the foreground publishes at once: the process may be frozen right after,
/// and from then on the widgets follow the server themselves with the
/// sign-in published here.
class _HomeWidgetSync {
  _HomeWidgetSync(this._controller) {
    _controller.addListener(_onChanged);
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycleChanged);
    _onChanged();
  }

  static const Duration _coalesce = Duration(milliseconds: 500);

  final NeoAgentController _controller;
  final HomeWidgetBridge _bridge = HomeWidgetBridge();
  final MascotMoodStabilizer _stabilizer = MascotMoodStabilizer();
  late final AppLifecycleListener _lifecycle;
  bool _live =
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  Timer? _settleTimer;
  Timer? _publishTimer;
  Object? _published;

  void dispose() {
    _controller.removeListener(_onChanged);
    _lifecycle.dispose();
    _settleTimer?.cancel();
    _publishTimer?.cancel();
  }

  void _onLifecycleChanged(AppLifecycleState state) {
    final live = state == AppLifecycleState.resumed;
    if (live == _live) return;
    _live = live;
    _publishTimer?.cancel();
    _publishTimer = null;
    _publish();
  }

  void _onChanged() {
    final (mood, moment) = _controller._mascotReading;
    _settleTimer?.cancel();
    final settleIn = _stabilizer.update(mood, moment: moment);
    if (settleIn != null) {
      _settleTimer = Timer(settleIn, _onChanged);
    }
    _publishTimer ??= Timer(_coalesce, () {
      _publishTimer = null;
      _publish();
    });
  }

  void _publish() {
    final controller = _controller;
    final mood = _stabilizer.mood;
    final status = HomeWidgetStatus(
      mood: mood.name,
      detail: _detail(mood),
      live: _live,
      callStartedAt: controller.liveVoiceSessionStartedAt,
      backendUrl: controller.backendUrl,
      sessionCookie: controller.isAuthenticated
          ? controller.sessionCookie ?? ''
          : '',
      agentId: controller.selectedAgentId ?? '',
    );
    if (status.signature == _published) return;
    _published = status.signature;
    unawaited(_bridge.publish(status));
  }

  /// The title of the work the mood is about. Idle and offline name none,
  /// so a finished run does not read as current.
  String _detail(MascotMood mood) {
    if (mood == MascotMood.idle || mood == MascotMood.asleep) return '';
    final voiceTask = _controller.voiceAssistantLiveState.activeTaskRequest
        .trim();
    if (voiceTask.isNotEmpty || mood == MascotMood.listening) return voiceTask;
    final run = _controller.activeRun;
    if (run != null) return run.title.trim();
    for (final summary in _controller.recentRuns) {
      if (summary.isActive) return summary.title.trim();
    }
    return '';
  }
}
