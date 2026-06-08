part of 'main.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model Picker — option type, helpers, button, and dialog
// ─────────────────────────────────────────────────────────────────────────────

class _ModelPickerOption {
  const _ModelPickerOption({
    required this.value,
    required this.label,
    this.group = '',
    this.subtitle,
    this.color,
    this.icon,
    this.isAuto = false,
    this.priceTier,
  });

  final String value;
  final String label;
  final String group;
  final String? subtitle;
  final Color? color;
  final IconData? icon;
  final bool isAuto;
  /// 'free' | 'cheap' | 'medium' | 'expensive' | null
  final String? priceTier;
}

// ─── Provider helpers ─────────────────────────────────────────────────────────

Color _providerPickerColor(String provider) {
  final String p = provider.toLowerCase();
  if (p.contains('google') || p.contains('gemini')) {
    return const Color(0xFF4285F4);
  }
  if (p.contains('openai') || p.contains('gpt') || p.contains('codex')) {
    return const Color(0xFF10A37F);
  }
  if (p.contains('anthropic') || p.contains('claude')) {
    return const Color(0xFFD97757);
  }
  if (p.contains('meta') || p.contains('llama')) return const Color(0xFF0668E1);
  if (p.contains('mistral')) return const Color(0xFFF97316);
  if (p.contains('grok') || p.contains('xai')) return const Color(0xFF9B5DE5);
  if (p.contains('copilot') || p.contains('github')) {
    return const Color(0xFF238636);
  }
  if (p.contains('openrouter')) return const Color(0xFF6366F1);
  if (p.contains('nvidia')) return const Color(0xFF76B900);
  if (p.contains('minimax')) return const Color(0xFF0EA5E9);
  if (p.contains('deepgram')) return const Color(0xFF13D4A0);
  if (p.contains('ollama')) return const Color(0xFF6C8EBF);
  return const Color(0xFF7C8CFF);
}

IconData _providerPickerIcon(String provider) {
  final String p = provider.toLowerCase();
  if (p.contains('google') || p.contains('gemini')) {
    return Icons.auto_awesome_rounded;
  }
  if (p.contains('openai') || p.contains('gpt') || p.contains('codex')) {
    return Icons.bolt_rounded;
  }
  if (p.contains('anthropic') || p.contains('claude')) {
    return Icons.menu_book_rounded;
  }
  if (p.contains('meta') || p.contains('llama')) {
    return Icons.visibility_rounded;
  }
  if (p.contains('grok') || p.contains('xai')) return Icons.psychology_rounded;
  if (p.contains('copilot') || p.contains('github')) return Icons.code_rounded;
  if (p.contains('openrouter')) return Icons.hub_rounded;
  if (p.contains('nvidia')) return Icons.speed_rounded;
  if (p.contains('minimax')) return Icons.water_rounded;
  if (p.contains('deepgram')) return Icons.hearing_rounded;
  if (p.contains('ollama')) return Icons.device_hub_rounded;
  return Icons.memory_rounded;
}

String _providerPickerLabel(String id) {
  const Map<String, String> labels = <String, String>{
    'anthropic': 'Anthropic',
    'openai': 'OpenAI',
    'google': 'Google',
    'gemini': 'Google',
    'meta': 'Meta',
    'mistral': 'Mistral',
    'grok': 'xAI',
    'grok-oauth': 'xAI (OAuth)',
    'xai': 'xAI',
    'ollama': 'Ollama',
    'github-copilot': 'GitHub Copilot',
    'openai-codex': 'OpenAI Codex',
    'claude-code': 'Claude Code',
    'openrouter': 'OpenRouter',
    'nvidia': 'NVIDIA NIM',
    'minimax': 'MiniMax',
    'deepgram': 'Deepgram',
  };
  return labels[id.toLowerCase()] ?? id;
}

// ─── Option builders ──────────────────────────────────────────────────────────

List<_ModelPickerOption> _modelPickerOptions(
  List<ModelMeta> models, {
  bool allowAuto = false,
}) {
  return <_ModelPickerOption>[
    if (allowAuto)
      const _ModelPickerOption(
        value: 'auto',
        label: 'Smart Selector',
        subtitle: 'Auto-routes to the best available model',
        icon: Icons.auto_awesome_outlined,
        isAuto: true,
      ),
    ...models.map((ModelMeta m) {
      final List<String> parts = <String>[];
      if (m.provider.isNotEmpty) parts.add(_providerPickerLabel(m.provider));
      if (m.purpose.isNotEmpty) parts.add(m.purpose);
      return _ModelPickerOption(
        value: m.id,
        label: m.label,
        group: m.provider,
        subtitle: parts.isNotEmpty ? parts.join(' · ') : null,
        color: _providerPickerColor(m.provider),
        icon: _providerPickerIcon(m.provider),
        priceTier: m.priceTier,
      );
    }),
  ];
}

List<_ModelPickerOption> _simplePickerOptions(List<String> values) {
  return values
      .map((String v) => _ModelPickerOption(value: v, label: v))
      .toList();
}

// ─────────────────────────────────────────────────────────────────────────────
// Model Picker Button — drop-in trigger that opens the dialog
// ─────────────────────────────────────────────────────────────────────────────

class _ModelPickerButton extends StatelessWidget {
  const _ModelPickerButton({
    required this.value,
    required this.options,
    required this.onChanged,
    required this.dialogTitle,
  });

  final String value;
  final List<_ModelPickerOption> options;
  final ValueChanged<String?> onChanged;
  final String dialogTitle;

  _ModelPickerOption get _current => options.firstWhere(
        (o) => o.value == value,
        orElse: () => _ModelPickerOption(value: value, label: value),
      );

  @override
  Widget build(BuildContext context) {
    final _ModelPickerOption current = _current;
    final Color iconColor = current.isAuto
        ? _accentHover
        : (current.color ?? _textSecondary);
    final IconData iconData = current.isAuto
        ? Icons.auto_awesome_outlined
        : (current.icon ?? Icons.memory_rounded);
    final bool showShell = current.icon != null || current.isAuto;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openPicker(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: <Widget>[
              if (showShell) ...<Widget>[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(iconData, size: 16, color: iconColor),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  current.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.unfold_more_rounded, size: 16, color: _textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 230),
      transitionBuilder: (
        BuildContext ctx,
        Animation<double> animation,
        Animation<double> secondary,
        Widget child,
      ) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
      pageBuilder: (
        BuildContext dialogContext,
        Animation<double> animation,
        Animation<double> secondary,
      ) {
        return _ModelPickerDialog(
          title: dialogTitle,
          options: options,
          currentValue: value,
          onChanged: (String v) {
            onChanged(v);
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Model Picker Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _ModelPickerDialog extends StatefulWidget {
  const _ModelPickerDialog({
    required this.title,
    required this.options,
    required this.currentValue,
    required this.onChanged,
  });

  final String title;
  final List<_ModelPickerOption> options;
  final String currentValue;
  final ValueChanged<String> onChanged;

  @override
  State<_ModelPickerDialog> createState() => _ModelPickerDialogState();
}

class _ModelPickerDialogState extends State<_ModelPickerDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_ModelPickerOption> get _filtered {
    if (_query.isEmpty) return widget.options;
    final String q = _query.toLowerCase();
    return widget.options.where((_ModelPickerOption o) {
      return o.label.toLowerCase().contains(q) ||
          (o.subtitle?.toLowerCase().contains(q) ?? false) ||
          o.group.toLowerCase().contains(q) ||
          o.value.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<_ModelPickerOption> filtered = _filtered;
    final _ModelPickerOption? autoOption =
        filtered.where((o) => o.isAuto).firstOrNull;
    final List<_ModelPickerOption> regularOptions =
        filtered.where((o) => !o.isAuto).toList();

    final List<String> groups = <String>[];
    final Map<String, List<_ModelPickerOption>> grouped =
        <String, List<_ModelPickerOption>>{};
    for (final _ModelPickerOption opt in regularOptions) {
      if (!grouped.containsKey(opt.group)) {
        groups.add(opt.group);
        grouped[opt.group] = <_ModelPickerOption>[];
      }
      grouped[opt.group]!.add(opt);
    }

    final bool hasGroups = groups.any((String g) => g.isNotEmpty);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          minWidth: 300,
          maxHeight: MediaQuery.sizeOf(context).height * 0.76,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Material(
            color: _bgCard,
            borderRadius: BorderRadius.circular(20),
            elevation: 24,
            shadowColor: Colors.black.withValues(alpha: 0.5),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _borderLight),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 10, 12),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              widget.title,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: _textSecondary,
                            ),
                            style: IconButton.styleFrom(
                              minimumSize: const Size(36, 36),
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: TextField(
                        controller: _searchCtrl,
                        autofocus: true,
                        onChanged: (String v) =>
                            setState(() => _query = v.trim()),
                        style: TextStyle(color: _textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search…',
                          hintStyle: TextStyle(color: _textMuted, fontSize: 14),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: _textMuted,
                          ),
                          suffixIcon: _query.isNotEmpty
                              ? GestureDetector(
                                  onTap: () => setState(() {
                                    _searchCtrl.clear();
                                    _query = '';
                                  }),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Icon(
                                      Icons.cancel_rounded,
                                      size: 16,
                                      color: _textMuted,
                                    ),
                                  ),
                                )
                              : null,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                          filled: true,
                          fillColor: _bgSecondary,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _accent, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    Divider(height: 1, thickness: 1, color: _border),
                    // List
                    Flexible(
                      child: filtered.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(36),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.search_off_rounded,
                                    size: 36,
                                    color: _textMuted,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No results for "$_query"',
                                    style: TextStyle(
                                      color: _textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              shrinkWrap: true,
                              children: <Widget>[
                                if (autoOption != null) ...<Widget>[
                                  _PickerRow(
                                    option: autoOption,
                                    selected:
                                        widget.currentValue == autoOption.value,
                                    onTap: () =>
                                        widget.onChanged(autoOption.value),
                                  ),
                                  if (regularOptions.isNotEmpty)
                                    Divider(
                                      height: 1,
                                      indent: 14,
                                      endIndent: 14,
                                      color: _border,
                                    ),
                                ],
                                for (final String group in groups) ...<Widget>[
                                  if (hasGroups && group.isNotEmpty)
                                    _PickerGroupHeader(
                                      label: _providerPickerLabel(group),
                                      color: _providerPickerColor(group),
                                    ),
                                  for (final _ModelPickerOption opt
                                      in grouped[group]!)
                                    _PickerRow(
                                      option: opt,
                                      selected:
                                          widget.currentValue == opt.value,
                                      onTap: () => widget.onChanged(opt.value),
                                    ),
                                ],
                              ],
                            ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _PriceTierChip extends StatelessWidget {
  const _PriceTierChip({required this.tier});

  final String tier;

  @override
  Widget build(BuildContext context) {
    final (String text, Color color) = switch (tier) {
      'free'      => ('FREE',  const Color(0xFF22C55E)),
      'cheap'     => ('\$',    const Color(0xFF4ADE80)),
      'medium'    => ('\$\$',  const Color(0xFFF59E0B)),
      'expensive' => ('\$\$\$', const Color(0xFFEF4444)),
      _           => ('', Colors.transparent),
    };
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _PickerGroupHeader extends StatelessWidget {
  const _PickerGroupHeader({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: _textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: _border)),
        ],
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _ModelPickerOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = option.isAuto
        ? _accentHover
        : (option.color ?? _textSecondary);
    final IconData iconData = option.isAuto
        ? Icons.auto_awesome_outlined
        : (option.icon ?? Icons.memory_rounded);
    final bool showShell = option.icon != null || option.isAuto;

    return Material(
      color: selected
          ? _accentMuted.withValues(alpha: 0.15)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: <Widget>[
              if (showShell) ...<Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color:
                        iconColor.withValues(alpha: selected ? 0.2 : 0.11),
                    borderRadius: BorderRadius.circular(10),
                    border: selected
                        ? Border.all(
                            color: iconColor.withValues(alpha: 0.38),
                          )
                        : null,
                  ),
                  child: Icon(iconData, size: 18, color: iconColor),
                ),
                const SizedBox(width: 12),
              ] else
                const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      option.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selected ? _accentHover : _textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (option.subtitle != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        option.subtitle!,
                        style: TextStyle(fontSize: 12, color: _textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (option.priceTier != null) ...<Widget>[
                _PriceTierChip(tier: option.priceTier!),
                const SizedBox(width: 6),
              ],
              SizedBox(
                width: 20,
                child: selected
                    ? Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: _accentHover,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
