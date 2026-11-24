part of 'main.dart';

/// Settings › Computer: whether the agent may share web pages from its
/// computer, and the pages it shares now.
class _SharedWebPagesGroup extends StatefulWidget {
  const _SharedWebPagesGroup({required this.controller});

  final NeoAgentController controller;

  @override
  State<_SharedWebPagesGroup> createState() => _SharedWebPagesGroupState();
}

class _SharedWebPagesGroupState extends State<_SharedWebPagesGroup> {
  bool _refreshing = false;
  String? _busyId;
  String? _error;

  NeoAgentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      await _controller.refreshWebShares();
      if (mounted) setState(() => _error = null);
    } catch (error) {
      if (mounted) setState(() => _error = formatCaughtError(error));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _setEnabled(bool enabled) {
    _autosaveSettings(_controller, <String, dynamic>{
      'web_sharing_enabled': enabled,
    });
  }

  Future<void> _stop(Map<String, dynamic> share) async {
    final id = share['id']?.toString() ?? '';
    setState(() {
      _busyId = id;
      _error = null;
    });
    try {
      await _controller.stopWebShare(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appStrings.sharedWebPageStopped(share['name']?.toString() ?? ''),
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = formatCaughtError(error));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _copy(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(appStrings.linkCopied)));
  }

  void _open(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    unawaited(
      url_launcher.launchUrl(
        uri,
        mode: url_launcher.LaunchMode.externalApplication,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _controller.webShares;
    // Nothing to show until the server answers, or when its admin turned
    // sharing off for everyone.
    if (data['allowed'] != true) return const SizedBox.shrink();
    final supported = data['supported'] != false;
    final enabled = _controller.webSharingEnabled;
    final computerRunning = data['computerRunning'] == true;
    final shares = _jsonList(data['shares'])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final error = _error;

    return _SettingsGroup(
      title: appStrings.sharedWebPages,
      description: appStrings.sharedWebPagesDescription,
      trailing: supported
          ? IconButton(
              tooltip: appStrings.refresh,
              onPressed: _refreshing ? null : _refresh,
              icon: const Icon(Icons.refresh, size: 18),
            )
          : null,
      children: <Widget>[
        if (!supported)
          _SettingsBlock(
            anchor: 'sharedWebPages',
            child: Text(
              appStrings.sharedWebPagesUnsupported,
              style: TextStyle(color: _textSecondary),
            ),
          )
        else ...<Widget>[
          _SettingsRow(
            anchor: 'sharedWebPages',
            label: appStrings.allowWebPageSharing,
            description: appStrings.allowWebPageSharingDescription,
            control: Switch(value: enabled, onChanged: _setEnabled),
          ),
          if (enabled && shares.isEmpty)
            _SettingsBlock(
              child: Text(
                appStrings.noSharedWebPages,
                style: TextStyle(color: _textSecondary),
              ),
            ),
          if (enabled)
            for (final share in shares) _shareRow(share),
          if (enabled && shares.isNotEmpty && !computerRunning)
            _SettingsBlock(
              child: Text(
                appStrings.sharedWebPagesOffline,
                style: TextStyle(color: _textSecondary),
              ),
            ),
        ],
        if (error != null) _SettingsBlock(child: _InlineError(message: error)),
      ],
    );
  }

  Widget _shareRow(Map<String, dynamic> share) {
    final id = share['id']?.toString() ?? '';
    final url = share['url']?.toString() ?? '';
    final busy = _busyId == id;
    return _SettingsRow(
      label: share['name']?.toString() ?? '',
      description:
          '$url\n${appStrings.sharedWebPagePortArg1(share['port'] ?? '')}',
      control: Wrap(
        spacing: 4,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          IconButton(
            tooltip: appStrings.open,
            onPressed: url.isEmpty ? null : () => _open(url),
            icon: const Icon(Icons.open_in_new, size: 18),
          ),
          IconButton(
            tooltip: appStrings.copyLink,
            onPressed: url.isEmpty ? null : () => _copy(url),
            icon: const Icon(Icons.link, size: 18),
          ),
          OutlinedButton(
            onPressed: busy ? null : () => _stop(share),
            child: Text(appStrings.stopSharing),
          ),
        ],
      ),
    );
  }
}
