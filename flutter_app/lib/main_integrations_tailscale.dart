part of 'main.dart';

class _TailscaleSignInActions extends StatelessWidget {
  const _TailscaleSignInActions({required this.controller});
  final NeoAgentController controller;

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (context.mounted) _showControllerError(context, controller, error);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(appStrings.tailscaleSignInBrowser),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 8,
        children: <Widget>[
          FilledButton.icon(
            onPressed: () => _run(context, controller.openTailscaleSignIn),
            icon: const Icon(Icons.open_in_new),
            label: Text(appStrings.tailscaleOpenSignIn),
          ),
          OutlinedButton(
            onPressed: () => _run(context, controller.cancelTailscaleSignIn),
            child: Text(appStrings.cancel),
          ),
        ],
      ),
    ],
  );
}

Future<void> _showTailscaleServiceAccess(
  BuildContext context,
  NeoAgentController controller,
  int connectionId,
) async {
  TailscaleAccess access;
  try {
    access = await controller.getTailscaleServiceAccess(connectionId);
  } catch (error) {
    if (context.mounted) _showControllerError(context, controller, error);
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _TailscaleServiceDialog(
      controller: controller,
      connectionId: connectionId,
      access: access,
    ),
  );
}

class _TailscaleServiceDialog extends StatefulWidget {
  const _TailscaleServiceDialog({
    required this.controller,
    required this.connectionId,
    required this.access,
  });
  final NeoAgentController controller;
  final int connectionId;
  final TailscaleAccess access;

  @override
  State<_TailscaleServiceDialog> createState() =>
      _TailscaleServiceDialogState();
}

class _TailscaleServiceDialogState extends State<_TailscaleServiceDialog> {
  late final List<TailscaleGrant> _grants = widget.access.services.toList();
  final TextEditingController _port = TextEditingController();
  final TextEditingController _path = TextEditingController();
  late String? _peerId = widget.access.peers.firstOrNull?.id;
  String _scheme = 'https';
  final Set<String> _methods = <String>{'GET'};
  bool _busy = false;
  String _error = '';

  @override
  void dispose() {
    _port.dispose();
    _path.dispose();
    super.dispose();
  }

  void _add() {
    final port = int.tryParse(_port.text.trim());
    if (_peerId == null ||
        port == null ||
        port < 1 ||
        port > 65535 ||
        !_path.text.startsWith('/') ||
        _methods.isEmpty) {
      setState(() => _error = appStrings.tailscaleServiceValidation);
      return;
    }
    setState(() {
      _error = '';
      _grants.add(
        TailscaleGrant(
          peerId: _peerId!,
          port: port,
          scheme: _scheme,
          path: _path.text,
          methods: _methods.toList(),
        ),
      );
      _path.clear();
    });
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await widget.controller.saveTailscaleServiceAccess(
        widget.connectionId,
        _grants,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = widget.controller.friendlyErrorMessage(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => _IntegrationDialog(
    title: appStrings.tailscaleServiceAccess,
    subtitle: appStrings.tailscaleServiceAccessHelp,
    width: 600,
    error: _error,
    onClose: _busy ? null : () => Navigator.of(context).pop(),
    children: <Widget>[
      for (final (index, grant) in _grants.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _RowSurface(
            child: Row(
              children: <Widget>[
                Icon(Icons.lan_outlined, size: 20, color: _textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${grant.scheme}://${widget.access.peers.where((peer) => peer.id == grant.peerId).firstOrNull?.name ?? grant.peerId}:${grant.port}${grant.path}',
                        style: _monoStyle(size: 12.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        grant.methods.join(' · '),
                        style: TextStyle(color: _textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: appStrings.remove,
                  onPressed: _busy
                      ? null
                      : () => setState(() => _grants.removeAt(index)),
                  icon: Icon(Icons.delete_outline_rounded, color: _danger),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _bgSecondary.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DropdownButtonFormField<String>(
              initialValue: _peerId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: appStrings.tailscalePeer,
                border: const OutlineInputBorder(),
              ),
              items: widget.access.peers
                  .map(
                    (peer) => DropdownMenuItem<String>(
                      value: peer.id,
                      child: Text(peer.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _peerId = value),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<String>(
                    initialValue: _scheme,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'https', child: Text('HTTPS')),
                      DropdownMenuItem(value: 'http', child: Text('HTTP')),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _scheme = value ?? 'https'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _port,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: appStrings.port,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _path,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: appStrings.tailscaleExactPath,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final method in const <String>[
                  'GET',
                  'HEAD',
                  'OPTIONS',
                  'POST',
                  'PUT',
                  'PATCH',
                  'DELETE',
                ])
                  FilterChip(
                    label: Text(method),
                    selected: _methods.contains(method),
                    onSelected: _busy
                        ? null
                        : (selected) => setState(() {
                            if (selected) {
                              _methods.add(method);
                            } else {
                              _methods.remove(method);
                            }
                          }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _add,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(appStrings.add),
            ),
          ],
        ),
      ),
    ],
    actions: <Widget>[
      FilledButton(
        onPressed: _busy ? null : _save,
        child: _IntegrationBusyLabel(busy: _busy, label: appStrings.save),
      ),
    ],
  );
}
