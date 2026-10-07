part of 'main.dart';

/// Filters for the Tools page. `all` is the overview: a short, ranked preview
/// of every group with a "See all" jump into the full list.
enum _ToolsSegment { all, integrations, mcp, skills, store }

/// How many rows a group shows in the overview before it is cut off.
const int _toolsOverviewLimit = 3;

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
  String _storeCategory = 'all';
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

  /// skills.sh is searched only where its results show: the overview and the
  /// Store segment.
  bool get _showsSkillsSh =>
      _segment == _ToolsSegment.all || _segment == _ToolsSegment.store;

  void _scheduleSkillsShSearch() {
    final query = _searchController.text.trim();
    if (!_showsSkillsSh || query == _skillsShQuery) return;
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
    _selectSegment(_ToolsSegment.store);
    _searchFocus.requestFocus();
  }

  /// The sidebar's "Tools" entry is [AppSection.integrations] and opens the
  /// overview. The other two sections only arrive from restored preferences
  /// written by builds that navigated to them directly.
  _ToolsSegment _segmentForSection(AppSection section) {
    switch (section) {
      case AppSection.mcp:
        return _ToolsSegment.mcp;
      case AppSection.skills:
        return _ToolsSegment.skills;
      default:
        return _ToolsSegment.all;
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
      if (_segment != _ToolsSegment.skills) {
        return true;
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

  List<StoreSkillItem> _visibleStoreSkills() {
    final items =
        widget.controller.storeSkills
            .where(
              (item) =>
                  _matches(<String>[
                    item.name,
                    item.description,
                    item.category,
                  ]) &&
                  (_segment != _ToolsSegment.store ||
                      _storeCategory == 'all' ||
                      item.category == _storeCategory),
            )
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return items;
  }

  void _selectSegment(_ToolsSegment segment) {
    setState(() => _segment = segment);
    _scheduleSkillsShSearch();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final integrations = _visibleIntegrations();
    final servers = _visibleServers();
    final skills = _visibleSkills();
    final storeSkills = _visibleStoreSkills();

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
                subtitle:
                    appStrings.everythingTheAgentCanUseOfficial,
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
                  _ToolsSegment.all:
                      integrations.length +
                      servers.length +
                      skills.length +
                      storeSkills.length +
                      _skillsShResults.length,
                  _ToolsSegment.integrations: integrations.length,
                  _ToolsSegment.mcp: servers.length,
                  _ToolsSegment.skills: skills.length,
                  _ToolsSegment.store:
                      storeSkills.length + _skillsShResults.length,
                },
                onSelected: _selectSegment,
              ),
              ..._buildFilterRow(controller),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: _buildSections(
                    controller: controller,
                    integrations: integrations,
                    servers: servers,
                    skills: skills,
                    storeSkills: storeSkills,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFilterRow(NeoAgentController controller) {
    final filters = <Widget>[];
    if (_segment == _ToolsSegment.skills) {
      filters.add(
        _ToolsFilterMenu(
          icon: Icons.tune_rounded,
          label: appStrings.status,
          value: _skillStatus,
          options: const <String>['all', 'active', 'draft', 'disabled'],
          onSelected: (value) => setState(() => _skillStatus = value),
        ),
      );
      filters.add(
        _ToolsFilterMenu(
          icon: Icons.source_outlined,
          label: appStrings.source,
          value: _skillSource,
          options: const <String>[
            'all',
            'built-in',
            'learned',
            'user',
            'store',
            'skills.sh',
          ],
          onSelected: (value) => setState(() => _skillSource = value),
        ),
      );
    }
    if (_segment == _ToolsSegment.store) {
      final categories = <String>{
        'all',
        ...controller.storeSkills.map((item) => item.category),
      }.toList();
      filters.add(
        _ToolsFilterMenu(
          icon: Icons.grid_view_rounded,
          label: appStrings.category,
          value: _storeCategory,
          options: categories,
          onSelected: (value) => setState(() => _storeCategory = value),
        ),
      );
    }
    if (filters.isEmpty) {
      return const <Widget>[];
    }
    return <Widget>[
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: filters),
    ];
  }

  List<Widget> _buildSections({
    required NeoAgentController controller,
    required List<OfficialIntegrationItem> integrations,
    required List<McpServerItem> servers,
    required List<SkillItem> skills,
    required List<StoreSkillItem> storeSkills,
  }) {
    final overview = _segment == _ToolsSegment.all;
    final children = <Widget>[];

    if (overview && _query.isEmpty) {
      final discover = storeSkills
          .where((item) => !item.installed)
          .take(8)
          .toList();
      if (discover.isNotEmpty) {
        children.add(
          _ToolsSectionHeader(
            title: appStrings.discover,
            count: discover.length,
            onSeeAll: () => _selectSegment(_ToolsSegment.store),
          ),
        );
        children.add(
          SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: discover.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) => _StoreSkillCard(
                controller: controller,
                item: discover[index],
              ),
            ),
          ),
        );
        children.add(const SizedBox(height: 26));
      }
    }

    children.addAll(
      _buildGroup(
        segment: _ToolsSegment.integrations,
        title: 'Integrations',
        emptyMessage: _query.isEmpty
            ? appStrings.noOfficialIntegrationsAreAvailableYet
            : appStrings.noIntegrationsMatchThisSearch,
        overview: overview,
        tiles: integrations
            .map((item) => _IntegrationTile(controller: controller, item: item))
            .toList(),
      ),
    );
    children.addAll(
      _buildGroup(
        segment: _ToolsSegment.mcp,
        title: appStrings.mcpServers,
        emptyMessage: _query.isEmpty
            ? appStrings.noMcpServersConfiguredYetAddOne
            : appStrings.noMcpServersMatchThisSearch,
        overview: overview,
        tiles: servers
            .map(
              (server) =>
                  _McpServerTile(controller: controller, server: server),
            )
            .toList(),
      ),
    );
    children.addAll(
      _buildGroup(
        segment: _ToolsSegment.skills,
        title: 'Skills',
        emptyMessage:
            _query.isEmpty && _skillStatus == 'all' && _skillSource == 'all'
            ? 'No skills installed yet. Install one from the store or write your own.'
            : appStrings.noSkillsMatchTheseFilters,
        overview: overview,
        tiles: skills
            .map((skill) => _SkillTile(controller: controller, skill: skill))
            .toList(),
      ),
    );
    // On the overview the Discover strip already carries the store, so the
    // group only reappears there to show search matches.
    if (!overview || _query.isNotEmpty) {
      children.addAll(
        _buildGroup(
          segment: _ToolsSegment.store,
          title: 'Store',
          emptyMessage: appStrings.noStoreSkillsMatchThisSearch,
          overview: overview,
          tiles: storeSkills
              .map(
                (item) => _StoreSkillTile(controller: controller, item: item),
              )
              .toList(),
        ),
      );
      children.addAll(_buildSkillsShGroup(controller, overview: overview));
    }

    if (children.isEmpty) {
      children.add(
        _EmptyCard(
          title: appStrings.nothingFound,
          subtitle: _query.isEmpty
              ? appStrings.addAnMcpServerOrInstallA
              : appStrings.noToolMatchesArg1(_searchController.text.trim()),
        ),
      );
    }
    return children;
  }

  List<Widget> _buildSkillsShGroup(
    NeoAgentController controller, {
    required bool overview,
  }) {
    if (_skillsShQuery.length < 2) {
      return overview
          ? const <Widget>[]
          : <Widget>[
              _ToolsSectionHeader(title: 'skills.sh', count: 0),
              _EmptyCard(
                title: appStrings.addFromSkillsSh,
                subtitle: appStrings.skillsShHint,
              ),
            ];
    }
    if (_skillsShLoading && _skillsShResults.isEmpty) {
      return <Widget>[
        _ToolsSectionHeader(title: 'skills.sh', count: 0),
        const LinearProgressIndicator(),
        const SizedBox(height: 26),
      ];
    }
    return _buildGroup(
      segment: _ToolsSegment.store,
      title: 'skills.sh',
      emptyMessage: _skillsShError ?? appStrings.noSkillsShMatches,
      overview: overview,
      tiles: _skillsShResults
          .map(
            (item) => _SkillsShTile(
              key: ValueKey<String>(item.id),
              controller: controller,
              item: item,
            ),
          )
          .toList(),
    );
  }

  /// One titled group of rows. In the overview only the first few rows show,
  /// with a "See all" jump; on a segment the full list shows.
  List<Widget> _buildGroup({
    required _ToolsSegment segment,
    required String title,
    required String emptyMessage,
    required bool overview,
    required List<Widget> tiles,
  }) {
    if (!overview && _segment != segment) {
      return const <Widget>[];
    }
    if (tiles.isEmpty) {
      if (overview) {
        return const <Widget>[];
      }
      return <Widget>[
        _ToolsSectionHeader(title: title, count: 0),
        _EmptyCard(title: appStrings.nothingHereYet2, subtitle: emptyMessage),
      ];
    }
    final shown = overview && tiles.length > _toolsOverviewLimit
        ? tiles.take(_toolsOverviewLimit).toList()
        : tiles;
    return <Widget>[
      _ToolsSectionHeader(
        title: title,
        count: tiles.length,
        onSeeAll: overview && tiles.length > shown.length
            ? () => _selectSegment(segment)
            : null,
      ),
      for (var index = 0; index < shown.length; index++) ...<Widget>[
        shown[index],
        if (index < shown.length - 1) const SizedBox(height: 10),
      ],
      const SizedBox(height: 26),
    ];
  }
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

  static const Map<_ToolsSegment, String> _labels = <_ToolsSegment, String>{
    _ToolsSegment.all: 'All',
    _ToolsSegment.integrations: 'Integrations',
    _ToolsSegment.mcp: 'MCP',
    _ToolsSegment.skills: 'Skills',
    _ToolsSegment.store: 'Store',
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
                label: _labels[segment]!,
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
  const _ToolsSectionHeader({
    required this.title,
    required this.count,
    this.onSeeAll,
  });

  final String title;
  final int count;
  final VoidCallback? onSeeAll;

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
          const Spacer(),
          if (onSeeAll != null)
            TextButton(onPressed: onSeeAll, child: Text(appStrings.seeAll)),
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

class _IntegrationTile extends StatelessWidget {
  const _IntegrationTile({required this.controller, required this.item});

  final NeoAgentController controller;
  final OfficialIntegrationItem item;

  @override
  Widget build(BuildContext context) {
    final needsSetup = !item.env.configured;
    return _ToolTile(
      icon: _OfficialIntegrationIcon(item: item),
      title: item.label,
      subtitle: item.description,
      statusColor: item.isConnected
          ? _success
          : item.hasExpiredAccounts || needsSetup
          ? _warning
          : _textMuted,
      meta: <String>[
        item.statusLabel,
        appStrings.arg1Tools(item.availableToolCount),
        appStrings.arg1Accounts(item.connection.accountCount),
      ],
      trailing: _ToolActionButton(
        label: item.isConnected
            ? 'Manage'
            : needsSetup && item.env.setupMode != 'user'
            ? appStrings.setUp
            : 'Connect',
        primary: !item.isConnected,
        onPressed: () => _openIntegrationDetail(context, controller, item),
      ),
      onTap: () => _openIntegrationDetail(context, controller, item),
    );
  }
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
      statusColor: skill.enabled ? _success : _textMuted,
      meta: <String>[
        skill.enabled ? 'Enabled' : 'Disabled',
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

class _StoreSkillTile extends StatelessWidget {
  const _StoreSkillTile({required this.controller, required this.item});

  final NeoAgentController controller;
  final StoreSkillItem item;

  @override
  Widget build(BuildContext context) {
    final icon = _ToolIconTile(
      color: _toolAccentFor(item.name),
      child: Text(item.icon, style: const TextStyle(fontSize: 22)),
    );
    return _ToolTile(
      icon: icon,
      title: item.name,
      subtitle: item.description,
      statusColor: item.installed ? _success : null,
      meta: <String>[if (item.installed) 'Installed', item.category],
      trailing: _ToolActionButton(
        label: item.installed ? 'Open' : 'Get',
        primary: !item.installed,
        onPressed: () => item.installed
            ? _openStoreSkillDetail(context, controller, item, icon)
            : controller.installStoreSkill(item.id),
      ),
      onTap: () => _openStoreSkillDetail(context, controller, item, icon),
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

/// Wide store card used by the Discover strip on the overview.
class _StoreSkillCard extends StatelessWidget {
  const _StoreSkillCard({required this.controller, required this.item});

  final NeoAgentController controller;
  final StoreSkillItem item;

  @override
  Widget build(BuildContext context) {
    final icon = _ToolIconTile(
      color: _toolAccentFor(item.name),
      child: Text(item.icon, style: const TextStyle(fontSize: 22)),
    );
    return SizedBox(
      width: 268,
      child: Material(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openStoreSkillDetail(context, controller, item, icon),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    icon,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Text(
                    item.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        item.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _ToolActionButton(
                      label: 'Get',
                      onPressed: () => controller.installStoreSkill(item.id),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _openStoreSkillDetail(
  BuildContext context,
  NeoAgentController controller,
  StoreSkillItem item,
  Widget icon,
) {
  _showToolDetail(
    context,
    icon: icon,
    title: item.name,
    subtitle: appStrings.storeSkill,
    child: StoreSkillDetailView(controller: controller, skillId: item.id),
  );
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
