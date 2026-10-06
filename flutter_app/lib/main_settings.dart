part of 'main.dart';

/// The pages this device shows. The System page manages the runtime on this
/// computer, so it exists on desktop only.
List<SettingsPage> _visibleSettingsPages() => SettingsPage.values
    .where((page) => page != SettingsPage.system || _supportsDesktopShell)
    .toList(growable: false);

/// The one Settings screen. Account, agent and app settings share a single
/// list, every page is one tap away, and a page never stacks more than one
/// dialog or sheet on top of itself.
class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  final TextEditingController _searchController = TextEditingController();

  /// The setting a search result pointed at. Its page scrolls to it and
  /// flashes it once.
  _SettingsHighlight? _highlight;

  NeoAgentController get _controller => widget.controller;

  String get _query => _searchController.text.trim();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openPage(SettingsPage page, {String? anchor}) {
    _searchController.clear();
    setState(() {
      _highlight = anchor == null ? null : _SettingsHighlight(anchor);
    });
    _controller.setSettingsPage(page);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final page = _controller.settingsPage;
        if (constraints.maxWidth >= 760) {
          final shown = page ?? SettingsPage.profile;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                width: 268,
                decoration: BoxDecoration(
                  color: _bgSecondary,
                  border: Border(right: BorderSide(color: _border)),
                ),
                child: _SettingsNav(
                  controller: _controller,
                  searchController: _searchController,
                  onSearchChanged: () => setState(() {}),
                  selected: _query.isEmpty ? shown : null,
                  onOpen: _openPage,
                  compact: false,
                ),
              ),
              Expanded(
                child: _query.isEmpty
                    ? _SettingsPageView(
                        key: ValueKey<SettingsPage>(shown),
                        controller: _controller,
                        page: shown,
                        highlight: _highlight,
                      )
                    : ListView(
                        padding: _pagePadding(context),
                        children: <Widget>[
                          _SettingsSearchResults(
                            controller: _controller,
                            query: _query,
                            onOpen: _openPage,
                          ),
                        ],
                      ),
              ),
            ],
          );
        }
        if (page == null || _query.isNotEmpty) {
          return _SettingsNav(
            controller: _controller,
            searchController: _searchController,
            onSearchChanged: () => setState(() {}),
            selected: null,
            onOpen: _openPage,
            compact: true,
          );
        }
        // On a phone a page sits on top of the list: back returns to it.
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _controller.setSettingsPage(null);
          },
          child: _SettingsPageView(
            key: ValueKey<SettingsPage>(page),
            controller: _controller,
            page: page,
            highlight: _highlight,
            onBack: () => _controller.setSettingsPage(null),
          ),
        );
      },
    );
  }
}

/// The page list: a rail beside the open page on wide screens, the whole
/// screen on a phone. A search replaces the list with matching settings.
class _SettingsNav extends StatelessWidget {
  const _SettingsNav({
    required this.controller,
    required this.searchController,
    required this.onSearchChanged,
    required this.selected,
    required this.onOpen,
    required this.compact,
  });

  final NeoAgentController controller;
  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final SettingsPage? selected;
  final void Function(SettingsPage page, {String? anchor}) onOpen;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final query = searchController.text.trim();
    final pages = _visibleSettingsPages();
    return ListView(
      padding: compact
          ? _pagePadding(context)
          : const EdgeInsets.fromLTRB(14, 26, 14, 24),
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(compact ? 2 : 10, 0, 0, 14),
          child: Text(
            appStrings.settings,
            style: compact
                ? _displayTitleStyle(26)
                : TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: _textPrimary,
                  ),
          ),
        ),
        _SettingsSearchField(
          controller: searchController,
          onChanged: onSearchChanged,
        ),
        if (compact && query.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          _SettingsSearchResults(
            controller: controller,
            query: query,
            onOpen: onOpen,
          ),
        ] else
          for (final scope in SettingsScope.values)
            ..._scopeSection(
              scope,
              pages.where((page) => page.scope == scope).toList(),
            ),
      ],
    );
  }

  List<Widget> _scopeSection(SettingsScope scope, List<SettingsPage> pages) {
    if (pages.isEmpty) return const <Widget>[];
    final header = Padding(
      padding: EdgeInsets.fromLTRB(compact ? 4 : 10, 22, 4, 8),
      child: Text(
        scope == SettingsScope.agent
            ? appStrings
                  .arg1Arg22(scope.label, controller.activeAgentLabel)
                  .toUpperCase()
            : scope.label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.geistMono(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
          color: _textMuted,
        ),
      ),
    );
    if (!compact) {
      return <Widget>[
        header,
        for (final page in pages)
          _SettingsNavItem(
            page: page,
            selected: page == selected,
            onTap: () => onOpen(page),
          ),
      ];
    }
    return <Widget>[
      header,
      _SettingsCardList(
        children: <Widget>[
          for (final page in pages)
            _SettingsListTile(
              icon: page.icon,
              title: page.label,
              onTap: () => onOpen(page),
            ),
        ],
      ),
    ];
  }
}

class _SettingsNavItem extends StatelessWidget {
  const _SettingsNavItem({
    required this.page,
    required this.selected,
    required this.onTap,
  });

  final SettingsPage page;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? _accentMuted : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: <Widget>[
                Icon(
                  page.icon,
                  size: 18,
                  color: selected ? _accent : _textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    page.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? _textPrimary : _textSecondary,
                    ),
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

class _SettingsSearchField extends StatelessWidget {
  const _SettingsSearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        hintText: appStrings.settingsSearchHint,
        prefixIcon: Icon(Icons.search, size: 18, color: _textMuted),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: appStrings.clear,
                icon: Icon(Icons.close, size: 18, color: _textMuted),
                onPressed: () {
                  controller.clear();
                  onChanged();
                },
              ),
      ),
    );
  }
}

/// One searchable setting: the page it lives on and the anchor its row
/// carries there, so a result can scroll straight to it.
class _SettingsEntry {
  const _SettingsEntry(
    this.page,
    this.anchor,
    this.label, {
    this.keywords = const <String>[],
    this.visible,
  });

  final SettingsPage page;
  final String anchor;
  final String Function() label;

  /// Extra English terms people search for, such as "byok" for API keys.
  final List<String> keywords;
  final bool Function(NeoAgentController controller)? visible;

  bool matches(String query) {
    if (label().toLowerCase().contains(query)) return true;
    return keywords.any((keyword) => keyword.contains(query));
  }
}

bool _isMobileDevice() => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

final List<_SettingsEntry> _settingsEntries = <_SettingsEntry>[
  _SettingsEntry(
    SettingsPage.profile,
    'displayName',
    () => appStrings.displayName,
    keywords: const <String>['name'],
  ),
  _SettingsEntry(SettingsPage.profile, 'email', () => appStrings.email),
  _SettingsEntry(
    SettingsPage.profile,
    'exportData',
    () => appStrings.exportMyData,
    keywords: const <String>['download', 'gdpr'],
  ),
  _SettingsEntry(
    SettingsPage.profile,
    'signOut',
    () => appStrings.signOut,
    keywords: const <String>['logout', 'log out'],
  ),
  _SettingsEntry(
    SettingsPage.profile,
    'deleteAccount',
    () => appStrings.deleteAccount,
  ),
  _SettingsEntry(
    SettingsPage.security,
    'qrLogin',
    () => appStrings.approveQrLogin,
    keywords: const <String>['scan', 'qr'],
    visible: (_) => !kIsWeb && Platform.isAndroid,
  ),
  _SettingsEntry(SettingsPage.security, 'password', () => appStrings.password),
  _SettingsEntry(
    SettingsPage.security,
    'twoFactor',
    () => appStrings.twoFactorAuthentication,
    keywords: const <String>['2fa', 'authenticator', 'recovery', 'totp'],
  ),
  _SettingsEntry(
    SettingsPage.security,
    'securityKeys',
    () => appStrings.securityKeys,
    keywords: const <String>['passkey', 'webauthn', 'yubikey'],
  ),
  _SettingsEntry(
    SettingsPage.security,
    'linkedProviders',
    () => appStrings.linkedSignInProviders,
    keywords: const <String>['google', 'github', 'oauth'],
  ),
  _SettingsEntry(
    SettingsPage.security,
    'sessions',
    () => appStrings.activeSessions,
    keywords: const <String>['devices', 'revoke'],
  ),
  _SettingsEntry(
    SettingsPage.usage,
    'limits',
    () => appStrings.usageLimits2,
    keywords: const <String>['quota', 'tokens'],
  ),
  _SettingsEntry(
    SettingsPage.usage,
    'tokenUsage',
    () => appStrings.settingsTokenUsage,
    keywords: const <String>['tokens', 'cost', 'cache', 'diagnostics'],
  ),
  _SettingsEntry(
    SettingsPage.usage,
    'billing',
    () => appStrings.billing,
    keywords: const <String>['plan', 'subscription', 'invoice', 'payment'],
    visible: (controller) => controller.showBillingSection,
  ),
  _SettingsEntry(
    SettingsPage.agents,
    'agentList',
    () => appStrings.settingsYourAgents,
    keywords: const <String>['bot', 'delegate', 'default agent'],
  ),
  _SettingsEntry(
    SettingsPage.permissions,
    'toolPermissions',
    () => appStrings.toolPermissions,
    keywords: const <String>['approval', 'shell', 'allow', 'block', 'policy'],
  ),
  _SettingsEntry(
    SettingsPage.computer,
    'computerRuntime',
    () => appStrings.computerWorkspace,
    keywords: const <String>['vm', 'browser', 'desktop'],
  ),
  _SettingsEntry(
    SettingsPage.computer,
    'shell',
    () => appStrings.computerShell,
    keywords: const <String>['terminal', 'cli'],
  ),
  _SettingsEntry(
    SettingsPage.computer,
    'socialReach',
    () => appStrings.socialReach2,
    keywords: const <String>[
      'cookies',
      'youtube',
      'reddit',
      'twitter',
      'linkedin',
      'github',
    ],
  ),
  _SettingsEntry(
    SettingsPage.models,
    'chatModel',
    () => appStrings.settingsChatModel,
    keywords: const <String>['default model', 'llm'],
  ),
  _SettingsEntry(
    SettingsPage.models,
    'taskModel_coding',
    () => appStrings.settingsAdvancedModels,
    keywords: const <String>['coding', 'research', 'android', 'computer use'],
  ),
  _SettingsEntry(
    SettingsPage.models,
    'systemOne',
    () => appStrings.systemOneModels,
    keywords: const <String>['systemone', 'fast model'],
  ),
  _SettingsEntry(
    SettingsPage.models,
    'smartSelection',
    () => appStrings.smartModelSelection,
    keywords: const <String>['routing', 'auto'],
  ),
  _SettingsEntry(
    SettingsPage.models,
    'modelPool',
    () => appStrings.settingsModelPool,
    keywords: const <String>['routing'],
  ),
  _SettingsEntry(
    SettingsPage.models,
    'apiKeys',
    () => appStrings.bringYourOwnKey2,
    keywords: const <String>[
      'byok',
      'api key',
      'openai',
      'anthropic',
      'ollama',
      'endpoint',
    ],
  ),
  _SettingsEntry(
    SettingsPage.behavior,
    'persona',
    () => appStrings.personaBehaviorNotes,
    keywords: const <String>['instructions', 'tone'],
  ),
  _SettingsEntry(
    SettingsPage.behavior,
    'socialBehavior',
    () => appStrings.enableBehaviorModules,
    keywords: const <String>['social', 'groups'],
  ),
  _SettingsEntry(
    SettingsPage.behavior,
    'socialMemory',
    () => appStrings.channelScopedSocialMemory,
  ),
  _SettingsEntry(
    SettingsPage.behavior,
    'roomNorms',
    () => appStrings.learnRoomNorms,
  ),
  _SettingsEntry(
    SettingsPage.behavior,
    'observability',
    () => appStrings.socialObservability,
  ),
  _SettingsEntry(
    SettingsPage.behavior,
    'turnTaking',
    () => appStrings.turnTakingModel,
  ),
  _SettingsEntry(
    SettingsPage.behavior,
    'minimumNeed',
    () => appStrings.settingsMinimumContribution,
  ),
  _SettingsEntry(
    SettingsPage.behavior,
    'batchWindow',
    () => appStrings.settingsBatchWindow,
  ),
  _SettingsEntry(
    SettingsPage.voice,
    'inputMode',
    () => appStrings.inputMode,
    keywords: const <String>['push to talk', 'hands-free', 'ptt'],
  ),
  _SettingsEntry(
    SettingsPage.voice,
    'liveProvider',
    () => appStrings.liveModelProvider,
  ),
  _SettingsEntry(SettingsPage.voice, 'liveModel', () => appStrings.liveModel),
  _SettingsEntry(
    SettingsPage.voice,
    'liveVoice',
    () => appStrings.settingsLiveVoice,
  ),
  _SettingsEntry(
    SettingsPage.voice,
    'speechToText',
    () => appStrings.speechToText,
    keywords: const <String>['stt', 'transcription', 'dictation'],
  ),
  _SettingsEntry(
    SettingsPage.voice,
    'voiceReplyModel',
    () => appStrings.voiceReplyModel,
    keywords: const <String>['tts'],
  ),
  _SettingsEntry(
    SettingsPage.messaging,
    'participation',
    () => appStrings.defaultGroupParticipation,
    keywords: const <String>['groups', 'mention'],
  ),
  _SettingsEntry(
    SettingsPage.messaging,
    'delivery',
    () => appStrings.messagingDelivery,
    keywords: const <String>['bubbles'],
  ),
  _SettingsEntry(
    SettingsPage.messaging,
    'channels',
    () => appStrings.settingsChannels,
    keywords: const <String>[
      'whatsapp',
      'telegram',
      'discord',
      'signal',
      'slack',
      'meshtastic',
      'webhook',
    ],
  ),
  _SettingsEntry(
    SettingsPage.general,
    'theme',
    () => appStrings.settingsTheme,
    keywords: const <String>['dark', 'light', 'appearance'],
  ),
  _SettingsEntry(
    SettingsPage.general,
    'language',
    () => appStrings.accountLanguageTitle,
    keywords: const <String>['deutsch', 'english'],
  ),
  _SettingsEntry(
    SettingsPage.general,
    'timeZone',
    () => appStrings.timeZone2,
    keywords: const <String>['timezone', 'clock'],
  ),
  _SettingsEntry(
    SettingsPage.general,
    'closeWindow',
    () => appStrings.settingsCloseWindow,
    keywords: const <String>['tray', 'background'],
    visible: (_) => _supportsDesktopShell,
  ),
  _SettingsEntry(
    SettingsPage.general,
    'hotkey',
    () => appStrings.reserveAssistantHotkey,
    keywords: const <String>['shortcut'],
    visible: (_) => _supportsDesktopShell,
  ),
  _SettingsEntry(
    SettingsPage.general,
    'locationTriggers',
    () => appStrings.settingsLocationTriggers,
    keywords: const <String>['geofence', 'gps'],
    visible: (_) => _isMobileDevice(),
  ),
  _SettingsEntry(
    SettingsPage.general,
    'notificationTriggers',
    () => appStrings.settingsNotificationTriggers,
    visible: (_) => !kIsWeb && Platform.isAndroid,
  ),
  _SettingsEntry(
    SettingsPage.general,
    'onboarding',
    () => appStrings.redoOnboarding,
    keywords: const <String>['setup'],
  ),
  _SettingsEntry(
    SettingsPage.system,
    'server',
    () => appStrings.server,
    keywords: const <String>['update', 'channel', 'beta', 'install', 'logs'],
  ),
];

/// Pages and settings matching a search, each opening its page, with the
/// setting itself scrolled into view.
class _SettingsSearchResults extends StatelessWidget {
  const _SettingsSearchResults({
    required this.controller,
    required this.query,
    required this.onOpen,
  });

  final NeoAgentController controller;
  final String query;
  final void Function(SettingsPage page, {String? anchor}) onOpen;

  @override
  Widget build(BuildContext context) {
    final needle = query.toLowerCase();
    final pages = _visibleSettingsPages();
    final pageHits = pages
        .where((page) => page.label.toLowerCase().contains(needle))
        .toList();
    final entryHits = _settingsEntries
        .where(
          (entry) =>
              pages.contains(entry.page) &&
              (entry.visible?.call(controller) ?? true) &&
              entry.matches(needle),
        )
        .toList();
    final total = pageHits.length + entryHits.length;
    if (total == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          appStrings.settingsSearchNoMatch(query),
          style: TextStyle(color: _textSecondary, height: 1.45),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            appStrings.settingsSearchResultCount(total),
            style: TextStyle(color: _textSecondary, fontSize: 13),
          ),
        ),
        _SettingsCardList(
          children: <Widget>[
            for (final page in pageHits)
              _SettingsListTile(
                icon: page.icon,
                title: page.label,
                subtitle: page.scope.label,
                onTap: () => onOpen(page),
              ),
            for (final entry in entryHits)
              _SettingsListTile(
                icon: entry.page.icon,
                title: entry.label(),
                subtitle: appStrings.arg1Arg22(
                  entry.page.scope.label,
                  entry.page.label,
                ),
                onTap: () => onOpen(entry.page, anchor: entry.anchor),
              ),
          ],
        ),
      ],
    );
  }
}

/// A page: its header, then its groups of settings.
class _SettingsPageView extends StatelessWidget {
  const _SettingsPageView({
    super.key,
    required this.controller,
    required this.page,
    required this.highlight,
    this.onBack,
  });

  final NeoAgentController controller;
  final SettingsPage page;
  final _SettingsHighlight? highlight;

  /// Set on a phone, where the page covers the list.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: _SettingsHighlightScope(
              highlight: highlight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (onBack != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: onBack,
                        icon: Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                        label: Text(appStrings.settings),
                      ),
                    ),
                  _SettingsPageHeader(controller: controller, page: page),
                  const SizedBox(height: 26),
                  if (controller.errorMessage != null) ...<Widget>[
                    _InlineError(
                      message: controller.errorMessage!,
                      onDismiss: controller.clearInlineError,
                    ),
                    const SizedBox(height: 18),
                  ],
                  _settingsPageBody(controller, page),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Widget _settingsPageBody(NeoAgentController controller, SettingsPage page) {
  switch (page) {
    case SettingsPage.profile:
    case SettingsPage.security:
    case SettingsPage.usage:
      return AccountSettingsPanel(controller: controller, page: page);
    case SettingsPage.agents:
      return AgentsPanel(controller: controller);
    case SettingsPage.permissions:
      return MainSecurity(controller: controller);
    case SettingsPage.computer:
      return _ComputerSettingsPage(controller: controller);
    case SettingsPage.models:
      return _ModelsSettingsPage(controller: controller);
    case SettingsPage.behavior:
      return _BehaviorSettingsPage(controller: controller);
    case SettingsPage.voice:
      return _VoiceSettingsPage(controller: controller);
    case SettingsPage.messaging:
      return MessagingPanel(controller: controller);
    case SettingsPage.general:
      return _GeneralSettingsPage(controller: controller);
    case SettingsPage.system:
      return ServerPanel(controller: controller, embedded: true);
  }
}

/// Scope, title and description of a page, plus who it applies to and
/// whether changes are still being saved.
class _SettingsPageHeader extends StatelessWidget {
  const _SettingsPageHeader({required this.controller, required this.page});

  final NeoAgentController controller;
  final SettingsPage page;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(page.scope.label.toUpperCase(), style: _sectionEyebrowStyle()),
        const SizedBox(height: 8),
        Text(page.label, style: _displayTitleStyle(compact ? 24 : 30)),
        const SizedBox(height: 8),
        Text(
          page.description,
          style: TextStyle(color: _textSecondary, height: 1.5),
        ),
      ],
    );
    final scope = _scopeIndicator();
    final status = _SettingsSaveStatus(controller: controller);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              heading,
              const SizedBox(height: 14),
              Wrap(
                spacing: 14,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[if (scope != null) scope, status],
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(child: heading),
            const SizedBox(width: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                if (scope != null) ...<Widget>[
                  scope,
                  const SizedBox(height: 10),
                ],
                status,
              ],
            ),
          ],
        );
      },
    );
  }

  Widget? _scopeIndicator() {
    switch (page.scope) {
      case SettingsScope.agent:
        if (controller.agentProfiles.isEmpty) return null;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              appStrings.settingsAppliesTo,
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
            const SizedBox(width: 8),
            _AgentSwitcher(controller: controller, compact: true),
          ],
        );
      case SettingsScope.account:
        return _SettingsScopePill(
          icon: Icons.cloud_outlined,
          label: appStrings.settingsScopeAccountHint,
        );
      case SettingsScope.allAgents:
        return _SettingsScopePill(
          icon: Icons.groups_2_outlined,
          label: appStrings.settingsScopeAllAgentsHint,
        );
      case SettingsScope.app:
        return null;
    }
  }
}

class _SettingsScopePill extends StatelessWidget {
  const _SettingsScopePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _bgTertiary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: _textSecondary),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: _textSecondary, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Settings save as they change; this says so, and shows when a save is
/// still in flight.
class _SettingsSaveStatus extends StatelessWidget {
  const _SettingsSaveStatus({required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    final saving =
        controller.isSavingSettings || controller.isSavingAccountSettings;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (saving)
          SizedBox.square(
            dimension: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: _textMuted,
            ),
          )
        else
          Icon(Icons.check_rounded, size: 15, color: _success),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            saving
                ? appStrings.settingsSaving
                : appStrings.settingsSavedAutomatically,
            style: TextStyle(color: _textMuted, fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}

/// Saves [payload] at once. The controller shows the new value immediately,
/// rolls it back if the save fails and reports the failure inline, so callers
/// have nothing left to handle.
void _autosaveSettings(
  NeoAgentController controller,
  Map<String, dynamic> payload,
) {
  unawaited(controller.saveSettingsPayload(payload).catchError((Object _) {}));
}

/// A titled block of settings: a heading and optional help line, then its
/// rows on one surface, separated by hairlines.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.children,
    this.description,
    this.trailing,
    this.anchor,
  });

  final String title;
  final String? description;
  final Widget? trailing;
  final List<Widget> children;

  /// Search target for groups that are a single setting, like a form.
  final String? anchor;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SettingsHeading(
            title: title,
            description: description,
            trailing: trailing,
          ),
          if (children.isNotEmpty) _SettingsCardList(children: children),
        ],
      ),
    );
    return anchor == null ? body : _SettingsAnchor(id: anchor!, child: body);
  }
}

/// The heading over a group of settings, also used over content that brings
/// its own layout, like the messaging channel grid.
class _SettingsHeading extends StatelessWidget {
  const _SettingsHeading({
    super.key,
    required this.title,
    this.description,
    this.trailing,
  });

  final String title;
  final String? description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                if (description != null) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    description!,
                    style: TextStyle(
                      fontSize: 13,
                      color: _textSecondary,
                      height: 1.45,
                    ),
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
    );
  }
}

/// Rows on a single card, split by hairlines.
class _SettingsCardList extends StatelessWidget {
  const _SettingsCardList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) Divider(height: 1, thickness: 1, color: _border),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One setting: label and help on the left, its control on the right. On a
/// narrow screen the control moves under the label.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.label,
    this.description,
    this.control,
    this.fillControl = false,
    this.tag,
    this.anchor,
    this.enabled = true,
  });

  final String label;
  final String? description;
  final Widget? control;

  /// Gives the control a fixed width beside the label and the full width
  /// under it. Pickers and text fields need this; switches and buttons size
  /// themselves.
  final bool fillControl;

  /// Short qualifier next to the label, such as "This device".
  final String? tag;
  final String? anchor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
            if (tag != null) _SettingsTag(label: tag!),
          ],
        ),
        if (description != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            description!,
            style: TextStyle(fontSize: 13, color: _textSecondary, height: 1.45),
          ),
        ],
      ],
    );
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final control = this.control;
          if (control == null) return text;
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                text,
                const SizedBox(height: 12),
                if (fillControl)
                  control
                else
                  Align(alignment: Alignment.centerLeft, child: control),
              ],
            );
          }
          return Row(
            children: <Widget>[
              Expanded(child: text),
              const SizedBox(width: 24),
              if (fillControl)
                SizedBox(width: 300, child: control)
              else
                control,
            ],
          );
        },
      ),
    );
    final body = enabled
        ? row
        : IgnorePointer(child: Opacity(opacity: 0.5, child: row));
    return anchor == null ? body : _SettingsAnchor(id: anchor!, child: body);
  }
}

/// Free-form content inside a group, for forms and lists.
class _SettingsBlock extends StatelessWidget {
  const _SettingsBlock({required this.child, this.anchor});

  final Widget child;
  final String? anchor;

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: const EdgeInsets.all(20), child: child);
    return anchor == null ? body : _SettingsAnchor(id: anchor!, child: body);
  }
}

class _SettingsTag extends StatelessWidget {
  const _SettingsTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _bgTertiary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _border),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.geistMono(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: _textSecondary,
        ),
      ),
    );
  }
}

/// A row that opens something, used for the page list on a phone and for
/// search results.
class _SettingsListTile extends StatelessWidget {
  const _SettingsListTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _bgTertiary,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 17, color: _textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: GoogleFonts.geistMono(
                        fontSize: 11.5,
                        color: _textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: _textMuted),
          ],
        ),
      ),
    );
  }
}

/// A one-of-a-few choice. Beside a label it keeps its natural width; under a
/// label on a phone it fills the row.
class _SettingsChoice<T extends Object> extends StatelessWidget {
  const _SettingsChoice({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return SegmentedButton<T>(
      segments: <ButtonSegment<T>>[
        for (final (option, label) in options)
          ButtonSegment<T>(value: option, label: Text(label)),
      ],
      selected: <T>{value},
      showSelectedIcon: false,
      onSelectionChanged: onChanged == null
          ? null
          : (selection) => onChanged(selection.first),
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        selectedBackgroundColor: _accentMuted,
        selectedForegroundColor: _textPrimary,
        foregroundColor: _textSecondary,
        side: BorderSide(color: _borderLight),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// A text setting that saves itself: shortly after typing stops, when the
/// field loses focus, on submit, and when the page closes with an edit still
/// pending.
class _AutosaveTextField extends StatefulWidget {
  const _AutosaveTextField({
    required this.value,
    required this.onSave,
    this.minLines = 1,
    this.maxLines = 1,
    this.maxLength,
  });

  final String value;
  final ValueChanged<String> onSave;
  final int minLines;
  final int maxLines;
  final int? maxLength;

  @override
  State<_AutosaveTextField> createState() => _AutosaveTextFieldState();
}

class _AutosaveTextFieldState extends State<_AutosaveTextField> {
  late final TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  late String _saved;

  @override
  void initState() {
    super.initState();
    _saved = widget.value;
    _textController = TextEditingController(text: widget.value);
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _AutosaveTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A value that changed elsewhere replaces the text, unless it is being
    // edited here.
    if (widget.value != oldWidget.value &&
        !_focusNode.hasFocus &&
        _textController.text == _saved) {
      _saved = widget.value;
      _textController.text = widget.value;
    }
  }

  @override
  void dispose() {
    _save(deferred: true);
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _textController.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (!_focusNode.hasFocus) _save();
  }

  /// [deferred] is for dispose, which runs while the tree is locked: the
  /// save, and the rebuild it causes, waits until the frame is done.
  void _save({bool deferred = false}) {
    _debounce?.cancel();
    final text = _textController.text;
    if (text == _saved) return;
    if (widget.maxLength != null && text.length > widget.maxLength!) return;
    _saved = text;
    final onSave = widget.onSave;
    if (deferred) {
      scheduleMicrotask(() => onSave(text));
    } else {
      onSave(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _textController,
      focusNode: _focusNode,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      textInputAction: widget.maxLines == 1
          ? TextInputAction.done
          : TextInputAction.newline,
      onSubmitted: (_) => _save(),
      onChanged: (_) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 1200), _save);
      },
      decoration: const InputDecoration(isDense: true),
    );
  }
}

/// Which setting a search result pointed at. A new instance per search tap,
/// so opening the same result twice flashes it twice.
class _SettingsHighlight {
  _SettingsHighlight(this.anchor);

  final String anchor;
}

class _SettingsHighlightScope extends InheritedWidget {
  const _SettingsHighlightScope({
    required this.highlight,
    required super.child,
  });

  final _SettingsHighlight? highlight;

  static _SettingsHighlight? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_SettingsHighlightScope>()
      ?.highlight;

  @override
  bool updateShouldNotify(_SettingsHighlightScope oldWidget) =>
      !identical(oldWidget.highlight, highlight);
}

/// Marks a setting a search can point at. When it is the target, it scrolls
/// into view and flashes briefly.
class _SettingsAnchor extends StatefulWidget {
  const _SettingsAnchor({required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  State<_SettingsAnchor> createState() => _SettingsAnchorState();
}

class _SettingsAnchorState extends State<_SettingsAnchor> {
  _SettingsHighlight? _handled;
  bool _lit = false;
  Timer? _fade;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final highlight = _SettingsHighlightScope.of(context);
    if (highlight == null ||
        highlight.anchor != widget.id ||
        identical(highlight, _handled)) {
      return;
    }
    _handled = highlight;
    _lit = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.15,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
    _fade?.cancel();
    _fade = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _lit = false);
    });
  }

  @override
  void dispose() {
    _fade?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: _lit ? _accentMuted : _accentMuted.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: widget.child,
    );
  }
}
