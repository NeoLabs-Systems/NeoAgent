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
      label: appStrings.empty,
      message: appStrings.use8CharactersLongerPassphrasesWork,
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
      label: appStrings.weak,
      message: appStrings.useAtLeast8Characters,
      color: _danger,
    );
  }
  if (evaluation.containsUserInfo) {
    return _PasswordStrengthInfo(
      score: 2,
      label: appStrings.fair,
      message: appStrings.doNotIncludeYourUsernameOr,
      color: _warning,
    );
  }
  if (evaluation.obviousPattern) {
    return _PasswordStrengthInfo(
      score: 2,
      label: appStrings.fair,
      message: appStrings.avoidRepeatedCharactersAndObviousSequences,
      color: _warning,
    );
  }
  if (score >= 4) {
    return _PasswordStrengthInfo(
      score: 4,
      label: appStrings.strong,
      message: appStrings.strongPassword,
      color: _success,
    );
  }
  if (score >= 3) {
    return _PasswordStrengthInfo(
      score: 3,
      label: appStrings.good,
      message: appStrings.goodPasswordALittleMoreLength,
      color: _success,
    );
  }
  return _PasswordStrengthInfo(
    score: 2,
    label: appStrings.fair,
    message: appStrings.addMoreLengthOrAnotherCharacter,
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
            Flexible(
              child: Text(
                appStrings.passwordStrengthArg1(info.label),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: info.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
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

/// The account pages of Settings: Profile, Sign-in & security, and Plan &
/// usage. One state backs all three, so a half-typed form survives switching
/// between them.
class AccountSettingsPanel extends StatefulWidget {
  const AccountSettingsPanel({
    super.key,
    required this.controller,
    required this.page,
  });

  final NeoAgentController controller;
  final SettingsPage page;

  @override
  State<AccountSettingsPanel> createState() => _AccountSettingsPanelState();
}

class _AccountSettingsPanelState extends State<AccountSettingsPanel> {
  late final TextEditingController _emailController;
  late final TextEditingController _emailPasswordController;
  late final TextEditingController _setupPasswordController;
  late final TextEditingController _setupCodeController;
  late final TextEditingController _disablePasswordController;
  late final TextEditingController _disableCodeController;
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmNewPasswordController;
  late final TextEditingController _securityKeyLabelController;
  Map<String, dynamic>? _pendingSetup;
  List<String> _recoveryCodes = const <String>[];
  String? _displayNameInlineError;
  String? _emailSuccessMessage;
  String? _emailInlineError;
  String? _passwordSuccessMessage;
  String? _passwordInlineError;
  bool _isExportingData = false;
  bool _isDeletingAccount = false;

  @override
  void initState() {
    super.initState();
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
    _securityKeyLabelController = TextEditingController();
    unawaited(widget.controller.refreshAccountSettings());
  }

  @override
  void didUpdateWidget(covariant AccountSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final email = widget.controller.user?['email']?.toString() ?? '';
    if (_emailController.text.isEmpty && email.isNotEmpty) {
      _emailController.text = email;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailPasswordController.dispose();
    _setupPasswordController.dispose();
    _setupCodeController.dispose();
    _disablePasswordController.dispose();
    _disableCodeController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    _securityKeyLabelController.dispose();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(appStrings.thatQrCodeIsNotA)));
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
            appStrings.thisCodeBelongsToADifferent(payload.backendUrl),
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
          content: Text(
            appStrings.approvedLoginForArg1(preview.requestedDevice.label),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      final message =
          widget.controller.errorMessage ?? appStrings.couldNotApproveQrLogin;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.page) {
      case SettingsPage.security:
        return _buildSecurityPage();
      case SettingsPage.usage:
        return _buildUsagePage();
      default:
        return _buildProfilePage();
    }
  }

  Widget _buildProfilePage() {
    final controller = widget.controller;
    final username =
        controller.user?['username']?.toString() ?? appStrings.account;
    final currentEmail =
        controller.user?['email']?.toString() ?? appStrings.noEmailLinked;
    final hasPassword = controller.user?['hasPassword'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SettingsGroup(
          title: appStrings.settingsPageProfile,
          children: <Widget>[
            _SettingsRow(
              label: appStrings.username,
              description: appStrings.settingsUsernameDescription,
              control: Text(
                '@$username',
                style: GoogleFonts.geistMono(
                  fontSize: 13.5,
                  color: _textPrimary,
                ),
              ),
            ),
            _SettingsRow(
              anchor: 'displayName',
              label: appStrings.displayName,
              description:
                  _displayNameInlineError ??
                  appStrings.shownInTheSidebarLeaveBlank,
              fillControl: true,
              control: _AutosaveTextField(
                value: controller.user?['display_name']?.toString() ?? '',
                maxLength: 64,
                onSave: (name) async {
                  setState(() => _displayNameInlineError = null);
                  final saved = await controller.updateAccountDisplayName(
                    displayName: name.trim(),
                  );
                  if (!saved && mounted) {
                    setState(
                      () => _displayNameInlineError =
                          controller.errorMessage ??
                          appStrings.displayNameMustBe64Characters,
                    );
                  }
                },
              ),
            ),
            _SettingsBlock(
              anchor: 'email',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    appStrings.email,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    appStrings.currentEmailArg1(currentEmail),
                    style: TextStyle(fontSize: 13, color: _textSecondary),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(labelText: appStrings.email),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailPasswordController,
                    obscureText: true,
                    enabled: hasPassword,
                    decoration: InputDecoration(
                      labelText: appStrings.currentPassword,
                      helperText: hasPassword
                          ? appStrings.requiredToAddOrChangeYourAccount
                          : appStrings.createAPasswordFirstToChange,
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed:
                          controller.isSavingAccountSettings || !hasPassword
                          ? null
                          : _saveEmail,
                      child: Text(appStrings.saveEmail),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        _SettingsGroup(
          title: appStrings.yourData,
          children: <Widget>[
            _SettingsRow(
              anchor: 'exportData',
              label: appStrings.exportMyData,
              description: controller.isAdmin
                  ? appStrings.downloadACopyOfYourData +
                        appStrings.themselvesTheServerOperatorRemovesAdmin +
                        '`neoagent admin revoke <username>`.'
                  : appStrings.downloadACopyOfYourData2 +
                        appStrings.deletionRemovesAllYourConversationsMemories +
                        appStrings.settingsAndCannotBeUndone,
              control: OutlinedButton.icon(
                onPressed: _isExportingData ? null : _exportMyData,
                icon: _isExportingData
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.download_outlined, size: 18),
                label: Text(appStrings.settingsExport),
              ),
            ),
          ],
        ),
        _SettingsGroup(
          title: appStrings.settingsLeave,
          children: <Widget>[
            _SettingsRow(
              anchor: 'signOut',
              label: appStrings.signOut,
              description: appStrings.settingsSignOutDescription,
              control: OutlinedButton.icon(
                onPressed: controller.logout,
                icon: Icon(Icons.logout, size: 18),
                label: Text(appStrings.signOut),
              ),
            ),
            _SettingsRow(
              anchor: 'deleteAccount',
              label: appStrings.deleteAccount,
              description: appStrings.settingsDeleteAccountDescription,
              control: OutlinedButton.icon(
                onPressed: _isDeletingAccount || controller.isAdmin
                    ? null
                    : _confirmDeleteAccount,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _danger,
                  side: BorderSide(color: _danger.withValues(alpha: 0.6)),
                ),
                icon: _isDeletingAccount
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.delete_forever_outlined, size: 18),
                label: Text(appStrings.deleteAccount),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveEmail() async {
    setState(() {
      _emailInlineError = null;
      _emailSuccessMessage = null;
    });
    if (_emailPasswordController.text.trim().isEmpty) {
      setState(() {
        _emailInlineError = appStrings.enterYourCurrentPasswordToSave;
      });
      return;
    }
    final saved = await widget.controller.updateAccountEmail(
      email: _emailController.text.trim(),
      currentPassword: _emailPasswordController.text,
    );
    if (saved && mounted) {
      setState(() {
        _emailPasswordController.clear();
        _emailSuccessMessage = appStrings.emailSavedIfConfirmationIsRequired;
      });
    }
  }

  Future<void> _exportMyData() async {
    setState(() => _isExportingData = true);
    try {
      final export = await widget.controller.backendClient.exportMyData(
        widget.controller.backendUrl,
      );
      final pretty = const JsonEncoder.withIndent('  ').convert(export);
      await Clipboard.setData(ClipboardData(text: pretty));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appStrings.yourDataExportWasCopiedTo)),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appStrings.couldNotExportYourDataArg1(_formatCaughtError(err)),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isExportingData = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final username = widget.controller.user?['username']?.toString() ?? '';
    final confirmController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final matches = confirmController.text.trim() == username;
            return AlertDialog(
              title: Text(appStrings.deleteAccountPermanently),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    appStrings.thisPermanentlyErasesAllOfYour +
                        appStrings.undoneTypeYourUsernameToConfirm,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: confirmController,
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: appStrings.username,
                      hintText: username,
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(appStrings.cancel),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _danger),
                  onPressed: matches
                      ? () => Navigator.of(dialogContext).pop(true)
                      : null,
                  child: Text(appStrings.deleteForever),
                ),
              ],
            );
          },
        );
      },
    );
    confirmController.dispose();
    if (confirmed != true) return;

    setState(() => _isDeletingAccount = true);
    try {
      await widget.controller.backendClient.deleteMyAccount(
        baseUrl: widget.controller.backendUrl,
        confirmUsername: username,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appStrings.yourAccountHasBeenDeleted)),
      );
      await widget.controller.logout();
    } catch (err) {
      if (!mounted) return;
      setState(() => _isDeletingAccount = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appStrings.couldNotDeleteYourAccountArg1(_formatCaughtError(err)),
          ),
        ),
      );
    }
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
              Text(appStrings.couldNotLoadUsageData),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: widget.controller.refreshAccountSettings,
                child: Text(appStrings.retry),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildStatBox(
      String label,
      int current,
      int? limit, {
      required int remaining,
      required bool reached,
      required DateTime? recoversAt,
      required DateTime? fullResetAt,
      bool isCustom = false,
    }) {
      final double progress = limit != null
          ? (limit <= 0 ? 1.0 : (current / limit).clamp(0.0, 1.0))
          : 0.0;
      final bool nearLimit = progress > 0.8;
      final bool atLimit = reached || progress >= 1.0;
      final resetLabel = _usageWindowResetLabel(
        reached: atLimit,
        recoversAt: recoversAt,
        fullResetAt: fullResetAt,
      );

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
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (limit != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
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
                  _formatTokenCount(current),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: atLimit
                        ? _danger
                        : nearLimit
                        ? _warning
                        : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    appStrings.tokensUsed,
                    style: TextStyle(color: _textSecondary, fontSize: 14),
                  ),
                ),
                const Spacer(),
                if (limit != null)
                  Text(
                    appStrings.ofArg1(_formatTokenCount(limit)),
                    style: TextStyle(color: _textMuted, fontSize: 13),
                  )
                else
                  Text(
                    appStrings.noLimit,
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
                    atLimit
                        ? _danger
                        : nearLimit
                        ? _warning
                        : _accent,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                atLimit
                    ? appStrings.limitReachedArg1(
                        resetLabel == null ? '' : ' · $resetLabel',
                      )
                    : appStrings.arg1UsedArg2Remaining(
                            (progress * 100).toStringAsFixed(0),
                            _formatTokenCount(remaining),
                          ) +
                          '${resetLabel == null ? '' : ' · $resetLabel'}',
                style: TextStyle(
                  fontSize: 11,
                  color: atLimit
                      ? _danger
                      : nearLimit
                      ? _warning
                      : _textMuted,
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
        buildStatBox(
          appStrings.recentUsage4Hours,
          usage.fourHourUsage,
          usage.fourHourLimit,
          remaining: usage.fourHourRemaining,
          reached: usage.fourHourReached,
          recoversAt: usage.fourHourRecoversAt,
          fullResetAt: usage.fourHourFullResetAt,
          isCustom: usage.fourHourIsCustom,
        ),
        const SizedBox(height: 16),
        buildStatBox(
          appStrings.weeklyUsage,
          usage.weeklyUsage,
          usage.weeklyLimit,
          remaining: usage.weeklyRemaining,
          reached: usage.weeklyReached,
          recoversAt: usage.weeklyRecoversAt,
          fullResetAt: usage.weeklyFullResetAt,
          isCustom: usage.weeklyIsCustom,
        ),
      ],
    );
  }

  Widget _buildUsagePage() {
    final controller = widget.controller;
    final tokenUsage = controller.tokenUsage;
    final lineStyle = TextStyle(color: _textPrimary, height: 1.4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SettingsGroup(
          anchor: 'limits',
          title: appStrings.usageLimits2,
          description: appStrings.keepTrackOfYourAiUsage,
          children: <Widget>[_SettingsBlock(child: _buildUsagePanel())],
        ),
        _SettingsGroup(
          anchor: 'tokenUsage',
          title: appStrings.settingsTokenUsage,
          description: appStrings.usageAndHealthSignalsThatHelp,
          children: <Widget>[
            _SettingsBlock(
              child: tokenUsage == null
                  ? Text(
                      appStrings.tokenUsageUnavailableOnThisServer,
                      style: TextStyle(color: _textSecondary),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          appStrings.totalArg1TokensAcrossArg2Runs(
                            tokenUsage.totalTokensLabel,
                            tokenUsage.totalRunsLabel,
                          ),
                          style: lineStyle,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          appStrings.last7DaysArg1TokensIn(
                            tokenUsage.last7DaysTokensLabel,
                            tokenUsage.last7DaysRunsLabel,
                          ),
                          style: lineStyle,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          appStrings.avgRunArg1Tokens(
                            tokenUsage.avgTokensPerRunLabel,
                          ),
                          style: lineStyle,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          appStrings.promptCacheArg1CachedTokens(
                                tokenUsage.cachedReadTokensLabel,
                              ) +
                              appStrings.arg1HitRatio(
                                tokenUsage.cacheHitRatioLabel,
                              ),
                          style: lineStyle,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          appStrings.measuredModelCostArg1(
                            tokenUsage.estimatedCostLabel,
                          ),
                          style: lineStyle,
                        ),
                      ],
                    ),
            ),
          ],
        ),
        if (controller.showBillingSection) BillingPanel(controller: controller),
      ],
    );
  }

  Widget _buildSecurityPage() {
    final controller = widget.controller;
    final twoFactorEnabled = controller.accountTwoFactor['enabled'] == true;
    final recoveryCount = _asInt(
      controller.accountTwoFactor['recoveryCodesRemaining'],
    );
    final keys = controller.accountSecurityKeys;
    final linkedProviderKeys = controller.linkedAuthProviders
        .map((provider) => provider.provider)
        .toSet();
    final linkableProviders = controller.authProviders
        .where(
          (provider) =>
              provider.configured && !linkedProviderKeys.contains(provider.id),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_supportsQrLoginApproval)
          _SettingsGroup(
            title: appStrings.approveQrLogin,
            children: <Widget>[
              _SettingsRow(
                anchor: 'qrLogin',
                label: appStrings.scanLoginQr,
                description: appStrings.scanQrLoginRequestsFromSigned,
                control: FilledButton.icon(
                  onPressed: controller.isApprovingQrLogin
                      ? null
                      : _startQrLoginApproval,
                  icon: controller.isApprovingQrLogin
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.camera_alt_outlined, size: 18),
                  label: Text(appStrings.scanLoginQr),
                ),
              ),
            ],
          ),
        _SettingsGroup(
          anchor: 'password',
          title: appStrings.password,
          children: <Widget>[_SettingsBlock(child: _buildPasswordPanel())],
        ),
        _SettingsGroup(
          anchor: 'twoFactor',
          title: appStrings.twoFactorAuthentication,
          description: twoFactorEnabled
              ? appStrings.arg1RecoveryCodesAreStillAvailable(recoveryCount)
              : appStrings.useAnAuthenticatorAppSuchAs,
          trailing: _StatusPill(
            label: twoFactorEnabled ? 'Enabled' : 'Disabled',
            color: twoFactorEnabled ? _success : _warning,
          ),
          children: <Widget>[
            _SettingsBlock(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (twoFactorEnabled)
                    _buildDisableTwoFactorPanel()
                  else
                    _buildEnableTwoFactorPanel(),
                  if (_recoveryCodes.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    _RecoveryCodesCard(codes: _recoveryCodes),
                  ],
                ],
              ),
            ),
          ],
        ),
        _SettingsGroup(
          anchor: 'securityKeys',
          title: appStrings.securityKeys,
          description:
              appStrings.signInWithAHardwareKey + appStrings.aKeyThatAsksForA,
          trailing: _StatusPill(
            label: keys.isEmpty
                ? 'None'
                : appStrings.arg1Registered(keys.length),
            color: keys.isEmpty ? _warning : _success,
          ),
          children: <Widget>[
            for (final key in keys)
              _SecurityKeyCard(
                securityKey: key,
                busy: controller.isConfiguringTwoFactor,
                onRename: () => _renameSecurityKey(key),
                onRemove: () => controller.removeSecurityKey(key.id),
              ),
            _SettingsBlock(child: _buildAddSecurityKey()),
          ],
        ),
        _SettingsGroup(
          anchor: 'linkedProviders',
          title: appStrings.linkedSignInProviders,
          children: <Widget>[
            if (controller.linkedAuthProviders.isEmpty)
              _SettingsBlock(
                child: Text(
                  appStrings.noExternalSignInProvidersLinked,
                  style: TextStyle(color: _textSecondary),
                ),
              ),
            for (final provider in controller.linkedAuthProviders)
              _SettingsRow(
                label: provider.label,
                description: provider.email.isNotEmpty
                    ? appStrings.arg1LastUsedArg2(
                        provider.email,
                        provider.lastUsedLabel,
                      )
                    : appStrings.lastUsedArg1(provider.lastUsedLabel),
                control: TextButton(
                  onPressed:
                      controller.isSavingAccountSettings || !provider.canUnlink
                      ? null
                      : () => controller.unlinkAccountProvider(provider.id),
                  child: Text(appStrings.unlink),
                ),
              ),
            if (linkableProviders.isNotEmpty)
              _SettingsBlock(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    for (final provider in linkableProviders)
                      OutlinedButton.icon(
                        onPressed: controller.isSavingAccountSettings
                            ? null
                            : () => controller.linkAccountProvider(provider.id),
                        icon: Icon(Icons.link, size: 18),
                        label: Text(appStrings.linkArg1(provider.label)),
                      ),
                  ],
                ),
              ),
          ],
        ),
        _SettingsGroup(
          anchor: 'sessions',
          title: appStrings.activeSessions,
          trailing: Text(
            appStrings.arg1Active(controller.accountSessions.length),
            style: TextStyle(color: _textSecondary),
          ),
          children: <Widget>[
            if (controller.accountSessions.isEmpty)
              _SettingsBlock(
                child: Text(
                  appStrings.noActiveSessionsFound,
                  style: TextStyle(color: _textSecondary),
                ),
              ),
            for (final session in controller.accountSessions)
              _AccountSessionCard(
                session: session,
                busy: controller.isRevokingSession,
                onRevoke: session.current
                    ? null
                    : () => controller.revokeAccountSession(session.id),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _addSecurityKey() async {
    final controller = widget.controller;
    final label = _securityKeyLabelController.text.trim();
    await controller.registerSecurityKey(
      label: label.isEmpty
          ? appStrings.securityKeyArg1(
              controller.accountSecurityKeys.length + 1,
            )
          : label,
    );
    if (!mounted) return;
    _securityKeyLabelController.clear();
    setState(() {});
  }

  Future<void> _renameSecurityKey(SecurityKeyItem key) async {
    final renameController = TextEditingController(text: key.label);
    final nextLabel = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(appStrings.renameSecurityKey),
        content: TextField(
          controller: renameController,
          autofocus: true,
          decoration: InputDecoration(labelText: appStrings.name),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(appStrings.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(renameController.text.trim()),
            child: Text(appStrings.save),
          ),
        ],
      ),
    );
    renameController.dispose();
    if (nextLabel == null || nextLabel.isEmpty) return;
    await widget.controller.renameSecurityKey(id: key.id, label: nextLabel);
  }

  /// Adding a key needs an authenticator this device can talk to. Keys
  /// registered elsewhere stay listed and manageable either way.
  Widget _buildAddSecurityKey() {
    final controller = widget.controller;
    if (!controller.supportsSecurityKeys) {
      return Text(
        appStrings.thisDeviceCannotRegisterSecurityKeys,
        style: TextStyle(color: _textSecondary, height: 1.4),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final nameField = TextField(
          controller: _securityKeyLabelController,
          decoration: InputDecoration(
            labelText: appStrings.nameOptional,
            hintText: appStrings.yubikeyMacbookTouchId,
          ),
        );
        // Side by side the button leaves the name field unusably narrow
        // below this width, so the two stack instead.
        final stacked = constraints.maxWidth < 520;
        final addButton = FilledButton.icon(
          onPressed: controller.isConfiguringTwoFactor ? null : _addSecurityKey,
          icon: controller.isConfiguringTwoFactor
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.key),
          label: Text(appStrings.addSecurityKey),
          style: FilledButton.styleFrom(
            // Size.fromHeight also pins the width to infinity, which is
            // what a full-width stacked button wants and what would
            // starve the name field beside it in a row.
            minimumSize: stacked
                ? const Size.fromHeight(56)
                : const Size(0, 56),
          ),
        );
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              nameField,
              const SizedBox(height: 12),
              addButton,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: nameField),
            const SizedBox(width: 12),
            addButton,
          ],
        );
      },
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
        if (hasPassword) ...<Widget>[
          TextField(
            controller: _currentPasswordController,
            obscureText: true,
            decoration: InputDecoration(labelText: appStrings.currentPassword),
          ),
          const SizedBox(height: 12),
        ] else ...<Widget>[
          Text(
            appStrings.noLocalPasswordIsSetYet,
            style: TextStyle(color: _textSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _newPasswordController,
          onChanged: (_) => setState(() {}),
          obscureText: true,
          decoration: InputDecoration(
            labelText: hasPassword ? 'New password' : appStrings.createPassword,
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
                ? appStrings.confirmNewPassword
                : appStrings.confirmPassword,
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
                          appStrings.enterYourCurrentPasswordToChange;
                    });
                    return;
                  }
                  if (_newPasswordController.text.length < 8) {
                    setState(() {
                      _passwordInlineError = appStrings.useANewPasswordWithAt;
                    });
                    return;
                  }
                  if (_newPasswordController.text !=
                      _confirmNewPasswordController.text) {
                    setState(() {
                      _passwordInlineError = appStrings.newPasswordsDoNotMatch;
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
                          ? appStrings.passwordChanged
                          : appStrings.passwordCreated;
                    });
                  }
                },
          icon: controller.isSavingAccountSettings
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.password_outlined),
          label: Text(
            hasPassword ? 'Change password' : appStrings.createPassword,
          ),
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
            decoration: InputDecoration(labelText: appStrings.currentPassword),
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
            label: Text(appStrings.startSetup),
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
            decoration: InputDecoration(
              labelText: appStrings.authenticatorCode,
            ),
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
            label: Text(appStrings.enable2fa),
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
          decoration: InputDecoration(labelText: appStrings.currentPassword),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _disableCodeController,
          decoration: InputDecoration(labelText: appStrings.n2faOrRecoveryCode),
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
              label: Text(appStrings.disable2fa),
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
              label: Text(appStrings.newRecoveryCodes),
            ),
          ],
        ),
      ],
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
            appStrings.saveTheseRecoveryCodesNowThey,
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
            label: Text(appStrings.copyCodes),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                      ? appStrings.arg1CurrentSession(session.clientLabel)
                      : session.clientLabel,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    session.locationSummary,
                    appStrings.lastSeenArg1(session.lastSeenLabel),
                  ].join(' · '),
                  style: TextStyle(color: _textSecondary),
                ),
                if (session.userAgent.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    appStrings.arg1Arg2CreatedArg3(
                      session.clientPlatformLabel,
                      session.clientBrowserLabel,
                      session.createdLabel,
                    ),
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
              child: Text(appStrings.revoke),
            ),
        ],
      ),
    );
  }
}

class _SecurityKeyCard extends StatelessWidget {
  const _SecurityKeyCard({
    required this.securityKey,
    required this.busy,
    required this.onRename,
    required this.onRemove,
  });

  final SecurityKeyItem securityKey;
  final bool busy;
  final VoidCallback onRename;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            securityKey.backedUp ? Icons.cloud_sync : Icons.key,
            color: _textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  securityKey.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  appStrings.addedArg1LastUsedArg2(
                    securityKey.addedLabel,
                    securityKey.lastUsedLabel,
                  ),
                  style: TextStyle(color: _textSecondary),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            enabled: !busy,
            icon: Icon(Icons.more_horiz, color: _textSecondary),
            onSelected: (action) =>
                action == 'rename' ? onRename() : onRemove(),
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'rename',
                child: Text(appStrings.rename),
              ),
              PopupMenuItem<String>(
                value: 'remove',
                child: Text(appStrings.remove),
              ),
            ],
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
                      icon: Icon(
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
                    appStrings.scanANeoagentLoginQr,
                    style: GoogleFonts.geist(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    appStrings.pointTheCameraAtTheCode,
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
      title: Text(appStrings.approveQrLogin),
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
                              appStrings.requestedArg1(_formatTimestamp(preview.requestedAt!)),
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
                    label: appStrings.expiresArg1(_formatTimestamp(preview.expiresAt!)),
                    icon: Icons.timer_outlined,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              preview.isClaimed
                  ? appStrings.thisRequestHasAlreadyBeenUsed
                  : preview.isExpired
                  ? appStrings.thisRequestHasExpiredAskTheOther
                  : appStrings.approveThisOnlyIfYouStarted,
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(false),
          child: Text(appStrings.cancel),
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
              : Icon(Icons.verified_user_outlined),
          label: Text(appStrings.approveLogin),
        ),
      ],
    );
  }
}
