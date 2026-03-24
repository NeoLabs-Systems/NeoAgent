part of 'main.dart';

EdgeInsets _pagePadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 1280) {
    return const EdgeInsets.fromLTRB(36, 28, 36, 36);
  }
  if (width >= 900) {
    return const EdgeInsets.fromLTRB(28, 24, 28, 28);
  }
  return const EdgeInsets.fromLTRB(18, 18, 18, 26);
}

List<AppSection> _mainSections(NeoAgentController controller) {
  return <AppSection>[
    AppSection.chat,
    AppSection.recordings,
    AppSection.runs,
    AppSection.logs,
    AppSection.devices,
    AppSection.scheduler,
    AppSection.skills,
    AppSection.mcp,
    AppSection.memory,
    if (controller.showHealthSection) AppSection.health,
    AppSection.settings,
    AppSection.messaging,
  ];
}

List<Widget> _buildSidebarItems(
  NeoAgentController controller, {
  required ValueChanged<AppSection> onSelect,
}) {
  final widgets = <Widget>[];
  for (final group in SidebarGroup.values) {
    final sections = _mainSections(
      controller,
    ).where((section) => section.group == group).toList();
    if (sections.isEmpty) {
      continue;
    }

    final active = controller.selectedSection.group == group;
    final defaultSection = sections.first;
    final hasChildren = sections.length > 1;

    widgets.add(
      _SidebarButton(
        label: group.label,
        icon: group.icon,
        active: active,
        trailing: hasChildren
            ? Icon(
                active ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: active ? _accent : _textMuted,
              )
            : null,
        onTap: () => onSelect(defaultSection),
      ),
    );

    if (!hasChildren || !active) {
      continue;
    }

    for (final section in sections) {
      widgets.add(
        _SidebarButton(
          label: section.label,
          icon: section.icon,
          active: controller.selectedSection == section,
          indent: 18,
          iconSize: 16,
          fontSize: 12,
          onTap: () => onSelect(section),
        ),
      );
    }
  }
  return widgets;
}

Future<void> _confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
  required Future<void> Function() onConfirm,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: _bgCard,
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
  if (confirmed == true) {
    await onConfirm();
  }
}

Widget _buildHealthSummaryPills(Map<String, dynamic> summary) {
  return Wrap(
    spacing: 10,
    runSpacing: 10,
    children: <Widget>[
      _MetaPill(
        icon: Icons.directions_walk_outlined,
        label: 'Steps ${_asInt(summary['stepsTotal'])}',
      ),
      _MetaPill(
        icon: Icons.favorite_outline,
        label: 'Heart ${_asInt(summary['heartRateRecordCount'])} records',
      ),
      _MetaPill(
        icon: Icons.bedtime_outlined,
        label: 'Sleep ${_asInt(summary['sleepSessionCount'])} sessions',
      ),
      _MetaPill(
        icon: Icons.fitness_center_outlined,
        label: 'Exercise ${_asInt(summary['exerciseSessionCount'])} sessions',
      ),
      _MetaPill(
        icon: Icons.monitor_weight_outlined,
        label: 'Weight ${_asInt(summary['weightRecordCount'])} records',
      ),
    ],
  );
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(subtitle, style: const TextStyle(color: _textSecondary)),
                if (trailing != null) ...<Widget>[
                  const SizedBox(height: 14),
                  trailing!,
                ],
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(color: _textSecondary),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
    );
  }
}

class _RunStatusPanel extends StatelessWidget {
  const _RunStatusPanel({required this.run, required this.tools});

  final ActiveRunState? run;
  final List<ToolEventItem> tools;

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        run?.title ?? 'Live run',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        run == null
                            ? 'Waiting for run events...'
                            : [
                                '${run!.phase}${run!.iteration > 0 ? ' · step ${run!.iteration}' : ''}',
                                if (run!.pendingSteeringCount > 0)
                                  '${run!.pendingSteeringCount} steering ${run!.pendingSteeringCount == 1 ? 'update' : 'updates'} queued',
                              ].join(' · '),
                        style: const TextStyle(color: _textSecondary),
                      ),
                    ],
                  ),
                ),
                if (run != null && run!.model.isNotEmpty)
                  _MetaPill(label: run!.model, icon: Icons.memory_outlined),
              ],
            ),
            if (tools.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: tools.map((tool) => _ToolChip(tool: tool)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({required this.tool});

  final ToolEventItem tool;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (tool.status) {
      case 'running':
        color = _warning;
        break;
      case 'failed':
        color = _danger;
        break;
      default:
        color = _success;
    }
    return Container(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 340),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                tool.type == 'note' ? Icons.info_outline : Icons.build_outlined,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tool.toolName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _StatusPill(label: tool.status, color: color),
            ],
          ),
          if (tool.summary.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              tool.summary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingToggle extends StatelessWidget {
  const _SettingToggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      onChanged: onChanged,
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.title,
    required this.value,
    required this.helper,
  });

  final String title;
  final String value;
  final String helper;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: const TextStyle(color: _textSecondary)),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(helper, style: const TextStyle(color: _textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: _EmptyState(title: title, subtitle: subtitle),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }
}

class _DotStatus extends StatelessWidget {
  const _DotStatus({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({
    required this.label,
    required this.icon,
    this.active = false,
    this.indent = 0,
    this.iconSize = 18,
    this.fontSize = 13,
    this.trailing,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final double indent;
  final double iconSize;
  final double fontSize;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: active ? _accentMuted : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(10 + indent, 9, 10, 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: active
                  ? const Border(left: BorderSide(color: _accent, width: 3))
                  : null,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  icon,
                  size: iconSize,
                  color: active ? _accent : _textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w500,
                      color: active ? _accent : _textSecondary,
                    ),
                  ),
                ),
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: 8),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BlurOrb extends StatelessWidget {
  const _BlurOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color.withValues(alpha: 0.18),
              blurRadius: 120,
              spreadRadius: 30,
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoBadge extends StatelessWidget {
  const _LogoBadge({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[_accent, Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x736366F1),
            blurRadius: 24,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: _borderLight),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.18),
        child: CustomPaint(painter: _NeoAgentLogoPainter()),
      ),
    );
  }
}

class _NeoAgentLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final top = Path()
      ..moveTo(size.width * 0.5, size.height * 0.08)
      ..lineTo(size.width * 0.1, size.height * 0.3)
      ..lineTo(size.width * 0.5, size.height * 0.52)
      ..lineTo(size.width * 0.9, size.height * 0.3)
      ..close();
    canvas.drawPath(top, fillPaint);

    final middle = Path()
      ..moveTo(size.width * 0.1, size.height * 0.52)
      ..lineTo(size.width * 0.5, size.height * 0.74)
      ..lineTo(size.width * 0.9, size.height * 0.52);
    canvas.drawPath(middle, strokePaint);

    final bottom = Path()
      ..moveTo(size.width * 0.1, size.height * 0.72)
      ..lineTo(size.width * 0.5, size.height * 0.94)
      ..lineTo(size.width * 0.9, size.height * 0.72);
    canvas.drawPath(bottom, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const _LogoBadge(size: 52),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: _textMuted),
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.entry});

  final ChatEntry entry;

  @override
  Widget build(BuildContext context) {
    final isUser = entry.role == 'user';
    final isTransient = entry.transient;

    return Opacity(
      opacity: isTransient ? 0.92 : 1,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: <Widget>[
          if (!isUser) ...<Widget>[
            const _MessageAvatar(assistant: true),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: isUser ? _accent : _bgCard,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isUser ? 14 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 14),
                ),
                border: isUser ? null : Border.all(color: _border),
                boxShadow: isUser
                    ? const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x4D6366F1),
                          blurRadius: 12,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: <Widget>[
                  if (!isUser && entry.platformTag != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _StatusPill(
                        label: entry.platformTag!,
                        color: entry.platform == 'live' ? _info : _warning,
                      ),
                    ),
                  MarkdownBody(
                    data: entry.content,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                        .copyWith(
                          p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isUser ? Colors.white : _textPrimary,
                            height: 1.65,
                          ),
                          code: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontFamily:
                                    GoogleFonts.jetBrainsMono().fontFamily,
                                backgroundColor: _bgPrimary,
                                color: isUser ? Colors.white : _textPrimary,
                              ),
                          blockquoteDecoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: const Color(0x22000000),
                          ),
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    entry.createdAtLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isUser ? const Color(0xCCFFFFFF) : _textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...<Widget>[
            const SizedBox(width: 12),
            const _MessageAvatar(assistant: false),
          ],
        ],
      ),
    );
  }
}

class _MessageAvatar extends StatelessWidget {
  const _MessageAvatar({required this.assistant});

  final bool assistant;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: assistant
            ? const LinearGradient(colors: <Color>[_accent, Color(0xFF8B5CF6)])
            : null,
        color: assistant ? null : const Color(0xFF1E1E32),
        boxShadow: assistant
            ? const <BoxShadow>[
                BoxShadow(
                  color: Color(0x596366F1),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Icon(
        assistant ? Icons.auto_awesome : Icons.person,
        size: 16,
        color: assistant ? Colors.white : _textSecondary,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: const Color(0xFF5EEAD4)),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x19EF4444),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x4CEF4444)),
      ),
      child: Text(message, style: const TextStyle(fontSize: 13)),
    );
  }
}

String _ensureModelValue(
  String value,
  List<ModelMeta> models, {
  required bool allowAuto,
}) {
  if (allowAuto && value == 'auto') {
    return 'auto';
  }
  for (final model in models) {
    if (model.id == value) {
      return value;
    }
  }
  if (allowAuto) {
    return 'auto';
  }
  return models.isNotEmpty ? models.first.id : value;
}

String _firstAvailableModelId(List<ModelMeta> models) {
  for (final model in models) {
    if (model.available) {
      return model.id;
    }
  }
  return models.isNotEmpty ? models.first.id : 'auto';
}

String _modelLabelForValue(String value, List<ModelMeta> models) {
  if (value == 'auto' || value.trim().isEmpty) {
    return 'Auto';
  }
  for (final model in models) {
    if (model.id == value) {
      return model.label;
    }
  }
  return value;
}

String _friendlyBaseUrlLabel(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.host.trim().isEmpty) {
    return value;
  }
  final port = uri.hasPort ? ':${uri.port}' : '';
  return '${uri.host}$port';
}

String? _androidRuntimeVersionLabel(Map<String, dynamic> runtime) {
  final apiLevel = _asInt(runtime['apiLevel']);
  final systemImage = runtime['systemImage']?.toString().trim() ?? '';
  if (apiLevel <= 0 && systemImage.isEmpty) {
    return null;
  }

  if (apiLevel > 0) {
    return 'Android $apiLevel';
  }
  return systemImage;
}

Map<String, dynamic> _jsonMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const <String, dynamic>{};
}

String _normalizeSuggestedWhitelistEntry(String platform, String entry) {
  final trimmed = entry.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  switch (platform) {
    case 'whatsapp':
      return trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    case 'telnyx':
      return trimmed.replaceAll(RegExp(r'[^0-9+]'), '');
    case 'discord':
    case 'telegram':
      return trimmed.replaceAll(
        RegExp(r'[^0-9a-z:_-]', caseSensitive: false),
        '',
      );
    default:
      return trimmed;
  }
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _parseTimestamp(String? raw) {
  if (raw == null || raw.isEmpty) {
    return DateTime.now();
  }
  final normalized = raw.contains('T') ? raw : '${raw.replaceFirst(' ', 'T')}Z';
  return DateTime.tryParse(normalized)?.toLocal() ?? DateTime.now();
}

DateTime? _parseOptionalTimestamp(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return _parseTimestamp(raw);
}

String _formatTimestamp(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$month/$day $hour:$minute';
}

String _formatTimeOnly(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}

String _formatDuration(int milliseconds) {
  final totalSeconds = math.max(0, milliseconds ~/ 1000);
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String _formatElapsed(Duration value) {
  final totalSeconds = math.max(0, value.inSeconds);
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  if (minutes > 0) {
    return '${minutes}m ${seconds}s';
  }
  return '${seconds}s';
}

String _formatNumber(int value) {
  final chars = value.abs().toString().split('').reversed.toList();
  final buffer = StringBuffer();
  for (var i = 0; i < chars.length; i++) {
    if (i > 0 && i % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(chars[i]);
  }
  final formatted = buffer.toString().split('').reversed.join();
  return value < 0 ? '-$formatted' : formatted;
}

String _summarizeToolArgs(dynamic raw) {
  if (raw is Map && raw.isNotEmpty) {
    final first = raw.entries.first;
    return '${first.key}: ${first.value}'.trim();
  }
  return '';
}

String _summarizeToolResult(dynamic raw) {
  if (raw == null) {
    return '';
  }
  if (raw is Map) {
    if (raw['timedOut'] == true) {
      final durationMs = _asInt(raw['durationMs']);
      final durationText = durationMs > 0
          ? ' after ${_formatDuration(durationMs)}'
          : '';
      return 'Timed out$durationText';
    }
    if (raw['killed'] == true) {
      return 'Stopped before completion';
    }
    if (raw['error'] != null) {
      return raw['error'].toString();
    }
    if (raw['status'] != null && raw['status'].toString() == 'stopped') {
      return 'Stopped';
    }
    if (raw['message'] != null) {
      return raw['message'].toString();
    }
    if (raw['content'] != null) {
      return raw['content'].toString();
    }
    return raw.entries
        .take(2)
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(' • ');
  }
  final text = raw.toString();
  return text.length > 140 ? '${text.substring(0, 140)}…' : text;
}

String _titleCase(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return '';
  }
  return normalized
      .split(RegExp(r'\s+'))
      .map((part) {
        if (part.isEmpty) {
          return part;
        }
        return '${part[0].toUpperCase()}${part.substring(1)}';
      })
      .join(' ');
}

String _truncateRunText(String value, {int maxLength = 1400}) {
  final trimmed = value.trim();
  if (trimmed.length <= maxLength) {
    return trimmed;
  }
  return '${trimmed.substring(0, maxLength)}\n\n…truncated…';
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}
