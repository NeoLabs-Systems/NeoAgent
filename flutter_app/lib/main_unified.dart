part of 'main.dart';

enum _ToolsPageTab { integrations, mcp, skills }

enum _SettingsWorkspaceSection { app, account, usage, security }

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

class _RunsAndLogsPanelState extends State<RunsAndLogsPanel> {
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Padding(
      padding: _pagePadding(context),
      child: Column(
        children: <Widget>[
          const _PageTitle(
            title: 'Runs',
            subtitle: 'Inspect execution history, failures, and tool traces.',
          ),
          const SizedBox(height: 12),
          Expanded(child: RunsPanel(controller: controller, embedded: true)),
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
  late AppSection _lastControllerSection;

  @override
  void initState() {
    super.initState();
    _lastControllerSection = widget.controller.selectedSection;
    _selectedSection = _sectionForAppSection(_lastControllerSection);
  }

  @override
  void didUpdateWidget(covariant SettingsWorkspacePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controllerSection = widget.controller.selectedSection;
    if (controllerSection != _lastControllerSection) {
      _lastControllerSection = controllerSection;
      _selectedSection = _sectionForAppSection(controllerSection);
    }
  }

  _SettingsWorkspaceSection _sectionForAppSection(AppSection section) {
    return section == AppSection.accountSettings
        ? _SettingsWorkspaceSection.account
        : _SettingsWorkspaceSection.app;
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
                        width: 240,
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
        ],
      ),
    );
  }

  void _selectSection(_SettingsWorkspaceSection section) {
    setState(() => _selectedSection = section);
    final appSection = section == _SettingsWorkspaceSection.app
        ? AppSection.settings
        : AppSection.accountSettings;
    _lastControllerSection = appSection;
    if (widget.controller.selectedSection != appSection) {
      widget.controller.setSelectedSection(appSection);
    }
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
      case _SettingsWorkspaceSection.usage:
        return AccountSettingsPanel(
          controller: widget.controller,
          embedded: true,
          initialTab: AccountSettingsTab.usage,
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
    final items = <_SettingsWorkspaceNavItem>[
      const _SettingsWorkspaceNavItem(
        section: _SettingsWorkspaceSection.app,
        icon: Icons.tune,
        label: 'General',
        description: 'Models, behavior, voice, and workspace',
      ),
      const _SettingsWorkspaceNavItem(
        section: _SettingsWorkspaceSection.account,
        icon: Icons.person_outline,
        label: 'Account',
        description: 'Profile, email, and personal data',
      ),
      const _SettingsWorkspaceNavItem(
        section: _SettingsWorkspaceSection.usage,
        icon: Icons.data_usage_outlined,
        label: 'Usage & limits',
        description: 'Plan usage and allowance details',
      ),
      const _SettingsWorkspaceNavItem(
        section: _SettingsWorkspaceSection.security,
        icon: Icons.security_outlined,
        label: 'Security',
        description: 'Password, 2FA, and active sessions',
      ),
    ];
    if (compact) {
      return DropdownButtonFormField<_SettingsWorkspaceSection>(
        key: ValueKey<_SettingsWorkspaceSection>(selected),
        initialValue: selected,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Settings area',
          prefixIcon: Icon(Icons.settings_outlined),
        ),
        items: items
            .map(
              (item) => DropdownMenuItem<_SettingsWorkspaceSection>(
                value: item.section,
                child: Text(item.label),
              ),
            )
            .toList(),
        onChanged: (section) {
          if (section != null) onSelected(section);
        },
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
            child: Text(
              'Settings areas',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final item in items) _navButton(item),
        ],
      ),
    );
  }

  Widget _navButton(_SettingsWorkspaceNavItem item) {
    final active = selected == item.section;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: active ? _accent.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onSelected(item.section),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  item.icon,
                  size: 20,
                  color: active ? _accent : _textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: active ? _accent : _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.description,
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsWorkspaceNavItem {
  const _SettingsWorkspaceNavItem({
    required this.section,
    required this.icon,
    required this.label,
    required this.description,
  });

  final _SettingsWorkspaceSection section;
  final IconData icon;
  final String label;
  final String description;
}
