part of 'main.dart';

// ── Tool approval request model ───────────────────────────────────────────────

class ToolApprovalRequest {
  const ToolApprovalRequest({
    required this.approvalId,
    required this.runId,
    required this.toolName,
    required this.toolArgs,
    required this.category,
    required this.expiresAt,
  });

  factory ToolApprovalRequest.fromJson(Map<String, dynamic> json) {
    return ToolApprovalRequest(
      approvalId: json['approvalId']?.toString() ?? '',
      runId: json['runId']?.toString() ?? '',
      toolName: json['toolName']?.toString() ?? '',
      toolArgs: json['toolArgs'] is Map
          ? Map<String, dynamic>.from(json['toolArgs'] as Map)
          : const <String, dynamic>{},
      category: json['category']?.toString() ?? 'unknown',
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString()) ??
                DateTime.now().add(const Duration(seconds: 30))
          : DateTime.now().add(const Duration(seconds: 30)),
    );
  }

  final String approvalId;
  final String runId;
  final String toolName;
  final Map<String, dynamic> toolArgs;
  final String category;
  final DateTime expiresAt;
}

// ── Category metadata ─────────────────────────────────────────────────────────

class _CategoryInfo {
  const _CategoryInfo({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.riskLevel,
  });
  final String label;
  final String subtitle;
  final IconData icon;
  final String riskLevel; // 'low' | 'medium' | 'high' | 'critical'
}

final _kCategoryInfo = <String, _CategoryInfo>{
  'shell': _CategoryInfo(
    label: appStrings.shellCommands,
    subtitle: appStrings.runArbitraryCommandsOnYourMachine,
    icon: Icons.terminal_rounded,
    riskLevel: 'critical',
  ),
  'file_write': _CategoryInfo(
    label: appStrings.fileWrites,
    subtitle: appStrings.createOrModifyFilesInYour,
    icon: Icons.edit_document,
    riskLevel: 'high',
  ),
  'android_privileged': _CategoryInfo(
    label: appStrings.androidControl,
    subtitle: appStrings.runShellCommandsOrInstallApps,
    icon: Icons.android_rounded,
    riskLevel: 'high',
  ),
  'desktop_control': _CategoryInfo(
    label: appStrings.desktopControl,
    subtitle: appStrings.clickTypeAndInteractWithDesktop,
    icon: Icons.desktop_windows_rounded,
    riskLevel: 'medium',
  ),
  'browser_privileged': _CategoryInfo(
    label: appStrings.browserScripting,
    subtitle: appStrings.executeJavascriptInsideYourBrowserSession,
    icon: Icons.code_rounded,
    riskLevel: 'high',
  ),
  'credential_use': _CategoryInfo(
    label: appStrings.credentialUse,
    subtitle:
        appStrings.fillApprovedLoginsOrAuthenticateRequests,
    icon: Icons.password_rounded,
    riskLevel: 'high',
  ),
  'network_write': _CategoryInfo(
    label: appStrings.networkWriteRequests,
    subtitle: appStrings.sendPostPutDeleteRequestsTo,
    icon: Icons.http_rounded,
    riskLevel: 'medium',
  ),
  'user_contact': _CategoryInfo(
    label: appStrings.callUser,
    subtitle: appStrings.allowTheAgentToStartAn,
    icon: Icons.phone_in_talk_rounded,
    riskLevel: 'medium',
  ),
  'skill_mutation': _CategoryInfo(
    label: appStrings.skillChanges,
    subtitle: appStrings.createUpdateOrDeleteSkills,
    icon: Icons.extension_rounded,
    riskLevel: 'medium',
  ),
  'external': _CategoryInfo(
    label: appStrings.externalMcpTools,
    subtitle:
        appStrings.toolsNotBuiltIntoNeoagentIncluding,
    icon: Icons.hub_rounded,
    riskLevel: 'high',
  ),
};

_CategoryInfo _categoryInfo(String category) {
  return _kCategoryInfo[category] ??
      _CategoryInfo(
        label: category,
        subtitle: appStrings.controlsAccessToArg1Tools(category),
        icon: Icons.lock_outline,
        riskLevel: 'medium',
      );
}

// A permission screen has one colour language: how risky the permission is.
// A decorative per-category hue competed with it and won visually, so a
// high-risk category could read as green/safe.
Color _riskColor(String level) {
  return switch (level) {
    'critical' => _danger,
    'high' => _warning,
    'medium' => _accent,
    _ => _textSecondary,
  };
}

// ── Notification service ──────────────────────────────────────────────────────

class _AppNotificationService {
  static const _channelId = 'tool_approval';
  static final _channelName = appStrings.toolApproval;
  static const _messagingChannelId = 'messaging_connection';
  static final _messagingChannelName = appStrings.messagingConnections;
  static const _incomingCallChannelId = 'agent_calls';
  static final _incomingCallChannelName = appStrings.agentCalls;
  static const _approveActionId = 'approve';
  static const _denyActionId = 'deny';

  static FlutterLocalNotificationsPlugin? _plugin;

  static Future<FlutterLocalNotificationsPlugin?> _getPlugin() async {
    if (_plugin != null) return _plugin;
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      final androidSettings = const AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      final darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: <DarwinNotificationCategory>[
          DarwinNotificationCategory(
            'tool_approval',
            actions: <DarwinNotificationAction>[
              DarwinNotificationAction.plain(_approveActionId, 'Allow'),
              DarwinNotificationAction.plain(
                _denyActionId,
                'Deny',
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.destructive,
                },
              ),
            ],
          ),
        ],
      );
      await plugin.initialize(
        InitializationSettings(
          android: androidSettings,
          iOS: darwinSettings,
          macOS: darwinSettings,
        ),
        onDidReceiveNotificationResponse: _onNotificationResponse,
        onDidReceiveBackgroundNotificationResponse:
            _onBackgroundNotificationResponse,
      );
      _plugin = plugin;
      return plugin;
    } catch (_) {
      return null;
    }
  }

  static void _onNotificationResponse(NotificationResponse response) {
    _handleNotificationAction(response.id, response.actionId, response.payload);
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationResponse(NotificationResponse response) {
    _handleNotificationAction(response.id, response.actionId, response.payload);
  }

  static void _handleNotificationAction(
    int? id,
    String? actionId,
    String? payload,
  ) {
    // No-op in background; the app will handle it on resume via foreground listener.
    // Foreground case is handled directly by the approval gate service.
  }

  static Future<void> requestPermission({bool sound = false}) async {
    final plugin = await _getPlugin();
    if (plugin == null) return;
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
      await plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: false, sound: sound);
      await plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: false, sound: sound);
    }
  }

  static Future<void> requestIncomingCallPermission() async {
    await requestPermission(sound: true);
    if (kIsWeb || !Platform.isAndroid) return;
    final plugin = await _getPlugin();
    await plugin
        ?.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestFullScreenIntentPermission();
  }

  static Future<void> showApprovalNotification(ToolApprovalRequest req) async {
    await requestPermission();
    final plugin = await _getPlugin();
    if (plugin == null) return;

    final info = _categoryInfo(req.category);
    final body = appStrings.agentWantsToUseArg1Tap(req.toolName);

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: appStrings.approvalRequestsForSensitiveAgentTools,
      importance: Importance.high,
      priority: Priority.high,
      ticker: appStrings.toolApprovalRequired,
      color: _riskColor(info.riskLevel),
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(_approveActionId, 'Allow'),
        const AndroidNotificationAction(_denyActionId, 'Deny'),
      ],
    );

    final darwinDetails = DarwinNotificationDetails(
      categoryIdentifier: 'tool_approval',
    );

    await plugin.show(
      req.approvalId.hashCode.abs() % 100000,
      appStrings.arg1ApprovalNeeded(info.label),
      body,
      NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      ),
      payload: req.approvalId,
    );
  }

  static Future<void> showMessagingConnectionNotification(
    String platform,
  ) async {
    await requestPermission();
    final plugin = await _getPlugin();
    if (plugin == null) return;

    final descriptor = _messagingPlatformById(platform);
    final label = descriptor?.label ?? platform;
    final androidDetails = AndroidNotificationDetails(
      _messagingChannelId,
      _messagingChannelName,
      channelDescription:
          appStrings.alertsWhenAMessagingConnectionNeeds,
      importance: Importance.high,
      priority: Priority.high,
      ticker: appStrings.messagingConnectionNeedsAttention,
    );
    const darwinDetails = DarwinNotificationDetails();

    await plugin.show(
      100000 + (platform.hashCode.abs() % 100000),
      appStrings.arg1NeedsAttention(label),
      appStrings.openNeoagentAndReconnectArg1To(label),
      NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      ),
      payload: 'messaging:$platform',
    );
  }

  static Future<void> cancelApprovalNotification(String approvalId) async {
    final plugin = await _getPlugin();
    await plugin?.cancel(approvalId.hashCode.abs() % 100000);
  }

  static Future<void> showIncomingCallNotification(
    IncomingAgentCall call,
  ) async {
    await requestIncomingCallPermission();
    final plugin = await _getPlugin();
    if (plugin == null) return;
    final androidDetails = AndroidNotificationDetails(
      _incomingCallChannelId,
      _incomingCallChannelName,
      channelDescription: appStrings.incomingInAppVoiceCallsFrom,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      ticker: appStrings.incomingNeoagentCall,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    await plugin.show(
      call.callId.hashCode.abs() % 100000,
      appStrings.incomingNeoagentCall,
      appStrings.arg1WantsToTalkWithYou(call.agentName),
      NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      ),
      payload: 'agent-call:${call.callId}',
    );
  }

  static Future<void> cancelIncomingCallNotification(String callId) async {
    final plugin = await _getPlugin();
    await plugin?.cancel(callId.hashCode.abs() % 100000);
  }
}

// ── Security settings screen ──────────────────────────────────────────────────

class MainSecurity extends StatefulWidget {
  const MainSecurity({super.key, required this.controller});
  final NeoAgentController controller;

  @override
  State<MainSecurity> createState() => _MainSecurityState();
}

class _MainSecurityState extends State<MainSecurity> {
  Map<String, String> _policies = const <String, String>{};

  /// Categories a manager has turned off for this account, mapped to that
  /// manager's name. The account's own setting can't override these.
  Map<String, String> _lockedBy = const <String, String>{};
  String _mode = 'default';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await widget.controller.backendClient
          .fetchSecurityPolicies(widget.controller.backendUrl);
      final raw = result['policies'];
      Map<String, String> loaded = const <String, String>{};
      if (raw is Map) {
        loaded = Map<String, String>.from(
          raw.map((k, v) => MapEntry(k.toString(), v.toString())),
        );
      }
      final locks = result['lockedByManager'];
      setState(() {
        _policies = loaded;
        _lockedBy = locks is Map
            ? locks.map(
                (key, manager) => MapEntry(
                  key.toString(),
                  AccessPerson.tryParse(manager)?.label ?? appStrings.yourManager,
                ),
              )
            : const <String, String>{};
        _mode = result['mode']?.toString() ?? 'default';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = _formatCaughtError(e);
        _loading = false;
      });
    }
  }

  Future<void> _setMode(String mode) async {
    final prev = _mode;
    setState(() => _mode = mode);
    try {
      await widget.controller.backendClient.saveSecurityMode(
        widget.controller.backendUrl,
        mode,
      );
    } catch (e) {
      setState(() => _mode = prev);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appStrings.failedToSaveArg1(e)),
            backgroundColor: _danger,
          ),
        );
      }
    }
  }

  Future<void> _setPolicy(String category, String policy) async {
    final prev = _policies[category];
    setState(() => _policies = {..._policies, category: policy});
    try {
      await widget.controller.backendClient.saveSecurityPolicy(
        widget.controller.backendUrl,
        category: category,
        policy: policy,
      );
    } catch (e) {
      setState(
        () => _policies = {..._policies, category: prev ?? 'require_approval'},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appStrings.failedToSaveArg1(e)),
            backgroundColor: _danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(appStrings.toolPermissions),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _error != null
          ? _ErrorView(error: _error!, onRetry: _load)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: <Widget>[
                _GlobalModeCard(mode: _mode, onChanged: _setMode),
                const SizedBox(height: 16),
                if (_mode == 'allow_all')
                  _InfoBanner(
                    icon: Icons.warning_amber_rounded,
                    color: colorScheme.errorContainer,
                    textColor: colorScheme.onErrorContainer,
                    message: _lockedBy.isEmpty
                        ? appStrings.allToolsAreAllowedTheAgent +
                              appStrings.switchToDefaultOrAlwaysAskTo
                        : appStrings.everyToolRunsWithoutAskingExcept +
                              appStrings.whoManagesThisAccountTurnedOff +
                              '${_lockedBy.keys.map((key) => _categoryInfo(key).label).join(', ')}.',
                  )
                else ...<Widget>[
                  if (_mode == 'always_ask')
                    _InfoBanner(
                      icon: Icons.info_outline_rounded,
                      color: colorScheme.secondaryContainer,
                      textColor: colorScheme.onSecondaryContainer,
                      message:
                          appStrings.theAgentWillAskBeforeEvery +
                          appStrings.regardlessOfPerCategorySettingsBelow,
                    ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 6),
                    child: _SectionTitle(appStrings.perCategoryPermissions),
                  ),
                  ..._policies.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PolicyCard(
                        category: e.key,
                        policy: e.value,
                        dimmed: _mode == 'always_ask',
                        lockedBy: _lockedBy[e.key],
                        onChanged: (p) => _setPolicy(e.key, p),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.error_outline, size: 48, color: _danger),
          const SizedBox(height: 12),
          Text(
            appStrings.failedToLoadPolicies,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            error,
            style: TextStyle(fontSize: 12, color: _textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: Icon(Icons.refresh),
            label: Text(appStrings.retry),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.textColor,
    required this.message,
  });
  final IconData icon;
  final Color color;
  final Color textColor;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: textColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: textColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobalModeCard extends StatelessWidget {
  const _GlobalModeCard({required this.mode, required this.onChanged});
  final String mode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.tune_rounded, size: 18, color: _accent),
                const SizedBox(width: 8),
                Text(
                  appStrings.globalSecurityMode,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ModeOption(
              value: 'allow_all',
              current: mode,
              label: appStrings.allowAll,
              subtitle:
                  appStrings.noApprovalPromptsAgentRunsWithout,
              icon: Icons.lock_open_rounded,
              color: _warning,
              onTap: () => onChanged('allow_all'),
            ),
            const SizedBox(height: 6),
            _ModeOption(
              value: 'default',
              current: mode,
              label: appStrings.defaultRecommended,
              subtitle: appStrings.usePerCategorySettingsBelow,
              icon: Icons.shield_outlined,
              color: _accentAlt,
              onTap: () => onChanged('default'),
            ),
            const SizedBox(height: 6),
            _ModeOption(
              value: 'always_ask',
              current: mode,
              label: appStrings.alwaysAsk,
              subtitle: appStrings.everySensitiveToolRequiresApprovalEvery,
              icon: Icons.pan_tool_outlined,
              color: _info,
              onTap: () => onChanged('always_ask'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.value,
    required this.current,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String value;
  final String current;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = value == current;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(24) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : _border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: selected ? color : _textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                      color: selected ? color : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: _textSecondary),
                  ),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({
    required this.category,
    required this.policy,
    required this.dimmed,
    required this.lockedBy,
    required this.onChanged,
  });
  final String category;
  final String policy;
  final bool dimmed;

  /// Name of the manager who turned this category off, if one did.
  final String? lockedBy;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final info = _categoryInfo(category);
    final colorScheme = Theme.of(context).colorScheme;
    final riskColor = _riskColor(info.riskLevel);
    final locked = lockedBy != null;

    return Opacity(
      opacity: dimmed || locked ? 0.55 : 1.0,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: riskColor.withAlpha(22),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(info.icon, size: 16, color: riskColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          info.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          info.subtitle,
                          style: TextStyle(fontSize: 11, color: _textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: riskColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      info.riskLevel.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: riskColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: <ButtonSegment<String>>[
                  ButtonSegment<String>(
                    value: 'deny',
                    label: Text(appStrings.block),
                    icon: Icon(Icons.block_rounded, size: 13),
                  ),
                  ButtonSegment<String>(
                    value: 'require_approval',
                    label: Text(appStrings.askMe),
                    icon: Icon(Icons.pan_tool_outlined, size: 13),
                  ),
                  ButtonSegment<String>(
                    value: 'allow',
                    label: Text(appStrings.allow),
                    icon: Icon(Icons.check_rounded, size: 13),
                  ),
                  ButtonSegment<String>(
                    value: 'allow_always',
                    label: Text(appStrings.always),
                    icon: Icon(Icons.verified_rounded, size: 13),
                  ),
                ],
                selected: <String>{locked ? 'deny' : policy},
                onSelectionChanged: dimmed || locked
                    ? null
                    : (s) => onChanged(s.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStateProperty.all(
                    const TextStyle(fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              if (locked)
                Row(
                  children: <Widget>[
                    Icon(Icons.lock_outline, size: 12, color: _textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        appStrings.turnedOffByArg1WhoManages(lockedBy) +
                        appStrings.onlyTheyCanChangeIt,
                        style: TextStyle(fontSize: 11, color: _textSecondary),
                      ),
                    ),
                  ],
                )
              else
                _PolicyHint(policy: policy),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicyHint extends StatelessWidget {
  const _PolicyHint({required this.policy});
  final String policy;

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (policy) {
      'deny' => (
        appStrings.completelyBlockedTheAgentCannotUse,
        _danger,
      ),
      'require_approval' => (
        appStrings.agentPausesAndAsksYouBefore,
        _warning,
      ),
      'allow' => (
        appStrings.allowedForThisRunWillAsk,
        _accentAlt,
      ),
      'allow_always' => (appStrings.permanentlyAllowedNeverAsksAgain, _info),
      _ => ('', _textSecondary),
    };
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(text, style: TextStyle(fontSize: 11, color: color));
  }
}

// ── Tool approval bottom sheet ────────────────────────────────────────────────

class ToolApprovalSheet extends StatefulWidget {
  const ToolApprovalSheet({
    super.key,
    required this.request,
    required this.controller,
  });
  final ToolApprovalRequest request;
  final NeoAgentController controller;

  @override
  State<ToolApprovalSheet> createState() => _ToolApprovalSheetState();
}

class _ToolApprovalSheetState extends State<ToolApprovalSheet>
    with SingleTickerProviderStateMixin {
  late final Timer _timer;
  late final AnimationController _ringController;
  int _remainingSeconds = 30;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final diff = widget.request.expiresAt.difference(DateTime.now());
    _remainingSeconds = diff.inSeconds.clamp(0, 30);

    _ringController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _remainingSeconds),
    )..forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remainingSeconds = (_remainingSeconds - 1).clamp(0, 30));
      if (_remainingSeconds <= 0) {
        _timer.cancel();
        if (mounted) Navigator.of(context).pop();
      }
    });

    // Cancel the notification now that the sheet is showing
    _AppNotificationService.cancelApprovalNotification(
      widget.request.approvalId,
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    _ringController.dispose();
    super.dispose();
  }

  Future<void> _decide(String decision, String scope) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    _timer.cancel();
    _ringController.stop();
    try {
      await widget.controller.backendClient.resolveToolApproval(
        widget.controller.backendUrl,
        approvalId: widget.request.approvalId,
        decision: decision,
        scope: scope,
        runId: widget.request.runId,
        toolName: widget.request.toolName,
        toolArgs: widget.request.toolArgs,
      );
      widget.controller.clearPendingApproval();
    } on BackendException catch (error) {
      if (error.statusCode == 410) {
        widget.controller.clearPendingApproval();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.message), backgroundColor: _warning),
          );
        }
      }
    } catch (_) {
      // timeout will fire server-side; safe to dismiss
    }
    if (mounted) Navigator.of(context).pop();
  }

  String _formatArgs() {
    final args = widget.request.toolArgs;
    if (args.isEmpty) return appStrings.noArguments;
    final buf = StringBuffer();
    for (final e in args.entries) {
      buf.writeln(appStrings.arg1Arg24(e.key, _redact(e.key, e.value)));
    }
    final out = buf.toString().trimRight();
    return out.length > 500 ? '${out.substring(0, 500)}…' : out;
  }

  String _redact(String key, dynamic value) {
    const sensitive = <String>[
      'token',
      'secret',
      'password',
      'key',
      'api_key',
      'auth',
      'credential',
    ];
    if (sensitive.any((s) => key.toLowerCase().contains(s))) return '••••••';
    return value?.toString() ?? 'null';
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final info = _categoryInfo(req.category);
    final colorScheme = Theme.of(context).colorScheme;
    final urgent = _remainingSeconds <= 8;
    final riskColor = _riskColor(info.riskLevel);
    final ringColor = urgent ? colorScheme.error : riskColor;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: <Widget>[
                  // Countdown ring
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        AnimatedBuilder(
                          animation: _ringController,
                          builder: (_, __) => CircularProgressIndicator(
                            value: 1 - _ringController.value,
                            strokeWidth: 3.5,
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            color: ringColor,
                          ),
                        ),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: ringColor,
                          ),
                          child: Text('$_remainingSeconds'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          appStrings.approvalRequired,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: riskColor.withAlpha(22),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                info.icon,
                                size: 13,
                                color: riskColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              info.label,
                              style: TextStyle(
                                fontSize: 12,
                                color: riskColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Tool + args preview
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: riskColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          req.toolName,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    if (req.toolArgs.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        _formatArgs(),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            // Action buttons
            if (_submitting)
              const Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Center(child: CircularProgressIndicator.adaptive()),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(Icons.block_rounded, size: 15),
                            label: Text(appStrings.deny),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colorScheme.error,
                              side: BorderSide(
                                color: colorScheme.error.withAlpha(100),
                              ),
                            ),
                            onPressed: () => _decide('denied', 'once'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(
                              Icons.check_circle_outline,
                              size: 15,
                            ),
                            label: Text(appStrings.allowOnce),
                            onPressed: () => _decide('approved', 'once'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(Icons.history_rounded, size: 15),
                            label: Text(appStrings.allowSession),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _info,
                            ),
                            onPressed: () => _decide('approved', 'session'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            icon: Icon(Icons.verified_rounded, size: 15),
                            label: Text(appStrings.alwaysAllow),
                            style: FilledButton.styleFrom(
                              backgroundColor: riskColor,
                            ),
                            onPressed: () => _decide('approved', 'always'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appStrings.alwaysAllowSavesThePolicyPermanently,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
