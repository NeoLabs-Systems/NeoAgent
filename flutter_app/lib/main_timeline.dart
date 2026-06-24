part of 'main.dart';

const double _timelineAxisHeaderHeight = 56;
const double _timelineLaneLabelWidth = 132;
const double _timelinePlotRightPadding = 84;
const double _timelineLanePadding = 18;
const double _timelineLaneGap = 18;
const double _timelineNodeWidth = 208;
const double _timelineNodeHeight = 88;
const double _timelineNodeGap = 18;
const double _timelineCanvasBottomPadding = 28;
const double _timelinePlotInset = _timelineNodeWidth / 2;

class TimelinePanel extends StatefulWidget {
  const TimelinePanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<TimelinePanel> createState() => _TimelinePanelState();
}

class _TimelinePanelState extends State<TimelinePanel> {
  final TransformationController _viewportController =
      TransformationController();

  int? _selectedEventId;
  int? _hoveredEventId;

  @override
  void dispose() {
    _viewportController.dispose();
    super.dispose();
  }

  void _resetViewport() {
    _viewportController.value = Matrix4.identity();
  }

  void _selectEvent(TimelineEventItem item) {
    if (_selectedEventId == item.id) {
      return;
    }
    setState(() {
      _selectedEventId = item.id;
    });
  }

  void _setHoveredEvent(int? eventId) {
    if (_hoveredEventId == eventId) {
      return;
    }
    setState(() {
      _hoveredEventId = eventId;
    });
  }

  void _moveSelection(List<TimelineEventItem> items, int offset) {
    if (items.isEmpty) {
      return;
    }
    final currentIndex = items.indexWhere(
      (item) => item.id == _selectedEventId,
    );
    final baseIndex = currentIndex == -1
        ? (offset > 0 ? 0 : items.length - 1)
        : currentIndex;
    final nextIndex = (baseIndex + offset).clamp(0, items.length - 1);
    setState(() {
      _selectedEventId = items[nextIndex].id;
    });
  }

  TimelineEventItem? _resolveSelectedEvent(List<TimelineEventItem> items) {
    if (items.isEmpty) {
      _selectedEventId = null;
      return null;
    }
    for (final item in items) {
      if (item.id == _selectedEventId) {
        return item;
      }
    }
    _selectedEventId = items.last.id;
    return items.last;
  }

  @override
  Widget build(BuildContext context) {
    final items = _sortedTimelineEvents(widget.controller.timelineItems);
    final selectedEvent = _resolveSelectedEvent(items);
    final selectedIndex = selectedEvent == null
        ? -1
        : items.indexWhere((item) => item.id == selectedEvent.id);

    return Padding(
      padding: _pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _PageTitle(
            title: 'Timeline',
            subtitle:
                'Interactive chronology across passive screen sessions, tasks, and runs.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (final filter in const <({String id, String label})>[
                (id: 'screen', label: 'Screen'),
                (id: 'tasks', label: 'Tasks'),
                (id: 'runs', label: 'Runs'),
              ])
                FilterChip(
                  selected: widget.controller.selectedTimelineSources.contains(
                    filter.id,
                  ),
                  label: Text(filter.label),
                  onSelected: (_) =>
                      widget.controller.toggleTimelineSource(filter.id),
                ),
              OutlinedButton.icon(
                onPressed: widget.controller.isRefreshingTimeline
                    ? null
                    : widget.controller.refreshTimeline,
                icon: widget.controller.isRefreshingTimeline
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_outlined),
                label: const Text('Refresh'),
              ),
              OutlinedButton.icon(
                onPressed: items.isEmpty ? null : _resetViewport,
                icon: const Icon(Icons.center_focus_strong_rounded),
                label: const Text('Reset view'),
              ),
            ],
          ),
          if (items.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _MetaPill(
                  label: '${items.length} events',
                  icon: Icons.bubble_chart_outlined,
                ),
                _MetaPill(
                  label: _formatTimelineRange(items.first, items.last),
                  icon: Icons.schedule_outlined,
                ),
                _MetaPill(
                  label: 'Drag to pan, scroll or pinch to zoom',
                  icon: Icons.pan_tool_alt_outlined,
                  color: _info,
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: items.isEmpty
                ? Card(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                          'No timeline activity yet for the selected filters.',
                          style: TextStyle(color: _textSecondary),
                        ),
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 1120;
                      final timelinePane = _InteractiveTimelineCanvas(
                        items: items,
                        selectedEventId: selectedEvent?.id,
                        hoveredEventId: _hoveredEventId,
                        viewportController: _viewportController,
                        onSelectEvent: _selectEvent,
                        onHoverEvent: _setHoveredEvent,
                      );
                      final detailPane = _TimelineSelectionPanel(
                        items: items,
                        selectedEvent: selectedEvent,
                        selectedIndex: selectedIndex,
                        onSelectPrevious: selectedIndex > 0
                            ? () => _moveSelection(items, -1)
                            : null,
                        onSelectNext:
                            selectedIndex >= 0 &&
                                selectedIndex < items.length - 1
                            ? () => _moveSelection(items, 1)
                            : null,
                        onOpenRun:
                            selectedEvent != null &&
                                selectedEvent.runId.isNotEmpty
                            ? () => unawaited(
                                widget.controller.openRunDetails(
                                  selectedEvent.runId,
                                ),
                              )
                            : null,
                      );

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Expanded(flex: 7, child: timelinePane),
                            const SizedBox(width: 16),
                            SizedBox(width: 360, child: detailPane),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Expanded(flex: 3, child: timelinePane),
                          const SizedBox(height: 16),
                          Expanded(flex: 2, child: detailPane),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _InteractiveTimelineCanvas extends StatelessWidget {
  const _InteractiveTimelineCanvas({
    required this.items,
    required this.selectedEventId,
    required this.hoveredEventId,
    required this.viewportController,
    required this.onSelectEvent,
    required this.onHoverEvent,
  });

  final List<TimelineEventItem> items;
  final int? selectedEventId;
  final int? hoveredEventId;
  final TransformationController viewportController;
  final ValueChanged<TimelineEventItem> onSelectEvent;
  final ValueChanged<int?> onHoverEvent;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Timeline map',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Events are placed by real timestamp and grouped into source lanes.',
                        style: TextStyle(color: _textSecondary, height: 1.35),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _bgTertiary.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _borderLight),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.touch_app_outlined,
                        size: 15,
                        color: _textMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tap cards for details',
                        style: TextStyle(color: _textSecondary, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scene = _TimelineSceneLayout.build(
                    items: items,
                    viewportWidth: constraints.maxWidth,
                  );
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            _bgSecondary.withValues(alpha: 0.92),
                            _bgCard.withValues(alpha: 0.78),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: _borderLight),
                      ),
                      child: InteractiveViewer(
                        transformationController: viewportController,
                        boundaryMargin: const EdgeInsets.all(160),
                        minScale: 0.65,
                        maxScale: 2.8,
                        panEnabled: true,
                        scaleEnabled: true,
                        constrained: false,
                        trackpadScrollCausesScale: true,
                        child: SizedBox(
                          width: scene.canvasWidth,
                          height: scene.canvasHeight,
                          child: Stack(
                            children: <Widget>[
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _TimelineScenePainter(
                                    scene: scene,
                                    selectedEventId: selectedEventId,
                                  ),
                                ),
                              ),
                              for (final lane in scene.lanes)
                                Positioned(
                                  left: 16,
                                  top: lane.top + 14,
                                  child: _TimelineLaneBadge(
                                    label: lane.label,
                                    color: lane.color,
                                    icon: _timelineLaneIcon(lane.sourceKind),
                                  ),
                                ),
                              for (final entry in scene.entries)
                                Positioned(
                                  left: entry.left,
                                  top: entry.top,
                                  width: _timelineNodeWidth,
                                  height: _timelineNodeHeight,
                                  child: _TimelineEventNode(
                                    item: entry.item,
                                    isSelected:
                                        entry.item.id == selectedEventId,
                                    isHovered: entry.item.id == hoveredEventId,
                                    onTap: () => onSelectEvent(entry.item),
                                    onHoverChanged: (hovering) => onHoverEvent(
                                      hovering ? entry.item.id : null,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineSelectionPanel extends StatelessWidget {
  const _TimelineSelectionPanel({
    required this.items,
    required this.selectedEvent,
    required this.selectedIndex,
    this.onSelectPrevious,
    this.onSelectNext,
    this.onOpenRun,
  });

  final List<TimelineEventItem> items;
  final TimelineEventItem? selectedEvent;
  final int selectedIndex;
  final VoidCallback? onSelectPrevious;
  final VoidCallback? onSelectNext;
  final VoidCallback? onOpenRun;

  @override
  Widget build(BuildContext context) {
    final item = selectedEvent;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Event detail',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Previous event',
                  onPressed: onSelectPrevious,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text(
                  item == null ? '0/0' : '${selectedIndex + 1}/${items.length}',
                  style: TextStyle(color: _textMuted, fontSize: 12),
                ),
                IconButton(
                  tooltip: 'Next event',
                  onPressed: onSelectNext,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (item == null)
              Expanded(
                child: Center(
                  child: Text(
                    'Select an event on the timeline.',
                    style: TextStyle(color: _textSecondary),
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: item.sourceColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              item.sourceLabel,
                              style: TextStyle(
                                color: item.sourceColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            item.occurredAtLabel,
                            style: TextStyle(color: _textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        item.title.ifEmpty(item.taskName),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          _MetaPill(
                            label: _titleCase(
                              item.eventKind.replaceAll('_', ' '),
                            ),
                            icon: Icons.label_outline_rounded,
                            color: item.sourceColor,
                          ),
                          _MetaPill(
                            label: _timelineNodeSubtitle(item),
                            icon: _timelineLaneIcon(item.sourceKind),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ..._timelineDetailBody(item, onOpenRun),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimelineLaneBadge extends StatelessWidget {
  const _TimelineLaneBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _bgCard.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _TimelineEventNode extends StatelessWidget {
  const _TimelineEventNode({
    required this.item,
    required this.isSelected,
    required this.isHovered,
    required this.onTap,
    required this.onHoverChanged,
  });

  final TimelineEventItem item;
  final bool isSelected;
  final bool isHovered;
  final VoidCallback onTap;
  final ValueChanged<bool> onHoverChanged;

  @override
  Widget build(BuildContext context) {
    final accentColor = item.sourceColor;
    final active = isSelected || isHovered;
    final borderColor = isSelected
        ? accentColor.withValues(alpha: 0.8)
        : accentColor.withValues(alpha: active ? 0.4 : 0.18);
    final glowColor = accentColor.withValues(alpha: isSelected ? 0.24 : 0.12);
    final subtitle = _timelineNodeSubtitle(item);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: Tooltip(
        message:
            '${item.occurredAtLabel}\n${item.title.ifEmpty(item.taskName)}',
        child: AnimatedScale(
          scale: active ? 1.02 : 1,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: <Color>[
                      _bgCard.withValues(alpha: 0.98),
                      _bgTertiary.withValues(alpha: 0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: borderColor),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: glowColor,
                      blurRadius: active ? 24 : 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: accentColor,
                            shape: BoxShape.circle,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.32),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formatTimelineTime(item.occurredAt),
                            style: TextStyle(
                              color: _textMuted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.ads_click_rounded,
                            size: 15,
                            color: accentColor,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Text(
                        item.title.ifEmpty(item.taskName),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          height: 1.22,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _textSecondary, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineScenePainter extends CustomPainter {
  const _TimelineScenePainter({
    required this.scene,
    required this.selectedEventId,
  });

  final _TimelineSceneLayout scene;
  final int? selectedEventId;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          Colors.white.withValues(alpha: 0.06),
          Colors.white.withValues(alpha: 0.02),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    final laneFillPaint = Paint()..style = PaintingStyle.fill;
    final laneStrokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _borderLight;
    for (var index = 0; index < scene.lanes.length; index++) {
      final lane = scene.lanes[index];
      final laneRect = Rect.fromLTWH(
        8,
        lane.top,
        scene.canvasWidth - 16,
        lane.height,
      );
      laneFillPaint.color = lane.color.withValues(
        alpha: index.isEven ? 0.05 : 0.025,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(laneRect, const Radius.circular(22)),
        laneFillPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(laneRect, const Radius.circular(22)),
        laneStrokePaint,
      );
    }

    final selectedEntry = selectedEventId == null
        ? null
        : scene.entries.cast<_TimelineSceneEntry?>().firstWhere(
            (entry) => entry?.item.id == selectedEventId,
            orElse: () => null,
          );
    if (selectedEntry != null) {
      final selectedLinePaint = Paint()
        ..color = selectedEntry.item.sourceColor.withValues(alpha: 0.26)
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(selectedEntry.centerX, _timelineAxisHeaderHeight - 4),
        Offset(selectedEntry.centerX, scene.canvasHeight),
        selectedLinePaint,
      );
    }

    final tickPaint = Paint()
      ..color = _borderLight
      ..strokeWidth = 1;
    for (final tick in scene.ticks) {
      canvas.drawLine(
        Offset(tick.x, _timelineAxisHeaderHeight - 8),
        Offset(tick.x, scene.canvasHeight - 10),
        tickPaint,
      );
      final textPainter = TextPainter(
        text: TextSpan(
          text: tick.label,
          style: TextStyle(
            color: _textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 120);
      textPainter.paint(canvas, Offset(tick.x - textPainter.width / 2, 14));
    }
  }

  @override
  bool shouldRepaint(covariant _TimelineScenePainter oldDelegate) {
    return scene != oldDelegate.scene ||
        selectedEventId != oldDelegate.selectedEventId;
  }
}

class _TimelineSceneLayout {
  const _TimelineSceneLayout({
    required this.canvasWidth,
    required this.canvasHeight,
    required this.lanes,
    required this.entries,
    required this.ticks,
  });

  factory _TimelineSceneLayout.build({
    required List<TimelineEventItem> items,
    required double viewportWidth,
  }) {
    final lanes = _buildTimelineLanes(items);
    final minimumCanvasWidth = math.max(
      viewportWidth - 36,
      items.length * 156 + _timelineLaneLabelWidth + _timelinePlotRightPadding,
    );
    final plotStart = _timelineLaneLabelWidth + _timelinePlotInset;
    final plotWidth =
        minimumCanvasWidth -
        plotStart -
        _timelinePlotRightPadding -
        _timelinePlotInset;
    final start = items.first.occurredAt;
    final end = items.last.occurredAt;
    final durationMs = math.max(end.difference(start).inMilliseconds, 1);
    final entries = <_TimelineSceneEntry>[];
    final laneGeometries = <_TimelineLaneGeometry>[];
    var laneTop = _timelineAxisHeaderHeight;

    for (final lane in lanes) {
      final laneItems = items
          .where((item) => item.sourceKind == lane.sourceKind)
          .toList(growable: false);
      final positioned = <({TimelineEventItem item, double x, int track})>[];
      final trackLastEdge = <double>[];
      for (final item in laneItems) {
        final elapsedMs = item.occurredAt.difference(start).inMilliseconds;
        final fraction = elapsedMs / durationMs;
        final x =
            plotStart + (fraction * plotWidth).clamp(0, plotWidth.toDouble());
        var track = 0;
        while (track < trackLastEdge.length &&
            x - trackLastEdge[track] < _timelineNodeWidth + _timelineNodeGap) {
          track += 1;
        }
        if (track == trackLastEdge.length) {
          trackLastEdge.add(x);
        } else {
          trackLastEdge[track] = x;
        }
        positioned.add((item: item, x: x, track: track));
      }

      final trackCount = math.max(trackLastEdge.length, 1);
      final laneHeight =
          trackCount * (_timelineNodeHeight + _timelineNodeGap) +
          (_timelineLanePadding * 2) -
          _timelineNodeGap;
      laneGeometries.add(
        _TimelineLaneGeometry(
          sourceKind: lane.sourceKind,
          label: lane.label,
          color: lane.color,
          top: laneTop,
          height: laneHeight,
        ),
      );
      for (final entry in positioned) {
        final top =
            laneTop +
            _timelineLanePadding +
            entry.track * (_timelineNodeHeight + _timelineNodeGap);
        entries.add(
          _TimelineSceneEntry(
            item: entry.item,
            left: entry.x - (_timelineNodeWidth / 2),
            top: top,
          ),
        );
      }
      laneTop += laneHeight + _timelineLaneGap;
    }

    return _TimelineSceneLayout(
      canvasWidth: minimumCanvasWidth,
      canvasHeight: laneTop + _timelineCanvasBottomPadding,
      lanes: laneGeometries,
      entries: entries,
      ticks: _buildTimelineTicks(
        start: start,
        end: end,
        plotStart: plotStart,
        plotWidth: plotWidth,
      ),
    );
  }

  final double canvasWidth;
  final double canvasHeight;
  final List<_TimelineLaneGeometry> lanes;
  final List<_TimelineSceneEntry> entries;
  final List<_TimelineTick> ticks;
}

class _TimelineLaneDefinition {
  const _TimelineLaneDefinition({
    required this.sourceKind,
    required this.label,
    required this.color,
  });

  final String sourceKind;
  final String label;
  final Color color;
}

class _TimelineLaneGeometry {
  const _TimelineLaneGeometry({
    required this.sourceKind,
    required this.label,
    required this.color,
    required this.top,
    required this.height,
  });

  final String sourceKind;
  final String label;
  final Color color;
  final double top;
  final double height;
}

class _TimelineSceneEntry {
  const _TimelineSceneEntry({
    required this.item,
    required this.left,
    required this.top,
  });

  final TimelineEventItem item;
  final double left;
  final double top;

  double get centerX => left + (_timelineNodeWidth / 2);
}

class _TimelineTick {
  const _TimelineTick({required this.x, required this.label});

  final double x;
  final String label;
}

List<TimelineEventItem> _sortedTimelineEvents(List<TimelineEventItem> items) {
  final sorted = List<TimelineEventItem>.of(items);
  sorted.sort((a, b) {
    final timestampCompare = a.occurredAt.compareTo(b.occurredAt);
    if (timestampCompare != 0) {
      return timestampCompare;
    }
    return a.id.compareTo(b.id);
  });
  return sorted;
}

List<_TimelineLaneDefinition> _buildTimelineLanes(
  List<TimelineEventItem> items,
) {
  const preferredOrder = <String>['screen', 'tasks', 'runs'];
  final firstBySource = <String, TimelineEventItem>{};
  for (final item in items) {
    firstBySource.putIfAbsent(item.sourceKind, () => item);
  }

  final lanes = <_TimelineLaneDefinition>[];
  for (final kind in preferredOrder) {
    final sample = firstBySource[kind];
    if (sample == null) {
      continue;
    }
    lanes.add(
      _TimelineLaneDefinition(
        sourceKind: kind,
        label: sample.sourceLabel,
        color: sample.sourceColor,
      ),
    );
  }

  final remaining =
      firstBySource.keys
          .where((kind) => !preferredOrder.contains(kind))
          .toList()
        ..sort();
  for (final kind in remaining) {
    final sample = firstBySource[kind]!;
    lanes.add(
      _TimelineLaneDefinition(
        sourceKind: kind,
        label: sample.sourceLabel,
        color: sample.sourceColor,
      ),
    );
  }
  return lanes;
}

List<_TimelineTick> _buildTimelineTicks({
  required DateTime start,
  required DateTime end,
  required double plotStart,
  required double plotWidth,
}) {
  final totalDuration = end.difference(start);
  final step = _pickTimelineTickStep(totalDuration);
  final rangeMs = math.max(totalDuration.inMilliseconds, 1);
  final alignedStart = _alignTimelineTick(start, step);
  final ticks = <_TimelineTick>[];

  for (
    var tick = alignedStart;
    !tick.isAfter(end.add(step));
    tick = tick.add(step)
  ) {
    final offsetMs = tick.difference(start).inMilliseconds;
    final fraction = (offsetMs / rangeMs).clamp(0.0, 1.0);
    ticks.add(
      _TimelineTick(
        x: plotStart + fraction * plotWidth,
        label: _formatTimelineTick(tick, step),
      ),
    );
  }
  if (ticks.length < 2) {
    ticks.add(
      _TimelineTick(
        x: plotStart + plotWidth,
        label: _formatTimelineTick(end, step),
      ),
    );
  }
  return ticks;
}

Duration _pickTimelineTickStep(Duration range) {
  final candidates = <Duration>[
    const Duration(minutes: 15),
    const Duration(minutes: 30),
    const Duration(hours: 1),
    const Duration(hours: 2),
    const Duration(hours: 6),
    const Duration(hours: 12),
    const Duration(days: 1),
    const Duration(days: 2),
    const Duration(days: 7),
    const Duration(days: 14),
    const Duration(days: 30),
    const Duration(days: 90),
  ];
  final targetTicks = math.max((range.inHours / 6).round(), 4);
  for (final step in candidates) {
    if (range.inMilliseconds / step.inMilliseconds <= targetTicks) {
      return step;
    }
  }
  return const Duration(days: 180);
}

DateTime _alignTimelineTick(DateTime value, Duration step) {
  final stepMs = math.max(step.inMilliseconds, 1);
  final alignedMs = (value.millisecondsSinceEpoch ~/ stepMs) * stepMs;
  return DateTime.fromMillisecondsSinceEpoch(alignedMs, isUtc: value.isUtc);
}

String _formatTimelineRange(TimelineEventItem first, TimelineEventItem last) {
  final start = first.occurredAt.toLocal();
  final end = last.occurredAt.toLocal();
  final startDate = _formatTimelineDate(start);
  final endDate = _formatTimelineDate(end);
  final startTime = _formatTimelineTime(start);
  final endTime = _formatTimelineTime(end);
  if (start.year == end.year &&
      start.month == end.month &&
      start.day == end.day) {
    return '$startDate · $startTime - $endTime';
  }
  return '$startDate, $startTime -> $endDate, $endTime';
}

String _formatTimelineTick(DateTime value, Duration step) {
  final local = value.toLocal();
  if (step.inHours < 24) {
    return _formatTimelineTime(local);
  }
  if (step.inDays < 30) {
    return '${_monthShort(local.month)} ${local.day}';
  }
  return '${_monthShort(local.month)} ${local.year}';
}

String _formatTimelineDate(DateTime value) {
  return '${_monthShort(value.month)} ${value.day}, ${value.year}';
}

String _formatTimelineTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _monthShort(int month) {
  const labels = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return labels[(month - 1).clamp(0, labels.length - 1)];
}

String _timelineNodeSubtitle(TimelineEventItem item) {
  switch (item.sourceKind) {
    case 'screen':
      return item.appName
          .ifEmpty(item.windowTitle)
          .ifEmpty(item.deviceLabel.ifEmpty('Passive capture'));
    case 'tasks':
      return _titleCase(item.eventKind.replaceAll('_', ' '));
    case 'runs':
      return item.summary.trim().ifEmpty(
        _titleCase(item.eventKind.replaceAll('_', ' ')),
      );
    default:
      return item.sourceLabel;
  }
}

IconData _timelineLaneIcon(String sourceKind) {
  switch (sourceKind) {
    case 'screen':
      return Icons.desktop_windows_outlined;
    case 'tasks':
      return Icons.task_alt_outlined;
    case 'runs':
      return Icons.monitor_heart_outlined;
    default:
      return Icons.timeline_outlined;
  }
}

List<Widget> _timelineDetailBody(
  TimelineEventItem item,
  VoidCallback? onOpenRun,
) {
  final content = <Widget>[];
  final body = item.sourceKind == 'screen'
      ? item.previewText.trim()
      : item.summary.trim();
  if (body.isNotEmpty) {
    content.add(
      Text(body, style: TextStyle(color: _textSecondary, height: 1.5)),
    );
    content.add(const SizedBox(height: 16));
  }

  switch (item.sourceKind) {
    case 'screen':
      content.addAll(<Widget>[
        _TimelineMetaLine(
          icon: Icons.computer_outlined,
          text:
              '${item.deviceLabel.ifEmpty('Desktop')} · ${item.appName.ifEmpty('Unknown app')}',
        ),
        if (item.windowTitle.isNotEmpty)
          _TimelineMetaLine(
            icon: Icons.web_asset_outlined,
            text: item.windowTitle,
          ),
        _TimelineMetaLine(
          icon: Icons.schedule_outlined,
          text: item.screenSpanLabel,
        ),
      ]);
      break;
    case 'tasks':
    case 'runs':
      content.addAll(<Widget>[
        _TimelineMetaLine(
          icon: item.sourceKind == 'tasks'
              ? Icons.task_alt_outlined
              : Icons.monitor_heart_outlined,
          text: _titleCase(item.eventKind.replaceAll('_', ' ')),
        ),
        if (item.runId.isNotEmpty && onOpenRun != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onOpenRun,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Open run'),
              ),
            ),
          ),
      ]);
      break;
    default:
      content.add(
        _TimelineMetaLine(
          icon: Icons.info_outline_rounded,
          text: _titleCase(item.eventKind.replaceAll('_', ' ')),
        ),
      );
      break;
  }
  return content;
}

class _TimelineMetaLine extends StatelessWidget {
  const _TimelineMetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 16, color: _textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: _textSecondary, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
