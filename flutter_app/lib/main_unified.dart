part of 'main.dart';

enum _ToolsPageTab { integrations, mcp, skills }

enum _RunsPageTab { runs, logs }

enum _SettingsWorkspaceSection { app, account, security }

class ToolsPanel extends StatefulWidget {
  const ToolsPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<ToolsPanel> createState() => _ToolsPanelState();
}

class _ToolsPanelState extends State<ToolsPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _ToolsPageTab.values.length,
      vsync: this,
      initialIndex: _tabForSection(widget.controller.selectedSection).index,
    );
  }

  @override
  void didUpdateWidget(covariant ToolsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectedSection = widget.controller.selectedSection;
    if (selectedSection != oldWidget.controller.selectedSection &&
        (selectedSection == AppSection.integrations ||
            selectedSection == AppSection.mcp ||
            selectedSection == AppSection.skills)) {
      final targetIndex = _tabForSection(selectedSection).index;
      if (_tabController.index != targetIndex) {
        _tabController.index = targetIndex;
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  _ToolsPageTab _tabForSection(AppSection section) {
    switch (section) {
      case AppSection.mcp:
        return _ToolsPageTab.mcp;
      case AppSection.skills:
        return _ToolsPageTab.skills;
      default:
        return _ToolsPageTab.integrations;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final visibleIntegrations = controller.officialIntegrations
        .where(
          (item) =>
              item.env.configured ||
              item.env.setupMode == 'user' ||
              item.isConnected,
        )
        .length;
    return Padding(
      padding: _pagePadding(context),
      child: Column(
        children: <Widget>[
          const _PageTitle(
            title: 'Tools',
            subtitle:
                'Manage official integrations, MCP servers, and reusable skills in one place.',
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: _bgSecondary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: TabBar(
              controller: _tabController,
              dividerColor: _border,
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700),
              tabs: <Widget>[
                Tab(text: 'Integrations ($visibleIntegrations)'),
                Tab(text: 'MCP (${controller.mcpServers.length})'),
                Tab(text: 'Skills (${controller.skills.length})'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                IntegrationsPanel(controller: controller, embedded: true),
                McpPanel(controller: controller, embedded: true),
                SkillsPanel(controller: controller, embedded: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RunsAndLogsPanel extends StatefulWidget {
  const RunsAndLogsPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<RunsAndLogsPanel> createState() => _RunsAndLogsPanelState();
}

class _RunsAndLogsPanelState extends State<RunsAndLogsPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _RunsPageTab.values.length,
      vsync: this,
      initialIndex: _tabForSection(widget.controller.selectedSection).index,
    );
  }

  @override
  void didUpdateWidget(covariant RunsAndLogsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectedSection = widget.controller.selectedSection;
    if (selectedSection != oldWidget.controller.selectedSection &&
        (selectedSection == AppSection.runs ||
            selectedSection == AppSection.logs)) {
      final targetIndex = _tabForSection(selectedSection).index;
      if (_tabController.index != targetIndex) {
        _tabController.index = targetIndex;
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  _RunsPageTab _tabForSection(AppSection section) {
    switch (section) {
      case AppSection.logs:
        return _RunsPageTab.logs;
      default:
        return _RunsPageTab.runs;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Padding(
      padding: _pagePadding(context),
      child: Column(
        children: <Widget>[
          const _PageTitle(
            title: 'Runs & Logs',
            subtitle:
                'Inspect execution history, failures, tool traces, and diagnostics from one workspace.',
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: _bgSecondary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: TabBar(
              controller: _tabController,
              dividerColor: _border,
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700),
              tabs: <Widget>[
                Tab(text: 'Runs (${controller.recentRuns.length})'),
                Tab(text: 'Logs (${controller.logs.length})'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                RunsPanel(controller: controller, embedded: true),
                LogsPanel(controller: controller, embedded: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsWorkspacePanel extends StatefulWidget {
  const SettingsWorkspacePanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<SettingsWorkspacePanel> createState() => _SettingsWorkspacePanelState();
}

class _SettingsWorkspacePanelState extends State<SettingsWorkspacePanel> {
  late _SettingsWorkspaceSection _selectedSection;

  @override
  void initState() {
    super.initState();
    _selectedSection =
        widget.controller.selectedSection == AppSection.accountSettings
        ? _SettingsWorkspaceSection.account
        : _SettingsWorkspaceSection.app;
  }

  @override
  void didUpdateWidget(covariant SettingsWorkspacePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller.selectedSection == AppSection.settings &&
        _selectedSection != _SettingsWorkspaceSection.app) {
      _selectedSection = _SettingsWorkspaceSection.app;
    }
    if (widget.controller.selectedSection == AppSection.accountSettings &&
        _selectedSection == _SettingsWorkspaceSection.app) {
      _selectedSection = _SettingsWorkspaceSection.account;
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.tablet;
    return Padding(
      padding: _pagePadding(context),
      child: Column(
        children: <Widget>[
          const _PageTitle(
            title: 'Settings',
            subtitle:
                'Workspace configuration and account security in one place.',
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _SettingsWorkspaceNav(
                            selected: _selectedSection,
                            compact: true,
                            onSelected: _selectSection,
                          ),
                          const SizedBox(height: 16),
                          Expanded(child: _buildContent()),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SizedBox(
                            width: 220,
                            child: _SettingsWorkspaceNav(
                              selected: _selectedSection,
                              compact: false,
                              onSelected: _selectSection,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(child: _buildContent()),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _selectSection(_SettingsWorkspaceSection section) {
    setState(() => _selectedSection = section);
    if (section == _SettingsWorkspaceSection.app) {
      widget.controller.setSelectedSection(AppSection.settings);
      return;
    }
    widget.controller.setSelectedSection(AppSection.accountSettings);
  }

  Widget _buildContent() {
    switch (_selectedSection) {
      case _SettingsWorkspaceSection.app:
        return SettingsPanel(controller: widget.controller, embedded: true);
      case _SettingsWorkspaceSection.account:
        return AccountSettingsPanel(
          controller: widget.controller,
          embedded: true,
          initialTab: AccountSettingsTab.account,
        );
      case _SettingsWorkspaceSection.security:
        return AccountSettingsPanel(
          controller: widget.controller,
          embedded: true,
          initialTab: AccountSettingsTab.security,
        );
    }
  }
}

class _SettingsWorkspaceNav extends StatelessWidget {
  const _SettingsWorkspaceNav({
    required this.selected,
    required this.compact,
    required this.onSelected,
  });

  final _SettingsWorkspaceSection selected;
  final bool compact;
  final ValueChanged<_SettingsWorkspaceSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _navButton(
        section: _SettingsWorkspaceSection.app,
        icon: Icons.tune,
        label: 'App Settings',
      ),
      _navButton(
        section: _SettingsWorkspaceSection.account,
        icon: Icons.person_outline,
        label: 'Account',
      ),
      _navButton(
        section: _SettingsWorkspaceSection.security,
        icon: Icons.security_outlined,
        label: 'Security',
      ),
    ];
    return compact
        ? Wrap(spacing: 8, runSpacing: 8, children: items)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: items,
          );
  }

  Widget _navButton({
    required _SettingsWorkspaceSection section,
    required IconData icon,
    required String label,
  }) {
    final button = _SidebarButton(
      label: label,
      icon: icon,
      active: selected == section,
      onTap: () => onSelected(section),
    );
    if (compact) {
      return button;
    }
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: button);
  }
}
