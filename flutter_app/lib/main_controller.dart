part of 'main.dart';

/// Run socket events that change a run's status or recorded steps.
const Set<String> _runActivityEvents = <String>{
  'run:start',
  'run:background',
  'run:analysis',
  'run:plan',
  'run:tool_start',
  'run:tool_end',
  'run:subagent',
  'run:verification',
  'run:input_required',
  'run:paused',
  'run:resumed',
  'run:complete',
  'run:stopped',
  'run:interrupted',
  'run:error',
};

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
    _AppNotificationService.onCallAction = _handleCallNotificationAction;
    _AppNotificationService.onApprovalAction = _resolveApprovalFromNotification;
    _AppNotificationService.listenForActions();
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

  SharedPreferences? _prefs;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  io.Socket? _socket;
  Timer? _updatePollTimer;
  Timer? _qrLoginPollTimer;
  Timer? _manualRunCooldownTimer;
  final Set<String> _backgroundRunIds = <String>{};
  // Chat runs the server moved to the background: the composer is free again,
  // but their final answer still belongs in this chat.
  final Set<String> _detachedChatRunIds = <String>{};
  final Set<String> _voiceRunIds = <String>{};
  final Set<String> _busyOfficialIntegrationKeys = <String>{};
  final Set<String> _busyMessagingPlatformKeys = <String>{};
  final Map<String, DateTime> _manualRunCooldowns = <String, DateTime>{};
  final Set<String> _addingTaskRecommendations = <String>{};
  static const Duration _manualRunCooldownDuration = Duration(seconds: 10);
  static const int _chatHistoryPageSize = 20;
  int _authCycle = 0;
  bool _isPollingQrLogin = false;
  bool _socketHasConnectedOnce = false;
  bool _onboardingManuallyReopened = false;
  List<LogEntry> _clientLogs = const <LogEntry>[];

  bool isBooting = true;
  AppLanguage language = currentAppLanguage;
  int _languageRevision = 0;
  bool showOnboarding = false;
  bool isAuthenticated = false;
  bool isAuthenticating = false;
  bool isAwaitingTwoFactor = false;
  bool isRefreshing = false;

  /// True from a bot switch until that bot's data has loaded. The switch
  /// clears the previous bot's lists, so pages would otherwise flash their
  /// empty states ("No runs yet") before the new data arrives.
  bool isSwitchingAgent = false;

  /// False from sign-in until the first refresh settles. Every list is empty
  /// until then, which pages would otherwise present as "nothing here".
  bool hasLoadedInitialData = false;
  int _refreshSeq = 0;
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
  bool isLoadingAccess = false;
  bool socketConnected = false;
  bool hasNetworkConnection = true;
  bool networkStatusKnown = false;
  bool isDiscoveringBackends = false;

  io.Socket? get streamSocket => socketConnected ? _socket : null;

  bool hasUser = true;
  bool registrationOpen = false;
  bool serviceEmailConfigured = false;
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

  /// The open Settings page. Null on a phone means the page list is showing;
  /// wider layouts show the profile page in its place.
  SettingsPage? settingsPage;
  Map<String, dynamic>? user;
  Map<String, dynamic> accountTwoFactor = const <String, dynamic>{};
  List<AccountSessionItem> accountSessions = const <AccountSessionItem>[];
  AccountUsageAndLimits? usageAndLimits;
  AccessSummary? accessSummary;
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
  bool chatHistoryHasMore = false;
  bool isLoadingOlderChatHistory = false;
  List<AgentProfile> agentProfiles = const <AgentProfile>[];
  String? selectedAgentId;
  List<ModelMeta> supportedModels = const <ModelMeta>[];

  /// SystemOne decision models, offered only in their own picker.
  List<ModelMeta> systemOneModels = const <ModelMeta>[];
  List<AiProviderMeta> aiProviders = const <AiProviderMeta>[];
  List<Map<String, dynamic>> byokProviders = const <Map<String, dynamic>>[];
  bool isLoadingByokProviders = false;
  List<RunSummary> recentRuns = const <RunSummary>[];
  DateTime? runsRefreshedAt;

  /// Fires on every run lifecycle socket event so open run views can refresh
  /// themselves without the whole app polling.
  final ValueNotifier<({int seq, String runId})> runActivity =
      ValueNotifier<({int seq, String runId})>((seq: 0, runId: ''));
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

  ActiveRunState? activeRun;
  // The foreground run that last ended in an error, cleared when the next one
  // starts. The mascot plays its blocked face once for it.
  String? _failedForegroundRunId;
  List<ToolEventItem> toolEvents = const <ToolEventItem>[];
  String streamingAssistant = '';
  // Which model turn the live bubble belongs to, so a new turn replaces it
  // rather than appearing to edit the previous one.
  int _streamingIteration = 0;
  bool _isStartingLiveVoice = false;
  bool _liveVoiceCaptureActive = false;
  bool _pendingLiveVoiceStop = false;
  bool _liveVoiceTelecomRouting = false;
  DateTime? _liveVoiceSessionStartedAt;
  bool _voiceCallRequested = false;
  bool _returnHomeAfterCall = false;
  final HomeWidgetBridge _homeWidgetBridge = HomeWidgetBridge();
  Timer? _incomingCallExpiryTimer;
  Completer<void>? _liveVoiceSessionOpenCompleter;
  final LiveVoicePlayer _liveVoicePlayer = LiveVoicePlayer();
  VoiceWorkClicks? _voiceWorkClicks;
  List<Uint8List>? _voiceKeyClickPcm;
  Timer? _voiceWorkClickArm;
  int _voiceWorkClickGeneration = 0;
  bool _liveVoiceHearingSpeech = false;
  VoiceAssistantLiveState voiceAssistantLiveState = VoiceAssistantLiveState();
  IncomingAgentCall? incomingAgentCall;

  /// The call that just ended, shown as a recap until the user moves on.
  EndedAgentCall? lastEndedCall;
  bool callSpeakerphoneOn = false;

  /// Ringing brought the app forward from the background, so a call that is
  /// not answered sends it back there.
  bool _callBroughtAppForward = false;

  /// A call hung up while it was still connecting; its session is closed as
  /// soon as the server reports it ready.
  String? _abandonedCallId;
  bool _desktopAskOnClose = true;
  bool _desktopKeepRunningOnClose = true;
  bool _desktopAssistantHotkeyEnabled = true;
  bool _locationTriggersEnabled = true;
  bool _notificationTriggersEnabled = true;

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
      ? appStrings.sendASteeringUpdateOrNextUp
      : appStrings.askAQuestionOrStartA;

  AgentProfile? get activeAgent {
    for (final agent in agentProfiles) {
      if (agent.id == selectedAgentId) {
        return agent;
      }
    }
    return agentProfiles.isEmpty ? null : agentProfiles.first;
  }

  String get activeAgentLabel => activeAgent?.displayName ?? appStrings.main;

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
    if (id == null || id.isEmpty) return appStrings.main;
    for (final agent in agentProfiles) {
      if (agent.id == id) return agent.displayName;
    }
    return appStrings.unknownAgent;
  }

  /// Tasks still running after the server moved them off the chat; the chat
  /// stays free while they work.
  List<RunSummary> get backgroundTasks => recentRuns
      .where((run) => run.isActive && run.ranInBackground)
      .toList(growable: false);

  bool get isAgentWorking => hasLiveRun || backgroundTasks.isNotEmpty;

  String get chatStatusLabel {
    final backgroundCount = backgroundTasks.length;
    final background = backgroundCount > 0
        ? appStrings.backgroundTaskCount(backgroundCount)
        : '';
    if (activeRun == null) {
      return background.ifEmpty(appStrings.idle);
    }

    var label = appStrings.arg1Arg2ActiveTools(
      activeRun!.phase,
      toolEvents.where((event) => event.status == 'running').length,
    );
    if (activeRun!.pendingSteeringCount > 0) {
      label = appStrings.arg1Arg2SteeringQueued(
        label,
        activeRun!.pendingSteeringCount,
      );
    } else if (hasLiveRun) {
      label = appStrings.arg1NewMessagesSteerThisRun(label);
    }
    return background.isEmpty ? label : '$label · $background';
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
    _AppNotificationService.onCallAction = null;
    _AppNotificationService.onApprovalAction = null;
    _AppNotificationService.stopListeningForActions();
    unawaited(CallBridge.dismiss());
    AndroidAutoBridge.instance.onStopVoiceMode = null;
    _updatePollTimer?.cancel();
    _qrLoginPollTimer?.cancel();
    _manualRunCooldownTimer?.cancel();
    _incomingCallExpiryTimer?.cancel();
    _socket?.dispose();
    runActivity.dispose();
    _diagnosticLogSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _appReleaseUpdater.dispose();
    _backendDiscoveryService.dispose();
    _desktopCompanion.removeListener(_onDesktopCompanionChanged);
    _localDisconnectHoldTimer?.cancel();
    unawaited(_desktopCompanion.disconnect());
    unawaited(_liveVoiceCapture.dispose());
    _haltVoiceWorkClicks();
    unawaited(_liveVoicePlayer.stop());
    _oauthLauncher.dispose();
    super.dispose();
  }

  bool get desktopAskOnClose => _desktopAskOnClose;

  bool get desktopKeepRunningOnClose => _desktopKeepRunningOnClose;

  bool get desktopAssistantHotkeyEnabled => _desktopAssistantHotkeyEnabled;

  ThemeMode get themeMode => _appThemeMode;

  /// Whether this phone checks its location against the account's geofences.
  bool get locationTriggersEnabled => _locationTriggersEnabled;

  /// Whether this Android phone forwards other apps' notifications as triggers.
  bool get notificationTriggersEnabled => _notificationTriggersEnabled;

  String? get sessionCookie => _backendClient.sessionCookie;

  BackendClient get backendClient => _backendClient;

  void clearPendingApproval() {
    pendingApproval = null;
    notifyListeners();
  }

  /// Allow or Deny tapped on the approval's notification. Allowing there is
  /// always for this once; wider scopes are chosen in the app.
  Future<void> _resolveApprovalFromNotification(
    String approvalId,
    String decision,
  ) async {
    final request = pendingApproval?.approvalId == approvalId
        ? pendingApproval
        : null;
    unawaited(_AppNotificationService.cancelApprovalNotification(approvalId));
    try {
      await _backendClient.resolveToolApproval(
        backendUrl,
        approvalId: approvalId,
        decision: decision,
        scope: 'once',
        runId: request?.runId,
        toolName: request?.toolName,
        toolArgs: request?.toolArgs,
      );
    } catch (error) {
      AppDiagnostics.log(
        'approvals',
        'notification_resolve.failed',
        error: error,
      );
    }
    if (pendingApproval?.approvalId == approvalId) {
      pendingApproval = null;
      notifyListeners();
    }
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
      ? appStrings.noNetworkConnectionNeoagentWillReconnectWhen
      : appStrings.noNetworkConnectionConnectToKeep;

  String get appUpdateChannelLabel =>
      appUpdateChannel == 'beta' ? 'Beta' : 'Stable';

  String get appUpdateLastCheckedLabel {
    final checkedAt = appUpdateLastCheckedAt;
    if (checkedAt == null) {
      return appStrings.notCheckedYet;
    }
    final local = checkedAt.toLocal();
    final minute = local.minute.toString().padLeft(2, '0');
    return appStrings.arg1Arg2Arg3Arg4Arg5(
      local.year,
      local.month.toString().padLeft(2, '0'),
      local.day.toString().padLeft(2, '0'),
      local.hour.toString().padLeft(2, '0'),
      minute,
    );
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
    final buffer = StringBuffer(appStrings.arg1Arg25(entry.area, entry.event));
    if (entry.data.isNotEmpty) {
      buffer.write(' ${jsonEncode(entry.data)}');
    }
    if (entry.error != null && entry.error!.trim().isNotEmpty) {
      buffer.write(appStrings.errorArg1(entry.error));
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
    await ensureAppLanguageLoaded();
    language = currentAppLanguage;
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
    _appThemeMode = ThemeMode.values.firstWhere(
      (mode) => mode.name == _prefs?.getString('app.themeMode'),
      orElse: () => ThemeMode.system,
    );
    _locationTriggersEnabled =
        _prefs?.getBool('mobile.locationTriggersEnabled') ?? true;
    _notificationTriggersEnabled =
        _prefs?.getBool('mobile.notificationTriggersEnabled') ?? true;
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
      final status = await _authStatusStartingLocalBackend();
      hasUser = status['hasUser'] != false;
      registrationOpen = status['registrationOpen'] == true;
      serviceEmailConfigured =
          (status['email'] is Map &&
          (status['email'] as Map)['configured'] == true);
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

  /// The local runtime is only launched by the installer and by the platform
  /// autostart hook at the next login, so an app launch in between reaches a
  /// backend that is not listening. Start it and retry once instead of
  /// stranding the user on a sign-in screen that cannot reach anything.
  Future<Map<String, dynamic>> _authStatusStartingLocalBackend() async {
    try {
      return await _backendClient.getAuthStatus(backendUrl);
    } on Object {
      if (!await _startLocalBackend()) {
        rethrow;
      }
      return _backendClient.getAuthStatus(backendUrl);
    }
  }

  /// Returns whether the backend this app points at is now running locally.
  Future<bool> _startLocalBackend() async {
    if (!_supportsDesktopShell) {
      return false;
    }
    final target = Uri.tryParse(_normalizeBackendUrl(backendUrl));
    if (target == null) {
      return false;
    }
    try {
      final manager = LocalRuntimeManager();
      final status = await manager.inspect();
      if (!status.installed || status.running) {
        return false;
      }
      final local = Uri.tryParse(_normalizeBackendUrl(status.backendUrl ?? ''));
      if (local == null || !_isSameLoopbackBackend(target, local)) {
        return false;
      }
      final started = await manager.runAction(LocalRuntimeAction.start);
      return started.running;
    } on Object catch (error, stackTrace) {
      AppDiagnostics.log(
        'localRuntime',
        'autostart.failed',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Whether the selected backend is the runtime installed on this computer.
  ///
  /// [runtimeBackendUrl] comes from the local runtime CLI, never from the
  /// network. Both sides must be loopback, so a remote server can never match
  /// this test no matter what address or metadata it reports.
  bool isLocalRuntimeBackend(String? runtimeBackendUrl) {
    final local = Uri.tryParse(_normalizeBackendUrl(runtimeBackendUrl ?? ''));
    final selected = Uri.tryParse(_normalizeBackendUrl(backendUrl));
    if (local == null || selected == null) {
      return false;
    }
    return _isSameLoopbackBackend(selected, local);
  }

  /// The installer and the manual backend field disagree on loopback spelling
  /// (`localhost` vs `127.0.0.1`), so compare the port on loopback hosts.
  bool _isSameLoopbackBackend(Uri left, Uri right) {
    const loopbackHosts = <String>{'localhost', '127.0.0.1', '::1'};
    return loopbackHosts.contains(left.host.toLowerCase()) &&
        loopbackHosts.contains(right.host.toLowerCase()) &&
        left.port == right.port;
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
            appStrings.noNetworkConnectionReconnectToCheck) {
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
          : appStrings.appUpdatesAreNotConfiguredFor;
      if (!silent) {
        notifyListeners();
      }
      return;
    }
    if (!hasNetworkConnection) {
      appUpdateErrorMessage = appStrings.noNetworkConnectionReconnectToCheck;
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
            result.error ?? appStrings.couldNotOpenTheReleaseAsset;
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
          appStrings.localNeoagentDiscoveryIsTemporarilyUnavailable;
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
      errorMessage = appStrings.enterTheAddressOfANeoagent;
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
      _ when kIsWeb => appStrings.webBrowser,
      _ when defaultTargetPlatform == TargetPlatform.android =>
        appStrings.androidApp,
      _ when defaultTargetPlatform == TargetPlatform.iOS =>
        appStrings.iphoneApp,
      _ when defaultTargetPlatform == TargetPlatform.macOS =>
        appStrings.macosApp,
      _ when defaultTargetPlatform == TargetPlatform.windows =>
        appStrings.windowsApp,
      _ when defaultTargetPlatform == TargetPlatform.linux =>
        appStrings.linuxApp,
      _ => appStrings.neoagentApp,
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
      'browserLabel': kIsWeb ? 'Browser' : appStrings.flutterApp,
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
        throw Exception(appStrings.qrLoginCouldNotBeStarted);
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
        retentionErrorMessage: appStrings.qrLoginCompletedButNeoagentCould,
        authMethod: 'qr',
      );
    } catch (error) {
      final message = _friendlyErrorMessage(error);
      qrLoginErrorMessage = message;
      final loweredMessage = message.toLowerCase();
      if (loweredMessage.contains('expired') ||
          loweredMessage.contains('abgelaufen') ||
          loweredMessage.contains(appStrings.alreadyUsed.toLowerCase())) {
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
        throw Exception(appStrings.providerSignInCouldNotBe);
      }
      final launchResult = await _oauthLauncher.launch(
        url: url,
        provider: provider,
      );
      if (!launchResult.launched) {
        throw Exception(
          launchResult.error ?? appStrings.couldNotOpenTheProviderSign,
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
        retentionErrorMessage: appStrings.signInCompletedButNeoagentCould,
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
        retentionErrorMessage: appStrings.twoFactorSignInCompletedBut,
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
          appStrings.ifThatAccountHasAConfirmed;
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
            appStrings.checkYourEmailToConfirmYour;
        await _persistCredentials();
        return;
      }
      await _completeAuthenticatedResponse(
        response,
        fallbackUsername: username,
        isRegistration: register,
        authMethod: 'password',
        retentionErrorMessage: appStrings.signInCompletedButNeoagentCould2,
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
      debugPrint(appStrings.failedToDismissOnboardingArg1(e));
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
    unawaited(BackgroundKeepAlive.stop());
    _disconnectSocket();
    _updatePollTimer?.cancel();
    _updatePollTimer = null;
    _clearQrLoginChallenge();
    isAuthenticated = false;
    isRefreshing = false;
    isSwitchingAgent = false;
    hasLoadedInitialData = false;
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
    accessSummary = null;
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
    systemOneModels = const <ModelMeta>[];
    aiProviders = const <AiProviderMeta>[];
    recentRuns = const <RunSummary>[];
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
    if (selectedSection != section) {
      errorMessage = null;
    }
    selectedSection = section;
    unawaited(_prefs?.setString(_selectedSectionPrefsKey, section.name));
    if (section == AppSection.devices) {
      unawaited(refreshDevices());
    }
    if (section == AppSection.settings) {
      unawaited(refreshAiCatalog());
    }
    notifyListeners();
  }

  /// Opens Settings, on [page] when one is given and otherwise on the page
  /// that was open last.
  void openSettings([SettingsPage? page]) {
    if (page != null) settingsPage = page;
    setSelectedSection(AppSection.settings);
  }

  void setSettingsPage(SettingsPage? page) {
    if (settingsPage == page) return;
    settingsPage = page;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> stopRun(String runId) async {
    try {
      await _backendClient.abortAgentRun(backendUrl, runId);
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
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
    isSwitchingAgent = true;
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
    // A later switch owns the flag until its own refresh lands.
    if (selectedAgentId == id && isSwitchingAgent) {
      isSwitchingAgent = false;
      notifyListeners();
    }
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

  void clearInlineError() {
    if (errorMessage == null) return;
    errorMessage = null;
    notifyListeners();
  }

  Future<Map<String, dynamic>> _pollForProviderAuthCompletion(
    String state,
  ) async {
    final deadline = DateTime.now().add(const Duration(minutes: 2));
    final authCycle = _authCycle;
    while (DateTime.now().isBefore(deadline)) {
      if (!isAuthenticating || _authCycle != authCycle) {
        throw Exception(appStrings.authenticationWasCanceledBeforeCompletion);
      }
      final response = await _backendClient.completeProviderAuth(
        baseUrl: backendUrl,
        state: state,
      );
      if (response['status']?.toString() == 'pending') {
        if (!isAuthenticating || _authCycle != authCycle) {
          throw Exception(appStrings.authenticationWasCanceledBeforeCompletion);
        }
        await Future<void>.delayed(const Duration(seconds: 2));
        continue;
      }
      return response;
    }
    throw Exception(appStrings.authenticationIsStillPendingFinishThe);
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

  Future<List<BehaviorDecisionEntry>> loadBehaviorDecisions(
    String platform,
  ) async {
    final data = await _backendClient.fetchBehaviorDecisions(
      backendUrl,
      platform: platform,
      agentId: _scopedAgentId,
    );
    final items = data['decisions'] is List
        ? data['decisions'] as List
        : const <dynamic>[];
    return items
        .whereType<Map>()
        .map(
          (item) =>
              BehaviorDecisionEntry.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
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

  /// Switches the interface immediately, remembers the choice on this device,
  /// and, once signed in, saves it on the account so the next device follows.
  Future<void> setLanguage(AppLanguage value) async {
    if (value == language) return;
    _languageRevision += 1;
    final revision = _languageRevision;
    language = value;
    currentAppLanguage = value;
    notifyListeners();
    final preferences = _prefs ?? await SharedPreferences.getInstance();
    _prefs = preferences;
    await preferences.setString(appLanguagePreferenceKey, value.code);
    if (revision != _languageRevision || !isAuthenticated) return;
    if (backendUrl.trim().isEmpty) return;
    try {
      await _backendClient.saveSettings(backendUrl, <String, dynamic>{
        'ui_language': value.code,
      });
      if (revision != _languageRevision) return;
      settings = <String, dynamic>{...settings, 'ui_language': value.code};
    } catch (_) {
      // The interface is already in the new language and the choice is stored
      // on this device. The next settings read will try the account again.
    }
  }

  /// An account that has chosen a language is authoritative, so the choice
  /// follows somebody to a second device. An account that has never chosen
  /// adopts what this device detected at first launch.
  void _reconcileLanguage(int revision) {
    if (revision != _languageRevision || !isAuthenticated) return;
    final stored = AppLanguage.fromCode(settings['ui_language']?.toString());
    if (stored == null) {
      settings = <String, dynamic>{...settings, 'ui_language': language.code};
      unawaited(
        _backendClient
            .saveSettings(backendUrl, <String, dynamic>{
              'ui_language': language.code,
            })
            .catchError((Object _) => <String, dynamic>{}),
      );
      return;
    }
    if (stored == language) return;
    language = stored;
    currentAppLanguage = stored;
    unawaited(_rememberLanguage(stored.code));
  }

  Future<void> _rememberLanguage(String code) async {
    final preferences = _prefs ?? await SharedPreferences.getInstance();
    _prefs = preferences;
    await preferences.setString(appLanguagePreferenceKey, code);
  }

  Future<void> refresh() async {
    if (!isAuthenticated) {
      return;
    }

    final authCycle = _authCycle;
    final languageRevision = _languageRevision;
    final refreshSeq = ++_refreshSeq;
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
          errorMessage = appStrings.yourSessionExpiredOrWasNot;
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
      final systemOneModelsFuture = _softRefreshLoad<Map<String, dynamic>>(
        'system_one_models',
        _backendClient.fetchSystemOneModels(backendUrl, agentId: agentId),
        const <String, dynamic>{'models': <dynamic>[]},
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
      if (!_isCurrentRefreshScope(authCycle, agentId)) {
        return;
      }

      final officialIntegrationsResponse = await officialIntegrationsFuture;
      if (!_isCurrentRefreshScope(authCycle, agentId)) {
        return;
      }
      officialIntegrations = _decodeModelList(
        'official_integrations',
        officialIntegrationsResponse,
        OfficialIntegrationItem.fromJson,
      );

      final history = await historyFuture;
      final modelsResponse = await modelsFuture;
      final providersResponse = await providersFuture;
      final systemOneModelsResponse = await systemOneModelsFuture;
      final settingsResponse = await settingsFuture;
      final behaviorResponse = await behaviorFuture;
      final runsResponse = await runsFuture;
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
      if (!_isCurrentRefreshScope(authCycle, agentId)) {
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
      systemOneModels = _decodeModelList(
        'system_one_models',
        systemOneModelsResponse['models'],
        ModelMeta.fromJson,
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
        _reconcileLanguage(languageRevision);
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
      versionInfo = versionResponse;
      _applySetupProgress(setupStatusResponse);
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
      unawaited(_syncDeviceTimeZone());
      _ensureSocketConnected();
      _ensureUpdatePolling();
    } catch (error) {
      if (_isCurrentAuthCycle(authCycle)) {
        errorMessage = _friendlyErrorMessage(error);
      }
    } finally {
      isRefreshing = false;
      // An older refresh that bailed out for a stale agent has applied
      // nothing; the newest one decides when the first load is done.
      if (refreshSeq == _refreshSeq && _isCurrentAuthCycle(authCycle)) {
        hasLoadedInitialData = true;
      }
      notifyListeners();
    }
  }

  /// Whether [section] has no real data to show yet: nothing has loaded since
  /// sign-in, or a bot switch emptied that bot's lists.
  bool isAwaitingDataFor(AppSection section) =>
      !hasLoadedInitialData || (isSwitchingAgent && section.isAgentScoped);

  bool _isCurrentAuthCycle(int authCycle) =>
      isAuthenticated && _authCycle == authCycle;

  /// A refresh loads everything for the agent selected when it started. Startup
  /// restores the persisted agent while an earlier refresh is still in flight,
  /// so without this the older response can land last and show the selected
  /// agent another agent's integrations, chats and memory.
  bool _isCurrentRefreshScope(int authCycle, String? agentId) =>
      _isCurrentAuthCycle(authCycle) && agentId == _scopedAgentId;

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
    final agentId = _scopedAgentId;
    try {
      final runsResponse = await _backendClient.fetchRuns(
        backendUrl,
        agentId: agentId,
      );
      // A poll started before a bot switch must not land the old bot's runs.
      if (agentId != _scopedAgentId) return;
      recentRuns = _decodeModelList(
        'runs',
        runsResponse['runs'],
        RunSummary.fromJson,
        fallbackToMapValues: true,
      );
      _runDetailsCache.clear();
      runsRefreshedAt = DateTime.now();
      final usage = await _backendClient.fetchTokenUsageSummary(
        backendUrl,
        agentId: agentId,
      );
      if (agentId != _scopedAgentId) return;
      tokenUsage = TokenUsageSnapshot.fromJson(usage);
      notifyListeners();
    } catch (_) {}
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

  Future<MemoryGraph> fetchMemoryGraph({required int limit}) async {
    return MemoryGraph.fromJson(
      await _backendClient.fetchMemoryGraph(
        backendUrl,
        limit: limit,
        agentId: _scopedAgentId,
      ),
    );
  }

  Future<List<MemoryItem>> fetchEntityMemories(String entityId) async {
    return _decodeModelList(
      'entity_memories',
      await _backendClient.fetchEntityMemories(
        backendUrl,
        entityId,
        agentId: _scopedAgentId,
      ),
      MemoryItem.fromJson,
    );
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

  Future<List<OfficialIntegrationItem>> fetchOfficialIntegrationsForAgent(
    String? agentId,
  ) async {
    return _decodeModelList(
      'official_integrations',
      await _backendClient.fetchOfficialIntegrations(
        backendUrl,
        agentId: agentId ?? _scopedAgentId,
      ),
      OfficialIntegrationItem.fromJson,
    );
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
      errorMessage = appStrings.localComputerControlIsAvailableIn;
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
      if (!interruptAgent && (computerDisplayUrl?.trim().isNotEmpty ?? false)) {
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
          deviceTarget: deviceTarget,
        ),
        deviceTarget: deviceTarget,
      );
      final stdout = result['stdout']?.toString() ?? '';
      final stderr = result['stderr']?.toString() ?? '';
      final exitCode = result['exitCode'];
      computerTerminalOutput = <String>[
        appStrings.arg13(normalized),
        if (stdout.isNotEmpty) stdout.trimRight(),
        if (stderr.isNotEmpty) stderr.trimRight(),
        if (exitCode != null) appStrings.exitArg1(exitCode),
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
      errorMessage =
          result.error ?? appStrings.couldNotOpenWorkspaceFileDownload;
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

  Future<void> setThemeMode(ThemeMode mode) async {
    _appThemeMode = mode;
    await _prefs?.setString('app.themeMode', mode.name);
    notifyListeners();
  }

  Future<void> setLocationTriggersEnabled(bool value) async {
    _locationTriggersEnabled = value;
    await _prefs?.setBool('mobile.locationTriggersEnabled', value);
    notifyListeners();
  }

  Future<void> setNotificationTriggersEnabled(bool value) async {
    _notificationTriggersEnabled = value;
    await _prefs?.setBool('mobile.notificationTriggersEnabled', value);
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
      throw StateError(appStrings.liveVoiceConnectionIsNotAvailable);
    }
    final completer = Completer<void>();
    _liveVoiceSessionOpenCompleter = completer;
    if (!_liveVoiceTelecomRouting) {
      try {
        _liveVoiceTelecomRouting = await AndroidAutoBridge.instance
            .startTelecomCallRouting();
      } catch (_) {
        // Call routing is an Android nicety; the session works without it.
      }
    }
    voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
      state: 'connecting',
      clearError: true,
    );
    notifyListeners();
    _socket!.emit('voice:session_open', <String, dynamic>{
      'agentId': _scopedAgentId,
      if (voiceAssistantLiveState.sessionId.trim().isNotEmpty)
        'sessionId': voiceAssistantLiveState.sessionId.trim(),
    });
    try {
      await completer.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw StateError(appStrings.theLiveVoiceModelDidNot);
        },
      );
    } catch (error) {
      await _stopLiveVoiceTelecomRouting();
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        state: 'idle',
        error: _friendlyErrorMessage(error),
      );
      notifyListeners();
      rethrow;
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
    lastEndedCall = null;
    unawaited(CallBridge.stopRinging());
    unawaited(
      _AppNotificationService.cancelIncomingCallNotification(call.callId),
    );
    _socket!.emit('voice:call_accept', <String, dynamic>{
      'callId': call.callId,
    });
    notifyListeners();
  }

  /// With [later] the agent hears that the user wants a call back.
  void declineIncomingAgentCall({bool later = false}) {
    final call = incomingAgentCall;
    if (call == null) return;
    if (call.accepting) _abandonedCallId = call.callId;
    _socket?.emit('voice:call_decline', <String, dynamic>{
      'callId': call.callId,
      if (later) 'later': true,
    });
    _clearIncomingAgentCall(call.callId);
    notifyListeners();
  }

  void _clearIncomingAgentCall(String? callId, {bool sessionStarted = false}) {
    final current = incomingAgentCall;
    if (current == null || (callId != null && current.callId != callId)) return;
    _incomingCallExpiryTimer?.cancel();
    _incomingCallExpiryTimer = null;
    incomingAgentCall = null;
    cancelIncomingCallBrowserAlert(current.callId);
    unawaited(
      _AppNotificationService.cancelIncomingCallNotification(current.callId),
    );
    // A started call keeps the screen over the lock screen until it ends.
    if (!sessionStarted) _releaseCallPresentation();
  }

  Future<void> _ringIncomingAgentCall(IncomingAgentCall call) async {
    showIncomingCallBrowserAlert(call.callId, call.agentName);
    if (_supportsDesktopShell) {
      unawaited(windowManager.show());
      unawaited(windowManager.focus());
    }
    unawaited(CallBridge.startRinging());
    unawaited(_AppNotificationService.showIncomingCallNotification(call));
    final broughtForward = await CallBridge.present();
    if (incomingAgentCall?.callId == call.callId) {
      _callBroughtAppForward = _callBroughtAppForward || broughtForward;
    } else if (broughtForward) {
      // The call ended while the app was coming forward.
      unawaited(CallBridge.dismiss(moveToBack: true));
    }
  }

  void _releaseCallPresentation() {
    final moveToBack = _callBroughtAppForward;
    _callBroughtAppForward = false;
    unawaited(CallBridge.dismiss(moveToBack: moveToBack));
  }

  void _handleCallNotificationAction(String callId, String action) {
    if (incomingAgentCall?.callId != callId) return;
    if (action == _AppNotificationService.callAnswerActionId) {
      acceptIncomingAgentCall();
    } else if (action == _AppNotificationService.callDeclineActionId) {
      declineIncomingAgentCall();
      notifyListeners();
    }
  }

  /// The name on the call screen: the agent that is calling, or the one the
  /// call is with.
  String get callAgentName {
    final ringing = incomingAgentCall?.agentName.trim() ?? '';
    if (ringing.isNotEmpty) return ringing;
    final active = activeAgent?.displayName.trim() ?? '';
    return active.isNotEmpty ? active : 'NeoAgent';
  }

  Future<void> toggleCallSpeakerphone() async {
    callSpeakerphoneOn = !callSpeakerphoneOn;
    notifyListeners();
    await CallBridge.setSpeakerphone(callSpeakerphoneOn);
  }

  void dismissCallRecap() {
    if (lastEndedCall == null) return;
    lastEndedCall = null;
    notifyListeners();
  }

  // The microphone streams straight to the live model, which decides when a
  // turn ends; there is nothing to buffer or commit on the client.
  Future<void> startLiveVoiceCapture() async {
    if (_isStartingLiveVoice || _liveVoiceCaptureActive) {
      return;
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
    // Browsers only let audio start from a user gesture, so the player comes
    // up with the press, before the session answers. Both live providers
    // speak 24 kHz PCM.
    unawaited(
      _liveVoicePlayer.start(sampleRate: 24000).catchError((Object error) {
        AppDiagnostics.log('voice', 'playback.start_failed', error: error);
      }),
    );
    try {
      await ensureLiveVoiceSession();
      final sessionId = voiceAssistantLiveState.sessionId.trim();
      if (!voiceAssistantLiveState.isHandsFree) {
        // Talking over the assistant stops it right away.
        await _liveVoicePlayer.flush();
      }
      _socket?.emit('voice:input_start', <String, dynamic>{
        'sessionId': sessionId,
      });
      await _liveVoiceCapture.start(
        sampleRate: voiceAssistantLiveState.inputSampleRate,
        onChunk: _sendLiveVoiceAudio,
        onError: (Object error, StackTrace stackTrace) {
          AppDiagnostics.log(
            'desktop.assistant',
            'ptt.capture_error',
            error: error,
            stackTrace: stackTrace,
          );
          _handleLiveVoiceCaptureLost(_friendlyErrorMessage(error));
        },
        onStoppedUnexpectedly: () => _handleLiveVoiceCaptureLost(
          appStrings.microphoneCaptureStoppedUnexpectedlyTryAgain,
        ),
      );
      _liveVoiceCaptureActive = true;
      AppDiagnostics.log(
        'desktop.assistant',
        'ptt.capture_started',
        data: <String, Object?>{
          'sessionId': voiceAssistantLiveState.sessionId.trim(),
        },
      );
      if (_pendingLiveVoiceStop) {
        _pendingLiveVoiceStop = false;
        await stopLiveVoiceCapture();
      }
    } catch (error) {
      // A denied or missing microphone must be visible, not look like mute.
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        error: _friendlyErrorMessage(error),
      );
      rethrow;
    } finally {
      _isStartingLiveVoice = false;
      notifyListeners();
    }
  }

  void _sendLiveVoiceAudio(Uint8List chunk) {
    final socket = _socket;
    final sessionId = voiceAssistantLiveState.sessionId.trim();
    if (socket == null || !socketConnected || sessionId.isEmpty) {
      return;
    }
    socket.emit('voice:audio', <String, dynamic>{
      'sessionId': sessionId,
      'audioBase64': base64Encode(chunk),
    });
  }

  void _handleLiveVoiceCaptureLost(String message) {
    if (!_liveVoiceCaptureActive && !_isStartingLiveVoice) {
      return;
    }
    _liveVoiceCaptureActive = false;
    voiceAssistantLiveState = voiceAssistantLiveState.copyWith(error: message);
    notifyListeners();
  }

  Future<void> _stopLiveVoiceTelecomRouting() async {
    if (!_liveVoiceTelecomRouting) return;
    _liveVoiceTelecomRouting = false;
    await AndroidAutoBridge.instance.stopTelecomCallRouting();
  }

  Future<void> toggleLiveVoiceCapture() async {
    if (isLiveVoiceCaptureEngaged) {
      await stopLiveVoiceCapture();
      return;
    }
    await startLiveVoiceCapture();
  }

  /// Push-to-talk release, or muting a hands-free call.
  Future<void> stopLiveVoiceCapture() async {
    if (_isStartingLiveVoice && !_liveVoiceCaptureActive) {
      _pendingLiveVoiceStop = true;
      return;
    }
    if (!_liveVoiceCaptureActive) {
      return;
    }
    _liveVoiceCaptureActive = false;
    await _liveVoiceCapture.stop();
    final sessionId = voiceAssistantLiveState.sessionId.trim();
    if (sessionId.isNotEmpty) {
      _socket?.emit('voice:input_end', <String, dynamic>{
        'sessionId': sessionId,
      });
    }
    AppDiagnostics.log('desktop.assistant', 'ptt.capture_stopped');
    notifyListeners();
  }

  /// Silences the assistant and the microphone (Android Auto stop, desktop
  /// popup cancel).
  Future<void> interruptLiveVoiceAssistant() async {
    await stopLiveVoiceCapture();
    await stopLiveVoicePlayback();
  }

  Future<void> stopLiveVoicePlayback() async {
    final sessionId = voiceAssistantLiveState.sessionId.trim();
    if (sessionId.isEmpty || _socket == null) return;
    await _liveVoicePlayer.flush();
    _socket!.emit('voice:interrupt', <String, dynamic>{'sessionId': sessionId});
  }

  Future<void> cancelLiveVoiceTask() async {
    final sessionId = voiceAssistantLiveState.sessionId.trim();
    if (sessionId.isEmpty || _socket == null) return;
    _socket!.emit('voice:cancel_task', <String, dynamic>{
      'sessionId': sessionId,
    });
  }

  /// Keyboard clicks fill the quiet while a handed-off task runs. Speech,
  /// reconnecting, and an idle call stay silent.
  void _syncVoiceWorkClicks() {
    final play =
        !_liveVoiceHearingSpeech && voiceAssistantLiveState.isWorkingSilently;
    if (!play) {
      _haltVoiceWorkClicks();
      return;
    }
    if (_voiceWorkClicks?.isPlaying == true) return;
    _voiceWorkClickArm?.cancel();
    _voiceWorkClickArm = Timer(const Duration(milliseconds: 180), () {
      _voiceWorkClickArm = null;
      if (_liveVoiceHearingSpeech ||
          !voiceAssistantLiveState.isWorkingSilently) {
        return;
      }
      unawaited(_ensureVoiceWorkClicks());
    });
  }

  Future<void> _ensureVoiceWorkClicks() async {
    final generation = ++_voiceWorkClickGeneration;
    if (_liveVoiceHearingSpeech || !voiceAssistantLiveState.isWorkingSilently) {
      return;
    }
    final List<Uint8List> clicks;
    try {
      final cached = _voiceKeyClickPcm;
      if (cached != null) {
        clicks = cached;
      } else {
        clicks = <Uint8List>[
          for (final asset in voiceWorkTypingAssets)
            voiceWorkTypingFromWav(await _loadAssetBytes(asset)),
        ];
        _voiceKeyClickPcm = clicks;
      }
      await _liveVoicePlayer.prepareWorkClicks(clicks);
    } catch (error, stackTrace) {
      AppDiagnostics.log(
        'voice',
        'work_clicks.unavailable',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }
    if (generation != _voiceWorkClickGeneration ||
        _liveVoiceHearingSpeech ||
        !voiceAssistantLiveState.isWorkingSilently) {
      return;
    }
    final sampleRate = voiceAssistantLiveState.outputSampleRate;
    final existing = _voiceWorkClicks;
    if (existing == null || existing.sampleRate != sampleRate) {
      existing?.dispose();
      _voiceWorkClicks = VoiceWorkClicks(
        sampleRate: sampleRate,
        clicks: clicks,
      );
    }
    _voiceWorkClicks!.start(_liveVoicePlayer.addWorkClick);
  }

  static Future<Uint8List> _loadAssetBytes(String asset) async {
    final data = await rootBundle.load(asset);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  void _haltVoiceWorkClicks() {
    _voiceWorkClickArm?.cancel();
    _voiceWorkClickArm = null;
    _voiceWorkClickGeneration++;
    _voiceWorkClicks?.stop();
    unawaited(_liveVoicePlayer.stopWorkClicks());
  }

  /// The state resets before the async teardown, so an error that arrives
  /// meanwhile (a failed connect reports closed, then why) is not wiped.
  /// [error] keeps the reason a server-ended call stopped on screen.
  Future<void> closeLiveVoiceSession({
    bool cancelTask = false,
    String? error,
  }) async {
    final sessionId = voiceAssistantLiveState.sessionId.trim();
    final startedAt = _liveVoiceSessionStartedAt;
    if (startedAt != null) {
      final request = voiceAssistantLiveState.activeTaskRequest.trim();
      lastEndedCall = EndedAgentCall(
        agentName: callAgentName,
        duration: DateTime.now().difference(startedAt),
        backgroundTask: voiceAssistantLiveState.hasActiveTask && !cancelTask
            ? request
            : null,
      );
    }
    if (callSpeakerphoneOn) {
      callSpeakerphoneOn = false;
      unawaited(CallBridge.setSpeakerphone(false));
    }
    _callBroughtAppForward = false;
    unawaited(CallBridge.dismiss());
    _liveVoiceHearingSpeech = false;
    _haltVoiceWorkClicks();
    _liveVoiceCaptureActive = false;
    _pendingLiveVoiceStop = false;
    _returnHomeAfterCall = false;
    _liveVoiceSessionStartedAt = null;
    voiceAssistantLiveState = VoiceAssistantLiveState(error: error);
    notifyListeners();
    if (sessionId.isNotEmpty) {
      _socket?.emit('voice:session_close', <String, dynamic>{
        'sessionId': sessionId,
        'cancelTask': cancelTask,
      });
    }
    await _liveVoiceCapture.stop();
    await _liveVoicePlayer.stop();
    await _stopLiveVoiceTelecomRouting();
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

  /// Transcripts stream in as growing partials of the current speaker's turn;
  /// a final one closes the turn and joins the chat like a typed message.
  void _applyLiveVoiceTranscript(Map<String, dynamic> payload) {
    final role = payload['role']?.toString() == 'assistant'
        ? 'assistant'
        : 'user';
    final content = payload['content']?.toString().trim() ?? '';
    if (content.isEmpty) return;
    final isFinal = payload['final'] == true;
    final timeline = voiceAssistantLiveState.timeline.toList(growable: true);
    final last = timeline.isEmpty ? null : timeline.last;
    if (last != null && last.role == role && !last.isFinal) {
      timeline[timeline.length - 1] = last.copyWith(
        content: content,
        isFinal: isFinal,
      );
    } else {
      timeline.add(
        VoiceTimelineItem(
          id: '${voiceAssistantLiveState.sessionId}:${DateTime.now().microsecondsSinceEpoch}',
          role: role,
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
    );
    if (isFinal) {
      _appendChatMessage(content, role: role, platform: 'voice_live');
    }
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

  Future<List<RunPromptTurn>> fetchRunPromptTurns(String runId) async {
    final response = await _backendClient.fetchRunPromptTurns(
      backendUrl,
      runId,
    );
    final turns = response['turns'];
    if (turns is! List) {
      return const <RunPromptTurn>[];
    }
    return turns
        .whereType<Map<dynamic, dynamic>>()
        .map(RunPromptTurn.fromJson)
        .toList();
  }

  Future<RunPromptSnapshot> fetchRunPrompt(
    String runId,
    String requestId,
  ) async {
    return RunPromptSnapshot.fromJson(
      await _backendClient.fetchRunPrompt(backendUrl, runId, requestId),
    );
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

  /// Merges [patch] into this agent's behavior config and saves it. The change
  /// shows at once; a failed save restores the previous config.
  Future<void> updateBehaviorConfig(Map<String, dynamic> patch) async {
    final previous = behaviorConfig;
    behaviorConfig = <String, dynamic>{...behaviorConfig, ...patch};
    await saveBehaviorConfig(behaviorConfig);
    if (errorMessage != null) {
      behaviorConfig = previous;
      notifyListeners();
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

  void _applySetupProgress(Object? raw) {
    if (raw is! Map) return;
    final setup = Map<String, dynamic>.from(raw);
    setupProfile = setup['profile']?.toString() == 'full' ? 'full' : 'quick';
    setupComplete = setup['complete'] != false;
    setupOpenSections = (setup['openSections'] as List? ?? const [])
        .map((section) => section.toString())
        .where((section) => section.isNotEmpty)
        .toList(growable: false);
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
      final systemOneModelsResponse = await _backendClient.fetchSystemOneModels(
        backendUrl,
        agentId: agentId,
      );
      supportedModels = _decodeModelList(
        'supported_models',
        modelsResponse['models'],
        ModelMeta.fromJson,
        fallbackToMapValues: true,
      );
      systemOneModels = _decodeModelList(
        'system_one_models',
        systemOneModelsResponse['models'],
        ModelMeta.fromJson,
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

  // ── Delegated access (managed / managing accounts) ───────────────────────

  Future<void> refreshAccess() async {
    if (!isAuthenticated) return;
    isLoadingAccess = true;
    notifyListeners();
    try {
      _applyAccessSummary(await _backendClient.fetchDelegation(backendUrl));
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isLoadingAccess = false;
      notifyListeners();
    }
  }

  void _applyAccessSummary(Map<String, dynamic> json) {
    final summary = AccessSummary.fromJson(json);
    accessSummary = summary;
    // Admin is granted and revoked from the operator side; keep the Admin tab
    // in step with what the server just said.
    final current = user;
    if (current != null && (current['isAdmin'] == true) != summary.isAdmin) {
      user = <String, dynamic>{...current, 'isAdmin': summary.isAdmin};
    }
  }

  Future<bool> _changeAccess(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    errorMessage = null;
    try {
      _applyAccessSummary(await request());
      return true;
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      return false;
    } finally {
      notifyListeners();
    }
  }

  /// Throws [BackendException] carrying the server's reason (expired, revoked,
  /// already used, ...) so the confirmation dialog can show it.
  Future<DelegationInvitePreview> previewDelegationInvite(String link) async {
    return DelegationInvitePreview.fromJson(
      await _backendClient.previewDelegationInvite(backendUrl, link),
    );
  }

  /// Throws like [previewDelegationInvite]: the link can change between the
  /// preview and the confirmation.
  Future<void> redeemDelegationInvite(String link) async {
    _applyAccessSummary(
      await _backendClient.redeemDelegationInvite(backendUrl, link),
    );
    notifyListeners();
  }

  Future<bool> leaveManager() {
    return _changeAccess(() => _backendClient.leaveDelegation(backendUrl));
  }

  /// Returns the shareable link. Throws on failure so the dialog stays open
  /// with the reason.
  Future<String> createDelegationInvite({
    required String label,
    required List<String> permissions,
    required int? expiresInHours,
    required bool singleUse,
  }) async {
    final response = await _backendClient.createDelegationInvite(
      backendUrl,
      label: label,
      permissions: permissions,
      expiresInHours: expiresInHours,
      singleUse: singleUse,
    );
    unawaited(refreshAccess());
    return response['link']?.toString() ?? '';
  }

  Future<bool> revokeDelegationInvite(String inviteId) {
    return _changeAccess(
      () => _backendClient.revokeDelegationInvite(backendUrl, inviteId),
    );
  }

  Future<bool> releaseManagedAccount(int userId) {
    return _changeAccess(
      () => _backendClient.releaseManagedAccount(backendUrl, userId),
    );
  }

  Future<bool> setManagedPermission(int userId, String key, bool allowed) {
    return _changeAccess(
      () => _backendClient.setManagedPermission(
        backendUrl,
        userId: userId,
        permission: key,
        allowed: allowed,
      ),
    );
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
        throw Exception(appStrings.providerLinkingCouldNotBeStarted);
      }
      final launchResult = await _oauthLauncher.launch(
        url: url,
        provider: provider,
      );
      if (!launchResult.launched) {
        throw Exception(
          launchResult.error ?? appStrings.couldNotOpenTheProviderLinking,
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
        throw Exception(appStrings.theSecurityKeyRegistrationCouldNot);
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
        throw Exception(appStrings.securityKeySignInCouldNot);
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
        retentionErrorMessage: appStrings.securityKeySignInCompletedBut,
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
        throw Exception(appStrings.officialIntegrationDidNotReturnA);
      }

      final launchResult = await _oauthLauncher.launch(
        url: url,
        provider: providerId,
        // NeoRecall (and other providers) may require 2FA before consent.
        timeout: const Duration(minutes: 5),
      );
      if (!launchResult.launched) {
        throw Exception(
          launchResult.error ?? appStrings.failedToLaunchOauthFlow,
        );
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

    throw Exception(appStrings.authenticationIsStillPendingFinishThe2);
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

  /// Connects a messaging platform that signs in through an official
  /// integration. The integration's own OAuth flow runs first when this
  /// agent has not connected that app yet; the platform then starts on it.
  Future<void> connectIntegrationMessagingPlatform(
    MessagingPlatformDescriptor platform,
  ) async {
    final providerId = platform.integrationProvider!;
    final appId = platform.integrationApp!;
    await refreshSkills();
    if (_findOfficialIntegrationApp(providerId, appId)?.isConnected != true) {
      await connectOfficialIntegration(providerId, appId: appId);
      final failure = errorMessage;
      if (failure != null) throw Exception(failure);
      if (_findOfficialIntegrationApp(providerId, appId)?.isConnected != true) {
        throw Exception(appStrings.finishSigningInToArg1In(platform.label));
      }
    }
    await connectMessagingPlatform(platform: platform.id);
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

  Future<String?> deviceTimeZone() async {
    try {
      final zone = (await FlutterTimezone.getLocalTimezone()).identifier.trim();
      return zone.isEmpty ? null : zone;
    } catch (error) {
      debugPrint(appStrings.timezoneCouldNotReadTheDevice(error));
      return null;
    }
  }

  // Adopts the device zone when the user has none yet, or while they follow
  // whichever device they are using. Runs in the background, so a failure is
  // logged instead of shown.
  Future<void> _syncDeviceTimeZone() async {
    if (!timeZoneFollowsDevice && timeZone.isNotEmpty) return;
    final zone = await deviceTimeZone();
    if (zone == null || zone == timeZone) return;
    final agentId = _scopedAgentId;
    try {
      await _queueSettingsWrite(<String, dynamic>{
        'timezone': zone,
      }, agentId: agentId);
      settings = <String, dynamic>{...settings, 'timezone': zone};
      notifyListeners();
    } catch (error) {
      debugPrint(appStrings.timezoneCouldNotSaveTheDevice(error));
    }
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

  Future<void> refreshByokProviders() async {
    isLoadingByokProviders = true;
    notifyListeners();
    try {
      final response = await _backendClient.fetchByokProviders(
        backendUrl,
        agentId: _scopedAgentId,
      );
      final raw = response['providers'];
      byokProviders = raw is List
          ? raw.whereType<Map>().map(Map<String, dynamic>.from).toList()
          : const <Map<String, dynamic>>[];
    } catch (_) {
      // Keep whatever list is already in memory.
    } finally {
      isLoadingByokProviders = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> saveByokProvider(
    String providerId, {
    required String apiKey,
    String? baseUrl,
    String? label,
  }) async {
    final response = await _backendClient.saveByokProvider(
      backendUrl,
      providerId,
      apiKey: apiKey,
      baseUrlOverride: baseUrl,
      label: label,
      agentId: _scopedAgentId,
    );
    await refreshByokProviders();
    await refreshAiCatalog();
    return response;
  }

  Future<Map<String, dynamic>> clearByokProvider(String providerId) async {
    final response = await _backendClient.clearByokProvider(
      backendUrl,
      providerId,
      agentId: _scopedAgentId,
    );
    await refreshByokProviders();
    await refreshAiCatalog();
    return response;
  }

  Future<Map<String, dynamic>> testByokProvider(
    String providerId, {
    String? apiKey,
    String? baseUrl,
  }) async {
    return _backendClient.testByokProvider(
      backendUrl,
      providerId,
      apiKey: apiKey,
      baseUrlOverride: baseUrl,
      agentId: _scopedAgentId,
    );
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
      'summary': response['summary']?.toString() ?? appStrings.whoCanMessage,
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

  TaskRecommendationStatus taskRecommendationStatus(
    TaskRecommendation recommendation,
  ) {
    if (_addingTaskRecommendations.contains(recommendation.title)) {
      return TaskRecommendationStatus.adding;
    }
    final exists = taskItems.any((task) => task.name == recommendation.title);
    return exists
        ? TaskRecommendationStatus.added
        : TaskRecommendationStatus.idle;
  }

  Future<void> addRecommendedTask(TaskRecommendation recommendation) async {
    if (!_addingTaskRecommendations.add(recommendation.title)) return;
    notifyListeners();
    try {
      await saveTask(
        name: recommendation.title,
        triggerType: 'schedule',
        triggerConfig: <String, dynamic>{
          'mode': 'recurring',
          'cronExpression': recommendation.cronExpression,
          'finishOnTime': false,
        },
        prompt: recommendation.prompt,
      );
    } finally {
      _addingTaskRecommendations.remove(recommendation.title);
      notifyListeners();
    }
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
          return appStrings.arg1Arg2LocalUriArg3(item.name, type, item.uri);
        })
        .join('\n');
    final attachmentBlock = [
      appStrings.sharedAttachmentsFromTheNeoagentClient,
      lines,
      appStrings.useTheseForContextIfA,
    ].join('\n');
    if (base.isEmpty) {
      return attachmentBlock;
    }
    return '$base\n\n$attachmentBlock';
  }

  void openVoiceAssistantSurface() {
    setSelectedSection(AppSection.voiceAssistant);
  }

  /// A call asked for from outside the app (the home-screen call widget).
  /// It starts the way the call button does, once signed in and connected:
  /// a cold start has neither yet, so the socket connecting picks it up.
  /// Hanging up then returns to the home screen, as a phone call does.
  void requestVoiceCall() {
    openVoiceAssistantSurface();
    if (voiceAssistantLiveState.hasActiveSession) return;
    _voiceCallRequested = true;
    _returnHomeAfterCall = true;
    _startRequestedVoiceCall();
  }

  void _startRequestedVoiceCall() {
    if (!_voiceCallRequested || !isAuthenticated || !socketConnected) return;
    _voiceCallRequested = false;
    unawaited(
      startVoiceCall().catchError((Object error) {
        // The controller records the error on the live state, which stays on
        // screen rather than leaving the app.
        _returnHomeAfterCall = false;
        AppDiagnostics.log('voice', 'requested_call.failed', error: error);
      }),
    );
  }

  /// Places a call the way the configured input mode expects: hands-free
  /// opens the microphone at once, push-to-talk waits for the first hold.
  Future<void> startVoiceCall() {
    lastEndedCall = null;
    return voiceInputMode == 'hands_free'
        ? startLiveVoiceCapture()
        : ensureLiveVoiceSession();
  }

  /// The user hanging up.
  Future<void> hangUpVoiceCall({bool cancelTask = false}) async {
    final returnHome = _returnHomeAfterCall;
    await closeLiveVoiceSession(cancelTask: cancelTask);
    if (returnHome) {
      await _homeWidgetBridge.returnToHomeScreen();
    }
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
        throw HealthBridgeException(appStrings.healthConnectIsNotAvailableOn);
      }
      if (!deviceStatus.permissionsGranted) {
        throw HealthBridgeException(
          appStrings.grantHealthConnectPermissionsBeforeSyncing,
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
      return appStrings.theComputerNeedsMoreFreeDisk;
    }
    if (backendCode == 'COMPUTER_CAPACITY') {
      return appStrings.allCloudComputerSlotsAreCurrently;
    }
    if (backendCode == 'COMPUTER_RUNTIME_UNAVAILABLE' ||
        backendCode == 'COMPUTER_FIRMWARE_MISSING') {
      return appStrings.theComputerRuntimeNeedsRepairRun;
    }

    if (backendStatusCode == 402) {
      final details = _extractMeaningfulErrorDetails(text);
      if (lower.contains('invalid credentials')) {
        return appStrings.theNeoagentDeploymentRespondedWithHttp;
      }
      if (details.isNotEmpty &&
          details.toLowerCase() !=
              'request failed with http $backendStatusCode') {
        return appStrings.theNeoagentDeploymentRespondedWithHttp2(details);
      }
      return appStrings.theNeoagentDeploymentRespondedWithHttp3;
    }

    if (lower.contains('invalid credentials')) {
      return appStrings.yourUsernameOrPasswordIsIncorrect;
    }
    if (lower.contains('registration is closed')) {
      return appStrings.thisServerIsAlreadySetUp;
    }
    if (lower.contains('too many attempts')) {
      return appStrings.tooManySignInAttemptsPlease;
    }
    if (lower.contains('qr login request was not found') ||
        lower.contains('qr login request has expired') ||
        lower.contains('this qr login request has expired')) {
      return appStrings.thisQrLoginRequestExpiredGenerate;
    }
    if (lower.contains('already used')) {
      return appStrings.thisQrLoginRequestWasAlready;
    }
    if (lower.contains('not approved yet')) {
      return appStrings.thisQrLoginRequestIsStill;
    }
    if (lower.contains('valid email')) {
      return appStrings.enterAValidEmailAddress;
    }
    if (lower.contains('email is already in use')) {
      return appStrings.thatEmailIsAlreadyLinkedTo;
    }
    if (lower.contains('current password is incorrect')) {
      return appStrings.yourCurrentPasswordIsIncorrect;
    }
    if (lower.contains('email confirmation required')) {
      return appStrings.confirmYourEmailBeforeSigningIn;
    }
    if (lower.contains('could not send confirmation email') ||
        lower.contains('service email is not configured')) {
      return appStrings.neoagentServiceEmailIsNotReady;
    }
    if (lower.contains('password min 8')) {
      return appStrings.useAPasswordWithAtLeast;
    }
    if (lower.contains('password is too weak')) {
      return text;
    }
    if (lower.contains('invalid 2fa') || lower.contains('two-factor code')) {
      return appStrings.theTwoFactorCodeIsNot;
    }
    if (lower.contains('two-factor challenge expired')) {
      return appStrings.theTwoFactorChallengeExpiredSign;
    }
    if (lower.contains('session_secret')) {
      return appStrings.n2faRequiresSessionSecretToBe;
    }
    if (lower.contains('cors') ||
        lower.contains('xmlhttprequest error') ||
        lower.contains('failed to fetch') ||
        lower.contains('network request failed') ||
        lower.contains('clientexception') ||
        lower.contains('socketexception')) {
      return appStrings.theAppCouldNotReachThis;
    }
    if (lower.contains('origin not allowed')) {
      return appStrings.thisBuildIsNotAllowedTo;
    }
    if (lower.contains('not authenticated')) {
      return appStrings.yourSessionExpiredPleaseSignIn;
    }
    if (lower.contains('no neoagent account is linked to this provider')) {
      return appStrings.thisGoogleAccountIsNotLinked;
    }
    if (lower.contains('already belongs to an existing account')) {
      return appStrings.thatEmailAlreadyBelongsToAn;
    }
    if (lower.contains('already linked to another neoagent account') ||
        lower.contains('already linked to another account')) {
      return appStrings.thatGoogleAccountIsAlreadyLinked;
    }
    if (lower.contains(
      'create a password or link another provider before removing this sign-in method',
    )) {
      return appStrings.addAnotherSignInMethodBefore;
    }
    if (lower.contains('unable to locate a java runtime') ||
        lower.contains('java runtime')) {
      final details = _extractMeaningfulErrorDetails(text);
      if (details.isNotEmpty) {
        return appStrings.mobileSetupFailedBecauseJavaIs(details);
      }
      return appStrings.mobileSetupFailedBecauseJavaIs2;
    }
    if (lower.contains('android sdk') ||
        lower.contains('sdkmanager') ||
        lower.contains('adb') ||
        lower.contains('emulator') ||
        lower.contains('gradle')) {
      final details = _extractMeaningfulErrorDetails(text);
      if (details.isNotEmpty) {
        return appStrings.mobileSetupFailedArg1(details);
      }
      return appStrings.mobileSetupFailedCheckThatAndroid;
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
          ? appStrings.theWebAppCouldNotReachThe(details)
          : appStrings.theWebAppCouldNotReach;
    }
    if (lower.contains('content security policy') ||
        lower.contains('connect-src')) {
      final details = _extractMeaningfulErrorDetails(text);
      return details.isNotEmpty
          ? appStrings.theBrowserBlockedARequiredRequestBecause(details)
          : appStrings.theBrowserBlockedARequiredRequest;
    }
    if (_shouldExposeErrorText(text)) {
      return _extractMeaningfulErrorDetails(text);
    }

    return appStrings.somethingWentWrongPleaseTryAgain;
  }

  String friendlyErrorMessage(Object error) => _friendlyErrorMessage(error);

  String _normalizeErrorText(Object error) {
    var text = _formatCaughtError(error);
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
        looksLikeStackTrace(text) ||
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

  /// This agent's SystemOne choice: `off`, `auto`, or a model id.
  String get systemOneModel {
    final value = settings['system_one_model']?.toString().trim() ?? '';
    return value.isEmpty ? 'off' : value;
  }

  /// A provider this agent can use (the server's key or its own) serves a
  /// SystemOne model the admin has not switched off.
  bool get systemOneAvailable =>
      systemOneModels.any((model) => model.available);

  String get timeZone => settings['timezone']?.toString().trim() ?? '';

  bool get timeZoneFollowsDevice => settings['timezone_auto'] != false;

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

  /// Models pinned to one kind of work (coding, research, ...). A kind with no
  /// entry follows the chat or sub-agent model.
  Map<String, String> get taskModels {
    final raw = settings['task_models'];
    if (raw is! Map) return const <String, String>{};
    return <String, String>{
      for (final entry in raw.entries)
        if (entry.value.toString().trim().isNotEmpty)
          entry.key.toString(): entry.value.toString(),
    };
  }

  String get defaultSpeechModel => _ensureModelValue(
    settings['default_speech_model']?.toString() ?? 'auto',
    supportedModels,
    allowAuto: true,
    preserveUnknown: true,
  );

  String get voiceSttProvider =>
      _settingString('voice_stt_provider', 'auto', lowercase: true);

  String get voiceSttModel => _settingString('voice_stt_model', '');

  /// Empty live voice values follow the server defaults in voiceCapabilities.
  String get voiceLiveProvider =>
      _settingString('voice_live_provider', '', lowercase: true);

  String get voiceLiveModel => _settingString('voice_live_model', '');

  String get voiceLiveVoice => _settingString('voice_live_voice', '');

  String get voiceInputMode =>
      _settingString('voice_input_mode', 'hands_free', lowercase: true);

  Map<String, dynamic> get voiceCapabilities =>
      _jsonMap(settings['voice_capabilities']);

  bool get isLiveVoiceCaptureStarting => _isStartingLiveVoice;

  bool get isLiveVoiceCaptureActive => _liveVoiceCaptureActive;

  DateTime? get liveVoiceSessionStartedAt => _liveVoiceSessionStartedAt;

  /// Mirrors the server's per-request admin flag; only decides what the UI
  /// shows. Every admin endpoint re-checks it server-side.
  bool get isAdmin => user?['isAdmin'] == true;

  String get accountLabel {
    final displayName = user?['display_name']?.toString().trim() ?? '';
    if (displayName.isNotEmpty) return displayName;
    return user?['username']?.toString() ??
        username.ifEmpty(appStrings.neoagentUser);
  }

  String get modelIndicator {
    if (defaultChatModel != 'auto') {
      final selected = _modelById(defaultChatModel);
      return selected?.label ?? defaultChatModel;
    }
    return appStrings.smartSelector2;
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
        StateError(appStrings.liveVoiceConnectionWasClosed),
      );
    }
    _liveVoiceSessionOpenCompleter = null;
    _socket?.dispose();
    _socket = null;
  }

  void _ensureSocketConnected() {
    unawaited(
      BackgroundKeepAlive.start(
        title: 'NeoAgent',
        body: 'Connected so calls and approvals can reach you',
      ),
    );
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
    socket.onAny((event, data) {
      if (!_runActivityEvents.contains(event)) {
        return;
      }
      runActivity.value = (
        seq: runActivity.value.seq + 1,
        runId: _jsonMap(data)['runId']?.toString() ?? '',
      );
    });
    socket.onConnect((_) {
      socketConnected = true;
      unawaited(_AppNotificationService.requestIncomingCallPermission());
      socket.emit('integrations:status');
      if (_socketHasConnectedOnce && isAuthenticated) {
        unawaited(refresh());
      }
      _socketHasConnectedOnce = true;
      _startRequestedVoiceCall();
      // A live call survives a socket drop: reopening the same session id
      // reattaches it on the server.
      if (voiceAssistantLiveState.hasActiveSession) {
        voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
          transportState: 'reconnecting',
        );
        unawaited(
          ensureLiveVoiceSession().catchError((Object error) {
            voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
              transportState: 'disconnected',
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
      if (voiceAssistantLiveState.hasActiveSession) {
        voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
          transportState: hasNetworkConnection
              ? 'reconnecting'
              : 'disconnected',
        );
      }
      notifyListeners();
    });
    socket.onConnectError((dynamic _) {
      socketConnected = false;
      if (voiceAssistantLiveState.hasActiveSession) {
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
      errorMessage = appStrings.arg1IsBlockedOnArg2Update(
        blocked.senderLabel,
        blocked.platform.toUpperCase(),
      );
      notifyListeners();
    });
    socket.on('messaging:error', (dynamic data) {
      final payload = _jsonMap(data);
      errorMessage =
          payload['error']?.toString() ??
          appStrings.messagingErrorPleaseTryAgain;
      notifyListeners();
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
      lastEndedCall = null;
      unawaited(_ringIncomingAgentCall(call));
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
      final readySessionId = payload['sessionId']?.toString();
      if (readySessionId != null && readySessionId == _abandonedCallId) {
        _abandonedCallId = null;
        socket.emit('voice:session_close', <String, dynamic>{
          'sessionId': readySessionId,
          'cancelTask': false,
        });
        return;
      }
      final acceptedCall = incomingAgentCall;
      final acceptedCallId = acceptedCall?.callId;
      final isAcceptedCall =
          acceptedCallId != null &&
          payload['sessionId']?.toString() == acceptedCallId;
      if (isAcceptedCall) {
        if (acceptedCall!.agentId.isNotEmpty &&
            agentProfiles.any((agent) => agent.id == acceptedCall.agentId)) {
          selectedAgentId = acceptedCall.agentId;
          unawaited(_persistSelectedAgentId(acceptedCall.agentId));
        }
        _clearIncomingAgentCall(acceptedCallId, sessionStarted: true);
        setSelectedSection(AppSection.voiceAssistant);
      }
      final outputSampleRate = _asInt(payload['outputSampleRate']) >= 8000
          ? _asInt(payload['outputSampleRate'])
          : 24000;
      _liveVoiceHearingSpeech = false;
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        sessionId: payload['sessionId']?.toString() ?? '',
        inputMode:
            payload['inputMode']?.toString().ifEmpty('hands_free') ??
            'hands_free',
        inputSampleRate: _asInt(payload['inputSampleRate']) >= 8000
            ? _asInt(payload['inputSampleRate'])
            : 24000,
        outputSampleRate: outputSampleRate,
        provider: payload['provider']?.toString() ?? '',
        model: payload['model']?.toString() ?? '',
        voice: payload['voice']?.toString() ?? '',
        activeRunId: payload['activeRunId']?.toString() ?? '',
        transportState: 'connected',
        state: 'listening',
        clearError: true,
      );
      unawaited(
        _liveVoicePlayer.start(sampleRate: outputSampleRate).catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          AppDiagnostics.log(
            'voice',
            'playback.start_failed',
            error: error,
            stackTrace: stackTrace,
          );
          voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
            error: appStrings.voicePlaybackIsUnavailableOnThis,
          );
          _syncVoiceWorkClicks();
          notifyListeners();
        }),
      );
      _liveVoiceSessionStartedAt ??= DateTime.now();
      _syncVoiceWorkClicks();
      if (_liveVoiceSessionOpenCompleter != null &&
          !_liveVoiceSessionOpenCompleter!.isCompleted) {
        _liveVoiceSessionOpenCompleter!.complete();
      }
      // An answered call is a phone call: in hands-free mode the microphone
      // opens right away.
      if (isAcceptedCall && voiceAssistantLiveState.isHandsFree) {
        unawaited(startLiveVoiceCapture().catchError((Object _) {}));
      }
      notifyListeners();
    });
    socket.on('voice:state', (dynamic data) {
      final payload = _jsonMap(data);
      if (!_matchesLiveVoiceSessionPayload(payload)) return;
      final state = payload['state']?.toString() ?? 'idle';
      if (state == 'closed') {
        unawaited(closeLiveVoiceSession(error: voiceAssistantLiveState.error));
        return;
      }
      if (state == 'listening' && voiceAssistantLiveState.isSpeaking) {
        _liveVoicePlayer.drain();
      }
      _liveVoiceHearingSpeech = state == 'speaking';
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(state: state);
      _syncVoiceWorkClicks();
      notifyListeners();
    });
    socket.on('voice:audio', (dynamic data) {
      final payload = _jsonMap(data);
      if (!_matchesLiveVoiceSessionPayload(payload)) return;
      final encoded = payload['audioBase64']?.toString() ?? '';
      if (encoded.isEmpty) return;
      _liveVoiceHearingSpeech = true;
      _haltVoiceWorkClicks();
      _liveVoicePlayer.add(base64Decode(encoded));
    });
    socket.on('voice:interrupted', (dynamic data) {
      if (!_matchesLiveVoiceSessionPayload(_jsonMap(data))) return;
      _liveVoiceHearingSpeech = false;
      unawaited(_liveVoicePlayer.flush());
      _syncVoiceWorkClicks();
    });
    socket.on('voice:transcript', (dynamic data) {
      final payload = _jsonMap(data);
      if (!_matchesLiveVoiceSessionPayload(payload)) return;
      _applyLiveVoiceTranscript(payload);
      notifyListeners();
    });
    socket.on('voice:task', (dynamic data) {
      final payload = _jsonMap(data);
      if (!_matchesLiveVoiceSessionPayload(payload)) return;
      final runId = payload['runId']?.toString() ?? '';
      if (payload['status']?.toString() == 'running') {
        voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
          activeRunId: runId,
          activeTaskRequest: payload['request']?.toString() ?? '',
        );
      } else if (voiceAssistantLiveState.activeRunId == runId) {
        voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
          activeRunId: '',
          activeTaskRequest: '',
        );
      }
      _syncVoiceWorkClicks();
      notifyListeners();
    });
    socket.on('voice:error', (dynamic data) {
      final payload = _jsonMap(data);
      if (!_matchesLiveVoiceSessionPayload(payload)) return;
      final message =
          payload['error']?.toString() ?? appStrings.liveVoiceFailed;
      final opening = _liveVoiceSessionOpenCompleter;
      if (payload['recoverable'] != true &&
          opening != null &&
          !opening.isCompleted) {
        opening.completeError(StateError(message));
      }
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        error: message,
      );
      _syncVoiceWorkClicks();
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
        return;
      }
      final pendingSteeringCount = activeRun?.pendingSteeringCount ?? 0;
      if (_isBackgroundRun(triggerSource)) {
        _backgroundRunIds.add(runId);
        unawaited(refreshRunsOnly());
        return;
      }
      if (!_matchesSelectedAgent(agentId)) {
        _backgroundRunIds.add(runId);
        return;
      }
      _failedForegroundRunId = null;
      activeRun = ActiveRunState(
        runId: runId,
        title:
            payload['title']?.toString().ifEmpty(appStrings.runningTask) ??
            appStrings.runningTask,
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
    socket.on('run:background', (dynamic data) {
      final runId = _jsonMap(data)['runId']?.toString() ?? '';
      // Any run moving to the background (chat or messaging) joins the
      // background task list, which comes from the run list.
      unawaited(refreshRunsOnly());
      if (runId.isEmpty || activeRun?.runId != runId) {
        return;
      }
      _backgroundRunIds.add(runId);
      _detachedChatRunIds.add(runId);
      activeRun = null;
      streamingAssistant = '';
      toolEvents = const <ToolEventItem>[];
      isSendingMessage = false;
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
        appStrings.modeArg1(payload['mode']?.toString() ?? 'execute'),
        appStrings.verificationArg12(
          payload['verification_need']?.toString() ?? 'none',
        ),
        appStrings.freshnessArg1(
          payload['freshness_risk']?.toString() ?? 'none',
        ),
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
          summary: steps.ifEmpty(appStrings.executionPlanCreated),
        ),
      ]);
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
    socket.on('run:pausing', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (activeRun?.runId == runId) {
        activeRun = activeRun!.copyWith(phase: 'Pausing');
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
        activeRun = activeRun!.copyWith(phase: appStrings.runningTool);
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
                appStrings.verificationStatusArg1(
                  payload['status']?.toString() ?? 'unknown',
                ),
              ) ??
              appStrings.verificationCompleted,
        ),
      ]);
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
                    appStrings.subagentUpdate2,
              ) ??
              appStrings.subagentUpdate2,
        ),
      );
      toolEvents = _capToolEvents(nextEvents);
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
      // An already-expired request must not be presented as actionable.
      if (!req.expiresAt.isAfter(DateTime.now())) return;
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
          summary: appStrings.queuedAsSteeringForTheCurrent(
            payload['content']?.toString() ?? '',
          ),
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
              ? appStrings.appliedTheLatestSteeringUpdateToThe
              : appStrings.appliedArg1QueuedSteeringUpdatesTo(
                  _asInt(payload['count']),
                ),
        ),
      ]);
      if (activeRun?.runId == runId || activeRun?.runId == 'pending') {
        activeRun = activeRun!.copyWith(
          pendingSteeringCount: _asInt(payload['pendingCount']),
          phase: appStrings.incorporatingSteering,
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
              ? appStrings.runningTool
              : 'Streaming',
        );
      }
      notifyListeners();
    });
    socket.on('run:complete', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.remove(runId)) {
        // A hand-off that finished after the call ended arrives as a chat
        // delivery instead of speech.
        final content = payload['content']?.toString().trim() ?? '';
        if (!voiceAssistantLiveState.hasActiveSession &&
            payload['outboxId'] != null &&
            content.isNotEmpty) {
          _appendAssistantChatMessage(content, platform: 'voice_live');
        }
        unawaited(refreshRateLimitUsage());
        notifyListeners();
        return;
      }
      if (_detachedChatRunIds.remove(runId)) {
        final content = payload['content']?.toString().trim() ?? '';
        if (content.isNotEmpty) {
          _appendAssistantChatMessage(content, platform: 'web');
        }
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
      if (!_isNewerRunActive(runId)) {
        streamingAssistant = '';
        isSendingMessage = false;
      }
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
      final runId = payload['runId']?.toString() ?? '';
      clearPendingApprovalForRun(runId);
      if (_voiceRunIds.remove(runId)) {
        return;
      }
      _detachedChatRunIds.remove(runId);
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
      final runId = payload['runId']?.toString() ?? '';
      clearPendingApprovalForRun(runId);
      if (_voiceRunIds.remove(runId)) {
        return;
      }
      _detachedChatRunIds.remove(runId);
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
      final runId = payload['runId']?.toString();
      if (runId != null && _voiceRunIds.remove(runId)) {
        return;
      }
      if (runId != null) {
        if (_detachedChatRunIds.remove(runId)) {
          errorMessage = _friendlyErrorMessage(
            BackendException(
              payload['error']?.toString().trim() ??
                  appStrings.iCouldNotCompleteThatRequest,
            ),
          );
        }
        if (_backgroundRunIds.remove(runId)) {
          unawaited(refreshRunsOnly());
          notifyListeners();
          return;
        }
      }
      if (_isNewerRunActive(runId ?? '')) {
        unawaited(refreshRunsOnly());
        return;
      }
      streamingAssistant = '';
      _failedForegroundRunId =
          runId ?? DateTime.now().microsecondsSinceEpoch.toString();
      activeRun = null;
      isSendingMessage = false;
      unawaited(refreshRunsOnly());
      final message =
          payload['error']?.toString().trim() ??
          appStrings.iCouldNotCompleteThatRequest;
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

  // A follow-up sent while a run was finishing starts its own run; the older
  // run's completion or error must not end the newer run's live state.
  bool _isNewerRunActive(String runId) {
    final current = activeRun;
    return runId.isNotEmpty &&
        current != null &&
        current.runId != runId &&
        current.runId != 'pending';
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
