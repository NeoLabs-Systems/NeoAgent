part of 'main.dart';

class NeoAgentController extends ChangeNotifier {
  NeoAgentController({
    this.appMode = NeoAgentAppMode.standard,
    required BackendClient backendClient,
    required HealthBridge healthBridge,
    required WidgetBridge widgetBridge,
    required RecordingBridge recordingBridge,
    OAuthLauncher? oauthLauncher,
  }) : _backendClient = backendClient,
       _healthBridge = healthBridge,
       _widgetBridge = widgetBridge,
       _recordingBridge = recordingBridge,
       _oauthLauncher = oauthLauncher ?? createOAuthLauncher() {
    _recordingBridge.onRecordingStopped = _handleRecordingStopped;
    _recordingBridge.addListener(_handleRecordingBridgeChanged);
    _desktopCompanion.addListener(notifyListeners);

    AndroidAutoBridge.instance.onStartVoiceMode = startLiveVoiceCapture;
    AndroidAutoBridge.instance.onStopVoiceMode = interruptLiveVoiceAssistant;

    _clientLogs = AppDiagnostics.recentEntries
        .map(_logEntryFromDiagnostic)
        .toList(growable: false);
    _rebuildMergedLogs();
    _diagnosticLogSubscription = AppDiagnostics.stream.listen(
      _handleDiagnosticLogEntry,
    );
  }

  final NeoAgentAppMode appMode;
  final BackendClient _backendClient;
  final HealthBridge _healthBridge;
  final WidgetBridge _widgetBridge;
  final RecordingBridge _recordingBridge;
  final OAuthLauncher _oauthLauncher;
  final app_release_updater.AppReleaseUpdater _appReleaseUpdater =
      app_release_updater.AppReleaseUpdater();
  final AppAnalytics _analytics = AppAnalytics();
  final LiveVoiceCapture _liveVoiceCapture = LiveVoiceCapture();
  final DesktopScreenCapture _desktopScreenCapture =
      createDesktopScreenCapture();
  final DesktopCompanionManager _desktopCompanion = DesktopCompanionManager(
    screenCapture: createDesktopScreenCapture(),
  );
  StreamSubscription<AppDiagnosticEntry>? _diagnosticLogSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _connectivityPluginAvailable = true;
  static const int _maxVisibleLogs = 400;

  static const String _configuredBackendUrl = String.fromEnvironment(
    'NEOAGENT_BACKEND_URL',
  );
  static const String _selectedSectionPrefsKey = 'ui.selectedSection';

  SharedPreferences? _prefs;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  io.Socket? _socket;
  Timer? _updatePollTimer;
  Timer? _qrLoginPollTimer;
  Timer? _manualRunCooldownTimer;
  final Set<String> _backgroundRunIds = <String>{};
  final Set<String> _voiceRunIds = <String>{};
  final Set<String> _busyOfficialIntegrationKeys = <String>{};
  final Map<String, DateTime> _manualRunCooldowns = <String, DateTime>{};
  static const Duration _manualRunCooldownDuration = Duration(seconds: 10);
  static const Duration _homeWidgetSyncCooldown = Duration(seconds: 5);
  DateTime? _lastHomeWidgetSyncAt;
  int _authCycle = 0;
  bool _isPollingQrLogin = false;
  bool _socketHasConnectedOnce = false;
  List<LogEntry> _serverLogs = const <LogEntry>[];
  List<LogEntry> _clientLogs = const <LogEntry>[];

  bool isBooting = true;
  bool showOnboarding = false;
  bool isAuthenticated = false;
  bool isAuthenticating = false;
  bool isAwaitingTwoFactor = false;
  bool isRefreshing = false;
  bool isRefreshingDevices = false;
  bool isSendingMessage = false;
  bool isSavingSettings = false;
  bool isSavingBackendUrl = false;
  bool isLoadingAccountSettings = false;
  bool isSavingAccountSettings = false;
  bool isConfiguringTwoFactor = false;
  bool isRevokingSession = false;
  bool isTriggeringUpdate = false;
  bool isSavingReleaseChannel = false;
  bool isSyncingHealth = false;
  bool isRunningDeviceAction = false;
  bool isPreparingQrLogin = false;
  bool isApprovingQrLogin = false;
  bool isCheckingAppUpdate = false;
  bool isOpeningAppUpdate = false;
  bool socketConnected = false;
  bool hasNetworkConnection = true;
  bool networkStatusKnown = false;
  bool _desktopFloatingToolbarPopupRequested = false;
  bool _voiceAssistantIncludeScreenContext = false;
  bool _didTrackAppOpen = false;
  bool _analyticsConfigured = false;
  bool _analyticsConsentResolved = false;
  bool _analyticsConsentGranted = false;

  io.Socket? get streamSocket => socketConnected ? _socket : null;

  bool hasUser = true;
  bool registrationOpen = false;
  bool serviceEmailConfigured = false;
  String deploymentProfile = 'private';
  String backendUrl = _defaultBackendUrl;
  String username = '';
  String email = '';
  String password = '';
  String pendingTwoFactorUsername = '';
  String? errorMessage;
  String? authInfoMessage;
  String? qrLoginErrorMessage;
  String appUpdateChannel = 'stable';
  bool appUpdateAutoCheckEnabled = true;
  String? installedAppVersion;
  app_release_updater.AppReleaseInfo? availableAppUpdate;
  String? appUpdateErrorMessage;
  DateTime? appUpdateLastCheckedAt;

  AppSection selectedSection = AppSection.chat;
  Map<String, dynamic>? user;
  Map<String, dynamic> accountTwoFactor = const <String, dynamic>{};
  List<AccountSessionItem> accountSessions = const <AccountSessionItem>[];
  List<AuthProviderCatalogItem> authProviders =
      const <AuthProviderCatalogItem>[];
  List<LinkedAuthProviderItem> linkedAuthProviders =
      const <LinkedAuthProviderItem>[];
  QrLoginChallenge? qrLoginChallenge;
  Map<String, dynamic> settings = const <String, dynamic>{};
  Map<String, dynamic>? versionInfo;
  Map<String, dynamic>? backendHealthStatus;
  HealthBridgeStatus? deviceHealthStatus;
  List<RecordingSessionItem> recordingSessions = const <RecordingSessionItem>[];

  List<ChatEntry> chatMessages = const <ChatEntry>[];
  List<AgentProfile> agentProfiles = const <AgentProfile>[];
  String? selectedAgentId;
  List<ModelMeta> supportedModels = const <ModelMeta>[];
  List<AiProviderMeta> aiProviders = const <AiProviderMeta>[];
  List<RunSummary> recentRuns = const <RunSummary>[];
  TokenUsageSnapshot? tokenUsage;
  UpdateStatusSnapshot updateStatus = const UpdateStatusSnapshot();
  List<LogEntry> logs = const <LogEntry>[];
  Map<String, MessagingPlatformStatus> messagingStatuses =
      const <String, MessagingPlatformStatus>{};
  List<MessagingMessage> messagingMessages = const <MessagingMessage>[];
  Map<String, MessagingAccessCatalog> messagingAccessCatalogs =
      const <String, MessagingAccessCatalog>{};
  MessagingQrState? pendingMessagingQr;
  final List<BlockedSenderNotice> _blockedSenderQueue = <BlockedSenderNotice>[];
  List<SkillItem> skills = const <SkillItem>[];
  List<StoreSkillItem> storeSkills = const <StoreSkillItem>[];
  List<OfficialIntegrationItem> officialIntegrations =
      const <OfficialIntegrationItem>[];
  MemoryOverview memoryOverview = const MemoryOverview();
  List<MemoryItem> memories = const <MemoryItem>[];
  List<MemoryItem> memoryRecallResults = const <MemoryItem>[];
  List<ConversationItem> memoryConversations = const <ConversationItem>[];
  List<TaskItem> taskItems = const <TaskItem>[];
  List<AiWidgetItem> widgets = const <AiWidgetItem>[];
  List<McpServerItem> mcpServers = const <McpServerItem>[];
  Map<String, dynamic> browserRuntime = const <String, dynamic>{};
  Map<String, dynamic> browserExtensionStatus = const <String, dynamic>{};
  List<Map<String, dynamic>> browserExtensionTokens =
      const <Map<String, dynamic>>[];
  Map<String, dynamic> androidRuntime = const <String, dynamic>{};
  Map<String, dynamic> desktopRuntime = const <String, dynamic>{};
  List<String> androidInstalledApps = const <String>[];
  List<Map<String, dynamic>> androidUiPreview = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> desktopDevices = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> desktopDisplays = const <Map<String, dynamic>>[];
  Map<String, dynamic> desktopPermissions = const <String, dynamic>{};
  String? selectedDesktopDeviceId;
  String? selectedBrowserExtensionTokenId;
  String? browserScreenshotPath;
  String? androidScreenshotPath;
  String? desktopScreenshotPath;
  String? browserLastResult;
  String? androidLastResult;
  String? desktopLastResult;
  String? androidUiDumpPath;
  final Map<String, RunDetailSnapshot> _runDetailsCache =
      <String, RunDetailSnapshot>{};
  String? _selectedWidgetId;
  String? _pendingChatDraft;
  List<SharedChatAttachment> _pendingSharedChatAttachments =
      const <SharedChatAttachment>[];

  ActiveRunState? activeRun;
  List<ToolEventItem> toolEvents = const <ToolEventItem>[];
  String streamingAssistant = '';
  bool isStartingRecording = false;
  bool isStoppingRecording = false;
  bool _isStartingLiveVoice = false;
  bool _isStoppingLiveVoice = false;
  bool _liveVoiceCaptureActive = false;
  DateTime? _liveVoiceCaptureStartedAt;
  bool _pendingLiveVoiceStop = false;
  int _liveVoiceTurnCounter = 0;
  String? _liveVoiceTurnId;
  final List<LiveVoiceBufferedChunk> _liveVoiceBufferedChunks =
      <LiveVoiceBufferedChunk>[];
  int _liveVoiceAckThrough = -1;
  int _liveVoiceFinalSequence = -1;
  bool _liveVoiceCommitPending = false;
  bool _liveVoiceAwaitingResponse = false;
  Map<String, dynamic>? _liveVoicePendingCommitPayload;
  DateTime? _liveVoiceRecoverableUntil;
  Timer? _liveVoiceRecoveryTimer;
  Completer<void>? _liveVoiceSessionOpenCompleter;
  VoiceAssistantLiveState voiceAssistantLiveState = VoiceAssistantLiveState();
  bool _desktopAskOnClose = true;
  bool _desktopKeepRunningOnClose = true;
  bool _desktopAutoShowFloatingToolbar = true;
  bool _desktopAssistantHotkeyEnabled = true;

  bool get desktopCompanionEnabled => _desktopCompanion.enabled;
  bool get isLauncherMode => appMode == NeoAgentAppMode.launcher;
  bool get desktopCompanionConnected => _desktopCompanion.connected;
  bool get desktopCompanionConnecting => _desktopCompanion.connecting;
  bool get desktopCompanionPaused => _desktopCompanion.paused;
  String get desktopCompanionLabel => _desktopCompanion.label;
  String? get desktopCompanionErrorMessage => _desktopCompanion.errorMessage;
  Map<String, Object?> get desktopCompanionStatus => _desktopCompanion.status;

  bool get hasLiveRun => isSendingMessage && activeRun != null;

  bool isOfficialIntegrationBusy(String key) =>
      _busyOfficialIntegrationKeys.contains(key);

  String get chatComposerHint => hasLiveRun
      ? 'Send a steering update or next-up note for the current run...'
      : 'Ask a question or start a task...';

  AgentProfile? get activeAgent {
    for (final agent in agentProfiles) {
      if (agent.id == selectedAgentId) {
        return agent;
      }
    }
    return agentProfiles.isEmpty ? null : agentProfiles.first;
  }

  String get activeAgentLabel => activeAgent?.displayName ?? 'Main';

  String? get _scopedAgentId => selectedAgentId;

  bool get requiresBackendUrlSetup =>
      !kIsWeb &&
      _configuredBackendUrl.trim().isEmpty &&
      backendUrl.trim().isEmpty;

  String agentLabelFor(String? id) {
    if (id == null || id.isEmpty) return 'Main';
    for (final agent in agentProfiles) {
      if (agent.id == id) return agent.displayName;
    }
    return 'Unknown agent';
  }

  String get chatStatusLabel {
    if (activeRun == null) {
      return 'Idle';
    }

    final base =
        '${activeRun!.phase} (${toolEvents.where((event) => event.status == 'running').length} active tools)';
    if (activeRun!.pendingSteeringCount > 0) {
      return '$base · ${activeRun!.pendingSteeringCount} steering queued';
    }
    if (hasLiveRun) {
      return '$base · new messages steer this run';
    }
    return base;
  }

  static String get _defaultBackendUrl {
    final configured = _configuredBackendUrl.trim();

    if (kIsWeb) {
      if (configured.isEmpty) {
        return '';
      }

      final configuredUri = Uri.tryParse(configured);
      final currentHost = Uri.base.host;
      final currentIsLoopback = _isLoopbackHost(currentHost);
      final configuredHost = configuredUri?.host ?? '';

      // If a web bundle was accidentally built against localhost and is later
      // served from a real host, prefer same-origin instead of bricking prod.
      if (!currentIsLoopback && _isLoopbackHost(configuredHost)) {
        return '';
      }

      return configured;
    }

    if (configured.isNotEmpty) {
      return configured;
    }

    return '';
  }

  static bool _isLoopbackHost(String host) {
    final normalized = host.trim().toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '::1' ||
        normalized == '[::1]';
  }

  @override
  void dispose() {
    AndroidAutoBridge.instance.onStartVoiceMode = null;
    AndroidAutoBridge.instance.onStopVoiceMode = null;
    _updatePollTimer?.cancel();
    _qrLoginPollTimer?.cancel();
    _manualRunCooldownTimer?.cancel();
    _liveVoiceRecoveryTimer?.cancel();
    _socket?.dispose();
    _diagnosticLogSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _appReleaseUpdater.dispose();
    unawaited(_analytics.dispose());
    _desktopCompanion.removeListener(notifyListeners);
    unawaited(_desktopCompanion.disconnect());
    _recordingBridge.removeListener(_handleRecordingBridgeChanged);
    _recordingBridge.dispose();
    unawaited(_liveVoiceCapture.dispose());
    _oauthLauncher.dispose();
    super.dispose();
  }

  RecordingRuntimeStatus get recordingRuntime => _recordingBridge.status;

  bool get desktopAskOnClose => _desktopAskOnClose;

  bool get desktopKeepRunningOnClose => _desktopKeepRunningOnClose;

  bool get desktopAutoShowFloatingToolbar => _desktopAutoShowFloatingToolbar;

  bool get desktopAssistantHotkeyEnabled => _desktopAssistantHotkeyEnabled;

  String? get sessionCookie => _backendClient.sessionCookie;

  bool get desktopFloatingToolbarPopupRequested =>
      _desktopFloatingToolbarPopupRequested;

  bool get voiceAssistantIncludeScreenContext =>
      _voiceAssistantIncludeScreenContext;

  bool get canCaptureVoiceAssistantScreenContext =>
      _desktopScreenCapture.isSupported;

  bool get showAnalyticsConsentBanner =>
      kIsWeb && _analyticsConfigured && !_analyticsConsentResolved;

  bool get analyticsConsentGranted =>
      _analyticsConsentResolved && _analyticsConsentGranted;

  bool get isLiveVoiceCaptureEngaged =>
      _isStartingLiveVoice || _liveVoiceCaptureActive;

  bool get appUpdaterConfigured =>
      !kIsWeb && app_release_updater.appUpdaterConfigured;

  bool get appUpdateAvailable => availableAppUpdate != null;

  bool get showOfflineBanner => networkStatusKnown && !hasNetworkConnection;

  String get offlineBannerMessage => isAuthenticated
      ? 'No network connection. NeoAgent will reconnect when the device is back online.'
      : 'No network connection. Connect to keep using NeoAgent.';

  String get appUpdateChannelLabel =>
      appUpdateChannel == 'beta' ? 'Beta' : 'Stable';

  String get appUpdateLastCheckedLabel {
    final checkedAt = appUpdateLastCheckedAt;
    if (checkedAt == null) {
      return 'Not checked yet';
    }
    final local = checkedAt.toLocal();
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:$minute';
  }

  bool get canStartDesktopRecording =>
      _supportsDesktopShell &&
      isAuthenticated &&
      !isBooting &&
      !requiresBackendUrlSetup &&
      backendUrl.trim().isNotEmpty &&
      !isStartingRecording &&
      !isLiveVoiceCaptureActive &&
      !isLiveVoiceCaptureStarting &&
      !recordingRuntime.active &&
      recordingRuntime.supportsSystemAudio;

  Map<String, Object?> _recordingRuntimeSnapshot() {
    final runtime = recordingRuntime;
    return <String, Object?>{
      'runtimeActive': runtime.active,
      'runtimePaused': runtime.paused,
      'runtimeSessionId': runtime.sessionId,
      'runtimeStartedAt': runtime.startedAt?.toIso8601String(),
      'runtimeError': runtime.errorMessage,
      'runtimeSupportsSystemAudio': runtime.supportsSystemAudio,
      'runtimeFloatingToolbarVisible': runtime.floatingToolbarVisible,
      'sessionsLoaded': recordingSessions.length,
    };
  }

  void _upsertRecordingSession(RecordingSessionItem session) {
    final existingIndex = recordingSessions.indexWhere(
      (item) => item.id == session.id,
    );
    if (existingIndex >= 0) {
      recordingSessions = <RecordingSessionItem>[
        ...recordingSessions.sublist(0, existingIndex),
        session,
        ...recordingSessions.sublist(existingIndex + 1),
      ];
      return;
    }
    recordingSessions = <RecordingSessionItem>[session, ...recordingSessions];
  }

  void _removeRecordingSession(String sessionId) {
    recordingSessions = recordingSessions
        .where((item) => item.id != sessionId)
        .toList();
  }

  void _appendChatMessage(
    String content, {
    required String role,
    required String platform,
    bool transient = false,
  }) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final previous = chatMessages.isNotEmpty ? chatMessages.last : null;
    if (previous != null &&
        previous.role == role &&
        previous.platform == platform &&
        previous.content.trim() == trimmed) {
      return;
    }

    chatMessages = <ChatEntry>[
      ...chatMessages,
      ChatEntry(
        id: '',
        role: role,
        content: trimmed,
        platform: platform,
        createdAt: DateTime.now(),
        transient: transient,
      ),
    ];
  }

  String _settingString(String key, String fallback, {bool lowercase = false}) {
    final value = settings[key]?.toString().trim() ?? '';
    if (value.isEmpty) {
      return fallback;
    }
    return lowercase ? value.toLowerCase() : value;
  }

  Future<void> _finalizeRecordingSessionQuietly(String? sessionId) async {
    final trimmed = sessionId?.trim() ?? '';
    if (trimmed.isEmpty) {
      return;
    }
    try {
      await _backendClient.finalizeRecordingSession(
        backendUrl,
        trimmed,
        stopReason: 'cancelled',
      );
    } catch (_) {}
  }

  Future<void> _startRecordingCapture({
    required String logKey,
    required Map<String, dynamic> payload,
    required Future<void> Function(String sessionId) startCapture,
  }) async {
    if (isStartingRecording || recordingRuntime.active) {
      return;
    }
    isStartingRecording = true;
    errorMessage = null;
    notifyListeners();

    String? sessionId;
    try {
      _logRecording('$logKey.request');
      final response = await _backendClient.createRecordingSession(
        backendUrl,
        payload,
      );
      final session = RecordingSessionItem.fromJson(
        _jsonMap(response['session']),
      );
      sessionId = session.id;
      _upsertRecordingSession(session);
      await startCapture(session.id);
      _logRecording(
        '$logKey.done',
        data: <String, Object?>{'sessionId': session.id},
      );
      notifyListeners();
    } catch (error) {
      _logRecording(
        '$logKey.failed',
        data: <String, Object?>{'sessionId': sessionId},
        error: error,
      );
      await _finalizeRecordingSessionQuietly(sessionId);
      errorMessage = _friendlyErrorMessage(error);
      await refreshRecordings();
    } finally {
      isStartingRecording = false;
      notifyListeners();
    }
  }

  void _logRecording(
    String event, {
    Map<String, Object?> data = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    AppDiagnostics.log(
      'recording.controller',
      event,
      data: <String, Object?>{..._recordingRuntimeSnapshot(), ...data},
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _logRecordingConsistency(String reason) {
    final activeSessionId = recordingRuntime.sessionId;
    RecordingSessionItem? activeSession;
    if (activeSessionId != null) {
      for (final session in recordingSessions) {
        if (session.id == activeSessionId) {
          activeSession = session;
          break;
        }
      }
    }

    final serverRecordingCount = recordingSessions
        .where((session) => session.status == 'recording')
        .length;

    _logRecording(
      'consistency.snapshot',
      data: <String, Object?>{
        'reason': reason,
        'activeSessionId': activeSessionId,
        'activeSessionStatus': activeSession?.status,
        'serverRecordingCount': serverRecordingCount,
      },
    );

    if (!recordingRuntime.active &&
        activeSession != null &&
        activeSession.status == 'recording') {
      _logRecording(
        'consistency.mismatch_runtime_inactive_server_recording',
        data: <String, Object?>{
          'reason': reason,
          'sessionId': activeSession.id,
        },
      );
    }

    if (recordingRuntime.active &&
        activeSession != null &&
        activeSession.status != 'recording') {
      _logRecording(
        'consistency.mismatch_runtime_active_server_not_recording',
        data: <String, Object?>{
          'reason': reason,
          'sessionId': activeSession.id,
          'serverStatus': activeSession.status,
        },
      );
    }
  }

  BlockedSenderNotice? get pendingBlockedSenderNotice =>
      _blockedSenderQueue.isEmpty ? null : _blockedSenderQueue.first;

  void _handleRecordingBridgeChanged() {
    _logRecording('bridge.changed');
    notifyListeners();
  }

  static LogEntry _logEntryFromDiagnostic(AppDiagnosticEntry entry) {
    final buffer = StringBuffer('[${entry.area}] ${entry.event}');
    if (entry.data.isNotEmpty) {
      buffer.write(' ${jsonEncode(entry.data)}');
    }
    if (entry.error != null && entry.error!.trim().isNotEmpty) {
      buffer.write('\nerror: ${entry.error}');
    }
    if (entry.stackTrace != null && entry.stackTrace!.trim().isNotEmpty) {
      buffer.write('\n${entry.stackTrace}');
    }
    return LogEntry(
      type: entry.error == null ? 'info' : 'error',
      message: buffer.toString(),
      timestamp: entry.timestamp,
      source: 'flutter',
    );
  }

  void _handleDiagnosticLogEntry(AppDiagnosticEntry entry) {
    final next = <LogEntry>[..._clientLogs, _logEntryFromDiagnostic(entry)];
    _clientLogs = next.length > _maxVisibleLogs
        ? next.sublist(next.length - _maxVisibleLogs)
        : next;
    _rebuildMergedLogs();
    notifyListeners();
  }

  void _setServerLogs(List<LogEntry> entries) {
    _serverLogs = entries.length > _maxVisibleLogs
        ? entries.sublist(entries.length - _maxVisibleLogs)
        : List<LogEntry>.from(entries, growable: false);
    _rebuildMergedLogs();
  }

  void _appendServerLog(LogEntry entry) {
    final next = <LogEntry>[..._serverLogs, entry];
    _serverLogs = next.length > _maxVisibleLogs
        ? next.sublist(next.length - _maxVisibleLogs)
        : next;
    _rebuildMergedLogs();
  }

  void _rebuildMergedLogs() {
    final merged = <LogEntry>[..._serverLogs, ..._clientLogs]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    logs = merged.length > _maxVisibleLogs
        ? merged.sublist(merged.length - _maxVisibleLogs)
        : merged;
  }

  Future<void> _handleRecordingStopped(String sessionId) async {
    _logRecording(
      'bridge.on_recording_stopped',
      data: <String, Object?>{'sessionId': sessionId},
    );
    try {
      await _backendClient.finalizeRecordingSession(
        backendUrl,
        sessionId,
        stopReason: 'ended',
      );
      _logRecording(
        'finalize.ok',
        data: <String, Object?>{'sessionId': sessionId, 'stopReason': 'ended'},
      );
      await refreshRecordings();
    } catch (error) {
      _logRecording(
        'finalize.failed',
        data: <String, Object?>{'sessionId': sessionId, 'stopReason': 'ended'},
        error: error,
      );
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> bootstrap() async {
    _prefs = await SharedPreferences.getInstance();
    await _desktopCompanion.bootstrap(_prefs!);
    final configured = _configuredBackendUrl.trim();
    final savedBackendUrl = _prefs?.getString('backend_url')?.trim() ?? '';
    backendUrl = configured.isNotEmpty ? _defaultBackendUrl : savedBackendUrl;
    username = _prefs?.getString('username') ?? '';
    password = '';
    _desktopAskOnClose = _prefs?.getBool('desktop.askOnClose') ?? true;
    _desktopKeepRunningOnClose =
        _prefs?.getBool('desktop.keepRunningOnClose') ?? true;
    _desktopAutoShowFloatingToolbar =
        _prefs?.getBool('desktop.autoShowFloatingToolbar') ?? true;
    _desktopAssistantHotkeyEnabled =
        _prefs?.getBool('desktop.assistantHotkeyEnabled') ?? true;
    _restoreSelectedSectionFromPrefs();
    _voiceAssistantIncludeScreenContext =
        (_prefs?.getBool('voiceAssistant.includeScreenContext') ?? false) &&
        canCaptureVoiceAssistantScreenContext;
    appUpdateChannel =
        _prefs?.getString('app.update.channel')?.trim().toLowerCase() == 'beta'
        ? 'beta'
        : 'stable';
    appUpdateAutoCheckEnabled =
        _prefs?.getBool('app.update.autoCheckEnabled') ?? true;
    installedAppVersion = await _safeLoadInstalledAppVersion();
    await _initializeAnalytics();
    await refreshConnectivityStatus();
    if (_connectivityPluginAvailable && _connectivitySubscription == null) {
      try {
        _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
          (results) {
            _applyConnectivityResults(results);
          },
          onError: (Object error, StackTrace stackTrace) {
            if (error is MissingPluginException) {
              _handleMissingConnectivityPlugin();
            }
          },
        );
      } on MissingPluginException {
        _handleMissingConnectivityPlugin();
      }
    }

    final savedCookieBackend =
        _prefs?.getString(_sessionCookieBackendPrefsKey)?.trim() ?? '';
    String savedCookie = '';
    try {
      savedCookie =
          (await _secureStorage.read(
            key: _sessionCookieSecureStorageKey,
          ))?.trim() ??
          '';
    } catch (_) {
      savedCookie = '';
    }
    if (savedCookie.isEmpty) {
      // Legacy fallback for older builds; migrate immediately to secure storage.
      savedCookie = _prefs?.getString(_sessionCookiePrefsKey)?.trim() ?? '';
      if (savedCookie.isNotEmpty) {
        try {
          await _secureStorage.write(
            key: _sessionCookieSecureStorageKey,
            value: savedCookie,
          );
          await _prefs?.remove(_sessionCookiePrefsKey);
        } catch (_) {}
      }
    }
    if (savedCookieBackend == backendUrl && savedCookie.isNotEmpty) {
      _backendClient.restoreSessionCookie(savedCookie);
    } else {
      _backendClient.clearSessionCookie();
    }

    await _recordingBridge.refreshStatus();
    notifyListeners();

    if (appUpdaterConfigured &&
        appUpdateAutoCheckEnabled &&
        hasNetworkConnection) {
      unawaited(checkForAppUpdates(silent: true));
    }

    if (requiresBackendUrlSetup) {
      isBooting = false;
      errorMessage = null;
      notifyListeners();
      return;
    }

    try {
      final status = await _backendClient.getAuthStatus(backendUrl);
      hasUser = status['hasUser'] != false;
      registrationOpen = status['registrationOpen'] == true;
      serviceEmailConfigured =
          (status['email'] is Map &&
          (status['email'] as Map)['configured'] == true);
      deploymentProfile = status['deploymentProfile']?.toString() ?? 'private';
      final rawAuthProviders = status['providers'];
      final authProviderRows = rawAuthProviders is List
          ? rawAuthProviders
          : rawAuthProviders is Map
          ? rawAuthProviders.values.toList(growable: false)
          : const <dynamic>[];
      authProviders = authProviderRows
          .whereType<Map<dynamic, dynamic>>()
          .map(AuthProviderCatalogItem.fromJson)
          .toList();

      if (status['authenticated'] == true &&
          status['user'] is Map<String, dynamic>) {
        user = Map<String, dynamic>.from(
          status['user'] as Map<String, dynamic>,
        );
        isAuthenticated = true;
      }
      if (isAuthenticated) {
        unawaited(refresh());
      }
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isBooting = false;
      notifyListeners();
    }
  }

  Future<String?> _safeLoadInstalledAppVersion() async {
    try {
      return await _appReleaseUpdater.currentVersion();
    } catch (_) {
      return null;
    }
  }

  Future<void> refreshConnectivityStatus() async {
    if (!_connectivityPluginAvailable) {
      if (!networkStatusKnown || !hasNetworkConnection) {
        networkStatusKnown = true;
        hasNetworkConnection = true;
        notifyListeners();
      }
      return;
    }
    try {
      final results = await Connectivity().checkConnectivity();
      _applyConnectivityResults(results);
    } on MissingPluginException {
      _handleMissingConnectivityPlugin();
    } catch (_) {
      if (!networkStatusKnown) {
        networkStatusKnown = true;
        hasNetworkConnection = true;
        notifyListeners();
      }
    }
  }

  void _applyConnectivityResults(List<ConnectivityResult> results) {
    final connected = results.any(
      (result) => result != ConnectivityResult.none,
    );
    final changed = !networkStatusKnown || connected != hasNetworkConnection;
    networkStatusKnown = true;
    hasNetworkConnection = connected;
    if (connected &&
        appUpdateErrorMessage ==
            'No network connection. Reconnect to check for updates.') {
      appUpdateErrorMessage = null;
    }
    if (changed) {
      notifyListeners();
    }
  }

  void _handleMissingConnectivityPlugin() {
    _connectivityPluginAvailable = false;
    unawaited(_connectivitySubscription?.cancel());
    _connectivitySubscription = null;
    if (!networkStatusKnown || !hasNetworkConnection) {
      networkStatusKnown = true;
      hasNetworkConnection = true;
      notifyListeners();
    }
  }

  Future<void> _initializeAnalytics() async {
    try {
      final runtimeConfig = await _backendClient.fetchRuntimeConfig(backendUrl);
      final analyticsConfig = runtimeConfig['analytics'];
      final mixpanelConfig = analyticsConfig is Map
          ? analyticsConfig['mixpanel']
          : null;
      final token = mixpanelConfig is Map
          ? mixpanelConfig['token']?.toString()
          : null;
      _analyticsConfigured = token != null && token.trim().isNotEmpty;
      final consentState = _prefs?.getBool('analytics.cookieConsent');
      // On web, require explicit opt-in (GDPR). On native, consent is implicit
      // unless the user has previously declined.
      _analyticsConsentResolved = consentState != null || !kIsWeb;
      _analyticsConsentGranted = kIsWeb
          ? consentState == true
          : consentState != false;
      await _analytics.initialize(
        token: token,
        consentGranted: _analyticsConsentGranted,
      );
      _trackAppOpenedIfNeeded();
    } catch (_) {
      _analyticsConfigured = false;
      _analyticsConsentResolved = false;
      _analyticsConsentGranted = false;
      await _analytics.initialize(token: null, consentGranted: false);
    }
  }

  void _trackAppOpenedIfNeeded({String? consentSource}) {
    if (!_analytics.enabled || _didTrackAppOpen) {
      return;
    }
    _didTrackAppOpen = true;
    unawaited(
      _analytics.trackAppOpened(
        appMode: appMode.name,
        platform: _analyticsPlatformLabel(),
        backendMode: backendUrl.trim().isEmpty ? 'same_origin' : 'custom',
        selectedSection: selectedSection.label,
        deploymentProfile: deploymentProfile,
        authenticated: isAuthenticated,
      ),
    );
    if (consentSource != null) {
      unawaited(
        _analytics.track(
          'analytics_consent_granted',
          properties: <String, Object?>{'consent_source': consentSource},
        ),
      );
    }
  }

  String _analyticsPlatformLabel() {
    if (kIsWeb) {
      return 'web';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  Future<void> acceptAnalyticsConsent() async {
    if (!_analyticsConfigured) {
      return;
    }
    _analyticsConsentResolved = true;
    _analyticsConsentGranted = true;
    await _prefs?.setBool('analytics.cookieConsent', true);
    await _analytics.setConsentGranted(true);
    _trackAppOpenedIfNeeded(consentSource: 'banner');
    notifyListeners();
  }

  Future<void> declineAnalyticsConsent() async {
    if (!_analyticsConfigured) {
      return;
    }
    _analyticsConsentResolved = true;
    _analyticsConsentGranted = false;
    await _prefs?.setBool('analytics.cookieConsent', false);
    await _analytics.setConsentGranted(false);
    notifyListeners();
  }

  Future<void> setAppUpdateChannel(String channel) async {
    final normalized = channel.trim().toLowerCase() == 'beta'
        ? 'beta'
        : 'stable';
    if (appUpdateChannel == normalized) {
      return;
    }
    appUpdateChannel = normalized;
    availableAppUpdate = null;
    appUpdateErrorMessage = null;
    await _prefs?.setString('app.update.channel', normalized);
    notifyListeners();
  }

  Future<void> setAppUpdateAutoCheckEnabled(bool enabled) async {
    appUpdateAutoCheckEnabled = enabled;
    await _prefs?.setBool('app.update.autoCheckEnabled', enabled);
    notifyListeners();
  }

  Future<void> checkForAppUpdates({bool silent = false}) async {
    if (isCheckingAppUpdate) {
      return;
    }
    unawaited(_analytics.trackAppUpdateCheck(silent: silent));
    if (!appUpdaterConfigured) {
      appUpdateErrorMessage = kIsWeb
          ? null
          : 'App updates are not configured for this build.';
      if (!silent) {
        notifyListeners();
      }
      return;
    }
    if (!hasNetworkConnection) {
      appUpdateErrorMessage =
          'No network connection. Reconnect to check for updates.';
      if (!silent) {
        notifyListeners();
      }
      return;
    }

    isCheckingAppUpdate = true;
    if (!silent) {
      appUpdateErrorMessage = null;
    }
    notifyListeners();

    try {
      final result = await _appReleaseUpdater.checkForUpdate(
        channel: appUpdateChannel,
        launcherMode: isLauncherMode,
      );
      installedAppVersion = result.currentVersion;
      appUpdateLastCheckedAt = DateTime.now();
      appUpdateErrorMessage = result.errorMessage;
      availableAppUpdate = result.updateAvailable ? result.release : null;
    } finally {
      isCheckingAppUpdate = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> testCliRuntime() =>
      _backendClient.testCli(backendUrl);

  Future<Map<String, dynamic>> testBrowserExtension() =>
      _backendClient.testExtension(backendUrl);

  Future<Map<String, dynamic>> testDesktopCompanion() =>
      _backendClient.testDesktop(backendUrl);

  Future<void> openAppUpdate() async {
    final release = availableAppUpdate;
    if (release == null || isOpeningAppUpdate) {
      return;
    }
    isOpeningAppUpdate = true;
    appUpdateErrorMessage = null;
    notifyListeners();
    try {
      final result = await _appReleaseUpdater.openReleaseAsset(
        launcher: _oauthLauncher,
        release: release,
      );
      if (!result.launched) {
        appUpdateErrorMessage =
            result.error ?? 'Could not open the release asset.';
      }
    } finally {
      isOpeningAppUpdate = false;
      notifyListeners();
    }
  }

  Future<bool> saveBackendUrl(String rawValue) async {
    final normalized = _normalizeBackendUrl(rawValue);
    if (normalized.isEmpty) {
      errorMessage = 'Enter the NeoAgent backend URL.';
      notifyListeners();
      return false;
    }

    isSavingBackendUrl = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _backendClient.getAuthStatus(normalized);
      await _prefs?.setString('backend_url', normalized);
      if (backendUrl != normalized) {
        _backendClient.clearSessionCookie();
        await _prefs?.remove(_sessionCookiePrefsKey);
        await _prefs?.remove(_sessionCookieBackendPrefsKey);
        try {
          await _secureStorage.delete(key: _sessionCookieSecureStorageKey);
        } catch (_) {}
      }
      backendUrl = normalized;
      isBooting = true;
      notifyListeners();
      await bootstrap();
      unawaited(
        _analytics.trackBackendUrlSaved(
          backendMode: backendUrl.trim().isEmpty ? 'same_origin' : 'custom',
        ),
      );
      return true;
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      return false;
    } finally {
      isSavingBackendUrl = false;
      if (requiresBackendUrlSetup) {
        isBooting = false;
      }
      notifyListeners();
    }
  }

  String _normalizeBackendUrl(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (trimmed.contains('://')) {
      return trimmed.replaceFirst(RegExp(r'/$'), '');
    }

    final lower = trimmed.toLowerCase();
    final is172Private = RegExp(
      r'^172\.(1[6-9]|2[0-9]|3[0-1])\.',
    ).hasMatch(lower);
    final isLocal =
        lower.startsWith('localhost') ||
        lower.startsWith('127.0.0.1') ||
        lower.startsWith('10.') ||
        lower.startsWith('192.168.') ||
        is172Private;
    final scheme = isLocal ? 'http://' : 'https://';
    return '$scheme${trimmed.replaceFirst(RegExp(r'/$'), '')}';
  }

  Map<String, dynamic> _qrLoginClientMetadata() {
    final platformLabel = switch (true) {
      _ when kIsWeb => 'Web browser',
      _ when defaultTargetPlatform == TargetPlatform.android => 'Android app',
      _ when defaultTargetPlatform == TargetPlatform.iOS => 'iPhone app',
      _ when defaultTargetPlatform == TargetPlatform.macOS => 'macOS app',
      _ when defaultTargetPlatform == TargetPlatform.windows => 'Windows app',
      _ when defaultTargetPlatform == TargetPlatform.linux => 'Linux app',
      _ => 'NeoAgent app',
    };
    final deviceClass = switch (true) {
      _ when kIsWeb => 'desktop',
      _
          when defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS =>
        'mobile',
      _
          when defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.linux =>
        'desktop',
      _ => 'unknown',
    };
    return <String, dynamic>{
      'deviceLabel': platformLabel,
      'platformLabel': platformLabel,
      'browserLabel': kIsWeb ? 'Browser' : 'Flutter app',
      'deviceClass': deviceClass,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'appMode': appMode.name,
    };
  }

  void _stopQrLoginPolling() {
    _qrLoginPollTimer?.cancel();
    _qrLoginPollTimer = null;
  }

  void _clearQrLoginChallenge() {
    _stopQrLoginPolling();
    qrLoginChallenge = null;
    qrLoginErrorMessage = null;
    _isPollingQrLogin = false;
  }

  void _ensureQrLoginPolling() {
    _stopQrLoginPolling();
    final challenge = qrLoginChallenge;
    if (challenge == null || !challenge.isUsable || isAuthenticated) {
      return;
    }
    _qrLoginPollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_pollQrLoginChallenge());
    });
  }

  Future<void> prepareQrLoginChallenge({bool force = false}) async {
    if (requiresBackendUrlSetup || isAuthenticated || isAwaitingTwoFactor) {
      _clearQrLoginChallenge();
      notifyListeners();
      return;
    }
    if (isPreparingQrLogin) return;
    if (!force && qrLoginChallenge?.isUsable == true) {
      _ensureQrLoginPolling();
      return;
    }

    isPreparingQrLogin = true;
    qrLoginErrorMessage = null;
    if (force) {
      qrLoginChallenge = null;
    }
    notifyListeners();

    try {
      final response = await _backendClient.createQrLoginChallenge(
        baseUrl: backendUrl,
        requestMetadata: _qrLoginClientMetadata(),
      );
      final challenge = QrLoginChallenge.fromJson(response);
      if (!challenge.isUsable) {
        throw Exception('QR login could not be started.');
      }
      qrLoginChallenge = challenge;
      qrLoginErrorMessage = null;
      _ensureQrLoginPolling();
    } catch (error) {
      _clearQrLoginChallenge();
      qrLoginErrorMessage = _friendlyErrorMessage(error);
    } finally {
      isPreparingQrLogin = false;
      notifyListeners();
    }
  }

  Future<void> _pollQrLoginChallenge() async {
    final challenge = qrLoginChallenge;
    if (_isPollingQrLogin || challenge == null || !challenge.isUsable) {
      return;
    }
    _isPollingQrLogin = true;
    try {
      final status = await _backendClient.getQrLoginChallengeStatus(
        baseUrl: backendUrl,
        challengeId: challenge.challengeId,
        pollToken: challenge.pollToken,
      );
      final nextStatus = status['status']?.toString() ?? 'pending';
      if (nextStatus == 'approved') {
        await _claimQrLoginChallenge(challenge);
        return;
      }
      if (nextStatus == 'expired' || nextStatus == 'claimed') {
        await prepareQrLoginChallenge(force: true);
      }
    } catch (error) {
      qrLoginErrorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    } finally {
      _isPollingQrLogin = false;
    }
  }

  Future<void> _claimQrLoginChallenge(QrLoginChallenge challenge) async {
    try {
      final response = await _backendClient.claimQrLoginChallenge(
        baseUrl: backendUrl,
        challengeId: challenge.challengeId,
        pollToken: challenge.pollToken,
      );
      _clearQrLoginChallenge();
      await _completeAuthenticatedResponse(
        response,
        retentionErrorMessage:
            'QR login completed, but NeoAgent could not keep the session. Please try again.',
        authMethod: 'qr',
      );
    } catch (error) {
      final message = _friendlyErrorMessage(error);
      qrLoginErrorMessage = message;
      if (message.toLowerCase().contains('expired') ||
          message.toLowerCase().contains('already used')) {
        await prepareQrLoginChallenge(force: true);
      } else {
        notifyListeners();
      }
    }
  }

  Future<QrLoginApprovalPreview> resolveQrLoginApproval(
    QrLoginScanPayload payload,
  ) async {
    final response = await _backendClient.resolveQrLoginChallenge(
      baseUrl: backendUrl,
      challengeId: payload.challengeId,
      secret: payload.secret,
    );
    return QrLoginApprovalPreview.fromJson(response);
  }

  Future<QrLoginApprovalPreview> approveQrLogin(
    QrLoginScanPayload payload,
  ) async {
    isApprovingQrLogin = true;
    errorMessage = null;
    notifyListeners();
    try {
      final response = await _backendClient.approveQrLoginChallenge(
        baseUrl: backendUrl,
        challengeId: payload.challengeId,
        secret: payload.secret,
        approvalMetadata: _qrLoginClientMetadata(),
      );
      return QrLoginApprovalPreview.fromJson(response);
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      rethrow;
    } finally {
      isApprovingQrLogin = false;
      notifyListeners();
    }
  }

  Future<void> _completeAuthenticatedResponse(
    Map<String, dynamic> response, {
    String? fallbackUsername,
    String? retentionErrorMessage,
    bool isRegistration = false,
    String authMethod = 'password',
  }) async {
    user = Map<String, dynamic>.from(
      response['user'] as Map<dynamic, dynamic>? ??
          <String, dynamic>{
            if (fallbackUsername != null && fallbackUsername.trim().isNotEmpty)
              'username': fallbackUsername.trim(),
          },
    );
    hasUser = true;
    isAuthenticated = true;
    isAwaitingTwoFactor = false;
    pendingTwoFactorUsername = '';
    password = '';

    final bool backendCompletedOnboarding =
        user?['hasCompletedOnboarding'] == true;
    showOnboarding = isRegistration || !backendCompletedOnboarding;

    _clearQrLoginChallenge();
    await _persistCredentials();
    await refresh();
    if (isAuthenticated) {
      unawaited(
        _analytics.trackSignedIn(
          authMethod: authMethod,
          isRegistration: isRegistration,
        ),
      );
    }
    if (!isAuthenticated && retentionErrorMessage != null) {
      errorMessage = retentionErrorMessage;
    }
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    this.username = username.trim();
    this.password = password;
    await _authenticate(register: false);
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    this.username = username.trim();
    this.email = email.trim();
    this.password = password;
    await _authenticate(register: true);
  }

  Future<void> authenticateWithProvider({
    required String provider,
    required bool register,
  }) async {
    isAuthenticating = true;
    errorMessage = null;
    authInfoMessage = null;
    notifyListeners();

    try {
      final begin = await _backendClient.beginProviderAuth(
        baseUrl: backendUrl,
        provider: provider,
        mode: register ? 'register' : 'login',
      );
      final url = begin['url']?.toString();
      final state = begin['state']?.toString();
      if (url == null || state == null || url.isEmpty || state.isEmpty) {
        throw Exception('Provider sign-in could not be started.');
      }
      final launchResult = await _oauthLauncher.launch(
        url: url,
        provider: provider,
      );
      if (!launchResult.launched) {
        throw Exception(
          launchResult.error ?? 'Could not open the provider sign-in page.',
        );
      }
      final response = await _pollForProviderAuthCompletion(state);
      if (response['requiresTwoFactor'] == true) {
        final responseUser =
            response['user'] as Map<dynamic, dynamic>? ??
            const <dynamic, dynamic>{};
        pendingTwoFactorUsername = responseUser['username']?.toString() ?? '';
        isAwaitingTwoFactor = true;
        isAuthenticated = false;
        password = '';
        await _persistCredentials();
        return;
      }
      await _completeAuthenticatedResponse(
        response,
        isRegistration: register,
        authMethod: 'oauth',
        retentionErrorMessage:
            'Sign-in completed, but NeoAgent could not keep the browser session. Please sign in again. If this keeps happening, check backend session cookie settings.',
      );
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      isAuthenticated = false;
    } finally {
      isAuthenticating = false;
      notifyListeners();
    }
  }

  Future<void> completeTwoFactorLogin({required String code}) async {
    isAuthenticating = true;
    errorMessage = null;
    authInfoMessage = null;
    notifyListeners();

    try {
      final response = await _backendClient.completeTwoFactorLogin(
        baseUrl: backendUrl,
        code: code.trim(),
      );
      await _completeAuthenticatedResponse(
        response,
        fallbackUsername: pendingTwoFactorUsername,
        authMethod: 'two_factor',
        retentionErrorMessage:
            'Two-factor sign-in completed, but NeoAgent could not keep the browser session. Please sign in again.',
      );
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      isAuthenticated = false;
    } finally {
      isAuthenticating = false;
      notifyListeners();
    }
  }

  Future<bool> requestPasswordReset(String account) async {
    isAuthenticating = true;
    errorMessage = null;
    authInfoMessage = null;
    notifyListeners();
    try {
      final response = await _backendClient.requestPasswordReset(
        baseUrl: backendUrl,
        account: account.trim(),
      );
      authInfoMessage =
          response['message']?.toString() ??
          'If that account has a confirmed email, NeoAgent will send a password reset link.';
      return true;
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      return false;
    } finally {
      isAuthenticating = false;
      notifyListeners();
    }
  }

  void cancelTwoFactorLogin() {
    isAwaitingTwoFactor = false;
    pendingTwoFactorUsername = '';
    password = '';
    notifyListeners();
  }

  Future<void> _authenticate({
    required bool register,
    bool silent = false,
  }) async {
    isAuthenticating = true;
    errorMessage = null;
    authInfoMessage = null;
    if (!silent) {
      notifyListeners();
    }

    try {
      final response = register
          ? await _backendClient.register(
              baseUrl: backendUrl,
              username: username,
              email: email,
              password: password,
            )
          : await _backendClient.login(
              baseUrl: backendUrl,
              username: username,
              password: password,
            );
      if (response['requiresTwoFactor'] == true) {
        pendingTwoFactorUsername = username;
        isAwaitingTwoFactor = true;
        isAuthenticated = false;
        password = '';
        await _persistCredentials();
        return;
      }
      if (response['requiresEmailConfirmation'] == true) {
        hasUser = true;
        isAuthenticated = false;
        isAwaitingTwoFactor = false;
        pendingTwoFactorUsername = '';
        password = '';
        authInfoMessage =
            response['message']?.toString() ??
            'Check your email to confirm your NeoAgent account before signing in.';
        await _persistCredentials();
        return;
      }
      await _completeAuthenticatedResponse(
        response,
        fallbackUsername: username,
        isRegistration: register,
        authMethod: 'password',
        retentionErrorMessage:
            'Sign-in completed, but NeoAgent could not keep the browser session. Please sign in again. If this keeps happening, the backend session cookie is likely not being retained.',
      );
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      isAuthenticated = false;
    } finally {
      isAuthenticating = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final recordingSessionId = recordingRuntime.sessionId;
    if (recordingRuntime.active && recordingSessionId != null) {
      try {
        await _recordingBridge.stopActiveRecording();
        if (!recordingRuntime.supportsBackgroundMic) {
          await _backendClient.finalizeRecordingSession(
            backendUrl,
            recordingSessionId,
            stopReason: 'ended',
          );
        }
      } catch (_) {}
    }

    final logoutFuture = _backendClient.logout(backendUrl);
    _authCycle += 1;
    _clearAuthenticatedState();
    unawaited(_analytics.trackSignedOut());
    isAuthenticating = true;
    notifyListeners();

    try {
      await logoutFuture;
    } catch (_) {}
    await _persistCredentials();
    isAuthenticating = false;
    notifyListeners();
  }

  Future<void> dismissOnboarding() async {
    showOnboarding = false;
    notifyListeners();
    try {
      await _backendClient.completeOnboarding(backendUrl);
      unawaited(_analytics.trackOnboardingDismissed());
      if (isAuthenticated && user != null) {
        user!['hasCompletedOnboarding'] = true;
      }
    } catch (e) {
      debugPrint('Failed to dismiss onboarding: $e');
      showOnboarding = true;
      notifyListeners();
    }
  }

  void reopenOnboarding() {
    showOnboarding = true;
    notifyListeners();
  }

  void _clearAuthenticatedState() {
    _disconnectSocket();
    _updatePollTimer?.cancel();
    _updatePollTimer = null;
    _clearQrLoginChallenge();
    isAuthenticated = false;
    isRefreshing = false;
    isAwaitingTwoFactor = false;
    pendingTwoFactorUsername = '';
    errorMessage = null;
    authInfoMessage = null;
    user = null;
    accountTwoFactor = const <String, dynamic>{};
    accountSessions = const <AccountSessionItem>[];
    linkedAuthProviders = const <LinkedAuthProviderItem>[];
    settings = const <String, dynamic>{};
    chatMessages = const <ChatEntry>[];
    agentProfiles = const <AgentProfile>[];
    selectedAgentId = null;
    supportedModels = const <ModelMeta>[];
    aiProviders = const <AiProviderMeta>[];
    recentRuns = const <RunSummary>[];
    tokenUsage = null;
    updateStatus = const UpdateStatusSnapshot();
    _serverLogs = const <LogEntry>[];
    _clientLogs = const <LogEntry>[];
    logs = const <LogEntry>[];
    messagingStatuses = const <String, MessagingPlatformStatus>{};
    messagingMessages = const <MessagingMessage>[];
    messagingAccessCatalogs = const <String, MessagingAccessCatalog>{};
    pendingMessagingQr = null;
    skills = const <SkillItem>[];
    storeSkills = const <StoreSkillItem>[];
    officialIntegrations = const <OfficialIntegrationItem>[];
    memoryOverview = const MemoryOverview();
    memories = const <MemoryItem>[];
    memoryRecallResults = const <MemoryItem>[];
    memoryConversations = const <ConversationItem>[];
    taskItems = const <TaskItem>[];
    widgets = const <AiWidgetItem>[];
    mcpServers = const <McpServerItem>[];
    browserRuntime = const <String, dynamic>{};
    browserExtensionStatus = const <String, dynamic>{};
    browserExtensionTokens = const <Map<String, dynamic>>[];
    androidRuntime = const <String, dynamic>{};
    desktopRuntime = const <String, dynamic>{};
    androidInstalledApps = const <String>[];
    androidUiPreview = const <Map<String, dynamic>>[];
    desktopDevices = const <Map<String, dynamic>>[];
    desktopDisplays = const <Map<String, dynamic>>[];
    desktopPermissions = const <String, dynamic>{};
    selectedDesktopDeviceId = null;
    selectedBrowserExtensionTokenId = null;
    browserScreenshotPath = null;
    androidScreenshotPath = null;
    desktopScreenshotPath = null;
    browserLastResult = null;
    androidLastResult = null;
    desktopLastResult = null;
    androidUiDumpPath = null;
    versionInfo = null;
    backendHealthStatus = null;
    recordingSessions = const <RecordingSessionItem>[];
    activeRun = null;
    toolEvents = const <ToolEventItem>[];
    streamingAssistant = '';
    selectedSection = AppSection.chat;
    unawaited(
      _prefs?.setString(_selectedSectionPrefsKey, AppSection.chat.name),
    );
    _selectedWidgetId = null;
    _pendingChatDraft = null;
    _runDetailsCache.clear();
    unawaited(
      _healthBridge.configureBackgroundSync(
        enabled: false,
        backendUrl: backendUrl,
        sessionCookie: '',
      ),
    );
    unawaited(
      _widgetBridge.configureHomeWidgets(
        enabled: false,
        backendUrl: backendUrl,
        sessionCookie: '',
      ),
    );
    unawaited(_syncDesktopCompanionSession());
  }

  Future<void> _persistCredentials() async {
    await _prefs?.setString('username', username);
    await _prefs?.remove('password');
    final sessionCookie = _backendClient.sessionCookie?.trim() ?? '';
    final shouldPersistSession = isAuthenticated && sessionCookie.isNotEmpty;
    if (shouldPersistSession) {
      try {
        await _secureStorage.write(
          key: _sessionCookieSecureStorageKey,
          value: sessionCookie,
        );
      } catch (_) {}
      await _prefs?.remove(_sessionCookiePrefsKey);
      await _prefs?.setString(_sessionCookieBackendPrefsKey, backendUrl);
      await _syncDesktopCompanionSession();
      unawaited(_syncHomeWidgetConfig());
      return;
    }
    await _prefs?.remove(_sessionCookiePrefsKey);
    await _prefs?.remove(_sessionCookieBackendPrefsKey);
    try {
      await _secureStorage.delete(key: _sessionCookieSecureStorageKey);
    } catch (_) {}
    await _syncDesktopCompanionSession();
    unawaited(_syncHomeWidgetConfig());
  }

  void _restoreSelectedSectionFromPrefs() {
    final rawSection =
        _prefs?.getString(_selectedSectionPrefsKey)?.trim() ?? '';
    if (rawSection.isEmpty) {
      return;
    }

    final restoredSection = AppSection.values.firstWhere(
      (section) => section.name == rawSection,
      orElse: () => AppSection.chat,
    );
    selectedSection = restoredSection;
  }

  Future<void> _syncDesktopCompanionSession() {
    return _desktopCompanion.updateSession(
      backendUrl: backendUrl,
      sessionCookie: _backendClient.sessionCookie ?? '',
      authenticated: isAuthenticated,
    );
  }

  void setSelectedSection(AppSection section) {
    final previousSection = selectedSection;
    selectedSection = section;
    unawaited(_prefs?.setString(_selectedSectionPrefsKey, section.name));
    if (section == AppSection.devices) {
      unawaited(refreshDevices());
    }
    if (section == AppSection.accountSettings) {
      unawaited(refreshAccountSettings());
    }
    if (previousSection != section) {
      unawaited(
        _analytics.trackSectionChanged(
          section: section.label,
          previousSection: previousSection.label,
        ),
      );
    }
    notifyListeners();
  }

  void _ensureSelectedAgent() {
    if (agentProfiles.isEmpty) {
      selectedAgentId = null;
      return;
    }
    final selectedExists = agentProfiles.any(
      (agent) => agent.id == selectedAgentId,
    );
    if (selectedExists) {
      return;
    }
    selectedAgentId = agentProfiles
        .firstWhere(
          (agent) => agent.isDefault,
          orElse: () => agentProfiles.first,
        )
        .id;
  }

  Future<void> switchAgent(String id) async {
    if (selectedAgentId == id) {
      return;
    }
    selectedAgentId = id;
    chatMessages = const <ChatEntry>[];
    recentRuns = const <RunSummary>[];
    messagingStatuses = const <String, MessagingPlatformStatus>{};
    messagingMessages = const <MessagingMessage>[];
    messagingAccessCatalogs = const <String, MessagingAccessCatalog>{};
    officialIntegrations = const <OfficialIntegrationItem>[];
    memoryOverview = const MemoryOverview();
    memories = const <MemoryItem>[];
    memoryRecallResults = const <MemoryItem>[];
    memoryConversations = const <ConversationItem>[];
    _runDetailsCache.clear();
    notifyListeners();
    await refresh();
  }

  Future<bool> saveAgentProfile({
    String? id,
    required String displayName,
    required String slug,
    String description = '',
    String responsibilities = '',
    String instructions = '',
    String status = 'active',
    bool canDelegate = false,
    bool canBeDelegatedTo = true,
    List<String> delegateTargets = const <String>[],
  }) async {
    final payload = <String, dynamic>{
      'displayName': displayName,
      'slug': slug,
      'description': description,
      'responsibilities': responsibilities,
      'instructions': instructions,
      'status': status,
      'canDelegate': canDelegate,
      'canBeDelegatedTo': canBeDelegatedTo,
      'delegateTargets': delegateTargets,
    };
    try {
      if (id == null) {
        final created = AgentProfile.fromJson(
          await _backendClient.createAgentProfile(backendUrl, payload),
        );
        selectedAgentId = created.id;
      } else {
        await _backendClient.updateAgentProfile(backendUrl, id, payload);
        selectedAgentId = id;
      }
      await refresh();
      return true;
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
      return false;
    }
  }

  Future<void> makeAgentDefault(String id) async {
    try {
      await _backendClient.setDefaultAgentProfile(backendUrl, id);
      selectedAgentId = id;
      await refresh();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> archiveAgent(String id) async {
    try {
      await _backendClient.archiveAgentProfile(backendUrl, id);
      if (selectedAgentId == id) {
        selectedAgentId = null;
      }
      await refresh();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  void showInlineError(String message) {
    errorMessage = message;
    authInfoMessage = null;
    notifyListeners();
  }

  Future<Map<String, dynamic>> _pollForProviderAuthCompletion(
    String state,
  ) async {
    final deadline = DateTime.now().add(const Duration(minutes: 2));
    final authCycle = _authCycle;
    while (DateTime.now().isBefore(deadline)) {
      if (!isAuthenticating || _authCycle != authCycle) {
        throw Exception('Authentication was canceled before completion.');
      }
      final response = await _backendClient.completeProviderAuth(
        baseUrl: backendUrl,
        state: state,
      );
      if (response['status']?.toString() == 'pending') {
        if (!isAuthenticating || _authCycle != authCycle) {
          throw Exception('Authentication was canceled before completion.');
        }
        await Future<void>.delayed(const Duration(seconds: 2));
        continue;
      }
      return response;
    }
    throw Exception(
      'Authentication is still pending. Finish the browser flow and try again.',
    );
  }

  void clearLogs() {
    _serverLogs = const <LogEntry>[];
    _clientLogs = const <LogEntry>[];
    logs = const <LogEntry>[];
    notifyListeners();
  }

  MessagingAccessCatalog currentMessagingAccessCatalog(String platform) {
    return messagingAccessCatalogs[platform] ??
        MessagingAccessCatalog.empty(platform);
  }

  MessagingAccessPolicy currentMessagingAccessPolicy(String platform) {
    return currentMessagingAccessCatalog(platform).policy;
  }

  List<MessagingAccessRule> _dedupeAccessRules(
    List<MessagingAccessRule> rules,
  ) {
    final seen = <String>{};
    final result = <MessagingAccessRule>[];
    for (final rule in rules) {
      if (rule.value.trim().isEmpty) continue;
      if (!seen.add(rule.id)) continue;
      result.add(rule);
    }
    return result;
  }

  MessagingAccessPolicy _policyWithAddedRule(
    MessagingAccessPolicy policy,
    QuickAllowSuggestion suggestion,
  ) {
    switch (suggestion.bucket) {
      case 'directRules':
        return policy.copyWith(
          directPolicy: policy.directPolicy == 'disabled'
              ? 'allowlist'
              : policy.directPolicy,
          directRules: _dedupeAccessRules(<MessagingAccessRule>[
            ...policy.directRules,
            suggestion.rule,
          ]),
        );
      case 'sharedActorRules':
        return policy.copyWith(
          sharedPolicy: policy.sharedPolicy == 'disabled'
              ? 'allowlist'
              : policy.sharedPolicy,
          sharedActorRules: _dedupeAccessRules(<MessagingAccessRule>[
            ...policy.sharedActorRules,
            suggestion.rule,
          ]),
        );
      default:
        return policy.copyWith(
          sharedPolicy: policy.sharedPolicy == 'disabled'
              ? 'allowlist'
              : policy.sharedPolicy,
          sharedSpaceRules: _dedupeAccessRules(<MessagingAccessRule>[
            ...policy.sharedSpaceRules,
            suggestion.rule,
          ]),
        );
    }
  }

  Future<MessagingAccessCatalog> loadMessagingAccessCatalog(
    String platform, {
    bool force = false,
  }) async {
    if (!force && messagingAccessCatalogs.containsKey(platform)) {
      return messagingAccessCatalogs[platform]!;
    }
    final data = await _backendClient.fetchMessagingAccessPolicy(
      backendUrl,
      platform: platform,
      agentId: _scopedAgentId,
    );
    final catalog = MessagingAccessCatalog.fromJson(platform, data);
    messagingAccessCatalogs = <String, MessagingAccessCatalog>{
      ...messagingAccessCatalogs,
      platform: catalog,
    };
    notifyListeners();
    return catalog;
  }

  Future<void> allowMessagingSuggestion(
    String platform,
    QuickAllowSuggestion suggestion,
  ) async {
    try {
      final nextPolicy = _policyWithAddedRule(
        currentMessagingAccessPolicy(platform),
        suggestion,
      );
      await saveMessagingAccessPolicy(platform, nextPolicy);
      errorMessage = null;
      notifyListeners();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  void consumeBlockedSenderNotice(String id) {
    if (_blockedSenderQueue.isNotEmpty && _blockedSenderQueue.first.id == id) {
      _blockedSenderQueue.removeAt(0);
    } else {
      _blockedSenderQueue.removeWhere((notice) => notice.id == id);
    }
    notifyListeners();
  }

  void _enqueueBlockedSenderNotice(BlockedSenderNotice notice) {
    final exists = _blockedSenderQueue.any((item) => item.id == notice.id);
    if (!exists) {
      _blockedSenderQueue.add(notice);
    }
  }

  MessagingQrState? _derivePendingMessagingQr(
    Map<String, MessagingPlatformStatus> statuses,
  ) {
    for (final entry in statuses.entries) {
      final status = entry.value;
      final qr = status.authInfo['qrCode']?.toString() ?? '';
      if (status.status == 'awaiting_qr' && qr.trim().isNotEmpty) {
        return MessagingQrState(platform: entry.key, qr: qr);
      }
    }
    return null;
  }

  Future<void> refresh() async {
    if (!isAuthenticated) {
      return;
    }

    final authCycle = _authCycle;
    isRefreshing = true;
    errorMessage = null;
    notifyListeners();

    try {
      final authStatus = await _backendClient.getAuthStatus(backendUrl);
      if (!_isCurrentAuthCycle(authCycle)) {
        return;
      }
      if (authStatus['authenticated'] != true ||
          authStatus['user'] is! Map<String, dynamic>) {
        final hadAuthenticatedSession = isAuthenticated;
        _authCycle += 1;
        _clearAuthenticatedState();
        if (hadAuthenticatedSession) {
          errorMessage =
              'Your session expired or was not retained by the browser. Please sign in again.';
          notifyListeners();
        }
        return;
      }

      user = Map<String, dynamic>.from(
        authStatus['user'] as Map<String, dynamic>,
      );

      final profilesResponse = await _backendClient.fetchAgentProfiles(
        backendUrl,
      );
      if (!_isCurrentAuthCycle(authCycle)) {
        return;
      }
      agentProfiles = _decodeModelList(
        'agent_profiles',
        profilesResponse['agents'],
        AgentProfile.fromJson,
        fallbackToMapValues: true,
      ).where((agent) => agent.id.isNotEmpty).toList();
      _ensureSelectedAgent();
      final agentId = _scopedAgentId;

      final historyFuture = _softRefreshLoad<Map<String, dynamic>>(
        'chat_history',
        _backendClient.fetchChatHistory(backendUrl, agentId: agentId),
        const <String, dynamic>{'messages': <dynamic>[]},
      );
      final modelsFuture = _softRefreshLoad<Map<String, dynamic>>(
        'supported_models',
        _backendClient.fetchSupportedModels(backendUrl, agentId: agentId),
        const <String, dynamic>{'models': <dynamic>[]},
      );
      final providersFuture = _softRefreshLoad<Map<String, dynamic>>(
        'ai_providers',
        _backendClient.fetchAiProviders(backendUrl, agentId: agentId),
        const <String, dynamic>{'providers': <dynamic>[]},
      );
      final settingsFuture = _softRefreshLoad<Map<String, dynamic>>(
        'settings',
        _backendClient.fetchSettings(backendUrl, agentId: agentId),
        const <String, dynamic>{},
      );
      final runsFuture = _softRefreshLoad<Map<String, dynamic>>(
        'runs',
        _backendClient.fetchRuns(backendUrl, agentId: agentId),
        const <String, dynamic>{'runs': <dynamic>[]},
      );
      final versionFuture = _softRefreshLoad<Map<String, dynamic>>(
        'version',
        _backendClient.fetchVersion(backendUrl),
        const <String, dynamic>{},
      );
      final tokenFuture = _softRefreshLoad<Map<String, dynamic>>(
        'token_usage',
        _backendClient.fetchTokenUsageSummary(backendUrl, agentId: agentId),
        const <String, dynamic>{},
      );
      final updateFuture = _backendClient
          .fetchUpdateStatus(backendUrl)
          .catchError((_) => const <String, dynamic>{});
      final messagingFuture = _softRefreshLoad<Map<String, dynamic>>(
        'messaging_status',
        _backendClient.fetchMessagingStatus(backendUrl, agentId: agentId),
        const <String, dynamic>{},
      );
      final messagingMessagesFuture =
          _softRefreshLoad<List<Map<String, dynamic>>>(
            'messaging_messages',
            _backendClient.fetchMessagingMessages(backendUrl, agentId: agentId),
            const <Map<String, dynamic>>[],
          );
      final skillsFuture = _softRefreshLoad<List<Map<String, dynamic>>>(
        'skills',
        _backendClient.fetchSkills(backendUrl),
        const <Map<String, dynamic>>[],
      );
      final storeSkillsFuture = _softRefreshLoad<List<Map<String, dynamic>>>(
        'skill_store',
        _backendClient.fetchSkillStore(backendUrl),
        const <Map<String, dynamic>>[],
      );
      final officialIntegrationsFuture =
          _softRefreshLoad<List<Map<String, dynamic>>>(
            'official_integrations',
            _backendClient.fetchOfficialIntegrations(
              backendUrl,
              agentId: agentId,
            ),
            const <Map<String, dynamic>>[],
          );
      final memoryFuture = _softRefreshLoad<Map<String, dynamic>>(
        'memory_overview',
        _backendClient.fetchMemoryOverview(backendUrl, agentId: agentId),
        const <String, dynamic>{},
      );
      final memoriesFuture = _softRefreshLoad<List<Map<String, dynamic>>>(
        'memories',
        _backendClient.fetchMemories(backendUrl, agentId: agentId),
        const <Map<String, dynamic>>[],
      );
      final conversationsFuture = _softRefreshLoad<List<Map<String, dynamic>>>(
        'memory_conversations',
        _backendClient.fetchConversations(backendUrl, agentId: agentId),
        const <Map<String, dynamic>>[],
      );
      final tasksFuture = _softRefreshLoad<List<Map<String, dynamic>>>(
        'tasks',
        _backendClient.fetchTasks(backendUrl, agentId: agentId),
        const <Map<String, dynamic>>[],
      );
      final widgetsFuture = _softRefreshLoad<List<Map<String, dynamic>>>(
        'widgets',
        _backendClient.fetchWidgets(backendUrl, agentId: agentId),
        const <Map<String, dynamic>>[],
      );
      final mcpFuture = _softRefreshLoad<List<Map<String, dynamic>>>(
        'mcp_servers',
        _backendClient.fetchMcpServers(backendUrl, agentId: agentId),
        const <Map<String, dynamic>>[],
      );
      final recordingsFuture = _backendClient
          .fetchRecordingSessions(backendUrl)
          .catchError((_) => const <Map<String, dynamic>>[]);
      final browserFuture = _backendClient
          .fetchBrowserStatus(backendUrl)
          .catchError((_) => const <String, dynamic>{});
      final browserExtensionFuture = _backendClient
          .fetchBrowserExtensionStatus(backendUrl)
          .catchError((_) => const <String, dynamic>{});
      final androidFuture = _backendClient
          .fetchAndroidStatus(backendUrl)
          .catchError((_) => const <String, dynamic>{});
      final desktopFuture = _backendClient
          .fetchDesktopStatus(backendUrl)
          .catchError((_) => const <String, dynamic>{});

      Map<String, dynamic>? healthResponse;
      try {
        healthResponse = await _softRefreshLoad<Map<String, dynamic>>(
          'health_status',
          _backendClient.fetchHealthStatus(backendUrl),
          const <String, dynamic>{},
        );
      } catch (_) {
        healthResponse = null;
      }
      if (!_isCurrentAuthCycle(authCycle)) {
        return;
      }

      officialIntegrations = _decodeModelList(
        'official_integrations',
        await officialIntegrationsFuture,
        OfficialIntegrationItem.fromJson,
      );
      if (!_isCurrentAuthCycle(authCycle)) {
        return;
      }

      final history = await historyFuture;
      final modelsResponse = await modelsFuture;
      final providersResponse = await providersFuture;
      final settingsResponse = await settingsFuture;
      final runsResponse = await runsFuture;
      final versionResponse = await versionFuture;
      final tokenResponse = await tokenFuture;
      final updateResponse = await updateFuture;
      final messagingResponse = await messagingFuture;
      final messagingMessagesResponse = await messagingMessagesFuture;
      final skillsResponse = await skillsFuture;
      final storeSkillsResponse = await storeSkillsFuture;
      final memoryResponse = await memoryFuture;
      final memoriesResponse = await memoriesFuture;
      final conversationsResponse = await conversationsFuture;
      final tasksResponse = await tasksFuture;
      final widgetsResponse = await widgetsFuture;
      final mcpResponse = await mcpFuture;
      final recordingsResponse = await recordingsFuture;
      final browserResponse = await browserFuture;
      final browserExtensionResponse = await browserExtensionFuture;
      final androidResponse = await androidFuture;
      final desktopResponse = await desktopFuture;
      if (!_isCurrentAuthCycle(authCycle)) {
        return;
      }

      chatMessages = _decodeModelList(
        'chat_history',
        history['messages'],
        ChatEntry.fromJson,
        fallbackToMapValues: true,
      );

      supportedModels = _decodeModelList(
        'supported_models',
        modelsResponse['models'],
        ModelMeta.fromJson,
        fallbackToMapValues: true,
      );

      aiProviders = _decodeModelList(
        'ai_providers',
        providersResponse['providers'],
        AiProviderMeta.fromJson,
        fallbackToMapValues: true,
      );

      settings = Map<String, dynamic>.from(settingsResponse);
      recentRuns = _decodeModelList(
        'runs',
        runsResponse['runs'],
        RunSummary.fromJson,
        fallbackToMapValues: true,
      );
      versionInfo = versionResponse;
      backendHealthStatus = healthResponse;
      tokenUsage = TokenUsageSnapshot.fromJson(tokenResponse);
      updateStatus = UpdateStatusSnapshot.fromJson(updateResponse);
      messagingStatuses = messagingResponse.map(
        (key, value) => MapEntry(
          key,
          MessagingPlatformStatus.fromJson(
            key,
            value is Map
                ? Map<String, dynamic>.from(value)
                : const <String, dynamic>{},
          ),
        ),
      );
      pendingMessagingQr = _derivePendingMessagingQr(messagingStatuses);
      messagingMessages = _decodeModelList(
        'messaging_messages',
        messagingMessagesResponse,
        MessagingMessage.fromJson,
      );
      skills = _decodeModelList('skills', skillsResponse, SkillItem.fromJson);
      storeSkills = _decodeModelList(
        'skill_store',
        storeSkillsResponse,
        StoreSkillItem.fromJson,
      );
      memoryOverview = MemoryOverview.fromJson(memoryResponse);
      memories = _decodeModelList(
        'memories',
        memoriesResponse,
        MemoryItem.fromJson,
      );
      memoryConversations = _decodeModelList(
        'memory_conversations',
        conversationsResponse,
        ConversationItem.fromJson,
      );
      taskItems = _decodeModelList('tasks', tasksResponse, TaskItem.fromJson);
      widgets = _decodeModelList(
        'widgets',
        widgetsResponse,
        AiWidgetItem.fromJson,
      );
      _selectedWidgetId =
          widgets.any((widget) => widget.id == _selectedWidgetId)
          ? _selectedWidgetId
          : (widgets.isEmpty ? null : widgets.first.id);
      mcpServers = _decodeModelList(
        'mcp_servers',
        mcpResponse,
        McpServerItem.fromJson,
      );
      recordingSessions = _decodeModelList(
        'recordings',
        recordingsResponse,
        RecordingSessionItem.fromJson,
      );
      browserRuntime = Map<String, dynamic>.from(browserResponse);
      browserExtensionStatus = Map<String, dynamic>.from(
        browserExtensionResponse,
      );
      browserExtensionTokens = _jsonMapList(
        browserExtensionStatus['tokens'],
        fallbackToMapValues: true,
      );
      selectedBrowserExtensionTokenId = _optionalIdFrom(
        browserExtensionStatus['selectedTokenId'],
      );
      androidRuntime = Map<String, dynamic>.from(androidResponse);
      desktopRuntime = Map<String, dynamic>.from(desktopResponse);
      selectedDesktopDeviceId =
          desktopRuntime['selectedDeviceId']?.toString().trim().isEmpty ?? true
          ? null
          : desktopRuntime['selectedDeviceId']?.toString();
      desktopDevices = _jsonMapList(
        desktopRuntime['devices'],
        fallbackToMapValues: true,
      );
      await _recordingBridge.refreshStatus();
      if (!_isCurrentAuthCycle(authCycle)) {
        return;
      }
      deviceHealthStatus = await _healthBridge.getStatus();
      if (!_isCurrentAuthCycle(authCycle)) {
        return;
      }
      await _syncBackgroundHealthConfig();
      if (!_isCurrentAuthCycle(authCycle)) {
        return;
      }
      await _syncHomeWidgetConfig();
      if (!_isCurrentAuthCycle(authCycle)) {
        return;
      }
      await _syncDesktopCompanionSession();
      if (!_isCurrentAuthCycle(authCycle)) {
        return;
      }
      _ensureSocketConnected();
      _ensureUpdatePolling();
    } catch (error) {
      if (_isCurrentAuthCycle(authCycle)) {
        errorMessage = _friendlyErrorMessage(error);
      }
    } finally {
      isRefreshing = false;
      notifyListeners();
    }
  }

  bool _isCurrentAuthCycle(int authCycle) =>
      isAuthenticated && _authCycle == authCycle;

  Future<T> _softRefreshLoad<T>(
    String label,
    Future<T> future,
    T fallback,
  ) async {
    try {
      return await future;
    } catch (error, stackTrace) {
      AppDiagnostics.log(
        'ui.refresh',
        '$label.failed',
        error: error,
        stackTrace: stackTrace,
      );
      return fallback;
    }
  }

  List<T> _decodeModelList<T>(
    String label,
    dynamic raw,
    T Function(Map<dynamic, dynamic> json) fromJson, {
    bool fallbackToMapValues = false,
  }) {
    final rows = _jsonMapList(raw, fallbackToMapValues: fallbackToMapValues);
    if (rows.isEmpty) {
      return <T>[];
    }

    final parsed = <T>[];
    for (var index = 0; index < rows.length; index += 1) {
      final row = rows[index];
      try {
        parsed.add(fromJson(row));
      } catch (error, stackTrace) {
        AppDiagnostics.log(
          'ui.refresh',
          '$label.item_parse_failed',
          data: <String, Object?>{
            'index': index,
            'keys': row.keys.take(16).join(','),
          },
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    return parsed;
  }

  String? _optionalIdFrom(dynamic value) {
    final normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty || normalized == 'null' ? null : normalized;
  }

  Future<void> refreshRunsOnly() async {
    try {
      final runsResponse = await _backendClient.fetchRuns(
        backendUrl,
        agentId: _scopedAgentId,
      );
      recentRuns = _decodeModelList(
        'runs',
        runsResponse['runs'],
        RunSummary.fromJson,
        fallbackToMapValues: true,
      );
      _runDetailsCache.clear();
      tokenUsage = TokenUsageSnapshot.fromJson(
        await _backendClient.fetchTokenUsageSummary(
          backendUrl,
          agentId: _scopedAgentId,
        ),
      );
      notifyListeners();
    } catch (_) {}

    Future<String> fetchMemoryTransferPrompt() async {
      final response = await _backendClient.fetchMemoryTransferPrompt(
        backendUrl,
        agentId: _scopedAgentId,
      );
      return response['prompt']?.toString() ?? '';
    }

    Future<MemoryTransferImportResult> importMemoryTransfer(
      String text, {
      bool applyBehaviorNotes = true,
      bool applyCoreMemory = true,
    }) async {
      final response = await _backendClient.importMemoryTransfer(
        backendUrl,
        text: text,
        applyBehaviorNotes: applyBehaviorNotes,
        applyCoreMemory: applyCoreMemory,
        agentId: _scopedAgentId,
      );
      final result = MemoryTransferImportResult.fromJson(response);
      await refreshMemory();
      return result;
    }
  }

  Future<void> refreshMessaging() async {
    try {
      final statuses = await _backendClient.fetchMessagingStatus(
        backendUrl,
        agentId: _scopedAgentId,
      );
      messagingStatuses = statuses.map(
        (key, value) => MapEntry(
          key,
          MessagingPlatformStatus.fromJson(
            key,
            value is Map
                ? Map<String, dynamic>.from(value)
                : const <String, dynamic>{},
          ),
        ),
      );
      pendingMessagingQr = _derivePendingMessagingQr(messagingStatuses);
      messagingMessages = _decodeModelList(
        'messaging_messages',
        await _backendClient.fetchMessagingMessages(
          backendUrl,
          agentId: _scopedAgentId,
        ),
        MessagingMessage.fromJson,
      );
      final policyResponses = await Future.wait(
        messagingPlatforms.map((platform) async {
          try {
            final data = await _backendClient.fetchMessagingAccessPolicy(
              backendUrl,
              platform: platform.id,
              agentId: _scopedAgentId,
            );
            return MapEntry(
              platform.id,
              MessagingAccessCatalog.fromJson(platform.id, data),
            );
          } catch (_) {
            return MapEntry(
              platform.id,
              MessagingAccessCatalog.empty(platform.id),
            );
          }
        }),
      );
      messagingAccessCatalogs = Map<String, MessagingAccessCatalog>.fromEntries(
        policyResponses,
      );
      notifyListeners();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> refreshSkills() async {
    skills = _decodeModelList(
      'skills',
      await _backendClient.fetchSkills(backendUrl),
      SkillItem.fromJson,
    );
    storeSkills = _decodeModelList(
      'skill_store',
      await _backendClient.fetchSkillStore(backendUrl),
      StoreSkillItem.fromJson,
    );
    try {
      officialIntegrations = _decodeModelList(
        'official_integrations',
        await _backendClient.fetchOfficialIntegrations(
          backendUrl,
          agentId: _scopedAgentId,
        ),
        OfficialIntegrationItem.fromJson,
      );
    } catch (_) {
      officialIntegrations = const <OfficialIntegrationItem>[];
    }
    notifyListeners();
  }

  Future<void> refreshMemory() async {
    memoryOverview = MemoryOverview.fromJson(
      await _backendClient.fetchMemoryOverview(
        backendUrl,
        agentId: _scopedAgentId,
      ),
    );
    memories = _decodeModelList(
      'memories',
      await _backendClient.fetchMemories(backendUrl, agentId: _scopedAgentId),
      MemoryItem.fromJson,
    );
    memoryConversations = _decodeModelList(
      'memory_conversations',
      await _backendClient.fetchConversations(
        backendUrl,
        agentId: _scopedAgentId,
      ),
      ConversationItem.fromJson,
    );
    notifyListeners();
  }

  Future<String> fetchMemoryTransferPrompt() async {
    final response = await _backendClient.fetchMemoryTransferPrompt(
      backendUrl,
      agentId: _scopedAgentId,
    );
    return response['prompt']?.toString() ?? '';
  }

  Future<MemoryTransferImportResult> importMemoryTransfer(
    String text, {
    bool applyBehaviorNotes = true,
    bool applyCoreMemory = true,
  }) async {
    final response = await _backendClient.importMemoryTransfer(
      backendUrl,
      text: text,
      applyBehaviorNotes: applyBehaviorNotes,
      applyCoreMemory: applyCoreMemory,
      agentId: _scopedAgentId,
    );
    final result = MemoryTransferImportResult.fromJson(response);
    await refreshMemory();
    return result;
  }

  Future<void> refreshTasks() async {
    taskItems = _decodeModelList(
      'tasks',
      await _backendClient.fetchTasks(backendUrl, agentId: _scopedAgentId),
      TaskItem.fromJson,
    );
    notifyListeners();
  }

  Future<void> refreshWidgets({bool all = false}) async {
    if (all) {
      unawaited(_analytics.trackWidgetRefreshRequested(all: all));
    }
    widgets = _decodeModelList(
      'widgets',
      await _backendClient.fetchWidgets(
        backendUrl,
        agentId: all ? null : _scopedAgentId,
        all: all,
      ),
      AiWidgetItem.fromJson,
    );
    _selectedWidgetId = widgets.any((widget) => widget.id == _selectedWidgetId)
        ? _selectedWidgetId
        : (widgets.isEmpty ? null : widgets.first.id);
    if (isAuthenticated) {
      unawaited(_maybeSyncHomeWidgets());
    }
    notifyListeners();
  }

  Future<void> refreshMcp() async {
    mcpServers = _decodeModelList(
      'mcp_servers',
      await _backendClient.fetchMcpServers(backendUrl, agentId: _scopedAgentId),
      McpServerItem.fromJson,
    );
    notifyListeners();
  }

  Future<void> refreshRecordings() async {
    _logRecording('refresh.request');
    recordingSessions = _decodeModelList(
      'recordings',
      await _backendClient.fetchRecordingSessions(backendUrl),
      RecordingSessionItem.fromJson,
    );
    await _recordingBridge.refreshStatus();
    _logRecording(
      'refresh.done',
      data: <String, Object?>{
        'sessionStatuses': recordingSessions
            .take(5)
            .map((item) => '${item.id}:${item.status}')
            .join(','),
      },
    );
    _logRecordingConsistency('refreshRecordings');
    notifyListeners();
  }

  Future<void> _refreshRecordingSessionById(String sessionId) async {
    final trimmed = sessionId.trim();
    if (trimmed.isEmpty || !isAuthenticated) {
      return;
    }

    try {
      _logRecording(
        'refresh_by_id.request',
        data: <String, Object?>{'sessionId': trimmed},
      );
      final response = await _backendClient.fetchRecordingSession(
        backendUrl,
        trimmed,
      );
      final session = RecordingSessionItem.fromJson(
        _jsonMap(response['session']),
      );
      _upsertRecordingSession(session);

      await _recordingBridge.refreshStatus();
      _logRecording(
        'refresh_by_id.done',
        data: <String, Object?>{
          'sessionId': trimmed,
          'status': session.status,
          'endedAt': session.endedAt?.toIso8601String(),
        },
      );
      _logRecordingConsistency('refreshRecordingSessionById');
      notifyListeners();
    } catch (error) {
      _logRecording(
        'refresh_by_id.fallback_full_refresh',
        data: <String, Object?>{'sessionId': trimmed},
        error: error,
      );
      // Session may have been pruned or unavailable; fall back to full refresh.
      await refreshRecordings();
    }
  }

  Future<void> refreshDevices() async {
    if (!isAuthenticated || isRefreshingDevices) {
      return;
    }
    isRefreshingDevices = true;
    notifyListeners();
    try {
      final browserResponse = await _backendClient.fetchBrowserStatus(
        backendUrl,
      );
      final browserExtensionResponse = await _backendClient
          .fetchBrowserExtensionStatus(backendUrl);
      final androidResponse = await _backendClient.fetchAndroidStatus(
        backendUrl,
      );
      final desktopResponse = await _backendClient.fetchDesktopStatus(
        backendUrl,
      );
      browserRuntime = Map<String, dynamic>.from(browserResponse);
      browserExtensionStatus = Map<String, dynamic>.from(
        browserExtensionResponse,
      );
      browserExtensionTokens = _jsonMapList(
        browserExtensionStatus['tokens'],
        fallbackToMapValues: true,
      );
      selectedBrowserExtensionTokenId = _optionalIdFrom(
        browserExtensionStatus['selectedTokenId'],
      );
      androidRuntime = Map<String, dynamic>.from(androidResponse);
      desktopRuntime = Map<String, dynamic>.from(desktopResponse);
      selectedDesktopDeviceId =
          desktopRuntime['selectedDeviceId']?.toString().trim().isEmpty ?? true
          ? null
          : desktopRuntime['selectedDeviceId']?.toString();
      desktopDevices = _jsonMapList(
        desktopRuntime['devices'],
        fallbackToMapValues: true,
      );
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isRefreshingDevices = false;
      notifyListeners();
    }
  }

  String get browserExtensionDownloadUrl =>
      '${_socketOrigin()}/api/browser-extension/download';

  Future<void> refreshBrowserExtensionStatus() async {
    try {
      final response = await _backendClient.fetchBrowserExtensionStatus(
        backendUrl,
      );
      browserExtensionStatus = Map<String, dynamic>.from(response);
      browserExtensionTokens = _jsonMapList(
        browserExtensionStatus['tokens'],
        fallbackToMapValues: true,
      );
      selectedBrowserExtensionTokenId = _optionalIdFrom(
        browserExtensionStatus['selectedTokenId'],
      );
      notifyListeners();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> downloadBrowserExtension() async {
    final result = await _oauthLauncher.openExternal(
      url: browserExtensionDownloadUrl,
      label: 'neoagent_browser_extension_download',
    );
    if (!result.launched) {
      errorMessage =
          result.error ?? 'Could not open browser extension download.';
      notifyListeners();
    }
  }

  Future<void> refreshAndroidApps({bool includeSystem = false}) async {
    try {
      final response = await _backendClient.fetchAndroidApps(
        backendUrl,
        includeSystem: includeSystem,
      );
      androidInstalledApps = _jsonStringList(
        response['packages'],
        nestedKeys: const <String>[
          'items',
          'data',
          'results',
          'rows',
          'values',
          'list',
          'packages',
        ],
        fallbackToMapValues: true,
      );
      notifyListeners();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> _runDeviceAction(
    Future<Map<String, dynamic>> Function() action, {
    required bool browser,
    bool refreshDevicesAfter = true,
    bool refreshAppsAfter = false,
  }) async {
    if (isRunningDeviceAction) {
      return;
    }
    isRunningDeviceAction = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await action();
      final pretty = const JsonEncoder.withIndent('  ').convert(result);
      if (browser) {
        browserLastResult = pretty;
        final screenshot = result['screenshotPath']?.toString();
        if (screenshot != null && screenshot.isNotEmpty) {
          browserScreenshotPath = screenshot;
        }
      } else {
        androidLastResult = pretty;
        final screenshot = result['screenshotPath']?.toString();
        if (screenshot != null && screenshot.isNotEmpty) {
          androidScreenshotPath = screenshot;
        }
        final dumpPath = result['uiDumpPath']?.toString();
        if (dumpPath != null && dumpPath.isNotEmpty) {
          androidUiDumpPath = dumpPath;
        }
        final preview = result['preview'];
        if (preview is List) {
          androidUiPreview = preview
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (item) =>
                    item.map((key, value) => MapEntry(key.toString(), value)),
              )
              .toList();
        }
      }
      if (refreshDevicesAfter) {
        await refreshDevices();
      }
      if (refreshAppsAfter) {
        await refreshAndroidApps();
      }
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isRunningDeviceAction = false;
      notifyListeners();
    }
  }

  Future<void> launchBrowserRuntime() async {
    await _runDeviceAction(
      () => _backendClient.launchBrowser(backendUrl),
      browser: true,
    );
    browserScreenshotPath = null;
  }

  Future<void> navigateBrowserRuntime({
    required String url,
    String? waitFor,
  }) async {
    await _runDeviceAction(
      () => _backendClient.navigateBrowser(
        backendUrl,
        url: url,
        waitFor: waitFor,
      ),
      browser: true,
    );
  }

  Future<void> clickBrowserRuntime({String? selector, String? text}) async {
    await _runDeviceAction(
      () => _backendClient.clickBrowser(
        backendUrl,
        selector: selector,
        text: text,
      ),
      browser: true,
    );
  }

  Future<void> clickBrowserPointRuntime({
    required int x,
    required int y,
  }) async {
    await _runDeviceAction(
      () => _backendClient.clickBrowserPoint(backendUrl, x: x, y: y),
      browser: true,
    );
  }

  Future<void> hoverBrowserPointRuntime({
    required int x,
    required int y,
  }) async {
    try {
      await _backendClient.hoverBrowserPoint(backendUrl, x: x, y: y);
    } catch (_) {}
  }

  Future<void> fillBrowserRuntime({
    required String selector,
    required String value,
    bool pressEnter = false,
  }) async {
    await _runDeviceAction(
      () => _backendClient.fillBrowser(
        backendUrl,
        selector: selector,
        value: value,
        pressEnter: pressEnter,
      ),
      browser: true,
    );
  }

  Future<void> typeBrowserTextRuntime(
    String text, {
    bool pressEnter = false,
  }) async {
    await _runDeviceAction(
      () => _backendClient.typeBrowserText(
        backendUrl,
        text: text,
        pressEnter: pressEnter,
      ),
      browser: true,
    );
  }

  Future<void> pressBrowserKeyRuntime(String key) async {
    await _runDeviceAction(
      () => _backendClient.pressBrowserKey(backendUrl, key: key),
      browser: true,
    );
  }

  Future<void> scrollBrowserRuntime({int deltaX = 0, int deltaY = 0}) async {
    await _runDeviceAction(
      () => _backendClient.scrollBrowser(
        backendUrl,
        deltaX: deltaX,
        deltaY: deltaY,
      ),
      browser: true,
    );
  }

  Future<void> screenshotBrowserRuntime() async {
    await _runDeviceAction(
      () => _backendClient.screenshotBrowser(backendUrl),
      browser: true,
    );
  }

  Future<void> refreshBrowserFrameRuntime() async {
    if (isRunningDeviceAction || browserRuntime['launched'] != true) {
      return;
    }
    try {
      final result = await _backendClient.screenshotBrowser(backendUrl);
      final screenshot = result['screenshotPath']?.toString();
      if (screenshot != null && screenshot.isNotEmpty) {
        browserScreenshotPath = screenshot;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> closeBrowserRuntime() async {
    await _runDeviceAction(
      () => _backendClient.closeBrowser(backendUrl),
      browser: true,
    );
    browserScreenshotPath = null;
    notifyListeners();
  }

  Future<void> startAndroidRuntime() async {
    await _runDeviceAction(
      () => _backendClient.startAndroidEmulator(backendUrl),
      browser: false,
      refreshAppsAfter: false,
    );
  }

  Future<void> stopAndroidRuntime() async {
    await _runDeviceAction(
      () => _backendClient.stopAndroidEmulator(backendUrl),
      browser: false,
    );
  }

  Future<void> screenshotAndroidRuntime() async {
    await _runDeviceAction(
      () => _backendClient.screenshotAndroid(backendUrl),
      browser: false,
      refreshDevicesAfter: false,
    );
  }

  Future<void> refreshAndroidFrameRuntime() async {
    if (isRunningDeviceAction) {
      return;
    }
    final devices = _jsonMapList(
      androidRuntime['devices'],
      fallbackToMapValues: true,
    );
    final online = devices.any(
      (device) => device['status']?.toString() == 'device',
    );
    if (!online) {
      return;
    }
    try {
      final result = await _backendClient.screenshotAndroid(backendUrl);
      final screenshot = result['screenshotPath']?.toString();
      if (screenshot != null && screenshot.isNotEmpty) {
        androidScreenshotPath = screenshot;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> startStreamRuntime({
    required String platform,
    required String deviceId,
    int fps = 10,
    int quality = 70,
  }) async {
    final normalizedDeviceId = deviceId.trim();
    if (normalizedDeviceId.isEmpty) {
      return;
    }
    await _backendClient.startStream(
      backendUrl,
      platform: platform,
      deviceId: normalizedDeviceId,
      fps: fps,
      quality: quality,
    );
  }

  Future<void> stopStreamRuntime({
    required String platform,
    required String deviceId,
  }) async {
    final normalizedDeviceId = deviceId.trim();
    if (normalizedDeviceId.isEmpty) {
      return;
    }
    await _backendClient.stopStream(
      backendUrl,
      platform: platform,
      deviceId: normalizedDeviceId,
    );
  }

  Future<void> dumpAndroidUiRuntime() async {
    await _runDeviceAction(
      () => _backendClient.dumpAndroidUi(backendUrl),
      browser: false,
      refreshDevicesAfter: false,
    );
  }

  Future<void> openAndroidAppRuntime({
    required String packageName,
    String? activity,
  }) async {
    await _runDeviceAction(
      () => _backendClient.openAndroidApp(
        backendUrl,
        packageName: packageName,
        activity: activity,
        uiDump: false,
        includeNodes: false,
      ),
      browser: false,
      refreshDevicesAfter: false,
    );
  }

  Future<void> openAndroidIntentRuntime({
    String? action,
    String? dataUri,
    String? packageName,
    String? component,
  }) async {
    await _runDeviceAction(
      () => _backendClient.openAndroidIntent(
        backendUrl,
        action: action,
        dataUri: dataUri,
        packageName: packageName,
        component: component,
        uiDump: false,
        includeNodes: false,
      ),
      browser: false,
      refreshDevicesAfter: false,
    );
  }

  Future<void> tapAndroidRuntime(Map<String, dynamic> payload) async {
    await _runDeviceAction(
      () => _backendClient.tapAndroid(backendUrl, <String, dynamic>{
        ...payload,
        'uiDump': false,
        'includeNodes': false,
      }),
      browser: false,
      refreshDevicesAfter: false,
    );
  }

  Future<void> typeAndroidRuntime(Map<String, dynamic> payload) async {
    await _runDeviceAction(
      () => _backendClient.typeAndroid(backendUrl, <String, dynamic>{
        ...payload,
        'uiDump': false,
        'includeNodes': false,
      }),
      browser: false,
      refreshDevicesAfter: false,
    );
  }

  Future<void> swipeAndroidRuntime(Map<String, dynamic> payload) async {
    await _runDeviceAction(
      () => _backendClient.swipeAndroid(backendUrl, <String, dynamic>{
        ...payload,
        'uiDump': false,
        'includeNodes': false,
      }),
      browser: false,
      refreshDevicesAfter: false,
    );
  }

  Future<void> pressAndroidKeyRuntime(String key) async {
    await _runDeviceAction(
      () => _backendClient.pressAndroidKey(
        backendUrl,
        key: key,
        uiDump: false,
        includeNodes: false,
      ),
      browser: false,
      refreshDevicesAfter: false,
    );
  }

  Future<void> waitForAndroidRuntime(Map<String, dynamic> payload) async {
    await _runDeviceAction(
      () => _backendClient.waitForAndroid(backendUrl, payload),
      browser: false,
      refreshDevicesAfter: false,
    );
  }

  Future<void> installAndroidApkRuntime({
    required String filename,
    required Uint8List bytes,
  }) async {
    await _runDeviceAction(
      () => _backendClient.installAndroidApk(
        backendUrl,
        filename: filename,
        bytes: bytes,
      ),
      browser: false,
      refreshAppsAfter: true,
    );
  }

  Future<void> _runDesktopDeviceAction(
    Future<Map<String, dynamic>> Function() action, {
    bool refreshDevicesAfter = true,
  }) async {
    if (isRunningDeviceAction) {
      return;
    }
    isRunningDeviceAction = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await action();
      desktopLastResult = const JsonEncoder.withIndent('  ').convert(result);
      final screenshot = result['screenshotPath']?.toString();
      if (screenshot != null && screenshot.isNotEmpty) {
        desktopScreenshotPath = screenshot;
      }
      final displays = _jsonMapList(
        result['displays'],
        fallbackToMapValues: true,
      );
      if (displays.isNotEmpty) {
        desktopDisplays = displays;
      }
      final permissions = result['permissions'];
      if (permissions is Map) {
        desktopPermissions = permissions.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
      if (refreshDevicesAfter) {
        await refreshDevices();
      }
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isRunningDeviceAction = false;
      notifyListeners();
    }
  }

  Future<void> selectDesktopDeviceRuntime(String deviceId) async {
    await _runDesktopDeviceAction(
      () => _backendClient.selectDesktopDevice(backendUrl, deviceId: deviceId),
    );
    desktopScreenshotPath = null;
    await refreshDesktopFrameRuntime();
  }

  Future<void> selectBrowserExtensionRuntime(String tokenId) async {
    isRunningDeviceAction = true;
    errorMessage = null;
    notifyListeners();
    try {
      final response = await _backendClient.selectBrowserExtensionToken(
        backendUrl,
        tokenId: tokenId,
      );
      final status = response['status'] is Map
          ? Map<String, dynamic>.from(response['status'] as Map)
          : await _backendClient.fetchBrowserExtensionStatus(backendUrl);
      browserExtensionStatus = Map<String, dynamic>.from(status);
      browserExtensionTokens = _jsonMapList(
        browserExtensionStatus['tokens'],
        fallbackToMapValues: true,
      );
      selectedBrowserExtensionTokenId = _optionalIdFrom(
        browserExtensionStatus['selectedTokenId'],
      );
      if (selectedBrowserExtensionTokenId != null) {
        settings = <String, dynamic>{
          ...settings,
          'browser_extension_token_id': selectedBrowserExtensionTokenId,
          'selected_browser_extension_token_id':
              selectedBrowserExtensionTokenId,
        };
      }
      browserScreenshotPath = null;
      await refreshBrowserFrameRuntime();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isRunningDeviceAction = false;
      notifyListeners();
    }
  }

  Future<void> openDesktopSelectionRuntime() async {
    await refreshDevices();
    errorMessage =
        'Select a desktop companion from the Desktop device dropdown.';
    notifyListeners();
  }

  Future<void> screenshotDesktopRuntime() async {
    await _runDesktopDeviceAction(
      () => _backendClient.screenshotDesktop(
        backendUrl,
        deviceId: selectedDesktopDeviceId,
      ),
      refreshDevicesAfter: false,
    );
  }

  Future<void> observeDesktopRuntime() async {
    await _runDesktopDeviceAction(
      () => _backendClient.observeDesktop(
        backendUrl,
        deviceId: selectedDesktopDeviceId,
        includeTree: true,
      ),
      refreshDevicesAfter: false,
    );
  }

  Future<void> refreshDesktopFrameRuntime() async {
    if (isRunningDeviceAction) {
      return;
    }
    final onlineDesktop = desktopDevices.firstWhere(
      (device) => device['online'] == true,
      orElse: () => const <String, dynamic>{},
    );
    if (onlineDesktop.isEmpty) {
      return;
    }
    final selectedId = selectedDesktopDeviceId;
    final selectedOnline = (selectedId ?? '').isNotEmpty
        ? desktopDevices.any(
            (device) =>
                device['online'] == true &&
                device['deviceId']?.toString() == selectedId,
          )
        : false;
    final targetDeviceId = selectedOnline
        ? selectedId
        : onlineDesktop['deviceId']?.toString();
    if ((targetDeviceId ?? '').isEmpty) {
      return;
    }
    try {
      final result = await _backendClient.screenshotDesktop(
        backendUrl,
        deviceId: targetDeviceId,
      );
      final screenshot = result['screenshotPath']?.toString();
      if (screenshot != null && screenshot.isNotEmpty) {
        desktopScreenshotPath = screenshot;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> clickDesktopRuntime({required int x, required int y}) async {
    await _runDesktopDeviceAction(
      () => _backendClient.clickDesktop(
        backendUrl,
        deviceId: selectedDesktopDeviceId,
        x: x,
        y: y,
      ),
      refreshDevicesAfter: false,
    );
  }

  Future<void> hoverDesktopRuntime({required int x, required int y}) async {
    try {
      await _backendClient.hoverDesktop(
        backendUrl,
        deviceId: selectedDesktopDeviceId,
        x: x,
        y: y,
      );
    } catch (_) {}
  }

  Future<void> dragDesktopRuntime({
    required int x1,
    required int y1,
    required int x2,
    required int y2,
  }) async {
    await _runDesktopDeviceAction(
      () => _backendClient.dragDesktop(
        backendUrl,
        deviceId: selectedDesktopDeviceId,
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
      ),
      refreshDevicesAfter: false,
    );
  }

  Future<void> scrollDesktopRuntime({int deltaY = 0}) async {
    await _runDesktopDeviceAction(
      () => _backendClient.scrollDesktop(
        backendUrl,
        deviceId: selectedDesktopDeviceId,
        deltaY: deltaY,
      ),
      refreshDevicesAfter: false,
    );
  }

  Future<void> typeDesktopRuntime(
    String text, {
    bool pressEnter = false,
  }) async {
    await _runDesktopDeviceAction(
      () => _backendClient.typeDesktopText(
        backendUrl,
        deviceId: selectedDesktopDeviceId,
        text: text,
        pressEnter: pressEnter,
      ),
      refreshDevicesAfter: false,
    );
  }

  Future<void> pressDesktopKeyRuntime(String key) async {
    await _runDesktopDeviceAction(
      () => _backendClient.pressDesktopKey(
        backendUrl,
        deviceId: selectedDesktopDeviceId,
        key: key,
      ),
      refreshDevicesAfter: false,
    );
  }

  Future<void> launchDesktopAppRuntime(String app) async {
    await _runDesktopDeviceAction(
      () => _backendClient.launchDesktopApp(
        backendUrl,
        deviceId: selectedDesktopDeviceId,
        app: app,
      ),
      refreshDevicesAfter: false,
    );
  }

  Future<void> revokeDesktopDeviceRuntime(String deviceId) async {
    await _runDesktopDeviceAction(
      () => _backendClient.revokeDesktopDevice(backendUrl, deviceId: deviceId),
    );
  }

  Future<void> pauseDesktopDeviceRuntime(
    String deviceId, {
    bool paused = true,
  }) async {
    await _runDesktopDeviceAction(
      () => _backendClient.pauseDesktopDevice(
        backendUrl,
        deviceId: deviceId,
        paused: paused,
      ),
    );
  }

  Uri resolveRuntimeAsset(String path) {
    final separator = path.contains('?') ? '&' : '?';
    return _backendClient.resolveAssetUri(
      backendUrl,
      '$path${separator}t=${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  Uri resolveRecordingSourceAudioUri(String sessionId, String sourceKey) {
    final encodedSessionId = Uri.encodeComponent(sessionId);
    final encodedSourceKey = Uri.encodeComponent(sourceKey);
    return resolveRuntimeAsset(
      '/api/recordings/$encodedSessionId/audio/$encodedSourceKey',
    );
  }

  Future<Uint8List> fetchRecordingSourceAudioBytes(
    String sessionId,
    String sourceKey,
  ) {
    final encodedSessionId = Uri.encodeComponent(sessionId);
    final encodedSourceKey = Uri.encodeComponent(sourceKey);
    return fetchRuntimeAssetBytes(
      '/api/recordings/$encodedSessionId/audio/$encodedSourceKey',
    );
  }

  Future<Uint8List> fetchRuntimeAssetBytes(String path) {
    final separator = path.contains('?') ? '&' : '?';
    return _backendClient.fetchBinary(
      backendUrl,
      '$path${separator}t=${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  Map<String, String>? get authenticatedImageHeaders {
    final cookie = _backendClient.sessionCookie;
    if (cookie == null || cookie.isEmpty) {
      return null;
    }
    return <String, String>{'Cookie': cookie};
  }

  Future<void> startWebRecording() async {
    await _startRecordingCapture(
      logKey: 'start_web',
      payload: buildWebScreenAndMicRecordingPayload(),
      startCapture: (sessionId) => _recordingBridge.startWebRecording(
        baseUrl: backendUrl,
        sessionId: sessionId,
      ),
    );
  }

  Future<void> startWebMicrophoneRecording() async {
    await _startRecordingCapture(
      logKey: 'start_web_mic_only',
      payload: buildWebMicrophoneRecordingPayload(),
      startCapture: (sessionId) => _recordingBridge.startWebMicrophoneRecording(
        baseUrl: backendUrl,
        sessionId: sessionId,
      ),
    );
  }

  Future<void> startBackgroundRecording() async {
    unawaited(_analytics.trackRecordingStarted(kind: 'background'));
    await _startRecordingCapture(
      logKey: 'start_background',
      payload: buildAndroidBackgroundRecordingPayload(),
      startCapture: (sessionId) => _recordingBridge.startBackgroundRecording(
        baseUrl: backendUrl,
        sessionCookie: _backendClient.sessionCookie ?? '',
        sessionId: sessionId,
      ),
    );
  }

  Future<void> startDesktopRecording() async {
    if (isLiveVoiceCaptureActive || isLiveVoiceCaptureStarting) {
      errorMessage =
          'Finish assistant push-to-talk before starting desktop recording.';
      notifyListeners();
      return;
    }
    if (!canStartDesktopRecording) {
      if (!isAuthenticated || requiresBackendUrlSetup) {
        errorMessage =
            'Sign in and finish backend setup before starting desktop recording.';
        notifyListeners();
      }
      return;
    }
    unawaited(_analytics.trackRecordingStarted(kind: 'desktop'));
    await _startRecordingCapture(
      logKey: 'start_desktop',
      payload: buildDesktopRecordingPayload(),
      startCapture: (sessionId) => _recordingBridge.startDesktopAudioRecording(
        baseUrl: backendUrl,
        sessionCookie: _backendClient.sessionCookie ?? '',
        sessionId: sessionId,
        autoShowToolbar: _desktopAutoShowFloatingToolbar,
      ),
    );
  }

  Future<void> pauseBackgroundRecording() async {
    try {
      _logRecording('pause_background.request');
      await _recordingBridge.pauseBackgroundRecording();
      _logRecording('pause_background.done');
    } catch (error) {
      _logRecording('pause_background.failed', error: error);
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> resumeBackgroundRecording() async {
    try {
      _logRecording('resume_background.request');
      await _recordingBridge.resumeBackgroundRecording();
      _logRecording('resume_background.done');
    } catch (error) {
      _logRecording('resume_background.failed', error: error);
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> pauseDesktopRecording() async {
    try {
      _logRecording('pause_desktop.request');
      await _recordingBridge.pauseDesktopRecording();
      _logRecording('pause_desktop.done');
    } catch (error) {
      _logRecording('pause_desktop.failed', error: error);
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> resumeDesktopRecording() async {
    try {
      _logRecording('resume_desktop.request');
      await _recordingBridge.resumeDesktopRecording();
      _logRecording('resume_desktop.done');
    } catch (error) {
      _logRecording('resume_desktop.failed', error: error);
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> showDesktopFloatingToolbar() async {
    try {
      _desktopFloatingToolbarPopupRequested = true;
      await _recordingBridge.showFloatingToolbar();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> hideDesktopFloatingToolbar() async {
    try {
      _desktopFloatingToolbarPopupRequested = false;
      await _recordingBridge.hideFloatingToolbar();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> openDesktopMicrophoneSettings() async {
    try {
      await _recordingBridge.openMicrophoneSettings();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> openDesktopSystemAudioSettings() async {
    try {
      await _recordingBridge.openSystemAudioSettings();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> setDesktopClosePreference({
    required bool askOnClose,
    required bool keepRunningOnClose,
  }) async {
    _desktopAskOnClose = askOnClose;
    _desktopKeepRunningOnClose = keepRunningOnClose;
    await _prefs?.setBool('desktop.askOnClose', askOnClose);
    await _prefs?.setBool('desktop.keepRunningOnClose', keepRunningOnClose);
    notifyListeners();
  }

  Future<void> setDesktopAutoShowFloatingToolbar(bool value) async {
    _desktopAutoShowFloatingToolbar = value;
    await _prefs?.setBool('desktop.autoShowFloatingToolbar', value);
    notifyListeners();
  }

  Future<void> setDesktopAssistantHotkeyEnabled(bool value) async {
    _desktopAssistantHotkeyEnabled = value;
    await _prefs?.setBool('desktop.assistantHotkeyEnabled', value);
    notifyListeners();
  }

  Future<void> setDesktopCompanionEnabled(bool value) async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    try {
      await _desktopCompanion.setEnabled(value, prefs);
      await _syncDesktopCompanionSession();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> setDesktopCompanionLabel(String value) async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    try {
      await _desktopCompanion.setLabel(value, prefs);
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> setDesktopCompanionPaused(bool value) async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    try {
      await _desktopCompanion.setPaused(value, prefs);
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> rotateDesktopCompanionIdentity() async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    try {
      await _desktopCompanion.rotateIdentity(prefs);
      await _syncDesktopCompanionSession();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> refreshDesktopCompanionStatus() async {
    try {
      await _desktopCompanion.refreshLocalStatus();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> openDesktopCompanionPermissionSettings(
    String permissionKey,
  ) async {
    try {
      await _desktopCompanion.openPermissionSettings(permissionKey);
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> setVoiceAssistantIncludeScreenContext(bool value) async {
    _voiceAssistantIncludeScreenContext =
        value && canCaptureVoiceAssistantScreenContext;
    await _prefs?.setBool(
      'voiceAssistant.includeScreenContext',
      _voiceAssistantIncludeScreenContext,
    );
    notifyListeners();
  }

  Future<void> toggleVoiceAssistantScreenContext() {
    return setVoiceAssistantIncludeScreenContext(
      !voiceAssistantIncludeScreenContext,
    );
  }

  void acknowledgeDesktopFloatingToolbarPopupRequest() {
    _desktopFloatingToolbarPopupRequested = false;
  }

  Future<Map<String, String>> _captureVoiceAssistantScreenshotPayload() async {
    if (!_voiceAssistantIncludeScreenContext ||
        !canCaptureVoiceAssistantScreenContext) {
      return const <String, String>{};
    }

    try {
      final capture = await _desktopScreenCapture.captureCurrentScreen();
      if (capture == null || capture.bytes.isEmpty) {
        return const <String, String>{};
      }
      final optimized = _optimizeVoiceAssistantScreenshotPayload(capture);
      if (optimized == null) {
        AppDiagnostics.log(
          'desktop.assistant',
          'screen_capture.optimize_failed',
          data: <String, Object?>{
            'mimeType': capture.mimeType,
            'originalByteLength': capture.bytes.length,
          },
        );
        return const <String, String>{};
      }
      AppDiagnostics.log(
        'desktop.assistant',
        'screen_capture.success',
        data: <String, Object?>{
          'mimeType': optimized.mimeType,
          'byteLength': optimized.bytes.length,
          'originalByteLength': capture.bytes.length,
          'resizedOrReencoded': optimized.resizedOrReencoded,
        },
      );
      return <String, String>{
        'screenshotMimeType': optimized.mimeType,
        'screenshotBase64': base64Encode(optimized.bytes),
      };
    } catch (error, stackTrace) {
      AppDiagnostics.log(
        'desktop.assistant',
        'screen_capture.failed',
        error: error,
        stackTrace: stackTrace,
      );
      return const <String, String>{};
    }
  }

  Future<Map<String, String>> buildVoiceAssistantContextPayload() async {
    return _captureVoiceAssistantScreenshotPayload();
  }

  _OptimizedScreenshotPayload? _optimizeVoiceAssistantScreenshotPayload(
    DesktopScreenCaptureResult capture,
  ) {
    final sourceBytes = Uint8List.fromList(capture.bytes);
    final sourceMime = _normalizeScreenshotMimeType(capture.mimeType);
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) {
      if (sourceBytes.length <= _voiceAssistantScreenshotMaxBytes) {
        return _OptimizedScreenshotPayload(
          bytes: sourceBytes,
          mimeType: sourceMime,
          resizedOrReencoded: false,
        );
      }
      return null;
    }

    var workingImage = decoded;
    var transformed = false;
    if (workingImage.width > _voiceAssistantScreenshotMaxDimension ||
        workingImage.height > _voiceAssistantScreenshotMaxDimension) {
      final scale = math.min(
        _voiceAssistantScreenshotMaxDimension / workingImage.width,
        _voiceAssistantScreenshotMaxDimension / workingImage.height,
      );
      final nextWidth = math.max(1, (workingImage.width * scale).round());
      final nextHeight = math.max(1, (workingImage.height * scale).round());
      workingImage = img.copyResize(
        workingImage,
        width: nextWidth,
        height: nextHeight,
        interpolation: img.Interpolation.average,
      );
      transformed = true;
    }

    if (!transformed &&
        sourceBytes.length <= _voiceAssistantScreenshotMaxBytes) {
      return _OptimizedScreenshotPayload(
        bytes: sourceBytes,
        mimeType: sourceMime,
        resizedOrReencoded: false,
      );
    }

    final qualitySteps = <int>[84, 74, 64, 54, 46, 40];
    var bestBytes = Uint8List(0);
    for (var pass = 0; pass < qualitySteps.length; pass += 1) {
      final encoded = Uint8List.fromList(
        img.encodeJpg(workingImage, quality: qualitySteps[pass]),
      );
      if (bestBytes.isEmpty || encoded.length < bestBytes.length) {
        bestBytes = encoded;
      }
      if (encoded.length <= _voiceAssistantScreenshotMaxBytes) {
        return _OptimizedScreenshotPayload(
          bytes: encoded,
          mimeType: 'image/jpeg',
          resizedOrReencoded: true,
        );
      }
      if (pass % 2 == 1) {
        final nextWidth = math.max(1, (workingImage.width * 0.85).round());
        final nextHeight = math.max(1, (workingImage.height * 0.85).round());
        if (nextWidth == workingImage.width &&
            nextHeight == workingImage.height) {
          continue;
        }
        workingImage = img.copyResize(
          workingImage,
          width: nextWidth,
          height: nextHeight,
          interpolation: img.Interpolation.average,
        );
      }
    }

    if (bestBytes.isNotEmpty &&
        bestBytes.length <= _voiceAssistantScreenshotMaxBytes) {
      return _OptimizedScreenshotPayload(
        bytes: bestBytes,
        mimeType: 'image/jpeg',
        resizedOrReencoded: true,
      );
    }
    return null;
  }

  String _normalizeScreenshotMimeType(String mimeType) {
    final normalized = mimeType.trim().toLowerCase();
    if (normalized.startsWith('image/')) {
      return normalized;
    }
    return 'image/png';
  }

  Future<void> stopRecording({String stopReason = 'stopped'}) async {
    final sessionId = recordingRuntime.sessionId;
    if (sessionId == null || isStoppingRecording) {
      return;
    }
    final isAndroidBackgroundStop =
        recordingRuntime.supportsBackgroundMic &&
        !recordingRuntime.supportsScreenAndMic;
    isStoppingRecording = true;
    errorMessage = null;
    _logRecording(
      'stop.request',
      data: <String, Object?>{
        'sessionId': sessionId,
        'isAndroidBackgroundStop': isAndroidBackgroundStop,
      },
    );
    notifyListeners();
    try {
      _desktopFloatingToolbarPopupRequested = false;
      unawaited(
        _analytics.trackRecordingStopped(
          kind:
              recordingRuntime.supportsBackgroundMic &&
                  !recordingRuntime.supportsScreenAndMic
              ? 'background'
              : 'desktop',
          stopReason: stopReason,
        ),
      );
      await _recordingBridge.stopActiveRecording();
      if (isAndroidBackgroundStop) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
      } else {
        await _backendClient.finalizeRecordingSession(
          backendUrl,
          sessionId,
          stopReason: stopReason,
        );
      }
      await refreshRecordings();
      _logRecording(
        'stop.done',
        data: <String, Object?>{'sessionId': sessionId},
      );
    } catch (error) {
      _logRecording(
        'stop.failed',
        data: <String, Object?>{
          'sessionId': sessionId,
          'isAndroidBackgroundStop': isAndroidBackgroundStop,
        },
        error: error,
      );
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    } finally {
      isStoppingRecording = false;
      notifyListeners();
    }
  }

  Future<void> retryRecording(String sessionId) async {
    try {
      await _backendClient.retryRecordingSession(backendUrl, sessionId);
      await refreshRecordings();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> deleteRecordingSegment(String sessionId, int segmentId) async {
    try {
      errorMessage = null;
      final response = await _backendClient.deleteRecordingTranscriptSegment(
        backendUrl,
        sessionId,
        segmentId,
      );
      final session = RecordingSessionItem.fromJson(
        _jsonMap(response['session']),
      );
      _upsertRecordingSession(session);
      notifyListeners();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> deleteRecordingSession(String sessionId) async {
    try {
      errorMessage = null;
      await _backendClient.deleteRecordingSession(backendUrl, sessionId);
      _removeRecordingSession(sessionId);
      notifyListeners();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<VoiceAssistantTurnResult> runVoiceAssistantTurn({
    required String sessionId,
    String? ttsProvider,
    String? ttsVoice,
    String? ttsModel,
  }) async {
    final screenshotPayload = await buildVoiceAssistantContextPayload();
    final response = await _backendClient.runVoiceAssistantTurn(
      backendUrl,
      sessionId: sessionId,
      ttsProvider:
          ttsProvider?.trim().ifEmpty(voiceTtsProvider) ?? voiceTtsProvider,
      ttsVoice: ttsVoice?.trim().ifEmpty(voiceTtsVoice) ?? voiceTtsVoice,
      ttsModel: ttsModel?.trim().ifEmpty(voiceTtsModel) ?? voiceTtsModel,
      agentId: _scopedAgentId,
      screenshotBase64: screenshotPayload['screenshotBase64'],
      screenshotMimeType: screenshotPayload['screenshotMimeType'],
    );

    final result = VoiceAssistantTurnResult.fromJson(response);
    _upsertRecordingSession(result.session);

    if (result.transcript.trim().isNotEmpty) {
      _appendUserChatMessage(result.transcript, platform: 'voice_assistant');
    }
    if (result.replyText.trim().isNotEmpty) {
      _appendAssistantChatMessage(
        result.replyText,
        platform: 'voice_assistant',
      );
    }
    notifyListeners();
    return result;
  }

  Future<bool> _ensureSocketReady({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    _ensureSocketConnected();
    if (socketConnected && _socket != null) {
      return true;
    }
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (socketConnected && _socket != null) {
        return true;
      }
    }
    return socketConnected && _socket != null;
  }

  Future<void> ensureLiveVoiceSession() async {
    if (voiceAssistantLiveState.hasActiveSession) {
      return;
    }
    if (_liveVoiceSessionOpenCompleter != null) {
      return _liveVoiceSessionOpenCompleter!.future;
    }
    final ready = await _ensureSocketReady();
    if (!ready || _socket == null) {
      throw StateError('Live voice connection is not available.');
    }
    final completer = Completer<void>();
    _liveVoiceSessionOpenCompleter = completer;
    _socket!.emit('voice:session_open', <String, dynamic>{
      'agentId': _scopedAgentId,
    });
    try {
      await completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw StateError('Live voice session did not initialize.');
        },
      );
    } finally {
      if (identical(_liveVoiceSessionOpenCompleter, completer)) {
        _liveVoiceSessionOpenCompleter = null;
      }
    }
  }

  String _createLiveVoiceTurnId() {
    _liveVoiceTurnCounter += 1;
    return 'live_${DateTime.now().millisecondsSinceEpoch}_$_liveVoiceTurnCounter';
  }

  bool _hasRecoverableLiveVoiceTurn() {
    final recoverableUntil = _liveVoiceRecoverableUntil;
    if ((_liveVoiceTurnId ?? '').trim().isEmpty) {
      return false;
    }
    if (recoverableUntil == null || !recoverableUntil.isAfter(DateTime.now())) {
      return false;
    }
    return _liveVoiceBufferedChunks.isNotEmpty ||
        _liveVoiceCaptureActive ||
        _liveVoiceCommitPending ||
        _liveVoiceAwaitingResponse;
  }

  void _setLiveVoiceRecoveryWindow() {
    _liveVoiceRecoveryTimer?.cancel();
    final recoverableUntil = DateTime.now().add(const Duration(seconds: 15));
    _liveVoiceRecoverableUntil = recoverableUntil;
    _liveVoiceRecoveryTimer = Timer(const Duration(seconds: 15), () {
      if (!_hasRecoverableLiveVoiceTurn()) {
        return;
      }
      _liveVoiceCaptureActive = false;
      _pendingLiveVoiceStop = false;
      unawaited(_liveVoiceCapture.stop());
      _resetLiveVoiceTurnBuffer();
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        sessionId: '',
        transportState: 'disconnected',
        state: 'error',
        error: 'Live voice reconnect timed out. Try again.',
        clearAudio: true,
        clearRecoverableUntil: true,
      );
      notifyListeners();
    });
    voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
      recoverableUntil: recoverableUntil,
    );
  }

  void _resetLiveVoiceTurnBuffer({bool clearRecovery = true}) {
    _liveVoiceTurnId = null;
    _liveVoiceBufferedChunks.clear();
    _liveVoiceAckThrough = -1;
    _liveVoiceFinalSequence = -1;
    _liveVoiceCommitPending = false;
    _liveVoiceAwaitingResponse = false;
    _liveVoicePendingCommitPayload = null;
    _liveVoiceCaptureStartedAt = null;
    if (clearRecovery) {
      _liveVoiceRecoveryTimer?.cancel();
      _liveVoiceRecoveryTimer = null;
      _liveVoiceRecoverableUntil = null;
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        clearRecoverableUntil: true,
      );
    }
  }

  void _markLiveVoiceChunksForReplay() {
    _liveVoiceAckThrough = -1;
    for (final chunk in _liveVoiceBufferedChunks) {
      chunk.sent = false;
    }
  }

  void _sendLiveVoiceInputStart({
    required String sessionId,
    required String turnId,
  }) {
    final socket = _socket;
    if (socket == null) {
      return;
    }
    socket.emit('voice:interrupt', <String, dynamic>{'sessionId': sessionId});
    socket.emit('voice:input_start', <String, dynamic>{
      'sessionId': sessionId,
      'turnId': turnId,
      'mimeType': 'audio/pcm;rate=16000;channels=1',
    });
  }

  Future<void> _flushLiveVoiceBufferedChunks() async {
    final socket = _socket;
    final sessionId = voiceAssistantLiveState.sessionId.trim();
    final turnId = (_liveVoiceTurnId ?? '').trim();
    if (socket == null ||
        !socketConnected ||
        sessionId.isEmpty ||
        turnId.isEmpty) {
      return;
    }
    for (final chunk in _liveVoiceBufferedChunks) {
      if (chunk.sent) {
        continue;
      }
      socket.emit('voice:audio_chunk', <String, dynamic>{
        'sessionId': sessionId,
        'turnId': turnId,
        'sequence': chunk.sequence,
        'mimeType': 'audio/pcm;rate=16000;channels=1',
        'audioBase64': base64Encode(chunk.bytes),
      });
      chunk.sent = true;
    }
  }

  Future<void> _emitPendingLiveVoiceCommitIfReady() async {
    final socket = _socket;
    final sessionId = voiceAssistantLiveState.sessionId.trim();
    final turnId = (_liveVoiceTurnId ?? '').trim();
    if (!_liveVoiceCommitPending ||
        socket == null ||
        !socketConnected ||
        sessionId.isEmpty ||
        turnId.isEmpty ||
        _liveVoiceFinalSequence < 0 ||
        _liveVoiceAckThrough < _liveVoiceFinalSequence) {
      return;
    }
    final payload = <String, dynamic>{
      'sessionId': sessionId,
      'turnId': turnId,
      'finalSequence': _liveVoiceFinalSequence,
      ...?_liveVoicePendingCommitPayload,
    };
    _liveVoiceCommitPending = false;
    _liveVoiceAwaitingResponse = true;
    socket.emit('voice:input_commit', payload);
  }

  Future<void> _restoreBufferedLiveVoiceTurnToActiveSession() async {
    final sessionId = voiceAssistantLiveState.sessionId.trim();
    final turnId = (_liveVoiceTurnId ?? '').trim();
    if (sessionId.isEmpty ||
        turnId.isEmpty ||
        !_hasRecoverableLiveVoiceTurn()) {
      return;
    }
    _markLiveVoiceChunksForReplay();
    _sendLiveVoiceInputStart(sessionId: sessionId, turnId: turnId);
    await _flushLiveVoiceBufferedChunks();
    await _emitPendingLiveVoiceCommitIfReady();
  }

  Future<void> startLiveVoiceCapture() async {
    if (recordingRuntime.active || isStartingRecording || isStoppingRecording) {
      throw StateError(
        'Stop recording before starting the assistant push-to-talk flow.',
      );
    }
    if (_isStartingLiveVoice || _isStoppingLiveVoice) {
      return;
    }

    bool routingStarted = false;
    try {
      routingStarted = await AndroidAutoBridge.instance
          .startTelecomCallRouting();
    } catch (_) {
      // Swallowed safely
    }

    _isStartingLiveVoice = true;
    _pendingLiveVoiceStop = false;
    errorMessage = null;
    AppDiagnostics.log(
      'desktop.assistant',
      'ptt.start_request',
      data: <String, Object?>{
        'hasActiveSession': voiceAssistantLiveState.hasActiveSession,
        'socketConnected': socketConnected,
      },
    );
    notifyListeners();

    try {
      await ensureLiveVoiceSession();
      final sessionId = voiceAssistantLiveState.sessionId.trim();
      if (sessionId.isEmpty || _socket == null) {
        throw StateError('Live voice session did not initialize.');
      }
      final turnId = _createLiveVoiceTurnId();
      _resetLiveVoiceTurnBuffer(clearRecovery: false);
      _liveVoiceTurnId = turnId;
      _setLiveVoiceRecoveryWindow();
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        transportState: 'connected',
        state: 'listening',
        partialTranscript: '',
        finalTranscript: '',
        interimAssistantText: '',
        finalAssistantText: '',
        assistantText: '',
        clearAudio: true,
        clearError: true,
      );
      notifyListeners();
      _sendLiveVoiceInputStart(sessionId: sessionId, turnId: turnId);
      await _liveVoiceCapture.start(
        onChunk: (Uint8List chunk) {
          final sequence = _liveVoiceBufferedChunks.length;
          _liveVoiceBufferedChunks.add(
            LiveVoiceBufferedChunk(sequence: sequence, bytes: chunk),
          );
          _setLiveVoiceRecoveryWindow();
          unawaited(_flushLiveVoiceBufferedChunks());
        },
        onError: (Object error, StackTrace stackTrace) {
          if (routingStarted) {
            AndroidAutoBridge.instance.stopTelecomCallRouting();
          }
          AppDiagnostics.log(
            'desktop.assistant',
            'ptt.capture_error',
            error: error,
            stackTrace: stackTrace,
          );
          if (!_liveVoiceCaptureActive && !_isStartingLiveVoice) {
            return;
          }
          _liveVoiceCaptureActive = false;
          _resetLiveVoiceTurnBuffer();
          voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
            state: 'error',
            error: _friendlyErrorMessage(error),
          );
          notifyListeners();
        },
        onStoppedUnexpectedly: () {
          if (routingStarted) {
            AndroidAutoBridge.instance.stopTelecomCallRouting();
          }
          AppDiagnostics.log(
            'desktop.assistant',
            'ptt.capture_stopped_unexpectedly',
          );
          if (!_liveVoiceCaptureActive && !_isStartingLiveVoice) {
            return;
          }
          _liveVoiceCaptureActive = false;
          _resetLiveVoiceTurnBuffer();
          voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
            state: 'error',
            error:
                'Microphone capture stopped unexpectedly. Re-open the assistant and try again.',
          );
          notifyListeners();
        },
      );
      _liveVoiceCaptureActive = true;
      _liveVoiceCaptureStartedAt = DateTime.now();
      AppDiagnostics.log(
        'desktop.assistant',
        'ptt.capture_started',
        data: <String, Object?>{'sessionId': sessionId},
      );
      if (_pendingLiveVoiceStop) {
        _pendingLiveVoiceStop = false;
        await stopLiveVoiceCapture();
        return;
      }
    } catch (error) {
      if (routingStarted) {
        await AndroidAutoBridge.instance.stopTelecomCallRouting();
      }
      _liveVoiceCaptureActive = false;
      _pendingLiveVoiceStop = false;
      rethrow;
    } finally {
      _isStartingLiveVoice = false;
      notifyListeners();
    }
  }

  Future<void> toggleLiveVoiceCapture() async {
    if (isLiveVoiceCaptureEngaged) {
      await stopLiveVoiceCapture();
      return;
    }
    await startLiveVoiceCapture();
  }

  Future<void> stopLiveVoiceCapture() async {
    await AndroidAutoBridge.instance.stopTelecomCallRouting();
    AppDiagnostics.log(
      'desktop.assistant',
      'ptt.stop_request',
      data: <String, Object?>{
        'isStarting': _isStartingLiveVoice,
        'isActive': _liveVoiceCaptureActive,
      },
    );
    if (_isStoppingLiveVoice) {
      return;
    }
    if (_isStartingLiveVoice && !_liveVoiceCaptureActive) {
      _pendingLiveVoiceStop = true;
      return;
    }
    if (!_liveVoiceCaptureActive) {
      return;
    }
    _isStoppingLiveVoice = true;
    try {
      _liveVoiceCaptureActive = false;
      _liveVoiceCaptureStartedAt = null;
      await _liveVoiceCapture.stop();
      if (_liveVoiceBufferedChunks.isEmpty) {
        _resetLiveVoiceTurnBuffer();
        voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
          state: 'idle',
          clearRecoverableUntil: true,
        );
        return;
      }
      final screenshotPayload = await buildVoiceAssistantContextPayload();
      AppDiagnostics.log(
        'desktop.assistant',
        'ptt.capture_committing',
        data: <String, Object?>{
          'sessionId': voiceAssistantLiveState.sessionId.trim(),
          'turnId': _liveVoiceTurnId,
        },
      );
      _liveVoiceFinalSequence = _liveVoiceBufferedChunks.length - 1;
      _liveVoiceCommitPending = true;
      _liveVoicePendingCommitPayload = <String, dynamic>{
        if ((screenshotPayload['screenshotBase64'] ?? '').isNotEmpty)
          'screenshotBase64': screenshotPayload['screenshotBase64'],
        if ((screenshotPayload['screenshotMimeType'] ?? '').isNotEmpty)
          'screenshotMimeType': screenshotPayload['screenshotMimeType'],
      };
      _setLiveVoiceRecoveryWindow();
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        state: 'transcribing',
      );
      await _flushLiveVoiceBufferedChunks();
      await _emitPendingLiveVoiceCommitIfReady();
    } finally {
      _isStoppingLiveVoice = false;
      notifyListeners();
    }
  }

  Future<void> interruptLiveVoiceAssistant() async {
    await AndroidAutoBridge.instance.stopTelecomCallRouting();
    final sessionId = voiceAssistantLiveState.sessionId.trim();
    if (sessionId.isEmpty || _socket == null) {
      return;
    }
    _socket!.emit('voice:interrupt', <String, dynamic>{'sessionId': sessionId});
    _liveVoiceCaptureActive = false;
    _liveVoiceCaptureStartedAt = null;
    _pendingLiveVoiceStop = false;
    _resetLiveVoiceTurnBuffer();
    voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
      state: 'idle',
      clearRecoverableUntil: true,
    );
    notifyListeners();
  }

  Future<void> closeLiveVoiceSession() async {
    final sessionId = voiceAssistantLiveState.sessionId.trim();
    if (sessionId.isEmpty || _socket == null) {
      return;
    }
    _socket!.emit('voice:session_close', <String, dynamic>{
      'sessionId': sessionId,
    });
    _liveVoiceCaptureActive = false;
    _liveVoiceCaptureStartedAt = null;
    _pendingLiveVoiceStop = false;
    _resetLiveVoiceTurnBuffer();
    voiceAssistantLiveState = VoiceAssistantLiveState();
    notifyListeners();
  }

  bool _matchesLiveVoiceSessionPayload(Map<String, dynamic> payload) {
    final payloadSessionId = payload['sessionId']?.toString().trim() ?? '';
    final activeSessionId = voiceAssistantLiveState.sessionId.trim();
    if (payloadSessionId.isEmpty) {
      return activeSessionId.isEmpty;
    }
    if (activeSessionId.isEmpty) {
      return true;
    }
    return payloadSessionId == activeSessionId;
  }

  void _appendAssistantChatMessage(
    String content, {
    required String platform,
    bool transient = false,
  }) {
    _appendChatMessage(
      content,
      role: 'assistant',
      platform: platform,
      transient: transient,
    );
  }

  void _appendUserChatMessage(String content, {required String platform}) {
    _appendChatMessage(content, role: 'user', platform: platform);
  }

  void _appendToolNote(String summary, {String toolName = 'note'}) {
    final trimmed = summary.trim();
    if (trimmed.isEmpty) {
      return;
    }
    toolEvents = <ToolEventItem>[
      ...toolEvents,
      ToolEventItem(
        id: 'note-${DateTime.now().microsecondsSinceEpoch}',
        toolName: toolName,
        type: 'note',
        status: 'completed',
        summary: trimmed,
      ),
    ];
  }

  Future<void> refreshUpdateStatus() async {
    try {
      updateStatus = UpdateStatusSnapshot.fromJson(
        await _backendClient.fetchUpdateStatus(backendUrl),
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<RunDetailSnapshot> fetchRunDetail(
    String runId, {
    bool force = false,
  }) async {
    final cached = _runDetailsCache[runId];
    if (!force && cached != null && cached.response.trim().isNotEmpty) {
      return cached;
    }
    final response = await _backendClient.fetchRunSteps(backendUrl, runId);
    final detail = RunDetailSnapshot.fromJson(response);
    _runDetailsCache[runId] = detail;
    return detail;
  }

  Future<void> deleteRun(String runId) async {
    try {
      await _backendClient.deleteRun(backendUrl, runId);
      _runDetailsCache.remove(runId);
      recentRuns = recentRuns.where((run) => run.id != runId).toList();
      notifyListeners();
      await refreshRunsOnly();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> sendMessage(
    String task, {
    List<SharedChatAttachment> sharedAttachments =
        const <SharedChatAttachment>[],
  }) async {
    final trimmed = task.trim();
    final normalizedAttachments = sharedAttachments
        .where((item) => item.isValid)
        .toList(growable: false);
    final outgoingTask = _taskWithSharedAttachments(
      trimmed,
      normalizedAttachments,
    );
    final canSteerLiveRun = hasLiveRun && _socket != null && socketConnected;
    if (outgoingTask.isEmpty || (isSendingMessage && !canSteerLiveRun)) {
      return;
    }
    unawaited(
      _analytics.trackChatMessageSent(
        length: trimmed.length,
        steeringLiveRun: canSteerLiveRun,
      ),
    );

    final optimistic = ChatEntry(
      id: '',
      role: 'user',
      content: trimmed.isNotEmpty
          ? trimmed
          : (normalizedAttachments.isNotEmpty
                ? 'Sent shared attachments from mobile app.'
                : outgoingTask),
      platform: 'flutter',
      createdAt: DateTime.now(),
      metadata: normalizedAttachments.isEmpty
          ? const <String, dynamic>{}
          : <String, dynamic>{
              'sharedAttachments': normalizedAttachments
                  .map((item) => item.toJson())
                  .toList(growable: false),
            },
    );
    chatMessages = <ChatEntry>[...chatMessages, optimistic];
    errorMessage = null;
    if (!canSteerLiveRun) {
      isSendingMessage = true;
      toolEvents = const <ToolEventItem>[];
      streamingAssistant = '';
      activeRun = ActiveRunState.pending(outgoingTask);
    }
    notifyListeners();

    try {
      if (_socket != null && socketConnected) {
        _socket!.emit('agent:run', <String, dynamic>{
          'task': outgoingTask,
          'agentId': _scopedAgentId,
          'options': <String, dynamic>{'agentId': _scopedAgentId},
        });
        return;
      }

      final response = await _backendClient.runTask(
        backendUrl,
        outgoingTask,
        agentId: _scopedAgentId,
      );
      final content = response['content']?.toString().trim();
      if (content != null && content.isNotEmpty) {
        _appendAssistantChatMessage(content, platform: 'web');
      }
      activeRun = null;
      await refreshRunsOnly();
    } catch (error) {
      chatMessages = <ChatEntry>[
        ...chatMessages,
        ChatEntry(
          id: '',
          role: 'assistant',
          content:
              'I could not complete that request right now. Please try again in a moment.',
          platform: 'flutter',
          createdAt: DateTime.now(),
        ),
      ];
      activeRun = null;
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      if (_socket == null || !socketConnected) {
        isSendingMessage = false;
        notifyListeners();
      }
    }
  }

  Future<void> saveSettings({
    required String browserBackend,
    String? browserExtensionTokenId,
    required String cliBackend,
    String? cliDesktopDeviceId,
    required bool smarterSelector,
    required List<String> enabledModels,
    required String defaultChatModel,
    required String defaultSubagentModel,
    required String defaultSpeechModel,
    required String defaultRecordingTranscriptionProvider,
    required String defaultRecordingTranscriptionModel,
    required String defaultRecordingSummaryProvider,
    required String defaultRecordingSummaryModel,
    required String fallbackModel,
    required String voiceSttProvider,
    required String voiceSttModel,
    required String voiceTtsProvider,
    required String voiceTtsModel,
    required String voiceTtsVoice,
    required String voiceRuntimeMode,
    required String voiceLiveProvider,
    required String voiceLiveModel,
    required String voiceLiveVoice,
    required Map<String, dynamic> aiProviderConfigs,
  }) async {
    isSavingSettings = true;
    errorMessage = null;
    notifyListeners();

    final payload = <String, dynamic>{
      'headless_browser': true,
      'browser_backend': browserBackend,
      if (browserExtensionTokenId != null)
        'browser_extension_token_id': browserExtensionTokenId,
      'cli_backend': cliBackend,
      if (cliDesktopDeviceId != null)
        'cli_desktop_device_id': cliDesktopDeviceId,
      'smarter_model_selector': smarterSelector,
      'enabled_models': enabledModels,
      'default_chat_model': defaultChatModel,
      'default_subagent_model': defaultSubagentModel,
      'default_speech_model': defaultSpeechModel,
      'default_recording_transcription_provider':
          defaultRecordingTranscriptionProvider,
      'default_recording_transcription_model':
          defaultRecordingTranscriptionModel,
      'default_recording_summary_provider': defaultRecordingSummaryProvider,
      'default_recording_summary_model': defaultRecordingSummaryModel,
      'fallback_model_id': fallbackModel,
      'voice_stt_provider': voiceSttProvider,
      'voice_stt_model': voiceSttModel,
      'voice_tts_provider': voiceTtsProvider,
      'voice_tts_model': voiceTtsModel,
      'voice_tts_voice': voiceTtsVoice,
      'voice_runtime_mode': voiceRuntimeMode,
      'voice_live_provider': voiceLiveProvider,
      'voice_live_model': voiceLiveModel,
      'voice_live_voice': voiceLiveVoice,
      'ai_provider_configs': aiProviderConfigs,
    };

    try {
      await _backendClient.saveSettings(
        backendUrl,
        payload,
        agentId: _scopedAgentId,
      );
      settings = <String, dynamic>{...settings, ...payload};
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isSavingSettings = false;
      notifyListeners();
    }
  }

  void _applyAccountResponse(Map<String, dynamic> response) {
    if (response['user'] is Map) {
      user = Map<String, dynamic>.from(response['user'] as Map);
    }
    if (response['twoFactor'] is Map) {
      accountTwoFactor = Map<String, dynamic>.from(
        response['twoFactor'] as Map,
      );
    }
    final sessions = response['sessions'];
    if (sessions is List) {
      accountSessions = sessions
          .whereType<Map<dynamic, dynamic>>()
          .map(AccountSessionItem.fromJson)
          .toList();
    }
    final authProviderRows = response['authProviders'];
    if (authProviderRows is List) {
      linkedAuthProviders = authProviderRows
          .whereType<Map<dynamic, dynamic>>()
          .map(LinkedAuthProviderItem.fromJson)
          .toList();
    }
  }

  Future<void> refreshAccountSettings() async {
    if (!isAuthenticated) return;
    isLoadingAccountSettings = true;
    errorMessage = null;
    notifyListeners();
    try {
      _applyAccountResponse(await _backendClient.fetchAccount(backendUrl));
      final sessionsResponse = await _backendClient.fetchAccountSessions(
        backendUrl,
      );
      _applyAccountResponse(sessionsResponse);
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isLoadingAccountSettings = false;
      notifyListeners();
    }
  }

  Future<bool> updateAccountEmail({
    required String email,
    required String currentPassword,
  }) async {
    isSavingAccountSettings = true;
    errorMessage = null;
    notifyListeners();
    try {
      _applyAccountResponse(
        await _backendClient.updateAccountEmail(
          baseUrl: backendUrl,
          email: email,
          currentPassword: currentPassword,
        ),
      );
      return true;
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      return false;
    } finally {
      isSavingAccountSettings = false;
      notifyListeners();
    }
  }

  Future<bool> updateAccountPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    isSavingAccountSettings = true;
    errorMessage = null;
    notifyListeners();
    try {
      _applyAccountResponse(
        await _backendClient.updateAccountPassword(
          baseUrl: backendUrl,
          currentPassword: currentPassword,
          newPassword: newPassword,
        ),
      );
      return true;
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      return false;
    } finally {
      isSavingAccountSettings = false;
      notifyListeners();
    }
  }

  Future<bool> updateAccountDisplayName({required String displayName}) async {
    isSavingAccountSettings = true;
    errorMessage = null;
    notifyListeners();
    try {
      _applyAccountResponse(
        await _backendClient.updateAccountDisplayName(
          baseUrl: backendUrl,
          displayName: displayName,
        ),
      );
      return true;
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      return false;
    } finally {
      isSavingAccountSettings = false;
      notifyListeners();
    }
  }

  Future<void> linkAccountProvider(String provider) async {
    isSavingAccountSettings = true;
    errorMessage = null;
    notifyListeners();
    try {
      final begin = await _backendClient.beginProviderAuth(
        baseUrl: backendUrl,
        provider: provider,
        mode: 'link',
      );
      final url = begin['url']?.toString();
      final state = begin['state']?.toString();
      if (url == null || state == null || url.isEmpty || state.isEmpty) {
        throw Exception('Provider linking could not be started.');
      }
      final launchResult = await _oauthLauncher.launch(
        url: url,
        provider: provider,
      );
      if (!launchResult.launched) {
        throw Exception(
          launchResult.error ?? 'Could not open the provider linking page.',
        );
      }
      await _pollForProviderAuthCompletion(state);
      await refreshAccountSettings();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isSavingAccountSettings = false;
      notifyListeners();
    }
  }

  Future<void> unlinkAccountProvider(int providerLinkId) async {
    isSavingAccountSettings = true;
    errorMessage = null;
    notifyListeners();
    try {
      _applyAccountResponse(
        await _backendClient.unlinkAccountProvider(
          baseUrl: backendUrl,
          providerLinkId: providerLinkId,
        ),
      );
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isSavingAccountSettings = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> beginTwoFactorSetup(
    String currentPassword,
  ) async {
    isConfiguringTwoFactor = true;
    errorMessage = null;
    notifyListeners();
    try {
      final response = await _backendClient.beginTwoFactorSetup(
        baseUrl: backendUrl,
        currentPassword: currentPassword,
      );
      if (response['status'] is Map) {
        accountTwoFactor = Map<String, dynamic>.from(response['status'] as Map);
      }
      return response;
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      return null;
    } finally {
      isConfiguringTwoFactor = false;
      notifyListeners();
    }
  }

  Future<List<String>> enableTwoFactor(String code) async {
    isConfiguringTwoFactor = true;
    errorMessage = null;
    notifyListeners();
    try {
      final response = await _backendClient.enableTwoFactor(
        baseUrl: backendUrl,
        code: code,
      );
      if (response['status'] is Map) {
        accountTwoFactor = Map<String, dynamic>.from(response['status'] as Map);
      }
      return _jsonStringList(
        response['recoveryCodes'],
        nestedKeys: const <String>[
          'items',
          'data',
          'results',
          'rows',
          'values',
          'list',
          'recoveryCodes',
          'codes',
        ],
        fallbackToMapValues: true,
      );
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      return const <String>[];
    } finally {
      isConfiguringTwoFactor = false;
      notifyListeners();
    }
  }

  Future<void> disableTwoFactor({
    required String currentPassword,
    required String code,
  }) async {
    isConfiguringTwoFactor = true;
    errorMessage = null;
    notifyListeners();
    try {
      final response = await _backendClient.disableTwoFactor(
        baseUrl: backendUrl,
        currentPassword: currentPassword,
        code: code,
      );
      if (response['status'] is Map) {
        accountTwoFactor = Map<String, dynamic>.from(response['status'] as Map);
      }
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isConfiguringTwoFactor = false;
      notifyListeners();
    }
  }

  Future<List<String>> regenerateRecoveryCodes({
    required String currentPassword,
    required String code,
  }) async {
    isConfiguringTwoFactor = true;
    errorMessage = null;
    notifyListeners();
    try {
      final response = await _backendClient.regenerateRecoveryCodes(
        baseUrl: backendUrl,
        currentPassword: currentPassword,
        code: code,
      );
      if (response['status'] is Map) {
        accountTwoFactor = Map<String, dynamic>.from(response['status'] as Map);
      }
      return _jsonStringList(
        response['recoveryCodes'],
        nestedKeys: const <String>[
          'items',
          'data',
          'results',
          'rows',
          'values',
          'list',
          'recoveryCodes',
          'codes',
        ],
        fallbackToMapValues: true,
      );
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      return const <String>[];
    } finally {
      isConfiguringTwoFactor = false;
      notifyListeners();
    }
  }

  Future<void> revokeAccountSession(int sessionId) async {
    isRevokingSession = true;
    errorMessage = null;
    notifyListeners();
    try {
      _applyAccountResponse(
        await _backendClient.revokeAccountSession(backendUrl, sessionId),
      );
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isRevokingSession = false;
      notifyListeners();
    }
  }

  Future<void> triggerUpdate() async {
    isTriggeringUpdate = true;
    errorMessage = null;
    notifyListeners();
    try {
      unawaited(_analytics.trackAppUpdateTriggered());
      await _backendClient.triggerUpdate(backendUrl);
      await refreshUpdateStatus();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isTriggeringUpdate = false;
      notifyListeners();
    }
  }

  Future<void> setReleaseChannel(String channel) async {
    if (isSavingReleaseChannel) {
      return;
    }

    isSavingReleaseChannel = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _backendClient.setReleaseChannel(
        backendUrl,
        channel,
      );
      final nextChannel = response['releaseChannel']?.toString() ?? channel;
      updateStatus = UpdateStatusSnapshot.fromJson(<String, dynamic>{
        ...?versionInfo,
        'state': updateStatus.state,
        'progress': updateStatus.progress,
        'message': updateStatus.message,
        'releaseChannel': nextChannel,
        'targetBranch': response['targetBranch'],
        'npmDistTag': response['npmDistTag'],
        'versionBefore': updateStatus.versionBefore,
        'versionAfter': updateStatus.versionAfter,
        'backendVersion': updateStatus.backendVersion,
        'installedVersion': updateStatus.installedVersion,
        'changelog': updateStatus.changelog,
        'logs': updateStatus.logs,
      });
      if (versionInfo != null) {
        versionInfo = <String, dynamic>{
          ...versionInfo!,
          'releaseChannel': nextChannel,
          'targetBranch': response['targetBranch'],
          'npmDistTag': response['npmDistTag'],
        };
      }
      await refreshUpdateStatus();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isSavingReleaseChannel = false;
      notifyListeners();
    }
  }

  Future<SkillDocument> fetchSkillDocument(String name) async {
    return SkillDocument.fromJson(
      await _backendClient.fetchSkillDocument(backendUrl, name),
    );
  }

  Future<void> saveSkillContent({
    required String name,
    required String content,
  }) async {
    await _backendClient.saveSkillContent(
      backendUrl,
      name: name,
      content: content,
    );
    await refreshSkills();
  }

  Future<void> createSkill({
    required String filename,
    required String content,
  }) async {
    await _backendClient.createSkill(
      backendUrl,
      filename: filename,
      content: content,
    );
    await refreshSkills();
  }

  Future<void> setSkillEnabled(String name, bool enabled) async {
    await _backendClient.setSkillEnabled(
      backendUrl,
      name: name,
      enabled: enabled,
    );
    await refreshSkills();
  }

  Future<void> deleteSkill(String name) async {
    await _backendClient.deleteSkill(backendUrl, name);
    await refreshSkills();
  }

  Future<void> installStoreSkill(String id) async {
    await _backendClient.installStoreSkill(backendUrl, id);
    await refreshSkills();
  }

  Future<void> uninstallStoreSkill(String id) async {
    await _backendClient.uninstallStoreSkill(backendUrl, id);
    await refreshSkills();
  }

  Future<void> connectOfficialIntegration(
    String providerId, {
    required String appId,
  }) async {
    final busyKey = '$providerId:$appId:connect';
    if (_busyOfficialIntegrationKeys.contains(busyKey)) {
      return;
    }

    final before = _findOfficialIntegrationApp(providerId, appId);
    final beforeCount = before?.accounts.length ?? 0;
    final beforeLatest = before?.accounts
        .map((account) => account.lastConnectedAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (latest, value) {
          if (latest == null || value.isAfter(latest)) {
            return value;
          }
          return latest;
        });

    _busyOfficialIntegrationKeys.add(busyKey);
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _backendClient.connectOfficialIntegration(
        backendUrl,
        providerId,
        appId: appId,
        agentId: _scopedAgentId,
      );
      final url = response['url']?.toString();
      final status = response['status']?.toString() ?? '';
      if ((status != 'oauth_redirect' && status != 'interactive_connect') ||
          url == null ||
          url.isEmpty) {
        throw Exception(
          'Official integration did not return a connection URL.',
        );
      }

      final launchResult = await _oauthLauncher.launch(
        url: url,
        provider: providerId,
      );
      if (!launchResult.launched) {
        throw Exception(launchResult.error ?? 'Failed to launch OAuth flow.');
      }
      if (launchResult.completed) {
        await refreshSkills();
        return;
      }
      if (launchResult.error != null) {
        throw Exception(launchResult.error!);
      }

      await _pollForOfficialIntegrationConnection(
        providerId,
        appId: appId,
        previousAccountCount: beforeCount,
        previousLatestConnectedAt: beforeLatest,
      );
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      _busyOfficialIntegrationKeys.remove(busyKey);
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> getOfficialIntegrationConfig(
    String providerId,
  ) async {
    final response = await _backendClient.fetchOfficialIntegrationConfig(
      backendUrl,
      providerId,
      agentId: _scopedAgentId,
    );
    final raw = response['config'];
    if (raw is Map) {
      return Map<String, dynamic>.from(
        raw.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    return const <String, dynamic>{};
  }

  Future<void> saveOfficialIntegrationConfig(
    String providerId, {
    required Map<String, dynamic> config,
  }) async {
    final busyKey = '$providerId:config:save';
    if (_busyOfficialIntegrationKeys.contains(busyKey)) {
      return;
    }

    _busyOfficialIntegrationKeys.add(busyKey);
    errorMessage = null;
    notifyListeners();

    try {
      await _backendClient.saveOfficialIntegrationConfig(
        backendUrl,
        providerId,
        config: config,
        agentId: _scopedAgentId,
      );
      await refreshSkills();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      rethrow;
    } finally {
      _busyOfficialIntegrationKeys.remove(busyKey);
      notifyListeners();
    }
  }

  Future<void> clearOfficialIntegrationConfig(String providerId) async {
    final busyKey = '$providerId:config:clear';
    if (_busyOfficialIntegrationKeys.contains(busyKey)) {
      return;
    }

    _busyOfficialIntegrationKeys.add(busyKey);
    errorMessage = null;
    notifyListeners();

    try {
      await _backendClient.clearOfficialIntegrationConfig(
        backendUrl,
        providerId,
        agentId: _scopedAgentId,
      );
      await refreshSkills();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      rethrow;
    } finally {
      _busyOfficialIntegrationKeys.remove(busyKey);
      notifyListeners();
    }
  }

  Future<void> disconnectOfficialIntegration(
    String providerId, {
    required int connectionId,
  }) async {
    final busyKey = '$providerId:$connectionId:disconnect';
    if (_busyOfficialIntegrationKeys.contains(busyKey)) {
      return;
    }

    _busyOfficialIntegrationKeys.add(busyKey);
    errorMessage = null;
    notifyListeners();

    try {
      await _backendClient.disconnectOfficialIntegration(
        backendUrl,
        providerId,
        connectionId: connectionId,
        agentId: _scopedAgentId,
      );
      await refreshSkills();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      _busyOfficialIntegrationKeys.remove(busyKey);
      notifyListeners();
    }
  }

  Future<void> setOfficialIntegrationAccessMode(
    String providerId, {
    required int connectionId,
    required String accessMode,
  }) async {
    final busyKey = '$providerId:$connectionId:access_mode';
    if (_busyOfficialIntegrationKeys.contains(busyKey)) {
      return;
    }

    _busyOfficialIntegrationKeys.add(busyKey);
    errorMessage = null;
    notifyListeners();

    try {
      await _backendClient.setOfficialIntegrationAccessMode(
        backendUrl,
        providerId,
        connectionId: connectionId,
        accessMode: accessMode,
        agentId: _scopedAgentId,
      );
      await refreshSkills();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      _busyOfficialIntegrationKeys.remove(busyKey);
      notifyListeners();
    }
  }

  OfficialIntegrationAppItem? _findOfficialIntegrationApp(
    String providerId,
    String appId,
  ) {
    for (final item in officialIntegrations) {
      if (item.id != providerId) continue;
      for (final app in item.apps) {
        if (app.id == appId) {
          return app;
        }
      }
    }
    return null;
  }

  Future<void> _pollForOfficialIntegrationConnection(
    String providerId, {
    required String appId,
    required int previousAccountCount,
    required DateTime? previousLatestConnectedAt,
  }) async {
    final deadline = DateTime.now().add(const Duration(minutes: 2));
    while (DateTime.now().isBefore(deadline)) {
      try {
        final items = await _backendClient.fetchOfficialIntegrations(
          backendUrl,
          agentId: _scopedAgentId,
        );
        officialIntegrations = items
            .map(OfficialIntegrationItem.fromJson)
            .toList();
      } catch (_) {
        await Future<void>.delayed(const Duration(seconds: 2));
        continue;
      }
      final match = _findOfficialIntegrationApp(providerId, appId);
      final latestConnectedAt = match?.accounts
          .map((account) => account.lastConnectedAt)
          .whereType<DateTime>()
          .fold<DateTime?>(null, (latest, value) {
            if (latest == null || value.isAfter(latest)) {
              return value;
            }
            return latest;
          });
      if (match != null &&
          match.isConnected &&
          (match.accounts.length > previousAccountCount ||
              (previousLatestConnectedAt == null &&
                  latestConnectedAt != null) ||
              (previousLatestConnectedAt != null &&
                  latestConnectedAt != null &&
                  latestConnectedAt.isAfter(previousLatestConnectedAt)))) {
        await refreshSkills();
        notifyListeners();
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }

    throw Exception(
      'Authentication is still pending. Finish the browser flow and refresh.',
    );
  }

  Future<void> connectMessagingPlatform({
    required String platform,
    Map<String, dynamic>? config,
    Map<String, dynamic>? configSnapshot,
  }) async {
    if (configSnapshot != null) {
      await _backendClient.saveSettings(
        backendUrl,
        configSnapshot,
        agentId: _scopedAgentId,
      );
      settings = <String, dynamic>{...settings, ...configSnapshot};
    }
    await _backendClient.connectMessagingPlatform(
      backendUrl,
      platform: platform,
      config: config,
      agentId: _scopedAgentId,
    );
    await refreshMessaging();
  }

  Future<void> saveSettingsPayload(Map<String, dynamic> payload) async {
    if (isSavingSettings) {
      return;
    }
    isSavingSettings = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _backendClient.saveSettings(
        backendUrl,
        payload,
        agentId: _scopedAgentId,
      );
      settings = <String, dynamic>{...settings, ...payload};
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      rethrow;
    } finally {
      isSavingSettings = false;
      notifyListeners();
    }
  }

  Future<void> disconnectMessagingPlatform(String platform) async {
    await _backendClient.disconnectMessagingPlatform(
      backendUrl,
      platform: platform,
      agentId: _scopedAgentId,
    );
    await refreshMessaging();
  }

  Future<void> logoutMessagingPlatform(String platform) async {
    await _backendClient.logoutMessagingPlatform(
      backendUrl,
      platform: platform,
      agentId: _scopedAgentId,
    );
    await refreshMessaging();
  }

  Future<List<Map<String, dynamic>>> fetchMessagingPlatformDevices(
    String platform,
  ) async {
    final data = await _backendClient.fetchMessagingPlatformDevices(
      backendUrl,
      platform: platform,
      agentId: _scopedAgentId,
    );
    final raw = data['devices'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  Future<void> saveTelnyxVoiceSecret(String secret) async {
    await _backendClient.saveTelnyxVoiceSecret(
      backendUrl,
      secret,
      agentId: _scopedAgentId,
    );
    settings = <String, dynamic>{
      ...settings,
      'platform_voice_secret_telnyx': secret,
    };
    notifyListeners();
  }

  Future<void> saveMessagingAccessPolicy(
    String platform,
    MessagingAccessPolicy policy,
  ) async {
    final response = await _backendClient.saveMessagingAccessPolicy(
      backendUrl,
      platform: platform,
      policy: policy.toJson(),
      agentId: _scopedAgentId,
    );
    final saved = MessagingAccessCatalog.fromJson(platform, <String, dynamic>{
      'policy': _jsonMap(response['policy']),
      'capabilities': currentMessagingAccessCatalog(
        platform,
      ).capabilities.toJson(),
      'discoveredTargets': currentMessagingAccessCatalog(
        platform,
      ).discoveredTargets.map((item) => item.toJson()).toList(growable: false),
      'suggestedTargets': currentMessagingAccessCatalog(
        platform,
      ).suggestedTargets.map((item) => item.toJson()).toList(growable: false),
      'summary': response['summary']?.toString() ?? 'Access policy',
    });
    messagingAccessCatalogs = <String, MessagingAccessCatalog>{
      ...messagingAccessCatalogs,
      platform: saved,
    };
    notifyListeners();
  }

  Future<void> createMemory({
    required String content,
    required String category,
    required int importance,
  }) async {
    await _backendClient.createMemory(
      backendUrl,
      content: content,
      category: category,
      importance: importance,
      agentId: _scopedAgentId,
    );
    memoryRecallResults = const <MemoryItem>[];
    await refreshMemory();
  }

  Future<void> deleteMemory(String id) async {
    await deleteMemories(<String>[id]);
  }

  Future<void> deleteMemories(List<String> ids) async {
    final uniqueIds = ids.toSet().where((id) => id.trim().isNotEmpty).toSet();
    if (uniqueIds.isEmpty) {
      return;
    }
    await _backendClient.deleteMemories(
      backendUrl,
      uniqueIds.toList(growable: false),
      agentId: _scopedAgentId,
    );
    memoryRecallResults = memoryRecallResults
        .where((memory) => !uniqueIds.contains(memory.id))
        .toList();
    await refreshMemory();
  }

  Future<void> archiveMemories(List<String> ids) async {
    final uniqueIds = ids.toSet().where((id) => id.trim().isNotEmpty).toSet();
    if (uniqueIds.isEmpty) {
      return;
    }
    await _backendClient.archiveMemories(
      backendUrl,
      uniqueIds.toList(growable: false),
      agentId: _scopedAgentId,
    );
    memoryRecallResults = memoryRecallResults
        .where((memory) => !uniqueIds.contains(memory.id))
        .toList();
    await refreshMemory();
  }

  Future<void> searchMemories(String query) async {
    memoryRecallResults = (await _backendClient.recallMemories(
      backendUrl,
      query,
      agentId: _scopedAgentId,
    )).map(MemoryItem.fromJson).toList();
    notifyListeners();
  }

  void clearMemorySearch() {
    memoryRecallResults = const <MemoryItem>[];
    notifyListeners();
  }

  Future<void> updateAssistantBehaviorNotes(String content) async {
    await _backendClient.saveSettings(backendUrl, <String, dynamic>{
      'assistant_behavior_notes': content,
    }, agentId: _scopedAgentId);
    await refreshMemory();
  }

  Future<void> updateCoreMemory(String key, String value) async {
    await _backendClient.updateCoreMemory(
      backendUrl,
      key: key,
      value: value,
      agentId: _scopedAgentId,
    );
    await refreshMemory();
  }

  Future<void> deleteCoreMemory(String key) async {
    await _backendClient.deleteCoreMemory(
      backendUrl,
      key,
      agentId: _scopedAgentId,
    );
    await refreshMemory();
  }

  Future<void> saveTask({
    int? id,
    required String name,
    required String triggerType,
    required Map<String, dynamic> triggerConfig,
    required String prompt,
    String? model,
    bool enabled = true,
    String? agentId,
  }) async {
    await _backendClient.saveTask(
      backendUrl,
      id: id,
      name: name,
      triggerType: triggerType,
      triggerConfig: triggerConfig,
      prompt: prompt,
      model: model,
      enabled: enabled,
      agentId: agentId ?? _scopedAgentId,
    );
    await refreshTasks();
  }

  String _manualRunCooldownKey(String scope, String id) => '$scope:$id';

  void _pruneManualRunCooldowns() {
    final now = DateTime.now();
    _manualRunCooldowns.removeWhere((_, expiresAt) => !expiresAt.isAfter(now));
  }

  void _ensureManualRunCooldownTicker() {
    if (_manualRunCooldowns.isEmpty) {
      _manualRunCooldownTimer?.cancel();
      _manualRunCooldownTimer = null;
      return;
    }
    _manualRunCooldownTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      _pruneManualRunCooldowns();
      if (_manualRunCooldowns.isEmpty) {
        _manualRunCooldownTimer?.cancel();
        _manualRunCooldownTimer = null;
      }
      notifyListeners();
    });
  }

  void _startManualRunCooldown(String scope, String id) {
    _manualRunCooldowns[_manualRunCooldownKey(scope, id)] = DateTime.now().add(
      _manualRunCooldownDuration,
    );
    _ensureManualRunCooldownTicker();
    notifyListeners();
  }

  int _manualRunCooldownSeconds(String scope, String id) {
    _pruneManualRunCooldowns();
    final expiresAt = _manualRunCooldowns[_manualRunCooldownKey(scope, id)];
    if (expiresAt == null) {
      return 0;
    }
    final remaining = expiresAt.difference(DateTime.now()).inSeconds;
    return remaining <= 0 ? 0 : remaining + 1;
  }

  bool canRunTaskNow(int id) => _manualRunCooldownSeconds('task', '$id') == 0;

  int taskRunCooldownSeconds(int id) =>
      _manualRunCooldownSeconds('task', '$id');

  bool canRefreshWidgetNow(String id) =>
      _manualRunCooldownSeconds('widget', id) == 0;

  int widgetRunCooldownSeconds(String id) =>
      _manualRunCooldownSeconds('widget', id);

  Future<void> toggleWidgetEnabled(AiWidgetItem item) async {
    await _backendClient.saveWidget(
      backendUrl,
      id: item.id,
      payload: <String, dynamic>{
        'name': item.name,
        'template': item.template,
        'layoutVariant': item.layoutVariant,
        'refreshCron': item.refreshCron,
        'definition': item.definition,
        'enabled': !item.enabled,
        'agentId': item.agentId ?? _scopedAgentId,
      },
    );
    await refreshWidgets();
    await refreshTasks();
  }

  Future<void> refreshWidgetNow(String id) async {
    if (!canRefreshWidgetNow(id)) {
      notifyListeners();
      return;
    }
    _startManualRunCooldown('widget', id);
    await _backendClient.refreshWidget(backendUrl, id);
    await refreshWidgets();
    await refreshTasks();
    await refreshRunsOnly();
  }

  Future<void> deleteWidget(String id) async {
    await _backendClient.deleteWidget(backendUrl, id);
    widgets = widgets.where((widget) => widget.id != id).toList();
    _selectedWidgetId = widgets.any((widget) => widget.id == _selectedWidgetId)
        ? _selectedWidgetId
        : (widgets.isEmpty ? null : widgets.first.id);
    notifyListeners();
    await refreshTasks();
  }

  void openWidgetCreateFlow() {
    queueChatDraft(
      'Create a new AI widget for the current agent. Choose the best template and approved layout variant, set a refresh cadence of at least 1 hour, create it, and run an initial refresh if appropriate.',
    );
  }

  void openWidgetEditFlow(AiWidgetItem item) {
    queueChatDraft(
      'Update the AI widget "${item.name}" (ID: ${item.id}) for the current agent. Keep the cadence at 1 hour or longer. Change the layout variant only if the edit explicitly requires it.\n\nCurrent template: ${item.template}\nCurrent layout variant: ${item.layoutVariant}\nCurrent refresh cron: ${item.refreshCron}\nCurrent definition prompt:\n${item.prompt}',
    );
  }

  void queueChatDraft(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return;
    }
    _pendingChatDraft = normalized;
    _pendingSharedChatAttachments = const <SharedChatAttachment>[];
    if (!_isMobilePlatform) {
      setSelectedSection(AppSection.chat);
    } else {
      notifyListeners();
    }
  }

  void queueSharedChatPayload({
    String? text,
    String? subject,
    List<Map<String, dynamic>> files = const <Map<String, dynamic>>[],
  }) {
    final attachments = files
        .map(SharedChatAttachment.fromJson)
        .where((item) => item.isValid)
        .toList(growable: false);
    final textPart = (text ?? '').toString().trim();
    final subjectPart = (subject ?? '').toString().trim();
    final combined = <String>[
      subjectPart,
      textPart,
    ].where((part) => part.isNotEmpty).join('\n').trim();

    _pendingChatDraft = combined;
    _pendingSharedChatAttachments = attachments;
    setSelectedSection(AppSection.chat);
  }

  bool get hasPendingSharedChatPayload =>
      (_pendingChatDraft?.trim().isNotEmpty ?? false) ||
      _pendingSharedChatAttachments.isNotEmpty;

  bool get _isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  String? peekPendingChatDraft() {
    final draft = _pendingChatDraft?.trim() ?? '';
    return draft.isEmpty ? null : draft;
  }

  List<SharedChatAttachment> peekPendingSharedChatAttachments() {
    return List<SharedChatAttachment>.unmodifiable(
      _pendingSharedChatAttachments,
    );
  }

  void clearPendingSharedChatPayload() {
    _pendingChatDraft = null;
    _pendingSharedChatAttachments = const <SharedChatAttachment>[];
  }

  String _taskWithSharedAttachments(
    String task,
    List<SharedChatAttachment> attachments,
  ) {
    final base = task.trim();
    if (attachments.isEmpty) {
      return base;
    }
    final lines = attachments
        .map((item) {
          final type = item.mimeType.trim().isEmpty
              ? 'unknown'
              : item.mimeType.trim();
          return '- ${item.name} ($type) [local uri: ${item.uri}]';
        })
        .join('\n');
    final attachmentBlock = [
      'Shared attachments from mobile app:',
      lines,
      'Use these for context. If the local URI is not directly accessible from the server, ask me to upload the file.',
    ].join('\n');
    if (base.isEmpty) {
      return attachmentBlock;
    }
    return '$base\n\n$attachmentBlock';
  }

  void selectWidget(String? widgetId) {
    if (widgetId != null && !widgets.any((widget) => widget.id == widgetId)) {
      return;
    }
    _selectedWidgetId = widgetId;
    notifyListeners();
  }

  void openWidgetSurface(String widgetId) {
    final normalized = widgetId.trim();
    setSelectedSection(AppSection.widgets);
    if (normalized.isNotEmpty) {
      _selectedWidgetId = normalized;
      unawaited(refreshWidgets(all: true));
    }
  }

  void openVoiceAssistantSurface() {
    setSelectedSection(AppSection.voiceAssistant);
  }

  String? get selectedWidgetId => _selectedWidgetId;

  AiWidgetItem? get selectedWidget {
    final widgetId = _selectedWidgetId;
    if (widgetId == null) {
      return widgets.isEmpty ? null : widgets.first;
    }
    for (final item in widgets) {
      if (item.id == widgetId) {
        return item;
      }
    }
    return widgets.isEmpty ? null : widgets.first;
  }

  Future<void> toggleTask(TaskItem task) async {
    await _backendClient.updateTask(backendUrl, task.id, <String, dynamic>{
      'enabled': !task.enabled,
      if (task.agentId != null && task.agentId!.isNotEmpty)
        'agentId': task.agentId,
    });
    await refreshTasks();
  }

  Future<void> runTaskNow(int id) async {
    if (!canRunTaskNow(id)) {
      notifyListeners();
      return;
    }
    _startManualRunCooldown('task', '$id');
    unawaited(_analytics.trackTaskRunRequested(taskId: id));
    await _backendClient.runSavedTask(backendUrl, id);
    await refreshTasks();
    await refreshRunsOnly();
  }

  Future<void> deleteTask(int id) async {
    await _backendClient.deleteTask(backendUrl, id);
    await refreshTasks();
  }

  Future<bool> saveMcpServer({
    int? id,
    required String name,
    required String command,
    required Map<String, dynamic> config,
    required bool enabled,
    String? agentId,
  }) async {
    try {
      await _backendClient.saveMcpServer(
        backendUrl,
        id: id,
        name: name,
        command: command,
        config: config,
        enabled: enabled,
        agentId: agentId ?? _scopedAgentId,
      );
      await refreshMcp();
      return true;
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
      return false;
    }
  }

  Future<void> startMcpServer(int id) async {
    await _backendClient.startMcpServer(backendUrl, id);
    await refreshMcp();
  }

  Future<void> stopMcpServer(int id) async {
    await _backendClient.stopMcpServer(backendUrl, id);
    await refreshMcp();
  }

  Future<void> deleteMcpServer(int id) async {
    await _backendClient.deleteMcpServer(backendUrl, id);
    await refreshMcp();
  }

  Future<void> requestHealthPermissions() async {
    try {
      deviceHealthStatus = await _healthBridge.requestPermissions();
      await _syncBackgroundHealthConfig();
      notifyListeners();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> syncHealthNow() async {
    isSyncingHealth = true;
    errorMessage = null;
    notifyListeners();

    try {
      final deviceStatus = await _healthBridge.getStatus();
      deviceHealthStatus = deviceStatus;
      if (!deviceStatus.available) {
        throw const HealthBridgeException(
          'Health Connect is not available on this device.',
        );
      }
      if (!deviceStatus.permissionsGranted) {
        throw const HealthBridgeException(
          'Grant Health Connect permissions before syncing.',
        );
      }

      final lastRun = _jsonMap(backendHealthStatus?['lastRun']);
      final lastWindowEndRaw = lastRun['sync_window_end']?.toString();
      final windowEnd = DateTime.now().toUtc();
      final windowStart = lastWindowEndRaw == null
          ? windowEnd.subtract(const Duration(hours: 24))
          : DateTime.parse(
              lastWindowEndRaw,
            ).toUtc().subtract(const Duration(minutes: 5));

      final payload = await _healthBridge.collectBatch(
        windowStart: windowStart,
        windowEnd: windowEnd,
      );

      await _backendClient.uploadHealthBatch(backendUrl, payload);
      backendHealthStatus = await _backendClient.fetchHealthStatus(backendUrl);
      await _syncBackgroundHealthConfig();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isSyncingHealth = false;
      notifyListeners();
    }
  }

  String _friendlyErrorMessage(Object error) {
    final text = _normalizeErrorText(error);
    final lower = text.toLowerCase();
    final backendStatusCode = error is BackendException
        ? error.statusCode
        : null;

    if (backendStatusCode == 402) {
      final details = _extractMeaningfulErrorDetails(text);
      if (lower.contains('invalid credentials')) {
        return 'The NeoAgent deployment responded with HTTP 402 instead of the normal 401 for invalid credentials. Check reverse-proxy, auth gateway, or payment-related rules on that server.';
      }
      if (details.isNotEmpty &&
          details.toLowerCase() !=
              'request failed with http $backendStatusCode') {
        return 'The NeoAgent deployment responded with HTTP 402.\n\n$details';
      }
      return 'The NeoAgent deployment responded with HTTP 402. Check reverse-proxy, auth gateway, or payment-related rules on that server.';
    }

    if (lower.contains('invalid credentials')) {
      return 'Your username or password is incorrect.';
    }
    if (lower.contains('registration is closed')) {
      return 'This server is already set up. Sign in with an existing account.';
    }
    if (lower.contains('too many attempts')) {
      return 'Too many sign-in attempts. Please wait and try again.';
    }
    if (lower.contains('qr login request was not found') ||
        lower.contains('qr login request has expired') ||
        lower.contains('this qr login request has expired')) {
      return 'This QR login request expired. Generate a new code and try again.';
    }
    if (lower.contains('already used')) {
      return 'This QR login request was already used.';
    }
    if (lower.contains('not approved yet')) {
      return 'This QR login request is still waiting for approval.';
    }
    if (lower.contains('valid email')) {
      return 'Enter a valid email address.';
    }
    if (lower.contains('email is already in use')) {
      return 'That email is already linked to another account.';
    }
    if (lower.contains('current password is incorrect')) {
      return 'Your current password is incorrect.';
    }
    if (lower.contains('email confirmation required')) {
      return 'Confirm your email before signing in. Check the service email message from NeoAgent.';
    }
    if (lower.contains('could not send confirmation email') ||
        lower.contains('service email is not configured')) {
      return 'NeoAgent service email is not ready. Ask the server operator to check the email environment settings.';
    }
    if (lower.contains('password min 8')) {
      return 'Use a password with at least 8 characters.';
    }
    if (lower.contains('password is too weak')) {
      return text;
    }
    if (lower.contains('invalid 2fa') || lower.contains('two-factor code')) {
      return 'The two-factor code is not valid.';
    }
    if (lower.contains('two-factor challenge expired')) {
      return 'The two-factor challenge expired. Sign in again.';
    }
    if (lower.contains('session_secret')) {
      return '2FA requires SESSION_SECRET to be configured on this NeoAgent deployment.';
    }
    if (lower.contains('cors') ||
        lower.contains('xmlhttprequest error') ||
        lower.contains('failed to fetch') ||
        lower.contains('network request failed') ||
        lower.contains('clientexception') ||
        lower.contains('socketexception')) {
      return 'The app could not reach this NeoAgent deployment. Check your network connection or confirm the service URL is correct.';
    }
    if (lower.contains('origin not allowed')) {
      return 'This build is not allowed to talk to this NeoAgent deployment.';
    }
    if (lower.contains('not authenticated')) {
      return 'Your session expired. Please sign in again.';
    }
    if (lower.contains('no neoagent account is linked to this provider')) {
      return 'This Google account is not linked yet. Use provider registration first, or sign in normally and link it from account settings.';
    }
    if (lower.contains('already belongs to an existing account')) {
      return 'That email already belongs to an existing account. Sign in first, then link Google from account settings.';
    }
    if (lower.contains('already linked to another neoagent account') ||
        lower.contains('already linked to another account')) {
      return 'That Google account is already linked to a different NeoAgent account.';
    }
    if (lower.contains(
      'create a password or link another provider before removing this sign-in method',
    )) {
      return 'Add another sign-in method before removing this one.';
    }
    if (lower.contains('unable to locate a java runtime') ||
        lower.contains('java runtime')) {
      final details = _extractMeaningfulErrorDetails(text);
      if (details.isNotEmpty) {
        return 'Mobile setup failed because Java is not available on the machine running NeoAgent.\n\n$details';
      }
      return 'Mobile setup failed because Java is not available on the machine running NeoAgent. Install a JDK and try again.';
    }
    if (lower.contains('android sdk') ||
        lower.contains('sdkmanager') ||
        lower.contains('adb') ||
        lower.contains('emulator') ||
        lower.contains('gradle')) {
      final details = _extractMeaningfulErrorDetails(text);
      if (details.isNotEmpty) {
        return 'Mobile setup failed.\n\n$details';
      }
      return 'Mobile setup failed. Check that Android tooling is installed correctly and try again.';
    }
    if (lower.contains('health connect')) {
      return text;
    }
    if (lower.contains('xmlhttprequest error') ||
        lower.contains('failed to fetch') ||
        lower.contains('networkerror') ||
        lower.contains('load failed')) {
      final details = _extractMeaningfulErrorDetails(text);
      return details.isNotEmpty
          ? 'The web app could not reach the NeoAgent backend.\n\n$details'
          : 'The web app could not reach the NeoAgent backend.';
    }
    if (lower.contains('content security policy') ||
        lower.contains('connect-src')) {
      final details = _extractMeaningfulErrorDetails(text);
      return details.isNotEmpty
          ? 'The browser blocked a required request because of Content Security Policy.\n\n$details'
          : 'The browser blocked a required request because of Content Security Policy.';
    }
    if (_shouldExposeErrorText(text)) {
      return _extractMeaningfulErrorDetails(text);
    }

    return 'Something went wrong. Please try again.';
  }

  String friendlyErrorMessage(Object error) => _friendlyErrorMessage(error);

  String _normalizeErrorText(Object error) {
    var text = error.toString().trim();
    const prefixes = <String>[
      'BackendException: ',
      'HealthBridgeException: ',
      'Exception: ',
    ];
    for (final prefix in prefixes) {
      if (text.startsWith(prefix)) {
        text = text.substring(prefix.length).trim();
      }
    }
    if (text.startsWith('PlatformException(') && text.endsWith(')')) {
      final inner = text.substring(
        'PlatformException('.length,
        text.length - 1,
      );
      final parts = inner.split(', ');
      if (parts.length >= 2) {
        text = parts[1].trim();
      }
    }
    return text;
  }

  String _extractMeaningfulErrorDetails(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where((line) => !line.startsWith('{') && !line.startsWith('"error"'))
        .toList();
    if (lines.isEmpty) {
      return text.trim();
    }
    return lines.join('\n');
  }

  bool _shouldExposeErrorText(String text) {
    if (text.isEmpty) {
      return false;
    }

    final lower = text.toLowerCase();
    if (lower.contains('stack trace') ||
        lower.contains('typeerror:') ||
        lower.contains('referenceerror:') ||
        lower.contains('syntaxerror:') ||
        lower.contains(' at ') ||
        lower.contains('/users/') ||
        lower.contains('/var/') ||
        lower.contains('/tmp/')) {
      return false;
    }

    final details = _extractMeaningfulErrorDetails(text);
    return details.isNotEmpty &&
        details != 'Something went wrong. Please try again.' &&
        details.length <= 800;
  }

  bool get headlessBrowser => true;

  String get browserBackend =>
      settings['browser_backend']?.toString().trim().toLowerCase() ?? 'vm';

  String get cliBackend =>
      settings['cli_backend']?.toString().trim().toLowerCase() ?? 'vm';

  String? get cliDesktopDeviceId {
    final v = settings['cli_desktop_device_id']?.toString().trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  String get cloudBrowserBackend {
    final browser = browserBackend;
    final profile = settings['runtime_profile']
        ?.toString()
        .trim()
        .toLowerCase();
    final runtime = settings['runtime_backend']
        ?.toString()
        .trim()
        .toLowerCase();
    if (updateStatus.deploymentProfile.toLowerCase() == 'prod' ||
        profile == 'secure-vm') {
      return 'vm';
    }
    if (browser == 'extension') return 'vm';
    if (browser == 'vm') return 'vm';
    if (runtime == 'vm') return 'vm';
    return 'vm';
  }

  bool get browserExtensionConnected =>
      browserExtensionStatus['connected'] == true;

  String? get browserExtensionTokenId {
    final v = settings['browser_extension_token_id']?.toString().trim();
    return (v == null || v.isEmpty || v == 'null') ? null : v;
  }

  bool get smarterSelector => settings['smarter_model_selector'] != false;

  Map<String, AiProviderConfig> get aiProviderConfigs {
    final raw = settings['ai_provider_configs'];
    final decoded = raw is Map
        ? raw.map(
            (key, value) => MapEntry(
              key.toString(),
              AiProviderConfig.fromJson(key.toString(), value),
            ),
          )
        : const <String, AiProviderConfig>{};

    if (aiProviders.isEmpty) {
      return decoded;
    }

    return <String, AiProviderConfig>{
      for (final provider in aiProviders)
        provider.id:
            decoded[provider.id] ?? AiProviderConfig.empty(provider.id),
    };
  }

  List<String> get enabledModelIds {
    final raw = settings['enabled_models'];
    if (raw is List) {
      final knownIds = supportedModels.map((model) => model.id).toSet();
      final filtered = raw
          .map((item) => item.toString())
          .where((id) => knownIds.contains(id))
          .toList();
      if (filtered.isNotEmpty) {
        return filtered;
      }
    }
    return supportedModels
        .where((model) => model.available)
        .map((model) => model.id)
        .toList();
  }

  String get defaultChatModel =>
      settings['default_chat_model']?.toString() ?? 'auto';

  String get defaultSubagentModel =>
      settings['default_subagent_model']?.toString() ?? 'auto';

  String get defaultSpeechModel =>
      settings['default_speech_model']?.toString() ?? 'auto';

  String get defaultRecordingTranscriptionModel =>
      settings['default_recording_transcription_model']?.toString() ?? 'nova-3';

  String get defaultRecordingTranscriptionProvider => _settingString(
    'default_recording_transcription_provider',
    'deepgram',
    lowercase: true,
  );

  String get defaultRecordingSummaryModel =>
      settings['default_recording_summary_model']?.toString() ?? 'auto';

  String get defaultRecordingSummaryProvider => _settingString(
    'default_recording_summary_provider',
    'auto',
    lowercase: true,
  );

  String get fallbackModel =>
      settings['fallback_model_id']?.toString() ??
      _firstAvailableModelId(supportedModels);

  String get voiceSttProvider =>
      _settingString('voice_stt_provider', 'openai', lowercase: true);

  String get voiceSttModel =>
      _settingString('voice_stt_model', 'gpt-4o-transcribe');

  String get voiceTtsProvider =>
      _settingString('voice_tts_provider', 'openai', lowercase: true);

  String get voiceTtsModel =>
      _settingString('voice_tts_model', 'gpt-4o-mini-tts');

  String get voiceTtsVoice => _settingString('voice_tts_voice', 'alloy');

  String get voiceRuntimeMode => 'live';

  String get voiceLiveProvider =>
      _settingString('voice_live_provider', 'openai', lowercase: true);

  String get voiceLiveModel => _settingString(
    'voice_live_model',
    (_voiceLiveModelsByProvider[voiceLiveProvider] ??
            _voiceLiveModelsByProvider['openai']!)
        .first,
  );

  String get voiceLiveVoice => _settingString(
    'voice_live_voice',
    (_voiceLiveVoicesByProvider[voiceLiveProvider] ??
            _voiceLiveVoicesByProvider['openai']!)
        .first,
  );

  bool get isLiveVoiceCaptureStarting => _isStartingLiveVoice;

  bool get isLiveVoiceCaptureActive => _liveVoiceCaptureActive;

  DateTime? get liveVoiceCaptureStartedAt => _liveVoiceCaptureStartedAt;

  String get accountLabel {
    final displayName = user?['display_name']?.toString().trim() ?? '';
    if (displayName.isNotEmpty) return displayName;
    return user?['username']?.toString() ?? username.ifEmpty('NeoAgent User');
  }

  String get modelIndicator {
    if (defaultChatModel != 'auto') {
      final selected = _modelById(defaultChatModel);
      return selected?.label ?? defaultChatModel;
    }
    return smarterSelector ? 'Smart selector active' : 'Manual routing';
  }

  bool get showHealthSection =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _syncBackgroundHealthConfig() async {
    final cookie = _backendClient.sessionCookie ?? '';
    await _prefs?.setString('health_sync_backend_url', backendUrl);
    await _prefs?.remove('health_sync_session_cookie');
    final enabled =
        isAuthenticated &&
        showHealthSection &&
        (deviceHealthStatus?.permissionsGranted ?? false);
    await _prefs?.setBool('health_sync_enabled', enabled);
    await _healthBridge.configureBackgroundSync(
      enabled: enabled,
      backendUrl: backendUrl,
      sessionCookie: cookie,
    );
  }

  Future<void> _syncHomeWidgetConfig() async {
    final cookie = _backendClient.sessionCookie ?? '';
    final enabled =
        isAuthenticated &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android;
    await _widgetBridge.configureHomeWidgets(
      enabled: enabled,
      backendUrl: backendUrl,
      sessionCookie: cookie,
    );
    if (enabled) {
      await _maybeSyncHomeWidgets();
    }
  }

  Future<void> _maybeSyncHomeWidgets({bool force = false}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    if (!isAuthenticated) {
      return;
    }
    final now = DateTime.now();
    if (!force &&
        _lastHomeWidgetSyncAt != null &&
        now.difference(_lastHomeWidgetSyncAt!) < _homeWidgetSyncCooldown) {
      return;
    }
    _lastHomeWidgetSyncAt = now;
    await _widgetBridge.syncNow();
  }

  Stream<String> get widgetOpenRequests => _widgetBridge.openWidgetRequests;

  List<ChatEntry> get visibleChatMessages {
    final entries = <ChatEntry>[...chatMessages];
    if (isSendingMessage &&
        activeRun != null &&
        streamingAssistant.trim().isEmpty) {
      entries.add(
        ChatEntry(
          id: '',
          role: 'assistant',
          content: '',
          platform: 'live',
          createdAt: DateTime.now(),
          transient: true,
          typing: true,
        ),
      );
    } else if (streamingAssistant.trim().isNotEmpty) {
      entries.add(
        ChatEntry(
          id: '',
          role: 'assistant',
          content: streamingAssistant,
          platform: 'live',
          createdAt: DateTime.now(),
          transient: true,
        ),
      );
    }
    return entries;
  }

  ModelMeta? _modelById(String id) {
    for (final model in supportedModels) {
      if (model.id == id) {
        return model;
      }
    }
    return null;
  }

  void _ensureUpdatePolling() {
    _updatePollTimer ??= Timer.periodic(const Duration(seconds: 5), (_) {
      if (isAuthenticated) {
        refreshUpdateStatus();
      }
    });
  }

  void _disconnectSocket() {
    socketConnected = false;
    _socketHasConnectedOnce = false;
    if (_liveVoiceSessionOpenCompleter != null &&
        !_liveVoiceSessionOpenCompleter!.isCompleted) {
      _liveVoiceSessionOpenCompleter!.completeError(
        StateError('Live voice connection was closed.'),
      );
    }
    _liveVoiceSessionOpenCompleter = null;
    _socket?.dispose();
    _socket = null;
  }

  void _ensureSocketConnected() {
    final origin = _socketOrigin();
    final existing = _socket?.io.uri;
    if (_socket != null && socketConnected && existing == origin) {
      return;
    }

    _disconnectSocket();

    final options = <String, dynamic>{
      'transports': <String>['websocket', 'polling'],
      'autoConnect': false,
      'withCredentials': true,
    };

    final cookie = _backendClient.sessionCookie;
    if (!kIsWeb && cookie != null && cookie.isNotEmpty) {
      options['extraHeaders'] = <String, String>{'Cookie': cookie};
    }

    final socket = io.io(origin, options);
    socket.onConnect((_) {
      socketConnected = true;
      socket.emit('client:request_logs');
      socket.emit('integrations:status');
      if (_socketHasConnectedOnce && isAuthenticated) {
        unawaited(refresh());
      }
      _socketHasConnectedOnce = true;
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        transportState: 'connected',
        clearError: _hasRecoverableLiveVoiceTurn(),
      );
      if (_hasRecoverableLiveVoiceTurn()) {
        unawaited(
          ensureLiveVoiceSession().catchError((Object error) {
            voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
              transportState: 'disconnected',
              state: 'error',
              error: _friendlyErrorMessage(error),
            );
            notifyListeners();
          }),
        );
      }
      notifyListeners();
    });
    socket.onDisconnect((_) {
      socketConnected = false;
      if (isSendingMessage && activeRun != null) {
        isSendingMessage = false;
        activeRun = activeRun!.copyWith(
          phase: 'Disconnected',
          pendingSteeringCount: 0,
        );
      }
      if (_hasRecoverableLiveVoiceTurn()) {
        _setLiveVoiceRecoveryWindow();
        voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
          sessionId: '',
          transportState: hasNetworkConnection
              ? 'reconnecting'
              : 'disconnected',
          state: _liveVoiceCaptureActive
              ? 'listening'
              : voiceAssistantLiveState.state,
        );
      } else {
        _liveVoiceCaptureActive = false;
        _pendingLiveVoiceStop = false;
        voiceAssistantLiveState = VoiceAssistantLiveState(
          transportState: hasNetworkConnection
              ? 'reconnecting'
              : 'disconnected',
        );
      }
      notifyListeners();
    });
    socket.onConnectError((dynamic _) {
      socketConnected = false;
      if (_hasRecoverableLiveVoiceTurn()) {
        voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
          transportState: 'reconnecting',
        );
      }
      notifyListeners();
    });
    socket.on('server:log_history', (dynamic data) {
      final next = <LogEntry>[];
      if (data is List) {
        for (final item in data) {
          next.add(LogEntry.fromJson(_jsonMap(item)));
        }
      }
      _setServerLogs(next);
      notifyListeners();
    });
    socket.on('server:log', (dynamic data) {
      _appendServerLog(LogEntry.fromJson(_jsonMap(data)));
      notifyListeners();
    });
    socket.on('messaging:qr', (dynamic data) {
      final payload = _jsonMap(data);
      pendingMessagingQr = MessagingQrState(
        platform: payload['platform']?.toString() ?? 'whatsapp',
        qr: payload['qr']?.toString() ?? '',
      );
      notifyListeners();
    });
    socket.on('messaging:connected', (dynamic _) {
      pendingMessagingQr = null;
      unawaited(refreshMessaging());
    });
    socket.on('messaging:disconnected', (dynamic _) {
      pendingMessagingQr = null;
      unawaited(refreshMessaging());
    });
    socket.on('messaging:logged_out', (dynamic _) {
      pendingMessagingQr = null;
      unawaited(refreshMessaging());
    });
    socket.on('integrations:status', (dynamic data) {
      officialIntegrations = _decodeModelList(
        'official_integrations.socket',
        data,
        OfficialIntegrationItem.fromJson,
      );
      notifyListeners();
    });
    socket.on('messaging:sent', (dynamic data) {
      final payload = _jsonMap(data);
      messagingMessages = <MessagingMessage>[
        MessagingMessage.fromSocket(payload, outgoing: true),
        ...messagingMessages,
      ];
      _appendAssistantChatMessage(
        payload['content']?.toString() ?? '',
        platform:
            payload['platform']?.toString().ifEmpty('webchat') ?? 'webchat',
      );
      notifyListeners();
    });
    socket.on('messaging:message', (dynamic data) {
      final payload = _jsonMap(data);
      messagingMessages = <MessagingMessage>[
        MessagingMessage.fromSocket(payload, outgoing: false),
        ...messagingMessages,
      ];
      _appendUserChatMessage(
        payload['content']?.toString() ?? '',
        platform:
            payload['platform']?.toString().ifEmpty('webchat') ?? 'webchat',
      );
      notifyListeners();
    });
    socket.on('messaging:blocked_sender', (dynamic data) {
      final blockedNotice = BlockedSenderNotice.fromSocket(_jsonMap(data));
      final blocked = MessagingMessage.fromBlockedNotice(blockedNotice);
      messagingMessages = <MessagingMessage>[blocked, ...messagingMessages];
      _enqueueBlockedSenderNotice(blockedNotice);
      errorMessage =
          '${blocked.senderLabel} is blocked on ${blocked.platform.toUpperCase()}. Update the access list to allow replies.';
      notifyListeners();
    });
    socket.on('messaging:error', (dynamic data) {
      final payload = _jsonMap(data);
      errorMessage =
          payload['error']?.toString() ?? 'Messaging error. Please try again.';
      notifyListeners();
    });
    socket.on('recordings:updated', (dynamic data) {
      final payload = _jsonMap(data);
      final sessionId = payload['sessionId']?.toString() ?? '';
      if (sessionId.isEmpty) {
        unawaited(refreshRecordings());
        return;
      }
      unawaited(_refreshRecordingSessionById(sessionId));
    });
    socket.on('voice:session_ready', (dynamic data) {
      final payload = _jsonMap(data);
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        sessionId: payload['sessionId']?.toString() ?? '',
        runtimeMode:
            payload['runtimeMode']?.toString().ifEmpty('live') ?? 'live',
        provider:
            payload['provider']?.toString().ifEmpty(voiceLiveProvider) ??
            voiceLiveProvider,
        model:
            payload['model']?.toString().ifEmpty(voiceLiveModel) ??
            voiceLiveModel,
        voice:
            payload['voice']?.toString().ifEmpty(voiceLiveVoice) ??
            voiceLiveVoice,
        transportState: 'connected',
        state: 'idle',
        clearError: true,
      );
      if (_liveVoiceSessionOpenCompleter != null &&
          !_liveVoiceSessionOpenCompleter!.isCompleted) {
        _liveVoiceSessionOpenCompleter!.complete();
      }
      if (_hasRecoverableLiveVoiceTurn()) {
        unawaited(_restoreBufferedLiveVoiceTurnToActiveSession());
      }
      notifyListeners();
    });
    socket.on('voice:assistant_state', (dynamic data) {
      final payload = _jsonMap(data);
      if (!_matchesLiveVoiceSessionPayload(payload)) {
        return;
      }
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        state: payload['state']?.toString().ifEmpty('idle') ?? 'idle',
      );
      notifyListeners();
    });
    socket.on('voice:chunk_ack', (dynamic data) {
      final payload = _jsonMap(data);
      if (!_matchesLiveVoiceSessionPayload(payload)) {
        return;
      }
      final ackTurnId = payload['turnId']?.toString().trim() ?? '';
      if (ackTurnId.isEmpty || ackTurnId != (_liveVoiceTurnId ?? '').trim()) {
        return;
      }
      _liveVoiceAckThrough = math.max(
        _liveVoiceAckThrough,
        _asInt(payload['receivedThrough']),
      );
      for (final chunk in _liveVoiceBufferedChunks) {
        if (chunk.sequence <= _liveVoiceAckThrough) {
          chunk.sent = true;
        }
      }
      unawaited(_emitPendingLiveVoiceCommitIfReady());
    });
    socket.on('voice:transcript_partial', (dynamic data) {
      final payload = _jsonMap(data);
      if (!_matchesLiveVoiceSessionPayload(payload)) {
        return;
      }
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        partialTranscript: payload['content']?.toString() ?? '',
      );
      notifyListeners();
    });
    socket.on('voice:transcript_final', (dynamic data) {
      final payload = _jsonMap(data);
      if (!_matchesLiveVoiceSessionPayload(payload)) {
        return;
      }
      final content = payload['content']?.toString() ?? '';
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        partialTranscript: content,
        finalTranscript: content,
      );
      if (content.trim().isNotEmpty) {
        _appendUserChatMessage(content, platform: 'voice_live');
      }
      notifyListeners();
    });
    socket.on('voice:assistant_text', (dynamic data) {
      final payload = _jsonMap(data);
      if (!_matchesLiveVoiceSessionPayload(payload)) {
        return;
      }
      final content = payload['content']?.toString() ?? '';
      final kind = payload['kind']?.toString() ?? 'final';
      if (content.trim().isEmpty) {
        return;
      }
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        interimAssistantText: kind == 'final'
            ? voiceAssistantLiveState.interimAssistantText
            : content,
        finalAssistantText: kind == 'final'
            ? content
            : voiceAssistantLiveState.finalAssistantText,
        assistantText: content,
      );
      if (kind == 'final' && content.trim().isNotEmpty) {
        _resetLiveVoiceTurnBuffer();
        _appendAssistantChatMessage(content, platform: 'voice_live');
      }
      notifyListeners();
    });
    socket.on('voice:audio_chunk', (dynamic data) {
      final payload = _jsonMap(data);
      if (!_matchesLiveVoiceSessionPayload(payload)) {
        return;
      }
      final audioBase64 = payload['audioBase64']?.toString() ?? '';
      if (audioBase64.trim().isEmpty) return;
      final chunk = base64Decode(audioBase64);
      if (chunk.isEmpty) return;
      final mimeType = payload['mimeType']?.toString() ?? 'audio/mpeg';
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        audioMimeType: mimeType,
        audioQueue: <Uint8List>[...voiceAssistantLiveState.audioQueue, chunk],
        audioStreamDone: false,
      );
      notifyListeners();
    });
    socket.on('voice:audio_done', (dynamic data) {
      final payload = _jsonMap(data);
      if (!_matchesLiveVoiceSessionPayload(payload)) {
        return;
      }
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        audioStreamDone: true,
      );
      notifyListeners();
    });
    socket.on('voice:error', (dynamic data) {
      final payload = _jsonMap(data);
      if (!_matchesLiveVoiceSessionPayload(payload)) {
        return;
      }
      _resetLiveVoiceTurnBuffer();
      final message = payload['error']?.toString() ?? 'Live voice failed.';
      if (_liveVoiceSessionOpenCompleter != null &&
          !_liveVoiceSessionOpenCompleter!.isCompleted) {
        _liveVoiceSessionOpenCompleter!.completeError(StateError(message));
      }
      _liveVoiceSessionOpenCompleter = null;
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        error: message,
        state: payload['phase']?.toString() == 'tts' ? 'degraded' : 'idle',
        clearAudio: true,
        clearRecoverableUntil: true,
      );
      _liveVoiceCaptureActive = false;
      _pendingLiveVoiceStop = false;
      errorMessage = message;
      notifyListeners();
    });
    socket.on('run:start', (dynamic data) {
      final payload = _jsonMap(data);
      final triggerSource = payload['triggerSource']?.toString() ?? '';
      final runId = payload['runId']?.toString() ?? '';
      if (triggerSource == 'voice_live') {
        _voiceRunIds.add(runId);
        return;
      }
      final pendingSteeringCount = activeRun?.pendingSteeringCount ?? 0;
      if (_isBackgroundRun(triggerSource)) {
        _backgroundRunIds.add(runId);
        return;
      }
      activeRun = ActiveRunState(
        runId: runId,
        title:
            payload['title']?.toString().ifEmpty('Running task') ??
            'Running task',
        model: payload['model']?.toString() ?? '',
        triggerSource: triggerSource,
        phase: 'Starting',
        iteration: 0,
        pendingSteeringCount: pendingSteeringCount,
      );
      toolEvents = const <ToolEventItem>[];
      streamingAssistant = '';
      isSendingMessage = true;
      notifyListeners();
    });
    socket.on('run:thinking', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.contains(runId)) {
        return;
      }
      if (_backgroundRunIds.contains(runId)) {
        return;
      }
      if (activeRun?.runId == runId) {
        activeRun = activeRun!.copyWith(
          phase: 'Thinking',
          iteration: _asInt(payload['iteration']),
        );
        notifyListeners();
      }
    });
    socket.on('run:analysis', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.contains(runId)) {
        return;
      }
      if (_backgroundRunIds.contains(runId)) {
        return;
      }
      final summary = [
        'mode: ${payload['mode']?.toString() ?? 'execute'}',
        'verification: ${payload['verification_need']?.toString() ?? 'none'}',
        'freshness: ${payload['freshness_risk']?.toString() ?? 'none'}',
      ].join(' | ');
      toolEvents = <ToolEventItem>[
        ...toolEvents,
        ToolEventItem(
          id: 'analysis-${DateTime.now().microsecondsSinceEpoch}',
          toolName: 'analysis',
          type: 'analysis',
          status: 'completed',
          summary: summary,
        ),
      ];
      if (activeRun?.runId == runId) {
        activeRun = activeRun!.copyWith(phase: 'Analyzing');
      }
      notifyListeners();
    });
    socket.on('run:plan', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.contains(runId)) {
        return;
      }
      if (_backgroundRunIds.contains(runId)) {
        return;
      }
      final steps = _jsonList(payload['steps'], fallbackToMapValues: true)
          .map((item) {
            if (item is Map) {
              return item['title']?.toString() ?? '';
            }
            return item.toString();
          })
          .where((item) => item.trim().isNotEmpty)
          .take(4)
          .join(' | ');
      toolEvents = <ToolEventItem>[
        ...toolEvents,
        ToolEventItem(
          id: 'plan-${DateTime.now().microsecondsSinceEpoch}',
          toolName: 'plan',
          type: 'planning',
          status: 'completed',
          summary: steps.ifEmpty('Execution plan created.'),
        ),
      ];
      if (activeRun?.runId == runId) {
        activeRun = activeRun!.copyWith(phase: 'Planning');
      }
      notifyListeners();
    });
    socket.on('run:stopping', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.contains(runId)) {
        return;
      }
      if (_backgroundRunIds.contains(runId)) {
        return;
      }
      if (activeRun?.runId == runId) {
        activeRun = activeRun!.copyWith(phase: 'Stopping');
        notifyListeners();
      }
    });
    socket.on('run:tool_start', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.contains(runId)) {
        return;
      }
      if (_backgroundRunIds.contains(runId)) {
        return;
      }
      final item = ToolEventItem(
        id:
            payload['stepId']?.toString().ifEmpty(
              DateTime.now().microsecondsSinceEpoch.toString(),
            ) ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        toolName: payload['toolName']?.toString() ?? 'tool',
        type: payload['type']?.toString() ?? '',
        status: 'running',
        summary: _summarizeToolArgs(payload['toolArgs']),
      );
      toolEvents = <ToolEventItem>[
        ...toolEvents.where((event) => event.id != item.id),
        item,
      ];
      if (activeRun?.runId == runId) {
        activeRun = activeRun!.copyWith(phase: 'Running tool');
      }
      notifyListeners();
    });
    socket.on('run:verification', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.contains(runId)) {
        return;
      }
      if (_backgroundRunIds.contains(runId)) {
        return;
      }
      toolEvents = <ToolEventItem>[
        ...toolEvents,
        ToolEventItem(
          id: 'verification-${DateTime.now().microsecondsSinceEpoch}',
          toolName: 'verification',
          type: 'verification',
          status: payload['status']?.toString() == 'verified'
              ? 'completed'
              : 'failed',
          summary:
              payload['notes']?.toString().ifEmpty(
                'Verification status: ${payload['status']?.toString() ?? 'unknown'}',
              ) ??
              'Verification completed.',
        ),
      ];
      if (activeRun?.runId == runId) {
        activeRun = activeRun!.copyWith(phase: 'Verifying');
      }
      notifyListeners();
    });
    socket.on('run:subagent', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.contains(runId)) {
        return;
      }
      if (_backgroundRunIds.contains(runId)) {
        return;
      }
      final newId =
          'subagent-${payload['handle']?.toString() ?? DateTime.now().microsecondsSinceEpoch}';
      final nextEvents = toolEvents
          .where((event) => event.id != newId)
          .toList(growable: true);
      nextEvents.insert(
        0,
        ToolEventItem(
          id: newId,
          toolName: 'subagent',
          type: 'subagent',
          status: payload['status']?.toString() == 'failed'
              ? 'failed'
              : (payload['status']?.toString() == 'running'
                    ? 'running'
                    : 'completed'),
          summary:
              payload['task']?.toString().ifEmpty(
                payload['error']?.toString() ??
                    payload['result']?.toString() ??
                    'Subagent update.',
              ) ??
              'Subagent update.',
        ),
      );
      toolEvents = nextEvents;
      notifyListeners();
    });
    socket.on('run:tool_end', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.contains(runId)) {
        return;
      }
      if (_backgroundRunIds.contains(runId)) {
        return;
      }
      final stepId = payload['stepId']?.toString() ?? '';
      final updated = ToolEventItem(
        id: stepId,
        toolName: payload['toolName']?.toString() ?? 'tool',
        type: payload['type']?.toString() ?? '',
        status: payload['status']?.toString() ?? 'completed',
        summary:
            payload['error']?.toString() ??
            _summarizeToolResult(payload['result']),
      );
      var replaced = false;
      final next = toolEvents.map((event) {
        if (event.id == stepId) {
          replaced = true;
          return updated;
        }
        return event;
      }).toList();
      if (!replaced) {
        next.add(updated);
      }
      toolEvents = next;
      final toolName = payload['toolName']?.toString() ?? '';
      final screenshotPath =
          payload['screenshotPath']?.toString() ??
          (payload['result'] is Map
              ? (payload['result'] as Map)['screenshotPath']?.toString()
              : null);
      if (screenshotPath != null && screenshotPath.isNotEmpty) {
        if (toolName.startsWith('browser_')) {
          browserScreenshotPath = screenshotPath;
        } else if (toolName.startsWith('android_')) {
          androidScreenshotPath = screenshotPath;
        }
      }
      if (toolName.startsWith('browser_')) {
        unawaited(refreshDevices());
      } else if (toolName.startsWith('android_')) {
        unawaited(refreshDevices());
      }
      notifyListeners();
    });
    socket.on('run:steer_queued', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.contains(runId)) {
        return;
      }
      if (_backgroundRunIds.contains(runId)) {
        return;
      }
      toolEvents = <ToolEventItem>[
        ...toolEvents,
        ToolEventItem(
          id: 'steer-queued-${DateTime.now().microsecondsSinceEpoch}',
          toolName: 'steering',
          type: 'note',
          status: 'completed',
          summary:
              'Queued as steering for the current run: ${payload['content']?.toString() ?? ''}',
        ),
      ];
      if (activeRun?.runId == runId || activeRun?.runId == 'pending') {
        activeRun = activeRun!.copyWith(
          pendingSteeringCount: _asInt(payload['pendingCount']),
        );
      }
      notifyListeners();
    });
    socket.on('run:steer_applied', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.contains(runId)) {
        return;
      }
      if (_backgroundRunIds.contains(runId)) {
        return;
      }
      toolEvents = <ToolEventItem>[
        ...toolEvents,
        ToolEventItem(
          id: 'steer-applied-${DateTime.now().microsecondsSinceEpoch}',
          toolName: 'steering',
          type: 'note',
          status: 'completed',
          summary: payload['count'] == 1
              ? 'Applied the latest steering update to the current run.'
              : 'Applied ${_asInt(payload['count'])} queued steering updates to the current run.',
        ),
      ];
      if (activeRun?.runId == runId || activeRun?.runId == 'pending') {
        activeRun = activeRun!.copyWith(
          pendingSteeringCount: _asInt(payload['pendingCount']),
          phase: 'Incorporating steering',
        );
      }
      notifyListeners();
    });
    socket.on('run:interim', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.contains(runId)) {
        return;
      }
      _appendToolNote(payload['message']?.toString() ?? '');
      if (runId.isNotEmpty && activeRun?.runId == runId) {
        final phase = payload['phase']?.toString().trim() ?? '';
        if (phase.isNotEmpty) {
          activeRun = activeRun!.copyWith(phase: phase);
        }
      }
      notifyListeners();
    });
    socket.on('run:assistant_interim', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.contains(runId)) {
        return;
      }
      final content = payload['content']?.toString() ?? '';
      final kind =
          payload['kind']?.toString().ifEmpty('progress') ?? 'progress';
      final platform = payload['platform']?.toString().ifEmpty('web') ?? 'web';
      _appendAssistantChatMessage(content, platform: platform);
      _appendToolNote(content, toolName: 'interim_$kind');
      if (activeRun?.runId == runId) {
        activeRun = activeRun!.copyWith(phase: 'Responding');
      }
      notifyListeners();
    });
    socket.on('run:stream', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.contains(runId)) {
        return;
      }
      if (_backgroundRunIds.contains(runId)) {
        return;
      }
      streamingAssistant = payload['content']?.toString() ?? '';
      if (activeRun?.runId == runId) {
        activeRun = activeRun!.copyWith(
          phase: toolEvents.any((event) => event.status == 'running')
              ? 'Running tool'
              : 'Streaming',
        );
      }
      notifyListeners();
    });
    socket.on('run:complete', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.remove(runId)) {
        return;
      }
      if (_backgroundRunIds.remove(runId)) {
        unawaited(refreshRunsOnly());
        unawaited(refreshMemory());
        notifyListeners();
        return;
      }
      final content = payload['content']?.toString().trim() ?? '';
      if (content.isNotEmpty) {
        _appendAssistantChatMessage(content, platform: 'web');
      }
      streamingAssistant = '';
      isSendingMessage = false;
      if (activeRun?.runId == runId) {
        activeRun = activeRun!.copyWith(
          phase: 'Completed',
          pendingSteeringCount: 0,
        );
      }
      unawaited(refreshRunsOnly());
      notifyListeners();
    });
    socket.on('run:stopped', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.remove(runId)) {
        return;
      }
      if (_backgroundRunIds.remove(runId)) {
        unawaited(refreshRunsOnly());
        unawaited(refreshMemory());
        notifyListeners();
        return;
      }
      streamingAssistant = '';
      isSendingMessage = false;
      if (activeRun?.runId == runId) {
        activeRun = activeRun!.copyWith(
          phase: 'Stopped',
          pendingSteeringCount: 0,
        );
      }
      unawaited(refreshRunsOnly());
      notifyListeners();
    });
    socket.on('run:error', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString();
      if (runId != null && _voiceRunIds.remove(runId)) {
        _resetLiveVoiceTurnBuffer();
        voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
          error:
              payload['error']?.toString() ??
              'I could not complete that voice request.',
          state: 'idle',
          clearRecoverableUntil: true,
        );
        notifyListeners();
        return;
      }
      if (runId != null) {
        if (_backgroundRunIds.remove(runId)) {
          unawaited(refreshRunsOnly());
          notifyListeners();
          return;
        }
      }
      streamingAssistant = '';
      activeRun = null;
      isSendingMessage = false;
      errorMessage =
          'I could not complete that request right now. Please try again in a moment.';
      notifyListeners();
    });
    socket.on('tasks:task_complete', (dynamic _) {
      unawaited(refreshTasks());
    });
    socket.on('tasks:task_running', (dynamic _) {
      unawaited(refreshTasks());
    });
    socket.on('tasks:task_error', (dynamic _) {
      unawaited(refreshTasks());
    });
    socket.on('tasks:task_deleted', (dynamic _) {
      unawaited(refreshTasks());
    });
    socket.on('tasks:task_skipped', (dynamic _) {
      unawaited(refreshTasks());
    });
    socket.on('skill:draft_created', (dynamic _) {
      unawaited(refreshSkills());
    });
    socket.connect();
    _socket = socket;
  }

  bool _isBackgroundRun(String triggerSource) {
    return triggerSource == 'schedule' ||
        triggerSource == 'tasks' ||
        triggerSource == 'messaging';
  }

  String _socketOrigin() {
    final trimmed = backendUrl.trim();
    if (trimmed.isEmpty) {
      final base = Uri.base;
      final port = base.hasPort ? ':${base.port}' : '';
      return '${base.scheme}://${base.host}$port';
    }
    final uri = Uri.parse(trimmed);
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port';
  }
}
