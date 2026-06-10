part of 'main.dart';

class _PasswordStrengthInfo {
  const _PasswordStrengthInfo({
    required this.score,
    required this.label,
    required this.message,
    required this.color,
  });

  final int score;
  final String label;
  final String message;
  final Color color;
}

_PasswordStrengthInfo _passwordStrengthInfo({
  required String password,
  String username = '',
  String email = '',
}) {
  final value = password.trim();
  if (value.isEmpty) {
    return _PasswordStrengthInfo(
      score: 0,
      label: 'Empty',
      message: 'Use 8+ characters. Longer passphrases work well.',
      color: _borderLight,
    );
  }
  final evaluation = evaluatePasswordStrength(
    password: password,
    username: username,
    email: email,
  );
  final score = evaluation.score;

  if (!evaluation.hasMinimumLength) {
    return _PasswordStrengthInfo(
      score: 1,
      label: 'Weak',
      message: 'Use at least 8 characters.',
      color: _danger,
    );
  }
  if (evaluation.containsUserInfo) {
    return _PasswordStrengthInfo(
      score: 2,
      label: 'Fair',
      message: 'Do not include your username or email.',
      color: _warning,
    );
  }
  if (evaluation.obviousPattern) {
    return _PasswordStrengthInfo(
      score: 2,
      label: 'Fair',
      message: 'Avoid repeated characters and obvious sequences.',
      color: _warning,
    );
  }
  if (score >= 4) {
    return _PasswordStrengthInfo(
      score: 4,
      label: 'Strong',
      message: 'Strong password.',
      color: _success,
    );
  }
  if (score >= 3) {
    return _PasswordStrengthInfo(
      score: 3,
      label: 'Good',
      message: 'Good password. A little more length makes it stronger.',
      color: _success,
    );
  }
  return _PasswordStrengthInfo(
    score: 2,
    label: 'Fair',
    message: 'Add more length or another character type.',
    color: _warning,
  );
}

class _PasswordStrengthIndicator extends StatelessWidget {
  const _PasswordStrengthIndicator({required this.info});

  final _PasswordStrengthInfo info;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              'Password strength: ${info.label}',
              style: TextStyle(color: info.color, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: info.score / 4,
                  backgroundColor: _borderLight,
                  valueColor: AlwaysStoppedAnimation<Color>(info.color),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          info.message,
          style: TextStyle(color: _textSecondary, fontSize: 12, height: 1.35),
        ),
      ],
    );
  }
}

enum AccountSettingsTab { account, usage, security }

class AccountSettingsPanel extends StatefulWidget {
  const AccountSettingsPanel({
    super.key,
    required this.controller,
    this.embedded = false,
    this.initialTab,
  });

  final NeoAgentController controller;
  final bool embedded;
  final AccountSettingsTab? initialTab;

  @override
  State<AccountSettingsPanel> createState() => _AccountSettingsPanelState();
}

class _AccountSettingsPanelState extends State<AccountSettingsPanel> {
  late AccountSettingsTab _selectedTab;
  late final TextEditingController _displayNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _emailPasswordController;
  late final TextEditingController _setupPasswordController;
  late final TextEditingController _setupCodeController;
  late final TextEditingController _disablePasswordController;
  late final TextEditingController _disableCodeController;
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmNewPasswordController;
  Map<String, dynamic>? _pendingSetup;
  List<String> _recoveryCodes = const <String>[];
  String? _displayNameSuccessMessage;
  String? _displayNameInlineError;
  String? _emailSuccessMessage;
  String? _emailInlineError;
  String? _passwordSuccessMessage;
  String? _passwordInlineError;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab ?? AccountSettingsTab.account;
    _displayNameController = TextEditingController(
      text: widget.controller.user?['display_name']?.toString() ?? '',
    );
    _emailController = TextEditingController(
      text: widget.controller.user?['email']?.toString() ?? '',
    );
    _emailPasswordController = TextEditingController();
    _setupPasswordController = TextEditingController();
    _setupCodeController = TextEditingController();
    _disablePasswordController = TextEditingController();
    _disableCodeController = TextEditingController();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmNewPasswordController = TextEditingController();
    unawaited(widget.controller.refreshAccountSettings());
  }

  @override
  void didUpdateWidget(covariant AccountSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != null &&
        oldWidget.initialTab != widget.initialTab) {
      _selectedTab = widget.initialTab!;
    }
    final displayName =
        widget.controller.user?['display_name']?.toString() ?? '';
    if (_displayNameController.text.isEmpty && displayName.isNotEmpty) {
      _displayNameController.text = displayName;
    }
    final email = widget.controller.user?['email']?.toString() ?? '';
    if (_emailController.text.isEmpty && email.isNotEmpty) {
      _emailController.text = email;
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _emailPasswordController.dispose();
    _setupPasswordController.dispose();
    _setupCodeController.dispose();
    _disablePasswordController.dispose();
    _disableCodeController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  bool get _supportsQrLoginApproval =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _startQrLoginApproval() async {
    final scanned = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => const _QrLoginScannerDialog(),
    );
    if (!mounted || scanned == null || scanned.trim().isEmpty) {
      return;
    }

    final payload = QrLoginScanPayload.tryParse(scanned);
    if (payload == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That QR code is not a NeoAgent login request.'),
        ),
      );
      return;
    }

    final scannedBackend = widget.controller._normalizeBackendUrl(
      payload.backendUrl,
    );
    final currentBackend = widget.controller._normalizeBackendUrl(
      widget.controller.backendUrl,
    );
    if (scannedBackend != currentBackend) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This code belongs to a different NeoAgent server: ${payload.backendUrl}',
          ),
        ),
      );
      return;
    }

    try {
      final preview = await widget.controller.resolveQrLoginApproval(payload);
      if (!mounted) return;
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return _QrLoginApprovalDialog(
            preview: preview,
            busy: widget.controller.isApprovingQrLogin,
          );
        },
      );
      if (approved != true || !mounted) {
        return;
      }
      await widget.controller.approveQrLogin(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Approved login for ${preview.requestedDevice.label}.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      final message =
          widget.controller.errorMessage ?? 'Could not approve QR login.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 860;
    final showTabSwitcher = widget.initialTab == null;
    return ListView(
      padding: widget.embedded ? EdgeInsets.zero : _pagePadding(context),
      children: <Widget>[
        if (!widget.embedded)
          _PageTitle(
            title: 'Account settings',
            subtitle:
                'Manage your account email, two-factor authentication, and active sessions.',
            trailing: _refreshButton(),
          )
        else
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _refreshButton(),
            ),
          ),
        if (widget.controller.errorMessage != null) ...<Widget>[
          _InlineError(message: widget.controller.errorMessage!),
          const SizedBox(height: 16),
        ],
        if (showTabSwitcher && compact)
          _AccountSettingsTabs(
            selected: _selectedTab,
            onSelected: (value) => setState(() => _selectedTab = value),
          )
        else
          const SizedBox.shrink(),
        if (showTabSwitcher && compact) const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: !showTabSwitcher
                ? _buildSelectedPanel()
                : compact
                ? _buildSelectedPanel()
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 220,
                        child: _AccountSettingsTabs(
                          selected: _selectedTab,
                          onSelected: (value) =>
                              setState(() => _selectedTab = value),
                          vertical: true,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(child: _buildSelectedPanel()),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedPanel() {
    switch (_selectedTab) {
      case AccountSettingsTab.account:
        return _buildAccountPanel();
      case AccountSettingsTab.usage:
        return _buildUsagePanel();
      case AccountSettingsTab.security:
        return _buildSecurityPanel();
    }
  }

  Widget _refreshButton() {
    return OutlinedButton.icon(
      onPressed: widget.controller.isLoadingAccountSettings
          ? null
          : widget.controller.refreshAccountSettings,
      icon: widget.controller.isLoadingAccountSettings
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.refresh),
      label: Text('Refresh'),
    );
  }

  Widget _buildAccountPanel() {
    final controller = widget.controller;
    final username = controller.user?['username']?.toString() ?? 'Account';
    final currentEmail =
        controller.user?['email']?.toString() ?? 'No email linked';
    final hasPassword = controller.user?['hasPassword'] == true;
    final availableProviders = controller.authProviders
        .where((provider) => provider.configured)
        .toList();
    final linkedProviderKeys = controller.linkedAuthProviders
        .map((provider) => provider.provider)
        .toSet();
    final linkableProviders = availableProviders
        .where((provider) => !linkedProviderKeys.contains(provider.id))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionTitle('Account'),
        const SizedBox(height: 12),
        _MetaPill(label: username, icon: Icons.person_outline),
        const SizedBox(height: 18),
        TextField(
          controller: _displayNameController,
          decoration: const InputDecoration(
            labelText: 'Display name',
            helperText: 'Shown in the sidebar. Leave blank to use your username.',
          ),
        ),
        if (_displayNameInlineError != null) ...<Widget>[
          const SizedBox(height: 10),
          _InlineError(message: _displayNameInlineError!),
        ],
        if (_displayNameSuccessMessage != null) ...<Widget>[
          const SizedBox(height: 10),
          _InlineSuccess(message: _displayNameSuccessMessage!),
        ],
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: controller.isSavingAccountSettings
              ? null
              : () async {
                  setState(() {
                    _displayNameInlineError = null;
                    _displayNameSuccessMessage = null;
                  });
                  final trimmed = _displayNameController.text.trim();
                  if (trimmed.length > 64) {
                    setState(() {
                      _displayNameInlineError =
                          'Display name must be 64 characters or fewer.';
                    });
                    return;
                  }
                  final saved = await controller.updateAccountDisplayName(
                    displayName: trimmed,
                  );
                  if (saved && mounted) {
                    setState(() {
                      _displayNameSuccessMessage = 'Display name saved.';
                    });
                  }
                },
          icon: controller.isSavingAccountSettings
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.save_outlined),
          label: Text('Save name'),
        ),
        const SizedBox(height: 22),
        Text('Current email: $currentEmail'),
        const SizedBox(height: 16),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailPasswordController,
          obscureText: true,
          enabled: hasPassword,
          decoration: InputDecoration(
            labelText: 'Current password',
            helperText: hasPassword
                ? 'Required to add or change your account email.'
                : 'Create a password first to change your account email.',
          ),
        ),
        if (_emailInlineError != null) ...<Widget>[
          const SizedBox(height: 10),
          _InlineError(message: _emailInlineError!),
        ],
        if (_emailSuccessMessage != null) ...<Widget>[
          const SizedBox(height: 10),
          _InlineSuccess(message: _emailSuccessMessage!),
        ],
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: controller.isSavingAccountSettings || !hasPassword
              ? null
              : () async {
                  setState(() {
                    _emailInlineError = null;
                    _emailSuccessMessage = null;
                  });
                  if (_emailPasswordController.text.trim().isEmpty) {
                    setState(() {
                      _emailInlineError =
                          'Enter your current password to save email changes.';
                    });
                    return;
                  }
                  final trimmedEmail = _emailController.text.trim();
                  final saved = await controller.updateAccountEmail(
                    email: trimmedEmail,
                    currentPassword: _emailPasswordController.text,
                  );
                  if (saved && mounted) {
                    setState(() {
                      _emailPasswordController.clear();
                      _emailSuccessMessage =
                          'Email saved. If confirmation is required, check the new address for a NeoAgent confirmation link.';
                    });
                  }
                },
          icon: controller.isSavingAccountSettings
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.save_outlined),
          label: Text('Save email'),
        ),
        const SizedBox(height: 28),
        Row(
          children: <Widget>[
            const Expanded(child: _SectionTitle('Linked sign-in providers')),
            if (controller.linkedAuthProviders.isNotEmpty)
              Text(
                '${controller.linkedAuthProviders.length} linked',
                style: TextStyle(color: _textSecondary),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (controller.linkedAuthProviders.isEmpty)
          Text(
            'No external sign-in providers linked.',
            style: TextStyle(color: _textSecondary),
          )
        else
          ...controller.linkedAuthProviders.map(
            (provider) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: provider.icon == 'google'
                    ? const CircleAvatar(
                        backgroundColor: Color(0x1A4285F4),
                        child: Text(
                          'G',
                          style: TextStyle(
                            color: Color(0xFF4285F4),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : const CircleAvatar(child: Icon(Icons.link)),
                title: Text(provider.label),
                subtitle: Text(
                  provider.email.isNotEmpty
                      ? '${provider.email}\nLast used: ${provider.lastUsedLabel}'
                      : 'Last used: ${provider.lastUsedLabel}',
                ),
                isThreeLine: provider.email.isNotEmpty,
                trailing: TextButton(
                  onPressed:
                      controller.isSavingAccountSettings || !provider.canUnlink
                      ? null
                      : () => controller.unlinkAccountProvider(provider.id),
                  child: const Text('Unlink'),
                ),
              ),
            ),
          ),
        if (linkableProviders.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: linkableProviders
                .map(
                  (provider) => OutlinedButton.icon(
                    onPressed: controller.isSavingAccountSettings
                        ? null
                        : () => controller.linkAccountProvider(provider.id),
                    icon: provider.icon == 'google'
                        ? const Text(
                            'G',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4285F4),
                            ),
                          )
                        : const Icon(Icons.link),
                    label: Text('Link ${provider.label}'),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  String _formatTokens(int amount) {
    if (amount >= 1000000) {
      final value = amount / 1000000;
      return '${value == value.truncateToDouble() ? value.toInt() : value.toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      final value = amount / 1000;
      return '${value == value.truncateToDouble() ? value.toInt() : value.toStringAsFixed(1)}k';
    }
    return amount.toString();
  }

  Widget _buildUsagePanel() {
    if (widget.controller.isLoadingAccountSettings) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    final usage = widget.controller.usageAndLimits;
    if (usage == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.error_outline, size: 48, color: _textSecondary),
              const SizedBox(height: 16),
              const Text('Could not load usage data.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: widget.controller.refreshAccountSettings,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildStatBox(String label, int current, int? limit, {bool isCustom = false}) {
      final double progress = limit != null
          ? (limit <= 0 ? 1.0 : (current / limit).clamp(0.0, 1.0))
          : 0.0;
      final bool nearLimit = progress > 0.8;
      final bool atLimit = progress >= 1.0;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _bgSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: atLimit
                ? _danger.withValues(alpha: 0.6)
                : nearLimit
                    ? _warning.withValues(alpha: 0.5)
                    : _borderLight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (limit != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isCustom
                          ? _warning.withValues(alpha: 0.12)
                          : _accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isCustom ? 'custom' : 'default',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isCustom ? _warning : _accent,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  _formatTokens(current),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: atLimit ? _danger : nearLimit ? _warning : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    ' tokens used',
                    style: TextStyle(color: _textSecondary, fontSize: 14),
                  ),
                ),
                const Spacer(),
                if (limit != null)
                  Text(
                    'of ${_formatTokens(limit)}',
                    style: TextStyle(color: _textMuted, fontSize: 13),
                  )
                else
                  Text(
                    'No limit',
                    style: TextStyle(color: _textMuted, fontSize: 13),
                  ),
              ],
            ),
            if (limit != null) ...<Widget>[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: progress,
                  backgroundColor: _border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    atLimit ? _danger : nearLimit ? _warning : _accent,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${(progress * 100).toStringAsFixed(0)}% used',
                style: TextStyle(
                  fontSize: 11,
                  color: atLimit ? _danger : nearLimit ? _warning : _textMuted,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionTitle('Usage & Limits'),
        const SizedBox(height: 12),
        Text(
          'Keep track of your AI usage. Limits are enforced to ensure fair usage across the platform.',
          style: TextStyle(color: _textSecondary, height: 1.4),
        ),
        const SizedBox(height: 24),
        buildStatBox('Recent Usage (4 Hours)', usage.fourHourUsage, usage.fourHourLimit, isCustom: usage.fourHourIsCustom),
        const SizedBox(height: 16),
        buildStatBox('Weekly Usage', usage.weeklyUsage, usage.weeklyLimit, isCustom: usage.weeklyIsCustom),
      ],
    );
  }

  Widget _buildSecurityPanel() {
    final controller = widget.controller;
    final twoFactorEnabled = controller.accountTwoFactor['enabled'] == true;
    final recoveryCount = _asInt(
      controller.accountTwoFactor['recoveryCodesRemaining'],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_supportsQrLoginApproval) ...<Widget>[
          Row(
            children: <Widget>[
              const Expanded(child: _SectionTitle('Approve QR login')),
              _StatusPill(label: 'Android only', color: _accent),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Scan QR login requests from signed-out devices and approve them from this authenticated mobile session.',
            style: TextStyle(color: _textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  _accent.withValues(alpha: 0.16),
                  _success.withValues(alpha: 0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _borderLight),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: controller.isApprovingQrLogin
                      ? null
                      : _startQrLoginApproval,
                  icon: controller.isApprovingQrLogin
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt_outlined),
                  label: const Text('Scan login QR'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        _buildPasswordPanel(),
        const SizedBox(height: 24),
        Row(
          children: <Widget>[
            Expanded(child: _SectionTitle('Two-factor authentication')),
            _StatusPill(
              label: twoFactorEnabled ? 'Enabled' : 'Disabled',
              color: twoFactorEnabled ? _success : _warning,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          twoFactorEnabled
              ? '$recoveryCount recovery codes are still available.'
              : 'Use an authenticator app such as Authy, 1Password, or Google Authenticator.',
          style: TextStyle(color: _textSecondary, height: 1.4),
        ),
        const SizedBox(height: 16),
        if (!twoFactorEnabled) _buildEnableTwoFactorPanel(),
        if (twoFactorEnabled) _buildDisableTwoFactorPanel(),
        if (_recoveryCodes.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          _RecoveryCodesCard(codes: _recoveryCodes),
        ],
        const SizedBox(height: 24),
        Row(
          children: <Widget>[
            Expanded(child: _SectionTitle('Active sessions')),
            Text(
              '${controller.accountSessions.length} active',
              style: TextStyle(color: _textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (controller.accountSessions.isEmpty)
          Text(
            'No active sessions found.',
            style: TextStyle(color: _textSecondary),
          )
        else
          ...controller.accountSessions.map(
            (session) => _AccountSessionCard(
              session: session,
              busy: controller.isRevokingSession,
              onRevoke: session.current
                  ? null
                  : () => controller.revokeAccountSession(session.id),
            ),
          ),
      ],
    );
  }

  Widget _buildPasswordPanel() {
    final controller = widget.controller;
    final hasPassword = controller.user?['hasPassword'] == true;
    final strength = _passwordStrengthInfo(
      password: _newPasswordController.text,
      username: controller.user?['username']?.toString() ?? '',
      email: controller.user?['email']?.toString() ?? '',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionTitle('Password'),
        const SizedBox(height: 12),
        if (hasPassword) ...<Widget>[
          TextField(
            controller: _currentPasswordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current password'),
          ),
          const SizedBox(height: 12),
        ] else ...<Widget>[
          Text(
            'No local password is set yet. Create one to enable username/password sign-in.',
            style: TextStyle(color: _textSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _newPasswordController,
          onChanged: (_) => setState(() {}),
          obscureText: true,
          decoration: InputDecoration(
            labelText: hasPassword ? 'New password' : 'Create password',
          ),
        ),
        const SizedBox(height: 10),
        _PasswordStrengthIndicator(info: strength),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmNewPasswordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: hasPassword
                ? 'Confirm new password'
                : 'Confirm password',
          ),
        ),
        if (_passwordInlineError != null) ...<Widget>[
          const SizedBox(height: 10),
          _InlineError(message: _passwordInlineError!),
        ],
        if (_passwordSuccessMessage != null) ...<Widget>[
          const SizedBox(height: 10),
          _InlineSuccess(message: _passwordSuccessMessage!),
        ],
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: controller.isSavingAccountSettings
              ? null
              : () async {
                  setState(() {
                    _passwordInlineError = null;
                    _passwordSuccessMessage = null;
                  });
                  if (hasPassword && _currentPasswordController.text.isEmpty) {
                    setState(() {
                      _passwordInlineError =
                          'Enter your current password to change it.';
                    });
                    return;
                  }
                  if (_newPasswordController.text.length < 8) {
                    setState(() {
                      _passwordInlineError =
                          'Use a new password with at least 8 characters.';
                    });
                    return;
                  }
                  if (_newPasswordController.text !=
                      _confirmNewPasswordController.text) {
                    setState(() {
                      _passwordInlineError = 'New passwords do not match.';
                    });
                    return;
                  }
                  final saved = await controller.updateAccountPassword(
                    currentPassword: _currentPasswordController.text,
                    newPassword: _newPasswordController.text,
                  );
                  if (saved && mounted) {
                    setState(() {
                      _currentPasswordController.clear();
                      _newPasswordController.clear();
                      _confirmNewPasswordController.clear();
                      _passwordSuccessMessage = hasPassword
                          ? 'Password changed.'
                          : 'Password created.';
                    });
                  }
                },
          icon: controller.isSavingAccountSettings
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.password_outlined),
          label: Text(hasPassword ? 'Change password' : 'Create password'),
        ),
      ],
    );
  }

  Widget _buildEnableTwoFactorPanel() {
    final setupUrl = _pendingSetup?['otpauthUrl']?.toString() ?? '';
    final manualKey = _pendingSetup?['manualKey']?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_pendingSetup == null) ...<Widget>[
          TextField(
            controller: _setupPasswordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current password'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: widget.controller.isConfiguringTwoFactor
                ? null
                : () async {
                    final setup = await widget.controller.beginTwoFactorSetup(
                      _setupPasswordController.text,
                    );
                    if (setup != null && mounted) {
                      setState(() => _pendingSetup = setup);
                    }
                  },
            icon: Icon(Icons.qr_code_2_outlined),
            label: Text('Start setup'),
          ),
        ] else ...<Widget>[
          Center(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: QrImageView(
                data: setupUrl,
                version: QrVersions.auto,
                size: 220,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(manualKey, style: TextStyle(color: _textSecondary)),
          const SizedBox(height: 12),
          TextField(
            controller: _setupCodeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Authenticator code'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: widget.controller.isConfiguringTwoFactor
                ? null
                : () async {
                    final codes = await widget.controller.enableTwoFactor(
                      _setupCodeController.text,
                    );
                    if (codes.isNotEmpty && mounted) {
                      setState(() {
                        _recoveryCodes = codes;
                        _pendingSetup = null;
                        _setupPasswordController.clear();
                        _setupCodeController.clear();
                      });
                    }
                  },
            icon: Icon(Icons.verified_user_outlined),
            label: Text('Enable 2FA'),
          ),
        ],
      ],
    );
  }

  Widget _buildDisableTwoFactorPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: _disablePasswordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Current password'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _disableCodeController,
          decoration: const InputDecoration(labelText: '2FA or recovery code'),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            FilledButton.icon(
              onPressed: widget.controller.isConfiguringTwoFactor
                  ? null
                  : () => widget.controller.disableTwoFactor(
                      currentPassword: _disablePasswordController.text,
                      code: _disableCodeController.text,
                    ),
              icon: Icon(Icons.lock_open_outlined),
              label: Text('Disable 2FA'),
            ),
            OutlinedButton.icon(
              onPressed: widget.controller.isConfiguringTwoFactor
                  ? null
                  : () async {
                      final codes = await widget.controller
                          .regenerateRecoveryCodes(
                            currentPassword: _disablePasswordController.text,
                            code: _disableCodeController.text,
                          );
                      if (codes.isNotEmpty && mounted) {
                        setState(() => _recoveryCodes = codes);
                      }
                    },
              icon: Icon(Icons.password_outlined),
              label: Text('New recovery codes'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AccountSettingsTabs extends StatelessWidget {
  const _AccountSettingsTabs({
    required this.selected,
    required this.onSelected,
    this.vertical = false,
  });

  final AccountSettingsTab selected;
  final ValueChanged<AccountSettingsTab> onSelected;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      _tabButton(AccountSettingsTab.account, Icons.person_outline, 'Account'),
      _tabButton(AccountSettingsTab.usage, Icons.data_usage_outlined, 'Usage & Limits'),
      _tabButton(
        AccountSettingsTab.security,
        Icons.security_outlined,
        'Security',
      ),
    ];
    return vertical
        ? Column(children: buttons)
        : Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }

  Widget _tabButton(AccountSettingsTab tab, IconData icon, String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: vertical ? 8 : 0),
      child: _SidebarButton(
        label: label,
        icon: icon,
        active: selected == tab,
        onTap: () => onSelected(tab),
      ),
    );
  }
}

class _RecoveryCodesCard extends StatelessWidget {
  const _RecoveryCodesCard({required this.codes});

  final List<String> codes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Save these recovery codes now. They will not be shown again.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: codes
                .map(
                  (code) => SelectableText(
                    code,
                    style: TextStyle(fontFamily: 'monospace'),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: codes.join('\n'))),
            icon: Icon(Icons.copy_outlined),
            label: Text('Copy codes'),
          ),
        ],
      ),
    );
  }
}

class _AccountSessionCard extends StatelessWidget {
  const _AccountSessionCard({
    required this.session,
    required this.busy,
    required this.onRevoke,
  });

  final AccountSessionItem session;
  final bool busy;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            session.deviceIcon,
            color: session.current ? _success : _textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  session.current
                      ? '${session.clientLabel} · Current session'
                      : session.clientLabel,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    session.locationSummary,
                    'Last seen ${session.lastSeenLabel}',
                  ].join(' · '),
                  style: TextStyle(color: _textSecondary),
                ),
                if (session.userAgent.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    '${session.clientPlatformLabel} · ${session.clientBrowserLabel} · Created ${session.createdLabel}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _textMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          if (!session.current)
            TextButton(
              onPressed: busy ? null : onRevoke,
              child: Text('Revoke'),
            ),
        ],
      ),
    );
  }
}

class _QrLoginScannerDialog extends StatefulWidget {
  const _QrLoginScannerDialog();

  @override
  State<_QrLoginScannerDialog> createState() => _QrLoginScannerDialogState();
}

class _QrLoginScannerDialogState extends State<_QrLoginScannerDialog> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          MobileScanner(
            fit: BoxFit.cover,
            onDetect: (capture) {
              if (_handled) return;
              final raw = capture.barcodes
                  .map((barcode) => barcode.rawValue?.trim() ?? '')
                  .firstWhere((value) => value.isNotEmpty, orElse: () => '');
              if (raw.isEmpty) return;
              _handled = true;
              Navigator.of(context).pop(raw);
            },
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.black.withValues(alpha: 0.72),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.78),
                ],
                stops: const <double>[0, 0.42, 1],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Center(
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Scan a NeoAgent login QR',
                    style: GoogleFonts.geist(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Point the camera at the code shown on the signed-out device. Approval stays on this phone.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrLoginApprovalDialog extends StatelessWidget {
  const _QrLoginApprovalDialog({required this.preview, required this.busy});

  final QrLoginApprovalPreview preview;
  final bool busy;

  IconData get _deviceIcon => switch (preview.requestedDevice.deviceClass) {
    'mobile' => Icons.smartphone_rounded,
    'tablet' => Icons.tablet_mac_rounded,
    'desktop' => Icons.laptop_mac_rounded,
    'server' => Icons.dns_outlined,
    _ => Icons.devices_other_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final canApprove =
        preview.canApprove && !preview.isExpired && !preview.isClaimed;
    return AlertDialog(
      backgroundColor: _bgCard,
      title: const Text('Approve QR login'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _bgSecondary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(_deviceIcon, color: _accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          preview.requestedDevice.label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          [
                            preview.requestLocation.label,
                            if (preview.requestedAt != null)
                              'Requested ${_formatTimestamp(preview.requestedAt!)}',
                          ].join(' · '),
                          style: TextStyle(color: _textSecondary, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _MetaPill(
                  label: preview.requestedDevice.platformLabel,
                  icon: Icons.devices_outlined,
                ),
                _MetaPill(
                  label: preview.requestedDevice.browserLabel,
                  icon: Icons.language_outlined,
                ),
                if (preview.expiresAt != null)
                  _MetaPill(
                    label: 'Expires ${_formatTimestamp(preview.expiresAt!)}',
                    icon: Icons.timer_outlined,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              preview.isClaimed
                  ? 'This request has already been used.'
                  : preview.isExpired
                  ? 'This request has expired. Ask the other device to generate a new code.'
                  : 'Approve this only if you started the login on that device just now.',
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: !canApprove || busy
              ? null
              : () => Navigator.of(context).pop(true),
          icon: busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.verified_user_outlined),
          label: const Text('Approve login'),
        ),
      ],
    );
  }
}
