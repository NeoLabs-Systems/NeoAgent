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
  Widget build(BuildContext context) => AlertDialog(
    title: Text(appStrings.tailscaleServiceAccess),
    content: SizedBox(
      width: 600,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(appStrings.tailscaleServiceAccessHelp),
            const SizedBox(height: 12),
            for (final (index, grant) in _grants.indexed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${grant.scheme}://${widget.access.peers.where((peer) => peer.id == grant.peerId).firstOrNull?.name ?? grant.peerId}:${grant.port}${grant.path}',
                ),
                subtitle: Text(grant.methods.join(', ')),
                trailing: IconButton(
                  tooltip: appStrings.remove,
                  onPressed: _busy
                      ? null
                      : () => setState(() => _grants.removeAt(index)),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _peerId,
              isExpanded: true,
              decoration: InputDecoration(labelText: appStrings.tailscalePeer),
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
            Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _scheme,
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
                    decoration: InputDecoration(labelText: appStrings.port),
                  ),
                ),
              ],
            ),
            TextField(
              controller: _path,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: appStrings.tailscaleExactPath,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
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
            TextButton.icon(
              onPressed: _busy ? null : _add,
              icon: const Icon(Icons.add),
              label: Text(appStrings.add),
            ),
            if (_error.isNotEmpty)
              Text(_error, style: TextStyle(color: _danger)),
          ],
        ),
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
        child: Text(appStrings.close),
      ),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: Text(appStrings.save),
      ),
    ],
  );
}
