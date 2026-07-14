part of 'main.dart';

class TimelinePanel extends StatefulWidget {
  const TimelinePanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<TimelinePanel> createState() => _TimelinePanelState();
}

class _TimelinePanelState extends State<TimelinePanel> {
  int? _selectedEventId;

  void _selectEvent(TimelineEventItem item) {
    if (_selectedEventId == item.id) {
      return;
    }
    setState(() {
      _selectedEventId = item.id;
    });
  }

  Future<void> _showEventDetailsPopup(
    List<TimelineEventItem> items,
    TimelineEventItem initialEvent,
  ) async {
    _selectEvent(initialEvent);
    var selectedIndex = items.indexWhere((item) => item.id == initialEvent.id);
    if (selectedIndex < 0) {
      selectedIndex = 0;
    }

    Widget buildDetail(StateSetter setPopupState) {
      final selectedEvent = items[selectedIndex];
      void selectOffset(int offset) {
        final nextIndex = (selectedIndex + offset).clamp(0, items.length - 1);
        if (nextIndex == selectedIndex) {
          return;
        }
        setPopupState(() {
          selectedIndex = nextIndex;
        });
        _selectEvent(items[nextIndex]);
      }

      return _TimelineDetailPane(
        items: items,
        selectedEvent: selectedEvent,
        selectedIndex: selectedIndex,
        onSelectPrevious: selectedIndex > 0 ? () => selectOffset(-1) : null,
        onSelectNext: selectedIndex < items.length - 1
            ? () => selectOffset(1)
            : null,
        onOpenRun: selectedEvent.runId.isNotEmpty
            ? () => unawaited(
                widget.controller.openRunDetails(selectedEvent.runId),
              )
            : null,
        onClose: () => Navigator.of(context).pop(),
      );
    }

    final compact = MediaQuery.sizeOf(context).width < 760;

    if (compact) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return FractionallySizedBox(
                heightFactor: 0.9,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: buildDetail(setSheetState),
                ),
              );
            },
          );
        },
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 40,
                vertical: 40,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 640,
                  maxHeight: 780,
                ),
                child: buildDetail(setDialogState),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _sortedTimelineEvents(widget.controller.timelineItems);
    final groups = _groupTimelineEvents(items);
    final controller = widget.controller;

    return Padding(
      padding: _pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _PageTitle(
            title: 'Timeline',
            subtitle:
                'Emails, AI actions, tasks and run activity in one chronological feed.',
            trailing: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                for (final filter in const <({String id, String label})>[
                  (id: 'tasks', label: 'Tasks'),
                  (id: 'runs', label: 'Runs'),
                ])
                  FilterChip(
                    selected: controller.selectedTimelineSources.contains(
                      filter.id,
                    ),
                    label: Text(filter.label),
                    onSelected: (_) =>
                        controller.toggleTimelineSource(filter.id),
                    avatar: Icon(
                      _timelineLaneIcon(filter.id),
                      size: 16,
                      color:
                          controller.selectedTimelineSources.contains(filter.id)
                          ? _bgSecondary
                          : _sourceColorForKind(filter.id),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: controller.isRefreshingTimeline
                      ? null
                      : controller.refreshTimeline,
                  icon: controller.isRefreshingTimeline
                      ? const SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_outlined),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ),
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
                : _TimelineFeedPane(
                    groups: groups,
                    selectedEventId: _selectedEventId,
                    onSelectEvent: (item) =>
                        unawaited(_showEventDetailsPopup(items, item)),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TimelineFeedPane extends StatelessWidget {
  const _TimelineFeedPane({
    required this.groups,
    required this.selectedEventId,
    required this.onSelectEvent,
  });

  final List<_TimelineDayGroup> groups;
  final int? selectedEventId;
  final ValueChanged<TimelineEventItem> onSelectEvent;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: _bgSecondary.withValues(alpha: 0.78),
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Timeline feed',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '${groups.fold<int>(0, (sum, group) => sum + group.items.length)} entries',
                  style: TextStyle(color: _textMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(0),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                return _TimelineDaySection(
                  group: group,
                  selectedEventId: selectedEventId,
                  onSelectEvent: onSelectEvent,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineDaySection extends StatelessWidget {
  const _TimelineDaySection({
    required this.group,
    required this.selectedEventId,
    required this.onSelectEvent,
  });

  final _TimelineDayGroup group;
  final int? selectedEventId;
  final ValueChanged<TimelineEventItem> onSelectEvent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: group.isToday ? _accent : _bgTertiary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    group.label,
                    style: TextStyle(
                      color: group.isToday ? _bgSecondary : _textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    group.dateLabel.toUpperCase(),
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                Text(
                  '${group.items.length} events',
                  style: TextStyle(color: _textMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          for (var index = 0; index < group.items.length; index++)
            _TimelineFeedRow(
              item: group.items[index],
              isSelected: group.items[index].id == selectedEventId,
              isFirst: index == 0,
              isLast: index == group.items.length - 1,
              onTap: () => onSelectEvent(group.items[index]),
            ),
        ],
      ),
    );
  }
}

class _TimelineFeedRow extends StatelessWidget {
  const _TimelineFeedRow({
    required this.item,
    required this.isSelected,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final TimelineEventItem item;
  final bool isSelected;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sourceColor = item.sourceColor;
    final chips = _timelineEventChips(item);

    return Material(
      color: isSelected
          ? sourceColor.withValues(alpha: 0.08)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 82,
                child: Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: Text(
                    _formatTimelineTime(item.occurredAt),
                    style: TextStyle(
                      color: isSelected ? _textPrimary : _textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 30,
                child: Column(
                  children: <Widget>[
                    Container(
                      width: 2,
                      height: isFirst ? 24 : 18,
                      color: isFirst ? Colors.transparent : _borderLight,
                    ),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _bgCard,
                        border: Border.all(
                          color: sourceColor.withValues(alpha: 0.95),
                          width: 3,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: sourceColor.withValues(alpha: 0.22),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 2,
                      height: isLast ? 26 : 148,
                      color: isLast ? Colors.transparent : _borderLight,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 14, bottom: 14),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _bgCard.withValues(alpha: 0.98)
                        : _bgSecondary.withValues(alpha: 0.52),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? sourceColor.withValues(alpha: 0.45)
                          : _border,
                    ),
                    boxShadow: isSelected
                        ? <BoxShadow>[
                            BoxShadow(
                              color: sourceColor.withValues(alpha: 0.08),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ]
                        : const <BoxShadow>[],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          _TimelineTypeChip(item: item),
                          const Spacer(),
                          if (isSelected)
                            Icon(
                              Icons.chevron_right_rounded,
                              color: sourceColor,
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        item.title.ifEmpty(item.taskName),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _timelineCardDescription(item),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 14.5,
                          height: 1.4,
                        ),
                      ),
                      if (chips.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            for (final chip in chips) _TimelineInlineChip(chip),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineTypeChip extends StatelessWidget {
  const _TimelineTypeChip({required this.item});

  final TimelineEventItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: item.sourceColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: item.sourceColor.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            _timelineLaneIcon(item.sourceKind),
            size: 15,
            color: item.sourceColor,
          ),
          const SizedBox(width: 8),
          Text(
            item.sourceLabel.toLowerCase(),
            style: TextStyle(
              color: item.sourceColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineInlineChip extends StatelessWidget {
  const _TimelineInlineChip(this.chip);

  final _TimelineChip chip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: chip.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chip.color.withValues(alpha: 0.2)),
      ),
      child: Text(
        chip.label,
        style: TextStyle(
          color: chip.color,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TimelineDetailPane extends StatelessWidget {
  const _TimelineDetailPane({
    required this.items,
    required this.selectedEvent,
    required this.selectedIndex,
    this.onSelectPrevious,
    this.onSelectNext,
    this.onOpenRun,
    this.onClose,
  });

  final List<TimelineEventItem> items;
  final TimelineEventItem? selectedEvent;
  final int selectedIndex;
  final VoidCallback? onSelectPrevious;
  final VoidCallback? onSelectNext;
  final VoidCallback? onOpenRun;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final item = selectedEvent;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: BoxDecoration(
              color: _bgSecondary.withValues(alpha: 0.8),
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'DETAIL',
                        style: TextStyle(
                          color: _textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Event detail',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Previous event',
                  onPressed: onSelectPrevious,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text(
                  item == null ? '0/0' : '${selectedIndex + 1}/${items.length}',
                  style: TextStyle(color: _textMuted, fontSize: 12.5),
                ),
                IconButton(
                  tooltip: 'Next event',
                  onPressed: onSelectNext,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
                if (onClose != null)
                  IconButton(
                    tooltip: 'Close',
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
          ),
          Expanded(
            child: item == null
                ? Center(
                    child: Text(
                      'Select an event from the feed.',
                      style: TextStyle(color: _textSecondary),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: <Widget>[
                            _TimelineStatPill(
                              icon: _timelineLaneIcon(item.sourceKind),
                              label: item.sourceLabel,
                              color: item.sourceColor,
                            ),
                            _TimelineStatPill(
                              icon: Icons.schedule_outlined,
                              label:
                                  '${_formatTimelineTime(item.occurredAt)} · ${_formatTimelineDate(item.occurredAt.toLocal())}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          item.title.ifEmpty(item.taskName),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _timelineDetailDescription(item),
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            _TimelineInlineChip(
                              _TimelineChip(
                                label: _titleCase(
                                  item.eventKind.replaceAll('_', ' '),
                                ),
                                color: item.sourceColor,
                              ),
                            ),
                            for (final chip in _timelineEventChips(
                              item,
                            ).take(4))
                              _TimelineInlineChip(chip),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _TimelineDetailGrid(item: item),
                        if (onOpenRun != null) ...<Widget>[
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: onOpenRun,
                              icon: const Icon(Icons.open_in_new_rounded),
                              label: const Text('Open linked run'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        ..._timelineDetailBody(item, onOpenRun),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TimelineDetailGrid extends StatelessWidget {
  const _TimelineDetailGrid({required this.item});

  final TimelineEventItem item;

  @override
  Widget build(BuildContext context) {
    final cells = _timelineDetailCells(item);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 1,
        crossAxisSpacing: 1,
        childAspectRatio: 1.48,
      ),
      itemCount: cells.length,
      itemBuilder: (context, index) {
        final cell = cells[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _bgSecondary.withValues(alpha: 0.68),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                cell.label,
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.6,
                ),
              ),
              const Spacer(),
              Text(
                cell.value,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cell.emphasized
                      ? cell.color ?? _textPrimary
                      : _textPrimary,
                  fontSize: cell.emphasized ? 18 : 16,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TimelineStatPill extends StatelessWidget {
  const _TimelineStatPill({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? _textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _bgPrimary.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: tone),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: tone,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineDayGroup {
  const _TimelineDayGroup({
    required this.date,
    required this.label,
    required this.dateLabel,
    required this.isToday,
    required this.items,
  });

  final DateTime date;
  final String label;
  final String dateLabel;
  final bool isToday;
  final List<TimelineEventItem> items;
}

class _TimelineChip {
  const _TimelineChip({required this.label, required this.color});

  final String label;
  final Color color;
}

class _TimelineDetailCell {
  const _TimelineDetailCell({
    required this.label,
    required this.value,
    this.emphasized = false,
    this.color,
  });

  final String label;
  final String value;
  final bool emphasized;
  final Color? color;
}

List<TimelineEventItem> _sortedTimelineEvents(List<TimelineEventItem> items) {
  final sorted = List<TimelineEventItem>.of(items);
  sorted.sort((a, b) {
    final timestampCompare = b.occurredAt.compareTo(a.occurredAt);
    if (timestampCompare != 0) {
      return timestampCompare;
    }
    return b.id.compareTo(a.id);
  });
  return sorted;
}

List<_TimelineDayGroup> _groupTimelineEvents(List<TimelineEventItem> items) {
  final groups = <_TimelineDayGroup>[];
  final now = DateTime.now();
  DateTime? activeDate;
  final buffer = <TimelineEventItem>[];

  void flush() {
    if (activeDate == null || buffer.isEmpty) {
      return;
    }
    final day = activeDate;
    groups.add(
      _TimelineDayGroup(
        date: day,
        label: _timelineDayLabel(day, now),
        dateLabel: _formatTimelineDate(day),
        isToday: _isSameDay(day, now),
        items: List<TimelineEventItem>.of(buffer),
      ),
    );
    buffer.clear();
  }

  for (final item in items) {
    final local = item.occurredAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    if (activeDate == null || !_isSameDay(activeDate, day)) {
      flush();
      activeDate = day;
    }
    buffer.add(item);
  }
  flush();
  return groups;
}

List<_TimelineChip> _timelineEventChips(TimelineEventItem item) {
  final chips = <_TimelineChip>[];
  if (item.sourceKind == 'tasks') {
    chips.add(
      _TimelineChip(
        label: _titleCase(item.eventKind.replaceAll('_', ' ')),
        color: _warning,
      ),
    );
    if (item.taskName.trim().isNotEmpty &&
        item.taskName.trim() != item.title.trim()) {
      chips.add(_TimelineChip(label: item.taskName.trim(), color: _success));
    }
  } else if (item.sourceKind == 'runs') {
    chips.add(
      _TimelineChip(
        label: _titleCase(item.eventKind.replaceAll('_', ' ')),
        color: _success,
      ),
    );
    if (item.runId.isNotEmpty) {
      chips.add(_TimelineChip(label: 'Run linked', color: _accentAlt));
    }
  }
  if (item.deviceLabel.trim().isNotEmpty) {
    chips.add(_TimelineChip(label: item.deviceLabel.trim(), color: _info));
  }
  return chips.take(4).toList(growable: false);
}

List<_TimelineDetailCell> _timelineDetailCells(TimelineEventItem item) {
  final cells = <_TimelineDetailCell>[
    _TimelineDetailCell(
      label: 'SOURCE',
      value: item.sourceLabel,
      emphasized: true,
      color: item.sourceColor,
    ),
    _TimelineDetailCell(
      label: 'KIND',
      value: _titleCase(item.eventKind.replaceAll('_', ' ')),
    ),
    _TimelineDetailCell(
      label: 'TIME',
      value:
          '${_formatTimelineTime(item.occurredAt)}\n${_formatTimelineDate(item.occurredAt.toLocal())}',
    ),
  ];

  if (item.sourceKind == 'tasks') {
    cells.add(
      _TimelineDetailCell(
        label: 'TASK',
        value: item.taskName.ifEmpty(item.title),
      ),
    );
    cells.add(
      _TimelineDetailCell(
        label: 'RUN LINK',
        value: item.runId.isNotEmpty ? 'Available' : 'None',
      ),
    );
    cells.add(
      _TimelineDetailCell(
        label: 'SUMMARY',
        value: item.summary.trim().ifEmpty('No summary'),
      ),
    );
  } else if (item.sourceKind == 'runs') {
    cells.add(
      _TimelineDetailCell(
        label: 'RUN',
        value: item.runId.isNotEmpty ? item.runId : 'Unavailable',
      ),
    );
    cells.add(
      _TimelineDetailCell(
        label: 'SUMMARY',
        value: item.summary.trim().ifEmpty('No summary'),
      ),
    );
    cells.add(
      _TimelineDetailCell(
        label: 'TITLE',
        value: item.title.ifEmpty('Untitled run event'),
      ),
    );
  } else {
    cells.add(
      _TimelineDetailCell(
        label: 'SUMMARY',
        value: item.summary.trim().ifEmpty('No summary'),
      ),
    );
  }

  if (cells.length.isOdd) {
    cells.add(const _TimelineDetailCell(label: 'STATUS', value: 'Captured'));
  }
  return cells.take(6).toList(growable: false);
}

String _timelineCardDescription(TimelineEventItem item) {
  switch (item.sourceKind) {
    case 'tasks':
    case 'runs':
      return item.summary.trim().ifEmpty(
        _titleCase(item.eventKind.replaceAll('_', ' ')),
      );
    default:
      return item.summary.trim().ifEmpty(item.sourceLabel);
  }
}

String _timelineDetailDescription(TimelineEventItem item) {
  final body = item.summary.trim();
  if (body.isNotEmpty) {
    return body;
  }
  return _titleCase(item.eventKind.replaceAll('_', ' '));
}

Color _sourceColorForKind(String kind) {
  switch (kind) {
    case 'tasks':
      return _warning;
    case 'runs':
      return _success;
    default:
      return _textSecondary;
  }
}

String _timelineDayLabel(DateTime day, DateTime now) {
  if (_isSameDay(day, now)) {
    return 'Today';
  }
  final yesterday = now.subtract(const Duration(days: 1));
  if (_isSameDay(day, yesterday)) {
    return 'Yesterday';
  }
  return _weekdayShort(day.weekday);
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
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

String _weekdayShort(int weekday) {
  const labels = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return labels[(weekday - 1).clamp(0, labels.length - 1)];
}

IconData _timelineLaneIcon(String sourceKind) {
  switch (sourceKind) {
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

  content.add(
    _TimelineMetaLine(
      icon: item.sourceKind == 'tasks'
          ? Icons.task_alt_outlined
          : Icons.monitor_heart_outlined,
      text: _titleCase(item.eventKind.replaceAll('_', ' ')),
    ),
  );
  if (item.runId.isNotEmpty && onOpenRun != null) {
    content.add(
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onOpenRun,
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Open run'),
          ),
        ),
      ),
    );
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
