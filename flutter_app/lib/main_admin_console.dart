part of 'main.dart';

enum _AdminTab {
  users,
  server,
  providers,
  models,
  integrations,
  config,
  billing,
  analytics,
  sql,
}

extension on _AdminTab {
  String get label {
    switch (this) {
      case _AdminTab.users:
        return 'Users';
      case _AdminTab.server:
        return appStrings.server;
      case _AdminTab.providers:
        return appStrings.providers;
      case _AdminTab.models:
        return appStrings.models;
      case _AdminTab.integrations:
        return appStrings.integrations;
      case _AdminTab.config:
        return 'Configuration';
      case _AdminTab.billing:
        return appStrings.billing;
      case _AdminTab.analytics:
        return 'Analytics';
      case _AdminTab.sql:
        return 'SQL';
    }
  }

  IconData get icon {
    switch (this) {
      case _AdminTab.users:
        return Icons.group_outlined;
      case _AdminTab.server:
        return Icons.dns_outlined;
      case _AdminTab.providers:
        return Icons.key_outlined;
      case _AdminTab.models:
        return Icons.view_list_outlined;
      case _AdminTab.integrations:
        return Icons.extension_outlined;
      case _AdminTab.config:
        return Icons.tune;
      case _AdminTab.billing:
        return Icons.credit_card;
      case _AdminTab.analytics:
        return Icons.insights_outlined;
      case _AdminTab.sql:
        return Icons.storage_outlined;
    }
  }
}

/// One thing an admin might look for, the tab that has it, and the card on
/// that tab to scroll to.
class _AdminSearchEntry {
  const _AdminSearchEntry(this.title, this.tab, this.keywords, {this.card});

  final String title;
  final _AdminTab tab;

  /// Title of the card holding it; null lands at the top of the tab.
  final String? card;

  /// Lower-case words people are likely to type, beyond the title itself.
  final String keywords;

  bool matches(String query) {
    final haystack =
        appStrings.arg1Arg2Arg37(title.toLowerCase(), keywords, tab.label.toLowerCase());
    return query
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .every(haystack.contains);
  }
}

List<_AdminSearchEntry> _adminSearchIndex = <_AdminSearchEntry>[
  _AdminSearchEntry(
    'Accounts',
    _AdminTab.users,
    appStrings.usersPeopleSearchEmailUsernameAdmin,
    card: 'Accounts',
  ),
  _AdminSearchEntry(
    appStrings.deleteAnAccount,
    _AdminTab.users,
    appStrings.removeEraseGdprUser,
    card: 'Accounts',
  ),
  _AdminSearchEntry(
    appStrings.signOutEverywhere,
    _AdminTab.users,
    appStrings.sessionsLogoutRevokeForce,
    card: 'Accounts',
  ),
  _AdminSearchEntry(
    appStrings.perAccountRateLimits,
    _AdminTab.users,
    appStrings.tokenBudgetLimit4HourWeekly,
    card: 'Accounts',
  ),
  _AdminSearchEntry(
    appStrings.defaultRateLimits,
    _AdminTab.users,
    appStrings.tokenBudgetLimit4HourWeekly2,
    card: appStrings.defaultRateLimits,
  ),
  _AdminSearchEntry(
    appStrings.assignAPlanToAnAccount,
    _AdminTab.users,
    appStrings.subscriptionBillingOverrideComp,
    card: 'Accounts',
  ),
  _AdminSearchEntry(
    appStrings.accessActivity,
    _AdminTab.users,
    appStrings.auditLogAdminGrantRevokeInvite,
    card: appStrings.accessActivity,
  ),
  _AdminSearchEntry(
    appStrings.versionAndUptime,
    _AdminTab.server,
    appStrings.releaseCommitBranchNode,
    card: 'Server',
  ),
  _AdminSearchEntry(
    appStrings.updateTheServer2,
    _AdminTab.server,
    appStrings.upgradeUpdateNowReleaseChannelStable,
    card: 'Updates',
  ),
  _AdminSearchEntry(
    appStrings.healthChecks,
    _AdminTab.server,
    appStrings.statusDatabaseRuntimeVmProviders,
    card: appStrings.healthChecks,
  ),
  _AdminSearchEntry(
    'Issues',
    _AdminTab.server,
    appStrings.errorsProblemsFailures,
    card: 'Issues',
  ),
  _AdminSearchEntry(
    'Logs',
    _AdminTab.server,
    appStrings.serverOutputConsoleWarningsErrorsCopy,
    card: 'Logs',
  ),
  _AdminSearchEntry(
    'Environment',
    _AdminTab.server,
    appStrings.portNodeEnvPublicUrlTrust,
    card: 'Environment',
  ),
  _AdminSearchEntry(
    appStrings.aiProviderKeys,
    _AdminTab.providers,
    appStrings.apiKeyAnthropicClaudeOpenaiGpt,
    card: appStrings.serverProviderCredentials,
  ),
  _AdminSearchEntry(
    appStrings.customOpenaiCompatibleEndpoint,
    _AdminTab.providers,
    appStrings.baseUrlTokenLocal,
    card: appStrings.serverProviderCredentials,
  ),
  _AdminSearchEntry(
    'Ollama',
    _AdminTab.providers,
    appStrings.localModelsUrl,
    card: appStrings.serverProviderCredentials,
  ),
  _AdminSearchEntry(
    appStrings.braveSearch,
    _AdminTab.providers,
    appStrings.webSearchApiKey,
    card: appStrings.serverProviderCredentials,
  ),
  _AdminSearchEntry(
    appStrings.deepgramKey,
    _AdminTab.providers,
    appStrings.voiceNoteSpeechTranscriptionApiKey,
    card: appStrings.serverProviderCredentials,
  ),
  _AdminSearchEntry(
    appStrings.githubCopilotAndOpenaiCodex,
    _AdminTab.providers,
    appStrings.accessToken,
    card: appStrings.serverProviderCredentials,
  ),
  _AdminSearchEntry(
    appStrings.jevDecisions,
    _AdminTab.models,
    appStrings.jevTypesafeDecisionModelOpenrouterRouting,
    card: appStrings.jevDecisions,
  ),
  _AdminSearchEntry(
    appStrings.enableOrDisableModels,
    _AdminTab.models,
    appStrings.modelVisibilityHideShowList,
    card: appStrings.modelAvailability,
  ),
  _AdminSearchEntry(
    appStrings.googleWorkspace,
    _AdminTab.integrations,
    appStrings.oauthClientIdSecretRedirectGmail,
    card: appStrings.googleWorkspace,
  ),
  _AdminSearchEntry(
    appStrings.microsoft365,
    _AdminTab.integrations,
    appStrings.oauthOutlookTenantClientIdSecret,
    card: appStrings.microsoft365,
  ),
  _AdminSearchEntry(
    appStrings.notionSlackFigmaGithubSpotifyTrello,
    _AdminTab.integrations,
    appStrings.oauthClientIdSecretRedirectApi,
    card: appStrings.integrationApps,
  ),
  _AdminSearchEntry(
    appStrings.liveVoiceDefaults,
    _AdminTab.integrations,
    appStrings.voiceCallGptLiveGeminiLive,
    card: appStrings.liveVoice,
  ),
  _AdminSearchEntry(
    'Sign-ups',
    _AdminTab.config,
    appStrings.registrationRegisterNewAccountsAllowSignup,
    card: 'Access',
  ),
  _AdminSearchEntry(
    appStrings.publicUrlAndAllowedOrigins,
    _AdminTab.config,
    appStrings.corsDomainHttpsPublicUrlOrigins,
    card: 'General',
  ),
  _AdminSearchEntry(
    appStrings.secureCookies,
    _AdminTab.config,
    appStrings.httpsSessionCookie,
    card: 'General',
  ),
  _AdminSearchEntry(
    'Meshtastic',
    _AdminTab.config,
    appStrings.meshRadioMessaging,
    card: 'General',
  ),
  _AdminSearchEntry(
    appStrings.memoryIngestionInterval,
    _AdminTab.config,
    appStrings.memoryImportSync,
    card: 'General',
  ),
  _AdminSearchEntry(
    appStrings.cloudComputerVm,
    _AdminTab.config,
    appStrings.vmImageMemoryCpuQemuRuntime,
    card: appStrings.cloudComputers,
  ),
  _AdminSearchEntry(
    appStrings.serviceEmailSmtp,
    _AdminTab.config,
    appStrings.smtpMailSenderPasswordTlsConfirmation,
    card: appStrings.serviceEmail,
  ),
  _AdminSearchEntry(
    appStrings.stripeSetup,
    _AdminTab.billing,
    appStrings.billingStripeKeysWebhookSecretTrial,
    card: appStrings.stripeBilling,
  ),
  _AdminSearchEntry(
    'Plans',
    _AdminTab.billing,
    appStrings.pricingPriceSubscriptionTiersCreateEdit,
    card: 'Plans',
  ),
  _AdminSearchEntry(
    'Subscriptions',
    _AdminTab.billing,
    appStrings.customersOverridePlanStatusCanceledTrialing,
    card: 'Subscriptions',
  ),
  _AdminSearchEntry(
    appStrings.usageAnalytics,
    _AdminTab.analytics,
    appStrings.statsRunsTokensUsersChartsSuccess,
  ),
  _AdminSearchEntry(
    appStrings.topUsersAndRecentRuns,
    _AdminTab.analytics,
    appStrings.usageLeaderboard,
    card: appStrings.topUsers,
  ),
  _AdminSearchEntry(
    appStrings.sqlConsole,
    _AdminTab.sql,
    appStrings.databaseQuerySelectCsvTemplates,
    card: appStrings.sqlConsole,
  ),
];

/// The in-app admin page. Only reachable for admin accounts; every endpoint
/// behind it re-checks the admin flag on the server.
class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final TextEditingController _search = TextEditingController();
  _AdminTab _tab = _AdminTab.users;

  /// Card to bring into view after opening a search result.
  String? _targetCard;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(_AdminTab tab, {String? card}) {
    setState(() {
      _tab = tab;
      _targetCard = card;
      _search.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final results = query.isEmpty
        ? const <_AdminSearchEntry>[]
        : _adminSearchIndex
              .where((entry) => entry.matches(query))
              .toList(growable: false);
    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Admin',
          subtitle:
              appStrings.runThisServerAccountsUpdatesProviders +
              appStrings.andBillingTeamLinksLiveOn,
        ),
        _SearchField(
          controller: _search,
          hintText: appStrings.searchAdminSettingsEGStripe,
          onChanged: (_) => setState(() {}),
          onClear: () => setState(_search.clear),
          onSubmitted: (_) {
            if (results.isNotEmpty) {
              _open(results.first.tab, card: results.first.card);
            }
          },
        ),
        const SizedBox(height: 14),
        if (query.isNotEmpty)
          _AdminSearchResults(
            results: results,
            onOpen: (entry) => _open(entry.tab, card: entry.card),
          )
        else ...<Widget>[
          _AdminTabBar(selected: _tab, onSelect: _open),
          const SizedBox(height: 20),
          _SectionFocus(
            title: _targetCard,
            child: KeyedSubtree(
              key: ValueKey<(_AdminTab, String?)>((_tab, _targetCard)),
              child: _body(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _body() {
    final controller = widget.controller;
    switch (_tab) {
      case _AdminTab.users:
        return _SectionStack(
          children: <Widget>[
            _AdminUsersTab(controller: controller),
            _AccessActivityCard(controller: controller),
          ],
        );
      case _AdminTab.server:
        return _AdminServerTab(controller: controller);
      case _AdminTab.providers:
        return _AdminProvidersTab(controller: controller);
      case _AdminTab.models:
        return _AdminModelsTab(controller: controller);
      case _AdminTab.integrations:
        return _AdminIntegrationsTab(controller: controller);
      case _AdminTab.config:
        return _AdminConfigTab(controller: controller);
      case _AdminTab.billing:
        return _AdminBillingTab(controller: controller);
      case _AdminTab.analytics:
        return _AdminAnalyticsTab(controller: controller);
      case _AdminTab.sql:
        return _AdminSqlTab(controller: controller);
    }
  }
}

class _AdminSearchResults extends StatelessWidget {
  const _AdminSearchResults({required this.results, required this.onOpen});

  final List<_AdminSearchEntry> results;
  final ValueChanged<_AdminSearchEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return _EmptyCard(
        title: appStrings.nothingMatches,
        subtitle: appStrings.tryAProviderNameEmailLimits,
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: results
            .map(
              (entry) => ListTile(
                leading: Icon(entry.tab.icon, color: _accent),
                title: Text(entry.title),
                subtitle: Text(appStrings.adminArg1(entry.tab.label)),
                trailing: Icon(Icons.chevron_right),
                onTap: () => onOpen(entry),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _AdminTabBar extends StatelessWidget {
  const _AdminTabBar({required this.selected, required this.onSelect});

  final _AdminTab selected;
  final ValueChanged<_AdminTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _AdminTab.values
          .map(
            (tab) => _AdminTabChip(
              tab: tab,
              active: tab == selected,
              onTap: () => onSelect(tab),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _AdminTabChip extends StatelessWidget {
  const _AdminTabChip({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  final _AdminTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: radius,
            color: active ? _accentMuted : _bgTertiary,
            border: Border.all(
              color: active ? _accent.withValues(alpha: 0.3) : _border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(tab.icon, size: 15, color: active ? _accent : _textMuted),
              const SizedBox(width: 7),
              Text(
                tab.label,
                style: GoogleFonts.geist(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: active ? _accentHover : _textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
