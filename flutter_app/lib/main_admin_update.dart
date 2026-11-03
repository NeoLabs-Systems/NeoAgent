part of 'main.dart';

// Updating NeoAgent from the admin pages: the banner that offers a new
// version (and follows the update while it runs) and the updates card. The
// server runs the same flow as `neoagent update`; this only shows it.

/// What the server knows about updates: the installed version, a newer one
/// waiting on the channel, and the update job when one ran.
class _AdminUpdateStatus {
  _AdminUpdateStatus(Map<String, dynamic> json)
    : version = _asText(json['version'], fallback: ''),
      channel = _asText(json['channel'], fallback: 'beta'),
      selfUpdate = json['selfUpdate'] == true,
      blockedReason = json['blockedReason']?.toString(),
      checkedAt = DateTime.tryParse(
        json['checkedAt']?.toString() ?? '',
      )?.toLocal(),
      checkFailed = json['checkFailed'] == true,
      hasAvailable = json['available'] is Map,
      availableVersion = _jsonMap(json['available'])['version']?.toString(),
      changes = _jsonStringList(_jsonMap(json['available'])['changes']),
      state = _asText(_jsonMap(json['job'])['state'], fallback: 'idle'),
      progress = _asInt(_jsonMap(json['job'])['progress']).clamp(0, 100),
      message = _asText(_jsonMap(json['job'])['message'], fallback: ''),
      versionAfter = _jsonMap(json['job'])['versionAfter']?.toString(),
      logs = _jsonStringList(_jsonMap(json['job'])['logs']),
      completedAt = DateTime.tryParse(
        _jsonMap(json['job'])['completedAt']?.toString() ?? '',
      )?.toLocal();

  final String version;
  final String channel;
  final bool selfUpdate;
  final String? blockedReason;
  final DateTime? checkedAt;
  final bool checkFailed;
  final bool hasAvailable;
  final String? availableVersion;
  final List<String> changes;
  final String state;
  final int progress;
  final String message;
  final String? versionAfter;
  final List<String> logs;
  final DateTime? completedAt;

  bool get running => state == 'running';
  bool get canStart => hasAvailable && selfUpdate;
}

/// Loads the update status, starts updates and follows them to the end, also
/// across the server restart in the middle of one.
class _AdminUpdateWatcher extends ChangeNotifier {
  _AdminUpdateWatcher(this._client, this._baseUrl);

  final BackendClient _client;
  final String _baseUrl;
  _AdminUpdateStatus? status;
  bool busy = false;
  bool reconnecting = false;
  String? error;
  DateTime? _dismissedAt;
  bool _followed = false;
  bool _disposed = false;
  Timer? _timer;

  /// A failed update is news for half an hour, or until it is dismissed. A
  /// finished one is only news on the page that watched it run: after the
  /// reload it has been delivered.
  bool get finishedRecently {
    final done = status?.completedAt;
    if (done == null || done == _dismissedAt) return false;
    final state = status!.state;
    if (state == 'completed') return _followed;
    return state == 'failed' && DateTime.now().difference(done) < const Duration(minutes: 30);
  }

  bool get justUpdated => _followed && status?.state == 'completed';

  void dismiss() {
    _dismissedAt = status?.completedAt;
    notifyListeners();
  }

  Future<void> load() => _fetch(() => _client.fetchAdminUpdate(_baseUrl));

  Future<void> check() => _guard(
    () => _fetch(
      () => _client.checkAdminUpdate(_baseUrl),
      rethrowErrors: true,
    ),
  );

  Future<void> setChannel(String channel) => _guard(
    () => _fetch(
      () => _client.setAdminUpdateChannel(_baseUrl, channel),
      rethrowErrors: true,
    ),
  );

  Future<void> start() => _guard(() async {
    _followed = true;
    await _fetch(
      () => _client.startAdminUpdate(_baseUrl),
      rethrowErrors: true,
    );
  });

  Future<void> _guard(Future<void> Function() action) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } on BackendException catch (failure) {
      error = failure.message;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _fetch(
    Future<Map<String, dynamic>> Function() request, {
    bool rethrowErrors = false,
  }) async {
    try {
      status = _AdminUpdateStatus(await request());
      reconnecting = false;
      if (status!.running) _followed = true;
    } catch (failure) {
      // The server going away mid-update is expected; anything else is shown.
      final code = failure is BackendException ? failure.statusCode : null;
      final gone = code == null || code >= 502;
      if (_followed && gone) {
        reconnecting = true;
      } else if (rethrowErrors && failure is BackendException) {
        rethrow;
      }
    }
    _schedule();
    if (!_disposed) notifyListeners();
  }

  void _schedule() {
    _timer?.cancel();
    if (_disposed || !(status?.running == true || reconnecting)) return;
    _timer = Timer(const Duration(seconds: 2), load);
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

String _adminChannelLabel(String channel) =>
    channel == 'stable' ? appStrings.stable : appStrings.beta;

/// The banner above every admin tab. It offers the update, then shows its
/// progress, then the result; with nothing to say it takes no space.
class _AdminUpdateBanner extends StatefulWidget {
  const _AdminUpdateBanner({required this.watcher});

  final _AdminUpdateWatcher watcher;

  @override
  State<_AdminUpdateBanner> createState() => _AdminUpdateBannerState();
}

class _AdminUpdateBannerState extends State<_AdminUpdateBanner> {
  bool _showChanges = false;
  Timer? _reload;

  _AdminUpdateWatcher get watcher => widget.watcher;

  @override
  void dispose() {
    _reload?.cancel();
    super.dispose();
  }

  Future<void> _confirmAndStart(_AdminUpdateStatus status) {
    return _confirmDelete(
      context,
      title: appStrings.adminUpdateConfirmTitle(status.availableVersion ?? ''),
      message: appStrings.adminUpdateConfirmMessage,
      confirmLabel: appStrings.updateNow,
      onConfirm: watcher.start,
    );
  }

  /// The web client files changed with the update, so the page loads again.
  void _reloadSoon() {
    if (_reload != null || !canReloadPage) return;
    _reload = Timer(const Duration(seconds: 3), reloadPage);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: watcher,
      builder: (context, _) {
        final status = watcher.status;
        if (status == null) return const SizedBox.shrink();
        if (status.running || watcher.reconnecting) {
          return _frame(_accent, _running(status));
        }
        if (watcher.finishedRecently) {
          if (status.state == 'completed') {
            if (watcher.justUpdated) _reloadSoon();
            return _frame(_success, _completed(status));
          }
          return _frame(_danger, _failed(status));
        }
        if (status.canStart) return _frame(_accent, _available(status));
        return const SizedBox.shrink();
      },
    );
  }

  Widget _frame(Color tone, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: tone.withValues(alpha: 0.4)),
        ),
        child: child,
      ),
    );
  }

  Widget _heading(
    IconData icon,
    Color tone,
    String title,
    String? subtitle, {
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 20, color: tone),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  subtitle,
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
        if (trailing != null) ...<Widget>[const SizedBox(width: 12), trailing],
      ],
    );
  }

  Widget _available(_AdminUpdateStatus status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _heading(
          Icons.system_update_alt,
          _accent,
          appStrings.adminUpdateReadyTitle(status.availableVersion ?? ''),
          appStrings.adminUpdateReadySubtitle(
            status.version,
            _adminChannelLabel(status.channel),
          ),
          trailing: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              if (status.changes.isNotEmpty)
                TextButton(
                  style: _adminOpsActionStyle(),
                  onPressed: () =>
                      setState(() => _showChanges = !_showChanges),
                  child: Text(appStrings.adminUpdateWhatsNew),
                ),
              FilledButton(
                onPressed: watcher.busy ? null : () => _confirmAndStart(status),
                child: Text(appStrings.updateNow),
              ),
            ],
          ),
        ),
        if (_showChanges)
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final change in status.changes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '•  $change',
                      style: TextStyle(
                        fontSize: 13,
                        color: _textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (watcher.error != null) ...<Widget>[
          const SizedBox(height: 10),
          _InlineError(message: watcher.error!),
        ],
      ],
    );
  }

  Widget _running(_AdminUpdateStatus status) {
    final target = status.versionAfter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _heading(
          Icons.sync,
          _accent,
          target == null || target.isEmpty
              ? appStrings.adminUpdatingTitle
              : appStrings.adminUpdatingToTitle(target),
          watcher.reconnecting
              ? appStrings.adminUpdateReconnecting
              : status.message,
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: watcher.reconnecting ? null : status.progress / 100,
            minHeight: 5,
            backgroundColor: _border,
            valueColor: AlwaysStoppedAnimation<Color>(_accent),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          appStrings.adminUpdateHandsOff,
          style: TextStyle(fontSize: 12.5, color: _textMuted),
        ),
      ],
    );
  }

  Widget _completed(_AdminUpdateStatus status) {
    return _heading(
      Icons.check_circle_outline,
      _success,
      appStrings.adminUpdateDoneTitle(status.versionAfter ?? status.version),
      canReloadPage ? appStrings.adminUpdateDoneReloading : null,
      trailing: Wrap(
        spacing: 8,
        children: <Widget>[
          TextButton(
            style: _adminOpsActionStyle(),
            onPressed: watcher.dismiss,
            child: Text(appStrings.close),
          ),
          if (canReloadPage)
            FilledButton(
              onPressed: reloadPage,
              child: Text(appStrings.adminUpdateReload),
            ),
        ],
      ),
    );
  }

  Widget _failed(_AdminUpdateStatus status) {
    return _heading(
      Icons.error_outline,
      _danger,
      appStrings.adminUpdateFailedTitle,
      status.message,
      trailing: Wrap(
        spacing: 8,
        children: <Widget>[
          TextButton(
            style: _adminOpsActionStyle(),
            onPressed: watcher.dismiss,
            child: Text(appStrings.close),
          ),
          if (status.canStart)
            FilledButton(
              onPressed: watcher.busy ? null : () => _confirmAndStart(status),
              child: Text(appStrings.retry),
            ),
        ],
      ),
    );
  }
}

/// The updates card of the Server tab: channel, check now, why an install
/// cannot update itself, and the log of the last run.
class _AdminUpdateCard extends StatelessWidget {
  const _AdminUpdateCard({required this.watcher});

  final _AdminUpdateWatcher watcher;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: watcher,
      builder: (context, _) {
        final status = watcher.status;
        if (status == null) return const SizedBox.shrink();
        final locked = status.running || watcher.busy || !status.selfUpdate;
        final checked = status.checkedAt == null
            ? appStrings.adminUpdateNeverChecked
            : appStrings.adminUpdateCheckedAgo(
                _relativeTime(status.checkedAt!),
              );
        final summary = status.hasAvailable
            ? appStrings.adminUpdateReadyTitle(status.availableVersion ?? '')
            : status.checkFailed
            ? appStrings.adminUpdateCheckFailed
            : status.checkedAt == null
            ? checked
            : '${appStrings.adminUpdateUpToDate} · $checked';
        return _SectionCard(
          title: appStrings.updates,
          description: appStrings.adminUpdatesHint,
          trailing: OutlinedButton.icon(
            onPressed: locked ? null : watcher.check,
            icon: watcher.busy
                ? const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 18),
            label: Text(appStrings.adminUpdateCheckNow),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _AdminOpsFactGrid(
                facts: <(String, String)>[
                  ('Version', status.version),
                  (appStrings.releaseChannel, _adminChannelLabel(status.channel)),
                ],
              ),
              const SizedBox(height: 12),
              Text(summary, style: TextStyle(color: _textSecondary, height: 1.4)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: <ButtonSegment<String>>[
                      ButtonSegment<String>(
                        value: 'stable',
                        label: Text(appStrings.stable),
                        icon: const Icon(Icons.verified_outlined),
                      ),
                      ButtonSegment<String>(
                        value: 'beta',
                        label: Text(appStrings.beta),
                        icon: const Icon(Icons.science_outlined),
                      ),
                    ],
                    selected: <String>{status.channel},
                    onSelectionChanged: locked
                        ? null
                        : (selection) => watcher.setChannel(selection.first),
                  ),
                  Text(
                    appStrings.adminUpdateChannelHint,
                    style: TextStyle(fontSize: 12.5, color: _textMuted),
                  ),
                ],
              ),
              if (!status.selfUpdate) ...<Widget>[
                const SizedBox(height: 14),
                _blockedNote(status.blockedReason),
              ],
              if (status.logs.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(appStrings.adminUpdateDetails),
                  children: <Widget>[
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: SingleChildScrollView(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SelectableText(
                            status.logs.join('\n'),
                            style: _monoStyle(size: 12, color: _textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (watcher.error != null) ...<Widget>[
                const SizedBox(height: 14),
                _InlineError(message: watcher.error!),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _blockedNote(String? reason) {
    final container = reason == 'container';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _InlineNote(
          icon: container
              ? Icons.inventory_2_outlined
              : Icons.lock_outline_rounded,
          message: switch (reason) {
            'container' => appStrings.adminUpdateContainerHint,
            'managed' => appStrings.adminUpdateManagedHint,
            _ => appStrings.adminUpdateNotGitHint,
          },
        ),
        if (container) ...<Widget>[
          const SizedBox(height: 12),
          SelectableText(
            'docker compose pull\ndocker compose up -d',
            style: _monoStyle(size: 13, color: _textSecondary),
          ),
        ],
      ],
    );
  }
}
