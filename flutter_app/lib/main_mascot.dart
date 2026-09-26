part of 'main.dart';

extension _MascotReading on NeoAgentController {
  /// The mascot's mood read straight off live state, and for done/blocked
  /// the run it belongs to. [MascotMoodStabilizer] decides what is shown.
  (MascotMood, Object?) get _mascotReading {
    if (!socketConnected) return (MascotMood.asleep, null);

    final threads = _coworkThreads.values;
    if (pendingApproval != null ||
        threads.any((thread) => thread.runStatus == 'waiting_input')) {
      return (MascotMood.waiting, null);
    }

    // An open call that is just waiting is not a conversation.
    if (isLiveVoiceCaptureEngaged || voiceAssistantLiveState.isSpeaking) {
      return (MascotMood.listening, null);
    }

    final run = activeRun;
    final foregroundLive = isSendingMessage && run != null;
    final coworkRunning = threads
        .where((thread) => thread.runStatus == 'running')
        .toList(growable: false);
    if ((foregroundLive &&
            toolEvents.any((event) => event.status == 'running')) ||
        voiceAssistantLiveState.hasActiveTask ||
        coworkRunning.any((thread) => thread.phase.startsWith('Running')) ||
        _hasUnwatchedLiveRun) {
      return (MascotMood.working, null);
    }
    if (foregroundLive || coworkRunning.isNotEmpty) {
      return (MascotMood.thinking, null);
    }

    final failedRunId = _failedForegroundRunId;
    if (failedRunId != null) return (MascotMood.blocked, failedRunId);
    if (run != null && run.phase == 'Completed') {
      return (MascotMood.done, run.runId);
    }
    return (MascotMood.idle, null);
  }

  /// A run the server lists as running that no open view is following —
  /// scheduled, task and messaging runs. Read from the run list rather than
  /// from socket events so a run whose end was missed during a disconnect
  /// cannot pin the mascot to working; the next refresh corrects it.
  bool get _hasUnwatchedLiveRun {
    final watched = <String?>{
      activeRun?.runId,
      _failedForegroundRunId,
      ..._voiceRunIds,
      for (final thread in _coworkThreads.values) thread.activeRunId,
    };
    return recentRuns.any(
      (run) => run.status == 'running' && !watched.contains(run.id),
    );
  }
}

/// The mascot following what the agent is doing right now.
class _LiveMascot extends StatefulWidget {
  const _LiveMascot({required this.controller, required this.size});

  final NeoAgentController controller;
  final double size;

  @override
  State<_LiveMascot> createState() => _LiveMascotState();
}

class _LiveMascotState extends State<_LiveMascot> {
  final MascotMoodStabilizer _stabilizer = MascotMoodStabilizer();
  Timer? _settleTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _read();
  }

  @override
  void didUpdateWidget(_LiveMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
      _read();
    }
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final before = _stabilizer.mood;
    _read();
    if (_stabilizer.mood != before) {
      setState(() {});
    }
  }

  void _read() {
    final (mood, moment) = widget.controller._mascotReading;
    _settleTimer?.cancel();
    final settleIn = _stabilizer.update(mood, moment: moment);
    if (settleIn != null) {
      _settleTimer = Timer(settleIn, _onChanged);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NeoMascot(mood: _stabilizer.mood, size: widget.size);
  }
}
