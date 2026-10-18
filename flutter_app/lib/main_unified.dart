part of 'main.dart';

/// The three kinds of tool on the Tools page, one tab each. skills.sh search
/// results live inside the Skills tab, next to the skills already installed.
enum _ToolsSegment { integrations, skills, mcp }

class ToolsPanel extends StatefulWidget {
  const ToolsPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<ToolsPanel> createState() => _ToolsPanelState();
}

class _ToolsPanelState extends State<ToolsPanel> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  late _ToolsSegment _segment;
  late AppSection _lastSection;
  String _query = '';
  String _skillStatus = 'all';
  String _skillSource = 'all';
  Timer? _skillsShDebounce;
  int _skillsShRequest = 0;
  String _skillsShQuery = '';
  List<SkillsShItem> _skillsShResults = const <SkillsShItem>[];
  bool _skillsShLoading = false;
  String? _skillsShError;

  @override
  void initState() {
    super.initState();
    _lastSection = widget.controller.selectedSection;
    _segment = _segmentForSection(_lastSection);
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
      _scheduleSkillsShSearch();
    });
  }

  @override
  void didUpdateWidget(covariant ToolsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final section = widget.controller.selectedSection;
    if (section != _lastSection) {
      _lastSection = section;
      _segment = _segmentForSection(section);
    }
  }

  @override
  void dispose() {
    _skillsShDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _scheduleSkillsShSearch() {
    final query = _searchController.text.trim();
    if (_segment != _ToolsSegment.skills || query == _skillsShQuery) return;
    _skillsShDebounce?.cancel();
    _skillsShQuery = query;
    if (query.length < 2) {
      setState(() {
        _skillsShResults = const <SkillsShItem>[];
        _skillsShLoading = false;
        _skillsShError = null;
      });
      return;
    }
    setState(() => _skillsShLoading = true);
    _skillsShDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _runSkillsShSearch(query),
    );
  }

  Future<void> _runSkillsShSearch(String query) async {
    final request = ++_skillsShRequest;
    try {
      final results = await widget.controller.searchSkillsSh(query);
      if (!mounted || request != _skillsShRequest) return;
      setState(() {
        _skillsShResults = results;
        _skillsShError = null;
        _skillsShLoading = false;
      });
    } catch (error) {
      if (!mounted || request != _skillsShRequest) return;
      setState(() {
        _skillsShResults = const <SkillsShItem>[];
        _skillsShError = formatCaughtError(error);
        _skillsShLoading = false;
      });
    }
  }

  void _browseSkillsSh() {
    _selectSegment(_ToolsSegment.skills);
    _searchFocus.requestFocus();
  }

  /// The sidebar's "Tools" entry is [AppSection.integrations]. The other two
  /// sections only arrive from restored preferences written by builds that
  /// navigated to them directly.
  _ToolsSegment _segmentForSection(AppSection section) {
    switch (section) {
      case AppSection.mcp:
        return _ToolsSegment.mcp;
      case AppSection.skills:
        return _ToolsSegment.skills;
      default:
        return _ToolsSegment.integrations;
    }
  }

  bool _matches(List<String> fields) {
    if (_query.isEmpty) return true;
    return fields.any((value) => value.toLowerCase().contains(_query));
  }

  List<OfficialIntegrationItem> _visibleIntegrations() {
    final items =
        widget.controller.officialIntegrations
            .where(
              (item) =>
                  item.env.configured ||
                  item.env.setupMode == 'user' ||
                  item.isConnected,
            )
            .where(
              (item) => _matches(<String>[
                item.label,
                item.description,
                ...item.apps.map((app) => app.label),
              ]),
            )
            .toList()
          ..sort(_compareOfficialIntegrationItems);
    return items;
  }

  List<McpServerItem> _visibleServers() {
    return widget.controller.mcpServers
        .where(
          (server) =>
              _matches(<String>[server.name, server.command, server.status]),
        )
        .toList();
  }

  List<SkillItem> _visibleSkills() {
    return widget.controller.skills.where((skill) {
      if (!_matches(<String>[
        skill.name,
        skill.description,
        skill.category,
        skill.source,
      ])) {
        return false;
      }
      switch (_skillStatus) {
        case 'active':
          if (!skill.enabled || skill.draft) return false;
        case 'draft':
          if (!skill.draft) return false;
        case 'disabled':
          if (skill.enabled) return false;
      }
      return _skillSource == 'all' || skill.source == _skillSource;
    }).toList();
  }

  void _selectSegment(_ToolsSegment segment) {
    setState(() => _segment = segment);
    _scheduleSkillsShSearch();
  }

  /// Opens the integration a link asked for, once the list has loaded it.
  void _openRequestedIntegration() {
    final controller = widget.controller;
    final requested = controller.requestedIntegrationId;
    if (requested == null) return;
    final item = controller.officialIntegrations
        .where((candidate) => candidate.id == requested)
        .firstOrNull;
    if (item == null) return;
    controller.clearRequestedIntegration();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openIntegrationDetail(context, controller, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    _openRequestedIntegration();
    final controller = widget.controller;
    final integrations = _visibleIntegrations();
    final servers = _visibleServers();
    final skills = _visibleSkills();

    return Padding(
      padding: _pagePadding(context),
      // Rows stay scannable on ultra-wide windows instead of stretching across
      // the whole panel.
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _PageTitle(
                title: 'Tools',
                subtitle: appStrings.everythingTheAgentCanUseOfficial,
                trailing: _ToolsAddMenu(
                  controller: controller,
                  onBrowseSkillsSh: _browseSkillsSh,
                ),
              ),
              TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: appStrings.searchToolsIntegrationsAndSkills,
                  prefixIcon: Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: appStrings.clearSearch,
                          onPressed: _searchController.clear,
                          icon: Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              _ToolsSegmentBar(
                selected: _segment,
                counts: <_ToolsSegment, int>{
                  _ToolsSegment.integrations: integrations.length,
                  _ToolsSegment.skills: skills.length,
                  _ToolsSegment.mcp: servers.length,
                },
                onSelected: _selectSegment,
              ),
              ..._buildFilterRow(),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: switch (_segment) {
                    _ToolsSegment.integrations => _buildIntegrations(
                      controller,
                      integrations,
                    ),
                    _ToolsSegment.skills => _buildSkills(controller, skills),
                    _ToolsSegment.mcp => _buildServers(controller, servers),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFilterRow() {
    if (_segment != _ToolsSegment.skills) {
      return const <Widget>[];
    }
    return <Widget>[
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          _ToolsFilterMenu(
            icon: Icons.tune_rounded,
            label: appStrings.status,
            value: _skillStatus,
            options: const <String>['all', 'active', 'draft', 'disabled'],
            onSelected: (value) => setState(() => _skillStatus = value),
          ),
          _ToolsFilterMenu(
            icon: Icons.source_outlined,
            label: appStrings.source,
            value: _skillSource,
            options: const <String>[
              'all',
              'built-in',
              'learned',
              'user',
              'skills.sh',
            ],
            onSelected: (value) => setState(() => _skillSource = value),
          ),
        ],
      ),
    ];
  }

  /// Connected integrations first, then the ones that can still be added.
  /// An integration with only expired accounts counts as connected: it needs
  /// a reconnect, not a first-time setup.
  List<Widget> _buildIntegrations(
    NeoAgentController controller,
    List<OfficialIntegrationItem> integrations,
  ) {
    if (integrations.isEmpty) {
      return <Widget>[
        _EmptyCard(
          title: appStrings.nothingFound,
          subtitle: _query.isEmpty
              ? appStrings.noOfficialIntegrationsAreAvailableYet
              : appStrings.noIntegrationsMatchThisSearch,
        ),
      ];
    }
    final connected = integrations
        .where((item) => item.isConnected || item.hasExpiredAccounts)
        .toList();
    final available = integrations
        .where((item) => !item.isConnected && !item.hasExpiredAccounts)
        .toList();
    return <Widget>[
      if (connected.isNotEmpty) ...<Widget>[
        _ToolsSectionHeader(
          title: appStrings.connected,
          count: connected.length,
        ),
        _IntegrationGrid(controller: controller, items: connected),
        const SizedBox(height: 28),
      ],
      if (available.isNotEmpty) ...<Widget>[
        _ToolsSectionHeader(
          title: appStrings.available,
          count: available.length,
        ),
        _IntegrationGrid(controller: controller, items: available),
      ],
    ];
  }

  List<Widget> _buildSkills(
    NeoAgentController controller,
    List<SkillItem> skills,
  ) {
    final filtered = _skillStatus != 'all' || _skillSource != 'all';
    return <Widget>[
      if (skills.isEmpty)
        _EmptyCard(
          title: appStrings.nothingHereYet2,
          subtitle: _query.isEmpty && !filtered
              ? 'No skills installed yet. Install one from skills.sh or write your own.'
              : appStrings.noSkillsMatchTheseFilters,
        )
      else
        ..._spaced(
          skills
              .map((skill) => _SkillTile(controller: controller, skill: skill))
              .toList(),
        ),
      const SizedBox(height: 28),
      ..._buildSkillsSh(controller),
    ];
  }

  List<Widget> _buildSkillsSh(NeoAgentController controller) {
    final header = _ToolsSectionHeader(
      title: 'skills.sh',
      count: _skillsShResults.length,
    );
    if (_skillsShQuery.length < 2) {
      return <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.travel_explore_rounded, size: 18, color: _textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                appStrings.skillsShHint,
                style: TextStyle(color: _textMuted, fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      ];
    }
    if (_skillsShLoading && _skillsShResults.isEmpty) {
      return <Widget>[header, const LinearProgressIndicator()];
    }
    if (_skillsShResults.isEmpty) {
      return <Widget>[
        header,
        _EmptyCard(
          title: appStrings.nothingFound,
          subtitle: _skillsShError ?? appStrings.noSkillsShMatches,
        ),
      ];
    }
    return <Widget>[
      header,
      ..._spaced(
        _skillsShResults
            .map(
              (item) => _SkillsShTile(
                key: ValueKey<String>(item.id),
                controller: controller,
                item: item,
              ),
            )
            .toList(),
      ),
    ];
  }

  List<Widget> _buildServers(
    NeoAgentController controller,
    List<McpServerItem> servers,
  ) {
    if (servers.isEmpty) {
      return <Widget>[
        _EmptyCard(
          title: appStrings.nothingHereYet2,
          subtitle: _query.isEmpty
              ? appStrings.noMcpServersConfiguredYetAddOne
              : appStrings.noMcpServersMatchThisSearch,
        ),
      ];
    }
    return _spaced(
      servers
          .map((server) => _McpServerTile(controller: controller, server: server))
          .toList(),
    );
  }

  static List<Widget> _spaced(List<Widget> tiles) => <Widget>[
    for (var index = 0; index < tiles.length; index++) ...<Widget>[
      tiles[index],
      if (index < tiles.length - 1) const SizedBox(height: 10),
    ],
  ];
}

class _ToolsAddMenu extends StatelessWidget {
  const _ToolsAddMenu({
    required this.controller,
    required this.onBrowseSkillsSh,
  });

  final NeoAgentController controller;
  final VoidCallback onBrowseSkillsSh;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      builder: (context, menuController, child) => FilledButton.icon(
        onPressed: () => menuController.isOpen
            ? menuController.close()
            : menuController.open(),
        icon: Icon(Icons.add_rounded, size: 18),
        label: Text(appStrings.add),
      ),
      menuChildren: <Widget>[
        MenuItemButton(
          leadingIcon: Icon(Icons.dns_outlined, size: 18),
          onPressed: () => _openMcpEditor(context, controller),
          child: Text(appStrings.addMcpServer),
        ),
        MenuItemButton(
          leadingIcon: Icon(Icons.auto_awesome_outlined, size: 18),
          onPressed: () => _openCreateSkill(context, controller),
          child: Text(appStrings.newSkill),
        ),
        MenuItemButton(
          leadingIcon: Icon(Icons.travel_explore_rounded, size: 18),
          onPressed: onBrowseSkillsSh,
          child: Text(appStrings.addFromSkillsSh),
        ),
      ],
    );
  }
}

class _ToolsSegmentBar extends StatelessWidget {
  const _ToolsSegmentBar({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final _ToolsSegment selected;
  final Map<_ToolsSegment, int> counts;
  final ValueChanged<_ToolsSegment> onSelected;

  static String _label(_ToolsSegment segment) => switch (segment) {
    _ToolsSegment.integrations => appStrings.integrations,
    _ToolsSegment.skills => appStrings.skills,
    _ToolsSegment.mcp => appStrings.mcpServers,
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final segment in _ToolsSegment.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _ToolsSegmentChip(
                label: _label(segment),
                count: counts[segment] ?? 0,
                selected: segment == selected,
                onTap: () => onSelected(segment),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToolsSegmentChip extends StatelessWidget {
  const _ToolsSegmentChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? _accent : _textSecondary;
    return Material(
      color: selected ? _accentMuted : _bgSecondary,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? _accent.withValues(alpha: 0.45) : _border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count',
                style: TextStyle(
                  color: foreground.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolsFilterMenu extends StatelessWidget {
  const _ToolsFilterMenu({
    required this.icon,
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onSelected;

  static String _optionLabel(String option) {
    if (option == 'all') return appStrings.all;
    return option[0].toUpperCase() + option.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: label,
      position: PopupMenuPosition.under,
      initialValue: value,
      onSelected: onSelected,
      itemBuilder: (context) => options
          .map(
            (option) => PopupMenuItem<String>(
              value: option,
              child: Text(_optionLabel(option)),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: _bgSecondary,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: value == 'all' ? _border : _accent.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 15, color: _textSecondary),
            const SizedBox(width: 8),
            Text(
              appStrings.arg1Arg24(label, _optionLabel(value)),
              style: TextStyle(
                color: value == 'all' ? _textSecondary : _accent,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: _textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolsSectionHeader extends StatelessWidget {
  const _ToolsSectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: _textPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$count',
            style: TextStyle(color: _textMuted, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Rounded app-icon tile used by every Tools row so the list scans evenly.
class _ToolIconTile extends StatelessWidget {
  const _ToolIconTile({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// Uniform Tools row: icon, name, one-line summary, a compact meta line, and a
/// single primary control. Details live behind the row tap.
class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.onTap,
    this.statusColor,
    this.trailing,
  });

  final Widget icon;
  final String title;
  final String subtitle;
  final List<String> meta;
  final VoidCallback onTap;
  final Color? statusColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _bgSecondary,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: <Widget>[
              icon,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _textSecondary, fontSize: 13),
                    ),
                    if (meta.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 7),
                      Row(
                        children: <Widget>[
                          if (statusColor != null) ...<Widget>[
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(width: 7),
                          ],
                          Expanded(
                            child: Text(
                              meta.join('  ·  '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _textMuted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact pill control on the right of a [_ToolTile].
class _ToolActionButton extends StatelessWidget {
  const _ToolActionButton({
    required this.label,
    required this.onPressed,
    this.primary = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      padding: WidgetStatePropertyAll<EdgeInsets>(
        const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      ),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
      textStyle: const WidgetStatePropertyAll<TextStyle>(
        TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
    );
    if (primary) {
      return FilledButton(
        onPressed: onPressed,
        style: style,
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: style,
      child: Text(label),
    );
  }
}

/// Integrations as an even grid of cards: three across on wide windows, one
/// on phones.
class _IntegrationGrid extends StatelessWidget {
  const _IntegrationGrid({required this.controller, required this.items});

  final NeoAgentController controller;
  final List<OfficialIntegrationItem> items;

  static const double _gap = 12;
  static const double _minCardWidth = 280;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = ((constraints.maxWidth + _gap) / (_minCardWidth + _gap))
            .floor()
            .clamp(1, 3);
        final width = (constraints.maxWidth - _gap * (columns - 1)) / columns;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: <Widget>[
            for (final item in items)
              SizedBox(
                width: width,
                child: _IntegrationCard(controller: controller, item: item),
              ),
          ],
        );
      },
    );
  }
}

/// One integration in the grid. A connected card says who is connected and
/// which apps are on; an available card says what it is and how to start.
/// Everything else lives in the detail sheet behind the tap.
class _IntegrationCard extends StatelessWidget {
  const _IntegrationCard({required this.controller, required this.item});

  final NeoAgentController controller;
  final OfficialIntegrationItem item;

  @override
  Widget build(BuildContext context) {
    final linked = item.isConnected || item.hasExpiredAccounts;
    final phoneOnly = item.setUpOnPhoneOnly;
    final card = Material(
      color: _bgSecondary,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: phoneOnly
            ? null
            : () => _openIntegrationDetail(context, controller, item),
        child: Container(
          height: 124,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: item.hasExpiredAccounts
                  ? _warning.withValues(alpha: 0.45)
                  : _border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _OfficialIntegrationIcon.named(
                    icon: item.icon,
                    label: item.label,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                          ),
                        ),
                        if (linked) ...<Widget>[
                          const SizedBox(height: 3),
                          _buildStatusLine(),
                        ],
                      ],
                    ),
                  ),
                  if (linked)
                    Icon(Icons.chevron_right_rounded, color: _textMuted)
                  else if (!phoneOnly)
                    Text(
                      item.env.configured ? appStrings.connect : appStrings.setUp,
                      style: TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                phoneOnly ? appStrings.setUpOnPhone : _footnote(linked),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // Set up from the phone app: shown so people know it exists, but muted.
    return phoneOnly ? Opacity(opacity: 0.55, child: card) : card;
  }

  /// Who is connected, counted by person rather than by app connection, or a
  /// reconnect warning when an account expired.
  Widget _buildStatusLine() {
    final expired = item.hasExpiredAccounts;
    final accounts = _connectedAccountLabels(item);
    final label = expired
        ? appStrings.reconnectNeeded
        : accounts.isEmpty
        ? appStrings.connected
        : accounts.length == 1
        ? accounts.first
        : '${accounts.first} +${accounts.length - 1}';
    final color = expired ? _warning : _success;
    return Row(
      children: <Widget>[
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: expired ? _warning : _textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// A connected multi-app integration lists the apps that are on; anything
  /// else shows its description.
  String _footnote(bool linked) {
    if (linked && item.apps.length > 1) {
      final on = item.apps
          .where((app) => app.isConnected)
          .map((app) => app.label)
          .toList();
      if (on.isNotEmpty) return on.join(' · ');
    }
    return item.description;
  }
}

/// Distinct connected accounts across every app of an integration. One Google
/// account connected to Gmail and Calendar is one person, not two.
List<String> _connectedAccountLabels(OfficialIntegrationItem item) {
  final seen = <String>{};
  final labels = <String>[];
  for (final app in item.apps) {
    for (final account in app.accounts) {
      final email = account.accountEmail?.trim() ?? '';
      if (!account.connected || email.isEmpty) continue;
      if (seen.add(email.toLowerCase())) labels.add(email);
    }
  }
  return labels;
}

void _openIntegrationDetail(
  BuildContext context,
  NeoAgentController controller,
  OfficialIntegrationItem item,
) {
  _showToolDetail(
    context,
    icon: _OfficialIntegrationIcon(item: item),
    title: item.label,
    subtitle: appStrings.officialIntegration,
    child: IntegrationDetailView(controller: controller, providerId: item.id),
  );
}

class _McpServerTile extends StatelessWidget {
  const _McpServerTile({required this.controller, required this.server});

  final NeoAgentController controller;
  final McpServerItem server;

  @override
  Widget build(BuildContext context) {
    final running = server.status == 'running';
    final icon = _ToolIconTile(
      color: server.hasError ? _danger : _accentAlt,
      child: Icon(
        Icons.dns_rounded,
        size: 22,
        color: server.hasError ? _danger : _accentAlt,
      ),
    );
    return _ToolTile(
      icon: icon,
      title: server.name,
      subtitle: server.command.ifEmpty(appStrings.noServerUrlSet),
      statusColor: running
          ? _success
          : server.hasError
          ? _danger
          : _textMuted,
      meta: <String>[
        running
            ? 'Running'
            : server.hasError
            ? 'Error'
            : 'Stopped',
        appStrings.arg1Tools(server.toolCount),
        server.authMethodLabel,
      ],
      trailing: _ToolActionButton(
        label: running ? 'Stop' : 'Start',
        primary: !running,
        onPressed: () => running
            ? controller.stopMcpServer(server.id)
            : controller.startMcpServer(server.id),
      ),
      onTap: () => _showToolDetail(
        context,
        icon: icon,
        title: server.name,
        subtitle: appStrings.mcpServer,
        child: McpServerDetailView(controller: controller, serverId: server.id),
      ),
    );
  }
}

class _SkillTile extends StatelessWidget {
  const _SkillTile({required this.controller, required this.skill});

  final NeoAgentController controller;
  final SkillItem skill;

  @override
  Widget build(BuildContext context) {
    final color = _toolAccentFor(skill.name);
    final icon = _ToolIconTile(
      color: color,
      child: Text(
        skill.name.isEmpty ? '?' : skill.name[0].toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    return _ToolTile(
      icon: icon,
      title: skill.name,
      subtitle: skill.description.ifEmpty(appStrings.noDescription),
      meta: <String>[
        skill.category,
        skill.source,
        if (skill.draft) 'Draft',
      ],
      trailing: Switch(
        value: skill.enabled,
        onChanged: (value) => controller.setSkillEnabled(skill.name, value),
      ),
      onTap: () => _showToolDetail(
        context,
        icon: icon,
        title: skill.name,
        subtitle: appStrings.skill,
        child: SkillDetailView(controller: controller, skillName: skill.name),
      ),
    );
  }
}

/// A skills.sh search hit. Installing makes it a regular user skill, so once
/// installed it opens the same detail view as any other skill.
class _SkillsShTile extends StatefulWidget {
  const _SkillsShTile({
    super.key,
    required this.controller,
    required this.item,
  });

  final NeoAgentController controller;
  final SkillsShItem item;

  @override
  State<_SkillsShTile> createState() => _SkillsShTileState();
}

class _SkillsShTileState extends State<_SkillsShTile> {
  late String _installedName = widget.item.installedName;
  bool _installing = false;

  Future<void> _install() async {
    setState(() => _installing = true);
    try {
      final name = await widget.controller.installSkillsShSkill(widget.item);
      if (!mounted) return;
      setState(() => _installedName = name);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appStrings.installedSkillArg1(name))),
      );
    } catch (error) {
      if (mounted) _showFormError(context, formatCaughtError(error));
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  void _open(Widget icon) {
    if (_installedName.isEmpty) {
      url_launcher.launchUrl(
        Uri.parse('https://skills.sh/${widget.item.id}'),
        mode: url_launcher.LaunchMode.externalApplication,
      );
      return;
    }
    _showToolDetail(
      context,
      icon: icon,
      title: _installedName,
      subtitle: appStrings.skill,
      child: SkillDetailView(
        controller: widget.controller,
        skillName: _installedName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final installed = _installedName.isNotEmpty;
    final color = _toolAccentFor(item.name);
    final icon = _ToolIconTile(
      color: color,
      child: Text(
        item.name.isEmpty ? '?' : item.name[0].toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    return _ToolTile(
      icon: icon,
      title: item.name,
      subtitle: item.source,
      statusColor: installed ? _success : null,
      meta: <String>[
        if (installed) 'Installed',
        if (item.installs != null)
          appStrings.skillsShInstallsArg1(_formatInstallCount(item.installs!)),
      ],
      trailing: _ToolActionButton(
        label: installed
            ? appStrings.open
            : _installing
            ? appStrings.installingSkill
            : 'Get',
        primary: !installed,
        onPressed: _installing
            ? null
            : installed
            ? () => _open(icon)
            : _install,
      ),
      onTap: () => _open(icon),
    );
  }
}

String _formatInstallCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
  return '$count';
}

/// Stable per-name accent so skill tiles stay visually distinguishable.
Color _toolAccentFor(String seed) {
  final palette = <Color>[_accent, _accentAlt, _info, _success, _warning];
  var hash = 0;
  for (final unit in seed.codeUnits) {
    hash = (hash + unit) % palette.length;
  }
  return palette[hash];
}

/// Detail sheet for one tool. Keeps every row in the list compact by moving
/// accounts, errors, and destructive actions behind a tap.
Future<void> _showToolDetail(
  BuildContext context, {
  required Widget icon,
  required String title,
  required String subtitle,
  required Widget child,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: _bgCard,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 10, 14),
              child: Row(
                children: <Widget>[
                  icon,
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: _textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: _border),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                child: child,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class RunsAndLogsPanel extends StatefulWidget {
  const RunsAndLogsPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<RunsAndLogsPanel> createState() => _RunsAndLogsPanelState();
}

class _RunsAndLogsPanelState extends State<RunsAndLogsPanel> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _pagePadding(context),
      child: RunsPanel(controller: widget.controller),
    );
  }
}
