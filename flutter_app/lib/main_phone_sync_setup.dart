part of 'main.dart';

/// Turning this phone's calendar and contacts sharing on, changing it, or
/// stopping it. Only phones open this; elsewhere the integration points here.
Future<void> _showPhoneSyncSetup(
  BuildContext context,
  NeoAgentController controller,
) async {
  await controller.phoneSync.refresh();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PhoneSyncSheet(controller: controller),
  );
}

/// Asked once per install, the first time the app is ready after sign-in.
Future<void> _offerPhoneSyncSetup(
  BuildContext context,
  NeoAgentController controller,
) async {
  final phoneSync = controller.phoneSync;
  await phoneSync.markOffered();
  if (!context.mounted) return;
  final setUp = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(Icons.event_available_rounded, color: _accent, size: 32),
      title: Text(appStrings.phoneSyncPromptTitle),
      content: Text(
        appStrings.phoneSyncPromptBody,
        textAlign: TextAlign.center,
        style: TextStyle(color: _textSecondary, height: 1.45),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(appStrings.notNow),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(appStrings.setUp),
        ),
      ],
    ),
  );
  if (setUp == true && context.mounted) {
    await _showPhoneSyncSetup(context, controller);
  }
}

class _PhoneSyncSheet extends StatefulWidget {
  const _PhoneSyncSheet({required this.controller});

  final NeoAgentController controller;

  @override
  State<_PhoneSyncSheet> createState() => _PhoneSyncSheetState();
}

class _PhoneSyncSheetState extends State<_PhoneSyncSheet> {
  late Set<String> _selected = _sharing
      ? _phoneSync.status.kinds.toSet()
      : PhoneSync.kinds.toSet();
  bool _denied = false;
  String _error = '';

  PhoneSync get _phoneSync => widget.controller.phoneSync;
  bool get _sharing => _phoneSync.isSharingWithCurrentAgent;
  bool get _changed => !setEquals(_selected, _phoneSync.status.kinds.toSet());

  Future<void> _share() async {
    setState(() {
      _error = '';
      _denied = false;
    });
    try {
      final shared = await _phoneSync.enable(_selected.toList());
      if (!mounted) return;
      if (shared.isEmpty) {
        setState(() => _denied = true);
        return;
      }
      setState(() => _selected = shared.toSet());
    } catch (error) {
      if (mounted) {
        setState(() => _error = widget.controller.friendlyErrorMessage(error));
      }
    }
  }

  Future<void> _stop() async {
    await _phoneSync.disable();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _phoneSync,
      builder: (context, _) {
        final status = _phoneSync.status;
        final busy = _phoneSync.busy;
        final otherAgent = status.enabled && !_sharing;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _sharing
                          ? Icons.event_available_rounded
                          : Icons.edit_calendar_rounded,
                      color: _accent,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  appStrings.phoneSyncTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _sharing ? _syncLine(status) : appStrings.phoneSyncIntro,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: status.lastError != null && _sharing
                        ? _danger
                        : _textSecondary,
                    height: 1.45,
                  ),
                ),
                if (!_sharing) ...<Widget>[
                  const SizedBox(height: 18),
                  _PhoneSyncPoint(
                    icon: Icons.sync_rounded,
                    text: appStrings.phoneSyncPointAccounts,
                  ),
                  _PhoneSyncPoint(
                    icon: Icons.lock_outline_rounded,
                    text: appStrings.phoneSyncPointPrivate,
                  ),
                  _PhoneSyncPoint(
                    icon: Icons.edit_note_rounded,
                    text: appStrings.phoneSyncPointWrites,
                  ),
                ],
                const SizedBox(height: 18),
                _PhoneSyncKindTile(
                  icon: Icons.calendar_month_rounded,
                  title: appStrings.triggerSectionCalendar,
                  subtitle: appStrings.phoneSyncCalendarHint,
                  value: _selected.contains('calendar'),
                  onChanged: busy ? null : (on) => _toggle('calendar', on),
                ),
                const SizedBox(height: 8),
                _PhoneSyncKindTile(
                  icon: Icons.contacts_rounded,
                  title: appStrings.phoneSyncContacts,
                  subtitle: appStrings.phoneSyncContactsHint,
                  value: _selected.contains('contacts'),
                  onChanged: busy ? null : (on) => _toggle('contacts', on),
                ),
                if (otherAgent) ...<Widget>[
                  const SizedBox(height: 12),
                  _InlineNote(
                    icon: Icons.swap_horiz_rounded,
                    message: appStrings.phoneSyncOtherAgent,
                  ),
                ],
                if (_denied) ...<Widget>[
                  const SizedBox(height: 12),
                  _InlineNote(
                    icon: Icons.block_rounded,
                    message: appStrings.phoneSyncDenied,
                  ),
                  TextButton.icon(
                    onPressed: _phoneSync.openSettings,
                    icon: const Icon(Icons.settings_rounded),
                    label: Text(appStrings.openPhoneSettings),
                  ),
                ],
                if (_error.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    _error,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _danger, fontSize: 12.5),
                  ),
                ],
                const SizedBox(height: 20),
                if (!_sharing || _changed)
                  FilledButton(
                    onPressed: busy || _selected.isEmpty ? null : _share,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(
                      busy
                          ? appStrings.saving
                          : _sharing
                          ? appStrings.save
                          : appStrings.phoneSyncShare,
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: busy ? null : _phoneSync.syncNow,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.sync_rounded),
                    label: Text(busy ? appStrings.saving : appStrings.syncNow),
                  ),
                if (_sharing) ...<Widget>[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: busy ? null : _stop,
                    style: TextButton.styleFrom(foregroundColor: _danger),
                    child: Text(appStrings.phoneSyncStop),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _toggle(String kind, bool on) {
    setState(() {
      _selected = <String>{..._selected};
      on ? _selected.add(kind) : _selected.remove(kind);
    });
  }

  String _syncLine(DeviceSyncStatus status) {
    if (status.lastError != null) return status.lastError!;
    final at = status.lastSuccessAt;
    return at == null
        ? appStrings.phoneSyncWaiting
        : appStrings.phoneSyncLastSyncedArg1(_relativeTime(at.toLocal()));
  }
}

class _PhoneSyncPoint extends StatelessWidget {
  const _PhoneSyncPoint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: _accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(color: _textPrimary, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _PhoneSyncKindTile extends StatelessWidget {
  const _PhoneSyncKindTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: value ? _accent.withValues(alpha: 0.08) : _bgSecondary,
      borderRadius: BorderRadius.circular(16),
      child: SwitchListTile.adaptive(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: value ? _accent.withValues(alpha: 0.4) : _border),
        ),
        secondary: Icon(icon, color: value ? _accent : _textSecondary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(color: _textSecondary)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
