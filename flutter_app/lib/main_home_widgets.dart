part of 'main.dart';

/// Keeps the Android home-screen widgets on what the in-app mascot shows.
///
/// The controller notifies many times a second while a run streams, so
/// publishing is coalesced and skipped when nothing visible changed. Leaving
/// the foreground publishes at once: the process may be frozen right after,
/// and the widgets then have to say that what they show is the last known
/// state.
class _HomeWidgetSync {
  _HomeWidgetSync(this._controller) {
    _controller.addListener(_onChanged);
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycleChanged);
    _onChanged();
  }

  static const Duration _coalesce = Duration(milliseconds: 500);
  static const int _faceSize = 256;

  final NeoAgentController _controller;
  final HomeWidgetBridge _bridge = HomeWidgetBridge();
  final MascotMoodStabilizer _stabilizer = MascotMoodStabilizer();
  final Map<MascotMood, Uint8List> _faces = <MascotMood, Uint8List>{};
  late final AppLifecycleListener _lifecycle;
  bool _live =
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  Timer? _settleTimer;
  Timer? _publishTimer;
  Object? _published;

  /// Publishes run one after another, so a slow first face render cannot
  /// land after a newer state.
  Future<void> _publishing = Future<void>.value();

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
    _enqueuePublish();
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
      _enqueuePublish();
    });
  }

  void _enqueuePublish() {
    _publishing = _publishing.then((_) => _publish()).catchError((
      Object error,
    ) {
      AppDiagnostics.log('home_widgets', 'publish.failed', error: error);
    });
  }

  Future<void> _publish() async {
    final mood = _stabilizer.mood;
    final callStartedAt = _controller.liveVoiceSessionStartedAt;
    final label = _label(mood, onCall: callStartedAt != null);
    final detail = _detail(mood);
    final face = _faces[mood] ??= await renderMascotPng(mood, size: _faceSize);
    final status = HomeWidgetStatus(
      mood: mood.name,
      label: label,
      detail: detail,
      face: face,
      live: _live,
      callStartedAt: callStartedAt,
    );
    if (status.signature == _published) return;
    _published = status.signature;
    await _bridge.publish(status);
  }

  static String _label(MascotMood mood, {required bool onCall}) =>
      switch (mood) {
        MascotMood.idle => onCall ? 'On a call' : 'Ready',
        MascotMood.listening => 'Listening',
        MascotMood.thinking => 'Thinking',
        MascotMood.working => 'Working',
        MascotMood.waiting => 'Needs you',
        MascotMood.blocked => 'Blocked',
        MascotMood.done => 'Done',
        MascotMood.asleep => 'Offline',
      };

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
