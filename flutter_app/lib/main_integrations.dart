part of 'main.dart';

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
          final busy = controller.isOfficialIntegrationBusy(item.id);
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _bgSecondary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: item.isConnected ? _accentMuted : _border,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                final actionRow = Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    if (!item.env.configured)
                      OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.settings_suggest_outlined),
                        label: const Text('Server Setup Required'),
                      )
                    else if (item.isConnected)
                      FilledButton.icon(
                        onPressed: busy
                            ? null
                            : () => controller.connectOfficialIntegration(
                                item.id,
                              ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(busy ? 'Working...' : 'Reconnect'),
                      )
                    else
                      FilledButton.icon(
                        onPressed: busy
                            ? null
                            : () => controller.connectOfficialIntegration(
                                item.id,
                              ),
                        icon: const Icon(Icons.link_rounded),
                        label: Text(busy ? 'Connecting...' : 'Connect'),
                      ),
                    if (item.isConnected)
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => controller.disconnectOfficialIntegration(
                                item.id,
                              ),
                        icon: const Icon(Icons.link_off_rounded),
                        label: const Text('Disconnect'),
                      ),
                  ],
                );

                final body = <Widget>[
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
                                ...item.apps.map(
                                  (app) => _MetaPill(
                                    label: app.label,
                                    icon: Icons.apps_rounded,
                                  ),
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
                                  ? 'Connected as ${item.connection.accountEmail ?? 'unknown account'}'
                                  : 'Connect once to unlock Gmail, Calendar, Drive, Docs, and Sheets for the AI.',
                              style: const TextStyle(color: _textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (compact) ...<Widget>[
                    const SizedBox(height: 14),
                    actionRow,
                  ],
                ];

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: body,
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: body,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 220,
                      child: Align(
                        alignment: Alignment.topRight,
                        child: actionRow,
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
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
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.36)),
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
