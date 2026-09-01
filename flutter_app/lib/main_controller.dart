part of 'main.dart';

class NeoAgentController extends ChangeNotifier {
  NeoAgentController({
    this.appMode = NeoAgentAppMode.standard,
    required BackendClient backendClient,
    required HealthBridge healthBridge,
    OAuthLauncher? oauthLauncher,
    WebAuthnClient? webAuthnClient,
  }) : _backendClient = backendClient,
       _healthBridge = healthBridge,
       _oauthLauncher = oauthLauncher ?? createOAuthLauncher(),
       _webAuthnClient = webAuthnClient ?? createWebAuthnClient() {
    _desktopCompanion.addListener(_onDesktopCompanionChanged);
    AndroidAutoBridge.instance.onStartVoiceMode = startLiveVoiceCapture;
    AndroidAutoBridge.instance.onStopVoiceMode = interruptLiveVoiceAssistant;

    _clientLogs = AppDiagnostics.recentEntries
        .map(_logEntryFromDiagnostic)
        .toList(growable: false);
    _rebuildLogs();
    _diagnosticLogSubscription = AppDiagnostics.stream.listen(
      _handleDiagnosticLogEntry,
    );
  }

  final NeoAgentAppMode appMode;
  final BackendClient _backendClient;
  final HealthBridge _healthBridge;
  final OAuthLauncher _oauthLauncher;
  final WebAuthnClient _webAuthnClient;
  final BackendDiscoveryService _backendDiscoveryService =
      BackendDiscoveryService();
  final app_release_updater.AppReleaseUpdater _appReleaseUpdater =
      app_release_updater.AppReleaseUpdater();
  final LiveVoiceCapture _liveVoiceCapture = LiveVoiceCapture();
  final DesktopCompanionManager _desktopCompanion = DesktopCompanionManager(
    screenCapture: createDesktopScreenCapture(),
  );
  StreamSubscription<AppDiagnosticEntry>? _diagnosticLogSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _connectivityPluginAvailable = true;
  static const int _maxVisibleLogs = 400;
  static const int _maxToolEvents =
      500; // separate list from _maxVisibleLogs (chat diagnostics)

  static const String _configuredBackendUrl = String.fromEnvironment(
    'NEOAGENT_BACKEND_URL',
  );
  static const String _selectedSectionPrefsKey = 'ui.selectedSection';
  static const String _selectedAgentPrefsKey = 'ui.selectedAgentId';
  static const String _desktopWorkspaceModePrefsKey = 'desktop.workspaceMode';
  static const Set<String> _workspaceToolNames = <String>{
    'read_file',
    'read_files',
    'write_file',
    'edit_file',
    'replace_file_range',
    'list_directory',
    'search_files',
  };

  SharedPreferences? _prefs;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  io.Socket? _socket;
  Timer? _updatePollTimer;
  Timer? _qrLoginPollTimer;
  Timer? _manualRunCooldownTimer;
  final Set<String> _backgroundRunIds = <String>{};
  final Set<String> _voiceRunIds = <String>{};
  final Set<String> _busyOfficialIntegrationKeys = <String>{};
  final Set<String> _busyMessagingPlatformKeys = <String>{};
  final Map<String, DateTime> _manualRunCooldowns = <String, DateTime>{};
  static const Duration _manualRunCooldownDuration = Duration(seconds: 10);
  static const int _chatHistoryPageSize = 20;
  int _authCycle = 0;
  bool _isPollingQrLogin = false;
  bool _socketHasConnectedOnce = false;
  bool _onboardingManuallyReopened = false;
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
  int _activeSettingsSaves = 0;
  int _pendingSettingsWrites = 0;
  int _settingsMutationId = 0;
  Future<void> _settingsWriteTail = Future<void>.value();
  bool isSavingBackendUrl = false;
  bool isLoadingAccountSettings = false;
  bool isSavingAccountSettings = false;
  bool isConfiguringTwoFactor = false;
  bool isUsingSecurityKey = false;
  bool isRevokingSession = false;
  bool isTriggeringUpdate = false;
  bool isSavingReleaseChannel = false;
  bool isSyncingHealth = false;
  bool isRunningDeviceAction = false;
  bool isLoadingWorkspaceFiles = false;
  bool isSavingWorkspaceFile = false;
  bool isPreparingQrLogin = false;
  bool isApprovingQrLogin = false;
  bool isCheckingAppUpdate = false;
  bool isOpeningAppUpdate = false;
  bool isLoadingBilling = false;
  bool showBillingSection = false;
  bool socketConnected = false;
  bool hasNetworkConnection = true;
  bool networkStatusKnown = false;
  bool isDiscoveringBackends = false;
  bool desktopCoworkMode = false;
  bool isLoadingCowork = false;

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
  String? backendDiscoveryErrorMessage;
  List<BackendDiscoveryCandidate> discoveredBackends =
      const <BackendDiscoveryCandidate>[];
  String setupProfile = 'quick';
  bool setupComplete = true;
  List<String> setupOpenSections = const <String>[];

  AppSection selectedSection = AppSection.chat;
  Map<String, dynamic>? user;
  Map<String, dynamic> accountTwoFactor = const <String, dynamic>{};
  List<AccountSessionItem> accountSessions = const <AccountSessionItem>[];
  AccountUsageAndLimits? usageAndLimits;
  List<AuthProviderCatalogItem> authProviders =
      const <AuthProviderCatalogItem>[];
  List<LinkedAuthProviderItem> linkedAuthProviders =
      const <LinkedAuthProviderItem>[];
  List<SecurityKeyItem> accountSecurityKeys = const <SecurityKeyItem>[];
  QrLoginChallenge? qrLoginChallenge;
  Map<String, dynamic> settings = const <String, dynamic>{};
  Map<String, dynamic> behaviorConfig = const <String, dynamic>{};
  Map<String, dynamic>? versionInfo;
  Map<String, dynamic>? backendHealthStatus;
  HealthBridgeStatus? deviceHealthStatus;

  List<ChatEntry> chatMessages = const <ChatEntry>[];
  List<CoworkChat> coworkChats = const <CoworkChat>[];
  String? selectedCoworkChatId;
  final Map<String, CoworkThreadState> _coworkThreads =
      <String, CoworkThreadState>{};
  CoworkDeviceSelection? coworkDefaultDevice;
  bool coworkWorkSurfacePinned = false;
  bool chatHistoryHasMore = false;
  bool isLoadingOlderChatHistory = false;
  List<AgentProfile> agentProfiles = const <AgentProfile>[];
  String? selectedAgentId;
  List<ModelMeta> supportedModels = const <ModelMeta>[];
  List<AiProviderMeta> aiProviders = const <AiProviderMeta>[];
  List<RunSummary> recentRuns = const <RunSummary>[];
  List<TimelineEventItem> timelineItems = const <TimelineEventItem>[];
  TokenUsageSnapshot? tokenUsage;
  Map<String, dynamic>? billingSubscription;
  List<Map<String, dynamic>> billingPlans = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> billingInvoices = const <Map<String, dynamic>>[];
  UpdateStatusSnapshot updateStatus = const UpdateStatusSnapshot();
  List<LogEntry> logs = const <LogEntry>[];
  Map<String, MessagingPlatformStatus> messagingStatuses =
      const <String, MessagingPlatformStatus>{};
  List<MessagingMessage> messagingMessages = const <MessagingMessage>[];
  Map<String, MessagingAccessCatalog> messagingAccessCatalogs =
      const <String, MessagingAccessCatalog>{};
  MessagingQrState? pendingMessagingQr;
  ToolApprovalRequest? pendingApproval;
  final List<BlockedSenderNotice> _blockedSenderQueue = <BlockedSenderNotice>[];
  final Set<String> _ignoredChats = <String>{};
  List<SkillItem> skills = const <SkillItem>[];
  List<StoreSkillItem> storeSkills = const <StoreSkillItem>[];
  List<OfficialIntegrationItem> officialIntegrations =
      const <OfficialIntegrationItem>[];
  MemoryOverview memoryOverview = const MemoryOverview();
  List<MemoryItem> memories = const <MemoryItem>[];
  List<MemoryItem> memoryRecallResults = const <MemoryItem>[];
  List<ConversationItem> memoryConversations = const <ConversationItem>[];
  List<TaskItem> taskItems = const <TaskItem>[];
  List<McpServerItem> mcpServers = const <McpServerItem>[];
  Map<String, dynamic> _computerRuntime = const <String, dynamic>{
    'state': 'stopped',
  };
  final Map<String, Map<String, dynamic>> _computerRuntimeByProvider =
      <String, Map<String, dynamic>>{};
  Timer? _localDisconnectHoldTimer;
  bool _localDisplayConnected = false;

  Map<String, dynamic> get computerRuntime => _computerRuntime;
  set computerRuntime(Map<String, dynamic> value) => _setComputerRuntime(value);
  Map<String, dynamic> teachRuntime = const <String, dynamic>{'status': 'idle'};
  String? computerDisplayUrl;
  String computerTerminalOutput = '';
  Map<String, dynamic> computerBrowserRuntime = const <String, dynamic>{};
  String? computerBrowserScreenshotPath;
  Map<String, dynamic> socialReachStatus = const <String, dynamic>{};
  Map<String, dynamic> androidRuntime = const <String, dynamic>{};
  List<String> androidInstalledApps = const <String>[];
  List<Map<String, dynamic>> androidUiPreview = const <Map<String, dynamic>>[];
  String? androidScreenshotPath;
  String? androidLastResult;
  String? androidUiDumpPath;
  String workspaceCurrentPath = '';
  String? workspaceSelectedFilePath;
  String workspaceEditorContent = '';
  List<Map<String, dynamic>> workspaceEntries = const <Map<String, dynamic>>[];
  final Map<String, RunDetailSnapshot> _runDetailsCache =
      <String, RunDetailSnapshot>{};
  String? _pendingChatDraft;
  List<SharedChatAttachment> _pendingSharedChatAttachments =
      const <SharedChatAttachment>[];
  String? _chatHistoryBeforeCreatedAt;
  String? _chatHistoryBeforeSource;
  String? _chatHistoryBeforeId;
  String? _requestedRunFocusId;

  CoworkChat? get selectedCoworkChat {
    final id = selectedCoworkChatId;
    if (id == null) return null;
    for (final chat in coworkChats) {
      if (chat.id == id) return chat;
    }
    return null;
  }

  CoworkThreadState get selectedCoworkThread =>
      _coworkThreads[selectedCoworkChatId] ?? const CoworkThreadState();

  CoworkThreadState coworkThreadFor(String conversationId) =>
      _coworkThreads[conversationId] ?? const CoworkThreadState();

  ActiveRunState? activeRun;
  List<ToolEventItem> toolEvents = const <ToolEventItem>[];
  String streamingAssistant = '';
  // Which model turn the live bubble belongs to, so a new turn replaces it
  // rather than appearing to edit the previous one.
  int _streamingIteration = 0;
  bool _isStartingLiveVoice = false;
  bool _isStoppingLiveVoice = false;
  bool _liveVoiceCaptureActive = false;
  DateTime? _liveVoiceCaptureStartedAt;
  bool _pendingLiveVoiceStop = false;
  int _liveVoiceTurnCounter = 0;
  String? _liveVoiceTurnId;
  final List<LiveVoiceBufferedChunk> _liveVoiceBufferedChunks =
      <LiveVoiceBufferedChunk>[];
  final Set<String> _liveVoiceAudioKeys = <String>{};
  int _liveVoiceAckThrough = -1;
  int _liveVoiceFinalSequence = -1;
  bool _liveVoiceCommitPending = false;
  bool _liveVoiceAwaitingResponse = false;
  Map<String, dynamic>? _liveVoicePendingCommitPayload;
  DateTime? _liveVoiceRecoverableUntil;
  Timer? _liveVoiceRecoveryTimer;
  Timer? _incomingCallExpiryTimer;
  Completer<void>? _liveVoiceSessionOpenCompleter;
  VoiceAssistantLiveState voiceAssistantLiveState = VoiceAssistantLiveState();
  IncomingAgentCall? incomingAgentCall;
  bool _desktopAskOnClose = true;
  bool _desktopKeepRunningOnClose = true;
  bool _desktopAssistantHotkeyEnabled = true;
  bool isRefreshingTimeline = false;
  Set<String> selectedTimelineSources = <String>{'tasks', 'runs'};

  bool get isLauncherMode => appMode == NeoAgentAppMode.launcher;
  bool get localComputerSupported => _desktopCompanion.supported;
  bool get localComputerConnected => _desktopCompanion.connected;
  bool get localComputerDisplayConnected =>
      localComputerSupported &&
      (_desktopCompanion.connected || _localDisplayConnected);
  bool get localComputerConnecting => _desktopCompanion.connecting;
  bool get localComputerEnabled => _desktopCompanion.enabled;
  String? get localComputerError => _desktopCompanion.errorMessage;
  String? get localComputerPendingPermission =>
      _desktopCompanion.pendingPermission;
  Set<String> get localComputerPermissions =>
      _desktopCompanion.grantedPermissions;
  Map<String, Object?> get localComputerStatus => _desktopCompanion.status;
  String get computerProvider =>
      computerRuntime['provider']?.toString() == 'local' ? 'local' : 'cloud';
  String? get requestedRunFocusId => _requestedRunFocusId;

  bool get hasLiveRun => isSendingMessage && activeRun != null;

  bool isOfficialIntegrationBusy(String key) =>
      _busyOfficialIntegrationKeys.contains(key);
  bool isMessagingPlatformBusy(String platform, String action) =>
      _busyMessagingPlatformKeys.contains('$platform:$action');

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

  bool _matchesSelectedAgent(String? agentId) {
    final selected = selectedAgentId?.trim() ?? '';
    if (selected.isEmpty) {
      return true;
    }
    final incoming = agentId?.trim() ?? '';
    if (incoming.isEmpty) {
      // Legacy payloads without agent scope belong to the default/main agent.
      final active = activeAgent;
      return active == null || active.isDefault || active.id == selected;
    }
    return incoming == selected;
  }

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
    _incomingCallExpiryTimer?.cancel();
    _socket?.dispose();
    _diagnosticLogSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _appReleaseUpdater.dispose();
    _backendDiscoveryService.dispose();
    _desktopCompanion.removeListener(_onDesktopCompanionChanged);
    _localDisconnectHoldTimer?.cancel();
    unawaited(_desktopCompanion.disconnect());
    unawaited(_liveVoiceCapture.dispose());
    _oauthLauncher.dispose();
    super.dispose();
  }

  bool get desktopAskOnClose => _desktopAskOnClose;

  bool get desktopKeepRunningOnClose => _desktopKeepRunningOnClose;

  bool get desktopAssistantHotkeyEnabled => _desktopAssistantHotkeyEnabled;

  String? get sessionCookie => _backendClient.sessionCookie;

  BackendClient get backendClient => _backendClient;

  void clearPendingApproval() {
    pendingApproval = null;
    notifyListeners();
  }

  void clearPendingApprovalForRun(String runId) {
    if (pendingApproval?.runId != runId) return;
    _AppNotificationService.cancelApprovalNotification(
      pendingApproval?.approvalId ?? '',
    );
    pendingApproval = null;
    notifyListeners();
  }

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

  void _appendChatMessage(
    String content, {
    required String role,
    required String platform,
    bool transient = false,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final previous = chatMessages.isNotEmpty ? chatMessages.last : null;
    if (previous != null &&
        previous.role == role &&
        previous.platform == platform &&
        previous.content.trim() == trimmed &&
        metadata.isEmpty) {
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
        metadata: metadata,
      ),
    ];
  }

  void _resetChatHistoryPagination() {
    chatHistoryHasMore = false;
    isLoadingOlderChatHistory = false;
    _chatHistoryBeforeCreatedAt = null;
    _chatHistoryBeforeSource = null;
    _chatHistoryBeforeId = null;
  }

  void _applyChatHistoryCursor(Map<String, dynamic> history) {
    chatHistoryHasMore = history['hasMore'] == true;
    _chatHistoryBeforeCreatedAt = _optionalIdFrom(
      history['nextBeforeCreatedAt'],
    );
    _chatHistoryBeforeSource = _optionalIdFrom(history['nextBeforeSource']);
    _chatHistoryBeforeId = _optionalIdFrom(history['nextBeforeId']);
  }

  String _chatEntryKey(ChatEntry entry) {
    final stableId = entry.id.trim();
    if (stableId.isNotEmpty) {
      return [
        stableId,
        entry.platform,
        entry.role,
        entry.createdAt.toIso8601String(),
      ].join('|');
    }
    return [
      entry.role,
      entry.platform,
      entry.createdAt.toIso8601String(),
      entry.content,
    ].join('|');
  }

  List<ChatEntry> _chatHistoryEntriesFromResponse(
    Map<String, dynamic> history,
  ) {
    return _decodeModelList(
      'chat_history',
      history['messages'],
      ChatEntry.fromJson,
      fallbackToMapValues: true,
    );
  }

  Future<bool> loadOlderChatHistory() async {
    if (!isAuthenticated ||
        isLoadingOlderChatHistory ||
        !chatHistoryHasMore ||
        _chatHistoryBeforeCreatedAt == null ||
        _chatHistoryBeforeSource == null ||
        _chatHistoryBeforeId == null) {
      return false;
    }

    final agentId = _scopedAgentId;
    final beforeCreatedAt = _chatHistoryBeforeCreatedAt;
    final beforeSource = _chatHistoryBeforeSource;
    final beforeId = _chatHistoryBeforeId;
    isLoadingOlderChatHistory = true;
    notifyListeners();
    try {
      final history = await _backendClient.fetchChatHistory(
        backendUrl,
        agentId: agentId,
        limit: _chatHistoryPageSize,
        beforeCreatedAt: beforeCreatedAt,
        beforeSource: beforeSource,
        beforeId: beforeId,
      );
      if (agentId != _scopedAgentId) {
        return false;
      }
      final olderMessages = _chatHistoryEntriesFromResponse(history);
      _applyChatHistoryCursor(history);
      if (olderMessages.isEmpty) {
        return false;
      }
      final existingKeys = chatMessages.map(_chatEntryKey).toSet();
      final prepended = olderMessages
          .where((entry) => existingKeys.add(_chatEntryKey(entry)))
          .toList(growable: false);
      if (prepended.isEmpty) {
        return false;
      }
      chatMessages = <ChatEntry>[...prepended, ...chatMessages];
      return true;
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      return false;
    } finally {
      isLoadingOlderChatHistory = false;
      notifyListeners();
    }
  }

  String _settingString(String key, String fallback, {bool lowercase = false}) {
    final value = settings[key]?.toString().trim() ?? '';
    if (value.isEmpty) {
      return fallback;
    }
    return lowercase ? value.toLowerCase() : value;
  }

  BlockedSenderNotice? get pendingBlockedSenderNotice =>
      _blockedSenderQueue.isEmpty ? null : _blockedSenderQueue.first;

  List<String> get ignoredChats => _ignoredChats.toList();

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
    _rebuildLogs();
    notifyListeners();
  }

  void _rebuildLogs() {
    logs = List<LogEntry>.from(_clientLogs, growable: false);
  }

  Future<void> bootstrap() async {
    _prefs = await SharedPreferences.getInstance();
    _ignoredChats.addAll(
      _prefs?.getStringList('messaging.ignored_chats') ?? <String>[],
    );
    await _desktopCompanion.bootstrap(_prefs!);
    final configured = _configuredBackendUrl.trim();
    final savedBackendUrl = _prefs?.getString('backend_url')?.trim() ?? '';
    backendUrl = configured.isNotEmpty ? _defaultBackendUrl : savedBackendUrl;
    username = _prefs?.getString('username') ?? '';
    password = '';
    _desktopAskOnClose = _prefs?.getBool('desktop.askOnClose') ?? true;
    _desktopKeepRunningOnClose =
        _prefs?.getBool('desktop.keepRunningOnClose') ?? true;
    _desktopAssistantHotkeyEnabled =
        _prefs?.getBool('desktop.assistantHotkeyEnabled') ?? true;
    desktopCoworkMode = _supportsDesktopShell
        ? _prefs?.getString(_desktopWorkspaceModePrefsKey) == 'cowork'
        : false;
    _restoreSelectedSectionFromPrefs();
    appUpdateChannel =
        _prefs?.getString('app.update.channel')?.trim().toLowerCase() == 'beta'
        ? 'beta'
        : 'stable';
    appUpdateAutoCheckEnabled =
        _prefs?.getBool('app.update.autoCheckEnabled') ?? true;
    installedAppVersion = await _safeLoadInstalledAppVersion();
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
      unawaited(discoverBackends());
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
        _syncOnboardingFromAccount();
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

  Future<void> discoverBackends() async {
    if (isDiscoveringBackends || kIsWeb) return;
    isDiscoveringBackends = true;
    backendDiscoveryErrorMessage = null;
    notifyListeners();
    try {
      discoveredBackends = await _backendDiscoveryService.discover();
    } catch (_) {
      backendDiscoveryErrorMessage =
          'Local NeoAgent discovery is temporarily unavailable.';
    } finally {
      isDiscoveringBackends = false;
      notifyListeners();
    }
  }

  Future<bool> saveBackendUrl(
    String rawValue, {
    String? setupClaimToken,
  }) async {
    final normalized = _normalizeBackendUrl(rawValue);
    if (normalized.isEmpty) {
      errorMessage = 'Enter the address of a NeoAgent server.';
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
      final claimToken = setupClaimToken?.trim() ?? '';
      if (claimToken.isNotEmpty) {
        await _backendClient.exchangeSetupClaim(
          baseUrl: normalized,
          token: claimToken,
        );
        final pendingSessionCookie = _backendClient.sessionCookie?.trim() ?? '';
        if (pendingSessionCookie.isNotEmpty) {
          try {
            await _secureStorage.write(
              key: _sessionCookieSecureStorageKey,
              value: pendingSessionCookie,
            );
            await _prefs?.setString(_sessionCookieBackendPrefsKey, normalized);
          } catch (_) {}
        }
      }
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

    _syncOnboardingFromAccount();

    _clearQrLoginChallenge();
    await _persistCredentials();
    await refresh();
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
    final logoutFuture = _backendClient.logout(backendUrl);
    _authCycle += 1;
    _clearAuthenticatedState();
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
    _onboardingManuallyReopened = false;
    showOnboarding = false;
    notifyListeners();
    try {
      await _backendClient.completeOnboarding(backendUrl);
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
    _onboardingManuallyReopened = true;
    showOnboarding = true;
    notifyListeners();
  }

  bool _userHasCompletedOnboarding(Map<String, dynamic>? account) {
    final raw = account?['hasCompletedOnboarding'];
    return raw == true || raw == 1 || raw == '1' || raw == 'true';
  }

  void _syncOnboardingFromAccount() {
    final hasCompletedOnboarding = _userHasCompletedOnboarding(user);
    if (hasCompletedOnboarding) {
      if (!_onboardingManuallyReopened) {
        showOnboarding = false;
      }
      return;
    }
    _onboardingManuallyReopened = false;
    showOnboarding = true;
  }

  void _clearAuthenticatedState() {
    _disconnectSocket();
    _updatePollTimer?.cancel();
    _updatePollTimer = null;
    _clearQrLoginChallenge();
    isAuthenticated = false;
    isRefreshing = false;
    showOnboarding = false;
    _onboardingManuallyReopened = false;
    _busyMessagingPlatformKeys.clear();
    isAwaitingTwoFactor = false;
    pendingTwoFactorUsername = '';
    errorMessage = null;
    authInfoMessage = null;
    user = null;
    accountTwoFactor = const <String, dynamic>{};
    accountSessions = const <AccountSessionItem>[];
    usageAndLimits = null;
    linkedAuthProviders = const <LinkedAuthProviderItem>[];
    accountSecurityKeys = const <SecurityKeyItem>[];
    settings = const <String, dynamic>{};
    behaviorConfig = const <String, dynamic>{};
    chatMessages = const <ChatEntry>[];
    _resetChatHistoryPagination();
    agentProfiles = const <AgentProfile>[];
    selectedAgentId = null;
    unawaited(_persistSelectedAgentId(null));
    supportedModels = const <ModelMeta>[];
    aiProviders = const <AiProviderMeta>[];
    recentRuns = const <RunSummary>[];
    coworkChats = const <CoworkChat>[];
    selectedCoworkChatId = null;
    _coworkThreads.clear();
    coworkDefaultDevice = null;
    isLoadingCowork = false;
    timelineItems = const <TimelineEventItem>[];
    isRefreshingTimeline = false;
    tokenUsage = null;
    updateStatus = const UpdateStatusSnapshot();
    _clientLogs = const <LogEntry>[];
    logs = const <LogEntry>[];
    messagingStatuses = const <String, MessagingPlatformStatus>{};
    messagingMessages = const <MessagingMessage>[];
    messagingAccessCatalogs = const <String, MessagingAccessCatalog>{};
    pendingMessagingQr = null;
    skills = const <SkillItem>[];
    storeSkills = const <StoreSkillItem>[];
    officialIntegrations = const <OfficialIntegrationItem>[];
    setupProfile = 'quick';
    setupComplete = true;
    setupOpenSections = const <String>[];
    memoryOverview = const MemoryOverview();
    memories = const <MemoryItem>[];
    memoryRecallResults = const <MemoryItem>[];
    memoryConversations = const <ConversationItem>[];
    taskItems = const <TaskItem>[];
    mcpServers = const <McpServerItem>[];
    androidRuntime = const <String, dynamic>{};
    androidInstalledApps = const <String>[];
    androidUiPreview = const <Map<String, dynamic>>[];
    androidScreenshotPath = null;
    androidLastResult = null;
    androidUiDumpPath = null;
    versionInfo = null;
    backendHealthStatus = null;
    activeRun = null;
    toolEvents = const <ToolEventItem>[];
    streamingAssistant = '';
    selectedSection = AppSection.chat;
    unawaited(
      _prefs?.setString(_selectedSectionPrefsKey, AppSection.chat.name),
    );
    unawaited(_syncDesktopCompanionSession());
    _pendingChatDraft = null;
    _runDetailsCache.clear();
    unawaited(
      _healthBridge.configureBackgroundSync(
        enabled: false,
        backendUrl: backendUrl,
        sessionCookie: '',
      ),
    );
  }

  Future<void> _persistCredentials() async {
    await _prefs?.setString('username', username);
    await _prefs?.remove('password');
    final sessionCookie = _backendClient.sessionCookie?.trim() ?? '';
    final shouldPersistSession = isAuthenticated && sessionCookie.isNotEmpty;
    if (shouldPersistSession) {
      var storedSecurely = false;
      try {
        await _secureStorage.write(
          key: _sessionCookieSecureStorageKey,
          value: sessionCookie,
        );
        storedSecurely = true;
      } catch (_) {}
      if (storedSecurely) {
        await _prefs?.remove(_sessionCookiePrefsKey);
      } else {
        await _prefs?.setString(_sessionCookiePrefsKey, sessionCookie);
      }
      await _prefs?.setString(_sessionCookieBackendPrefsKey, backendUrl);
      await _syncDesktopCompanionSession();
      return;
    }
    await _prefs?.remove(_sessionCookiePrefsKey);
    await _prefs?.remove(_sessionCookieBackendPrefsKey);
    try {
      await _secureStorage.delete(key: _sessionCookieSecureStorageKey);
    } catch (_) {}
    await _syncDesktopCompanionSession();
  }

  bool _lastCompanionConnected = false;

  void _setComputerRuntime(Map<String, dynamic> incoming) {
    final snapshot = Map<String, dynamic>.from(incoming);
    final provider = snapshot['provider']?.toString() == 'local'
        ? 'local'
        : 'cloud';
    _computerRuntimeByProvider[provider] = snapshot;
    _computerRuntime = snapshot;
  }

  Map<String, dynamic> computerRuntimeFor(String? target) {
    final provider = target == 'local' || target == 'cloud'
        ? target!
        : computerProvider;
    final scoped = _computerRuntimeByProvider[provider];
    if (scoped != null) return scoped;
    if (_computerRuntime['provider']?.toString() == provider) {
      return _computerRuntime;
    }
    return provider == 'local'
        ? const <String, dynamic>{'state': 'stopped', 'provider': 'local'}
        : _computerRuntime;
  }

  void _onDesktopCompanionChanged() {
    final connected = _desktopCompanion.connected;
    if (connected) {
      _localDisconnectHoldTimer?.cancel();
      _localDisconnectHoldTimer = null;
      _localDisplayConnected = true;
    } else if (_localDisplayConnected && _localDisconnectHoldTimer == null) {
      _localDisconnectHoldTimer = Timer(const Duration(seconds: 2), () {
        _localDisconnectHoldTimer = null;
        if (!_desktopCompanion.connected) {
          _localDisplayConnected = false;
          notifyListeners();
        }
      });
    }
    notifyListeners();
    if (!isAuthenticated) {
      _lastCompanionConnected = connected;
      return;
    }
    if (connected == _lastCompanionConnected) return;
    _lastCompanionConnected = connected;
    if (connected) {
      unawaited(refreshComputerRuntime(silent: true, deviceTarget: 'local'));
    }
  }

  Future<void> _syncDesktopCompanionSession() {
    return _desktopCompanion.updateSession(
      backendUrl: backendUrl,
      sessionCookie: _backendClient.sessionCookie ?? '',
      authenticated: isAuthenticated,
    );
  }

  Future<void> ensureLocalDeviceConnected() async {
    if (!isAuthenticated || !_desktopCompanion.supported || _prefs == null) {
      return;
    }
    if (!_desktopCompanion.enabled) {
      await _desktopCompanion.setEnabled(true, _prefs!);
    }
    await _syncDesktopCompanionSession();
    await _desktopCompanion.reconnectIfNeeded();
  }

  Future<void> handleAppResumed() async {
    if (!isAuthenticated) return;
    await _desktopCompanion.reconnectIfNeeded(force: true);
    _ensureSocketConnected();
    unawaited(refreshComputerRuntime(silent: true));
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

  void setSelectedSection(AppSection section) {
    selectedSection = section;
    unawaited(_prefs?.setString(_selectedSectionPrefsKey, section.name));
    if (section == AppSection.devices) {
      unawaited(refreshDevices());
    }
    if (section == AppSection.timeline) {
      unawaited(refreshTimeline());
    }
    if (section == AppSection.accountSettings) {
      unawaited(refreshAccountSettings());
    }
    if (section == AppSection.billing) {
      unawaited(refreshBilling());
    }
    if (section == AppSection.settings) {
      unawaited(refreshAiCatalog());
    }
    notifyListeners();
  }

  Future<void> setDesktopCoworkMode(bool enabled) async {
    if (!_supportsDesktopShell || desktopCoworkMode == enabled) return;
    desktopCoworkMode = enabled;
    await _prefs?.setString(
      _desktopWorkspaceModePrefsKey,
      enabled ? 'cowork' : 'standard',
    );
    notifyListeners();
    if (enabled) await refreshCowork();
  }

  Future<void> refreshCowork({bool selectFirst = true}) async {
    if (!isAuthenticated || !_supportsDesktopShell || isLoadingCowork) return;
    isLoadingCowork = true;
    notifyListeners();
    try {
      final responses = await Future.wait(<Future<Map<String, dynamic>>>[
        _backendClient.fetchCoworkChats(backendUrl),
        _backendClient.fetchCoworkCapabilities(backendUrl),
      ]);
      coworkChats = _decodeModelList(
        'cowork_chats',
        responses[0]['chats'],
        (json) => CoworkChat.fromJson(Map<String, dynamic>.from(json)),
        fallbackToMapValues: true,
      );
      coworkDefaultDevice = CoworkDeviceSelection.fromJson(
        _jsonMap(responses[1]['device']),
      );
      if (selectFirst) {
        final selectedStillExists = coworkChats.any(
          (chat) => chat.id == selectedCoworkChatId,
        );
        if (!selectedStillExists) {
          selectedCoworkChatId = coworkChats.isEmpty
              ? null
              : coworkChats.first.id;
        }
      }
      final selectedId = selectedCoworkChatId;
      if (selectedId != null && !_coworkThreads.containsKey(selectedId)) {
        await _loadCoworkChat(selectedId);
      }
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isLoadingCowork = false;
      notifyListeners();
    }
  }

  Future<void> _loadCoworkChat(String conversationId) async {
    _coworkThreads[conversationId] = coworkThreadFor(
      conversationId,
    ).copyWith(loading: true);
    notifyListeners();
    try {
      final response = await _backendClient.fetchCoworkChat(
        backendUrl,
        conversationId,
      );
      final messages =
          _jsonMapList(response['messages'], fallbackToMapValues: true)
              .map((message) {
                return ChatEntry(
                  id: message['id']?.toString() ?? '',
                  role: message['role']?.toString() ?? 'assistant',
                  content: message['content']?.toString() ?? '',
                  platform: 'cowork',
                  runId: message['runId']?.toString(),
                  senderName: message['agentName']?.toString(),
                  metadata: _jsonMap(message['metadata']),
                  createdAt: _parseTimestamp(message['createdAt']?.toString()),
                );
              })
              .toList(growable: false);
      final inputRequests = _jsonMapList(
        response['inputRequests'],
        fallbackToMapValues: true,
      ).map(CoworkInputRequest.fromJson).toList(growable: false);
      final activity = <CoworkActivityItem>[];
      String? activeRunId;
      String? runStatus;
      DateTime? runStartedAt;
      final runs = _jsonMapList(response['activity'], fallbackToMapValues: true)
          .reversed;
      for (final run in runs) {
        final runId = run['id']?.toString() ?? '';
        final status = run['status']?.toString() ?? 'pending';
        if (activeRunId == null &&
            <String>{
              'pending',
              'running',
              'pausing',
              'paused',
              'resuming',
            }.contains(status)) {
          activeRunId = runId;
          runStatus = status;
          runStartedAt = _parseTimestamp(run['createdAt']?.toString());
        }
        for (final step in _jsonMapList(
          run['steps'],
          fallbackToMapValues: true,
        )) {
          final toolName = step['toolName']?.toString() ?? '';
          final result = step['result'];
          final startedAt = _parseTimestamp(step['startedAt']?.toString());
          final completedAt = step['completedAt']?.toString();
          activity.add(
            CoworkActivityItem(
              id: step['id']?.toString() ?? 'step-${step['index']}',
              runId: runId,
              kind: step['type']?.toString() ?? 'tool',
              label: toolName.isEmpty
                  ? (step['type']?.toString() ?? 'step')
                  : toolName,
              status: step['status']?.toString() ?? 'completed',
              summary:
                  step['error']?.toString() ?? _summarizeToolResult(result),
              createdAt: startedAt,
              durationMs: completedAt == null
                  ? null
                  : _parseTimestamp(completedAt)
                        .difference(startedAt)
                        .inMilliseconds,
              toolArgs: _jsonMap(step['toolInput']),
              detail: _coworkToolDetail(toolName, result),
              screenshotPath: result is Map
                  ? result['screenshotPath']?.toString()
                  : null,
            ),
          );
        }
      }
      _coworkThreads[conversationId] = CoworkThreadState(
        messages: messages,
        activity: activity,
        inputRequests: inputRequests,
        changes: _jsonMapList(response['changes'], fallbackToMapValues: true)
            .map(CoworkChangedFile.fromJson)
            .toList(growable: false),
        activeRunId: activeRunId,
        runStatus: runStatus,
        runStartedAt: runStartedAt,
      );
    } catch (error) {
      _coworkThreads[conversationId] = coworkThreadFor(
        conversationId,
      ).copyWith(loading: false);
      errorMessage = _friendlyErrorMessage(error);
    }
  }

  Future<void> _refreshCoworkConversation(String conversationId) async {
    await refreshCowork(selectFirst: false);
    if (coworkChats.any((chat) => chat.id == conversationId)) {
      await _loadCoworkChat(conversationId);
      notifyListeners();
    }
  }

  Future<void> selectCoworkChat(String conversationId) async {
    if (selectedCoworkChatId == conversationId) return;
    selectedCoworkChatId = conversationId;
    notifyListeners();
    if (!_coworkThreads.containsKey(conversationId)) {
      await _loadCoworkChat(conversationId);
      notifyListeners();
    }
  }

  /// Starts a session. When [template] is given the new chat inherits its
  /// agent, mode, device, workspace folder and model, so "New session" keeps
  /// working in the same project.
  Future<void> createCoworkChat({CoworkChat? template}) async {
    try {
      final response = await _backendClient.createCoworkChat(
        backendUrl,
        template == null
            ? <String, dynamic>{}
            : <String, dynamic>{
                'agentId': template.agentId,
                'mode': template.mode == CoworkInteractionMode.plan
                    ? 'plan'
                    : 'agent',
                'deviceTargetOverride': template.device.override,
                'workspacePathOverride': template.workspacePathOverride,
                'modelOverride': template.modelOverride,
              },
      );
      final chat = CoworkChat.fromJson(_jsonMap(response['chat']));
      coworkChats = <CoworkChat>[chat, ...coworkChats];
      selectedCoworkChatId = chat.id;
      _coworkThreads[chat.id] = const CoworkThreadState();
      notifyListeners();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<bool> updateCoworkChat(
    String conversationId,
    Map<String, dynamic> patch,
  ) async {
    try {
      final response = await _backendClient.updateCoworkChat(
        backendUrl,
        conversationId,
        patch,
      );
      final updated = CoworkChat.fromJson(_jsonMap(response['chat']));
      coworkChats = coworkChats
          .map((chat) => chat.id == updated.id ? updated : chat)
          .toList(growable: false);
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
      return false;
    }
  }

  Future<void> implementSelectedCoworkPlan() async {
    final chat = selectedCoworkChat;
    if (chat == null || chat.mode != CoworkInteractionMode.plan) return;
    final updated = await updateCoworkChat(chat.id, <String, dynamic>{
      'mode': 'agent',
    });
    if (!updated) return;
    if (selectedCoworkChatId == chat.id) {
      await sendCoworkMessage('Implement the plan above.');
    }
  }

  Future<void> deleteCoworkChat(String conversationId) async {
    try {
      await _backendClient.deleteCoworkChat(backendUrl, conversationId);
      coworkChats = coworkChats
          .where((chat) => chat.id != conversationId)
          .toList(growable: false);
      _coworkThreads.remove(conversationId);
      if (selectedCoworkChatId == conversationId) {
        selectedCoworkChatId = coworkChats.isEmpty
            ? null
            : coworkChats.first.id;
      }
      notifyListeners();
      final selectedId = selectedCoworkChatId;
      if (selectedId != null && !_coworkThreads.containsKey(selectedId)) {
        await _loadCoworkChat(selectedId);
      }
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  void setCoworkWorkSurfacePinned(bool pinned) {
    coworkWorkSurfacePinned = pinned;
    notifyListeners();
  }

  Future<void> refreshCoworkChanges(String conversationId) async {
    try {
      final response = await _backendClient.fetchCoworkChanges(
        backendUrl,
        conversationId,
      );
      _coworkThreads[conversationId] = coworkThreadFor(conversationId).copyWith(
        changes: _jsonMapList(response['changes'], fallbackToMapValues: true)
            .map(CoworkChangedFile.fromJson)
            .toList(growable: false),
      );
      notifyListeners();
    } catch (_) {
      // The list is rebuilt on the next full thread load.
    }
  }

  /// Lists a folder of the chat's workspace on the chat's device. Throws on
  /// failure so the workbench can show the error inline.
  Future<List<CoworkWorkspaceEntry>> browseCoworkWorkspace(
    CoworkChat chat,
    String path,
  ) async {
    final response = await _backendClient.fetchWorkspaceDirectory(
      backendUrl,
      path: path.isEmpty ? '.' : path,
      deviceTarget: chat.device.effective,
      workspaceRoot: chat.isLocal ? chat.workspacePathOverride : null,
    );
    final error = response['error']?.toString() ?? '';
    if (error.isNotEmpty) throw Exception(error);
    return _jsonMapList(response['entries'], fallbackToMapValues: true)
        .map(CoworkWorkspaceEntry.fromJson)
        .toList(growable: false);
  }

  Future<String> readCoworkWorkspaceFile(CoworkChat chat, String path) async {
    final response = await _backendClient.fetchWorkspaceFile(
      backendUrl,
      path: path,
      deviceTarget: chat.device.effective,
      workspaceRoot: chat.isLocal ? chat.workspacePathOverride : null,
    );
    final error = response['error']?.toString() ?? '';
    if (error.isNotEmpty) throw Exception(error);
    return response['content']?.toString() ?? '';
  }

  Future<void> sendCoworkMessage(
    String content, {
    List<SharedChatAttachment> sharedAttachments =
        const <SharedChatAttachment>[],
  }) async {
    final chat = selectedCoworkChat;
    if (chat == null) return;
    await _sendCoworkMessageToChat(
      chat,
      content,
      sharedAttachments: sharedAttachments,
    );
  }

  Future<void> _sendCoworkMessageToChat(
    CoworkChat chat,
    String content, {
    List<SharedChatAttachment> sharedAttachments =
        const <SharedChatAttachment>[],
  }) async {
    final trimmed = content.trim();
    final normalizedAttachments = sharedAttachments
        .where((item) => item.isValid)
        .toList(growable: false);
    final outgoingTask = _taskWithSharedAttachments(
      trimmed,
      normalizedAttachments,
    );
    if (outgoingTask.isEmpty || _socket == null) return;
    final current = coworkThreadFor(chat.id);
    _coworkThreads[chat.id] = current.copyWith(
      messages: <ChatEntry>[
        ...current.messages,
        ChatEntry(
          id: 'local-${DateTime.now().microsecondsSinceEpoch}',
          role: 'user',
          content: trimmed.isNotEmpty ? trimmed : 'Sent shared attachments.',
          platform: 'cowork',
          createdAt: DateTime.now(),
          transient: true,
          metadata: normalizedAttachments.isEmpty
              ? const <String, dynamic>{}
              : <String, dynamic>{
                  'sharedAttachments': normalizedAttachments
                      .map((item) => item.toJson())
                      .toList(growable: false),
                },
        ),
      ],
      sending: true,
      phase: current.hasLiveRun ? 'Steering' : 'Queued',
    );
    notifyListeners();
    _socket!.emit('agent:run', <String, dynamic>{
      'task': outgoingTask,
      'options': <String, dynamic>{
        'conversationId': chat.id,
        'coworkDisplayContent': trimmed.isNotEmpty
            ? trimmed
            : 'Sent shared attachments.',
        if (normalizedAttachments.isNotEmpty)
          'coworkSharedAttachments': normalizedAttachments
              .map((item) => item.toJson())
              .toList(growable: false),
      },
    });
  }

  Future<void> pauseCoworkRun() async {
    final runId = selectedCoworkThread.activeRunId;
    if (runId == null) return;
    try {
      await _backendClient.pauseAgentRun(backendUrl, runId);
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> resumeCoworkRun() async {
    final runId = selectedCoworkThread.activeRunId;
    if (runId == null) return;
    try {
      await _backendClient.resumeAgentRun(backendUrl, runId);
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> stopCoworkRun() async {
    final runId = selectedCoworkThread.activeRunId;
    if (runId == null) return;
    try {
      await _backendClient.abortAgentRun(backendUrl, runId);
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> answerCoworkInput(
    CoworkInputRequest request,
    Map<String, String> answers,
  ) async {
    final chat = selectedCoworkChat;
    if (chat == null) return;
    try {
      final response = await _backendClient.answerCoworkInput(
        backendUrl,
        conversationId: chat.id,
        requestId: request.id,
        answers: answers,
      );
      final prompt = _jsonMap(response['answer'])['prompt']?.toString() ?? '';
      await _loadCoworkChat(chat.id);
      notifyListeners();
      if (prompt.isNotEmpty) {
        await _sendCoworkMessageToChat(chat, prompt);
      }
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  String? _coworkConversationId(Map<String, dynamic> payload) {
    final direct = payload['conversationId']?.toString().trim() ?? '';
    if (direct.isNotEmpty && coworkChats.any((chat) => chat.id == direct)) {
      return direct;
    }
    final runId = payload['runId']?.toString().trim() ?? '';
    if (runId.isEmpty) return null;
    for (final entry in _coworkThreads.entries) {
      if (entry.value.activeRunId == runId ||
          entry.value.activity.any((item) => item.runId == runId) ||
          entry.value.messages.any((message) => message.runId == runId)) {
        return entry.key;
      }
    }
    return null;
  }

  void _updateCoworkRunEvent(String event, Map<String, dynamic> payload) {
    final conversationId = _coworkConversationId(payload);
    if (conversationId == null) return;
    final current = coworkThreadFor(conversationId);
    final runId = payload['runId']?.toString() ?? current.activeRunId ?? '';
    var next = current;

    switch (event) {
      case 'start':
        next = current.copyWith(
          activeRunId: runId,
          runStatus: 'running',
          runStartedAt: DateTime.now(),
          phase: 'Starting',
          sending: true,
          streamingContent: '',
        );
      case 'phase':
        final label = payload['label']?.toString().trim() ?? '';
        if (label.isNotEmpty) next = current.copyWith(phase: label);
      case 'thinking':
        next = current.copyWith(phase: 'Thinking');
      case 'analysis':
        next = current.copyWith(phase: 'Analyzing');
      case 'plan':
        next = current.copyWith(phase: 'Planning');
      case 'stopping':
        next = current.copyWith(phase: 'Stopping', runStatus: 'stopping');
      case 'pausing':
        next = current.copyWith(phase: 'Pausing', runStatus: 'pausing');
      case 'stream':
        next = current.copyWith(
          phase: 'Streaming',
          streamingContent: payload['content']?.toString() ?? '',
        );
      case 'tool_start':
        final toolName = payload['toolName']?.toString() ?? 'tool';
        final item = CoworkActivityItem(
          id:
              payload['stepId']?.toString().ifEmpty(
                'tool-${DateTime.now().microsecondsSinceEpoch}',
              ) ??
              'tool-${DateTime.now().microsecondsSinceEpoch}',
          runId: runId,
          kind: payload['type']?.toString() ?? 'tool',
          label: toolName,
          status: 'running',
          summary: _summarizeToolArgs(payload['toolArgs']),
          createdAt: DateTime.now(),
          toolArgs: _jsonMap(payload['toolArgs']),
        );
        next = current.copyWith(
          phase: 'Running $toolName',
          activity: <CoworkActivityItem>[
            ...current.activity.where((entry) => entry.id != item.id),
            item,
          ],
        );
      case 'tool_end':
        final stepId = payload['stepId']?.toString() ?? '';
        final toolName = payload['toolName']?.toString() ?? 'tool';
        final toolResult = _jsonMap(payload['result']);
        final itemId = stepId.isEmpty
            ? 'tool-${DateTime.now().microsecondsSinceEpoch}'
            : stepId;
        final started = current.activity
            .where((entry) => entry.id == itemId)
            .firstOrNull;
        final status = payload['status']?.toString() ?? 'completed';
        final summary =
            payload['error']?.toString() ??
            _summarizeToolResult(payload['result']);
        final detail = _coworkToolDetail(toolName, payload['result']);
        final screenshot = toolResult['screenshotPath']?.toString();
        final item = started == null
            ? CoworkActivityItem(
                id: itemId,
                runId: runId,
                kind: payload['type']?.toString() ?? 'tool',
                label: toolName,
                status: status,
                summary: summary,
                createdAt: DateTime.now(),
                detail: detail,
                screenshotPath: screenshot,
              )
            : started.copyWith(
                status: status,
                summary: summary,
                durationMs: DateTime.now()
                    .difference(started.createdAt)
                    .inMilliseconds,
                detail: detail,
                screenshotPath: screenshot,
              );
        next = current.copyWith(
          phase: 'Working',
          activity: <CoworkActivityItem>[
            ...current.activity.where((entry) => entry.id != item.id),
            item,
          ],
        );
        if (CoworkActivityItem.writeTools.contains(toolName)) {
          unawaited(refreshCoworkChanges(conversationId));
        }
        final selectedChat = selectedCoworkChatId == conversationId
            ? selectedCoworkChat
            : null;
        if (selectedChat != null) {
          final target = selectedChat.device.effective;
          final screenshotPath =
              payload['screenshotPath']?.toString() ??
              toolResult['screenshotPath']?.toString() ??
              toolResult['path']?.toString();
          if (toolName.startsWith('browser_') &&
              screenshotPath?.trim().isNotEmpty == true) {
            computerBrowserScreenshotPath = screenshotPath;
          }
          if (toolName == 'execute_command') {
            computerTerminalOutput =
                toolResult['stdout']?.toString() ??
                toolResult['output']?.toString() ??
                computerTerminalOutput;
          }
          if (_workspaceToolNames.contains(toolName)) {
            unawaited(refreshWorkspaceFiles(deviceTarget: target));
          }
          if (toolName.startsWith('browser_') ||
              toolName.startsWith('desktop_') ||
              toolName == 'execute_command' ||
              _workspaceToolNames.contains(toolName)) {
            unawaited(
              refreshComputerRuntime(silent: true, deviceTarget: target),
            );
          }
        }
      case 'verification' || 'subagent' || 'steer_queued' || 'steer_applied':
        final kind = event == 'verification'
            ? 'verification'
            : event == 'subagent'
            ? 'subagent'
            : 'steering';
        final status = event == 'verification'
            ? (payload['status']?.toString() == 'verified'
                  ? 'completed'
                  : 'failed')
            : payload['status']?.toString() == 'failed'
            ? 'failed'
            : payload['status']?.toString() == 'running'
            ? 'running'
            : 'completed';
        final summary = event == 'verification'
            ? (payload['notes']?.toString() ??
                  'Verification: ${payload['status']?.toString() ?? 'unknown'}')
            : event == 'subagent'
            ? (payload['task']?.toString() ??
                  payload['error']?.toString() ??
                  payload['result']?.toString() ??
                  'Subagent update')
            : event == 'steer_queued'
            ? 'Queued steering: ${payload['content']?.toString() ?? ''}'
            : 'Applied ${_asInt(payload['count'])} steering update(s).';
        final item = CoworkActivityItem(
          id: '$kind-${payload['handle']?.toString() ?? DateTime.now().microsecondsSinceEpoch}',
          runId: runId,
          kind: kind,
          label: kind == 'subagent'
              ? 'Subagent'
              : kind == 'steering'
              ? 'Steering'
              : 'Verification',
          status: status,
          summary: summary,
          createdAt: DateTime.now(),
        );
        next = current.copyWith(
          phase: event == 'verification'
              ? 'Verifying'
              : event == 'steer_applied'
              ? 'Incorporating steering'
              : current.phase,
          activity: <CoworkActivityItem>[...current.activity, item],
        );
      case 'interim':
        final content =
            payload['content']?.toString() ??
            payload['message']?.toString() ??
            '';
        if (content.trim().isNotEmpty) {
          next = current.copyWith(
            phase: 'Working',
            messages: <ChatEntry>[
              ...current.messages,
              ChatEntry(
                id: 'interim-${DateTime.now().microsecondsSinceEpoch}',
                role: 'assistant',
                content: content,
                platform: 'cowork',
                runId: runId,
                createdAt: DateTime.now(),
                transient: true,
                metadata: <String, dynamic>{
                  'interim': true,
                  'kind': payload['kind']?.toString() ?? 'progress',
                },
              ),
            ],
          );
        }
      case 'input_required':
        final request = CoworkInputRequest.fromJson(
          _jsonMap(payload['request']),
        );
        next = current.copyWith(
          phase: 'Waiting for input',
          runStatus: 'waiting_input',
          sending: false,
          inputRequests: <CoworkInputRequest>[
            ...current.inputRequests.where((entry) => entry.id != request.id),
            request,
          ],
        );
      case 'complete':
        final content = payload['content']?.toString().trim() ?? '';
        next = current.copyWith(
          messages: content.isEmpty
              ? current.messages
              : <ChatEntry>[
                  ...current.messages,
                  ChatEntry(
                    id: 'final-${DateTime.now().microsecondsSinceEpoch}',
                    role: 'assistant',
                    content: content,
                    platform: 'cowork',
                    runId: runId,
                    createdAt: DateTime.now(),
                    transient: true,
                  ),
                ],
          phase: 'Completed',
          runStatus: 'completed',
          sending: false,
          streamingContent: '',
          clearActiveRunId: true,
        );
        unawaited(_refreshCoworkConversation(conversationId));
      case 'paused':
        next = current.copyWith(phase: 'Paused', runStatus: 'paused');
      case 'resumed':
        next = current.copyWith(phase: 'Working', runStatus: 'running');
      case 'stopped':
        next = current.copyWith(
          phase: 'Stopped',
          runStatus: 'stopped',
          sending: false,
          streamingContent: '',
          clearActiveRunId: true,
        );
        unawaited(_refreshCoworkConversation(conversationId));
      case 'error':
        next = current.copyWith(
          phase: payload['error']?.toString() ?? 'Failed',
          runStatus: 'failed',
          sending: false,
          streamingContent: '',
          clearActiveRunId: true,
        );
        unawaited(_refreshCoworkConversation(conversationId));
    }
    _coworkThreads[conversationId] = next;
    notifyListeners();
  }

  Future<void> openRunDetails(String runId) async {
    final normalized = runId.trim();
    if (normalized.isEmpty) {
      return;
    }
    _requestedRunFocusId = normalized;
    setSelectedSection(AppSection.runs);
    await refreshRunsOnly();
  }

  void clearRequestedRunFocus(String runId) {
    if (_requestedRunFocusId == runId) {
      _requestedRunFocusId = null;
    }
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
      unawaited(_persistSelectedAgentId(selectedAgentId));
      return;
    }

    final restoredId = _prefs?.getString(_selectedAgentPrefsKey)?.trim() ?? '';
    if (restoredId.isNotEmpty &&
        agentProfiles.any((agent) => agent.id == restoredId)) {
      selectedAgentId = restoredId;
      return;
    }

    selectedAgentId = agentProfiles
        .firstWhere(
          (agent) => agent.isDefault,
          orElse: () => agentProfiles.first,
        )
        .id;
    unawaited(_persistSelectedAgentId(selectedAgentId));
  }

  Future<void> _persistSelectedAgentId(String? id) async {
    final normalized = id?.trim() ?? '';
    if (normalized.isEmpty) {
      await _prefs?.remove(_selectedAgentPrefsKey);
      return;
    }
    await _prefs?.setString(_selectedAgentPrefsKey, normalized);
  }

  Future<void> switchAgent(String id) async {
    if (selectedAgentId == id) {
      return;
    }
    selectedAgentId = id;
    unawaited(_persistSelectedAgentId(id));
    chatMessages = const <ChatEntry>[];
    _resetChatHistoryPagination();
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
        unawaited(_persistSelectedAgentId(created.id));
      } else {
        await _backendClient.updateAgentProfile(backendUrl, id, payload);
        selectedAgentId = id;
        unawaited(_persistSelectedAgentId(id));
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
        unawaited(_persistSelectedAgentId(null));
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
          directPolicy: policy.directPolicy == 'disabled'
              ? 'allowlist'
              : policy.directPolicy,
          sharedPolicy: policy.sharedPolicy == 'disabled'
              ? 'allowlist'
              : policy.sharedPolicy,
          sharedActorRules: _dedupeAccessRules(<MessagingAccessRule>[
            ...policy.sharedActorRules,
            suggestion.rule,
          ]),
        );
      case 'sharedMemberRules':
        return policy.copyWith(
          sharedPolicy: policy.sharedPolicy == 'disabled'
              ? 'allowlist'
              : policy.sharedPolicy,
          sharedMemberRules: _dedupeAccessRules(<MessagingAccessRule>[
            ...policy.sharedMemberRules,
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
    QuickAllowSuggestion suggestion, {
    String? chatId,
  }) async {
    try {
      final nextPolicy = _policyWithAddedRule(
        currentMessagingAccessPolicy(platform),
        suggestion,
      );
      await saveMessagingAccessPolicy(platform, nextPolicy);
      if (chatId != null) {
        _blockedSenderQueue.removeWhere(
          (notice) => notice.platform == platform && notice.chatId == chatId,
        );
      }
      errorMessage = null;
      notifyListeners();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> ignoreBlockedSender(BlockedSenderNotice notice) async {
    final key = '${notice.platform}:${notice.chatId ?? notice.sender ?? ''}';
    _ignoredChats.add(key);
    _blockedSenderQueue.removeWhere(
      (n) =>
          n.platform == notice.platform &&
          (n.chatId == notice.chatId || n.sender == notice.sender),
    );
    await _prefs?.setStringList(
      'messaging.ignored_chats',
      _ignoredChats.toList(),
    );
    notifyListeners();
  }

  Future<void> removeIgnoredChat(String key) async {
    _ignoredChats.remove(key);
    await _prefs?.setStringList(
      'messaging.ignored_chats',
      _ignoredChats.toList(),
    );
    notifyListeners();
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
    final ignoreKey =
        '${notice.platform}:${notice.chatId ?? notice.sender ?? ''}';
    if (_ignoredChats.contains(ignoreKey)) return;
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
      _syncOnboardingFromAccount();

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
        _backendClient.fetchChatHistory(
          backendUrl,
          agentId: agentId,
          limit: _chatHistoryPageSize,
        ),
        const <String, dynamic>{'messages': <dynamic>[], 'hasMore': false},
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
      final settingsMutationId = _settingsMutationId;
      final settingsWriteWasPending = _pendingSettingsWrites > 0;
      final settingsFuture = _softRefreshLoad<Map<String, dynamic>>(
        'settings',
        _backendClient.fetchSettings(backendUrl, agentId: agentId),
        Map<String, dynamic>.from(settings),
      );
      final behaviorFuture = _softRefreshLoad<Map<String, dynamic>>(
        'behavior_config',
        _backendClient.fetchBehaviorConfig(backendUrl, agentId: agentId),
        const <String, dynamic>{},
      );
      final runsFuture = _softRefreshLoad<Map<String, dynamic>>(
        'runs',
        _backendClient.fetchRuns(backendUrl, agentId: agentId),
        const <String, dynamic>{'runs': <dynamic>[]},
      );
      final timelineFuture = _softRefreshLoad<Map<String, dynamic>>(
        'timeline',
        _backendClient.fetchTimeline(
          backendUrl,
          sources: selectedTimelineSources,
          limit: 50,
        ),
        const <String, dynamic>{'items': <dynamic>[]},
      );
      final versionFuture = _softRefreshLoad<Map<String, dynamic>>(
        'version',
        _backendClient.fetchVersion(backendUrl),
        const <String, dynamic>{},
      );
      final setupStatusFuture = _softRefreshLoad<Map<String, dynamic>>(
        'setup_status',
        _backendClient.getSetupStatus(backendUrl),
        const <String, dynamic>{'complete': true},
      );
      final tokenFuture = _softRefreshLoad<Map<String, dynamic>>(
        'token_usage',
        _backendClient.fetchTokenUsageSummary(backendUrl, agentId: agentId),
        const <String, dynamic>{},
      );
      final rateLimitFuture = _softRefreshLoad<Map<String, dynamic>>(
        'rate_limits',
        _backendClient.fetchAccountUsage(backendUrl),
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
      final mcpFuture = _softRefreshLoad<List<Map<String, dynamic>>>(
        'mcp_servers',
        _backendClient.fetchMcpServers(backendUrl, agentId: agentId),
        const <Map<String, dynamic>>[],
      );
      unawaited(checkBillingEnabled());
      final computerFuture = _backendClient
          .fetchComputerStatus(backendUrl)
          .catchError((_) => const <String, dynamic>{});
      final socialReachFuture = _backendClient
          .fetchSocialReachStatus(backendUrl)
          .catchError((_) => const <String, dynamic>{});
      final androidFuture = _backendClient
          .fetchAndroidStatus(backendUrl)
          .catchError((_) => const <String, dynamic>{});
      final teachFuture = _backendClient
          .fetchTeachStatus(backendUrl)
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
      final behaviorResponse = await behaviorFuture;
      final runsResponse = await runsFuture;
      final timelineResponse = await timelineFuture;
      final versionResponse = await versionFuture;
      final setupStatusResponse = await setupStatusFuture;
      final tokenResponse = await tokenFuture;
      final rateLimitResponse = await rateLimitFuture;
      final updateResponse = await updateFuture;
      final messagingResponse = await messagingFuture;
      final messagingMessagesResponse = await messagingMessagesFuture;
      final skillsResponse = await skillsFuture;
      final storeSkillsResponse = await storeSkillsFuture;
      final memoryResponse = await memoryFuture;
      final memoriesResponse = await memoriesFuture;
      final conversationsResponse = await conversationsFuture;
      final tasksResponse = await tasksFuture;
      final mcpResponse = await mcpFuture;
      final computerResponse = await computerFuture;
      final socialReachResponse = await socialReachFuture;
      final androidResponse = await androidFuture;
      final teachResponse = await teachFuture;
      if (!_isCurrentAuthCycle(authCycle)) {
        return;
      }

      chatMessages = _chatHistoryEntriesFromResponse(history);
      _applyChatHistoryCursor(history);

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

      if (!settingsWriteWasPending &&
          settingsMutationId == _settingsMutationId &&
          agentId == _scopedAgentId) {
        settings = Map<String, dynamic>.from(settingsResponse);
      }
      behaviorConfig = behaviorResponse['config'] is Map
          ? Map<String, dynamic>.from(behaviorResponse['config'] as Map)
          : const <String, dynamic>{};
      recentRuns = _decodeModelList(
        'runs',
        runsResponse['runs'],
        RunSummary.fromJson,
        fallbackToMapValues: true,
      );
      timelineItems = _decodeModelList(
        'timeline',
        timelineResponse['items'],
        TimelineEventItem.fromJson,
        fallbackToMapValues: true,
      );
      versionInfo = versionResponse;
      setupProfile = setupStatusResponse['profile']?.toString() == 'full'
          ? 'full'
          : 'quick';
      setupComplete = setupStatusResponse['complete'] != false;
      setupOpenSections =
          (setupStatusResponse['openSections'] as List? ?? const [])
              .map((section) => section.toString())
              .where((section) => section.isNotEmpty)
              .toList(growable: false);
      backendHealthStatus = healthResponse;
      tokenUsage = TokenUsageSnapshot.fromJson(tokenResponse);
      usageAndLimits = AccountUsageAndLimits.fromJson(rateLimitResponse);
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
      mcpServers = _decodeModelList(
        'mcp_servers',
        mcpResponse,
        McpServerItem.fromJson,
      );
      computerRuntime = Map<String, dynamic>.from(computerResponse);
      teachRuntime = Map<String, dynamic>.from(teachResponse);
      socialReachStatus = Map<String, dynamic>.from(socialReachResponse);
      androidRuntime = Map<String, dynamic>.from(androidResponse);
      deviceHealthStatus = await _healthBridge.getStatus();
      if (!_isCurrentAuthCycle(authCycle)) {
        return;
      }
      await _syncBackgroundHealthConfig();
      if (!_isCurrentAuthCycle(authCycle)) {
        return;
      }
      await _syncDesktopCompanionSession();
      if (!_isCurrentAuthCycle(authCycle)) return;
      unawaited(ensureLocalDeviceConnected());
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
  }

  Future<void> refreshTimeline({
    Set<String>? sources,
    bool notify = true,
  }) async {
    if (!isAuthenticated) {
      return;
    }
    if (sources != null) {
      selectedTimelineSources = sources
          .map((value) => value.trim().toLowerCase())
          .where((value) => value.isNotEmpty)
          .toSet();
    }
    isRefreshingTimeline = true;
    if (notify) {
      notifyListeners();
    }
    try {
      final response = await _backendClient.fetchTimeline(
        backendUrl,
        sources: selectedTimelineSources,
        limit: 50,
      );
      timelineItems = _decodeModelList(
        'timeline',
        response['items'],
        TimelineEventItem.fromJson,
        fallbackToMapValues: true,
      );
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isRefreshingTimeline = false;
      if (notify) {
        notifyListeners();
      }
    }
  }

  Future<void> toggleTimelineSource(String sourceKind) async {
    final normalized = sourceKind.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    final next = <String>{...selectedTimelineSources};
    if (next.contains(normalized)) {
      if (next.length == 1) {
        return;
      }
      next.remove(normalized);
    } else {
      next.add(normalized);
    }
    await refreshTimeline(sources: next);
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

  Future<List<TaskDeliveryTarget>> fetchTaskDeliveryTargets({
    String? query,
    String? platform,
    String? agentId,
  }) async {
    final rows = await _backendClient.fetchTaskDeliveryTargets(
      backendUrl,
      query: query,
      platform: platform,
      agentId: agentId ?? _scopedAgentId,
    );
    return rows
        .map(TaskDeliveryTarget.fromJson)
        .where((target) => target.platform.isNotEmpty && target.to.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> refreshMcp() async {
    mcpServers = _decodeModelList(
      'mcp_servers',
      await _backendClient.fetchMcpServers(backendUrl, agentId: _scopedAgentId),
      McpServerItem.fromJson,
    );
    notifyListeners();
  }

  Future<void> refreshDevices({String? deviceTarget}) async {
    if (!isAuthenticated || isRefreshingDevices) {
      return;
    }
    isRefreshingDevices = true;
    notifyListeners();
    try {
      // Each surface is refreshed independently: a computer runtime that fails
      // to report must not wipe the Android or Teach state along with it.
      Object? failure;
      Future<void> refresh(
        Future<Map<String, dynamic>> Function() fetch,
        void Function(Map<String, dynamic>) apply,
      ) async {
        try {
          apply(Map<String, dynamic>.from(await fetch()));
        } catch (error) {
          failure ??= error;
        }
      }

      await Future.wait(<Future<void>>[
        refresh(
          () => _backendClient.fetchComputerStatus(
            backendUrl,
            deviceTarget: deviceTarget,
          ),
          (value) => computerRuntime = value,
        ),
        refresh(
          () => _backendClient.fetchAndroidStatus(backendUrl),
          (value) => androidRuntime = value,
        ),
        refresh(
          () => _backendClient.fetchTeachStatus(backendUrl),
          (value) => teachRuntime = value,
        ),
      ]);
      if (_desktopCompanion.enabled) {
        await _desktopCompanion.refreshLocalStatus();
      }
      if (failure != null) errorMessage = _friendlyErrorMessage(failure!);
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isRefreshingDevices = false;
      notifyListeners();
    }
  }

  Future<void> selectComputerProvider(String provider) async {
    final normalized = provider.trim().toLowerCase();
    if (normalized == computerProvider || isRunningDeviceAction) return;
    if (normalized == 'local' && !_desktopCompanion.supported) {
      errorMessage =
          'Local computer control is available in the NeoAgent desktop app on macOS, Windows and Linux.';
      notifyListeners();
      return;
    }
    isRunningDeviceAction = true;
    errorMessage = null;
    notifyListeners();
    try {
      if (normalized == 'local' && _desktopCompanion.supported) {
        await _desktopCompanion.setEnabled(true, _prefs!);
        await _syncDesktopCompanionSession();
        await _desktopCompanion.refreshLocalStatus();
      }
      computerRuntime = Map<String, dynamic>.from(
        await _backendClient.setComputerProvider(backendUrl, normalized),
      );
      computerDisplayUrl = null;
      workspaceCurrentPath = '';
      workspaceEntries = const <Map<String, dynamic>>[];
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isRunningDeviceAction = false;
      notifyListeners();
    }
  }

  Future<void> grantLocalComputerPermission(
    String capability, {
    required bool remember,
  }) async {
    if (_prefs == null) return;
    await _desktopCompanion.grantPermission(
      capability,
      _prefs!,
      remember: remember,
    );
    await refreshComputerRuntime(silent: true);
    notifyListeners();
  }

  Future<void> denyLocalComputerPermission(String capability) async {
    await _desktopCompanion.denyPermission(capability);
    await refreshComputerRuntime(silent: true);
    notifyListeners();
  }

  Future<void> revokeLocalComputerPermission(String capability) async {
    if (_prefs == null) return;
    await _desktopCompanion.revokePermission(capability, _prefs!);
    await refreshComputerRuntime(silent: true);
    notifyListeners();
  }

  Future<void> openLocalComputerSystemPermission(String capability) async {
    final key = capability == 'screen' ? 'screencapture' : 'inputcontrol';
    try {
      await _desktopCompanion.openPermissionSettings(key);
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> startComputerRuntime({String? deviceTarget}) async {
    if (isRunningDeviceAction) return;
    isRunningDeviceAction = true;
    errorMessage = null;
    notifyListeners();
    try {
      computerRuntime = Map<String, dynamic>.from(
        await _backendClient.startComputer(
          backendUrl,
          deviceTarget: deviceTarget,
        ),
      );
      if ((deviceTarget ?? computerProvider) == 'cloud') {
        await _backendClient.acquireComputerControl(
          backendUrl,
          deviceTarget: deviceTarget,
        );
        final display = await _backendClient.createComputerDisplaySession(
          backendUrl,
          deviceTarget: deviceTarget,
        );
        final viewPath = display['viewUrl']?.toString().trim() ?? '';
        if (viewPath.isNotEmpty) {
          computerDisplayUrl = Uri.parse(
            _socketOrigin(),
          ).resolve(viewPath).toString();
        }
      }
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      await refreshComputerRuntime(silent: true, deviceTarget: deviceTarget);
    } finally {
      isRunningDeviceAction = false;
      notifyListeners();
    }
  }

  Future<void> refreshComputerRuntime({
    bool silent = false,
    String? deviceTarget,
  }) async {
    try {
      computerRuntime = Map<String, dynamic>.from(
        await _backendClient.fetchComputerStatus(
          backendUrl,
          deviceTarget: deviceTarget,
        ),
      );
      teachRuntime = Map<String, dynamic>.from(
        await _backendClient.fetchTeachStatus(backendUrl),
      );
      if (!silent) notifyListeners();
    } catch (error) {
      if (!silent) {
        errorMessage = _friendlyErrorMessage(error);
        notifyListeners();
      }
    }
  }

  Future<void> openComputerDisplayRuntime({String? deviceTarget}) async {
    await _connectComputerDisplayRuntime(
      deviceTarget: deviceTarget,
      interruptAgent: false,
    );
  }

  Future<void> interruptComputerAgentRuntime({String? deviceTarget}) async {
    await _connectComputerDisplayRuntime(
      deviceTarget: deviceTarget,
      interruptAgent: true,
    );
  }

  Future<void> _connectComputerDisplayRuntime({
    String? deviceTarget,
    required bool interruptAgent,
  }) async {
    if (isRunningDeviceAction) return;
    isRunningDeviceAction = true;
    errorMessage = null;
    notifyListeners();
    try {
      final provider = deviceTarget ?? computerProvider;
      if (interruptAgent) {
        await _backendClient.acquireComputerControl(
          backendUrl,
          deviceTarget: deviceTarget,
        );
      }
      if (provider == 'local') {
        await refreshComputerRuntime(silent: true, deviceTarget: deviceTarget);
        return;
      }
      final display = await _backendClient.createComputerDisplaySession(
        backendUrl,
        deviceTarget: deviceTarget,
      );
      computerRuntime = Map<String, dynamic>.from(
        await _backendClient.fetchComputerStatus(
          backendUrl,
          deviceTarget: deviceTarget,
        ),
      );
      final viewPath = display['viewUrl']?.toString().trim() ?? '';
      computerDisplayUrl = viewPath.isEmpty
          ? null
          : Uri.parse(_socketOrigin()).resolve(viewPath).toString();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isRunningDeviceAction = false;
      notifyListeners();
    }
  }

  Future<void> stopComputerRuntime({String? deviceTarget}) async {
    if (isRunningDeviceAction) return;
    isRunningDeviceAction = true;
    errorMessage = null;
    notifyListeners();
    try {
      computerRuntime = Map<String, dynamic>.from(
        await _backendClient.stopComputer(
          backendUrl,
          deviceTarget: deviceTarget,
        ),
      );
      computerDisplayUrl = null;
      teachRuntime = const <String, dynamic>{'status': 'idle'};
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isRunningDeviceAction = false;
      notifyListeners();
    }
  }

  Future<void> startTeachRuntime(String goal) async {
    final normalizedGoal = goal.trim();
    if (normalizedGoal.isEmpty || isRunningDeviceAction) return;
    isRunningDeviceAction = true;
    errorMessage = null;
    notifyListeners();
    try {
      teachRuntime = Map<String, dynamic>.from(
        await _backendClient.startTeach(
          backendUrl,
          goal: normalizedGoal,
          agentId: _scopedAgentId,
        ),
      );
      final display = await _backendClient.createComputerDisplaySession(
        backendUrl,
      );
      final viewPath = display['viewUrl']?.toString().trim() ?? '';
      computerDisplayUrl = viewPath.isEmpty
          ? null
          : Uri.parse(_socketOrigin()).resolve(viewPath).toString();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isRunningDeviceAction = false;
      notifyListeners();
    }
  }

  Future<void> stopTeachRuntime() async {
    final id = teachRuntime['id']?.toString().trim() ?? '';
    if (id.isEmpty || isRunningDeviceAction) return;
    isRunningDeviceAction = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await _backendClient.stopTeach(backendUrl, sessionId: id);
      teachRuntime = <String, dynamic>{'status': 'completed', ...result};
      await refreshSkills();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      await refreshComputerRuntime(silent: true);
    } finally {
      isRunningDeviceAction = false;
      notifyListeners();
    }
  }

  Future<void> cancelTeachRuntime() async {
    final id = teachRuntime['id']?.toString().trim() ?? '';
    if (id.isEmpty || isRunningDeviceAction) return;
    isRunningDeviceAction = true;
    notifyListeners();
    try {
      await _backendClient.cancelTeach(backendUrl, sessionId: id);
      teachRuntime = const <String, dynamic>{'status': 'idle'};
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isRunningDeviceAction = false;
      notifyListeners();
    }
  }

  Future<void> launchComputerAppRuntime(
    String app, {
    String? deviceTarget,
  }) async {
    if (isRunningDeviceAction) return;
    isRunningDeviceAction = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _withLocalUserControl(
        () => _backendClient.launchComputerApp(
          backendUrl,
          app: app,
          deviceTarget: deviceTarget,
        ),
        deviceTarget: deviceTarget,
      );
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isRunningDeviceAction = false;
      notifyListeners();
    }
  }

  Future<void> executeComputerCommandRuntime(
    String command, {
    String? deviceTarget,
  }) async {
    final normalized = command.trim();
    if (normalized.isEmpty || isRunningDeviceAction) return;
    isRunningDeviceAction = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await _withLocalUserControl(
        () => _backendClient.executeComputerCommand(
          backendUrl,
          command: normalized,
          cwd: '/home/neo/workspace',
          deviceTarget: deviceTarget,
        ),
        deviceTarget: deviceTarget,
      );
      final stdout = result['stdout']?.toString() ?? '';
      final stderr = result['stderr']?.toString() ?? '';
      final exitCode = result['exitCode'];
      computerTerminalOutput = <String>[
        '\$ $normalized',
        if (stdout.isNotEmpty) stdout.trimRight(),
        if (stderr.isNotEmpty) stderr.trimRight(),
        if (exitCode != null) '[exit $exitCode]',
      ].join('\n');
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isRunningDeviceAction = false;
      notifyListeners();
    }
  }

  Future<void> refreshComputerBrowser({String? deviceTarget}) async {
    if (isRunningDeviceAction) return;
    isRunningDeviceAction = true;
    errorMessage = null;
    notifyListeners();
    try {
      computerBrowserRuntime = Map<String, dynamic>.from(
        await _backendClient.fetchComputerBrowserStatus(
          backendUrl,
          deviceTarget: deviceTarget,
        ),
      );
      final screenshot = await _backendClient.screenshotComputerBrowser(
        backendUrl,
        deviceTarget: deviceTarget,
      );
      computerBrowserScreenshotPath =
          screenshot['screenshotPath']?.toString() ??
          screenshot['path']?.toString();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isRunningDeviceAction = false;
      notifyListeners();
    }
  }

  Future<void> navigateComputerBrowser(
    String url, {
    String? deviceTarget,
  }) async {
    final normalized = url.trim();
    if (normalized.isEmpty || isRunningDeviceAction) return;
    isRunningDeviceAction = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await _withLocalUserControl(
        () => _backendClient.navigateComputerBrowser(
          backendUrl,
          url: normalized,
          deviceTarget: deviceTarget,
        ),
        deviceTarget: deviceTarget,
      );
      computerBrowserRuntime = Map<String, dynamic>.from(result);
      computerBrowserScreenshotPath =
          result['screenshotPath']?.toString() ?? result['path']?.toString();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isRunningDeviceAction = false;
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

  /// Android-only status poll. Kept separate from [refreshDevices] so a failing
  /// computer runtime cannot blank out the Android panel, and so the boot
  /// progress can be polled cheaply while the emulator comes up.
  Future<void> refreshAndroidRuntime() async {
    if (!isAuthenticated) return;
    try {
      androidRuntime = Map<String, dynamic>.from(
        await _backendClient.fetchAndroidStatus(backendUrl),
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<void> startAndroidRuntime() async {
    await _runDeviceAction(
      () => _backendClient.startAndroidEmulator(backendUrl),
      refreshAppsAfter: false,
    );
  }

  Future<void> stopAndroidRuntime() async {
    await _runDeviceAction(
      () => _backendClient.stopAndroidEmulator(backendUrl),
    );
  }

  Future<void> screenshotAndroidRuntime() async {
    await _runDeviceAction(
      () => _backendClient.screenshotAndroid(backendUrl),
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
      refreshDevicesAfter: false,
    );
  }

  /// Touch input on the live Android surface.
  ///
  /// Deliberately outside [_runDeviceAction]: that flag disables the whole
  /// Devices panel for the duration, which makes rapid taps flicker and drops
  /// every gesture that lands while another one is still in flight.
  Future<void> _runAndroidInput(
    Future<Map<String, dynamic>> Function() action,
  ) async {
    try {
      final result = await action();
      final screenshot = result['screenshotPath']?.toString();
      if (screenshot != null && screenshot.isNotEmpty) {
        androidScreenshotPath = screenshot;
        notifyListeners();
      } else {
        // Key presses answer without a frame; pull one so the surface follows.
        await refreshAndroidFrameRuntime();
      }
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> tapAndroidRuntime(Map<String, dynamic> payload) async {
    await _runAndroidInput(
      () => _backendClient.tapAndroid(backendUrl, <String, dynamic>{
        ...payload,
        'uiDump': false,
        'includeNodes': false,
      }),
    );
  }

  Future<void> typeAndroidRuntime(Map<String, dynamic> payload) async {
    await _runDeviceAction(
      () => _backendClient.typeAndroid(backendUrl, <String, dynamic>{
        ...payload,
        'uiDump': false,
        'includeNodes': false,
      }),
      refreshDevicesAfter: false,
    );
  }

  Future<void> swipeAndroidRuntime(Map<String, dynamic> payload) async {
    await _runAndroidInput(
      () => _backendClient.swipeAndroid(backendUrl, <String, dynamic>{
        ...payload,
        'uiDump': false,
        'includeNodes': false,
      }),
    );
  }

  Future<void> pressAndroidKeyRuntime(String key) async {
    await _runAndroidInput(
      () => _backendClient.pressAndroidKey(
        backendUrl,
        key: key,
        uiDump: false,
        includeNodes: false,
      ),
    );
  }

  Future<void> waitForAndroidRuntime(Map<String, dynamic> payload) async {
    await _runDeviceAction(
      () => _backendClient.waitForAndroid(backendUrl, payload),
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
      refreshAppsAfter: true,
    );
  }

  String workspaceDownloadUrl(String path, {String? deviceTarget}) {
    return '${_socketOrigin()}/${_backendClient.workspaceDownloadPath(path, deviceTarget: deviceTarget).replaceFirst(RegExp(r'^/'), '')}';
  }

  Future<void> refreshWorkspaceFiles({
    String? path,
    String? deviceTarget,
  }) async {
    if (!isAuthenticated || isLoadingWorkspaceFiles) {
      return;
    }
    isLoadingWorkspaceFiles = true;
    errorMessage = null;
    notifyListeners();
    try {
      final response = await _backendClient.fetchWorkspaceDirectory(
        backendUrl,
        path: path ?? workspaceCurrentPath,
        deviceTarget: deviceTarget,
      );
      workspaceCurrentPath = response['path']?.toString() ?? '';
      workspaceEntries = _jsonMapList(
        response['entries'],
        fallbackToMapValues: true,
      );
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isLoadingWorkspaceFiles = false;
      notifyListeners();
    }
  }

  Future<void> openWorkspaceDirectory(
    String path, {
    String? deviceTarget,
  }) async {
    workspaceSelectedFilePath = null;
    workspaceEditorContent = '';
    await refreshWorkspaceFiles(path: path, deviceTarget: deviceTarget);
  }

  Future<void> openWorkspaceFile(String path, {String? deviceTarget}) async {
    if (isLoadingWorkspaceFiles) {
      return;
    }
    isLoadingWorkspaceFiles = true;
    errorMessage = null;
    notifyListeners();
    try {
      final response = await _backendClient.fetchWorkspaceFile(
        backendUrl,
        path: path,
        deviceTarget: deviceTarget,
      );
      workspaceSelectedFilePath = response['path']?.toString() ?? path;
      workspaceEditorContent = response['content']?.toString() ?? '';
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isLoadingWorkspaceFiles = false;
      notifyListeners();
    }
  }

  Future<void> saveWorkspaceFile(String content, {String? deviceTarget}) async {
    final path = workspaceSelectedFilePath?.trim() ?? '';
    if (path.isEmpty || isSavingWorkspaceFile) {
      return;
    }
    isSavingWorkspaceFile = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _withLocalUserControl(
        () => _backendClient.saveWorkspaceFile(
          backendUrl,
          path: path,
          content: content,
          deviceTarget: deviceTarget,
        ),
        deviceTarget: deviceTarget,
      );
      workspaceEditorContent = content;
      await refreshWorkspaceFiles(
        path: workspaceCurrentPath,
        deviceTarget: deviceTarget,
      );
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isSavingWorkspaceFile = false;
      notifyListeners();
    }
  }

  Future<T> _withLocalUserControl<T>(
    Future<T> Function() action, {
    String? deviceTarget,
  }) async {
    if ((deviceTarget ?? computerProvider) != 'local') return action();
    await _backendClient.acquireComputerControl(
      backendUrl,
      deviceTarget: deviceTarget ?? 'local',
    );
    try {
      return await action();
    } finally {
      try {
        await _backendClient.releaseComputerControl(
          backendUrl,
          deviceTarget: deviceTarget ?? 'local',
        );
      } catch (_) {}
    }
  }

  Future<void> downloadWorkspaceFile(
    String path, {
    String? deviceTarget,
  }) async {
    final normalized = path.trim();
    if (normalized.isEmpty) {
      return;
    }
    final result = await _oauthLauncher.openExternal(
      url: workspaceDownloadUrl(normalized, deviceTarget: deviceTarget),
      label: 'neoagent_workspace_file_download',
    );
    if (!result.launched) {
      errorMessage = result.error ?? 'Could not open workspace file download.';
      notifyListeners();
    }
  }

  Uri resolveRuntimeAsset(String path) {
    final separator = path.contains('?') ? '&' : '?';
    return _backendClient.resolveAssetUri(
      backendUrl,
      '$path${separator}t=${DateTime.now().millisecondsSinceEpoch}',
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

  Future<void> setDesktopAssistantHotkeyEnabled(bool value) async {
    _desktopAssistantHotkeyEnabled = value;
    await _prefs?.setBool('desktop.assistantHotkeyEnabled', value);
    notifyListeners();
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
    if (voiceAssistantLiveState.hasActiveSession &&
        voiceAssistantLiveState.transportState == 'connected') {
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
      if (voiceAssistantLiveState.sessionId.trim().isNotEmpty)
        'sessionId': voiceAssistantLiveState.sessionId.trim(),
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

  void acceptIncomingAgentCall() {
    final call = incomingAgentCall;
    if (call == null || call.accepting || _socket == null) return;
    incomingAgentCall = call.copyWith(accepting: true);
    unawaited(
      _AppNotificationService.cancelIncomingCallNotification(call.callId),
    );
    _socket!.emit('voice:call_accept', <String, dynamic>{
      'callId': call.callId,
    });
    notifyListeners();
  }

  void declineIncomingAgentCall() {
    final call = incomingAgentCall;
    if (call == null) return;
    _socket?.emit('voice:call_decline', <String, dynamic>{
      'callId': call.callId,
    });
    _clearIncomingAgentCall(call.callId);
    notifyListeners();
  }

  void _clearIncomingAgentCall([String? callId]) {
    final current = incomingAgentCall;
    if (current == null || (callId != null && current.callId != callId)) return;
    _incomingCallExpiryTimer?.cancel();
    _incomingCallExpiryTimer = null;
    incomingAgentCall = null;
    cancelIncomingCallBrowserAlert(current.callId);
    unawaited(
      _AppNotificationService.cancelIncomingCallNotification(current.callId),
    );
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
    socket.emit('voice:input_start', <String, dynamic>{
      'sessionId': sessionId,
      'turnId': turnId,
      'mimeType':
          'audio/pcm;rate=${voiceAssistantLiveState.inputSampleRate};channels=1',
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
        'mimeType':
            'audio/pcm;rate=${voiceAssistantLiveState.inputSampleRate};channels=1',
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
        clearAudio: true,
        clearError: true,
      );
      notifyListeners();
      _sendLiveVoiceInputStart(sessionId: sessionId, turnId: turnId);
      await _liveVoiceCapture.start(
        sampleRate: voiceAssistantLiveState.inputSampleRate,
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
      _liveVoicePendingCommitPayload = <String, dynamic>{};
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

  Future<void> stopLiveVoicePlayback() async {
    final sessionId = voiceAssistantLiveState.sessionId.trim();
    if (sessionId.isEmpty || _socket == null) return;
    _socket!.emit('voice:interrupt', <String, dynamic>{'sessionId': sessionId});
    voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
      state: voiceAssistantLiveState.activeRunId.trim().isNotEmpty
          ? 'working'
          : 'idle',
      clearAudio: true,
    );
    notifyListeners();
  }

  Future<void> cancelLiveVoiceTask() async {
    final sessionId = voiceAssistantLiveState.sessionId.trim();
    if (sessionId.isEmpty || _socket == null) return;
    _socket!.emit('voice:cancel_task', <String, dynamic>{
      'sessionId': sessionId,
    });
  }

  Future<void> closeLiveVoiceSession({bool cancelTask = false}) async {
    final sessionId = voiceAssistantLiveState.sessionId.trim();
    if (sessionId.isEmpty || _socket == null) {
      return;
    }
    _socket!.emit('voice:session_close', <String, dynamic>{
      'sessionId': sessionId,
      'cancelTask': cancelTask,
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

  void _upsertVoiceTimelineItem({
    required Map<String, dynamic> payload,
    required String role,
    required String kind,
    required String content,
    required bool isFinal,
  }) {
    final sessionId = payload['sessionId']?.toString().trim().isNotEmpty == true
        ? payload['sessionId'].toString()
        : voiceAssistantLiveState.sessionId;
    final turnId = payload['turnId']?.toString().trim().isNotEmpty == true
        ? payload['turnId'].toString()
        : (_liveVoiceTurnId ?? '');
    final runId = payload['runId']?.toString() ?? '';
    final messageId =
        payload['messageId']?.toString() ??
        payload['outboxId']?.toString() ??
        '';
    final id = role == 'user' && turnId.isNotEmpty
        ? '$sessionId:$turnId:user'
        : messageId.isNotEmpty
        ? messageId
        : '$sessionId:$turnId:$role:$kind:${content.hashCode}';
    final timeline = voiceAssistantLiveState.timeline.toList(growable: true);
    final index = timeline.indexWhere((item) => item.id == id);
    if (index >= 0) {
      timeline[index] = timeline[index].copyWith(
        runId: runId,
        messageId: messageId,
        kind: kind,
        content: content,
        isFinal: isFinal,
      );
    } else {
      timeline.add(
        VoiceTimelineItem(
          id: id,
          sessionId: sessionId,
          turnId: turnId,
          runId: runId,
          messageId: messageId,
          role: role,
          kind: kind,
          content: content,
          isFinal: isFinal,
          createdAt: DateTime.now(),
        ),
      );
    }
    voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
      timeline: timeline.length > 100
          ? timeline.sublist(timeline.length - 100)
          : timeline,
      activeRunId: runId.isNotEmpty
          ? runId
          : voiceAssistantLiveState.activeRunId,
    );
  }

  void _appendAssistantChatMessage(
    String content, {
    required String platform,
    bool transient = false,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) {
    _appendChatMessage(
      content,
      role: 'assistant',
      platform: platform,
      transient: transient,
      metadata: metadata,
    );
  }

  void _appendUserChatMessage(String content, {required String platform}) {
    _appendChatMessage(content, role: 'user', platform: platform);
  }

  List<ToolEventItem> _capToolEvents(List<ToolEventItem> events) {
    if (events.length <= _maxToolEvents) return events;
    return events.sublist(events.length - _maxToolEvents);
  }

  void _appendToolNote(String summary, {String toolName = 'note'}) {
    final trimmed = summary.trim();
    if (trimmed.isEmpty) {
      return;
    }
    toolEvents = _capToolEvents(<ToolEventItem>[
      ...toolEvents,
      ToolEventItem(
        id: 'note-${DateTime.now().microsecondsSinceEpoch}',
        toolName: toolName,
        type: 'note',
        status: 'completed',
        summary: trimmed,
      ),
    ]);
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

  Future<String> transcribeDictationAudio({
    required String audioBase64,
    String mimeType = 'audio/pcm;rate=16000;channels=1',
  }) async {
    final result = await _backendClient.transcribeAudio(
      backendUrl,
      audioBase64: audioBase64,
      mimeType: mimeType,
    );
    return result['transcript']?.toString() ?? '';
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
      await refreshRateLimitUsage();
    } catch (error) {
      final friendlyError = _friendlyErrorMessage(error);
      chatMessages = <ChatEntry>[
        ...chatMessages,
        ChatEntry(
          id: '',
          role: 'assistant',
          content: friendlyError,
          platform: 'flutter',
          createdAt: DateTime.now(),
        ),
      ];
      activeRun = null;
      errorMessage = friendlyError;
      if (error is BackendException && error.statusCode == 429) {
        await refreshRateLimitUsage();
      }
    } finally {
      if (_socket == null || !socketConnected) {
        isSendingMessage = false;
        notifyListeners();
      }
    }
  }

  Future<void> saveSettings({
    required bool smarterSelector,
    required List<String> enabledModels,
    required String defaultChatModel,
    required String defaultSubagentModel,
    required String defaultSpeechModel,
    required String voiceSttProvider,
    required String voiceSttModel,
    required String voiceTtsProvider,
    required String voiceTtsModel,
    required String voiceTtsVoice,
    required String voiceMediaMode,
    required String voiceInputMode,
    required Map<String, dynamic> aiProviderConfigs,
  }) async {
    _beginSettingsSave();

    final payload = <String, dynamic>{
      'headless_browser': true,
      'runtime_profile': 'cloud-computer',
      'runtime_backend': 'qemu',
      'smarter_model_selector': smarterSelector,
      'enabled_models': enabledModels,
      'default_chat_model': defaultChatModel,
      'default_subagent_model': defaultSubagentModel,
      'default_speech_model': defaultSpeechModel,
      'voice_stt_provider': voiceSttProvider,
      'voice_stt_model': voiceSttModel,
      'voice_tts_provider': voiceTtsProvider,
      'voice_tts_model': voiceTtsModel,
      'voice_tts_voice': voiceTtsVoice,
      'voice_media_mode': voiceMediaMode,
      'voice_input_mode': voiceInputMode,
      'ai_provider_configs': aiProviderConfigs,
    };

    final agentId = _scopedAgentId;
    final mutationId = ++_settingsMutationId;
    try {
      await _queueSettingsWrite(payload, agentId: agentId);
      if (mutationId == _settingsMutationId && agentId == _scopedAgentId) {
        settings = <String, dynamic>{...settings, ...payload};
      }
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      _finishSettingsSave();
    }
  }

  Future<void> saveBehaviorConfig(Map<String, dynamic> config) async {
    _beginSettingsSave();
    try {
      final response = await _backendClient.saveBehaviorConfig(
        backendUrl,
        config,
        agentId: _scopedAgentId,
      );
      behaviorConfig = response['config'] is Map
          ? Map<String, dynamic>.from(response['config'] as Map)
          : Map<String, dynamic>.from(config);
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      _finishSettingsSave();
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
    final securityKeyRows = response['securityKeys'] ?? response['credentials'];
    if (securityKeyRows is List) {
      accountSecurityKeys = securityKeyRows
          .whereType<Map<dynamic, dynamic>>()
          .map(SecurityKeyItem.fromJson)
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

  Future<void> refreshAiCatalog() async {
    if (!isAuthenticated) return;
    try {
      final agentId = _scopedAgentId;
      final modelsResponse = await _backendClient.fetchSupportedModels(
        backendUrl,
        agentId: agentId,
      );
      final providersResponse = await _backendClient.fetchAiProviders(
        backendUrl,
        agentId: agentId,
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
      notifyListeners();
    } catch (_) {
      // Keep whatever catalog is already in memory rather than clearing it.
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
      usageAndLimits = AccountUsageAndLimits.fromJson(
        await _backendClient.fetchAccountUsage(backendUrl),
      );
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isLoadingAccountSettings = false;
      notifyListeners();
    }
  }

  Future<void> refreshRateLimitUsage() async {
    if (!isAuthenticated) return;
    try {
      usageAndLimits = AccountUsageAndLimits.fromJson(
        await _backendClient.fetchAccountUsage(backendUrl),
      );
      notifyListeners();
    } catch (_) {}
  }

  // ── Billing ──────────────────────────────────────────────────────────────

  Future<void> checkBillingEnabled() async {
    try {
      final r = await _backendClient.getBillingPlans(backendUrl);
      final enabled = r['plans'] != null;
      if (showBillingSection != enabled) {
        showBillingSection = enabled;
        notifyListeners();
      }
    } catch (_) {
      if (showBillingSection) {
        showBillingSection = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshBilling() async {
    if (!isAuthenticated || !showBillingSection) return;
    isLoadingBilling = true;
    notifyListeners();
    try {
      final results = await Future.wait(<Future<Map<String, dynamic>>>[
        _backendClient.getBillingInfo(backendUrl),
        _backendClient.getBillingPlans(backendUrl),
        _backendClient.getBillingInvoices(backendUrl),
      ]);
      billingSubscription = results[0]['subscription'] as Map<String, dynamic>?;
      billingPlans = _asDynList(
        results[1]['plans'],
      ).cast<Map<String, dynamic>>();
      billingInvoices = _asDynList(
        results[2]['invoices'],
      ).cast<Map<String, dynamic>>();
    } catch (_) {
      // retain previous data on error
    } finally {
      isLoadingBilling = false;
      notifyListeners();
    }
  }

  Future<String?> createCheckoutSession(String planId) async {
    try {
      final serverUrl = backendUrl;
      final result = await _backendClient.createCheckoutSession(
        baseUrl: serverUrl,
        planId: planId,
        successUrl: '$serverUrl/',
        cancelUrl: '$serverUrl/',
      );
      return result['url'] as String?;
    } catch (e) {
      errorMessage = _friendlyErrorMessage(e);
      notifyListeners();
      return null;
    }
  }

  Future<String?> createPortalSession() async {
    try {
      final serverUrl = backendUrl;
      final result = await _backendClient.createPortalSession(
        baseUrl: serverUrl,
        returnUrl: '$serverUrl/',
      );
      return result['url'] as String?;
    } catch (e) {
      errorMessage = _friendlyErrorMessage(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> cancelBillingSubscription() async {
    try {
      await _backendClient.cancelBillingSubscription(backendUrl);
      await refreshBilling();
      return true;
    } catch (e) {
      errorMessage = _friendlyErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  List<dynamic> _asDynList(dynamic val) =>
      val is List ? val : const <dynamic>[];

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

  bool get supportsSecurityKeys => _webAuthnClient.isSupported;

  Map<String, dynamic> _asJsonMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  Future<void> registerSecurityKey({required String label}) async {
    isConfiguringTwoFactor = true;
    errorMessage = null;
    notifyListeners();
    try {
      final begin = await _backendClient.beginSecurityKeyRegistration(
        backendUrl,
      );
      final options = _asJsonMap(begin['options']);
      if (options.isEmpty) {
        throw Exception('The security key registration could not be started.');
      }
      final attestation = await _webAuthnClient.createCredential(options);
      _applyAccountResponse(
        await _backendClient.completeSecurityKeyRegistration(
          baseUrl: backendUrl,
          response: attestation,
          label: label.trim(),
        ),
      );
    } on WebAuthnException catch (error) {
      if (!error.cancelled) {
        errorMessage = error.message;
      }
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isConfiguringTwoFactor = false;
      notifyListeners();
    }
  }

  Future<void> renameSecurityKey({
    required int id,
    required String label,
  }) async {
    isConfiguringTwoFactor = true;
    errorMessage = null;
    notifyListeners();
    try {
      _applyAccountResponse(
        await _backendClient.renameSecurityKey(
          baseUrl: backendUrl,
          id: id,
          label: label.trim(),
        ),
      );
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isConfiguringTwoFactor = false;
      notifyListeners();
    }
  }

  Future<void> removeSecurityKey(int id) async {
    isConfiguringTwoFactor = true;
    errorMessage = null;
    notifyListeners();
    try {
      _applyAccountResponse(
        await _backendClient.deleteSecurityKey(baseUrl: backendUrl, id: id),
      );
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isConfiguringTwoFactor = false;
      notifyListeners();
    }
  }

  Future<void> signInWithSecurityKey({String? username}) async {
    isUsingSecurityKey = true;
    isAuthenticating = true;
    errorMessage = null;
    authInfoMessage = null;
    notifyListeners();

    try {
      final begin = await _backendClient.beginSecurityKeyLogin(
        baseUrl: backendUrl,
        username: username?.trim(),
      );
      final options = _asJsonMap(begin['options']);
      if (options.isEmpty) {
        throw Exception('Security key sign-in could not be started.');
      }
      final assertion = await _webAuthnClient.getAssertion(options);
      final response = await _backendClient.completeSecurityKeyLogin(
        baseUrl: backendUrl,
        response: assertion,
      );
      if (response['requiresTwoFactor'] == true) {
        final responseUser = _asJsonMap(response['user']);
        pendingTwoFactorUsername = responseUser['username']?.toString() ?? '';
        isAwaitingTwoFactor = true;
        isAuthenticated = false;
        await _persistCredentials();
        return;
      }
      await _completeAuthenticatedResponse(
        response,
        fallbackUsername: username,
        authMethod: 'security_key',
        retentionErrorMessage:
            'Security key sign-in completed, but NeoAgent could not keep the browser session. Please sign in again.',
      );
    } on WebAuthnException catch (error) {
      if (!error.cancelled) {
        errorMessage = error.message;
      }
      isAuthenticated = false;
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      isAuthenticated = false;
    } finally {
      isUsingSecurityKey = false;
      isAuthenticating = false;
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
        // NeoRecall (and other providers) may require 2FA before consent.
        timeout: const Duration(minutes: 5),
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

  Future<Map<String, dynamic>> unlockBitwarden(
    String masterPassword, {
    required bool persistSession,
    String? twoStepMethod,
    String? twoStepCode,
  }) async {
    try {
      errorMessage = null;
      return await _backendClient.unlockBitwarden(
        backendUrl,
        masterPassword: masterPassword,
        persistSession: persistSession,
        twoStepMethod: twoStepMethod,
        twoStepCode: twoStepCode,
        agentId: _scopedAgentId,
      );
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> lockBitwarden() async {
    try {
      errorMessage = null;
      await _backendClient.lockBitwarden(backendUrl, agentId: _scopedAgentId);
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> fetchBitwardenItems() async {
    final response = await _backendClient.fetchBitwardenItems(
      backendUrl,
      agentId: _scopedAgentId,
    );
    return _jsonMapList(
      response['items'],
    ).map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchCredentialBindings() async {
    final response = await _backendClient.fetchCredentialBindings(
      backendUrl,
      agentId: _scopedAgentId,
    );
    return _jsonMapList(
      response['bindings'],
    ).map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> createCredentialBinding(Map<String, dynamic> binding) async {
    try {
      errorMessage = null;
      await _backendClient.createCredentialBinding(
        backendUrl,
        binding: binding,
        agentId: _scopedAgentId,
      );
      await refreshSkills();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      rethrow;
    }
  }

  Future<void> deleteCredentialBinding(String bindingId) async {
    try {
      errorMessage = null;
      await _backendClient.deleteCredentialBinding(
        backendUrl,
        bindingId,
        agentId: _scopedAgentId,
      );
      await refreshSkills();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      rethrow;
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

  Future<Map<String, dynamic>> testOfficialIntegration(
    String providerId, {
    required int connectionId,
  }) async {
    final busyKey = '$providerId:$connectionId:test';
    if (_busyOfficialIntegrationKeys.contains(busyKey)) {
      return const <String, dynamic>{};
    }
    _busyOfficialIntegrationKeys.add(busyKey);
    errorMessage = null;
    notifyListeners();
    try {
      final result = await _backendClient.testOfficialIntegration(
        backendUrl,
        providerId,
        connectionId: connectionId,
        agentId: _scopedAgentId,
      );
      await refreshSkills();
      return result;
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      rethrow;
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
      await saveSettingsPayload(configSnapshot);
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
    final agentId = _scopedAgentId;
    final previousSettings = settings;
    final mutationId = ++_settingsMutationId;
    settings = <String, dynamic>{...settings, ...payload};
    _beginSettingsSave();
    try {
      await _queueSettingsWrite(payload, agentId: agentId);
    } catch (error) {
      if (mutationId == _settingsMutationId && agentId == _scopedAgentId) {
        settings = previousSettings;
      }
      errorMessage = _friendlyErrorMessage(error);
      rethrow;
    } finally {
      _finishSettingsSave();
    }
  }

  void _beginSettingsSave() {
    _activeSettingsSaves += 1;
    isSavingSettings = true;
    errorMessage = null;
    notifyListeners();
  }

  void _finishSettingsSave() {
    _activeSettingsSaves = math.max(0, _activeSettingsSaves - 1);
    isSavingSettings = _activeSettingsSaves > 0;
    notifyListeners();
  }

  Future<Map<String, dynamic>> _queueSettingsWrite(
    Map<String, dynamic> payload, {
    required String? agentId,
  }) {
    final settingsBackendUrl = backendUrl;
    _pendingSettingsWrites += 1;
    final request = _settingsWriteTail.then(
      (_) => _backendClient.saveSettings(
        settingsBackendUrl,
        payload,
        agentId: agentId,
      ),
    );
    final write = request.whenComplete(() {
      _pendingSettingsWrites = math.max(0, _pendingSettingsWrites - 1);
    });
    _settingsWriteTail = write.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return write;
  }

  Future<Map<String, dynamic>> refreshSocialReachStatus() async {
    final response = await _backendClient.fetchSocialReachStatus(backendUrl);
    socialReachStatus = Map<String, dynamic>.from(response);
    notifyListeners();
    return socialReachStatus;
  }

  Future<Map<String, dynamic>> importSocialReachCookies(String platform) async {
    final response = await _backendClient.importSocialReachCookies(
      backendUrl,
      platform,
    );
    await refreshSocialReachStatus();
    return response;
  }

  Future<Map<String, dynamic>> clearSocialReachCookies(String platform) async {
    final response = await _backendClient.clearSocialReachCookies(
      backendUrl,
      platform,
    );
    await refreshSocialReachStatus();
    return response;
  }

  Future<void> disconnectMessagingPlatform(String platform) async {
    final busyKey = '$platform:disconnect';
    if (_busyMessagingPlatformKeys.contains(busyKey)) {
      return;
    }

    _busyMessagingPlatformKeys.add(busyKey);
    errorMessage = null;
    notifyListeners();

    try {
      await _backendClient.disconnectMessagingPlatform(
        backendUrl,
        platform: platform,
        agentId: _scopedAgentId,
      );
      await refreshMessaging();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      _busyMessagingPlatformKeys.remove(busyKey);
      notifyListeners();
    }
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
    memoryRecallResults = (await _backendClient.recallMemory(
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

  Future<Map<String, dynamic>> inspectMemory(String query) async {
    return _backendClient.inspectMemory(
      backendUrl,
      query,
      agentId: _scopedAgentId,
    );
  }

  Future<void> updateAssistantBehaviorNotes(String content) async {
    final agentId = _scopedAgentId;
    _settingsMutationId += 1;
    _beginSettingsSave();
    try {
      await _queueSettingsWrite(<String, dynamic>{
        'assistant_behavior_notes': content,
      }, agentId: agentId);
      await refreshMemory();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      _finishSettingsSave();
    }
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
    Map<String, dynamic>? taskConfig,
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
      taskConfig: taskConfig,
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
      'Shared attachments from the NeoAgent client:',
      lines,
      'Use these for context. If a local URI is not directly accessible from the server, ask me to provide the file through an accessible workspace.',
    ].join('\n');
    if (base.isEmpty) {
      return attachmentBlock;
    }
    return '$base\n\n$attachmentBlock';
  }

  void openVoiceAssistantSurface() {
    setSelectedSection(AppSection.voiceAssistant);
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
    try {
      await _backendClient.startMcpServer(backendUrl, id);
      await refreshMcp();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      await refreshMcp();
      notifyListeners();
    }
  }

  Future<void> stopMcpServer(int id) async {
    try {
      await _backendClient.stopMcpServer(backendUrl, id);
      await refreshMcp();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      await refreshMcp();
      notifyListeners();
    }
  }

  Future<void> deleteMcpServer(int id) async {
    try {
      await _backendClient.deleteMcpServer(backendUrl, id);
      await refreshMcp();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      await refreshMcp();
      notifyListeners();
    }
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
    final backendCode = error is BackendException ? error.code : null;

    if (backendCode == 'COMPUTER_STORAGE_CAPACITY') {
      return 'The computer needs more free disk space on the NeoAgent host. Free some space, then try again.';
    }
    if (backendCode == 'COMPUTER_CAPACITY') {
      return 'All cloud-computer slots are currently in use. Try again in a moment.';
    }
    if (backendCode == 'COMPUTER_RUNTIME_UNAVAILABLE' ||
        backendCode == 'COMPUTER_FIRMWARE_MISSING') {
      return 'The computer runtime needs repair. Run NeoAgent Doctor, then try again.';
    }

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
      final filtered = <String>[];
      for (final item in raw) {
        final savedId = item.toString().trim();
        if (savedId.isEmpty) continue;
        final model = _modelForValue(savedId, supportedModels);
        final id = model?.id ?? savedId;
        // Availability belongs to execution-time routing, not persistence.
        // A saved choice remains selected until the user explicitly changes it.
        if (!filtered.contains(id)) {
          filtered.add(id);
        }
      }
      if (filtered.isNotEmpty) {
        return filtered;
      }
    }
    return supportedModels
        .where((model) => model.available)
        .map((model) => model.id)
        .toList();
  }

  String get defaultChatModel => _ensureModelValue(
    settings['default_chat_model']?.toString() ?? 'auto',
    supportedModels,
    allowAuto: true,
    preserveUnknown: true,
  );

  String get defaultSubagentModel => _ensureModelValue(
    settings['default_subagent_model']?.toString() ?? 'auto',
    supportedModels,
    allowAuto: true,
    preserveUnknown: true,
  );

  String get defaultSpeechModel => _ensureModelValue(
    settings['default_speech_model']?.toString() ?? 'auto',
    supportedModels,
    allowAuto: true,
    preserveUnknown: true,
  );

  String get voiceSttProvider =>
      _settingString('voice_stt_provider', '', lowercase: true);

  String get voiceSttModel => _settingString('voice_stt_model', '');

  String get voiceTtsProvider =>
      _settingString('voice_tts_provider', '', lowercase: true);

  String get voiceTtsModel => _settingString('voice_tts_model', '');

  String get voiceTtsVoice => _settingString('voice_tts_voice', '');

  String get voiceMediaMode =>
      _settingString('voice_media_mode', 'auto', lowercase: true);

  String get voiceInputMode =>
      _settingString('voice_input_mode', 'ptt', lowercase: true);

  Map<String, dynamic> get voiceCapabilities =>
      _jsonMap(settings['voice_capabilities']);

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
    return _modelForValue(id, supportedModels);
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
    if (_socket != null && existing == origin) {
      if (!socketConnected) {
        _socket!.connect();
      }
      return;
    }

    _disconnectSocket();

    final options = <String, dynamic>{
      'transports': <String>['websocket', 'polling'],
      'autoConnect': false,
      'reconnection': true,
      'reconnectionDelay': 800,
      'reconnectionDelayMax': 8000,
      'withCredentials': true,
    };

    final cookie = _backendClient.sessionCookie;
    if (!kIsWeb && cookie != null && cookie.isNotEmpty) {
      options['extraHeaders'] = <String, String>{'Cookie': cookie};
    }

    final socket = io.io(origin, options);
    socket.onConnect((_) {
      socketConnected = true;
      unawaited(_AppNotificationService.requestIncomingCallPermission());
      socket.emit('integrations:status');
      if (_socketHasConnectedOnce && isAuthenticated) {
        unawaited(refresh());
      }
      _socketHasConnectedOnce = true;
      final shouldRebindVoiceSession =
          voiceAssistantLiveState.hasActiveSession ||
          _hasRecoverableLiveVoiceTurn();
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        transportState: shouldRebindVoiceSession ? 'reconnecting' : 'connected',
        clearError: _hasRecoverableLiveVoiceTurn(),
      );
      if (shouldRebindVoiceSession) {
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
      final hasVoiceSession = voiceAssistantLiveState.hasActiveSession;
      if (_hasRecoverableLiveVoiceTurn()) {
        _setLiveVoiceRecoveryWindow();
      }
      if (hasVoiceSession) {
        voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
          transportState: hasNetworkConnection
              ? 'reconnecting'
              : 'disconnected',
          state: _liveVoiceCaptureActive ? 'listening' : 'reconnecting',
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
      if (voiceAssistantLiveState.hasActiveSession ||
          _hasRecoverableLiveVoiceTurn()) {
        voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
          transportState: 'reconnecting',
        );
      }
      notifyListeners();
    });
    socket.on('computer:status', (dynamic data) {
      computerRuntime = _jsonMap(data);
      notifyListeners();
    });
    socket.on('teach:status', (dynamic data) {
      teachRuntime = _jsonMap(data);
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
    socket.on('messaging:attention_required', (dynamic data) {
      final payload = _jsonMap(data);
      final platform = payload['platform']?.toString() ?? '';
      if (platform.isEmpty) return;
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        unawaited(
          _AppNotificationService.showMessagingConnectionNotification(platform),
        );
      }
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
      final agentId =
          payload['agentId']?.toString() ?? payload['agent_id']?.toString();
      if (!_matchesSelectedAgent(agentId)) {
        return;
      }
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
      final agentId =
          payload['agentId']?.toString() ?? payload['agent_id']?.toString();
      if (!_matchesSelectedAgent(agentId)) {
        return;
      }
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
    socket.on('timeline:updated', (dynamic _) {
      unawaited(refreshTimeline());
    });
    socket.on('voice:incoming_call', (dynamic data) {
      final call = IncomingAgentCall.fromJson(_jsonMap(data));
      if (call.callId.isEmpty) return;
      incomingAgentCall = call;
      _incomingCallExpiryTimer?.cancel();
      final delay = call.expiresAt.difference(DateTime.now());
      _incomingCallExpiryTimer = Timer(
        delay.isNegative ? Duration.zero : delay,
        () {
          _clearIncomingAgentCall(call.callId);
          notifyListeners();
        },
      );
      unawaited(_AppNotificationService.showIncomingCallNotification(call));
      showIncomingCallBrowserAlert(call.callId, call.agentName);
      if (_supportsDesktopShell) {
        unawaited(windowManager.show());
        unawaited(windowManager.focus());
      }
      notifyListeners();
    });
    socket.on('voice:call_cancelled', (dynamic data) {
      _clearIncomingAgentCall(_jsonMap(data)['callId']?.toString());
      notifyListeners();
    });
    socket.on('voice:call_ended', (dynamic data) {
      _clearIncomingAgentCall(_jsonMap(data)['callId']?.toString());
      notifyListeners();
    });
    socket.on('voice:session_ready', (dynamic data) {
      final payload = _jsonMap(data);
      final acceptedCall = incomingAgentCall;
      final acceptedCallId = acceptedCall?.callId;
      if (acceptedCallId != null &&
          payload['sessionId']?.toString() == acceptedCallId) {
        if (acceptedCall!.agentId.isNotEmpty &&
            agentProfiles.any((agent) => agent.id == acceptedCall.agentId)) {
          selectedAgentId = acceptedCall.agentId;
          unawaited(_persistSelectedAgentId(acceptedCall.agentId));
        }
        _clearIncomingAgentCall(acceptedCallId);
        setSelectedSection(AppSection.voiceAssistant);
      }
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        sessionId: payload['sessionId']?.toString() ?? '',
        mediaMode:
            payload['mediaMode']?.toString().ifEmpty('composed') ?? 'composed',
        inputMode: payload['inputMode']?.toString().ifEmpty('ptt') ?? 'ptt',
        inputSampleRate: _asInt(payload['inputSampleRate']) >= 8000
            ? _asInt(payload['inputSampleRate'])
            : 24000,
        provider:
            payload['provider']?.toString().ifEmpty(voiceSttProvider) ??
            voiceSttProvider,
        model:
            payload['model']?.toString().ifEmpty(voiceSttModel) ??
            voiceSttModel,
        voice:
            payload['voice']?.toString().ifEmpty(voiceTtsVoice) ??
            voiceTtsVoice,
        activeRunId: payload['activeRunId']?.toString() ?? '',
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
        activeRunId: payload['clearRunId'] == true
            ? ''
            : payload['runId']?.toString().trim().isNotEmpty == true
            ? payload['runId'].toString()
            : voiceAssistantLiveState.activeRunId,
      );
      notifyListeners();
    });
    socket.on('voice:task_cancelled', (dynamic data) {
      final payload = _jsonMap(data);
      if (!_matchesLiveVoiceSessionPayload(payload)) {
        return;
      }
      final runId = payload['runId']?.toString() ?? '';
      if (runId.isNotEmpty) {
        _voiceRunIds.remove(runId);
      }
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        activeRunId: '',
        state: 'idle',
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
      final content = payload['content']?.toString() ?? '';
      _upsertVoiceTimelineItem(
        payload: payload,
        role: 'user',
        kind: 'transcript_partial',
        content: content,
        isFinal: false,
      );
      notifyListeners();
    });
    socket.on('voice:transcript_final', (dynamic data) {
      final payload = _jsonMap(data);
      if (!_matchesLiveVoiceSessionPayload(payload)) {
        return;
      }
      final content = payload['content']?.toString() ?? '';
      _upsertVoiceTimelineItem(
        payload: payload,
        role: 'user',
        kind: 'transcript_final',
        content: content,
        isFinal: true,
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
      final isFinal = kind == 'final' || kind == 'opening';
      if (content.trim().isEmpty) {
        return;
      }
      _upsertVoiceTimelineItem(
        payload: payload,
        role: 'assistant',
        kind: kind,
        content: content,
        isFinal: isFinal,
      );
      if (isFinal && content.trim().isNotEmpty) {
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
      final sequence = _asInt(payload['sequence']);
      final messageId = payload['messageId']?.toString() ?? '';
      final runId = payload['runId']?.toString() ?? '';
      final turnId = payload['turnId']?.toString() ?? '';
      final kind = payload['kind']?.toString() ?? 'audio';
      final audioKey = '$messageId:$runId:$turnId:$kind:$sequence';
      if (!_liveVoiceAudioKeys.add(audioKey)) return;
      if (_liveVoiceAudioKeys.length > 512) {
        _liveVoiceAudioKeys.remove(_liveVoiceAudioKeys.first);
      }
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
      final agentId =
          payload['agentId']?.toString() ?? payload['agent_id']?.toString();
      if (triggerSource == 'voice_live') {
        _voiceRunIds.add(runId);
        voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
          activeRunId: runId,
          state: 'working',
        );
        notifyListeners();
        return;
      }
      if (triggerSource == 'cowork' || _coworkConversationId(payload) != null) {
        _updateCoworkRunEvent('start', payload);
        return;
      }
      final pendingSteeringCount = activeRun?.pendingSteeringCount ?? 0;
      if (_isBackgroundRun(triggerSource)) {
        _backgroundRunIds.add(runId);
        return;
      }
      if (!_matchesSelectedAgent(agentId)) {
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
      _streamingIteration = 0;
      isSendingMessage = true;
      notifyListeners();
    });
    socket.on('run:phase', (dynamic data) {
      final payload = _jsonMap(data);
      if (_coworkConversationId(payload) != null) {
        _updateCoworkRunEvent('phase', payload);
      }
    });
    socket.on('run:thinking', (dynamic data) {
      final payload = _jsonMap(data);
      if (_coworkConversationId(payload) != null) {
        _updateCoworkRunEvent('thinking', payload);
        return;
      }
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
      if (_coworkConversationId(payload) != null) {
        _updateCoworkRunEvent('analysis', payload);
        return;
      }
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
      toolEvents = _capToolEvents(<ToolEventItem>[
        ...toolEvents,
        ToolEventItem(
          id: 'analysis-${DateTime.now().microsecondsSinceEpoch}',
          toolName: 'analysis',
          type: 'analysis',
          status: 'completed',
          summary: summary,
        ),
      ]);
      if (activeRun?.runId == runId) {
        activeRun = activeRun!.copyWith(phase: 'Analyzing');
      }
      notifyListeners();
    });
    socket.on('run:plan', (dynamic data) {
      final payload = _jsonMap(data);
      if (_coworkConversationId(payload) != null) {
        _updateCoworkRunEvent('plan', payload);
        return;
      }
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
      toolEvents = _capToolEvents(<ToolEventItem>[
        ...toolEvents,
        ToolEventItem(
          id: 'plan-${DateTime.now().microsecondsSinceEpoch}',
          toolName: 'plan',
          type: 'planning',
          status: 'completed',
          summary: steps.ifEmpty('Execution plan created.'),
        ),
      ]);
      if (activeRun?.runId == runId) {
        activeRun = activeRun!.copyWith(phase: 'Planning');
      }
      notifyListeners();
    });
    socket.on('run:stopping', (dynamic data) {
      final payload = _jsonMap(data);
      if (_coworkConversationId(payload) != null) {
        _updateCoworkRunEvent('stopping', payload);
        return;
      }
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
    socket.on('run:pausing', (dynamic data) {
      final payload = _jsonMap(data);
      if (_coworkConversationId(payload) != null) {
        _updateCoworkRunEvent('pausing', payload);
        return;
      }
      final runId = payload['runId']?.toString() ?? '';
      if (activeRun?.runId == runId) {
        activeRun = activeRun!.copyWith(phase: 'Pausing');
        notifyListeners();
      }
    });
    socket.on('run:tool_start', (dynamic data) {
      final payload = _jsonMap(data);
      if (_coworkConversationId(payload) != null) {
        _updateCoworkRunEvent('tool_start', payload);
        return;
      }
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
      toolEvents = _capToolEvents(<ToolEventItem>[
        ...toolEvents.where((event) => event.id != item.id),
        item,
      ]);
      // Text streamed before a tool call was the agent thinking out loud, not
      // its answer. Keep it in the activity timeline and take it out of the live
      // bubble so it cannot be mistaken for a reply that later changed.
      final preamble = streamingAssistant.trim();
      if (preamble.isNotEmpty) {
        _appendToolNote(preamble, toolName: 'reasoning');
        streamingAssistant = '';
      }
      if (activeRun?.runId == runId) {
        activeRun = activeRun!.copyWith(phase: 'Running tool');
      }
      notifyListeners();
    });
    socket.on('run:verification', (dynamic data) {
      final payload = _jsonMap(data);
      if (_coworkConversationId(payload) != null) {
        _updateCoworkRunEvent('verification', payload);
        return;
      }
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.contains(runId)) {
        return;
      }
      if (_backgroundRunIds.contains(runId)) {
        return;
      }
      toolEvents = _capToolEvents(<ToolEventItem>[
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
      ]);
      if (activeRun?.runId == runId) {
        activeRun = activeRun!.copyWith(phase: 'Verifying');
      }
      notifyListeners();
    });
    socket.on('run:subagent', (dynamic data) {
      final payload = _jsonMap(data);
      if (_coworkConversationId(payload) != null) {
        _updateCoworkRunEvent('subagent', payload);
        return;
      }
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
      toolEvents = _capToolEvents(nextEvents);
      notifyListeners();
    });
    socket.on('run:tool_end', (dynamic data) {
      final payload = _jsonMap(data);
      if (_coworkConversationId(payload) != null) {
        _updateCoworkRunEvent('tool_end', payload);
        return;
      }
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
      toolEvents = _capToolEvents(next);
      final toolName = payload['toolName']?.toString() ?? '';
      final screenshotPath =
          payload['screenshotPath']?.toString() ??
          (payload['result'] is Map
              ? (payload['result'] as Map)['screenshotPath']?.toString()
              : null);
      if (screenshotPath != null && screenshotPath.isNotEmpty) {
        if (toolName.startsWith('android_')) {
          androidScreenshotPath = screenshotPath;
        }
      }
      if (toolName.startsWith('android_')) {
        unawaited(refreshDevices());
      }
      notifyListeners();
    });
    socket.on('tool:approval_required', (dynamic data) {
      final payload = _jsonMap(data);
      final req = ToolApprovalRequest.fromJson(payload);
      pendingApproval = req;
      notifyListeners();
      // Show interactive push notification when app is backgrounded
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        _AppNotificationService.showApprovalNotification(req);
      }
    });
    socket.on('tool:approval_resolved', (dynamic data) {
      final payload = _jsonMap(data);
      final resolvedId = payload['approvalId']?.toString() ?? '';
      if (pendingApproval?.approvalId == resolvedId) {
        _AppNotificationService.cancelApprovalNotification(resolvedId);
        pendingApproval = null;
        notifyListeners();
      }
    });
    socket.on('run:steer_queued', (dynamic data) {
      final payload = _jsonMap(data);
      if (_coworkConversationId(payload) != null) {
        _updateCoworkRunEvent('steer_queued', payload);
        return;
      }
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.contains(runId)) {
        return;
      }
      if (_backgroundRunIds.contains(runId)) {
        return;
      }
      toolEvents = _capToolEvents(<ToolEventItem>[
        ...toolEvents,
        ToolEventItem(
          id: 'steer-queued-${DateTime.now().microsecondsSinceEpoch}',
          toolName: 'steering',
          type: 'note',
          status: 'completed',
          summary:
              'Queued as steering for the current run: ${payload['content']?.toString() ?? ''}',
        ),
      ]);
      if (activeRun?.runId == runId || activeRun?.runId == 'pending') {
        activeRun = activeRun!.copyWith(
          pendingSteeringCount: _asInt(payload['pendingCount']),
        );
      }
      notifyListeners();
    });
    socket.on('run:steer_applied', (dynamic data) {
      final payload = _jsonMap(data);
      if (_coworkConversationId(payload) != null) {
        _updateCoworkRunEvent('steer_applied', payload);
        return;
      }
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.contains(runId)) {
        return;
      }
      if (_backgroundRunIds.contains(runId)) {
        return;
      }
      toolEvents = _capToolEvents(<ToolEventItem>[
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
      ]);
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
      if (_coworkConversationId(payload) != null) {
        _updateCoworkRunEvent('interim', payload);
        return;
      }
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
      if (_coworkConversationId(payload) != null) {
        _updateCoworkRunEvent('interim', payload);
        return;
      }
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
    socket.on('run:input_required', (dynamic data) {
      final payload = _jsonMap(data);
      _updateCoworkRunEvent('input_required', payload);
    });
    socket.on('run:paused', (dynamic data) {
      final payload = _jsonMap(data);
      if (_coworkConversationId(payload) != null) {
        _updateCoworkRunEvent('paused', payload);
      }
    });
    socket.on('run:resumed', (dynamic data) {
      final payload = _jsonMap(data);
      if (_coworkConversationId(payload) != null) {
        _updateCoworkRunEvent('resumed', payload);
      }
    });
    socket.on('run:stream', (dynamic data) {
      final payload = _jsonMap(data);
      if (_coworkConversationId(payload) != null) {
        _updateCoworkRunEvent('stream', payload);
        return;
      }
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.contains(runId)) {
        return;
      }
      if (_backgroundRunIds.contains(runId)) {
        return;
      }
      // Each model turn restarts its stream from empty, so the payload is the
      // text of that turn alone. Without tracking the turn, a later turn's text
      // overwrote the live bubble in place and the answer appeared to rewrite
      // itself; a new turn now starts a new bubble instead.
      final iteration = _asInt(payload['iteration']);
      if (iteration != _streamingIteration) {
        _streamingIteration = iteration;
        streamingAssistant = '';
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
      if (_coworkConversationId(payload) != null) {
        _updateCoworkRunEvent('complete', payload);
        return;
      }
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.remove(runId)) {
        voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
          activeRunId: '',
          state: voiceAssistantLiveState.state == 'speaking'
              ? 'speaking'
              : 'idle',
        );
        unawaited(refreshRateLimitUsage());
        notifyListeners();
        return;
      }
      if (_backgroundRunIds.remove(runId)) {
        unawaited(refreshRunsOnly());
        unawaited(refreshMemory());
        unawaited(refreshRateLimitUsage());
        notifyListeners();
        return;
      }
      final content = payload['content']?.toString().trim() ?? '';
      if (content.isNotEmpty) {
        final schema = payload['schema'];
        _appendAssistantChatMessage(
          content,
          platform: 'web',
          metadata: schema != null
              ? <String, dynamic>{'schema': schema}
              : const <String, dynamic>{},
        );
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
      unawaited(refreshRateLimitUsage());
      notifyListeners();
    });
    socket.on('run:stopped', (dynamic data) {
      final payload = _jsonMap(data);
      if (_coworkConversationId(payload) != null) {
        _updateCoworkRunEvent('stopped', payload);
        return;
      }
      final runId = payload['runId']?.toString() ?? '';
      clearPendingApprovalForRun(runId);
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
    socket.on('run:interrupted', (dynamic data) {
      final payload = _jsonMap(data);
      if (_coworkConversationId(payload) != null) {
        _updateCoworkRunEvent('stopped', payload);
        return;
      }
      final runId = payload['runId']?.toString() ?? '';
      clearPendingApprovalForRun(runId);
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
          phase: 'Interrupted',
          pendingSteeringCount: 0,
        );
      }
      unawaited(refreshRunsOnly());
      notifyListeners();
    });
    socket.on('run:error', (dynamic data) {
      final payload = _jsonMap(data);
      if (_coworkConversationId(payload) != null) {
        _updateCoworkRunEvent('error', payload);
        return;
      }
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
      final message =
          payload['error']?.toString().trim() ??
          'I could not complete that request right now. Please try again in a moment.';
      errorMessage = _friendlyErrorMessage(
        BackendException(
          message,
          statusCode: payload['code'] == 'RATE_LIMIT_EXCEEDED' ? 429 : null,
        ),
      );
      if (payload['code'] == 'RATE_LIMIT_EXCEEDED') {
        unawaited(refreshRateLimitUsage());
      }
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
    socket.on('skill:learned', (dynamic _) {
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
