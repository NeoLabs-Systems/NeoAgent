part of 'main.dart';

// ─── Runs page ─────────────────────────────────────────────────────────────
//
// Wide screens show the run list beside the selected run; phones show the list
// and push the run onto its own page. Both refresh themselves from run socket
// events (throttled), with a slow poll as a safety net while the socket is
// down or a run is still live.

const double _runsSplitMinWidth = 860;
const Duration _runsRefreshThrottle = Duration(milliseconds: 1500);
const Duration _runsSafetyPoll = Duration(seconds: 10);

enum _RunFilter { all, live, failed, completed }

String _runFilterLabel(_RunFilter filter) => switch (filter) {
  _RunFilter.all => 'All',
  _RunFilter.live => 'Live',
  _RunFilter.failed => 'Failed',
  _RunFilter.completed => 'Done',
};

Color? _runFilterColor(_RunFilter filter) => switch (filter) {
  _RunFilter.all => null,
  _RunFilter.live => _info,
  _RunFilter.failed => _danger,
  _RunFilter.completed => _success,
};

bool _runMatchesFilter(RunSummary run, _RunFilter filter) => switch (filter) {
  _RunFilter.all => true,
  _RunFilter.live => run.isActive,
  _RunFilter.failed => run.isFailure,
  _RunFilter.completed => run.status == 'completed',
};

/// Who started the run: a person writing in, or the system (tasks,
/// subagents, delegations).
enum _RunKind { all, messages, tasks }

String _runKindLabel(_RunKind kind) => switch (kind) {
  _RunKind.all => 'Everything',
  _RunKind.messages => 'Messages',
  _RunKind.tasks => 'Tasks',
};

bool _runMatchesKind(RunSummary run, _RunKind kind) => switch (kind) {
  _RunKind.all => true,
  _RunKind.messages => !run.isSystemRun,
  _RunKind.tasks => run.isSystemRun,
};

TextStyle _runMonoStyle({double size = 12, Color? color, FontWeight? weight}) {
  return TextStyle(
    fontFamily: GoogleFonts.geistMono().fontFamily,
    fontSize: size,
    fontWeight: weight,
    color: color ?? _textSecondary,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );
}

/// One-second wall clock for elapsed timers; only its listeners rebuild.
class _RunClock extends ValueNotifier<DateTime> {
  _RunClock() : super(DateTime.now()) {
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => value = DateTime.now(),
    );
  }

  late final Timer _timer;

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}

class RunsPanel extends StatefulWidget {
  const RunsPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<RunsPanel> createState() => _RunsPanelState();
}

class _RunsPanelState extends State<RunsPanel> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _listScroll = ScrollController();
  final _RunClock _clock = _RunClock();
  late final AppLifecycleListener _lifecycle;
  late final Timer _safetyPoll;
  Timer? _refreshTimer;
  DateTime _lastRefreshAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _refreshing = false;
  bool _refreshAgain = false;
  bool _appVisible = true;
  bool _paused = false;
  bool _split = true;

  _RunFilter _filter = _RunFilter.all;
  _RunKind _kind = _RunKind.all;
  String? _selectedRunId;

  /// Runs on screen. Lags the controller's list while new runs are held back.
  List<RunSummary> _runs = const <RunSummary>[];
  Set<String> _heldRunIds = const <String>{};
  Set<String> _freshRunIds = const <String>{};
  bool _adoptedOnce = false;

  NeoAgentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearchChanged);
    _listScroll.addListener(_onListScrolled);
    _controller.addListener(_onControllerChanged);
    _controller.runActivity.addListener(_scheduleRefresh);
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycleChanged);
    _safetyPoll = Timer.periodic(_runsSafetyPoll, (_) => _safetyRefresh());
    _adoptRuns(hold: false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openRequestedRun());
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.runActivity.removeListener(_scheduleRefresh);
    _refreshTimer?.cancel();
    _safetyPoll.cancel();
    _lifecycle.dispose();
    _clock.dispose();
    _search
      ..removeListener(_onSearchChanged)
      ..dispose();
    _listScroll
      ..removeListener(_onListScrolled)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() {});

  void _onControllerChanged() {
    if (!mounted) {
      return;
    }
    final scrolledAway = _listScroll.hasClients && _listScroll.offset > 4;
    setState(() => _adoptRuns(hold: _paused || scrolledAway));
    _openRequestedRun();
  }

  void _onListScrolled() {
    if (_heldRunIds.isNotEmpty && !_paused && _listScroll.offset <= 4) {
      setState(() => _adoptRuns(hold: false));
    }
  }

  void _onLifecycleChanged(AppLifecycleState state) {
    final visible =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    final becameVisible = visible && !_appVisible;
    _appVisible = visible;
    if (becameVisible) {
      _scheduleRefresh();
    }
  }

  /// Takes the controller's run list. Runs already on screen update in place;
  /// new ones slide in, or wait behind the "new runs" pill when [hold] is set
  /// so the list never shifts under the reader.
  void _adoptRuns({required bool hold}) {
    final incoming = _controller.recentRuns;
    final shownIds = _runs.map((run) => run.id).toSet();
    final holdNew = hold && _runs.isNotEmpty;
    final next = <RunSummary>[];
    final held = <String>{};
    for (final run in incoming) {
      if (holdNew && !shownIds.contains(run.id)) {
        held.add(run.id);
      } else {
        next.add(run);
      }
    }
    _freshRunIds = _adoptedOnce
        ? next
              .map((run) => run.id)
              .where((id) => !shownIds.contains(id))
              .toSet()
        : const <String>{};
    // A bot switch replaces the whole list; that is not a burst of new runs.
    _adoptedOnce = !_controller.isSwitchingAgent;
    _runs = next;
    _heldRunIds = held;
  }

  void _showHeldRuns() {
    setState(() => _adoptRuns(hold: false));
    if (_listScroll.hasClients) {
      unawaited(
        _listScroll.animateTo(
          0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  void _scheduleRefresh() {
    if (_paused || !_appVisible || _refreshTimer != null) {
      return;
    }
    final wait =
        _runsRefreshThrottle - DateTime.now().difference(_lastRefreshAt);
    _refreshTimer = Timer(wait.isNegative ? Duration.zero : wait, () {
      _refreshTimer = null;
      unawaited(_refresh());
    });
  }

  void _safetyRefresh() {
    if (!_controller.socketConnected || _runs.any((run) => run.isActive)) {
      _scheduleRefresh();
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) {
      _refreshAgain = true;
      return;
    }
    setState(() => _refreshing = true);
    _lastRefreshAt = DateTime.now();
    await _controller.refreshRunsOnly();
    if (!mounted) {
      return;
    }
    setState(() => _refreshing = false);
    if (_refreshAgain) {
      _refreshAgain = false;
      _scheduleRefresh();
    }
  }

  void _togglePaused() {
    setState(() => _paused = !_paused);
    if (!_paused) {
      _showHeldRuns();
      _scheduleRefresh();
    }
  }

  void _setFilter(_RunFilter filter) => setState(() => _filter = filter);

  void _setKind(_RunKind kind) => setState(() => _kind = kind);

  void _openRequestedRun() {
    final runId = _controller.requestedRunFocusId?.trim() ?? '';
    if (runId.isEmpty ||
        !_controller.recentRuns.any((run) => run.id == runId)) {
      return;
    }
    _controller.clearRequestedRunFocus(runId);
    setState(() {
      _adoptRuns(hold: false);
      _filter = _RunFilter.all;
      _kind = _RunKind.all;
    });
    _search.clear();
    _openRun(runId);
  }

  void _openRun(String runId) {
    if (_split) {
      setState(() => _selectedRunId = runId);
      return;
    }
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _RunDetailPage(
            controller: _controller,
            runId: runId,
            live: !_paused,
          ),
        ),
      ),
    );
  }

  /// Falls back to the first visible run and remembers it, so a run arriving
  /// at the top of the list never steals the open detail pane.
  String? _resolveSelection(List<RunSummary> visible) {
    if (!_runs.any((run) => run.id == _selectedRunId)) {
      _selectedRunId = _groupRuns(
        visible,
      ).map((entry) => entry.run?.id).nonNulls.firstOrNull;
    }
    return _selectedRunId;
  }

  List<RunSummary> get _visibleRuns {
    final query = _search.text.trim().toLowerCase();
    return _runs.where((run) {
      if (!_runMatchesKind(run, _kind) || !_runMatchesFilter(run, _filter)) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final haystack = <String>[
        run.title,
        run.status,
        run.model,
        run.triggerSource,
        run.error,
        run.id,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _PageTitle(
          title: appStrings.runs,
          subtitle: appStrings.liveExecutionHistoryToolStepsAnd,
          trailing: _RunsLiveControls(
            paused: _paused,
            connected: controller.socketConnected,
            refreshing: _refreshing,
            refreshedAt: controller.runsRefreshedAt,
            clock: _clock,
            onTogglePaused: _togglePaused,
            onRefresh: () {
              _showHeldRuns();
              unawaited(_refresh());
            },
            onShowHealth: () => showDialog<void>(
              context: context,
              builder: (_) => _RunHealthDialog(controller: controller),
            ),
          ),
        ),
        if (controller.errorMessage != null) ...<Widget>[
          _InlineError(
            message: controller.errorMessage!,
            onDismiss: controller.clearInlineError,
          ),
          const SizedBox(height: 12),
        ],
        Expanded(
          child: _runs.isEmpty && _heldRunIds.isEmpty
              ? Align(
                  alignment: Alignment.topCenter,
                  child: _EmptyCard(
                    title: appStrings.noRunsYet,
                    subtitle: appStrings.sendATaskFromChatAnd,
                    action: OutlinedButton.icon(
                      onPressed: () => controller.setSelectedSection(AppSection.chat),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: Text(appStrings.uxOpenChat),
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    _split = constraints.maxWidth >= _runsSplitMinWidth;
                    final visible = _visibleRuns;
                    final listPane = _buildListPane(visible);
                    if (!_split) {
                      return listPane;
                    }
                    final selectedId = _resolveSelection(visible);
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SizedBox(
                          width: constraints.maxWidth >= 1200 ? 400 : 340,
                          child: listPane,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              switchInCurve: Curves.easeOutCubic,
                              layoutBuilder: (current, previous) => Stack(
                                fit: StackFit.expand,
                                children: <Widget>[...previous, ?current],
                              ),
                              child: selectedId == null
                                  ? Center(
                                      child: _EmptyState(
                                        title: appStrings.selectARun,
                                        subtitle:
                                            appStrings.pickARunFromTheList,
                                      ),
                                    )
                                  : _RunDetailView(
                                      key: ValueKey<String>(selectedId),
                                      controller: controller,
                                      runId: selectedId,
                                      clock: _clock,
                                      live: !_paused,
                                      padding: const EdgeInsets.fromLTRB(
                                        24,
                                        22,
                                        24,
                                        28,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildListPane(List<RunSummary> visible) {
    final selectedId = _split ? _resolveSelection(visible) : null;
    final kindCounts = <_RunKind, int>{
      for (final kind in _RunKind.values)
        kind: _runs.where((run) => _runMatchesKind(run, kind)).length,
    };
    final counts = <_RunFilter, int>{
      for (final filter in _RunFilter.values)
        filter: _runs
            .where(
              (run) =>
                  _runMatchesKind(run, _kind) && _runMatchesFilter(run, filter),
            )
            .length,
    };
    final entries = _groupRuns(visible);
    final keyIndex = <Key, int>{
      for (final (index, entry) in entries.indexed) entry.key: index,
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                isDense: true,
                hintText: appStrings.searchTitleModelTriggerRunId,
                prefixIcon: Icon(Icons.search, size: 18),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: appStrings.clearSearch,
                        icon: Icon(Icons.close, size: 16),
                        onPressed: _search.clear,
                        visualDensity: VisualDensity.compact,
                      ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
              ),
            ),
          ),
          _RunFilterBar(
            groups: <Widget>[
              _RunChipGroup<_RunKind>(
                options: _RunKind.values,
                selected: _kind,
                counts: kindCounts,
                label: _runKindLabel,
                onChanged: _setKind,
              ),
              _RunChipGroup<_RunFilter>(
                options: _RunFilter.values,
                selected: _filter,
                counts: counts,
                label: _runFilterLabel,
                dotColor: _runFilterColor,
                onChanged: _setFilter,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: _border),
          Expanded(
            child: Stack(
              children: <Widget>[
                if (visible.isEmpty)
                  _RunListNoMatches(
                    onClear: () {
                      _search.clear();
                      setState(() {
                        _filter = _RunFilter.all;
                        _kind = _RunKind.all;
                      });
                    },
                  )
                else
                  ListView.builder(
                    controller: _listScroll,
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: entries.length,
                    findChildIndexCallback: (key) => keyIndex[key],
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final run = entry.run;
                      if (run == null) {
                        return _RunGroupHeader(
                          key: entry.key,
                          label: entry.header!,
                        );
                      }
                      return _RunListRow(
                        key: entry.key,
                        run: run,
                        selected: run.id == selectedId,
                        animateIn: _freshRunIds.contains(run.id),
                        clock: _clock,
                        onTap: () => _openRun(run.id),
                      );
                    },
                  ),
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _RunNewRunsPill(
                      count: _heldRunIds.length,
                      onPressed: _showHeldRuns,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

typedef _RunListEntry = ({Key key, String? header, RunSummary? run});

/// Live runs first, then everything else by day.
List<_RunListEntry> _groupRuns(List<RunSummary> runs) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  String groupOf(RunSummary run) {
    if (run.isActive) {
      return 'Live';
    }
    final created = run.createdAt;
    final day = DateTime(created.year, created.month, created.day);
    if (!day.isBefore(today)) {
      return appStrings.today;
    }
    if (!day.isBefore(yesterday)) {
      return appStrings.yesterday;
    }
    return appStrings.earlier;
  }

  final ordered = <RunSummary>[
    ...runs.where((run) => run.isActive),
    ...runs.where((run) => !run.isActive),
  ];
  final entries = <_RunListEntry>[];
  String? current;
  for (final run in ordered) {
    final group = groupOf(run);
    if (group != current) {
      current = group;
      entries.add((
        key: ValueKey<String>('group-$group'),
        header: group,
        run: null,
      ));
    }
    entries.add((
      key: ValueKey<String>('run-${run.id}'),
      header: null,
      run: run,
    ));
  }
  return entries;
}

// ── Live controls ─────────────────────────────────────────────────────────────

class _RunsLiveControls extends StatelessWidget {
  const _RunsLiveControls({
    required this.paused,
    required this.connected,
    required this.refreshing,
    required this.refreshedAt,
    required this.clock,
    required this.onTogglePaused,
    required this.onRefresh,
    required this.onShowHealth,
  });

  final VoidCallback onShowHealth;
  final bool paused;
  final bool connected;
  final bool refreshing;
  final DateTime? refreshedAt;
  final ValueListenable<DateTime> clock;
  final VoidCallback onTogglePaused;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final (color, label) = paused
        ? (_textMuted, 'Paused')
        : connected
        ? (_success, 'Live')
        : (_warning, 'Reconnecting');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _RunPulseDot(color: color, pulsing: !paused && connected),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  label,
                  key: ValueKey<String>(label),
                  style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!paused && refreshedAt != null) ...<Widget>[
                const SizedBox(width: 8),
                ValueListenableBuilder<DateTime>(
                  valueListenable: clock,
                  builder: (context, now, _) {
                    final seconds = now.difference(refreshedAt!).inSeconds;
                    final ago = seconds < 5
                        ? appStrings.justNow
                        : seconds < 60
                        ? appStrings.arg1SAgo(seconds)
                        : _relativeTime(refreshedAt!);
                    return Text(
                      appStrings.updatedArg1(ago),
                      style: TextStyle(color: _textSecondary, fontSize: 12),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: paused ? 'Resume live updates' : appStrings.pauseLiveUpdates,
          onPressed: onTogglePaused,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              key: ValueKey<bool>(paused),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Run health',
          onPressed: onShowHealth,
          icon: const Icon(Icons.monitor_heart_outlined),
        ),
        IconButton(
          tooltip: appStrings.refreshNow,
          onPressed: refreshing ? null : onRefresh,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: refreshing
                ? const SizedBox.square(
                    key: ValueKey<String>('refreshing'),
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.refresh_rounded,
                    key: ValueKey<String>('idle'),
                  ),
          ),
        ),
      ],
    );
  }
}

class _RunPulseDot extends StatefulWidget {
  const _RunPulseDot({required this.color, required this.pulsing});

  final Color color;
  final bool pulsing;

  @override
  State<_RunPulseDot> createState() => _RunPulseDotState();
}

class _RunPulseDotState extends State<_RunPulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _RunPulseDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    final animate = widget.pulsing && !MediaQuery.disableAnimationsOf(context);
    if (animate && !_pulse.isAnimating) {
      unawaited(_pulse.repeat());
    } else if (!animate && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = Curves.easeOut.transform(_pulse.value);
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              if (_pulse.isAnimating)
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.5 * (1 - t)),
                  spreadRadius: 6 * t,
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── List pieces ───────────────────────────────────────────────────────────────

/// Chip groups side by side in one scrolling row, split by a hairline.
class _RunFilterBar extends StatelessWidget {
  const _RunFilterBar({required this.groups});

  final List<Widget> groups;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: <Widget>[
          for (final (index, group) in groups.indexed) ...<Widget>[
            if (index > 0)
              Container(
                width: 1,
                height: 18,
                margin: const EdgeInsets.only(left: 4, right: 8),
                color: _border,
              ),
            group,
          ],
        ],
      ),
    );
  }
}

class _RunChipGroup<T> extends StatelessWidget {
  const _RunChipGroup({
    required this.options,
    required this.selected,
    required this.counts,
    required this.label,
    required this.onChanged,
    this.dotColor,
  });

  final List<T> options;
  final T selected;
  final Map<T, int> counts;
  final String Function(T) label;
  final Color? Function(T)? dotColor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = selected;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: options.map((option) {
        final selected = option == current;
        final dot = dotColor?.call(option);
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Semantics(
            button: true,
            selected: selected,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onChanged(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                decoration: BoxDecoration(
                  color: selected ? _bgTertiary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? _border : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (dot != null) ...<Widget>[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: dot,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label(option),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected ? _textPrimary : _textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.4),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: Text(
                        '${counts[option] ?? 0}',
                        key: ValueKey<int>(counts[option] ?? 0),
                        style: _runMonoStyle(size: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RunGroupHeader extends StatelessWidget {
  const _RunGroupHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        label.toUpperCase(),
        style: _sectionEyebrowStyle().copyWith(color: _textMuted),
      ),
    );
  }
}

class _RunListRow extends StatelessWidget {
  const _RunListRow({
    super.key,
    required this.run,
    required this.selected,
    required this.animateIn,
    required this.clock,
    required this.onTap,
  });

  final RunSummary run;
  final bool selected;
  final bool animateIn;
  final ValueListenable<DateTime> clock;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final row = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(13, 11, 16, 11),
          decoration: BoxDecoration(
            color: selected
                ? _accent.withValues(alpha: 0.10)
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: selected ? _accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: _RunStatusGlyph(status: run.status),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            run.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _RunTimeLabel(run: run, clock: clock),
                      ],
                    ),
                    const SizedBox(height: 3),
                    _buildSubtitle(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return animateIn ? _RunAppear(child: row) : row;
  }

  Widget _buildSubtitle() {
    if (run.isFailure && run.error.trim().isNotEmpty) {
      return Text(
        formatCaughtError(run.error.trim()),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: _danger),
      );
    }
    final details = <String>[
      if (!run.isActive) run.durationLabel,
      run.sourceLabel,
      run.isActive
          ? run.modelLabel
          : (run.totalTokens > 0 ? '${run.totalTokensLabel} tok' : ''),
    ].where((part) => part.isNotEmpty).join(' · ');
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          if (run.isActive)
            TextSpan(
              text: appStrings.arg12(run.statusLabel),
              style: TextStyle(
                color: run.statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          TextSpan(text: details),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12, color: _textMuted),
    );
  }
}

class _RunTimeLabel extends StatelessWidget {
  const _RunTimeLabel({required this.run, required this.clock});

  final RunSummary run;
  final ValueListenable<DateTime> clock;

  @override
  Widget build(BuildContext context) {
    if (!run.isActive) {
      return Text(
        _relativeTime(run.createdAt),
        style: TextStyle(fontSize: 12, color: _textSecondary),
      );
    }
    return ValueListenableBuilder<DateTime>(
      valueListenable: clock,
      builder: (context, now, _) => Text(
        _formatElapsed(now.difference(run.createdAt)),
        style: _runMonoStyle(color: run.statusColor, weight: FontWeight.w600),
      ),
    );
  }
}

class _RunStatusGlyph extends StatelessWidget {
  const _RunStatusGlyph({required this.status, this.size = 16});

  final String status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final key = ValueKey<String>(status);
    final Widget glyph = switch (status) {
      'running' => Padding(
        key: key,
        padding: const EdgeInsets.all(1.5),
        child: CircularProgressIndicator(strokeWidth: 2, color: _info),
      ),
      'completed' => Icon(
        Icons.check_circle_outline_rounded,
        key: key,
        size: size,
        color: _success,
      ),
      'failed' || 'error' => Icon(
        Icons.cancel_outlined,
        key: key,
        size: size,
        color: _danger,
      ),
      'paused' || 'waiting_input' => Icon(
        Icons.pause_circle_outline_rounded,
        key: key,
        size: size,
        color: _warning,
      ),
      'stopped' || 'interrupted' => Icon(
        Icons.stop_circle_outlined,
        key: key,
        size: size,
        color: _textMuted,
      ),
      _ => Icon(
        Icons.radio_button_unchecked_rounded,
        key: key,
        size: size,
        color: _textMuted,
      ),
    };
    return SizedBox.square(
      dimension: size,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: glyph,
      ),
    );
  }
}

/// Grows a newly inserted row open from zero height and fades it in.
class _RunAppear extends StatefulWidget {
  const _RunAppear({required this.child});

  final Widget child;

  @override
  State<_RunAppear> createState() => _RunAppearState();
}

class _RunAppearState extends State<_RunAppear>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  )..forward();
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return SizeTransition(
      sizeFactor: _curve,
      // `alignment` needs Flutter 3.41; updates from older CLIs still build here.
      // ignore: deprecated_member_use
      axisAlignment: -1,
      child: FadeTransition(
        opacity: _curve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.2),
            end: Offset.zero,
          ).animate(_curve),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Fades its child between dim and full to mark something still in progress.
class _RunBreathing extends StatefulWidget {
  const _RunBreathing({required this.child});

  final Widget child;

  @override
  State<_RunBreathing> createState() => _RunBreathingState();
}

class _RunBreathingState extends State<_RunBreathing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.45,
        end: 1,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

class _RunNewRunsPill extends StatelessWidget {
  const _RunNewRunsPill({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final visible = count > 0;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        offset: visible ? Offset.zero : const Offset(0, -1.4),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: visible ? 1 : 0,
          child: FilledButton.icon(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              shape: const StadiumBorder(),
              elevation: 6,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            icon: Icon(Icons.arrow_upward_rounded, size: 15),
            label: Text(
              count == 1 ? '1 new run' : appStrings.arg1NewRuns(count),
            ),
          ),
        ),
      ),
    );
  }
}

class _RunListNoMatches extends StatelessWidget {
  const _RunListNoMatches({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              appStrings.noRunsMatchTheseFilters,
              style: TextStyle(color: _textSecondary),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: onClear,
              child: Text(appStrings.clearFilters),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Run detail ────────────────────────────────────────────────────────────────

/// Phone layout: the run on its own page, pushed from the list.
class _RunDetailPage extends StatefulWidget {
  const _RunDetailPage({
    required this.controller,
    required this.runId,
    required this.live,
  });

  final NeoAgentController controller;
  final String runId;
  final bool live;

  @override
  State<_RunDetailPage> createState() => _RunDetailPageState();
}

class _RunDetailPageState extends State<_RunDetailPage> {
  final _RunClock _clock = _RunClock();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPrimary,
      appBar: AppBar(
        title: Text(appStrings.run),
        backgroundColor: _bgPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: _RunDetailView(
          controller: widget.controller,
          runId: widget.runId,
          clock: _clock,
          live: widget.live,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          onDeleted: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}

class _RunDetailView extends StatefulWidget {
  const _RunDetailView({
    super.key,
    required this.controller,
    required this.runId,
    required this.clock,
    required this.live,
    required this.padding,
    this.onDeleted,
  });

  final NeoAgentController controller;
  final String runId;
  final ValueListenable<DateTime> clock;
  final bool live;
  final EdgeInsets padding;
  final VoidCallback? onDeleted;

  @override
  State<_RunDetailView> createState() => _RunDetailViewState();
}

class _RunDetailViewState extends State<_RunDetailView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);
  final ScrollController _scroll = ScrollController();
  late final Timer _safetyPoll;
  Timer? _fetchTimer;
  DateTime _lastFetchAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _fetching = false;
  bool _fetchAgain = false;

  RunDetailSnapshot? _detail;
  bool _loading = true;
  String? _error;
  Set<String> _seenStepIds = const <String>{};
  Set<String> _freshStepIds = const <String>{};
  final Set<String> _expandedStepIds = <String>{};
  String? _graphNodeId;

  NeoAgentController get _controller => widget.controller;

  RunSummary? get _summary =>
      _controller.recentRuns.where((run) => run.id == widget.runId).firstOrNull;

  RunSummary? get _run => _detail?.run ?? _summary;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_onTabChanged);
    _controller.addListener(_onControllerChanged);
    _controller.runActivity.addListener(_onRunActivity);
    _safetyPoll = Timer.periodic(_runsSafetyPoll, (_) {
      if (_run?.isActive ?? false) {
        _scheduleFetch();
      }
    });
    unawaited(_fetch(force: false));
  }

  @override
  void didUpdateWidget(covariant _RunDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.live && !oldWidget.live) {
      _scheduleFetch();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.runActivity.removeListener(_onRunActivity);
    _fetchTimer?.cancel();
    _safetyPoll.cancel();
    _tabs
      ..removeListener(_onTabChanged)
      ..dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabs.indexIsChanging) {
      setState(() {});
    }
  }

  /// The list refresh may learn about a status change before this run's own
  /// events arrive; catch up when the two disagree.
  void _onControllerChanged() {
    final summary = _summary;
    final detail = _detail;
    if (summary != null &&
        detail != null &&
        summary.status != detail.run.status) {
      _scheduleFetch();
    }
  }

  void _onRunActivity() {
    final runId = _controller.runActivity.value.runId;
    if (runId == widget.runId || (runId.isEmpty && (_run?.isActive ?? false))) {
      _scheduleFetch();
    }
  }

  void _scheduleFetch() {
    if (!widget.live || _fetchTimer != null) {
      return;
    }
    final wait = _runsRefreshThrottle - DateTime.now().difference(_lastFetchAt);
    _fetchTimer = Timer(wait.isNegative ? Duration.zero : wait, () {
      _fetchTimer = null;
      unawaited(_fetch(force: true));
    });
  }

  bool get _isNearBottom =>
      !_scroll.hasClients || _scroll.position.extentAfter < 160;

  Future<void> _fetch({required bool force}) async {
    if (_fetching) {
      _fetchAgain = true;
      return;
    }
    _fetching = true;
    _lastFetchAt = DateTime.now();
    try {
      final detail = await _controller.fetchRunDetail(
        widget.runId,
        force: force,
      );
      if (!mounted) {
        return;
      }
      final followTail = _isNearBottom;
      final stepIds = detail.steps.map((step) => step.id).toSet();
      setState(() {
        _freshStepIds = _detail == null
            ? const <String>{}
            : stepIds.difference(_seenStepIds);
        _seenStepIds = stepIds;
        _detail = detail;
        _loading = false;
        _error = null;
      });
      if (followTail &&
          _freshStepIds.isNotEmpty &&
          detail.run.isActive &&
          _tabs.index == 0) {
        _scrollToEnd();
      }
    } catch (error, stackTrace) {
      AppDiagnostics.log(
        'runs.ui',
        'detail.fetch_failed',
        data: <String, Object?>{'runId': widget.runId},
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }
      // A failed live refresh keeps the last good snapshot on screen.
      setState(() {
        _loading = false;
        if (_detail == null) {
          _error = _controller.friendlyErrorMessage(error);
        }
      });
    } finally {
      _fetching = false;
      if (_fetchAgain && mounted) {
        _fetchAgain = false;
        _scheduleFetch();
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) {
        return;
      }
      unawaited(
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  void _toggleStep(String stepId) {
    setState(() {
      if (!_expandedStepIds.remove(stepId)) {
        _expandedStepIds.add(stepId);
      }
    });
  }

  Future<void> _copy(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showPrompt() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) =>
          _RunPromptDialog(controller: _controller, runId: widget.runId),
    );
  }

  Future<void> _resume() async {
    await _controller.resumeRun(widget.runId);
    _scheduleFetch();
  }

  Future<void> _stop() async {
    await _controller.stopRun(widget.runId);
    _scheduleFetch();
  }

  Future<void> _delete(RunSummary run) async {
    await _confirmDelete(
      context,
      title: appStrings.deleteRun,
      message: appStrings.removeArg1AndItsRecordedSteps(run.title),
      onConfirm: () async {
        await _controller.deleteRun(run.id);
        widget.onDeleted?.call();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final run = _run;
    if (run == null) {
      return _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: _EmptyState(
                title: appStrings.runNotFound,
                subtitle: appStrings.itMayHaveBeenDeleted,
              ),
            );
    }
    final detail = _detail;
    final response = detail?.response.trim() ?? '';
    return SingleChildScrollView(
      controller: _scroll,
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _RunDetailHeader(
            run: run,
            onStop: run.isActive ? _stop : null,
            onResume: run.status == 'paused' ? _resume : null,
            onCopyResponse: response.isEmpty
                ? null
                : () => _copy(response, appStrings.copiedFinalResponse),
            onShowPrompt: _showPrompt,
            onCopyId: () => _copy(run.id, appStrings.copiedRunId),
            onDelete: () => _delete(run),
          ),
          const SizedBox(height: 16),
          _RunStatsStrip(run: run, detail: detail, clock: widget.clock),
          if (run.isFailure && run.error.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _InlineError(message: formatCaughtError(run.error.trim())),
          ],
          const SizedBox(height: 14),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: _border,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            tabs: <Widget>[
              Tab(text: 'Timeline'),
              Tab(text: 'Response'),
              Tab(text: appStrings.flowGraph),
              const Tab(text: 'Telemetry'),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: <Widget>[...previous, ?current],
            ),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.02),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey<int>(_tabs.index),
              child: _buildTab(run, detail),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(RunSummary run, RunDetailSnapshot? detail) {
    if (detail == null) {
      if (_error != null) {
        return _InlineError(message: _error!);
      }
      return const _RunSkeleton();
    }
    switch (_tabs.index) {
      case 1:
        if (run.isActive && detail.response.trim().isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              appStrings.theFinalResponseAppearsHereWhenThe,
              style: TextStyle(color: _textSecondary),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _RunResponseCard(
              response: detail.response,
              onCopy: () => _copy(detail.response, appStrings.copiedFinalResponse),
            ),
            if (detail.run.deliverableType.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              _DeliverableSummaryCard(run: detail.run),
            ],
          ],
        );
      case 3:
        return RunTelemetryView(detail: detail);
      case 2:
        final step = detail.steps
            .where((item) => item.id == _graphNodeId)
            .firstOrNull;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _RunFlowGraphCanvas(
              run: run,
              detail: detail,
              loading: false,
              errorMessage: null,
              selectedNodeId: _graphNodeId,
              onNodeSelected: (id) => setState(() => _graphNodeId = id),
            ),
            if (step != null) ...<Widget>[
              const SizedBox(height: 12),
              _RunSelectedStepCard(step: step),
            ],
          ],
        );
      default:
        return _RunWaterfall(
          run: run,
          steps: detail.steps,
          clock: widget.clock,
          expandedStepIds: _expandedStepIds,
          freshStepIds: _freshStepIds,
          onToggle: _toggleStep,
        );
    }
  }
}

class _RunDetailHeader extends StatelessWidget {
  const _RunDetailHeader({
    required this.run,
    required this.onStop,
    required this.onResume,
    required this.onCopyResponse,
    required this.onShowPrompt,
    required this.onCopyId,
    required this.onDelete,
  });

  final RunSummary run;
  final Future<void> Function()? onStop;
  final Future<void> Function()? onResume;
  final VoidCallback? onCopyResponse;
  final Future<void> Function() onShowPrompt;
  final VoidCallback onCopyId;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            _RunStatusBadge(run: run),
            Text(
              appStrings.arg1Arg22(
                run.sourceLabel,
                _relativeTime(run.createdAt),
              ),
              style: TextStyle(color: _textSecondary, fontSize: 12.5),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          run.title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 20,
            height: 1.25,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: _textPrimary,
          ),
        ),
      ],
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        if (onResume != null)
          FilledButton.icon(
            onPressed: onResume,
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: Text(appStrings.resumeTask),
          ),
        if (onStop != null)
          FilledButton.tonalIcon(
            onPressed: onStop,
            style: FilledButton.styleFrom(
              backgroundColor: _danger.withValues(alpha: 0.14),
              foregroundColor: _danger,
            ),
            icon: Icon(Icons.stop_rounded, size: 18),
            label: Text(appStrings.stopRun),
          ),
        OutlinedButton.icon(
          onPressed: onCopyResponse,
          icon: Icon(Icons.copy_all_outlined, size: 17),
          label: Text(appStrings.copyResponse),
        ),
        PopupMenuButton<String>(
          tooltip: appStrings.moreActions,
          icon: Icon(Icons.more_horiz_rounded),
          onSelected: (value) {
            switch (value) {
              case 'prompt':
                unawaited(onShowPrompt());
              case 'id':
                onCopyId();
              case 'delete':
                unawaited(onDelete());
            }
          },
          itemBuilder: (context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'prompt',
              child: ListTile(
                leading: Icon(Icons.article_outlined),
                title: Text(appStrings.fullPrompt),
              ),
            ),
            PopupMenuItem<String>(
              value: 'id',
              child: ListTile(
                leading: Icon(Icons.tag_rounded),
                title: Text(appStrings.copyRunId),
              ),
            ),
            PopupMenuItem<String>(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete_outline, color: _danger),
                title: Text(
                  appStrings.deleteRun2,
                  style: TextStyle(color: _danger),
                ),
              ),
            ),
          ],
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[heading, const SizedBox(height: 12), actions],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: heading),
            const SizedBox(width: 16),
            actions,
          ],
        );
      },
    );
  }
}

class _RunStatusBadge extends StatelessWidget {
  const _RunStatusBadge({required this.run});

  final RunSummary run;

  @override
  Widget build(BuildContext context) {
    final color = run.statusColor;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _RunStatusGlyph(status: run.status, size: 14),
          const SizedBox(width: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              run.statusLabel,
              key: ValueKey<String>(run.status),
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RunStatsStrip extends StatelessWidget {
  const _RunStatsStrip({
    required this.run,
    required this.detail,
    required this.clock,
  });

  final RunSummary run;
  final RunDetailSnapshot? detail;
  final ValueListenable<DateTime> clock;

  @override
  Widget build(BuildContext context) {
    final steps = detail?.steps.length;
    final failed = detail?.failedTools ?? 0;
    final cells = <(String, Widget)>[
      (
        'Duration',
        run.isActive
            ? ValueListenableBuilder<DateTime>(
                valueListenable: clock,
                builder: (context, now, _) => _value(
                  _formatElapsed(now.difference(run.createdAt)),
                  color: _info,
                ),
              )
            : _value(run.durationLabel),
      ),
      ('Tokens', _RunCountUp(value: run.totalTokens)),
      (
        'Steps',
        steps == null
            ? _value('—')
            : Row(
                children: <Widget>[
                  _RunCountUp(value: steps),
                  if (failed > 0)
                    Flexible(
                      child: _value(
                        appStrings.arg1Failed(failed),
                        color: _danger,
                      ),
                    ),
                ],
              ),
      ),
      ('Model', _value(run.modelLabel)),
      ('Trigger', _value(run.triggerLabel)),
      ('Started', _value(_formatTimestamp(run.createdAt))),
      if (detail?.metrics case final metrics?) ...<(String, Widget)>[
        (
          'First action',
          _value(
            metrics.firstActionMs == null
                ? '—'
                : _formatDuration(metrics.firstActionMs!),
          ),
        ),
        ('Turns', _value('${metrics.turns}')),
        (
          'Tools',
          _value(
            metrics.toolsSuppressed > 0
                ? '${metrics.toolCalls} / ${metrics.toolsSuppressed} suppressed'
                : '${metrics.toolCalls}',
          ),
        ),
        (
          'In / out',
          _value(
            '${_formatCompactCount(metrics.inputTokens)} / ${_formatCompactCount(metrics.outputTokens)}',
          ),
        ),
        (
          'Memory',
          _value(
            '${metrics.memoryRecalls} / ${_formatCompactCount(metrics.memoryTokens)} tokens',
          ),
        ),
        (
          'Delivery',
          _value(
            metrics.deliverySuppressed > 0
                ? '${metrics.deliverySent} / ${metrics.deliverySuppressed} duplicate stopped'
                : '${metrics.deliverySent}',
          ),
        ),
      ],
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 6
            : constraints.maxWidth >= 420
            ? 3
            : 2;
        const gap = 8.0;
        final cellWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cells.map((cell) {
            return Container(
              width: cellWidth,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
              decoration: BoxDecoration(
                color: _bgSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    cell.$1.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                      color: _textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  cell.$2,
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  static Widget _value(String text, {Color? color}) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _runMonoStyle(
        size: 14,
        color: color ?? _textPrimary,
        weight: FontWeight.w500,
      ),
    );
  }
}

/// Counts up to [value], and eases between values as it changes live.
class _RunCountUp extends StatelessWidget {
  const _RunCountUp({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.toDouble()),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, current, _) =>
          _RunStatsStrip._value(_formatNumber(current.round())),
    );
  }
}

class _RunSkeleton extends StatelessWidget {
  const _RunSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double width) => Container(
      width: width,
      height: 10,
      decoration: BoxDecoration(
        color: _bgTertiary,
        borderRadius: BorderRadius.circular(4),
      ),
    );
    return _RunBreathing(
      child: Column(
        children: List<Widget>.generate(6, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              children: <Widget>[
                bar(20),
                const SizedBox(width: 12),
                bar(90.0 + (index * 37) % 80),
                const SizedBox(width: 16),
                Expanded(
                  child: FractionallySizedBox(
                    alignment: Alignment(-1 + index * 0.3, 0),
                    widthFactor: 0.2 + (index % 3) * 0.15,
                    child: bar(double.infinity),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ── Waterfall timeline ────────────────────────────────────────────────────────

/// Step classification shared by the timeline and the flow graph.
String _runStepKind(RunStepItem step) {
  final lower = appStrings.arg1Arg23(step.type, step.toolName).toLowerCase();
  if (lower.contains('model') ||
      lower.contains('think') ||
      lower.contains('llm')) {
    return 'model';
  }
  if (lower.contains('plan')) {
    return 'plan';
  }
  if (lower.contains('subagent') ||
      lower.contains('helper') ||
      lower.contains('delegat')) {
    return 'subagent';
  }
  if (lower.contains('verif')) {
    return 'verify';
  }
  if (lower.contains('note') || lower.contains('analysis')) {
    return 'note';
  }
  return 'tool';
}

Color _runStepKindColor(String kind) => switch (kind) {
  'model' => _info,
  'plan' => _warning,
  'subagent' => _accentHover,
  'verify' => const Color(0xFF8B5CF6),
  _ => _success,
};

String _runStepKindLabel(String kind) => switch (kind) {
  'model' => 'Model',
  'plan' => 'Plan',
  'subagent' => 'Agent',
  'verify' => 'Verify',
  'note' => 'Note',
  _ => 'Tool',
};

typedef _RunStepSpan = ({RunStepItem step, Duration start, Duration end});

class _RunWaterfall extends StatelessWidget {
  const _RunWaterfall({
    required this.run,
    required this.steps,
    required this.clock,
    required this.expandedStepIds,
    required this.freshStepIds,
    required this.onToggle,
  });

  final RunSummary run;
  final List<RunStepItem> steps;
  final ValueListenable<DateTime> clock;
  final Set<String> expandedStepIds;
  final Set<String> freshStepIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Row(
          children: <Widget>[
            if (run.isActive) ...<Widget>[
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
            ],
            Text(
              run.isActive
                  ? appStrings.waitingForTheFirstStep
                  : appStrings.noStepsWereRecordedForThis,
              style: TextStyle(color: _textSecondary),
            ),
          ],
        ),
      );
    }
    if (!run.isActive) {
      return _buildTimeline(run.completedAt ?? run.createdAt);
    }
    return ValueListenableBuilder<DateTime>(
      valueListenable: clock,
      builder: (context, now, _) => _buildTimeline(now),
    );
  }

  Widget _buildTimeline(DateTime runEnd) {
    final origin = run.createdAt;
    final spans = <_RunStepSpan>[];
    var cursor = Duration.zero;
    for (final step in steps) {
      var start = step.startedAt?.difference(origin) ?? cursor;
      if (start.isNegative) {
        start = Duration.zero;
      }
      var end =
          step.completedAt?.difference(origin) ??
          (step.status == 'running' ? runEnd.difference(origin) : start);
      if (end < start) {
        end = start;
      }
      spans.add((step: step, start: start, end: end));
      if (end > cursor) {
        cursor = end;
      }
    }
    final runLength = runEnd.difference(origin);
    final total = <Duration>[
      runLength,
      cursor,
      const Duration(seconds: 1),
    ].reduce((a, b) => a > b ? a : b);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final nameWidth = (constraints.maxWidth * 0.26).clamp(140.0, 260.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (!compact) _buildAxis(total, nameWidth),
            for (final (index, span) in spans.indexed)
              _RunWaterfallRow(
                key: ValueKey<String>(span.step.id),
                index: index,
                span: span,
                total: total,
                runEnd: runEnd,
                compact: compact,
                nameWidth: nameWidth,
                isLast: index == spans.length - 1,
                expanded: expandedStepIds.contains(span.step.id),
                animateIn: freshStepIds.contains(span.step.id),
                onTap: () => onToggle(span.step.id),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: <Widget>[
                for (final kind in const <String>[
                  'model',
                  'tool',
                  'plan',
                  'subagent',
                  'verify',
                ])
                  _GraphLegendChip(
                    color: _runStepKindColor(kind),
                    label: _runStepKindLabel(kind),
                  ),
                _GraphLegendChip(color: _danger, label: 'Failed'),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildAxis(Duration total, double nameWidth) {
    final style = _runMonoStyle(size: 11, color: _textMuted);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: <Widget>[
          SizedBox(width: _RunWaterfallRow.leadWidth + nameWidth + 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                for (var i = 0; i <= 4; i++)
                  Text(
                    _formatElapsed(
                      Duration(milliseconds: total.inMilliseconds * i ~/ 4),
                    ),
                    style: style,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12 + _RunWaterfallRow.durationWidth + 8),
        ],
      ),
    );
  }
}

class _RunWaterfallRow extends StatelessWidget {
  const _RunWaterfallRow({
    super.key,
    required this.index,
    required this.span,
    required this.total,
    required this.runEnd,
    required this.compact,
    required this.nameWidth,
    required this.isLast,
    required this.expanded,
    required this.animateIn,
    required this.onTap,
  });

  /// Width of the step number and kind chip before the step name.
  static const double leadWidth = 8 + 22 + 8 + 50 + 10;
  static const double durationWidth = 64;

  final int index;
  final _RunStepSpan span;
  final Duration total;
  final DateTime runEnd;
  final bool compact;
  final double nameWidth;
  final bool isLast;
  final bool expanded;
  final bool animateIn;
  final VoidCallback onTap;

  RunStepItem get _step => span.step;

  bool get _running => _step.status == 'running';

  Color get _color => _step.status == 'failed'
      ? _danger
      : _runStepKindColor(_runStepKind(_step));

  String get _durationLabel {
    if (_running && _step.startedAt != null) {
      return _formatElapsed(runEnd.difference(_step.startedAt!));
    }
    return _step.durationLabel ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: expanded ? _bgSecondary : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: expanded ? _border : Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: compact ? _buildCompactHeader() : _buildWideHeader(),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? _RunStepDetails(step: _step, compact: compact)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
    return animateIn ? _RunAppear(child: body) : body;
  }

  Widget _buildWideHeader() {
    final kind = _runStepKind(_step);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 9, 8, 9),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 22,
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.right,
              style: _runMonoStyle(size: 11, color: _textMuted),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 50,
            padding: const EdgeInsets.symmetric(vertical: 2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _runStepKindColor(kind).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              _runStepKindLabel(kind).toUpperCase(),
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: _runStepKindColor(kind),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: nameWidth,
            child: Text(
              _step.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _runMonoStyle(size: 13, color: _textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _buildBar(height: 10)),
          const SizedBox(width: 12),
          SizedBox(
            width: durationWidth,
            child: Text(
              _durationLabel,
              textAlign: TextAlign.right,
              style: _runMonoStyle(color: _running ? _info : _textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactHeader() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 28,
            child: Column(
              children: <Widget>[
                const SizedBox(height: 14),
                _running
                    ? _RunPulseDot(color: _info, pulsing: true)
                    : Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: _color,
                          shape: BoxShape.circle,
                        ),
                      ),
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.only(top: 4),
                    color: isLast ? Colors.transparent : _border,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 9, 10, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _step.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _runMonoStyle(size: 13.5, color: _textPrimary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _durationLabel,
                        style: _runMonoStyle(
                          color: _running ? _info : _textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  _buildBar(height: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar({required double height}) {
    final totalMs = total.inMilliseconds;
    final startFraction = span.start.inMilliseconds / totalMs;
    final widthFraction = (span.end - span.start).inMilliseconds / totalMs;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final bar = DecoratedBox(
            decoration: BoxDecoration(
              color: _color,
              borderRadius: BorderRadius.circular(height / 2.5),
              boxShadow: _running
                  ? <BoxShadow>[
                      BoxShadow(
                        color: _color.withValues(alpha: 0.45),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          );
          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _bgTertiary,
                    borderRadius: BorderRadius.circular(height / 2.5),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                top: 0,
                bottom: 0,
                left: width * startFraction,
                width: math.max(3, width * widthFraction),
                child: _running ? _RunBreathing(child: bar) : bar,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RunStepDetails extends StatelessWidget {
  const _RunStepDetails({required this.step, required this.compact});

  final RunStepItem step;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      step.typeLabel,
      step.statusLabel,
      if (step.startedAt != null) _formatTimeOnly(step.startedAt!),
      if (step.tokensUsed > 0)
        appStrings.arg1Tokens(_formatNumber(step.tokensUsed)),
    ].join(' · ');
    final description = step.description.trim();
    final input = step.inputSummary.trim().isEmpty
        ? null
        : _RunDetailBlock(label: appStrings.input, value: step.inputSummary);
    final output = step.error.trim().isNotEmpty
        ? _RunDetailBlock(
            label: appStrings.error,
            value: formatCaughtError(step.error),
            monospace: ErrorAudience.isAdmin(),
          )
        : step.result.trim().isNotEmpty
        ? _RunDetailBlock(
            label: appStrings.result,
            value: _truncateRunText(step.result),
            monospace: true,
          )
        : null;
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 12 : 40, 0, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(meta, style: TextStyle(color: _textSecondary, fontSize: 12)),
          if (description.isNotEmpty && description != step.summary.trim())
            _RunDetailBlock(label: appStrings.description, value: description),
          if (input != null && output != null && !compact)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: input),
                const SizedBox(width: 12),
                Expanded(child: output),
              ],
            )
          else ...<Widget>[?input, ?output],
          if (input == null && output == null && description.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                appStrings.noInputOrOutputWasRecorded,
                style: TextStyle(color: _textMuted, fontSize: 12.5),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Prompt inspector, response and flow graph ─────────────────────────────────

class _RunPromptDialog extends StatefulWidget {
  const _RunPromptDialog({required this.controller, required this.runId});

  final NeoAgentController controller;
  final String runId;

  @override
  State<_RunPromptDialog> createState() => _RunPromptDialogState();
}

class _RunPromptDialogState extends State<_RunPromptDialog> {
  bool _captureRequested = false;
  List<RunPromptTurn> _turns = const <RunPromptTurn>[];
  String? _selectedRequestId;
  RunPromptSnapshot? _snapshot;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTurns());
  }

  Future<void> _loadTurns() async {
    try {
      final turns = await widget.controller.fetchRunPromptTurns(widget.runId);
      if (!mounted) {
        return;
      }
      setState(() {
        _turns = turns;
        _loading = false;
      });
      if (turns.isNotEmpty) {
        await _loadTurn(turns.first.requestId);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = widget.controller.friendlyErrorMessage(error);
      });
    }
  }

  Future<void> _loadTurn(String requestId) async {
    setState(() {
      _selectedRequestId = requestId;
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await widget.controller.fetchRunPrompt(
        widget.runId,
        requestId,
      );
      if (!mounted || _selectedRequestId != requestId) {
        return;
      }
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || _selectedRequestId != requestId) {
        return;
      }
      setState(() {
        _loading = false;
        _error = widget.controller.friendlyErrorMessage(error);
      });
    }
  }

  Future<void> _requestCapture() async {
    try {
      await widget.controller.requestCaptureNextRun();
      if (mounted) {
        setState(() => _captureRequested = true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = widget.controller.friendlyErrorMessage(error));
      }
    }
  }

  Future<void> _copyPrompt() async {
    final snapshot = _snapshot;
    if (snapshot == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: snapshot.plainText));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(appStrings.copiedFullPrompt)));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final snapshot = _snapshot;
    return AlertDialog(
      backgroundColor: _bgCard,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: <Widget>[
          Icon(Icons.article_outlined, color: _accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              appStrings.fullPrompt,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          if (snapshot != null)
            Text(
              appStrings.arg1Chars(_formatNumber(snapshot.characters)),
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
        ],
      ),
      content: SizedBox(
        width: size.width * 0.9 > 820 ? 820 : size.width * 0.9,
        height: size.height * 0.7,
        child: _buildBody(snapshot),
      ),
      actions: <Widget>[
        TextButton.icon(
          onPressed: snapshot == null ? null : _copyPrompt,
          icon: Icon(Icons.copy_all_outlined, size: 18),
          label: Text(appStrings.copy),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appStrings.close),
        ),
      ],
    );
  }

  Widget _buildBody(RunPromptSnapshot? snapshot) {
    if (_error != null) {
      return Center(child: _InlineError(message: _error!));
    }
    if (_turns.isEmpty) {
      if (_loading) {
        return Center(
          child: Text(
            appStrings.loadingPrompt,
            style: TextStyle(color: _textSecondary),
          ),
        );
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Prompts are kept for failed runs, a sample of the others, and any run you ask for. This one was not kept.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textSecondary),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: _captureRequested ? null : _requestCapture,
              child: Text(
                _captureRequested
                    ? "The next run's prompts will be kept"
                    : "Keep the next run's prompts",
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _turns
                .map(
                  (turn) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(turn.label),
                      selected: turn.requestId == _selectedRequestId,
                      onSelected: (_) => _loadTurn(turn.requestId),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 12),
        if (_loading || snapshot == null)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: ListView.builder(
              itemCount: snapshot.sections.length + 1,
              itemBuilder: (context, index) {
                if (index == snapshot.sections.length) {
                  return _RunPromptToolsBlock(toolNames: snapshot.toolNames);
                }
                final section = snapshot.sections[index];
                return _RunPromptSectionTile(
                  section: section,
                  initiallyExpanded: index == 0,
                );
              },
            ),
          ),
      ],
    );
  }
}

class _RunPromptSectionTile extends StatelessWidget {
  const _RunPromptSectionTile({
    required this.section,
    required this.initiallyExpanded,
  });

  final RunPromptSection section;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 10),
      title: Text(
        section.label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
      subtitle: Text(
        appStrings.arg1Arg2Chars(
          section.role,
          _formatNumber(section.characters),
        ),
        style: TextStyle(color: _textSecondary, fontSize: 11),
      ),
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _bgPrimary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: SelectableText(
            section.text.isEmpty ? '(empty)' : section.text,
            style: TextStyle(
              height: 1.5,
              fontSize: 12.5,
              color: _textPrimary,
              fontFamily: GoogleFonts.geistMono().fontFamily,
            ),
          ),
        ),
      ],
    );
  }
}

class _RunPromptToolsBlock extends StatelessWidget {
  const _RunPromptToolsBlock({required this.toolNames});

  final List<String> toolNames;

  @override
  Widget build(BuildContext context) {
    if (toolNames.isEmpty) {
      return const SizedBox.shrink();
    }
    return _RunDetailBlock(
      label: appStrings.toolsOfferedArg1(toolNames.length),
      value: toolNames.join(', '),
      monospace: true,
    );
  }
}

class _RunResponseCard extends StatelessWidget {
  const _RunResponseCard({required this.response, required this.onCopy});

  final String response;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: _SectionTitle(appStrings.finalResponse)),
                OutlinedButton.icon(
                  onPressed: response.trim().isEmpty ? null : onCopy,
                  icon: Icon(Icons.copy_all_outlined),
                  label: Text(appStrings.copy),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (response.trim().isEmpty)
              Text(
                appStrings.noFinalResponseWasCapturedForThis,
                style: TextStyle(color: _textSecondary),
              )
            else
              MarkdownBody(
                data: response,
                selectable: true,
                sizedImageBuilder: _markdownImageLink,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                    .copyWith(
                      p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _textPrimary,
                        height: 1.6,
                      ),
                      code: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: GoogleFonts.geistMono().fontFamily,
                        backgroundColor: _bgSecondary,
                        color: _textPrimary,
                      ),
                      blockquoteDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: _bgSecondary,
                        border: Border.all(color: _border),
                      ),
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DeliverableSummaryCard extends StatelessWidget {
  const _DeliverableSummaryCard({required this.run});

  final RunSummary run;

  @override
  Widget build(BuildContext context) {
    final artifacts = run.deliverableArtifacts;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _SectionTitle(appStrings.sectionDeliverable),
            const SizedBox(height: 12),
            Text(
              run.deliverableSummary.ifEmpty(
                appStrings.workflowArg1(
                  run.deliverableType.replaceAll('_', ' '),
                ),
              ),
              style: TextStyle(color: _textPrimary, height: 1.45),
            ),
            if (artifacts.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              ...artifacts.map((artifact) {
                final meta = <String>[
                  artifact.kind,
                  if (artifact.mimeType.trim().isNotEmpty) artifact.mimeType,
                  if (artifact.size > 0) appStrings.arg1Bytes(artifact.size),
                ].join(' • ');
                final location = artifact.uri.ifEmpty(artifact.path);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _bgSecondary,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          artifact.displayLabel,
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (meta.trim().isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            meta,
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (location.trim().isNotEmpty) ...<Widget>[
                          const SizedBox(height: 6),
                          SelectableText(
                            location,
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 12,
                              fontFamily: GoogleFonts.geistMono().fontFamily,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _RunDetailBlock extends StatelessWidget {
  const _RunDetailBlock({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: _textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _bgPrimary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: SelectableText(
              value,
              style: TextStyle(
                height: 1.5,
                fontSize: 12.5,
                color: _textPrimary,
                fontFamily: monospace
                    ? GoogleFonts.geistMono().fontFamily
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Run flow graph (#66) ─────────────────────────────────────────────────

// ── Data model ──────────────────────────────────────────────────────────────

class _FlowNode {
  _FlowNode({
    required this.id,
    required this.label,
    required this.nodeType,
    required this.status,
    this.step,
  });

  final String id;
  final String label;
  final String nodeType;
  final String status;
  final RunStepItem? step;
  double x = 0;
  double y = 0;
  int lane = 0;

  static const double w = 156.0;
  static const double h = 64.0;
  static const double hGap = 34.0;
  static const double vGap = 80.0;

  Color get nodeColor {
    if (status == 'failed') return _danger;
    switch (nodeType) {
      case 'start':
        return _accent;
      case 'end':
        return _success;
      case 'fail':
        return _danger;
      default:
        return _runStepKindColor(nodeType);
    }
  }

  IconData get nodeIcon {
    switch (nodeType) {
      case 'start':
        return Icons.play_circle_outline;
      case 'end':
        return Icons.check_circle_outline;
      case 'fail':
        return Icons.error_outline;
      case 'model':
        return Icons.psychology_outlined;
      case 'plan':
        return Icons.list_alt_outlined;
      case 'subagent':
        return Icons.account_tree_outlined;
      case 'verify':
        return Icons.fact_check_outlined;
      case 'note':
        return Icons.notes_outlined;
      default:
        return Icons.build_circle_outlined;
    }
  }
}

List<_FlowNode> _buildRunFlowNodes(RunDetailSnapshot detail) {
  final nodes = <_FlowNode>[];

  nodes.add(
    _FlowNode(
      id: '__start__',
      label: 'Start',
      nodeType: 'start',
      status: 'completed',
    ),
  );

  int subLaneCounter = 0;
  for (final step in detail.steps) {
    final nodeType = _runStepKind(step);
    final nodeLane = nodeType == 'subagent' ? ++subLaneCounter : 0;
    nodes.add(
      _FlowNode(
        id: step.id,
        label: step.label,
        nodeType: nodeType,
        status: step.status,
        step: step,
      )..lane = nodeLane,
    );
  }

  nodes.add(
    _FlowNode(
      id: '__end__',
      label: detail.run.isFailure ? 'Failed' : 'Done',
      nodeType: detail.run.isFailure ? 'fail' : 'end',
      status: detail.run.isFailure ? 'failed' : 'completed',
    ),
  );

  // Layout positions
  final mainNodes = nodes.where((n) => n.lane == 0).toList();
  double cx = 0;
  for (final n in mainNodes) {
    n.x = cx;
    n.y = 0;
    cx += _FlowNode.w + _FlowNode.hGap;
  }

  final subLanes = <int, List<_FlowNode>>{};
  for (final n in nodes.where((n) => n.lane > 0)) {
    subLanes.putIfAbsent(n.lane, () => []).add(n);
  }
  int laneRow = 1;
  for (final laneNodes in subLanes.values) {
    double subCx = _FlowNode.w + _FlowNode.hGap;
    for (final n in laneNodes) {
      n.x = subCx;
      n.y = laneRow * (_FlowNode.h + _FlowNode.vGap);
      subCx += _FlowNode.w + _FlowNode.hGap;
    }
    laneRow++;
  }

  return nodes;
}

List<(String, String, bool)> _buildRunFlowEdges(List<_FlowNode> nodes) {
  final edges = <(String, String, bool)>[];
  final mainLane = nodes.where((n) => n.lane == 0).toList();
  for (int i = 0; i + 1 < mainLane.length; i++) {
    edges.add((mainLane[i].id, mainLane[i + 1].id, false));
  }
  // Delegation nodes: connect from start to their first node
  for (final n in nodes.where((n) => n.lane > 0)) {
    edges.add(('__start__', n.id, true));
  }
  return edges;
}

// ── Edge painter ──────────────────────────────────────────────────────────────

class _RunGraphEdgePainter extends CustomPainter {
  const _RunGraphEdgePainter({required this.nodeMap, required this.edges});

  final Map<String, _FlowNode> nodeMap;
  final List<(String, String, bool)> edges;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (fromId, toId, isDelegation) in edges) {
      final from = nodeMap[fromId];
      final to = nodeMap[toId];
      if (from == null || to == null) continue;

      final color = isDelegation
          ? _accentHover.withValues(alpha: 0.55)
          : _border.withValues(alpha: 0.8);

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;

      final start = Offset(from.x + _FlowNode.w, from.y + _FlowNode.h / 2);
      final end = Offset(to.x, to.y + _FlowNode.h / 2);

      if (from.y != to.y) {
        final mid = (start.dx + end.dx) / 2;
        final path = Path()
          ..moveTo(start.dx, start.dy)
          ..cubicTo(mid, start.dy, mid, end.dy, end.dx, end.dy);
        canvas.drawPath(path, paint);
      } else {
        canvas.drawLine(start, end, paint);
      }

      // Arrowhead
      final arrowPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      const arrowSize = 6.0;
      final arrow = Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(end.dx - arrowSize, end.dy - arrowSize * 0.5)
        ..lineTo(end.dx - arrowSize, end.dy + arrowSize * 0.5)
        ..close();
      canvas.drawPath(arrow, arrowPaint);
    }
  }

  @override
  bool shouldRepaint(_RunGraphEdgePainter old) =>
      old.nodeMap != nodeMap || old.edges != edges;
}

// ── Individual node widget ────────────────────────────────────────────────────

class _FlowNodeWidget extends StatelessWidget {
  const _FlowNodeWidget({
    required this.node,
    required this.selected,
    required this.onTap,
  });

  final _FlowNode node;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = node.nodeColor;
    final isSpecial =
        node.nodeType == 'start' ||
        node.nodeType == 'end' ||
        node.nodeType == 'fail';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _FlowNode.w,
        height: _FlowNode.h,
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.16)
              : isSpecial
              ? color.withValues(alpha: 0.10)
              : _bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.30),
            width: selected ? 2.0 : 1.2,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color.withValues(alpha: selected ? 0.22 : 0.07),
              blurRadius: selected ? 14 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(node.nodeIcon, size: 13, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    node.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  isSpecial ? node.nodeType : node.status,
                  style: TextStyle(color: _textSecondary, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Flow graph canvas ────────────────────────────────────────────────────────

class _RunFlowGraphCanvas extends StatefulWidget {
  const _RunFlowGraphCanvas({
    required this.run,
    required this.detail,
    required this.loading,
    required this.errorMessage,
    required this.selectedNodeId,
    required this.onNodeSelected,
  });

  final RunSummary? run;
  final RunDetailSnapshot? detail;
  final bool loading;
  final String? errorMessage;
  final String? selectedNodeId;
  final ValueChanged<String?> onNodeSelected;

  @override
  State<_RunFlowGraphCanvas> createState() => _RunFlowGraphCanvasState();
}

class _RunFlowGraphCanvasState extends State<_RunFlowGraphCanvas> {
  final TransformationController _transform = TransformationController();
  String? _lastRunId;

  @override
  void didUpdateWidget(covariant _RunFlowGraphCanvas old) {
    super.didUpdateWidget(old);
    final currentId = widget.detail?.run.id ?? widget.run?.id;
    if (currentId != _lastRunId && currentId != null) {
      _lastRunId = currentId;
      _transform.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.run == null) {
      return _EmptyCard(
        title: appStrings.selectARun,
        subtitle: appStrings.pickARunFromTheList2,
      );
    }

    if (widget.loading && widget.detail == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 14),
              Text(
                appStrings.loadingRunFlow,
                style: TextStyle(color: _textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.errorMessage != null) {
      return _InlineError(message: widget.errorMessage!);
    }

    final detail = widget.detail;
    if (detail == null) {
      return _EmptyCard(
        title: appStrings.noDetailAvailable,
        subtitle: appStrings.thisRunHasNoRecordedStep,
      );
    }

    final nodes = _buildRunFlowNodes(detail);
    final edges = _buildRunFlowEdges(nodes);
    final nodeMap = <String, _FlowNode>{for (final n in nodes) n.id: n};

    final canvasW =
        nodes.fold(0.0, (m, n) => math.max(m, n.x + _FlowNode.w)) + 48;
    final canvasH =
        nodes.fold(0.0, (m, n) => math.max(m, n.y + _FlowNode.h)) + 48;

    final stepCount = nodes.length - 2; // subtract start + end virtuals

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    appStrings.arg1StepArg2TapANode(
                      stepCount,
                      stepCount == 1 ? '' : 's',
                    ),
                    style: TextStyle(color: _textSecondary, fontSize: 12.5),
                  ),
                ),
                if (widget.loading)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                TextButton.icon(
                  onPressed: () => _transform.value = Matrix4.identity(),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                  icon: Icon(
                    Icons.center_focus_strong_outlined,
                    size: 15,
                  ),
                  label: Text(
                    appStrings.resetView,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: math.max(220.0, math.min(canvasH + 24, 380.0)),
            child: ClipRect(
              child: InteractiveViewer(
                transformationController: _transform,
                constrained: false,
                minScale: 0.2,
                maxScale: 3.0,
                boundaryMargin: const EdgeInsets.all(64),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: SizedBox(
                    width: canvasW,
                    height: canvasH,
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _RunGraphEdgePainter(
                              nodeMap: nodeMap,
                              edges: edges,
                            ),
                          ),
                        ),
                        ...nodes.map(
                          (node) => Positioned(
                            left: node.x,
                            top: node.y,
                            child: _FlowNodeWidget(
                              node: node,
                              selected: node.id == widget.selectedNodeId,
                              onTap: () => widget.onNodeSelected(
                                node.id == widget.selectedNodeId
                                    ? null
                                    : node.id,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: <Widget>[
                _GraphLegendChip(color: _info, label: appStrings.modelTurn),
                _GraphLegendChip(color: _success, label: appStrings.tool),
                _GraphLegendChip(color: _warning, label: appStrings.plan),
                _GraphLegendChip(
                  color: _accentHover,
                  label: appStrings.subAgent,
                ),
                _GraphLegendChip(color: _danger, label: 'Failed'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GraphLegendChip extends StatelessWidget {
  const _GraphLegendChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: _textSecondary)),
      ],
    );
  }
}

class _RunSelectedStepCard extends StatelessWidget {
  const _RunSelectedStepCard({required this.step});

  final RunStepItem step;

  @override
  Widget build(BuildContext context) {
    final color = step.statusColor;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.build_circle_outlined,
                    size: 18,
                    color: color,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        step.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.typeLabel,
                        style: TextStyle(color: _textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _StatusPill(label: step.statusLabel, color: color),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (step.startedAt != null)
                  _MetaPill(
                    label: step.startedAtLabel!,
                    icon: Icons.schedule_outlined,
                  ),
                if (step.durationLabel != null)
                  _MetaPill(
                    label: step.durationLabel!,
                    icon: Icons.timer_outlined,
                  ),
                if (step.tokensUsed > 0)
                  _MetaPill(
                    label: appStrings.arg1Tokens(
                      _formatNumber(step.tokensUsed),
                    ),
                    icon: Icons.toll_outlined,
                  ),
              ],
            ),
            if (step.description.trim().isNotEmpty &&
                step.description.trim() != step.summary.trim()) ...<Widget>[
              const SizedBox(height: 10),
              _RunDetailBlock(
                label: appStrings.description,
                value: step.description,
              ),
            ],
            if (step.inputSummary.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              _RunDetailBlock(
                label: appStrings.input,
                value: step.inputSummary,
              ),
            ],
            if (step.error.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              _RunDetailBlock(
                label: appStrings.error,
                value: formatCaughtError(step.error),
                monospace: ErrorAudience.isAdmin(),
              ),
            ] else if (step.result.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              _RunDetailBlock(
                label: appStrings.result,
                value: _truncateRunText(step.result),
                monospace: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Telemetry ─────────────────────────────────────────────────────────────────
//
// Why a run went the way it did, from its ledger. Everything here is metadata:
// decisions, durations, and counts. No prompt text and no private reasoning.

String _formatCompactCount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
  return '$value';
}

class RunTelemetryView extends StatelessWidget {
  const RunTelemetryView({super.key, required this.detail});

  final RunDetailSnapshot detail;

  @override
  Widget build(BuildContext context) {
    final metrics = detail.metrics;
    final ledger = detail.ledger;
    final rows = _buildRows();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (metrics != null) ...<Widget>[
          _RunLatencyBar(metrics: metrics),
          const SizedBox(height: 12),
        ],
        if (detail.diagnostics.isNotEmpty) ...<Widget>[
          _RunDiagnosticsCard(diagnostics: detail.diagnostics),
          const SizedBox(height: 12),
        ],
        if (ledger != null) ...<Widget>[
          _RunLedgerCard(ledger: ledger),
          const SizedBox(height: 12),
        ],
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'This run has no telemetry yet.',
              style: TextStyle(color: _textSecondary),
            ),
          )
        else
          ...rows,
      ],
    );
  }

  // Everything the ledger stored for this step, for working out why it went the
  // way it did. Events hold metadata only, so this shows no prompt or message text.
  static Widget? _details(Map<String, dynamic> payload) {
    const envelope = <String>{'schema_version', 'event_id', 'parent_event_id', 'timestamp', 'actor', 'candidates'};
    final fields = <String>[];
    void collect(String prefix, dynamic value) {
      if (value == null) return;
      if (value is Map) {
        value.forEach((key, inner) => collect(prefix.isEmpty ? '$key' : '$prefix.$key', inner));
      } else {
        fields.add('$prefix  ${value is List ? value.join(', ') : value}');
      }
    }

    payload.forEach((key, value) {
      if (!envelope.contains(key)) collect(key, value);
    });
    if (fields.isEmpty) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final field in fields)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(field, style: _runMonoStyle(size: 11.5, color: _textMuted)),
          ),
      ],
    );
  }

  List<Widget> _buildRows() {
    final rows = <Widget>[];
    var modelRequest = 0;
    final chosen = detail.events
        .where((event) => event.eventType == 'tool.call')
        .map((event) => event.toolName)
        .toSet();
    for (final event in detail.events) {
      final payload = event.payload;
      switch (event.eventType) {
        case 'context.built':
          final sections = _jsonMap(payload['sections']);
          rows.add(
            _RunTelemetryRow(
              expanded: _details(payload),
              title: 'Context build',
              durationMs: _asInt(payload['startup_ms']),
              detail:
                  '${_formatCompactCount(_asInt(sections['total_tokens']))} tokens · system ${_formatCompactCount(_asInt(sections['system_tokens']))} · tools ${_formatCompactCount(_asInt(sections['tool_schema_tokens']) + _asInt(sections['tool_catalog_tokens']))} · history ${_formatCompactCount(_asInt(sections['history_tokens']))} · memory ${_formatCompactCount(_asInt(sections['memory_tokens']))}',
            ),
          );
        case 'tools.selected':
          rows.add(_selectionRow(payload, chosen));
        case 'memory.recall':
          rows.add(
            _RunTelemetryRow(
              expanded: _details(payload),
              title: 'Memory recall',
              durationMs: event.durationMs,
              detail: payload['recalled'] == false
                  ? 'skipped (${payload['trigger']})'
                  : '${payload['trigger']} · kept ${_asInt(payload['kept'])} of ${_asInt(payload['candidates'])} · ${_asInt(payload['tokens'])} tokens',
            ),
          );
        case 'model.response':
          final usage = _jsonMap(payload['usage']);
          final phase = payload['phase']?.toString() ?? 'model_turn';
          final outcome = _jsonMap(payload['outcome']);
          final isTurn = phase == 'model_turn';
          if (isTurn) modelRequest += 1;
          final failed = outcome['status'] == 'failed';
          final cached = _asInt(usage['cached_read_tokens']);
          rows.add(
            _RunTelemetryRow(
              expanded: _details(payload),
              title: isTurn ? 'Model request #$modelRequest' : phase.replaceAll('_', ' '),
              durationMs: event.durationMs,
              failed: failed,
              detail: failed
                  ? 'failed: ${outcome['error_class']}'
                  : '${_formatCompactCount(_asInt(usage['input_tokens']))} in${cached > 0 ? ' (${_formatCompactCount(cached)} cached)' : ''} / ${_formatCompactCount(_asInt(usage['output_tokens']))} out${_asInt(payload['retry_count']) > 0 ? ' · ${_asInt(payload['retry_count'])} retries' : ''}',
            ),
          );
        case 'tool.result':
          final tool = _jsonMap(payload['tool']);
          final bytes = _asInt(tool['result_bytes']);
          final compacted = _asInt(tool['result_compacted_bytes']);
          final sandbox = _asInt(payload['sandbox_ms']);
          rows.add(
            _RunTelemetryRow(
              expanded: _details(payload),
              title: event.toolName,
              indent: true,
              durationMs: event.durationMs,
              failed: event.outcomeStatus == 'failed',
              detail: event.outcomeStatus == 'failed'
                  ? _jsonMap(payload['outcome'])['error']?.toString() ?? 'failed'
                  : '${compacted < bytes ? '$compacted of $bytes bytes kept' : '$bytes bytes'}${sandbox > 0 ? ' · ${_formatDuration(sandbox)} sandbox' : ''}',
            ),
          );
        case 'tool.suppressed':
          rows.add(
            _RunTelemetryRow(
              expanded: _details(payload),
              title: '${event.toolName} suppressed',
              indent: true,
              muted: true,
              detail: payload['reason']?.toString().replaceAll('_', ' ') ?? '',
            ),
          );
        case 'permission.decision':
          if (payload['decision'] == 'deny') {
            rows.add(
              _RunTelemetryRow(
              expanded: _details(payload),
                title: '${payload['tool']} denied',
                indent: true,
                failed: true,
                detail: 'by ${payload['by']}${payload['tainted'] == true ? ' · run had read outside content' : ''}',
              ),
            );
          }
        case 'recovery.triggered':
          rows.add(
            _RunTelemetryRow(
              expanded: _details(payload),
              title: 'Recovery note',
              detail: payload['reason']?.toString().replaceAll('_', ' ') ?? '',
            ),
          );
        case 'context.compacted':
          rows.add(
            _RunTelemetryRow(
              expanded: _details(payload),
              title: 'Context compacted',
              detail:
                  '${_formatCompactCount(_asInt(payload['before_tokens']))} → ${_formatCompactCount(_asInt(payload['after_tokens']))} tokens',
            ),
          );
        case 'checkpoint.created':
          if (payload['kind'] == 'workspace') {
            rows.add(
              _RunTelemetryRow(
              expanded: _details(payload),
                title: 'Workspace checkpoint',
                durationMs: event.durationMs,
                detail: 'snapshot before the first change',
              ),
            );
          }
        case 'checkpoint.restored':
          rows.add(
            _RunTelemetryRow(
              expanded: _details(payload),
              title: 'Workspace rolled back',
              detail: 'restored to the checkpoint',
            ),
          );
        case 'delivery.sent':
          rows.add(
            _RunTelemetryRow(
              expanded: _details(payload),
              title: 'Delivered: ${payload['purpose']}',
              durationMs: event.durationMs,
              detail: payload['channel']?.toString() ?? '',
            ),
          );
        case 'delivery.suppressed':
          rows.add(
            _RunTelemetryRow(
              expanded: _details(payload),
              title: 'Duplicate stopped: ${payload['purpose']}',
              muted: true,
              detail: payload['reason']?.toString().replaceAll('_', ' ') ?? '',
            ),
          );
        case 'delivery.failed':
          rows.add(
            _RunTelemetryRow(
              expanded: _details(payload),
              title: 'Delivery failed: ${payload['purpose']}',
              failed: true,
              durationMs: event.durationMs,
              detail: payload['ambiguous'] == true
                  ? 'may have arrived, so it will not be sent again'
                  : 'not delivered',
            ),
          );
      }
    }
    return rows;
  }

  Widget _selectionRow(Map<String, dynamic> payload, Set<String> chosen) {
    final kind = payload['kind']?.toString() ?? 'initial';
    if (kind == 'search') {
      return _RunTelemetryRow(
        title: 'Tool search',
        indent: true,
        detail: _stringList(payload['result_names']).join(', '),
      );
    }
    if (kind == 'activate') {
      return _RunTelemetryRow(
        title: 'Tools activated',
        indent: true,
        detail: _stringList(payload['activated']).join(', '),
      );
    }
    final selection = _jsonMap(payload['selection']);
    final candidates = _jsonMapList(payload['candidates']);
    return _RunTelemetryRow(
      title: 'Tool selection',
      durationMs: _asInt(payload['duration_ms']),
      detail:
          '${_asInt(selection['catalog_size'])} known · ${_asInt(selection['eligible_count'])} eligible · ${_asInt(selection['active_count'])} active',
      expanded: candidates.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final candidate in candidates)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '${_asInt(candidate['rank'])}  ${candidate['name']}  ${candidate['source']}${candidate['similarity'] == null ? '' : ' ${candidate['similarity']}'}${chosen.contains(candidate['name']) ? '  ← used' : ''}',
                      style: _runMonoStyle(
                        size: 11.5,
                        color: chosen.contains(candidate['name'])
                            ? _textPrimary
                            : _textMuted,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  static List<String> _stringList(dynamic value) => value is List
      ? value.map((item) => item.toString()).toList()
      : const <String>[];
}

class _RunTelemetryRow extends StatelessWidget {
  const _RunTelemetryRow({
    required this.title,
    this.detail = '',
    this.durationMs,
    this.indent = false,
    this.failed = false,
    this.muted = false,
    this.warning = false,
    this.expanded,
  });

  final String title;
  final String detail;
  final int? durationMs;
  final bool indent;
  final bool failed;
  final bool muted;
  final bool warning;
  final Widget? expanded;

  @override
  Widget build(BuildContext context) {
    final color = failed
        ? _danger
        : warning
        ? _warning
        : muted
        ? _textMuted
        : _textPrimary;
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (detail.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    detail,
                    style: TextStyle(color: _textSecondary, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        if (durationMs != null && durationMs! > 0) ...<Widget>[
          const SizedBox(width: 12),
          Text(_formatDuration(durationMs!), style: _runMonoStyle(size: 12)),
        ],
      ],
    );
    return Padding(
      padding: EdgeInsets.only(left: indent ? 18 : 0, bottom: 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
        decoration: BoxDecoration(
          color: _bgSecondary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: expanded == null
            ? header
            : Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 4),
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: header,
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[expanded!],
                ),
              ),
      ),
    );
  }
}

class _RunDiagnosticsCard extends StatelessWidget {
  const _RunDiagnosticsCard({required this.diagnostics});

  final List<RunDiagnostic> diagnostics;

  static (String, String) _explain(RunDiagnostic entry) {
    final percent = '${(entry.share * 100).round()}%';
    final times = '${entry.count} ${entry.count == 1 ? 'call' : 'calls'}';
    switch (entry.code) {
      case 'outcome_action_failed':
        return ('The last action failed', 'The run ended right after a change that did not work.');
      case 'outcome_tests_failing':
        return ('The last test run failed', 'The run ended with failing tests.');
      case 'outcome_unverified':
        return ('Changed, not tested', 'No passing test run was seen after the last change.');
      case 'outcome_rolled_back':
        return ('Changes were undone', 'The run ended by rolling back what it had changed.');
      case 'changes_not_tracked':
        return ('Changes not tracked', '$times changed things rollback and this report cannot see.');
      case 'delivery_ambiguous':
        return (
          'A message may have arrived',
          'The send failed in a way that leaves it unclear, so it was not sent again.',
        );
      case 'suppression_overruled':
        return ('A skipped call ran anyway', '$times the repeat guard skipped ran later.');
      case 'repeated_calls':
        return ('Same call repeated', '$times ran again with nothing changed.');
      case 'failed_tools':
        return ('Tools failed', '$times failed.');
      case 'tool_not_on_first_turn':
        return (
          'Tool not on the first turn',
          '${entry.tools.join(', ')} had to be found first, which cost a turn.',
        );
      case 'slow_model_loop':
        return ('Mostly model time', '$percent of the run was spent waiting on the model.');
      case 'tools_fill_context':
        return (
          'Tools fill the context',
          '$percent of the first prompt (${_formatCompactCount(entry.tokens)} tokens) was tool definitions.',
        );
      default:
        return (entry.code.replaceAll('_', ' '), '');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final entry in diagnostics)
          Builder(
            builder: (context) {
              final (title, detail) = _explain(entry);
              return _RunTelemetryRow(title: title, detail: detail, warning: true);
            },
          ),
      ],
    );
  }
}

class _RunLatencyBar extends StatelessWidget {
  const _RunLatencyBar({required this.metrics});

  final RunHarnessMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final parts = <(String, int, Color)>[
      ('Queue', metrics.queueMs, _textMuted),
      ('Model', metrics.modelMs, _info),
      ('Tools', metrics.toolMs, _success),
      ('Sandbox', metrics.sandboxMs, _warning),
      ('Delivery', metrics.deliveryMs, _accent),
    ].where((part) => part.$2 > 0).toList();
    if (parts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 8,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final part in parts)
                  Expanded(
                    flex: part.$2,
                    child: ColoredBox(color: part.$3),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: <Widget>[
            if (metrics.taskOutcome.isNotEmpty)
              Text(
                'Outcome ${metrics.taskOutcome.replaceAll('_', ' ')}',
                style: _runMonoStyle(size: 11.5, color: _textPrimary),
              ),
            if (metrics.filesChanged > 0)
              Text(
                '${metrics.filesChanged} file${metrics.filesChanged == 1 ? '' : 's'} changed',
                style: _runMonoStyle(size: 11.5),
              ),
            if (metrics.testsRun > 0)
              Text(
                '${metrics.testsRun} test run${metrics.testsRun == 1 ? '' : 's'}',
                style: _runMonoStyle(size: 11.5),
              ),
            for (final part in parts)
              Text(
                '${part.$1} ${_formatDuration(part.$2)}',
                style: _runMonoStyle(size: 11.5, color: part.$3),
              ),
            if (metrics.compactions > 0)
              Text(
                '${metrics.compactions} compaction${metrics.compactions == 1 ? '' : 's'}',
                style: _runMonoStyle(size: 11.5),
              ),
            if (metrics.recoveries > 0)
              Text(
                '${metrics.recoveries} recovery note${metrics.recoveries == 1 ? '' : 's'}',
                style: _runMonoStyle(size: 11.5),
              ),
            if (metrics.cachedTokens > 0)
              Text(
                '${_formatCompactCount(metrics.cachedTokens)} tokens from cache',
                style: _runMonoStyle(size: 11.5),
              ),
            if (metrics.promptVersion.isNotEmpty)
              Text(
                'Prompt ${metrics.promptVersion.substring(0, metrics.promptVersion.length < 8 ? metrics.promptVersion.length : 8)}',
                style: _runMonoStyle(size: 11.5),
              ),
          ],
        ),
      ],
    );
  }
}

class _RunLedgerCard extends StatelessWidget {
  const _RunLedgerCard({required this.ledger});

  final RunTaskLedger ledger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'TASK LEDGER',
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
              color: _textMuted,
            ),
          ),
          if (ledger.goal.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(ledger.goal, style: TextStyle(color: _textPrimary)),
          ],
          for (final step in ledger.steps)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${_stepMark(step.status)}  ${step.id}',
                style: _runMonoStyle(
                  size: 12,
                  color: step.status == 'blocked' ? _danger : null,
                ),
              ),
            ),
          for (final fact in ledger.verifiedFacts)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '· $fact',
                style: TextStyle(color: _textSecondary, fontSize: 12),
              ),
            ),
          for (final blocker in ledger.blockers)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '! $blocker',
                style: TextStyle(color: _danger, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  static String _stepMark(String status) => switch (status) {
    'done' => '●',
    'active' => '◐',
    'blocked' => '✕',
    _ => '○',
  };
}

/// Which problem dominates recent runs, before anyone changes the harness.
class _RunHealthDialog extends StatefulWidget {
  const _RunHealthDialog({required this.controller});

  final NeoAgentController controller;

  @override
  State<_RunHealthDialog> createState() => _RunHealthDialogState();
}

class _RunHealthDialogState extends State<_RunHealthDialog> {
  Map<String, dynamic>? _report;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final report = await widget.controller.fetchHarnessReport();
      if (mounted) {
        setState(() => _report = report);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = widget.controller.friendlyErrorMessage(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _bgCard,
      title: const Text('Run health, last 7 days'),
      content: SizedBox(width: 460, child: _buildBody()),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appStrings.close),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _InlineError(message: _error!);
    }
    final report = _report;
    if (report == null) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return RunHealthReportView(report: report);
  }
}

class RunHealthReportView extends StatelessWidget {
  const RunHealthReportView({super.key, required this.report});

  final Map<String, dynamic> report;

  @override
  Widget build(BuildContext context) {
    if (_asInt(report['runs']) == 0) {
      return Text(
        'No runs with telemetry in this period yet.',
        style: TextStyle(color: _textSecondary),
      );
    }
    final latency = _jsonMap(report['latency_ms']);
    final total = _jsonMap(latency['total']);
    final first = _jsonMap(latency['first_action']);
    final perRun = _jsonMap(report['per_run']);
    final rates = _jsonMap(report['rates']);
    String percent(dynamic value) =>
        '${((value is num ? value : 0) * 100).toStringAsFixed(1)}%';
    String spread(Map<String, dynamic> entry, String Function(int) format) {
      if (entry['p50'] == null) return '—';
      return '${format(_asInt(entry['p50']))} / ${format(_asInt(entry['p95']))}';
    }

    final rows = <(String, String)>[
      ('Runs', '${_asInt(report['runs'])}'),
      ('Completed', percent(report['success_rate'])),
      ('Time p50 / p95', spread(total, _formatDuration)),
      ('First action p50 / p95', spread(first, _formatDuration)),
      ('Tool calls p50 / p95', spread(_jsonMap(perRun['tool_calls']), (v) => '$v')),
      ('Input tokens p50 / p95', spread(_jsonMap(perRun['input_tokens']), _formatCompactCount)),
      ('Prompt cache hit', percent(rates['prompt_cache_hit'])),
      ('Runs with no tool', percent(rates['no_tool_runs'])),
      ('Failed tool calls', percent(rates['tool_failure'])),
      ('Tools already there on the first turn', rates['tool_selection_recall'] == null ? '—' : percent(rates['tool_selection_recall'])),
      ('Repeated tool calls', percent(rates['duplicate_tool_calls'])),
      ('Tool calls suppressed', percent(rates['tool_suppressed'])),
      ('Suppressed calls that ran later', percent(rates['suppressed_calls_that_ran_later'])),
      ('Duplicate messages stopped /1000 runs', '${rates['duplicate_deliveries_stopped_per_1000_runs'] ?? 0}'),
      ('Delivery failures /1000 runs', '${rates['delivery_failures_per_1000_runs'] ?? 0}'),
      ('Possibly delivered, not resent /1000 runs', '${rates['ambiguous_deliveries_per_1000_runs'] ?? 0}'),
      ('Recovery notes per run', '${rates['recoveries_per_run'] ?? 0}'),
      ('Compactions per run', '${rates['compactions_per_run'] ?? 0}'),
    ];
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      row.$1,
                      style: TextStyle(color: _textSecondary, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(row.$2, style: _runMonoStyle(size: 13, color: _textPrimary)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
