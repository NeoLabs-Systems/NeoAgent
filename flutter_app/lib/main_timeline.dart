part of 'main.dart';

class TimelinePanel extends StatelessWidget {
  const TimelinePanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _PageTitle(
            title: 'Timeline',
            subtitle:
                'User-wide activity feed for passive screen sessions, task lifecycle, and run lifecycle.',
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
                  selected: controller.selectedTimelineSources.contains(
                    filter.id,
                  ),
                  label: Text(filter.label),
                  onSelected: (_) => controller.toggleTimelineSource(filter.id),
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
          const SizedBox(height: 16),
          Expanded(
            child: controller.timelineItems.isEmpty
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
                : ListView.separated(
                    itemCount: controller.timelineItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = controller.timelineItems[index];
                      return _TimelineEventCard(
                        item: item,
                        onOpenRun: item.runId.isEmpty
                            ? null
                            : () => unawaited(
                                controller.openRunDetails(item.runId),
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TimelineEventCard extends StatelessWidget {
  const _TimelineEventCard({required this.item, this.onOpenRun});

  final TimelineEventItem item;
  final VoidCallback? onOpenRun;

  @override
  Widget build(BuildContext context) {
    final details = switch (item.sourceKind) {
      'screen' => <Widget>[
        _TimelineMetaLine(
          icon: Icons.computer_outlined,
          text:
              '${item.deviceLabel.ifEmpty('Desktop')} · ${item.appName.ifEmpty('Unknown app')}',
        ),
        if (item.windowTitle.isNotEmpty)
          _TimelineMetaLine(
            icon: Icons.crop_square_rounded,
            text: item.windowTitle,
          ),
        _TimelineMetaLine(
          icon: Icons.schedule_outlined,
          text: item.screenSpanLabel,
        ),
        if (item.previewText.trim().isNotEmpty)
          Text(
            item.previewText.trim(),
            style: TextStyle(color: _textSecondary, height: 1.45),
          ),
      ],
              'tasks' => <Widget>[
        _TimelineMetaLine(
          icon: Icons.task_alt_outlined,
          text: item.eventKind.replaceAll('_', ' '),
        ),
        if (item.summary.trim().isNotEmpty)
          Text(
            item.summary.trim(),
            style: TextStyle(color: _textSecondary, height: 1.45),
          ),
        if (item.runId.isNotEmpty && onOpenRun != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onOpenRun,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Open run'),
            ),
          ),
      ],
      _ => <Widget>[
        _TimelineMetaLine(
          icon: Icons.monitor_heart_outlined,
          text: item.eventKind.replaceAll('_', ' '),
        ),
        if (item.summary.trim().isNotEmpty)
          Text(
            item.summary.trim(),
            style: TextStyle(color: _textSecondary, height: 1.45),
          ),
        if (item.runId.isNotEmpty && onOpenRun != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onOpenRun,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Open run'),
            ),
          ),
      ],
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
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
            const SizedBox(height: 12),
            Text(
              item.title.ifEmpty(item.taskName),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            ...details,
          ],
        ),
      ),
    );
  }
}

class _TimelineMetaLine extends StatelessWidget {
  const _TimelineMetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
