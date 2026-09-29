part of 'main.dart';

// Delegated access: who manages this account (every user), and whom this
// account manages (admins). The server resolves every permission; these
// widgets only show and edit what it returns.

/// Invite and delegation errors carry a code (INVITE_EXPIRED, ...) and a
/// message written for this situation, so show that message as-is.
String _accessErrorText(NeoAgentController controller, Object error) {
  if (error is BackendException && error.code != null) return error.message;
  return controller._friendlyErrorMessage(error);
}

String _permissionLabel(String key) => _categoryInfo(key).label;

// ── Managed by (shown to every account) ─────────────────────────────────────

class _ManagedBySection extends StatelessWidget {
  const _ManagedBySection({required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    final summary = controller.accessSummary;
    final managedBy = summary?.managedBy;
    final Widget body;
    if (summary == null) {
      body = const _LoadingPlaceholder();
    } else if (managedBy == null) {
      body = _NotManaged(controller: controller);
    } else {
      body = _ManagedByDetails(
        controller: controller,
        managedBy: managedBy,
        permissions: summary.permissions,
      );
    }
    return _SectionCard(title: appStrings.managedBy, child: body);
  }
}

class _NotManaged extends StatelessWidget {
  const _NotManaged({required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          appStrings.youReOnYourOwnYou +
          appStrings.aTeammateSentYouAnInvite,
          style: TextStyle(color: _textSecondary, height: 1.45),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => _showRedeemInviteDialog(context, controller),
          icon: Icon(Icons.link),
          label: Text(appStrings.enterInviteLink),
        ),
      ],
    );
  }
}

class _ManagedByDetails extends StatelessWidget {
  const _ManagedByDetails({
    required this.controller,
    required this.managedBy,
    required this.permissions,
  });

  final NeoAgentController controller;
  final ManagedBy managedBy;
  final List<AccessPermission> permissions;

  @override
  Widget build(BuildContext context) {
    final manager = managedBy.manager;
    final since = managedBy.since;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.supervisor_account_outlined, color: _accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    appStrings.arg1ManagesThisAccount(manager.label),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (since != null)
                    Text(
                      appStrings.sinceArg1(_formatDate(since)),
                      style: TextStyle(color: _textMuted, fontSize: 12.5),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (managedBy.chain.length > 1) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            appStrings.chainArg1(managedBy.chain.map((person) => person.label).join(' › ')) +
            appStrings.aDecisionHigherUpTheChain,
            style: TextStyle(color: _textSecondary, fontSize: 13),
          ),
        ],
        const SizedBox(height: 14),
        _AccessPermissionList(controller: controller, permissions: permissions),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: _danger,
            side: BorderSide(color: _danger.withValues(alpha: 0.6)),
          ),
          onPressed: () => _confirmDelete(
            context,
            title: appStrings.leaveArg1STeam(manager.label),
            message: [
              appStrings.everythingArg1TurnedOffForYour(manager.label) +
                  appStrings.backOn,
              if (controller.accessSummary?.managing.isNotEmpty ?? false)
                appStrings.thePeopleYouManageStayWith,
            ].join(' '),
            confirmLabel: 'Leave',
            onConfirm: () async {
              await controller.leaveManager();
            },
          ),
          icon: Icon(Icons.logout),
          label: Text(appStrings.leave),
        ),
      ],
    );
  }
}

/// Read-only list of an account's own permissions and who decided each one.
class _AccessPermissionList extends StatelessWidget {
  const _AccessPermissionList({
    required this.controller,
    required this.permissions,
  });

  final NeoAgentController controller;
  final List<AccessPermission> permissions;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: permissions
          .map(
            (permission) => _AccessPermissionRow(
              permission: permission,
              source: _sourceLabel(permission),
              trailing: _StatusPill(
                label: permission.allowed ? 'Allowed' : 'Off',
                color: permission.allowed ? _success : _textMuted,
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  String _sourceLabel(AccessPermission permission) {
    final setBy = permission.setBy;
    if (setBy == null) return '';
    return permission.allowed
        ? appStrings.allowedByArg1(setBy.label)
        : appStrings.turnedOffByArg1(setBy.label);
  }
}

class _AccessPermissionRow extends StatelessWidget {
  const _AccessPermissionRow({
    required this.permission,
    required this.source,
    required this.trailing,
    this.locked = false,
  });

  final AccessPermission permission;
  final String source;
  final Widget trailing;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final info = _categoryInfo(permission.key);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Icon(info.icon, size: 18, color: _textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(info.label),
                if (source.isNotEmpty)
                  Row(
                    children: <Widget>[
                      if (locked) ...<Widget>[
                        Icon(Icons.lock_outline, size: 12, color: _textMuted),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          source,
                          style: TextStyle(color: _textMuted, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

// ── Redeeming an invite link ────────────────────────────────────────────────

Future<void> _showRedeemInviteDialog(
  BuildContext context,
  NeoAgentController controller,
) async {
  final joined = await showDialog<String>(
    context: context,
    builder: (_) => _RedeemInviteDialog(controller: controller),
  );
  if (joined == null || !context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(appStrings.arg1NowManagesThisAccount(joined))));
}

class _RedeemInviteDialog extends StatefulWidget {
  const _RedeemInviteDialog({required this.controller});

  final NeoAgentController controller;

  @override
  State<_RedeemInviteDialog> createState() => _RedeemInviteDialogState();
}

class _RedeemInviteDialogState extends State<_RedeemInviteDialog> {
  final TextEditingController _linkController = TextEditingController();
  DelegationInvitePreview? _preview;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    await _run(() async {
      final preview = await widget.controller.previewDelegationInvite(
        _linkController.text.trim(),
      );
      setState(() => _preview = preview);
    });
  }

  Future<void> _confirm() async {
    await _run(() async {
      await widget.controller.redeemDelegationInvite(
        _linkController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(_preview!.issuer.label);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _accessErrorText(widget.controller, error);
          _preview = null;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return AlertDialog(
      backgroundColor: _bgCard,
      title: Text(
        preview == null
            ? appStrings.enterInviteLink
            : appStrings.arg1WillManageThisAccount(preview.issuer.label),
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (preview == null)
                TextField(
                  controller: _linkController,
                  autofocus: true,
                  enabled: !_busy,
                  decoration: InputDecoration(
                    labelText: appStrings.inviteLink,
                    hintText: 'https://…/app/?invite=…',
                  ),
                  onSubmitted: (_) => _check(),
                )
              else
                _InvitePreviewDetails(preview: preview),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 14),
                _InlineError(message: _error!),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(appStrings.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : (preview == null ? _check : _confirm),
          child: Text(
            preview == null
                ? appStrings.checkLink
                : appStrings.letArg1ManageMe(preview.issuer.label),
          ),
        ),
      ],
    );
  }
}

class _InvitePreviewDetails extends StatelessWidget {
  const _InvitePreviewDetails({required this.preview});

  final DelegationInvitePreview preview;

  @override
  Widget build(BuildContext context) {
    final issuer = preview.issuer.label;
    final expiresAt = preview.expiresAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          appStrings.fromNowOnArg1DecidesWhich(issuer) +
          appStrings.seeYourUsernameAndTheseSettings +
          appStrings.orFiles,
          style: TextStyle(color: _textSecondary, height: 1.45),
        ),
        const SizedBox(height: 14),
        Text(
          preview.permissions.isEmpty
              ? appStrings.yourAgentWillNotBeAllowedAny
              : appStrings.yourAgentWillBeAllowed,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (preview.permissions.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: preview.permissions
                .map(
                  (key) => _MetaPill(
                    label: _permissionLabel(key),
                    icon: _categoryInfo(key).icon,
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 8),
          Text(
            appStrings.everythingElseIsTurnedOff,
            style: TextStyle(color: _textSecondary),
          ),
        ],
        const SizedBox(height: 14),
        Text(
          [
            if (expiresAt != null)
              appStrings.linkValidUntilArg1(_formatDate(expiresAt)),
            appStrings.youCanLeaveAtAnyTime,
          ].join(' '),
          style: TextStyle(color: _textMuted, fontSize: 12.5),
        ),
      ],
    );
  }
}

// ── Team page (every account) ───────────────────────────────────────────────

/// Who manages this account, whom it manages, and the invite links that set
/// that up. Open to every account; it has nothing to do with server admin.
class TeamPanel extends StatefulWidget {
  const TeamPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<TeamPanel> createState() => _TeamPanelState();
}

class _TeamPanelState extends State<TeamPanel> {
  NeoAgentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.refreshAccess());
  }

  @override
  Widget build(BuildContext context) {
    final summary = _controller.accessSummary;
    final inTeam =
        summary != null &&
        (summary.managedBy != null || summary.managing.isNotEmpty);
    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Team',
          subtitle:
              appStrings.letSomeoneYouWorkWithDecide +
              appStrings.useOrDoTheSameFor,
        ),
        if (_controller.errorMessage != null) ...<Widget>[
          _InlineError(
            message: _controller.errorMessage!,
            onDismiss: _controller.clearInlineError,
          ),
          const SizedBox(height: 16),
        ],
        _SectionStack(
          children: <Widget>[
            // Shown open until the account is part of a team, then folded
            // away.
            _TeamExplainer(
              key: ValueKey<bool>(inTeam),
              initiallyExpanded: !inTeam,
            ),
            _ManagedBySection(controller: _controller),
            _ManagingSection(controller: _controller, summary: summary),
            _InviteLinksSection(controller: _controller, summary: summary),
          ],
        ),
      ],
    );
  }
}

/// Plain-language difference between an account on its own and one that has
/// joined a team through an invite link.
class _TeamExplainer extends StatelessWidget {
  const _TeamExplainer({super.key, required this.initiallyExpanded});

  final bool initiallyExpanded;

  static List<(IconData, String, String)> _points =
      <(IconData, String, String)>[
        (
          Icons.person_outline,
          appStrings.onYourOwnTheDefault,
          appStrings.youDecideWhichToolsYourAgent +
              appStrings.permissionsToolPermissionsNobodyElseCan,
        ),
        (
          Icons.link,
          appStrings.joiningATeam,
          appStrings.aTeammateSendsYouAnInvite +
              appStrings.decideWhichToolsYourAgentMay +
              appStrings.theseSwitchesNeverYourChatsMemories,
        ),
        (
          Icons.account_tree_outlined,
          'Chains',
          appStrings.managersCanHaveManagersOfTheir +
              appStrings.decisionHigherUpTheChainWins +
              appStrings.nameOfWhoeverMadeIt,
        ),
        (
          Icons.logout,
          'Leaving',
          appStrings.youCanLeaveATeamAt,
        ),
        (
          Icons.admin_panel_settings_outlined,
          appStrings.notTheSameAsAdmin,
          appStrings.teamLinksNeverMakeAnyoneA +
              appStrings.serverItselfAccountsProvidersAndConfiguration,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          leading: Icon(Icons.help_outline, color: _accent),
          title: Text(
            appStrings.howTeamsWork,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          children: _points
              .map(
                (point) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(point.$1, size: 18, color: _textSecondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              point.$2,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              point.$3,
                              style: TextStyle(
                                color: _textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

/// Server-wide log of admin grants, invite links and team changes. Admin only.
class _AccessActivityCard extends StatefulWidget {
  const _AccessActivityCard({required this.controller});

  final NeoAgentController controller;

  @override
  State<_AccessActivityCard> createState() => _AccessActivityCardState();
}

class _AccessActivityCardState extends State<_AccessActivityCard>
    with _LoadSaveState<_AccessActivityCard> {
  List<Map<String, dynamic>> _entries = const <Map<String, dynamic>>[];
  Map<String, String> _usernames = const <String, String>{};

  @override
  NeoAgentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _runLoad(_fetch);
  }

  Future<void> _fetch() async {
    final response = await _client.fetchAccessAudit(_baseUrl, limit: 50);
    final entries = response['entries'];
    final usernames = response['usernames'];
    _entries = entries is List
        ? entries
              .whereType<Map<dynamic, dynamic>>()
              .map((entry) => Map<String, dynamic>.from(entry))
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    _usernames = usernames is Map
        ? usernames.map((id, name) => MapEntry(id.toString(), name.toString()))
        : const <String, String>{};
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: appStrings.accessActivity,
      trailing: _RefreshButton(
        busy: _loading,
        onPressed: () => _runLoad(_fetch),
      ),
      child:
          _loadGate(_fetch) ??
          _AccessActivityList(entries: _entries, usernames: _usernames),
    );
  }
}

class _ManagingSection extends StatelessWidget {
  const _ManagingSection({required this.controller, required this.summary});

  final NeoAgentController controller;
  final AccessSummary? summary;

  @override
  Widget build(BuildContext context) {
    final managing = summary?.managing ?? const <ManagedAccount>[];
    return _SectionCard(
      title: appStrings.managing,
      child: managing.isEmpty
          ? Text(
              appStrings.youDonTManageAnyoneYet +
              appStrings.sendItToATeammateWith,
              style: TextStyle(color: _textSecondary, height: 1.45),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < managing.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: 10),
                  _ManagedAccountCard(
                    key: ValueKey<int>(managing[i].person.id),
                    controller: controller,
                    account: managing[i],
                    // One teammate: show their switches. Several: a compact
                    // list.
                    initiallyExpanded: managing.length == 1,
                  ),
                ],
              ],
            ),
    );
  }
}

class _ManagedAccountCard extends StatefulWidget {
  const _ManagedAccountCard({
    super.key,
    required this.controller,
    required this.account,
    required this.initiallyExpanded,
  });

  final NeoAgentController controller;
  final ManagedAccount account;
  final bool initiallyExpanded;

  @override
  State<_ManagedAccountCard> createState() => _ManagedAccountCardState();
}

class _ManagedAccountCardState extends State<_ManagedAccountCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final account = widget.account;
    final person = account.person;
    final since = account.since;
    final myId = _asInt(controller.user?['id']);
    final allowed = account.permissions.where((p) => p.allowed).length;
    return _RowSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      person.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      [
                        '@${person.username}',
                        if (since != null) appStrings.sinceArg12(_formatDate(since)),
                        appStrings.arg1OfArg2ToolsAllowed(allowed, account.permissions.length),
                      ].join(' · '),
                      style: TextStyle(color: _textMuted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: _expanded ? 'Hide tools' : appStrings.showTools,
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              ),
              TextButton(
                onPressed: () => _confirmDelete(
                  context,
                  title: appStrings.stopManagingArg1(person.label),
                  message:
                      appStrings.everythingYouTurnedOffForArg1(person.label) +
                      appStrings.onTheyCanJoinAgainOnly,
                  confirmLabel: appStrings.stopManaging,
                  onConfirm: () => controller.releaseManagedAccount(person.id),
                ),
                child: Text(appStrings.stopManaging),
              ),
            ],
          ),
          if (_expanded) const SizedBox(height: 8),
          if (_expanded)
            ...account.permissions.map(
              (permission) => _AccessPermissionRow(
                permission: permission,
                locked: !permission.editable,
                source: _managedSource(permission, myId),
                trailing: Switch(
                  value: permission.allowed,
                  onChanged: permission.editable
                      ? (allowed) => controller.setManagedPermission(
                          person.id,
                          permission.key,
                          allowed,
                        )
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _managedSource(AccessPermission permission, int myId) {
    final setBy = permission.setBy;
    if (!permission.editable) {
      return setBy == null
          ? appStrings.notYoursToChange
          : appStrings.turnedOffForYouByArg1(setBy.label);
    }
    return setBy?.id == myId ? appStrings.setByYou : '';
  }
}

class _InviteLinksSection extends StatelessWidget {
  const _InviteLinksSection({required this.controller, required this.summary});

  final NeoAgentController controller;
  final AccessSummary? summary;

  @override
  Widget build(BuildContext context) {
    final summary = this.summary;
    final invites = summary?.invites ?? const <DelegationInvite>[];
    return _SectionCard(
      title: appStrings.inviteLinks,
      trailing: FilledButton.icon(
        onPressed: summary == null
            ? null
            : () => _showCreateInviteDialog(context, controller, summary),
        icon: Icon(Icons.add_link),
        label: Text(appStrings.newLink),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            appStrings.whoeverAcceptsALinkJoinsYour +
            appStrings.allowsYouCanChangeThatPer +
            'admin.',
            style: TextStyle(color: _textSecondary, height: 1.45),
          ),
          if (invites.isNotEmpty) const SizedBox(height: 8),
          ...invites.map(
            (invite) => _InviteRow(
              invite: invite,
              onRevoke: () => _confirmDelete(
                context,
                title: appStrings.revokeThisLink,
                message:
                    appStrings.nobodyCanUseItAnyMore +
                    appStrings.stayManagedByYou,
                confirmLabel: 'Revoke',
                onConfirm: () => controller.revokeDelegationInvite(invite.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteRow extends StatelessWidget {
  const _InviteRow({required this.invite, required this.onRevoke});

  final DelegationInvite invite;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final expiresAt = invite.expiresAt;
    final details = <String>[
      invite.permissions.isEmpty
          ? appStrings.noTools
          : invite.permissions.map(_permissionLabel).join(', '),
      invite.singleUse ? 'Single use' : appStrings.reusableUsedArg1(invite.useCount),
      expiresAt == null ? 'No expiry' : appStrings.expiresArg1(_formatDate(expiresAt)),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  invite.label.isEmpty ? appStrings.untitledLink : invite.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  details.join(' · '),
                  style: TextStyle(color: _textMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusPill(
            label: _titleCase(invite.status),
            color: _inviteStatusColor(),
          ),
          if (invite.isActive)
            IconButton(
              tooltip: appStrings.revoke,
              onPressed: onRevoke,
              icon: Icon(Icons.link_off),
            ),
        ],
      ),
    );
  }

  Color _inviteStatusColor() {
    switch (invite.status) {
      case 'active':
        return _success;
      case 'revoked':
        return _danger;
      default:
        return _textMuted;
    }
  }
}

// ── Creating an invite link ─────────────────────────────────────────────────

enum _InviteExpiry { day, week, month, never }

extension on _InviteExpiry {
  String get label {
    switch (this) {
      case _InviteExpiry.day:
        return appStrings.n24Hours;
      case _InviteExpiry.week:
        return appStrings.n7Days;
      case _InviteExpiry.month:
        return appStrings.n30Days;
      case _InviteExpiry.never:
        return 'Never';
    }
  }

  int? get hours {
    switch (this) {
      case _InviteExpiry.day:
        return 24;
      case _InviteExpiry.week:
        return 24 * 7;
      case _InviteExpiry.month:
        return 24 * 30;
      case _InviteExpiry.never:
        return null;
    }
  }
}

Future<void> _showCreateInviteDialog(
  BuildContext context,
  NeoAgentController controller,
  AccessSummary summary,
) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        _CreateInviteDialog(controller: controller, summary: summary),
  );
}

class _CreateInviteDialog extends StatefulWidget {
  const _CreateInviteDialog({required this.controller, required this.summary});

  final NeoAgentController controller;
  final AccessSummary summary;

  @override
  State<_CreateInviteDialog> createState() => _CreateInviteDialogState();
}

class _CreateInviteDialogState extends State<_CreateInviteDialog> {
  final TextEditingController _labelController = TextEditingController();
  final Set<String> _selected = <String>{};
  _InviteExpiry _expiry = _InviteExpiry.week;
  bool _singleUse = true;
  bool _busy = false;
  String? _error;
  String? _link;

  // A link can only hand out what this account holds itself.
  Set<String> get _held => widget.summary.permissions
      .where((permission) => permission.allowed)
      .map((permission) => permission.key)
      .toSet();

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final link = await widget.controller.createDelegationInvite(
        label: _labelController.text.trim(),
        permissions: widget.summary.catalog
            .where(_selected.contains)
            .toList(growable: false),
        expiresInHours: _expiry.hours,
        singleUse: _singleUse,
      );
      if (mounted) setState(() => _link = link);
    } catch (error) {
      if (mounted) {
        setState(() => _error = _accessErrorText(widget.controller, error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = _link;
    return AlertDialog(
      backgroundColor: _bgCard,
      title: Text(link == null ? 'New invite link' : appStrings.inviteLinkReady),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: link == null ? _buildForm() : _buildResult(link),
        ),
      ),
      actions: link == null
          ? <Widget>[
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: Text(appStrings.cancel),
              ),
              FilledButton(
                onPressed: _busy ? null : _create,
                child: Text(appStrings.createLink),
              ),
            ]
          : <Widget>[
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(appStrings.done),
              ),
            ],
    );
  }

  Widget _buildForm() {
    final held = _held;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: _labelController,
          maxLength: 80,
          decoration: InputDecoration(
            labelText: appStrings.labelOnlyYouSeeIt,
            hintText: appStrings.eGAlexSLaptop,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          appStrings.toolsTheManagedAccountMayUse,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        ...widget.summary.catalog.map((key) {
          final holds = held.contains(key);
          return CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _selected.contains(key),
            onChanged: holds && !_busy
                ? (checked) => setState(() {
                    if (checked == true) {
                      _selected.add(key);
                    } else {
                      _selected.remove(key);
                    }
                  })
                : null,
            secondary: Icon(_categoryInfo(key).icon, size: 18),
            title: Text(_permissionLabel(key)),
            subtitle: holds
                ? null
                : Text(appStrings.turnedOffForYouSoYou),
          );
        }),
        const SizedBox(height: 12),
        DropdownButtonFormField<_InviteExpiry>(
          initialValue: _expiry,
          decoration: InputDecoration(labelText: appStrings.linkExpiresAfter),
          items: _InviteExpiry.values
              .map(
                (expiry) =>
                    DropdownMenuItem(value: expiry, child: Text(expiry.label)),
              )
              .toList(growable: false),
          onChanged: _busy
              ? null
              : (value) => setState(() => _expiry = value ?? _expiry),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _singleUse,
          onChanged: _busy
              ? null
              : (value) => setState(() => _singleUse = value),
          title: Text(appStrings.singleUse),
          subtitle: Text(
            _singleUse
                ? appStrings.stopsWorkingAfterOnePersonRedeemsIt
                : appStrings.anyoneWithTheLinkCanJoin,
          ),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 8),
          _InlineError(message: _error!),
        ],
      ],
    );
  }

  Widget _buildResult(String link) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          appStrings.sendThisLinkOnlyToThe +
          appStrings.theServerKeepsOnlyAFingerprint,
          style: TextStyle(color: _textSecondary, height: 1.45),
        ),
        const SizedBox(height: 14),
        _RowSurface(child: SelectableText(link, style: _monoStyle(size: 12.5))),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: link));
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(appStrings.linkCopied)));
          },
          icon: Icon(Icons.copy),
          label: Text(appStrings.copyLink),
        ),
      ],
    );
  }
}

// ── Activity (audit log) ────────────────────────────────────────────────────

class _AccessActivityList extends StatelessWidget {
  const _AccessActivityList({required this.entries, required this.usernames});

  final List<Map<String, dynamic>> entries;
  final Map<String, String> usernames;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return _EmptyText(
        appStrings.adminGrantsInviteLinksAndManagement,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: Text(_describe(entry))),
                const SizedBox(width: 12),
                Text(
                  _formatTimestamp(
                    _parseTimestamp(entry['createdAt']?.toString()),
                  ),
                  style: TextStyle(color: _textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _person(Object? value) {
    if (value is! Map) return appStrings.aDeletedAccount;
    return value['username']?.toString() ?? appStrings.aDeletedAccount;
  }

  String _personById(Object? id) {
    if (id == null) return appStrings.aDeletedAccount;
    return usernames[id.toString()] ?? appStrings.aDeletedAccount;
  }

  String _describe(Map<String, dynamic> entry) {
    final detail = entry['detail'] is Map
        ? Map<String, dynamic>.from(entry['detail'] as Map)
        : const <String, dynamic>{};
    final actor = entry['actor'] == null
        ? appStrings.theOperator
        : _person(entry['actor']);
    final subject = _person(entry['subject']);
    switch (entry['action']?.toString()) {
      case 'admin.grant':
        return appStrings.arg1BecameAnAdminArg2(subject, detail['source'] ?? 'operator');
      case 'admin.revoke':
        return appStrings.arg1IsNoLongerAnAdmin(subject, detail['source'] ?? 'operator');
      case 'invite.create':
        return appStrings.arg1CreatedAnInviteLink(actor);
      case 'invite.revoke':
        final count = _asInt(detail['count']);
        return count > 1
            ? appStrings.arg1InviteLinksFromArg2WereRevoked(count, subject)
            : appStrings.arg1RevokedAnInviteLink(actor);
      case 'delegation.create':
        return appStrings.arg1JoinedUnderArg2(subject, _personById(detail['managerUserId']));
      case 'delegation.leave':
        return appStrings.arg1LeftArg2(subject, _personById(detail['managerUserId']));
      case 'delegation.release':
        return appStrings.arg1StoppedManagingArg2(_personById(detail['managerUserId']), subject);
      case 'delegation.reattach':
        return appStrings.arg1MovedFromArg2(subject, _personById(detail['fromManagerUserId'])) +
            appStrings.toArg1(_personById(detail['toManagerUserId']));
      case 'delegation.permission':
        final key = detail['permission']?.toString() ?? '';
        final allowed = detail['allowed'] == true;
        return appStrings.arg1Arg28(actor, allowed ? 'allowed' : 'turned off') +
            appStrings.arg1ForArg2(_permissionLabel(key), subject);
      default:
        return entry['action']?.toString() ?? '';
    }
  }
}
