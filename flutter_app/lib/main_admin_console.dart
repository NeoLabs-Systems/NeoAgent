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
        return 'Server';
      case _AdminTab.providers:
        return 'Providers';
      case _AdminTab.models:
        return 'Models';
      case _AdminTab.integrations:
        return 'Integrations';
      case _AdminTab.config:
        return 'Configuration';
      case _AdminTab.billing:
        return 'Billing';
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
        '${title.toLowerCase()} $keywords ${tab.label.toLowerCase()}';
    return query
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .every(haystack.contains);
  }
}

const List<_AdminSearchEntry> _adminSearchIndex = <_AdminSearchEntry>[
  _AdminSearchEntry(
    'Accounts',
    _AdminTab.users,
    'users people search email username admin badge managed team',
    card: 'Accounts',
  ),
  _AdminSearchEntry(
    'Delete an account',
    _AdminTab.users,
    'remove erase gdpr user',
    card: 'Accounts',
  ),
  _AdminSearchEntry(
    'Sign out everywhere',
    _AdminTab.users,
    'sessions logout revoke force',
    card: 'Accounts',
  ),
  _AdminSearchEntry(
    'Per-account rate limits',
    _AdminTab.users,
    'token budget limit 4 hour weekly quota user',
    card: 'Accounts',
  ),
  _AdminSearchEntry(
    'Default rate limits',
    _AdminTab.users,
    'token budget limit 4 hour weekly quota global',
    card: 'Default rate limits',
  ),
  _AdminSearchEntry(
    'Assign a plan to an account',
    _AdminTab.users,
    'subscription billing override comp',
    card: 'Accounts',
  ),
  _AdminSearchEntry(
    'Access activity',
    _AdminTab.users,
    'audit log admin grant revoke invite team history',
    card: 'Access activity',
  ),
  _AdminSearchEntry(
    'Version and uptime',
    _AdminTab.server,
    'release commit branch node',
    card: 'Server',
  ),
  _AdminSearchEntry(
    'Update the server',
    _AdminTab.server,
    'upgrade update now release channel stable beta',
    card: 'Updates',
  ),
  _AdminSearchEntry(
    'Health checks',
    _AdminTab.server,
    'status database runtime vm providers',
    card: 'Health checks',
  ),
  _AdminSearchEntry(
    'Issues',
    _AdminTab.server,
    'errors problems failures',
    card: 'Issues',
  ),
  _AdminSearchEntry(
    'Logs',
    _AdminTab.server,
    'server output console warnings errors copy',
    card: 'Logs',
  ),
  _AdminSearchEntry(
    'Environment',
    _AdminTab.server,
    'port node_env public url trust proxy secure cookies deployment',
    card: 'Environment',
  ),
  _AdminSearchEntry(
    'AI provider keys',
    _AdminTab.providers,
    'api key anthropic claude openai gpt xai grok google gemini minimax nvidia nim openrouter credentials',
    card: 'Server provider credentials',
  ),
  _AdminSearchEntry(
    'Custom OpenAI-compatible endpoint',
    _AdminTab.providers,
    'base url token local',
    card: 'Server provider credentials',
  ),
  _AdminSearchEntry(
    'Ollama',
    _AdminTab.providers,
    'local models url',
    card: 'Server provider credentials',
  ),
  _AdminSearchEntry(
    'Brave Search',
    _AdminTab.providers,
    'web search api key',
    card: 'Server provider credentials',
  ),
  _AdminSearchEntry(
    'Deepgram key',
    _AdminTab.providers,
    'voice note speech transcription api key',
    card: 'Server provider credentials',
  ),
  _AdminSearchEntry(
    'GitHub Copilot and OpenAI Codex',
    _AdminTab.providers,
    'access token',
    card: 'Server provider credentials',
  ),
  _AdminSearchEntry(
    'Jev decisions',
    _AdminTab.models,
    'jev typesafe decision model openrouter routing fast cheaper recommended',
    card: 'Jev decisions',
  ),
  _AdminSearchEntry(
    'Enable or disable models',
    _AdminTab.models,
    'model visibility hide show list',
    card: 'Model availability',
  ),
  _AdminSearchEntry(
    'Google Workspace',
    _AdminTab.integrations,
    'oauth client id secret redirect gmail calendar drive',
    card: 'Google Workspace',
  ),
  _AdminSearchEntry(
    'Microsoft 365',
    _AdminTab.integrations,
    'oauth outlook tenant client id secret',
    card: 'Microsoft 365',
  ),
  _AdminSearchEntry(
    'Notion, Slack, Figma, GitHub, Spotify, Trello',
    _AdminTab.integrations,
    'oauth client id secret redirect api key',
    card: 'Integration apps',
  ),
  _AdminSearchEntry(
    'Live voice defaults',
    _AdminTab.integrations,
    'voice call gpt-live gemini live model speech realtime',
    card: 'Live voice',
  ),
  _AdminSearchEntry(
    'Sign-ups',
    _AdminTab.config,
    'registration register new accounts allow signup',
    card: 'Access',
  ),
  _AdminSearchEntry(
    'Public URL and allowed origins',
    _AdminTab.config,
    'cors domain https public url origins',
    card: 'General',
  ),
  _AdminSearchEntry(
    'Secure cookies',
    _AdminTab.config,
    'https session cookie',
    card: 'General',
  ),
  _AdminSearchEntry(
    'Meshtastic',
    _AdminTab.config,
    'mesh radio messaging',
    card: 'General',
  ),
  _AdminSearchEntry(
    'Memory ingestion interval',
    _AdminTab.config,
    'memory import sync',
    card: 'General',
  ),
  _AdminSearchEntry(
    'Cloud computer (VM)',
    _AdminTab.config,
    'vm image memory cpu qemu runtime',
    card: 'Cloud computers',
  ),
  _AdminSearchEntry(
    'Service email (SMTP)',
    _AdminTab.config,
    'smtp mail sender password tls confirmation notifications reset',
    card: 'Service email',
  ),
  _AdminSearchEntry(
    'Stripe setup',
    _AdminTab.billing,
    'billing stripe keys webhook secret trial enable',
    card: 'Stripe billing',
  ),
  _AdminSearchEntry(
    'Plans',
    _AdminTab.billing,
    'pricing price subscription tiers create edit',
    card: 'Plans',
  ),
  _AdminSearchEntry(
    'Subscriptions',
    _AdminTab.billing,
    'customers override plan status canceled trialing',
    card: 'Subscriptions',
  ),
  _AdminSearchEntry(
    'Usage analytics',
    _AdminTab.analytics,
    'stats runs tokens users charts success rate',
  ),
  _AdminSearchEntry(
    'Top users and recent runs',
    _AdminTab.analytics,
    'usage leaderboard',
    card: 'Top users',
  ),
  _AdminSearchEntry(
    'SQL console',
    _AdminTab.sql,
    'database query select csv templates',
    card: 'SQL console',
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
        const _PageTitle(
          title: 'Admin',
          subtitle:
              'Run this server: accounts, updates, providers, configuration '
              'and billing. Team links live on the Team page.',
        ),
        _SearchField(
          controller: _search,
          hintText: 'Search admin settings (e.g. Stripe, SMTP, Ollama, logs)',
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
      return const _EmptyCard(
        title: 'Nothing matches',
        subtitle: 'Try a provider name, “email”, “limits”, “update” or “logs”.',
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
                subtitle: Text('Admin › ${entry.tab.label}'),
                trailing: const Icon(Icons.chevron_right),
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
