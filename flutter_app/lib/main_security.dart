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
    required this.color,
    required this.riskLevel,
  });
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String riskLevel; // 'low' | 'medium' | 'high' | 'critical'
}

const _kCategoryInfo = <String, _CategoryInfo>{
  'shell': _CategoryInfo(
    label: 'Shell Commands',
    subtitle: 'Run arbitrary commands on your machine or VM.',
    icon: Icons.terminal_rounded,
    color: Color(0xFFE53935),
    riskLevel: 'critical',
  ),
  'file_write': _CategoryInfo(
    label: 'File Writes',
    subtitle: 'Create or modify files in your workspace.',
    icon: Icons.edit_document,
    color: Color(0xFFF4511E),
    riskLevel: 'high',
  ),
  'android_privileged': _CategoryInfo(
    label: 'Android Control',
    subtitle: 'Run shell commands or install apps on your Android device.',
    icon: Icons.android_rounded,
    color: Color(0xFF43A047),
    riskLevel: 'high',
  ),
  'desktop_control': _CategoryInfo(
    label: 'Desktop Control',
    subtitle: 'Click, type, and interact with desktop apps.',
    icon: Icons.desktop_windows_rounded,
    color: Color(0xFF1E88E5),
    riskLevel: 'medium',
  ),
  'browser_privileged': _CategoryInfo(
    label: 'Browser Scripting',
    subtitle: 'Execute JavaScript inside your browser session.',
    icon: Icons.code_rounded,
    color: Color(0xFF8E24AA),
    riskLevel: 'high',
  ),
  'credential_use': _CategoryInfo(
    label: 'Credential Use',
    subtitle:
        'Fill approved logins or authenticate requests without showing secrets to the AI.',
    icon: Icons.password_rounded,
    color: Color(0xFF5E35B1),
    riskLevel: 'high',
  ),
  'network_write': _CategoryInfo(
    label: 'Network Write Requests',
    subtitle: 'Send POST / PUT / DELETE requests to external APIs.',
    icon: Icons.http_rounded,
    color: Color(0xFF00897B),
    riskLevel: 'medium',
  ),
  'user_contact': _CategoryInfo(
    label: 'Call User',
    subtitle: 'Allow the agent to start an in-app voice call with you.',
    icon: Icons.phone_in_talk_rounded,
    color: Color(0xFF2E7D32),
    riskLevel: 'medium',
  ),
  'skill_mutation': _CategoryInfo(
    label: 'Skill Changes',
    subtitle: 'Create, update, or delete skills.',
    icon: Icons.extension_rounded,
    color: Color(0xFFFB8C00),
    riskLevel: 'medium',
  ),
  'external': _CategoryInfo(
    label: 'External & MCP Tools',
    subtitle:
        'Tools not built into NeoAgent, including connected MCP servers and custom tool providers.',
    icon: Icons.hub_rounded,
    color: Color(0xFF6D4C41),
    riskLevel: 'high',
  ),
};

_CategoryInfo _categoryInfo(String category) {
  return _kCategoryInfo[category] ??
      _CategoryInfo(
        label: category,
        subtitle: 'Controls access to $category tools.',
        icon: Icons.lock_outline,
        color: const Color(0xFF888888),
        riskLevel: 'medium',
      );
}

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
  static const _channelName = 'Tool Approval';
  static const _messagingChannelId = 'messaging_connection';
  static const _messagingChannelName = 'Messaging Connections';
  static const _incomingCallChannelId = 'agent_calls';
  static const _incomingCallChannelName = 'Agent Calls';
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
    final body = 'Agent wants to use ${req.toolName}. Tap to decide.';

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Approval requests for sensitive agent tools',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'Tool approval required',
      color: info.color,
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
      '${info.label} approval needed',
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
    const androidDetails = AndroidNotificationDetails(
      _messagingChannelId,
      _messagingChannelName,
      channelDescription:
          'Alerts when a messaging connection needs user attention',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'Messaging connection needs attention',
    );
    const darwinDetails = DarwinNotificationDetails();

    await plugin.show(
      100000 + (platform.hashCode.abs() % 100000),
      '$label needs attention',
      'Open NeoAgent and reconnect $label to restore messaging.',
      const NotificationDetails(
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
    const androidDetails = AndroidNotificationDetails(
      _incomingCallChannelId,
      _incomingCallChannelName,
      channelDescription: 'Incoming in-app voice calls from NeoAgent',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      ticker: 'Incoming NeoAgent call',
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    await plugin.show(
      call.callId.hashCode.abs() % 100000,
      'Incoming NeoAgent call',
      '${call.agentName} wants to talk with you.',
      const NotificationDetails(
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
      setState(() {
        _policies = loaded;
        _mode = result['mode']?.toString() ?? 'default';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
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
            content: Text('Failed to save: $e'),
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
            content: Text('Failed to save: $e'),
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
        title: const Text('Tool Permissions'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
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
                    message:
                        'All tools are allowed — the agent can use any capability without asking. '
                        'Switch to "Default" or "Always ask" to re-enable approval checks.',
                  )
                else ...<Widget>[
                  if (_mode == 'always_ask')
                    _InfoBanner(
                      icon: Icons.info_outline_rounded,
                      color: colorScheme.secondaryContainer,
                      textColor: colorScheme.onSecondaryContainer,
                      message:
                          'The agent will ask before every sensitive tool, '
                          'regardless of per-category settings below.',
                    ),
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 6),
                    child: _SectionTitle('Per-category permissions'),
                  ),
                  ..._policies.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PolicyCard(
                        category: e.key,
                        policy: e.value,
                        dimmed: _mode == 'always_ask',
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
            'Failed to load policies',
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
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
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
                const Text(
                  'Global security mode',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ModeOption(
              value: 'allow_all',
              current: mode,
              label: 'Allow all',
              subtitle:
                  'No approval prompts — agent runs without interruption.',
              icon: Icons.lock_open_rounded,
              color: _warning,
              onTap: () => onChanged('allow_all'),
            ),
            const SizedBox(height: 6),
            _ModeOption(
              value: 'default',
              current: mode,
              label: 'Default (recommended)',
              subtitle: 'Use per-category settings below.',
              icon: Icons.shield_outlined,
              color: _accentAlt,
              onTap: () => onChanged('default'),
            ),
            const SizedBox(height: 6),
            _ModeOption(
              value: 'always_ask',
              current: mode,
              label: 'Always ask',
              subtitle: 'Every sensitive tool requires approval, every time.',
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
    required this.onChanged,
  });
  final String category;
  final String policy;
  final bool dimmed;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final info = _categoryInfo(category);
    final colorScheme = Theme.of(context).colorScheme;
    final riskColor = _riskColor(info.riskLevel);

    return Opacity(
      opacity: dimmed ? 0.55 : 1.0,
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
                      color: info.color.withAlpha(22),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(info.icon, size: 16, color: info.color),
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
                segments: const <ButtonSegment<String>>[
                  ButtonSegment<String>(
                    value: 'deny',
                    label: Text('Block'),
                    icon: Icon(Icons.block_rounded, size: 13),
                  ),
                  ButtonSegment<String>(
                    value: 'require_approval',
                    label: Text('Ask me'),
                    icon: Icon(Icons.pan_tool_outlined, size: 13),
                  ),
                  ButtonSegment<String>(
                    value: 'allow',
                    label: Text('Allow'),
                    icon: Icon(Icons.check_rounded, size: 13),
                  ),
                  ButtonSegment<String>(
                    value: 'allow_always',
                    label: Text('Always'),
                    icon: Icon(Icons.verified_rounded, size: 13),
                  ),
                ],
                selected: <String>{policy},
                onSelectionChanged: dimmed ? null : (s) => onChanged(s.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStateProperty.all(
                    const TextStyle(fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(height: 6),
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
        'Completely blocked — the agent cannot use this category.',
        _danger,
      ),
      'require_approval' => (
        'Agent pauses and asks you before running.',
        _warning,
      ),
      'allow' => (
        'Allowed for this run — will ask again next session.',
        _accentAlt,
      ),
      'allow_always' => ('Permanently allowed — never asks again.', _info),
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
    if (args.isEmpty) return '(no arguments)';
    final buf = StringBuffer();
    for (final e in args.entries) {
      buf.writeln('${e.key}: ${_redact(e.key, e.value)}');
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
    final ringColor = urgent ? colorScheme.error : info.color;

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
                        const Text(
                          'Approval required',
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
                                color: info.color.withAlpha(22),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                info.icon,
                                size: 13,
                                color: info.color,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              info.label,
                              style: TextStyle(
                                fontSize: 12,
                                color: info.color,
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
                            color: info.color,
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
                            icon: const Icon(Icons.block_rounded, size: 15),
                            label: const Text('Deny'),
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
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 15,
                            ),
                            label: const Text('Allow once'),
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
                            icon: const Icon(Icons.history_rounded, size: 15),
                            label: const Text('Allow session'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _info,
                            ),
                            onPressed: () => _decide('approved', 'session'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.verified_rounded, size: 15),
                            label: const Text('Always allow'),
                            style: FilledButton.styleFrom(
                              backgroundColor: info.color,
                            ),
                            onPressed: () => _decide('approved', 'always'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '"Always allow" saves the policy permanently — you can change it in Settings.',
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
