part of 'main.dart';

EdgeInsets _pagePadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 1280) {
    return const EdgeInsets.fromLTRB(40, 34, 40, 40);
  }
  if (width >= 900) {
    return const EdgeInsets.fromLTRB(30, 28, 30, 32);
  }
  return const EdgeInsets.fromLTRB(20, 20, 20, 28);
}

class _AmbientBackdrop extends StatefulWidget {
  const _AmbientBackdrop({required this.child});

  final Widget child;

  @override
  State<_AmbientBackdrop> createState() => _AmbientBackdropState();
}

class _AmbientBackdropState extends State<_AmbientBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: _appBackgroundGradient),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_controller.value);
          return Stack(
            children: <Widget>[
              Positioned(
                top: -120 + (t * 22),
                left: -90 + (t * 18),
                child: _BlurOrb(
                  size: 340,
                  color: _accent.withValues(alpha: 0.9),
                ),
              ),
              Positioned(
                top: 90 - (t * 26),
                right: -120 + (t * 22),
                child: _BlurOrb(
                  size: 280,
                  color: _accentAlt.withValues(alpha: 0.85),
                ),
              ),
              Positioned(
                bottom: -140 + (t * 16),
                left: 100 - (t * 24),
                child: _BlurOrb(
                  size: 360,
                  color: _accent.withValues(alpha: 0.45),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          Colors.white.withValues(alpha: 0.05),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.12),
                        ],
                        stops: const <double>[0, 0.32, 1],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0.75 - (t * 0.15), -0.9 + (t * 0.1)),
                        radius: 0.95,
                        colors: <Color>[
                          _glassHighlight.withValues(alpha: 0.14),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              widget.child,
            ],
          );
        },
      ),
    );
  }
}

class _EntranceMotion extends StatefulWidget {
  const _EntranceMotion({required this.child});

  final Widget child;

  @override
  State<_EntranceMotion> createState() => _EntranceMotionState();
}

class _EntranceMotionState extends State<_EntranceMotion> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _visible = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      offset: _visible ? Offset.zero : const Offset(0, 0.035),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        opacity: _visible ? 1 : 0,
        child: widget.child,
      ),
    );
  }
}

class _GlassSurface extends StatelessWidget {
  const _GlassSurface({
    super.key,
    required this.child,
    this.width,
    this.padding,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.blurSigma = 22,
    this.fillColor,
    this.borderColor,
    this.overlayGradient,
    this.boxShadow,
  });

  final Widget child;
  final double? width;
  final EdgeInsetsGeometry? padding;
  final BorderRadius borderRadius;
  final double blurSigma;
  final Color? fillColor;
  final Color? borderColor;
  final Gradient? overlayGradient;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: boxShadow,
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fillColor ?? _glassFill,
                gradient: overlayGradient ?? _liquidMetalGradient,
                borderRadius: borderRadius,
                border: Border.all(color: borderColor ?? _glassBorder),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  gradient: LinearGradient(
                    colors: <Color>[
                      _glassHighlight.withValues(alpha: 0.2),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.06),
                    ],
                    stops: const <double>[0, 0.22, 1],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: padding ?? EdgeInsets.zero,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

List<AppSection> _mainSections(NeoAgentController controller) {
  return <AppSection>[
    AppSection.chat,
    AppSection.recordings,
    AppSection.runs,
    AppSection.devices,
    AppSection.tasks,
    AppSection.widgets,
    AppSection.integrations,
    AppSection.memory,
    if (controller.showHealthSection) AppSection.health,
    AppSection.settings,
    AppSection.agents,
    AppSection.messaging,
  ];
}

List<Widget> _buildSidebarItems(
  NeoAgentController controller, {
  required ValueChanged<AppSection> onSelect,
  required SidebarGroup? expandedGroup,
  required ValueChanged<SidebarGroup> onToggleGroup,
}) {
  final widgets = <Widget>[];
  final mainSections = _mainSections(controller);
  final selectedSidebarSection = mainSections.contains(
    controller.selectedSection.sidebarSection,
  );
  for (final group in SidebarGroup.values) {
    final sections = mainSections
        .where((section) => section.group == group)
        .toList();
    if (sections.isEmpty) {
      continue;
    }

    final active =
        selectedSidebarSection &&
        controller.selectedSection.sidebarSection.group == group;
    final defaultSection = sections.first;
    final hasChildren = sections.length > 1;
    final expanded = expandedGroup == group;

    widgets.add(
      _SidebarButton(
        label: group.label,
        icon: group.icon,
        active: active,
        trailing: hasChildren
            ? Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: active ? _accent : _textMuted,
              )
            : null,
        onTap: hasChildren
            ? () => onToggleGroup(group)
            : () => onSelect(defaultSection),
      ),
    );

    if (!hasChildren || !expanded) {
      continue;
    }

    for (final section in sections) {
      widgets.add(
        _SidebarButton(
          label: section.label,
          icon: section.icon,
          active: controller.selectedSection.sidebarSection == section,
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
  String confirmLabel = 'Delete',
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
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
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
    final titleStyle = compact
        ? _displayTitleStyle(26)
        : _displayTitleStyle(32);
    final subtitleStyle = TextStyle(
      color: _textSecondary,
      height: compact ? 1.38 : 1.5,
    );
    return _EntranceMotion(
      child: Padding(
        padding: EdgeInsets.only(bottom: compact ? 16 : 24),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('CONTROL SURFACE', style: _sectionEyebrowStyle()),
                  const SizedBox(height: 6),
                  Text(title, style: titleStyle),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Text(subtitle, style: subtitleStyle),
                  ),
                  if (trailing != null) ...<Widget>[
                    const SizedBox(height: 12),
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
                        Text('CONTROL SURFACE', style: _sectionEyebrowStyle()),
                        const SizedBox(height: 8),
                        Text(title, style: titleStyle),
                        const SizedBox(height: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Text(subtitle, style: subtitleStyle),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
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
    final runningCount = tools.where((tool) => tool.status == 'running').length;
    final helperCount = tools.where((tool) => tool.isHelperRelated).length;
    final webCount = tools.where((tool) => tool.isWebRelated).length;

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
                        style: TextStyle(
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
                        style: TextStyle(color: _textSecondary),
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
                children: <Widget>[
                  _MetaPill(
                    label: '${tools.length} events',
                    icon: Icons.timeline_outlined,
                  ),
                  if (runningCount > 0)
                    _MetaPill(
                      label: '$runningCount active',
                      icon: Icons.sync_outlined,
                      color: _warning,
                    ),
                  if (webCount > 0)
                    _MetaPill(
                      label: '$webCount web',
                      icon: Icons.language_outlined,
                    ),
                  if (helperCount > 0)
                    _MetaPill(
                      label: '$helperCount helpers',
                      icon: Icons.account_tree_outlined,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              ...tools.asMap().entries.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(
                    bottom: entry.key == tools.length - 1 ? 0 : 12,
                  ),
                  child: _ToolEventTimelineRow(
                    tool: entry.value,
                    isLast: entry.key == tools.length - 1,
                  ),
                ),
              ),
            ] else
              Text(
                'Waiting for task events...',
                style: TextStyle(color: _textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToolEventTimelineRow extends StatelessWidget {
  const _ToolEventTimelineRow({required this.tool, required this.isLast});

  final ToolEventItem tool;
  final bool isLast;

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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 28,
          child: Column(
            children: <Widget>[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(tool.laneIcon, size: 16, color: color),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 62,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _bgSecondary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            tool.toolName,
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tool.laneLabel,
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusPill(label: tool.statusLabel, color: color),
                  ],
                ),
                if (tool.summary.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    tool.compactSummary,
                    style: TextStyle(color: _textSecondary, height: 1.45),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
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
    return _EntranceMotion(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      _accentHover,
                      _accentAlt.withValues(alpha: 0.9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(value, style: _displayTitleStyle(28)),
              const SizedBox(height: 12),
              Text(
                helper,
                style: TextStyle(color: _textSecondary, height: 1.45),
              ),
            ],
          ),
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
    return _EntranceMotion(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(34),
          child: _EmptyState(title: title, subtitle: subtitle),
        ),
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
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: _textSecondary,
      ),
    );
  }
}

class _DotStatus extends StatelessWidget {
  const _DotStatus({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _GlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderRadius: BorderRadius.circular(999),
      blurSigma: 16,
      fillColor: _bgSecondary.withValues(alpha: 0.28),
      borderColor: _glassBorder.withValues(alpha: 0.8),
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
      padding: const EdgeInsets.only(bottom: 6),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        scale: active ? 1.01 : 1,
        child: _GlassSurface(
          borderRadius: BorderRadius.circular(18),
          blurSigma: 18,
          fillColor: active
              ? _accentMuted.withValues(alpha: 0.32)
              : _bgCard.withValues(alpha: 0.2),
          borderColor: active
              ? _accent.withValues(alpha: 0.32)
              : Colors.white.withValues(alpha: 0.03),
          boxShadow: active
              ? <BoxShadow>[
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.12),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(12 + indent, 12, 12, 12),
                child: Row(
                  children: <Widget>[
                    if (active)
                      Container(
                        width: 6,
                        height: 26,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              _accentHover,
                              _accentAlt.withValues(alpha: 0.9),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    Icon(
                      icon,
                      size: iconSize,
                      color: active ? _accentHover : _textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: active ? _textPrimary : _textSecondary,
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
        ),
      ),
    );
  }
}

class _SidebarIconButton extends StatelessWidget {
  const _SidebarIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: _GlassSurface(
        borderRadius: BorderRadius.circular(999),
        blurSigma: 18,
        fillColor: _bgCard.withValues(alpha: 0.3),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 38,
              height: 38,
              child: Icon(icon, size: 17, color: _textSecondary),
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
        gradient: LinearGradient(
          colors: <Color>[_brandAccent, _brandAccentAlt],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.34),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _brandAccent.withValues(alpha: 0.32),
            blurRadius: 36,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.18),
        child: CustomPaint(painter: _NeoAgentLogoPainter()),
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup({
    required this.logoSize,
    this.titleFontSize = 28,
    this.direction = Axis.vertical,
    this.spacing = 18,
    this.alignment = CrossAxisAlignment.center,
  });

  final double logoSize;
  final double titleFontSize;
  final Axis direction;
  final double spacing;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      'NeoOS',
      style: GoogleFonts.spaceGrotesk(
        fontSize: titleFontSize,
        fontWeight: FontWeight.w700,
        color: _textPrimary,
        letterSpacing: -0.4,
      ),
    );

    if (direction == Axis.horizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _LogoBadge(size: logoSize),
          SizedBox(width: spacing),
          Flexible(child: title),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: <Widget>[
        _LogoBadge(size: logoSize),
        SizedBox(height: spacing),
        title,
      ],
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
          style: TextStyle(
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
            style: TextStyle(fontSize: 13, color: _textMuted),
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.entry, this.onLoadRunDetail});

  final ChatEntry entry;
  final Future<RunDetailSnapshot> Function(String runId)? onLoadRunDetail;

  @override
  Widget build(BuildContext context) {
    final isUser = entry.role == 'user';
    final isTransient = entry.transient;
    final sharedAttachments = (entry.metadata['sharedAttachments'] is List)
        ? (entry.metadata['sharedAttachments'] as List)
              .whereType<Map>()
              .map((item) => SharedChatAttachment.fromJson(item))
              .where((item) => item.isValid)
              .toList(growable: false)
        : const <SharedChatAttachment>[];

    if (entry.typing) {
      return const _TypingIndicatorBubble();
    }

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
                    ? <BoxShadow>[
                        BoxShadow(
                          color: _accentAlt.withValues(alpha: 0.30),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
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
                  if (sharedAttachments.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: sharedAttachments
                          .map((attachment) {
                            final icon =
                                attachment.mimeType.toLowerCase().startsWith(
                                  'video/',
                                )
                                ? Icons.videocam_outlined
                                : attachment.mimeType.toLowerCase().startsWith(
                                    'image/',
                                  )
                                ? Icons.image_outlined
                                : attachment.mimeType.toLowerCase().startsWith(
                                    'audio/',
                                  )
                                ? Icons.audiotrack_outlined
                                : Icons.attach_file_rounded;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? const Color(0x1FFFFFFF)
                                    : _bgSecondary,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: isUser
                                      ? const Color(0x40FFFFFF)
                                      : _border,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    icon,
                                    size: 14,
                                    color: isUser
                                        ? Colors.white
                                        : _textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 180,
                                    ),
                                    child: Text(
                                      attachment.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isUser
                                            ? Colors.white
                                            : _textPrimary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          })
                          .toList(growable: false),
                    ),
                  ],
                  if (!isUser &&
                      entry.runId?.trim().isNotEmpty == true) ...<Widget>[
                    const SizedBox(height: 12),
                    _MessageRunPreview(
                      runId: entry.runId!.trim(),
                      onLoadRunDetail: onLoadRunDetail,
                    ),
                  ],
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

class _MessageRunPreview extends StatefulWidget {
  const _MessageRunPreview({
    required this.runId,
    required this.onLoadRunDetail,
  });

  final String runId;
  final Future<RunDetailSnapshot> Function(String runId)? onLoadRunDetail;

  @override
  State<_MessageRunPreview> createState() => _MessageRunPreviewState();
}

class _MessageRunPreviewState extends State<_MessageRunPreview> {
  late Future<RunDetailSnapshot>? _future;

  @override
  void initState() {
    super.initState();
    _future = widget.onLoadRunDetail?.call(widget.runId);
  }

  @override
  void didUpdateWidget(covariant _MessageRunPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.runId != widget.runId ||
        oldWidget.onLoadRunDetail != widget.onLoadRunDetail) {
      _future = widget.onLoadRunDetail?.call(widget.runId);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_future == null) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<RunDetailSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _MessageRunCardShell(
            child: Row(
              children: <Widget>[
                SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Loading execution details...',
                    style: TextStyle(color: _textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final detail = snapshot.data!;
        final previewSteps = detail.steps.take(4).toList();
        return _MessageRunCardShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      detail.run.title.ifEmpty('Execution'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                  _StatusPill(
                    label: detail.run.statusLabel,
                    color: detail.run.statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _MetaPill(
                    label: '${detail.steps.length} steps',
                    icon: Icons.timeline_outlined,
                  ),
                  if (detail.webStepCount > 0)
                    _MetaPill(
                      label: '${detail.webStepCount} web',
                      icon: Icons.language_outlined,
                    ),
                  if (detail.helperCount > 0)
                    _MetaPill(
                      label: '${detail.helperCount} helpers',
                      icon: Icons.account_tree_outlined,
                    ),
                  if (detail.planningStepCount > 0)
                    _MetaPill(
                      label: '${detail.planningStepCount} planning',
                      icon: Icons.route_outlined,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ...previewSteps.asMap().entries.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(
                    bottom: entry.key == previewSteps.length - 1 ? 0 : 10,
                  ),
                  child: _MessageRunStepRow(
                    step: entry.value,
                    isLast: entry.key == previewSteps.length - 1,
                  ),
                ),
              ),
              if (detail.steps.length > previewSteps.length) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  '${detail.steps.length - previewSteps.length} more steps in run history',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MessageRunCardShell extends StatelessWidget {
  const _MessageRunCardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _GlassSurface(
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(14),
      blurSigma: 18,
      fillColor: _bgPrimary.withValues(alpha: 0.34),
      child: child,
    );
  }
}

class _MessageRunStepRow extends StatelessWidget {
  const _MessageRunStepRow({required this.step, required this.isLast});

  final RunStepItem step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 24,
          child: Column(
            children: <Widget>[
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: step.statusColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(step.laneIcon, size: 14, color: step.statusColor),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 34,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      step.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    step.laneLabel,
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                step.compactSummary,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
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
            ? LinearGradient(colors: <Color>[_accent, _accentAlt])
            : null,
        color: assistant ? null : _bgTertiary,
        boxShadow: assistant
            ? <BoxShadow>[
                BoxShadow(
                  color: _accentAlt.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
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
  const _MetaPill({required this.label, required this.icon, this.color});

  final String label;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accentColor = color ?? _accentAlt;
    return _GlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderRadius: BorderRadius.circular(999),
      blurSigma: 10,
      fillColor: _bgCard.withValues(alpha: 0.86),
      borderColor: _borderLight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: accentColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return _GlassSurface(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: BorderRadius.circular(16),
      blurSigma: 12,
      fillColor: _bgCard.withValues(alpha: 0.72),
      borderColor: _borderLight,
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.72)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 13,
              ),
            ),
          ),
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
        color: _danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.tag),
        border: Border.all(color: _danger.withValues(alpha: 0.30)),
      ),
      child: Text(message, style: TextStyle(color: _danger)),
    );
  }
}

class _InlineSuccess extends StatelessWidget {
  const _InlineSuccess({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _success.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.check_circle_outline, color: _success, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: _success, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobalNetworkBanner extends StatelessWidget {
  const _GlobalNetworkBanner({required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        return Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _warning.withValues(alpha: 0.32)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.cloud_off_outlined,
                            color: _warning,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              controller.offlineBannerMessage,
                              style: TextStyle(
                                color: _textPrimary,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: controller.refreshConnectivityStatus,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _textPrimary,
                          side: BorderSide(
                            color: _warning.withValues(alpha: 0.38),
                          ),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                : Row(
                    children: <Widget>[
                      Icon(Icons.cloud_off_outlined, color: _warning, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          controller.offlineBannerMessage,
                          style: TextStyle(color: _textPrimary, height: 1.35),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: controller.refreshConnectivityStatus,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _textPrimary,
                          side: BorderSide(
                            color: _warning.withValues(alpha: 0.38),
                          ),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _GlobalWebUpdateBanner extends StatelessWidget {
  const _GlobalWebUpdateBanner({required this.monitor});

  final WebAppUpdateMonitor monitor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final content = Text(
          'A newer web build is available on the server. Reload to fetch the latest bundle.',
          style: TextStyle(color: _textPrimary, height: 1.35),
        );
        return Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _accent.withValues(alpha: 0.3)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(
                            Icons.system_update_alt,
                            color: _accent,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: content),
                        ],
                      ),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: monitor.isReloading
                            ? null
                            : monitor.reloadToLatest,
                        child: Text(
                          monitor.isReloading ? 'Reloading...' : 'Reload now',
                        ),
                      ),
                      if (monitor.isReloading) ...<Widget>[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: const LinearProgressIndicator(minHeight: 3),
                        ),
                      ],
                    ],
                  )
                : Row(
                    children: <Widget>[
                      Icon(Icons.system_update_alt, color: _accent, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: content),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: monitor.isReloading
                            ? null
                            : monitor.reloadToLatest,
                        child: Text(
                          monitor.isReloading ? 'Reloading...' : 'Reload now',
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _GlobalAnalyticsConsentBanner extends StatelessWidget {
  const _GlobalAnalyticsConsentBanner({required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;
        final body = Text(
          'NeoAgent uses anonymous analytics to understand startup, navigation, and setup flows. No messages, credentials, or personal content are collected.',
          style: TextStyle(color: _textSecondary, height: 1.35),
        );
        return Material(
          color: Colors.transparent,
          child: _GlassSurface(
            borderRadius: BorderRadius.circular(22),
            blurSigma: 26,
            fillColor: _bgCard.withValues(alpha: 0.94),
            borderColor: _accent.withValues(alpha: 0.18),
            overlayGradient: LinearGradient(
              colors: <Color>[
                _accent.withValues(alpha: 0.12),
                _bgCard.withValues(alpha: 0.88),
                _bgSecondary.withValues(alpha: 0.86),
              ],
              stops: const <double>[0, 0.22, 1],
              begin: const Alignment(-1, -1),
              end: const Alignment(1, 1),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
              BoxShadow(
                color: _accent.withValues(alpha: 0.1),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _accent.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _accent.withValues(alpha: 0.24),
                              ),
                            ),
                            child: Icon(
                              Icons.cookie_outlined,
                              color: _accent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Analytics cookies',
                                  style: TextStyle(
                                    color: _textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                body,
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: controller.declineAnalyticsConsent,
                              child: const Text('Decline'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: controller.acceptAnalyticsConsent,
                              child: const Text('Allow analytics'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _accent.withValues(alpha: 0.24),
                          ),
                        ),
                        child: Icon(
                          Icons.cookie_outlined,
                          color: _accent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Analytics cookies',
                              style: TextStyle(
                                color: _textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            body,
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton(
                        onPressed: controller.declineAnalyticsConsent,
                        child: const Text('Decline'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: controller.acceptAnalyticsConsent,
                        child: const Text('Allow analytics'),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _DesktopCloseDecision {
  const _DesktopCloseDecision({
    required this.keepRunning,
    required this.rememberChoice,
  });

  final bool keepRunning;
  final bool rememberChoice;
}

class _RecordingPermissionBadge extends StatelessWidget {
  const _RecordingPermissionBadge({required this.label, required this.state});

  final String label;
  final RecordingPermissionState state;

  @override
  Widget build(BuildContext context) {
    final (color, icon, text) = switch (state) {
      RecordingPermissionState.granted => (
        _success,
        Icons.check_circle,
        'Ready',
      ),
      RecordingPermissionState.denied => (
        _danger,
        Icons.lock_outline,
        'Blocked',
      ),
      RecordingPermissionState.needsRestart => (
        _warning,
        Icons.restart_alt_rounded,
        'Restart needed',
      ),
      RecordingPermissionState.unsupported => (
        _textSecondary,
        Icons.do_not_disturb_alt_outlined,
        'Unsupported',
      ),
      RecordingPermissionState.unknown => (
        _warning,
        Icons.help_outline,
        'Check access',
      ),
    };

    return _GlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      borderRadius: BorderRadius.circular(16),
      blurSigma: 10,
      fillColor: color.withValues(alpha: 0.09),
      borderColor: color.withValues(alpha: 0.22),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '$label · $text',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _CompanionPermissionBadge extends StatelessWidget {
  const _CompanionPermissionBadge({required this.label, required this.state});

  final String label;
  final String state;

  @override
  Widget build(BuildContext context) {
    final normalized = state.trim().toLowerCase();
    final (color, icon, text) = switch (normalized) {
      'available' => (_success, Icons.check_circle, 'Granted'),
      'required' => (_warning, Icons.lock_outline, 'Needs access'),
      'unsupported' => (
        _textSecondary,
        Icons.do_not_disturb_alt_outlined,
        'Unsupported',
      ),
      _ => (_warning, Icons.help_outline, 'Unknown'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '$label · $text',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _AudioLevelBar extends StatelessWidget {
  const _AudioLevelBar({
    required this.label,
    required this.valueDb,
    required this.color,
    this.compact = false,
  });

  final String label;
  final double valueDb;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final progress = ((valueDb + 72) / 72).clamp(0.0, 1.0);
    return _GlassSurface(
      width: compact ? 168 : 240,
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(18),
      blurSigma: 10,
      fillColor: _bgCard.withValues(alpha: 0.88),
      borderColor: _borderLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              Text(
                valueDb <= -119 ? 'Silent' : '${valueDb.toStringAsFixed(0)} dB',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: compact ? 11 : 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              builder: (context, animatedValue, _) {
                return LinearProgressIndicator(
                  value: animatedValue,
                  minHeight: compact ? 7 : 8,
                  color: color,
                  backgroundColor: _borderLight,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopFloatingToolbar extends StatefulWidget {
  const _DesktopFloatingToolbar({required this.controller});

  final NeoAgentController controller;

  @override
  State<_DesktopFloatingToolbar> createState() =>
      _DesktopFloatingToolbarState();
}

class _DesktopFloatingToolbarState extends State<_DesktopFloatingToolbar> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant _DesktopFloatingToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker() {
    final runtime = widget.controller.recordingRuntime;
    final shouldTick =
        runtime.active &&
        runtime.startedAt != null &&
        runtime.floatingToolbarVisible;
    if (!shouldTick) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final runtime = controller.recordingRuntime;
    if (!runtime.supportsFloatingToolbar ||
        !runtime.active ||
        !runtime.floatingToolbarVisible) {
      return const SizedBox.shrink();
    }

    final elapsed = runtime.startedAt == null
        ? '00:00'
        : _formatDuration(
            DateTime.now().difference(runtime.startedAt!).inMilliseconds,
          );

    return Positioned(
      top: 10,
      left: 0,
      right: 0,
      child: SafeArea(
        child: IgnorePointer(
          ignoring: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: _DesktopFloatingToolbarSurface(
              controller: controller,
              elapsedLabel: elapsed,
              compactWindow: false,
              onOpenMainWindow: null,
            ),
          ),
        ),
      ),
    );
  }
}

class _DetachedDesktopFloatingToolbarShell extends StatefulWidget {
  const _DetachedDesktopFloatingToolbarShell({
    required this.controller,
    required this.onOpenMainWindow,
  });

  final NeoAgentController controller;
  final Future<void> Function() onOpenMainWindow;

  @override
  State<_DetachedDesktopFloatingToolbarShell> createState() =>
      _DetachedDesktopFloatingToolbarShellState();
}

class _DetachedDesktopFloatingToolbarShellState
    extends State<_DetachedDesktopFloatingToolbarShell> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(
    covariant _DetachedDesktopFloatingToolbarShell oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker() {
    final runtime = widget.controller.recordingRuntime;
    final shouldTick =
        runtime.active &&
        runtime.startedAt != null &&
        runtime.floatingToolbarVisible;
    if (!shouldTick) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final runtime = widget.controller.recordingRuntime;
    if (!runtime.active || !runtime.floatingToolbarVisible) {
      return const SizedBox.shrink();
    }

    final elapsed = runtime.startedAt == null
        ? '00:00'
        : _formatDuration(
            DateTime.now().difference(runtime.startedAt!).inMilliseconds,
          );

    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: _DesktopFloatingToolbarSurface(
                controller: widget.controller,
                elapsedLabel: elapsed,
                compactWindow: true,
                onOpenMainWindow: widget.onOpenMainWindow,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _desktopAssistantUsesToggleControls() {
  if (kIsWeb) {
    return false;
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return false;
  }
}

String _desktopAssistantPrimaryLabel(bool isCapturing) {
  if (_desktopAssistantUsesToggleControls()) {
    return isCapturing ? 'Stop and send' : 'Start talking';
  }
  return isCapturing ? 'Release to send' : 'Hold to talk';
}

String _desktopAssistantPrimaryCaption(bool isCapturing) {
  if (_desktopAssistantUsesToggleControls()) {
    return isCapturing
        ? 'Commit the active live capture'
        : 'Click once to begin capturing';
  }
  return isCapturing
      ? 'Stop capture and submit'
      : 'Press and hold for quick capture';
}

String _desktopAssistantIdleHint() {
  return _desktopAssistantUsesToggleControls()
      ? 'Click the mic to start speaking'
      : 'Hold Ctrl+Shift+Space to talk';
}

String _desktopAssistantScreenContextHint(bool enabled) {
  return enabled ? 'Current screen will be attached' : 'Audio only';
}

class _DesktopAssistantControlState {
  const _DesktopAssistantControlState({
    required this.isCapturing,
    required this.isBusy,
    required this.useToggleCapture,
    required this.statusLabel,
    required this.statusColor,
    required this.transcriptPreview,
    required this.primaryLabel,
    required this.primaryCaption,
    required this.primaryIcon,
    required this.primaryColor,
    required this.idleHint,
    required this.screenContextHint,
    required this.sourceSummary,
  });

  factory _DesktopAssistantControlState.fromController(
    NeoAgentController controller, {
    required bool blockedHintVisible,
  }) {
    final liveState = controller.voiceAssistantLiveState;
    final isCapturing = controller.isLiveVoiceCaptureEngaged;
    final includeScreenContext = controller.voiceAssistantIncludeScreenContext;
    final useToggleCapture = _desktopAssistantUsesToggleControls();
    final transcriptPreview = liveState.partialTranscript.trim().isEmpty
        ? liveState.finalTranscript.trim()
        : liveState.partialTranscript.trim();
    return _DesktopAssistantControlState(
      isCapturing: isCapturing,
      isBusy: liveState.isBusy,
      useToggleCapture: useToggleCapture,
      statusLabel: blockedHintVisible
          ? 'Assistant unavailable while recording'
          : (isCapturing
                ? _desktopAssistantPrimaryLabel(true)
                : _desktopAssistantStatusLabel(liveState.state)),
      statusColor: blockedHintVisible
          ? _warning
          : (isCapturing ? _success : _accent),
      transcriptPreview: transcriptPreview,
      primaryLabel: _desktopAssistantPrimaryLabel(isCapturing),
      primaryCaption: _desktopAssistantPrimaryCaption(isCapturing),
      primaryIcon: isCapturing ? Icons.stop_rounded : Icons.mic,
      primaryColor: isCapturing ? _warning : _success,
      idleHint: _desktopAssistantIdleHint(),
      screenContextHint: _desktopAssistantScreenContextHint(
        includeScreenContext,
      ),
      sourceSummary: includeScreenContext ? 'Mic + screen' : 'Direct mic',
    );
  }

  final bool isCapturing;
  final bool isBusy;
  final bool useToggleCapture;
  final String statusLabel;
  final Color statusColor;
  final String transcriptPreview;
  final String primaryLabel;
  final String primaryCaption;
  final IconData primaryIcon;
  final Color primaryColor;
  final String idleHint;
  final String screenContextHint;
  final String sourceSummary;
}

class _VoiceAssistantScreenContextButton extends StatelessWidget {
  const _VoiceAssistantScreenContextButton({
    required this.controller,
    required this.compact,
  });

  final NeoAgentController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = controller.voiceAssistantIncludeScreenContext;
    final onPressed = controller.canCaptureVoiceAssistantScreenContext
        ? () {
            unawaited(controller.toggleVoiceAssistantScreenContext());
          }
        : null;

    if (compact) {
      return IconButton(
        tooltip: enabled
            ? 'Stop including the current screen'
            : 'Include the current screen',
        onPressed: onPressed,
        style: IconButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.all(8),
          minimumSize: const Size(30, 30),
          backgroundColor: enabled
              ? _accent.withValues(alpha: 0.14)
              : _bgSecondary.withValues(alpha: 0.9),
          foregroundColor: enabled ? _accent : _textSecondary,
        ),
        icon: Icon(
          enabled
              ? Icons.desktop_windows_rounded
              : Icons.desktop_windows_outlined,
          size: 15,
        ),
      );
    }

    return _VoiceAssistantActionButton(
      icon: enabled
          ? Icons.desktop_windows_rounded
          : Icons.desktop_windows_outlined,
      label: enabled ? 'Screen on' : 'Screen off',
      onTap: onPressed,
    );
  }
}

class _DesktopAssistantPopupShell extends StatelessWidget {
  const _DesktopAssistantPopupShell({
    required this.controller,
    required this.blockedHintVisible,
    required this.onPrimaryAction,
    required this.onCancel,
  });

  final NeoAgentController controller;
  final bool blockedHintVisible;
  final Future<void> Function() onPrimaryAction;
  final Future<void> Function() onCancel;

  @override
  Widget build(BuildContext context) {
    final assistantUi = _DesktopAssistantControlState.fromController(
      controller,
      blockedHintVisible: blockedHintVisible,
    );

    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 430),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        _bgCard.withValues(alpha: 0.99),
                        _bgSecondary.withValues(alpha: 0.97),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _borderLight.withValues(alpha: 0.9),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: <Widget>[
                      _DesktopAssistantPulseDots(
                        color: assistantUi.statusColor,
                        active: assistantUi.isCapturing || assistantUi.isBusy,
                      ),
                      const SizedBox(width: 12),
                      _DesktopAssistantWaveform(
                        color: assistantUi.statusColor,
                        active: assistantUi.isCapturing,
                        busy: assistantUi.isBusy,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              assistantUi.statusLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                            if (!blockedHintVisible)
                              Text(
                                assistantUi.transcriptPreview.isEmpty
                                    ? '${assistantUi.idleHint} • ${assistantUi.screenContextHint}'
                                    : assistantUi.transcriptPreview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _textMuted,
                                  fontSize: 11.5,
                                  height: 1.35,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _VoiceAssistantScreenContextButton(
                        controller: controller,
                        compact: true,
                      ),
                      const SizedBox(width: 4),
                      FilledButton.icon(
                        onPressed: blockedHintVisible
                            ? null
                            : () {
                                unawaited(onPrimaryAction());
                              },
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          minimumSize: const Size(0, 38),
                          backgroundColor: assistantUi.statusColor,
                          foregroundColor: Colors.white,
                        ),
                        icon: Icon(
                          assistantUi.isCapturing
                              ? Icons.stop_rounded
                              : Icons.mic_rounded,
                          size: 16,
                        ),
                        label: Text(
                          assistantUi.isCapturing ? 'Send' : 'Talk',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cancel',
                        onPressed: () {
                          unawaited(onCancel());
                        },
                        style: IconButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(8),
                          minimumSize: const Size(30, 30),
                          backgroundColor: _bgSecondary.withValues(alpha: 0.9),
                          foregroundColor: _textSecondary,
                        ),
                        icon: const Icon(Icons.close_rounded, size: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _desktopAssistantStatusLabel(String state) {
  switch (state.trim().toLowerCase()) {
    case 'transcribing':
      return 'Transcribing';
    case 'thinking':
      return 'Thinking';
    case 'speaking':
      return 'Speaking';
    case 'listening':
      return 'Listening';
    case 'idle':
    default:
      return 'Ready';
  }
}

class _DesktopAssistantPulseDots extends StatelessWidget {
  const _DesktopAssistantPulseDots({required this.color, required this.active});

  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      child: Wrap(
        spacing: 3,
        runSpacing: 3,
        children: List<Widget>.generate(6, (index) {
          final opacity = active ? 0.35 + (index % 3) * 0.2 : 0.28;
          return Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: color.withValues(alpha: opacity),
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }
}

class _DesktopAssistantWaveform extends StatefulWidget {
  const _DesktopAssistantWaveform({
    required this.color,
    required this.active,
    required this.busy,
  });

  final Color color;
  final bool active;
  final bool busy;

  @override
  State<_DesktopAssistantWaveform> createState() =>
      _DesktopAssistantWaveformState();
}

class _DesktopAssistantWaveformState extends State<_DesktopAssistantWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 980),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _DesktopAssistantWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncAnimation() {
    if (widget.active || widget.busy) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
      return;
    }
    _controller.stop();
    _controller.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    const barCount = 18;
    return SizedBox(
      width: 116,
      height: 18,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            children: List<Widget>.generate(barCount, (index) {
              final phase = _controller.value * 2 * math.pi;
              final wave = math.sin(phase + index * 0.55);
              final minHeight = widget.busy ? 3.0 : 2.0;
              final maxHeight = widget.active
                  ? 12.0
                  : (widget.busy ? 7.0 : 3.0);
              final normalized = widget.active || widget.busy
                  ? (wave + 1) / 2
                  : 0.2;
              final height = minHeight + (maxHeight - minHeight) * normalized;
              return Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: 3,
                    height: height,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(
                        alpha: widget.active ? 0.9 : (widget.busy ? 0.65 : 0.4),
                      ),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _DesktopFloatingToolbarSurface extends StatelessWidget {
  const _DesktopFloatingToolbarSurface({
    required this.controller,
    required this.elapsedLabel,
    required this.compactWindow,
    required this.onOpenMainWindow,
  });

  final NeoAgentController controller;
  final String elapsedLabel;
  final bool compactWindow;
  final Future<void> Function()? onOpenMainWindow;

  @override
  Widget build(BuildContext context) {
    final runtime = controller.recordingRuntime;
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: compactWindow ? double.infinity : 680,
        ),
        margin: compactWindow
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 16),
        padding: EdgeInsets.symmetric(
          horizontal: compactWindow ? 10 : 14,
          vertical: compactWindow ? 8 : 12,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              _bgCard.withValues(alpha: 0.98),
              _bgCard.withValues(alpha: 0.92),
            ],
          ),
          borderRadius: BorderRadius.circular(compactWindow ? 22 : 24),
          border: Border.all(color: _borderLight),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            if (compactWindow)
              const _BrandLockup(
                logoSize: 34,
                titleFontSize: 16,
                direction: Axis.horizontal,
                spacing: 10,
                alignment: CrossAxisAlignment.start,
              ),
            if (compactWindow)
              DragToMoveArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _bgSecondary.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderLight),
                  ),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    size: 14,
                    color: _textMuted,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (runtime.paused ? _warning : _danger).withValues(
                  alpha: 0.10,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (runtime.paused ? _warning : _danger).withValues(
                    alpha: 0.20,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    runtime.paused
                        ? Icons.pause_circle_outline
                        : Icons.fiber_manual_record_rounded,
                    color: runtime.paused ? _warning : _danger,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    runtime.paused ? 'Paused' : 'Recording',
                    style: TextStyle(
                      color: runtime.paused ? _warning : _danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    elapsedLabel,
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            _AudioLevelBar(
              label: 'MIC',
              valueDb: runtime.microphoneLevelDb,
              color: _accent,
              compact: true,
            ),
            _AudioLevelBar(
              label: 'SYSTEM',
              valueDb: runtime.systemAudioLevelDb,
              color: _accentAlt,
              compact: true,
            ),
            if (compactWindow && onOpenMainWindow != null)
              IconButton(
                tooltip: 'Open NeoAgent',
                onPressed: onOpenMainWindow,
                style: IconButton.styleFrom(
                  backgroundColor: _bgSecondary,
                  foregroundColor: _textPrimary,
                ),
                icon: const Icon(Icons.open_in_full_rounded),
              ),
            IconButton(
              tooltip: runtime.paused ? 'Resume recording' : 'Pause recording',
              onPressed: runtime.paused
                  ? controller.resumeDesktopRecording
                  : controller.pauseDesktopRecording,
              style: IconButton.styleFrom(
                backgroundColor: _bgSecondary,
                foregroundColor: _textPrimary,
              ),
              icon: Icon(
                runtime.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              ),
            ),
            IconButton(
              tooltip: 'Stop recording',
              onPressed: controller.isStoppingRecording
                  ? null
                  : controller.stopRecording,
              style: IconButton.styleFrom(
                backgroundColor: _danger.withValues(alpha: 0.12),
                foregroundColor: _danger,
              ),
              icon: const Icon(Icons.stop_rounded),
            ),
            IconButton(
              tooltip: 'Hide floating bar',
              onPressed: controller.hideDesktopFloatingToolbar,
              style: IconButton.styleFrom(
                backgroundColor: _bgSecondary,
                foregroundColor: _textSecondary,
              ),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
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

List<dynamic> _jsonList(
  dynamic value, {
  List<String> nestedKeys = const <String>[
    'items',
    'data',
    'results',
    'rows',
    'values',
    'list',
  ],
  bool fallbackToMapValues = false,
}) {
  if (value is List) {
    return value;
  }
  if (value is Map) {
    for (final key in nestedKeys) {
      final nested = value[key];
      if (nested is List) {
        return nested;
      }
    }
    if (fallbackToMapValues) {
      return value.values.toList(growable: false);
    }
  }
  return const <dynamic>[];
}

List<Map<String, dynamic>> _jsonMapList(
  dynamic value, {
  List<String> nestedKeys = const <String>[
    'items',
    'data',
    'results',
    'rows',
    'values',
    'list',
  ],
  bool fallbackToMapValues = false,
}) {
  return _jsonList(
    value,
    nestedKeys: nestedKeys,
    fallbackToMapValues: fallbackToMapValues,
  ).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
}

List<String> _jsonStringList(
  dynamic value, {
  List<String> nestedKeys = const <String>[
    'items',
    'data',
    'results',
    'rows',
    'values',
    'list',
  ],
  bool fallbackToMapValues = false,
}) {
  return _jsonList(
        value,
        nestedKeys: nestedKeys,
        fallbackToMapValues: fallbackToMapValues,
      )
      .map((item) => item?.toString() ?? '')
      .where((item) => item.isNotEmpty)
      .toList();
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
