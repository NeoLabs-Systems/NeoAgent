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
    this.reason,
    this.title,
    this.action,
    this.detail,
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
      reason: json['reason']?.toString(),
      title: json['title']?.toString(),
      action: json['action']?.toString(),
      detail: json['detail']?.toString(),
    );
  }

  final String approvalId;
  final String runId;
  final String toolName;
  final Map<String, dynamic> toolArgs;
  final String category;
  final DateTime expiresAt;

  /// Why the run's trust asked for this call, when the category policy alone
  /// would have let it through (a group chat asked, or outside content led
  /// here).
  final String? reason;

  /// The server's wording, in the owner's language: who is asking, what for,
  /// and the one value that says what the call is about.
  final String? title;
  final String? action;
  final String? detail;

  String get displayTitle => title?.trim().ifEmpty(appStrings.approvalRequired)
      ?? appStrings.approvalRequired;
  String get displayAction =>
      action?.trim().ifEmpty(_categoryInfo(category).label) ??
      _categoryInfo(category).label;
}

String _formatCountdown(int seconds) {
  final minutes = seconds ~/ 60;
  return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
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
    subtitle: appStrings.fillApprovedLoginsOrAuthenticateRequests,
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
  'agent_creation': _CategoryInfo(
    label: appStrings.agentsCreationCategory,
    subtitle: appStrings.agentsCreationCategoryHint,
    icon: Icons.group_add_rounded,
    riskLevel: 'medium',
  ),
  'external': _CategoryInfo(
    label: appStrings.externalMcpTools,
    subtitle: appStrings.toolsNotBuiltIntoNeoagentIncluding,
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
  // Silent: the phone's own ringtone plays natively while a call rings.
  static const _incomingCallChannelId = 'agent_calls_ringing';
  static final _incomingCallChannelName = appStrings.agentCalls;
  static const _approveActionId = 'approve';
  static const _denyActionId = 'deny';
  static const callAnswerActionId = 'call_answer';
  static const callDeclineActionId = 'call_decline';
  static const _reviewActionId = 'review';
  static const _callPayloadPrefix = 'agent-call:';
  static const _approvalPayloadPrefix = 'approval:';

  /// Where an action tapped while the app runs in the background — handled
  /// in a separate isolate — is handed to the app's own isolate.
  static const _actionPortName = 'neoagent.notification_actions';
  static ReceivePort? _actionPort;

  /// Answer and Decline tapped on a ringing call's notification, with the
  /// call's id.
  static void Function(String callId, String action)? onCallAction;

  /// Allow and Deny tapped on an approval's notification, with its id and
  /// the decision.
  static void Function(String approvalId, String decision)? onApprovalAction;

  /// Starts taking actions from notifications in this isolate. Actions that
  /// need no UI arrive in a background isolate; the app is still running
  /// (the keep-alive service holds it), so they are forwarded here instead
  /// of opening it.
  static void listenForActions() {
    // Web has no isolate ports and no local notification actions.
    if (kIsWeb || _actionPort != null) return;
    final port = ReceivePort();
    IsolateNameServer.removePortNameMapping(_actionPortName);
    IsolateNameServer.registerPortWithName(port.sendPort, _actionPortName);
    port.listen((message) {
      if (message is List && message.length == 2) {
        _dispatchAction(message[0] as String?, message[1] as String?);
      }
    });
    _actionPort = port;
    unawaited(_getPlugin());
  }

  static void stopListeningForActions() {
    if (kIsWeb) return;
    IsolateNameServer.removePortNameMapping(_actionPortName);
    _actionPort?.close();
    _actionPort = null;
  }

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
          DarwinNotificationCategory(
            'agent_call',
            actions: <DarwinNotificationAction>[
              DarwinNotificationAction.plain(
                callDeclineActionId,
                'Decline',
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.destructive,
                },
              ),
              DarwinNotificationAction.plain(
                callAnswerActionId,
                'Answer',
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
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
    _dispatchAction(response.actionId, response.payload);
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationResponse(NotificationResponse response) {
    // With the app not running there is no one to hand it to: the request
    // then lapses on the server like an unanswered one.
    IsolateNameServer.lookupPortByName(
      _actionPortName,
    )?.send(<String?>[response.actionId, response.payload]);
  }

  static void _dispatchAction(String? actionId, String? payload) {
    if (payload == null || actionId == null) return;
    if (payload.startsWith(_callPayloadPrefix)) {
      if (actionId != callAnswerActionId && actionId != callDeclineActionId) {
        return;
      }
      onCallAction?.call(
        payload.substring(_callPayloadPrefix.length),
        actionId,
      );
      return;
    }
    if (payload.startsWith(_approvalPayloadPrefix)) {
      final decision = switch (actionId) {
        _approveActionId => 'approved',
        _denyActionId => 'denied',
        _ => null,
      };
      if (decision == null) return;
      onApprovalAction?.call(
        payload.substring(_approvalPayloadPrefix.length),
        decision,
      );
    }
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

    final remaining = req.expiresAt.difference(DateTime.now());
    if (remaining <= Duration.zero) return;
    final info = _categoryInfo(req.category);
    final body = <String>[
      req.displayAction,
      if (req.detail?.trim().isNotEmpty == true) req.detail!.trim(),
      if (req.reason?.trim().isNotEmpty == true) req.reason!.trim(),
    ].join('\n');

    // A live notification: it stays put, counts down to the request's
    // expiry, and is answered from the shade without opening the app.
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: appStrings.approvalRequestsForSensitiveAgentTools,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.reminder,
      ticker: appStrings.toolApprovalRequired,
      color: _riskColor(info.riskLevel),
      colorized: true,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: true,
      when: req.expiresAt.millisecondsSinceEpoch,
      usesChronometer: true,
      chronometerCountDown: true,
      timeoutAfter: remaining.inMilliseconds,
      styleInformation: BigTextStyleInformation(body),
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          _denyActionId,
          appStrings.deny,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          _reviewActionId,
          appStrings.approvalReview,
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          _approveActionId,
          appStrings.allowOnce,
          cancelNotification: true,
        ),
      ],
    );

    const darwinDetails = DarwinNotificationDetails(
      categoryIdentifier: 'tool_approval',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    await plugin.show(
      req.approvalId.hashCode.abs() % 100000,
      req.displayTitle,
      body,
      NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      ),
      payload: '$_approvalPayloadPrefix${req.approvalId}',
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
      channelDescription: appStrings.alertsWhenAMessagingConnectionNeeds,
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
    final ringFor = call.expiresAt.difference(DateTime.now());
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
      playSound: false,
      enableVibration: false,
      color: const Color(0xFF5FB06A),
      colorized: true,
      timeoutAfter: ringFor.isNegative ? null : ringFor.inMilliseconds,
      ticker: appStrings.incomingNeoagentCall,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          callDeclineActionId,
          appStrings.decline,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          callAnswerActionId,
          appStrings.answerCall,
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentSound: true,
      categoryIdentifier: 'agent_call',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    await plugin.show(
      call.callId.hashCode.abs() % 100000,
      call.agentName,
      appStrings.incomingCall,
      NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      ),
      payload: '$_callPayloadPrefix${call.callId}',
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
                  AccessPerson.tryParse(manager)?.label ??
                      appStrings.yourManager,
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
            content: Text(appStrings.failedToSaveArg1(_formatCaughtError(e))),
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
            content: Text(appStrings.failedToSaveArg1(_formatCaughtError(e))),
            backgroundColor: _danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: _ErrorView(error: _error!, onRetry: _load),
      );
    }
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SettingsGroup(
          anchor: 'toolPermissions',
          title: appStrings.globalSecurityMode,
          trailing: IconButton(
            icon: Icon(Icons.refresh_rounded),
            tooltip: appStrings.refresh,
            onPressed: _load,
          ),
          children: <Widget>[
            _SettingsRow(
              label: appStrings.toolPermissions,
              description: switch (_mode) {
                'allow_all' => appStrings.noApprovalPromptsAgentRunsWithout,
                'always_ask' =>
                  appStrings.everySensitiveToolRequiresApprovalEvery,
                _ => appStrings.usePerCategorySettingsBelow,
              },
              control: _SettingsChoice<String>(
                value: _mode,
                options: <(String, String)>[
                  ('allow_all', appStrings.allowAll),
                  ('default', appStrings.defaultRecommended),
                  ('always_ask', appStrings.alwaysAsk),
                ],
                onChanged: _setMode,
              ),
            ),
            if (_mode == 'allow_all')
              _SettingsBlock(
                child: _InfoBanner(
                  icon: Icons.warning_amber_rounded,
                  color: colorScheme.errorContainer,
                  textColor: colorScheme.onErrorContainer,
                  message: _lockedBy.isEmpty
                      ? appStrings.allToolsAreAllowedTheAgent +
                            appStrings.switchToDefaultOrAlwaysAskTo
                      : '${appStrings.everyToolRunsWithoutAskingExcept}${appStrings.whoManagesThisAccountTurnedOff}${_lockedBy.keys.map((key) => _categoryInfo(key).label).join(', ')}.',
                ),
              ),
            if (_mode == 'always_ask')
              _SettingsBlock(
                child: _InfoBanner(
                  icon: Icons.info_outline_rounded,
                  color: colorScheme.secondaryContainer,
                  textColor: colorScheme.onSecondaryContainer,
                  message:
                      appStrings.theAgentWillAskBeforeEvery +
                      appStrings.regardlessOfPerCategorySettingsBelow,
                ),
              ),
          ],
        ),
        if (_mode != 'allow_all')
          _SettingsGroup(
            title: appStrings.perCategoryPermissions,
            children: <Widget>[
              for (final entry in _policies.entries)
                _PolicyCard(
                  category: entry.key,
                  policy: entry.value,
                  dimmed: _mode == 'always_ask',
                  lockedBy: _lockedBy[entry.key],
                  onChanged: (policy) => _setPolicy(entry.key, policy),
                ),
            ],
          ),
      ],
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
    final riskColor = _riskColor(info.riskLevel);
    final locked = lockedBy != null;

    return Opacity(
      opacity: dimmed || locked ? 0.55 : 1.0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
    );
  }
}

class _PolicyHint extends StatelessWidget {
  const _PolicyHint({required this.policy});
  final String policy;

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (policy) {
      'deny' => (appStrings.completelyBlockedTheAgentCannotUse, _danger),
      'require_approval' => (appStrings.agentPausesAndAsksYouBefore, _warning),
      'allow' => (appStrings.allowedRunsWithoutAsking, _accentAlt),
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

class _ToolApprovalSheetState extends State<ToolApprovalSheet> {
  late final Timer _timer;
  late final int _totalSeconds;
  late int _remainingSeconds;
  bool _submitting = false;
  bool _showAllDetails = false;

  int _secondsLeft() =>
      widget.request.expiresAt.difference(DateTime.now()).inSeconds;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = _secondsLeft().clamp(0, 86400);
    _totalSeconds = _remainingSeconds < 1 ? 1 : _remainingSeconds;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remainingSeconds = _secondsLeft().clamp(0, 86400));
      if (_remainingSeconds <= 0) {
        _timer.cancel();
        if (mounted) Navigator.of(context).pop();
      }
    });

    widget.controller.addListener(_closeWhenAnsweredElsewhere);

    // Cancel the notification now that the sheet is showing
    _AppNotificationService.cancelApprovalNotification(
      widget.request.approvalId,
    );
  }

  /// Answered from the notification, a chat or another device.
  void _closeWhenAnsweredElsewhere() {
    if (_submitting || !mounted) return;
    if (widget.controller.pendingApproval?.approvalId ==
        widget.request.approvalId) {
      return;
    }
    widget.controller.removeListener(_closeWhenAnsweredElsewhere);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_closeWhenAnsweredElsewhere);
    _timer.cancel();
    super.dispose();
  }

  Future<void> _decide(String decision, String scope) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    _timer.cancel();
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
            SnackBar(
              content: Text(appStrings.approvalExpired),
              backgroundColor: _warning,
            ),
          );
        }
      }
    } catch (_) {
      // timeout will fire server-side; safe to dismiss
    }
    if (mounted) Navigator.of(context).pop();
  }

  /// Still waiting, but out of the way; the chat banner brings it back.
  void _decideLater() {
    widget.controller.dismissApprovalSheet(widget.request.approvalId);
    Navigator.of(context).pop();
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

  Widget _buildHeader(ColorScheme colorScheme, _CategoryInfo info, Color riskColor) {
    final req = widget.request;
    final urgent = _remainingSeconds <= 10;
    final timeColor = urgent ? colorScheme.error : colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(info.icon, size: 23, color: riskColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  req.displayTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  req.displayAction,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _formatCountdown(_remainingSeconds),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: timeColor,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(ColorScheme colorScheme) {
    final req = widget.request;
    final summary = req.detail?.trim() ?? '';
    if (summary.isEmpty && req.toolArgs.isEmpty) return const SizedBox.shrink();
    final text = _showAllDetails || summary.isEmpty ? _formatArgs() : summary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _showAllDetails = !_showAllDetails),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    text,
                    style: GoogleFonts.geistMono(
                      fontSize: 12,
                      height: 1.5,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  _showAllDetails
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(ColorScheme colorScheme) {
    const height = Size.fromHeight(50);
    final quiet = TextButton.styleFrom(
      foregroundColor: colorScheme.onSurfaceVariant,
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: height,
                    foregroundColor: colorScheme.error,
                    side: BorderSide(
                      color: colorScheme.error.withValues(alpha: 0.4),
                    ),
                  ),
                  onPressed: () => _decide('denied', 'once'),
                  child: Text(appStrings.deny),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: height),
                  onPressed: () => _decide('approved', 'once'),
                  child: Text(appStrings.allowOnce),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            children: <Widget>[
              TextButton(
                style: quiet,
                onPressed: () => _decide('approved', 'session'),
                child: Text(appStrings.allowSession),
              ),
              Tooltip(
                message: appStrings.alwaysAllowSavesThePolicyPermanently,
                child: TextButton(
                  style: quiet,
                  onPressed: () => _decide('approved', 'always'),
                  child: Text(appStrings.alwaysAllow),
                ),
              ),
              TextButton(
                style: quiet,
                onPressed: _decideLater,
                child: Text(appStrings.notNow),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final info = _categoryInfo(req.category);
    final colorScheme = Theme.of(context).colorScheme;
    final riskColor = _riskColor(info.riskLevel);
    final reason = req.reason?.trim() ?? '';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
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
                    _buildHeader(colorScheme, info, riskColor),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: _remainingSeconds / _totalSeconds,
                          minHeight: 3,
                          color: _remainingSeconds <= 10
                              ? colorScheme.error
                              : riskColor,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                    if (reason.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(
                              Icons.shield_outlined,
                              size: 16,
                              color: riskColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                reason,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    _buildDetails(colorScheme),
                  ],
                ),
              ),
            ),
            if (_submitting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: CircularProgressIndicator.adaptive()),
              )
            else
              _buildActions(colorScheme),
          ],
        ),
      ),
    );
  }
}
