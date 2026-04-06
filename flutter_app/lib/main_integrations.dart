part of 'main.dart';

class IntegrationsPanel extends StatelessWidget {
  const IntegrationsPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _pagePadding(context),
      child: Column(
        children: <Widget>[
          _PageTitle(
            title: 'Integrations',
            subtitle:
                'Connect and manage official integrations separately from reusable skills.',
          ),
          const SizedBox(height: 12),
          Expanded(child: OfficialIntegrationsTab(controller: controller)),
        ],
      ),
    );
  }
}

class OfficialIntegrationsTab extends StatelessWidget {
  const OfficialIntegrationsTab({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.officialIntegrations.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No official integrations are available yet.',
              style: TextStyle(color: _textSecondary),
            ),
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: controller.officialIntegrations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = controller.officialIntegrations[index];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _bgSecondary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: item.isConnected ? _accentMuted : _border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _OfficialIntegrationIcon(item: item),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              _StatusPill(
                                label: item.connection.statusLabel,
                                color: item.isConnected
                                    ? _success
                                    : item.env.configured
                                    ? _info
                                    : _warning,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.description,
                            style: const TextStyle(color: _textSecondary),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              _MetaPill(
                                label:
                                    '${item.connection.accountCount} accounts',
                                icon: Icons.alternate_email_rounded,
                              ),
                              _MetaPill(
                                label:
                                    '${item.connection.appCount} apps active',
                                icon: Icons.apps_rounded,
                              ),
                              _MetaPill(
                                label: '${item.availableToolCount} tools',
                                icon: Icons.build_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            !item.env.configured
                                ? item.env.summary
                                : item.isConnected
                                ? 'Connect as many accounts as you want. Each app can use a different account.'
                                : ((item.connectPrompt ?? '').trim().isNotEmpty
                                      ? item.connectPrompt!.trim()
                                      : 'Connect app accounts individually so the AI can use the right account for each official integration.'),
                            style: const TextStyle(color: _textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...item.apps.map(
                  (app) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _OfficialIntegrationAppCard(
                      controller: controller,
                      provider: item,
                      app: app,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OfficialIntegrationAppCard extends StatelessWidget {
  const _OfficialIntegrationAppCard({
    required this.controller,
    required this.provider,
    required this.app,
  });

  final NeoAgentController controller;
  final OfficialIntegrationItem provider;
  final OfficialIntegrationAppItem app;

  @override
  Widget build(BuildContext context) {
    final connectBusy = controller.isOfficialIntegrationBusy(
      '${provider.id}:${app.id}:connect',
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgPrimary,
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
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            app.label,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _StatusPill(
                          label: app.connection.statusLabel,
                          color: app.isConnected ? _success : _textSecondary,
                        ),
                      ],
                    ),
                    if ((app.description ?? '').trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        app.description!,
                        style: const TextStyle(color: _textSecondary),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _MetaPill(
                          label: '${app.accounts.length} accounts',
                          icon: Icons.account_circle_outlined,
                        ),
                        _MetaPill(
                          label: '${app.availableToolCount} tools',
                          icon: Icons.build_circle_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (!provider.env.configured)
                OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.settings_suggest_outlined),
                  label: const Text('Admin Setup Required'),
                )
              else
                FilledButton.icon(
                  onPressed: connectBusy
                      ? null
                      : () => controller.connectOfficialIntegration(
                          provider.id,
                          appId: app.id,
                        ),
                  icon: const Icon(Icons.link_rounded),
                  label: Text(
                    connectBusy
                        ? 'Connecting...'
                        : app.isConnected
                        ? 'Add Account'
                        : 'Connect Account',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (app.accounts.isEmpty)
            const Text(
              'No accounts connected yet.',
              style: TextStyle(color: _textSecondary),
            )
          else
            Column(
              children: app.accounts.map((account) {
                final disconnectBusy = controller.isOfficialIntegrationBusy(
                  '${provider.id}:${account.id}:disconnect',
                );
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: account.connected ? _accentMuted : _border,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              account.accountEmail ?? 'Unknown account',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Connection #${account.id}',
                              style: const TextStyle(color: _textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _StatusPill(
                        label: account.statusLabel,
                        color: account.connected ? _success : _textSecondary,
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: disconnectBusy
                            ? null
                            : () => controller.disconnectOfficialIntegration(
                                provider.id,
                                connectionId: account.id,
                              ),
                        icon: const Icon(Icons.link_off_rounded),
                        label: Text(
                          disconnectBusy ? 'Working...' : 'Disconnect',
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _OfficialIntegrationIcon extends StatelessWidget {
  const _OfficialIntegrationIcon({required this.item});

  final OfficialIntegrationItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.icon == 'google' ? const Color(0xFF4285F4) : _accent;
    final label = item.icon == 'google'
        ? 'G'
        : (item.label.isNotEmpty ? item.label[0] : '?');
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.36)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
