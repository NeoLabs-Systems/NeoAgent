import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:audioplayers/audioplayers.dart';

import 'src/android_apk_drop_zone.dart';
import 'src/backend_client.dart';
import 'src/diagnostics_logger.dart';
import 'src/health_bridge.dart';
import 'src/oauth_launcher.dart';
import 'src/recording_bridge.dart';
import 'src/theme/palette.dart';
import 'wearables/wearable_service.dart';

part 'main_theme.dart';
part 'main_app_shell.dart';
part 'main_integrations.dart';
part 'main_models.dart';
part 'main_shared.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NeoAgentApp());
}

const String _androidEmulatorBackendUrl = 'http://10.0.2.2:3333';
const String _browserUrlPlaceholder = 'https://example.com';
const String _androidLaunchPlaceholder = 'com.android.settings';
const String _packageOrUrlHint = 'Package name or URL';

enum AppSection {
  chat,
  voiceAssistant,
  devices,
  recordings,
  messaging,
  runs,
  settings,
  accountSettings,
  logs,
  skills,
  agents,
  integrations,
  memory,
  scheduler,
  mcp,
  health,
  wearables,
}

enum SidebarGroup { chat, agents, recordings, activity, automation, settings }

extension SidebarGroupX on SidebarGroup {
  String get label {
    switch (this) {
      case SidebarGroup.chat:
        return 'Chat';
      case SidebarGroup.agents:
        return 'Agents';
      case SidebarGroup.recordings:
        return 'Recording';
      case SidebarGroup.activity:
        return 'Activity';
      case SidebarGroup.automation:
        return 'Automation';
      case SidebarGroup.settings:
        return 'Settings';
    }
  }

  IconData get icon {
    switch (this) {
      case SidebarGroup.chat:
        return Icons.chat_bubble_outline;
      case SidebarGroup.agents:
        return Icons.smart_toy_outlined;
      case SidebarGroup.recordings:
        return Icons.fiber_smart_record_outlined;
      case SidebarGroup.activity:
        return Icons.insights_outlined;
      case SidebarGroup.automation:
        return Icons.auto_awesome_outlined;
      case SidebarGroup.settings:
        return Icons.tune;
    }
  }
}

extension AppSectionX on AppSection {
  String get label {
    switch (this) {
      case AppSection.chat:
        return 'Chat';
      case AppSection.voiceAssistant:
        return 'Voice assistant';
      case AppSection.devices:
        return 'Devices';
      case AppSection.recordings:
        return 'Recordings';
      case AppSection.messaging:
        return 'Messaging';
      case AppSection.runs:
        return 'Runs';
      case AppSection.settings:
        return 'Settings';
      case AppSection.accountSettings:
        return 'Account settings';
      case AppSection.logs:
        return 'Logs';
      case AppSection.skills:
        return 'Skills';
      case AppSection.agents:
        return 'Agents';
      case AppSection.integrations:
        return 'Integrations';
      case AppSection.memory:
        return 'Memory';
      case AppSection.scheduler:
        return 'Scheduler';
      case AppSection.mcp:
        return 'MCP';
      case AppSection.health:
        return 'Health';
      case AppSection.wearables:
        return 'Wearables';
    }
  }

  IconData get icon {
    switch (this) {
      case AppSection.chat:
        return Icons.chat_bubble_outline;
      case AppSection.voiceAssistant:
        return Icons.keyboard_voice_outlined;
      case AppSection.devices:
        return Icons.devices_other_outlined;
      case AppSection.recordings:
        return Icons.fiber_smart_record_outlined;
      case AppSection.messaging:
        return Icons.forum_outlined;
      case AppSection.runs:
        return Icons.history;
      case AppSection.settings:
        return Icons.tune;
      case AppSection.accountSettings:
        return Icons.manage_accounts_outlined;
      case AppSection.logs:
        return Icons.article_outlined;
      case AppSection.skills:
        return Icons.extension_outlined;
      case AppSection.agents:
        return Icons.smart_toy_outlined;
      case AppSection.integrations:
        return Icons.integration_instructions_outlined;
      case AppSection.memory:
        return Icons.psychology_outlined;
      case AppSection.scheduler:
        return Icons.schedule_outlined;
      case AppSection.mcp:
        return Icons.hub_outlined;
      case AppSection.health:
        return Icons.favorite_border;
      case AppSection.wearables:
        return Icons.watch_outlined;
    }
  }

  SidebarGroup get group {
    switch (this) {
      case AppSection.chat:
      case AppSection.voiceAssistant:
        return SidebarGroup.chat;
      case AppSection.agents:
        return SidebarGroup.agents;
      case AppSection.recordings:
      case AppSection.wearables:
        return SidebarGroup.recordings;
      case AppSection.runs:
      case AppSection.logs:
        return SidebarGroup.activity;
      case AppSection.devices:
      case AppSection.skills:
      case AppSection.integrations:
      case AppSection.memory:
      case AppSection.scheduler:
      case AppSection.mcp:
      case AppSection.health:
        return SidebarGroup.automation;
      case AppSection.settings:
      case AppSection.accountSettings:
      case AppSection.messaging:
        return SidebarGroup.settings;
    }
  }

  String get navigationTitle {
    final groupLabel = group.label;
    if (this == AppSection.wearables || this == AppSection.voiceAssistant) {
      return label;
    }
    if (group == SidebarGroup.chat || group == SidebarGroup.recordings) {
      return groupLabel;
    }
    if (groupLabel == label) {
      return groupLabel;
    }
    return '$groupLabel · $label';
  }
}

class NeoAgentApp extends StatefulWidget {
  const NeoAgentApp({super.key});

  @override
  State<NeoAgentApp> createState() => _NeoAgentAppState();
}

class _NeoAgentAppState extends State<NeoAgentApp> {
  late final NeoAgentController _controller;

  @override
  void initState() {
    super.initState();
    final backendClient = BackendClient();
    _controller = NeoAgentController(
      backendClient: backendClient,
      healthBridge: HealthBridge(),
      recordingBridge: createRecordingBridge(),
      wearableService: WearableService(
        backendClient: backendClient,
        getBackendUrl: () => _controller.backendUrl,
      ),
    )..bootstrap();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return MaterialApp(
          key: ValueKey<bool>(_controller.isAuthenticated),
          title: 'NeoOS',
          debugShowCheckedModeBanner: false,
          theme: _buildNeoAgentTheme(_lightPalette, Brightness.light),
          darkTheme: _buildNeoAgentTheme(_darkPalette, Brightness.dark),
          themeMode: ThemeMode.system,
          home: NeoAgentRoot(controller: _controller),
        );
      },
    );
  }
}

class NeoAgentRoot extends StatelessWidget {
  const NeoAgentRoot({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.isBooting) {
      return const SplashView();
    }
    if (!controller.isAuthenticated) {
      return AuthView(controller: controller);
    }
    return HomeView(controller: controller);
  }
}

class NeoAgentController extends ChangeNotifier {
  NeoAgentController({
    required BackendClient backendClient,
    required HealthBridge healthBridge,
    required RecordingBridge recordingBridge,
    required WearableService wearableService,
    OAuthLauncher? oauthLauncher,
  }) : _backendClient = backendClient,
       _healthBridge = healthBridge,
       _recordingBridge = recordingBridge,
       _wearableService = wearableService,
       _oauthLauncher = oauthLauncher ?? createOAuthLauncher() {
    _recordingBridge.onRecordingStopped = _handleRecordingStopped;
    _recordingBridge.addListener(_handleRecordingBridgeChanged);
  }

  final BackendClient _backendClient;
  final HealthBridge _healthBridge;
  final RecordingBridge _recordingBridge;
  final WearableService _wearableService;
  final OAuthLauncher _oauthLauncher;

  static const String _configuredBackendUrl = String.fromEnvironment(
    'NEOAGENT_BACKEND_URL',
  );

  SharedPreferences? _prefs;
  io.Socket? _socket;
  Timer? _updatePollTimer;
  final Set<String> _backgroundRunIds = <String>{};
  final Set<String> _busyOfficialIntegrationKeys = <String>{};
  int _authCycle = 0;

  bool isBooting = true;
  bool isAuthenticated = false;
  bool isAuthenticating = false;
  bool isAwaitingTwoFactor = false;
  bool isRefreshing = false;
  bool isRefreshingDevices = false;
  bool isSendingMessage = false;
  bool isSavingSettings = false;
  bool isLoadingAccountSettings = false;
  bool isSavingAccountSettings = false;
  bool isConfiguringTwoFactor = false;
  bool isRevokingSession = false;
  bool isTriggeringUpdate = false;
  bool isSavingReleaseChannel = false;
  bool isSyncingHealth = false;
  bool isRunningDeviceAction = false;
  bool socketConnected = false;

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

  AppSection selectedSection = AppSection.chat;
  Map<String, dynamic>? user;
  Map<String, dynamic> accountTwoFactor = const <String, dynamic>{};
  List<AccountSessionItem> accountSessions = const <AccountSessionItem>[];
  List<AuthProviderCatalogItem> authProviders =
      const <AuthProviderCatalogItem>[];
  List<LinkedAuthProviderItem> linkedAuthProviders =
      const <LinkedAuthProviderItem>[];
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
  List<SchedulerTask> schedulerTasks = const <SchedulerTask>[];
  List<McpServerItem> mcpServers = const <McpServerItem>[];
  Map<String, dynamic> browserRuntime = const <String, dynamic>{};
  Map<String, dynamic> browserExtensionStatus = const <String, dynamic>{};
  Map<String, dynamic> androidRuntime = const <String, dynamic>{};
  List<String> androidInstalledApps = const <String>[];
  List<Map<String, dynamic>> androidUiPreview = const <Map<String, dynamic>>[];
  String? browserScreenshotPath;
  String? androidScreenshotPath;
  String? browserLastResult;
  String? androidLastResult;
  String? androidUiDumpPath;
  final Map<String, RunDetailSnapshot> _runDetailsCache =
      <String, RunDetailSnapshot>{};

  ActiveRunState? activeRun;
  List<ToolEventItem> toolEvents = const <ToolEventItem>[];
  String streamingAssistant = '';
  bool isStartingRecording = false;
  bool isStoppingRecording = false;

  WearableService get wearableService => _wearableService;

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

    return _androidEmulatorBackendUrl;
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
    _updatePollTimer?.cancel();
    _socket?.dispose();
    _recordingBridge.removeListener(_handleRecordingBridgeChanged);
    _recordingBridge.dispose();
    _oauthLauncher.dispose();
    super.dispose();
  }

  RecordingRuntimeStatus get recordingRuntime => _recordingBridge.status;

  Map<String, Object?> _recordingRuntimeSnapshot() {
    final runtime = recordingRuntime;
    return <String, Object?>{
      'runtimeActive': runtime.active,
      'runtimePaused': runtime.paused,
      'runtimeSessionId': runtime.sessionId,
      'runtimeStartedAt': runtime.startedAt?.toIso8601String(),
      'runtimeError': runtime.errorMessage,
      'sessionsLoaded': recordingSessions.length,
    };
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
    backendUrl = _defaultBackendUrl;
    username = _prefs?.getString('username') ?? '';
    password = '';
    await _recordingBridge.refreshStatus();
    notifyListeners();

    try {
      final status = await _backendClient.getAuthStatus(backendUrl);
      hasUser = status['hasUser'] != false;
      registrationOpen = status['registrationOpen'] == true;
      serviceEmailConfigured =
          (status['email'] is Map &&
          (status['email'] as Map)['configured'] == true);
      deploymentProfile = status['deploymentProfile']?.toString() ?? 'private';
      authProviders =
          (status['providers'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<dynamic, dynamic>>()
              .map(AuthProviderCatalogItem.fromJson)
              .toList();

      final me = await _backendClient.getCurrentUser(backendUrl);
      if (me != null && me['user'] is Map<String, dynamic>) {
        user = Map<String, dynamic>.from(me['user'] as Map<String, dynamic>);
        isAuthenticated = true;
      }
      if (isAuthenticated) {
        await refresh();
      }
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isBooting = false;
      notifyListeners();
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
      user = Map<String, dynamic>.from(
        response['user'] as Map<dynamic, dynamic>? ?? const <String, dynamic>{},
      );
      hasUser = true;
      isAuthenticated = true;
      isAwaitingTwoFactor = false;
      pendingTwoFactorUsername = '';
      password = '';
      await _persistCredentials();
      await refresh();
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
      user = Map<String, dynamic>.from(
        response['user'] as Map<dynamic, dynamic>? ??
            <String, dynamic>{'username': pendingTwoFactorUsername},
      );
      hasUser = true;
      isAuthenticated = true;
      isAwaitingTwoFactor = false;
      pendingTwoFactorUsername = '';
      password = '';
      await _persistCredentials();
      await refresh();
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
      user = Map<String, dynamic>.from(
        response['user'] as Map<dynamic, dynamic>? ??
            <String, dynamic>{'username': username},
      );
      hasUser = true;
      isAuthenticated = true;
      isAwaitingTwoFactor = false;
      pendingTwoFactorUsername = '';
      password = '';
      await _persistCredentials();
      await refresh();
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
    isAuthenticating = true;
    notifyListeners();

    try {
      await logoutFuture;
    } catch (_) {}
    isAuthenticating = false;
    notifyListeners();
  }

  void _clearAuthenticatedState() {
    _disconnectSocket();
    _updatePollTimer?.cancel();
    _updatePollTimer = null;
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
    logs = const <LogEntry>[];
    messagingStatuses = const <String, MessagingPlatformStatus>{};
    messagingMessages = const <MessagingMessage>[];
    pendingMessagingQr = null;
    skills = const <SkillItem>[];
    storeSkills = const <StoreSkillItem>[];
    officialIntegrations = const <OfficialIntegrationItem>[];
    memoryOverview = const MemoryOverview();
    memories = const <MemoryItem>[];
    memoryRecallResults = const <MemoryItem>[];
    memoryConversations = const <ConversationItem>[];
    schedulerTasks = const <SchedulerTask>[];
    mcpServers = const <McpServerItem>[];
    browserRuntime = const <String, dynamic>{};
    browserExtensionStatus = const <String, dynamic>{};
    androidRuntime = const <String, dynamic>{};
    androidInstalledApps = const <String>[];
    androidUiPreview = const <Map<String, dynamic>>[];
    browserScreenshotPath = null;
    androidScreenshotPath = null;
    browserLastResult = null;
    androidLastResult = null;
    androidUiDumpPath = null;
    versionInfo = null;
    backendHealthStatus = null;
    recordingSessions = const <RecordingSessionItem>[];
    activeRun = null;
    toolEvents = const <ToolEventItem>[];
    streamingAssistant = '';
    selectedSection = AppSection.chat;
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
  }

  void setSelectedSection(AppSection section) {
    if (section == AppSection.wearables && !showWearablesSection) {
      selectedSection = AppSection.chat;
    } else {
      selectedSection = section;
    }
    if (section == AppSection.devices) {
      unawaited(refreshDevices());
    }
    if (section == AppSection.accountSettings) {
      unawaited(refreshAccountSettings());
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
    while (DateTime.now().isBefore(deadline)) {
      final response = await _backendClient.completeProviderAuth(
        baseUrl: backendUrl,
        state: state,
      );
      if (response['status']?.toString() == 'pending') {
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
    logs = const <LogEntry>[];
    notifyListeners();
  }

  List<String> currentMessagingWhitelist(String platform) {
    dynamic raw;
    switch (platform) {
      case 'whatsapp':
        raw = settings['platform_whitelist_whatsapp'];
        if (raw is String && raw.trim().isNotEmpty) {
          try {
            raw = jsonDecode(raw);
          } catch (_) {
            raw = const <dynamic>[];
          }
        }
        break;
      case 'telnyx':
        raw = settings['platform_whitelist_telnyx'];
        break;
      case 'discord':
        raw = settings['platform_whitelist_discord'];
        break;
      case 'telegram':
        raw = settings['platform_whitelist_telegram'];
        break;
      default:
        raw = settings['platform_whitelist_$platform'];
        break;
    }
    if (raw is List) {
      return raw
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }

  Future<void> allowMessagingEntry(String platform, String entry) async {
    try {
      final current = currentMessagingWhitelist(platform).toSet()..add(entry);
      switch (platform) {
        case 'whatsapp':
          await saveWhatsAppWhitelist(current.toList());
          break;
        case 'telnyx':
          await saveTelnyxWhitelist(current.toList());
          break;
        case 'discord':
          await saveDiscordWhitelist(current.toList());
          break;
        case 'telegram':
          await saveTelegramWhitelist(current.toList());
          break;
        default:
          await saveMessagingWhitelist(platform, current.toList());
      }
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
      final me = await _backendClient.getCurrentUser(backendUrl);
      if (!_isCurrentAuthCycle(authCycle)) {
        return;
      }
      if (me == null || me['user'] is! Map<String, dynamic>) {
        _authCycle += 1;
        _clearAuthenticatedState();
        return;
      }

      user = Map<String, dynamic>.from(me['user'] as Map<String, dynamic>);

      final profilesResponse = await _backendClient.fetchAgentProfiles(
        backendUrl,
      );
      if (!_isCurrentAuthCycle(authCycle)) {
        return;
      }
      agentProfiles =
          (profilesResponse['agents'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<dynamic, dynamic>>()
              .map(AgentProfile.fromJson)
              .where((agent) => agent.id.isNotEmpty)
              .toList();
      _ensureSelectedAgent();
      final agentId = _scopedAgentId;

      final historyFuture = _backendClient.fetchChatHistory(
        backendUrl,
        agentId: agentId,
      );
      final modelsFuture = _backendClient.fetchSupportedModels(
        backendUrl,
        agentId: agentId,
      );
      final providersFuture = _backendClient.fetchAiProviders(
        backendUrl,
        agentId: agentId,
      );
      final settingsFuture = _backendClient.fetchSettings(
        backendUrl,
        agentId: agentId,
      );
      final runsFuture = _backendClient.fetchRuns(backendUrl, agentId: agentId);
      final versionFuture = _backendClient.fetchVersion(backendUrl);
      final tokenFuture = _backendClient.fetchTokenUsageSummary(
        backendUrl,
        agentId: agentId,
      );
      final updateFuture = _backendClient.fetchUpdateStatus(backendUrl);
      final messagingFuture = _backendClient.fetchMessagingStatus(
        backendUrl,
        agentId: agentId,
      );
      final messagingMessagesFuture = _backendClient.fetchMessagingMessages(
        backendUrl,
        agentId: agentId,
      );
      final skillsFuture = _backendClient.fetchSkills(backendUrl);
      final storeSkillsFuture = _backendClient.fetchSkillStore(backendUrl);
      final officialIntegrationsFuture = _backendClient
          .fetchOfficialIntegrations(backendUrl, agentId: agentId);
      final memoryFuture = _backendClient.fetchMemoryOverview(
        backendUrl,
        agentId: agentId,
      );
      final memoriesFuture = _backendClient.fetchMemories(
        backendUrl,
        agentId: agentId,
      );
      final conversationsFuture = _backendClient.fetchConversations(
        backendUrl,
        agentId: agentId,
      );
      final schedulerFuture = _backendClient.fetchSchedulerTasks(backendUrl);
      final mcpFuture = _backendClient.fetchMcpServers(backendUrl);
      final recordingsFuture = _backendClient.fetchRecordingSessions(
        backendUrl,
      );
      final browserFuture = _backendClient.fetchBrowserStatus(backendUrl);
      final browserExtensionFuture = _backendClient.fetchBrowserExtensionStatus(
        backendUrl,
      );
      final androidFuture = _backendClient.fetchAndroidStatus(backendUrl);

      Map<String, dynamic>? healthResponse;
      try {
        healthResponse = await _backendClient.fetchHealthStatus(backendUrl);
      } catch (_) {
        healthResponse = null;
      }
      if (!_isCurrentAuthCycle(authCycle)) {
        return;
      }

      try {
        officialIntegrations = (await officialIntegrationsFuture)
            .map(OfficialIntegrationItem.fromJson)
            .toList();
      } catch (_) {
        officialIntegrations = const <OfficialIntegrationItem>[];
      }
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
      final schedulerResponse = await schedulerFuture;
      final mcpResponse = await mcpFuture;
      final recordingsResponse = await recordingsFuture;
      final browserResponse = await browserFuture;
      final browserExtensionResponse = await browserExtensionFuture;
      final androidResponse = await androidFuture;
      if (!_isCurrentAuthCycle(authCycle)) {
        return;
      }

      chatMessages = (history['messages'] as List<dynamic>? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((item) => ChatEntry.fromJson(item))
          .toList();

      supportedModels =
          (modelsResponse['models'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<dynamic, dynamic>>()
              .map((item) => ModelMeta.fromJson(item))
              .toList();

      aiProviders =
          (providersResponse['providers'] as List<dynamic>? ??
                  const <dynamic>[])
              .whereType<Map<dynamic, dynamic>>()
              .map((item) => AiProviderMeta.fromJson(item))
              .toList();

      settings = Map<String, dynamic>.from(settingsResponse);
      recentRuns = (runsResponse['runs'] as List<dynamic>? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((item) => RunSummary.fromJson(item))
          .toList();
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
      messagingMessages = messagingMessagesResponse
          .map(MessagingMessage.fromJson)
          .toList();
      skills = skillsResponse.map(SkillItem.fromJson).toList();
      storeSkills = storeSkillsResponse.map(StoreSkillItem.fromJson).toList();
      memoryOverview = MemoryOverview.fromJson(memoryResponse);
      memories = memoriesResponse.map(MemoryItem.fromJson).toList();
      memoryConversations = conversationsResponse
          .map(ConversationItem.fromJson)
          .toList();
      schedulerTasks = schedulerResponse.map(SchedulerTask.fromJson).toList();
      mcpServers = mcpResponse.map(McpServerItem.fromJson).toList();
      recordingSessions = recordingsResponse
          .map(RecordingSessionItem.fromJson)
          .toList();
      browserRuntime = Map<String, dynamic>.from(browserResponse);
      browserExtensionStatus = Map<String, dynamic>.from(
        browserExtensionResponse,
      );
      androidRuntime = Map<String, dynamic>.from(androidResponse);
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

  Future<void> refreshRunsOnly() async {
    try {
      final runsResponse = await _backendClient.fetchRuns(
        backendUrl,
        agentId: _scopedAgentId,
      );
      recentRuns = (runsResponse['runs'] as List<dynamic>? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((item) => RunSummary.fromJson(item))
          .toList();
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

  Future<void> refreshMessaging() async {
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
    messagingMessages = (await _backendClient.fetchMessagingMessages(
      backendUrl,
      agentId: _scopedAgentId,
    )).map(MessagingMessage.fromJson).toList();
    notifyListeners();
  }

  Future<void> refreshSkills() async {
    skills = (await _backendClient.fetchSkills(
      backendUrl,
    )).map(SkillItem.fromJson).toList();
    storeSkills = (await _backendClient.fetchSkillStore(
      backendUrl,
    )).map(StoreSkillItem.fromJson).toList();
    try {
      officialIntegrations = (await _backendClient.fetchOfficialIntegrations(
        backendUrl,
        agentId: _scopedAgentId,
      )).map(OfficialIntegrationItem.fromJson).toList();
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
    memories = (await _backendClient.fetchMemories(
      backendUrl,
      agentId: _scopedAgentId,
    )).map(MemoryItem.fromJson).toList();
    memoryConversations = (await _backendClient.fetchConversations(
      backendUrl,
      agentId: _scopedAgentId,
    )).map(ConversationItem.fromJson).toList();
    notifyListeners();
  }

  Future<void> refreshScheduler() async {
    schedulerTasks = (await _backendClient.fetchSchedulerTasks(
      backendUrl,
    )).map(SchedulerTask.fromJson).toList();
    notifyListeners();
  }

  Future<void> refreshMcp() async {
    mcpServers = (await _backendClient.fetchMcpServers(
      backendUrl,
    )).map(McpServerItem.fromJson).toList();
    notifyListeners();
  }

  Future<void> refreshRecordings() async {
    _logRecording('refresh.request');
    recordingSessions = (await _backendClient.fetchRecordingSessions(
      backendUrl,
    )).map(RecordingSessionItem.fromJson).toList();
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
      final existingIndex = recordingSessions.indexWhere(
        (item) => item.id == session.id,
      );
      if (existingIndex >= 0) {
        recordingSessions = <RecordingSessionItem>[
          ...recordingSessions.sublist(0, existingIndex),
          session,
          ...recordingSessions.sublist(existingIndex + 1),
        ];
      } else {
        recordingSessions = <RecordingSessionItem>[
          session,
          ...recordingSessions,
        ];
      }

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
      browserRuntime = Map<String, dynamic>.from(browserResponse);
      browserExtensionStatus = Map<String, dynamic>.from(
        browserExtensionResponse,
      );
      androidRuntime = Map<String, dynamic>.from(androidResponse);
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
      androidInstalledApps =
          (response['packages'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList();
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
  }

  Future<void> startAndroidRuntime() async {
    await _runDeviceAction(
      () => _backendClient.startAndroidEmulator(backendUrl),
      browser: false,
      refreshAppsAfter: true,
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
    final devices =
        (androidRuntime['devices'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<dynamic, dynamic>>();
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
    if (isStartingRecording || recordingRuntime.active) {
      return;
    }
    isStartingRecording = true;
    errorMessage = null;
    notifyListeners();

    String? sessionId;
    try {
      _logRecording('start_web.request');
      final response = await _backendClient.createRecordingSession(
        backendUrl,
        <String, dynamic>{
          'platform': 'web',
          'screenAnalysisReady': true,
          'sources': const <Map<String, dynamic>>[
            <String, dynamic>{
              'sourceKey': 'screen',
              'sourceKind': 'screen-share',
              'mediaKind': 'video',
              'mimeType': 'video/webm',
              'metadata': <String, dynamic>{
                'analysisReady': true,
                'transcribe': false,
              },
            },
            <String, dynamic>{
              'sourceKey': 'microphone',
              'sourceKind': 'microphone',
              'mediaKind': 'audio',
              'mimeType': 'audio/webm',
            },
          ],
        },
      );
      final session = RecordingSessionItem.fromJson(
        _jsonMap(response['session']),
      );
      sessionId = session.id;
      recordingSessions = <RecordingSessionItem>[
        session,
        ...recordingSessions.where((item) => item.id != session.id),
      ];
      await _recordingBridge.startWebRecording(
        baseUrl: backendUrl,
        sessionId: session.id,
      );
      _logRecording(
        'start_web.done',
        data: <String, Object?>{'sessionId': session.id},
      );
      notifyListeners();
    } catch (error) {
      _logRecording(
        'start_web.failed',
        data: <String, Object?>{'sessionId': sessionId},
        error: error,
      );
      if (sessionId != null) {
        try {
          await _backendClient.finalizeRecordingSession(
            backendUrl,
            sessionId,
            stopReason: 'cancelled',
          );
        } catch (_) {}
      }
      errorMessage = _friendlyErrorMessage(error);
      await refreshRecordings();
    } finally {
      isStartingRecording = false;
      notifyListeners();
    }
  }

  Future<void> startBackgroundRecording() async {
    if (isStartingRecording || recordingRuntime.active) {
      return;
    }
    isStartingRecording = true;
    errorMessage = null;
    notifyListeners();

    String? sessionId;
    try {
      _logRecording('start_background.request');
      final response = await _backendClient.createRecordingSession(
        backendUrl,
        <String, dynamic>{
          'platform': 'android',
          'screenAnalysisReady': false,
          'sources': const <Map<String, dynamic>>[
            <String, dynamic>{
              'sourceKey': 'microphone',
              'sourceKind': 'microphone',
              'mediaKind': 'audio',
              'mimeType': 'audio/wav',
              'metadata': <String, dynamic>{'backgroundCapable': true},
            },
          ],
        },
      );
      final session = RecordingSessionItem.fromJson(
        _jsonMap(response['session']),
      );
      sessionId = session.id;
      recordingSessions = <RecordingSessionItem>[
        session,
        ...recordingSessions.where((item) => item.id != session.id),
      ];
      await _recordingBridge.startBackgroundRecording(
        baseUrl: backendUrl,
        sessionCookie: _backendClient.sessionCookie ?? '',
        sessionId: session.id,
      );
      _logRecording(
        'start_background.done',
        data: <String, Object?>{'sessionId': session.id},
      );
      notifyListeners();
    } catch (error) {
      _logRecording(
        'start_background.failed',
        data: <String, Object?>{'sessionId': sessionId},
        error: error,
      );
      if (sessionId != null) {
        try {
          await _backendClient.finalizeRecordingSession(
            backendUrl,
            sessionId,
            stopReason: 'cancelled',
          );
        } catch (_) {}
      }
      errorMessage = _friendlyErrorMessage(error);
      await refreshRecordings();
    } finally {
      isStartingRecording = false;
      notifyListeners();
    }
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

  Future<void> stopRecording() async {
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
      await _recordingBridge.stopActiveRecording();
      if (isAndroidBackgroundStop) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
      } else {
        await _backendClient.finalizeRecordingSession(
          backendUrl,
          sessionId,
          stopReason: 'stopped',
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
      final existingIndex = recordingSessions.indexWhere(
        (item) => item.id == session.id,
      );
      if (existingIndex >= 0) {
        recordingSessions = <RecordingSessionItem>[
          ...recordingSessions.sublist(0, existingIndex),
          session,
          ...recordingSessions.sublist(existingIndex + 1),
        ];
      } else {
        recordingSessions = <RecordingSessionItem>[
          session,
          ...recordingSessions,
        ];
      }
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
      recordingSessions = recordingSessions
          .where((item) => item.id != sessionId)
          .toList();
      notifyListeners();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<VoiceAssistantTurnResult> runVoiceAssistantTurn({
    required String sessionId,
    String promptHint = '',
    String ttsVoice = 'alloy',
    String ttsModel = 'tts-1',
  }) async {
    final response = await _backendClient.runVoiceAssistantTurn(
      backendUrl,
      sessionId: sessionId,
      promptHint: promptHint,
      ttsVoice: ttsVoice,
      ttsModel: ttsModel,
      agentId: _scopedAgentId,
    );

    final result = VoiceAssistantTurnResult.fromJson(response);
    final session = result.session;
    final existingIndex = recordingSessions.indexWhere(
      (item) => item.id == session.id,
    );
    if (existingIndex >= 0) {
      recordingSessions = <RecordingSessionItem>[
        ...recordingSessions.sublist(0, existingIndex),
        session,
        ...recordingSessions.sublist(existingIndex + 1),
      ];
    } else {
      recordingSessions = <RecordingSessionItem>[session, ...recordingSessions];
    }

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

  void _appendAssistantChatMessage(
    String content, {
    required String platform,
    bool transient = false,
  }) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final previous = chatMessages.isNotEmpty ? chatMessages.last : null;
    if (previous != null &&
        previous.role == 'assistant' &&
        previous.platform == platform &&
        previous.content.trim() == trimmed) {
      return;
    }

    chatMessages = <ChatEntry>[
      ...chatMessages,
      ChatEntry(
        role: 'assistant',
        content: trimmed,
        platform: platform,
        createdAt: DateTime.now(),
        transient: transient,
      ),
    ];
  }

  void _appendUserChatMessage(String content, {required String platform}) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final previous = chatMessages.isNotEmpty ? chatMessages.last : null;
    if (previous != null &&
        previous.role == 'user' &&
        previous.platform == platform &&
        previous.content.trim() == trimmed) {
      return;
    }

    chatMessages = <ChatEntry>[
      ...chatMessages,
      ChatEntry(
        role: 'user',
        content: trimmed,
        platform: platform,
        createdAt: DateTime.now(),
      ),
    ];
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

  Future<void> sendMessage(String task) async {
    final trimmed = task.trim();
    final canSteerLiveRun = hasLiveRun && _socket != null && socketConnected;
    if (trimmed.isEmpty || (isSendingMessage && !canSteerLiveRun)) {
      return;
    }

    final optimistic = ChatEntry(
      role: 'user',
      content: trimmed,
      platform: 'flutter',
      createdAt: DateTime.now(),
    );
    chatMessages = <ChatEntry>[...chatMessages, optimistic];
    errorMessage = null;
    if (!canSteerLiveRun) {
      isSendingMessage = true;
      toolEvents = const <ToolEventItem>[];
      streamingAssistant = '';
      activeRun = ActiveRunState.pending(trimmed);
    }
    notifyListeners();

    try {
      if (_socket != null && socketConnected) {
        _socket!.emit('agent:run', <String, dynamic>{
          'task': trimmed,
          'agentId': _scopedAgentId,
          'options': <String, dynamic>{'agentId': _scopedAgentId},
        });
        return;
      }

      final response = await _backendClient.runTask(
        backendUrl,
        trimmed,
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
    required bool headlessBrowser,
    required String browserBackend,
    required bool smarterSelector,
    required List<String> enabledModels,
    required String defaultChatModel,
    required String defaultSubagentModel,
    required String fallbackModel,
    required Map<String, dynamic> aiProviderConfigs,
  }) async {
    isSavingSettings = true;
    errorMessage = null;
    notifyListeners();

    final payload = <String, dynamic>{
      'headless_browser': headlessBrowser,
      'browser_backend': browserBackend,
      'smarter_model_selector': smarterSelector,
      'enabled_models': enabledModels,
      'default_chat_model': defaultChatModel,
      'default_subagent_model': defaultSubagentModel,
      'fallback_model_id': fallbackModel,
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
      return (response['recoveryCodes'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList();
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
      return (response['recoveryCodes'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList();
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
      if (response['status']?.toString() != 'oauth_redirect' || url == null) {
        throw Exception('Official integration did not return an OAuth URL.');
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

  Future<Map<String, dynamic>> createWearablePairingCode({
    int ttlMinutes = 10,
    String? deviceHint,
  }) async {
    return _backendClient.createWearablePairingCode(
      backendUrl,
      ttlMinutes: ttlMinutes,
      deviceHint: deviceHint,
      agentId: _scopedAgentId,
    );
  }

  Future<void> saveWhatsAppWhitelist(List<String> values) async {
    final normalized = values
        .map((value) => value.replaceAll(RegExp(r'[^0-9]'), ''))
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    await _backendClient.saveSettings(backendUrl, <String, dynamic>{
      'platform_whitelist_whatsapp': jsonEncode(normalized),
    }, agentId: _scopedAgentId);
    settings = <String, dynamic>{
      ...settings,
      'platform_whitelist_whatsapp': jsonEncode(normalized),
    };
    notifyListeners();
  }

  Future<void> saveTelnyxWhitelist(List<String> values) async {
    await _backendClient.saveTelnyxWhitelist(
      backendUrl,
      values,
      agentId: _scopedAgentId,
    );
    settings = <String, dynamic>{
      ...settings,
      'platform_whitelist_telnyx': values,
    };
    notifyListeners();
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

  Future<void> saveDiscordWhitelist(List<String> values) async {
    await _backendClient.saveDiscordWhitelist(
      backendUrl,
      values,
      agentId: _scopedAgentId,
    );
    settings = <String, dynamic>{
      ...settings,
      'platform_whitelist_discord': values,
    };
    notifyListeners();
  }

  Future<void> saveTelegramWhitelist(List<String> values) async {
    await _backendClient.saveTelegramWhitelist(
      backendUrl,
      values,
      agentId: _scopedAgentId,
    );
    settings = <String, dynamic>{
      ...settings,
      'platform_whitelist_telegram': values,
    };
    notifyListeners();
  }

  Future<void> saveMessagingWhitelist(
    String platform,
    List<String> values,
  ) async {
    await _backendClient.saveMessagingWhitelist(
      backendUrl,
      platform: platform,
      ids: values,
      agentId: _scopedAgentId,
    );
    settings = <String, dynamic>{
      ...settings,
      'platform_whitelist_$platform': values,
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

  Future<void> saveSchedulerTask({
    int? id,
    required String name,
    required String cronExpression,
    required String prompt,
    String? model,
    bool enabled = true,
    String? agentId,
  }) async {
    await _backendClient.saveSchedulerTask(
      backendUrl,
      id: id,
      name: name,
      cronExpression: cronExpression,
      prompt: prompt,
      model: model,
      enabled: enabled,
      agentId: agentId ?? _scopedAgentId,
    );
    await refreshScheduler();
  }

  Future<void> toggleSchedulerTask(SchedulerTask task) async {
    await _backendClient
        .updateSchedulerTask(backendUrl, task.id, <String, dynamic>{
          'enabled': !task.enabled,
          if (task.agentId != null && task.agentId!.isNotEmpty)
            'agentId': task.agentId,
        });
    await refreshScheduler();
  }

  Future<void> runSchedulerTask(int id) async {
    await _backendClient.runSchedulerTask(backendUrl, id);
    await refreshScheduler();
    await refreshRunsOnly();
  }

  Future<void> deleteSchedulerTask(int id) async {
    await _backendClient.deleteSchedulerTask(backendUrl, id);
    await refreshScheduler();
  }

  Future<void> saveMcpServer({
    int? id,
    required String name,
    required String command,
    required Map<String, dynamic> config,
    required bool enabled,
    String? agentId,
  }) async {
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

      final lastRun =
          backendHealthStatus?['lastRun'] as Map<String, dynamic>? ?? const {};
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

    if (lower.contains('invalid credentials')) {
      return 'Your username or password is incorrect.';
    }
    if (lower.contains('registration is closed')) {
      return 'This server is already set up. Sign in with an existing account.';
    }
    if (lower.contains('too many attempts')) {
      return 'Too many sign-in attempts. Please wait and try again.';
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
    if (_shouldExposeErrorText(text)) {
      return _extractMeaningfulErrorDetails(text);
    }

    return 'Something went wrong. Please try again.';
  }

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

  bool get headlessBrowser =>
      settings['headless_browser'] != false &&
      settings['headless_browser'] != 'false';

  String get browserBackend =>
      settings['browser_backend']?.toString().trim().toLowerCase() ?? 'host';

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
    if (browser == 'host' || browser == 'vm') {
      return browser;
    }
    if (runtime == 'vm') return 'vm';
    return 'host';
  }

  bool get browserExtensionConnected =>
      browserExtensionStatus['connected'] == true;

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

  String get fallbackModel =>
      settings['fallback_model_id']?.toString() ??
      _firstAvailableModelId(supportedModels);

  String get accountLabel =>
      user?['username']?.toString() ?? username.ifEmpty('NeoAgent User');

  String get modelIndicator {
    if (defaultChatModel != 'auto') {
      final selected = _modelById(defaultChatModel);
      return selected?.label ?? defaultChatModel;
    }
    return smarterSelector ? 'Smart selector active' : 'Manual routing';
  }

  bool get showHealthSection =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get showWearablesSection => !kIsWeb;

  Future<void> _syncBackgroundHealthConfig() async {
    final cookie = _backendClient.sessionCookie ?? '';
    await _prefs?.setString('health_sync_backend_url', backendUrl);
    await _prefs?.setString('health_sync_session_cookie', cookie);
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
    if (streamingAssistant.trim().isNotEmpty) {
      entries.add(
        ChatEntry(
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
      notifyListeners();
    });
    socket.onDisconnect((_) {
      socketConnected = false;
      notifyListeners();
    });
    socket.onConnectError((dynamic _) {
      socketConnected = false;
      notifyListeners();
    });
    socket.on('server:log_history', (dynamic data) {
      final next = <LogEntry>[];
      if (data is List) {
        for (final item in data) {
          next.add(LogEntry.fromJson(_jsonMap(item)));
        }
      }
      logs = next;
      notifyListeners();
    });
    socket.on('server:log', (dynamic data) {
      final next = <LogEntry>[...logs, LogEntry.fromJson(_jsonMap(data))];
      logs = next.length > 400 ? next.sublist(next.length - 400) : next;
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
      if (data is! List) {
        return;
      }
      officialIntegrations = data
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (item) => OfficialIntegrationItem.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList();
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
    socket.on('run:start', (dynamic data) {
      final payload = _jsonMap(data);
      final triggerSource = payload['triggerSource']?.toString() ?? '';
      final runId = payload['runId']?.toString() ?? '';
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
      if (_backgroundRunIds.contains(runId)) {
        return;
      }
      final steps = (payload['steps'] as List<dynamic>? ?? const <dynamic>[])
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
      if (_backgroundRunIds.remove(runId)) {
        unawaited(refreshRunsOnly());
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
      if (_backgroundRunIds.remove(runId)) {
        unawaited(refreshRunsOnly());
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
    socket.connect();
    _socket = socket;
  }

  bool _isBackgroundRun(String triggerSource) {
    return triggerSource == 'scheduler' || triggerSource == 'messaging';
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

class DevicesPanel extends StatefulWidget {
  const DevicesPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<DevicesPanel> createState() => _DevicesPanelState();
}

class _DevicesPanelState extends State<DevicesPanel> {
  late final TextEditingController _browserUrlController;
  late final TextEditingController _androidLaunchController;
  late final TextEditingController _textEntryController;
  Timer? _surfaceFrameTimer;
  _DeviceSurface _surface = _DeviceSurface.browser;

  @override
  void initState() {
    super.initState();
    _browserUrlController = TextEditingController(text: _browserUrlPlaceholder);
    _androidLaunchController = TextEditingController(
      text: _androidLaunchPlaceholder,
    );
    _textEntryController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_bootstrapSurface());
    });
    _surfaceFrameTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_refreshSurfaceFrame());
    });
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _browserUrlController,
      _androidLaunchController,
      _textEntryController,
    ]) {
      controller.dispose();
    }
    _surfaceFrameTimer?.cancel();
    super.dispose();
  }

  bool get _isBrowser => _surface == _DeviceSurface.browser;

  bool get _androidOnline {
    final status = widget.controller.androidRuntime;
    final devices = (status['devices'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<dynamic, dynamic>>();
    return devices.any((device) => device['status']?.toString() == 'device');
  }

  bool get _androidStarting =>
      widget.controller.androidRuntime['starting'] == true;

  String? get _activeScreenshotPath => _isBrowser
      ? widget.controller.browserScreenshotPath
      : widget.controller.androidScreenshotPath;

  Future<void> _bootstrapSurface() async {
    await widget.controller.refreshDevices();
    await _ensurePreview();
  }

  Future<void> _ensurePreview() async {
    final controller = widget.controller;
    if (_isBrowser) {
      if (controller.browserRuntime['launched'] != true) {
        return;
      }
      if ((controller.browserScreenshotPath ?? '').isEmpty) {
        final currentUrl =
            controller.browserRuntime['pageInfo'] is Map<dynamic, dynamic>
            ? (controller.browserRuntime['pageInfo'] as Map)['url']?.toString()
            : null;
        if (currentUrl != null && currentUrl.isNotEmpty) {
          await controller.navigateBrowserRuntime(url: currentUrl);
        } else {
          await controller.screenshotBrowserRuntime();
        }
      }
      return;
    }

    if (_androidOnline && (controller.androidScreenshotPath ?? '').isEmpty) {
      await controller.screenshotAndroidRuntime();
    }
  }

  Future<void> _refreshSurfaceFrame() async {
    if (!mounted ||
        widget.controller.selectedSection != AppSection.devices ||
        widget.controller.isRunningDeviceAction ||
        widget.controller.isRefreshingDevices) {
      return;
    }
    if (_isBrowser) {
      await widget.controller.refreshBrowserFrameRuntime();
      return;
    }
    if (_androidStarting) {
      await widget.controller.refreshDevices();
      if (_androidOnline &&
          (widget.controller.androidScreenshotPath ?? '').isEmpty) {
        await widget.controller.screenshotAndroidRuntime();
      }
      return;
    }
    await widget.controller.refreshAndroidFrameRuntime();
  }

  Future<void> _switchSurface(int delta) async {
    final surfaces = _DeviceSurface.values;
    final currentIndex = surfaces.indexOf(_surface);
    final nextIndex = (currentIndex + delta) % surfaces.length;
    setState(
      () =>
          _surface = surfaces[nextIndex < 0 ? surfaces.length - 1 : nextIndex],
    );
    await _ensurePreview();
  }

  Future<void> _openPrimary() async {
    final controller = widget.controller;
    if (_isBrowser) {
      await controller.navigateBrowserRuntime(
        url: _browserUrlController.text.trim(),
      );
      return;
    }

    if (!_androidOnline) {
      await controller.startAndroidRuntime();
      await widget.controller.refreshDevices();
      if (_androidOnline) {
        await controller.screenshotAndroidRuntime();
      }
      return;
    }

    final raw = _androidLaunchController.text.trim();
    if (raw.isEmpty) {
      return;
    }
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      await controller.openAndroidIntentRuntime(
        action: 'android.intent.action.VIEW',
        dataUri: raw,
      );
      return;
    }
    await controller.openAndroidAppRuntime(packageName: raw);
  }

  Future<void> _sleepPrimary() async {
    final controller = widget.controller;
    if (_isBrowser) {
      if (controller.browserRuntime['launched'] != true) {
        return;
      }
      await controller.closeBrowserRuntime();
      return;
    }
    if (!_androidOnline) {
      return;
    }
    await controller.stopAndroidRuntime();
  }

  Future<void> _sendText() async {
    final text = _textEntryController.text;
    if (text.trim().isEmpty) {
      return;
    }
    if (_isBrowser) {
      await widget.controller.typeBrowserTextRuntime(text, pressEnter: true);
    } else {
      await widget.controller.typeAndroidRuntime(<String, dynamic>{
        'text': text,
        'pressEnter': true,
      });
    }
  }

  Future<void> _handleTap(Offset point) async {
    if (_isBrowser) {
      await widget.controller.clickBrowserPointRuntime(
        x: point.dx.round(),
        y: point.dy.round(),
      );
      return;
    }
    if (!_androidOnline) {
      await widget.controller.startAndroidRuntime();
      return;
    }
    await widget.controller.tapAndroidRuntime(<String, dynamic>{
      'x': point.dx.round(),
      'y': point.dy.round(),
    });
  }

  Future<void> _handleSwipe(Offset start, Offset end) async {
    if (_isBrowser) {
      await widget.controller.scrollBrowserRuntime(
        deltaY: (start.dy - end.dy).round(),
      );
      return;
    }
    if (!_androidOnline) {
      return;
    }
    await widget.controller.swipeAndroidRuntime(<String, dynamic>{
      'x1': start.dx.round(),
      'y1': start.dy.round(),
      'x2': end.dx.round(),
      'y2': end.dy.round(),
      'durationMs': 280,
    });
  }

  Future<void> _runQuickAction(String action) async {
    final controller = widget.controller;
    switch (action) {
      case 'browser_refresh':
        await controller.navigateBrowserRuntime(
          url: controller.browserRuntime['pageInfo'] is Map<dynamic, dynamic>
              ? ((controller.browserRuntime['pageInfo'] as Map)['url']
                        ?.toString() ??
                    _browserUrlController.text.trim())
              : _browserUrlController.text.trim(),
        );
        break;
      case 'browser_enter':
        await controller.pressBrowserKeyRuntime('Enter');
        break;
      case 'android_back':
        await controller.pressAndroidKeyRuntime('back');
        break;
      case 'android_home':
        await controller.pressAndroidKeyRuntime('home');
        break;
      case 'android_recent':
        await controller.pressAndroidKeyRuntime('app_switch');
        break;
      case 'surface_refresh':
        await _ensurePreview();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final browserStatus = controller.browserRuntime;
    final usingExtension = controller.browserBackend == 'extension';
    final extensionConnected = controller.browserExtensionConnected;
    final browserPageInfo = browserStatus['pageInfo'] is Map<dynamic, dynamic>
        ? Map<String, dynamic>.from(browserStatus['pageInfo'] as Map)
        : const <String, dynamic>{};
    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Remote Device',
          subtitle:
              'Tap, swipe, and type directly on the live surface. Use the arrows below to switch between browser and phone.',
          trailing: OutlinedButton.icon(
            onPressed:
                controller.isRefreshingDevices ||
                    controller.isRunningDeviceAction
                ? null
                : _bootstrapSurface,
            icon: Icon(Icons.sync),
            label: Text('Sync Surface'),
          ),
        ),
        if (controller.errorMessage case final message?)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _InlineError(message: message),
          ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Card(
              color: _bgCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(color: _borderLight),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: <Widget>[
                    _DeviceSurfaceHeader(
                      surface: _surface,
                      browserStatus: browserStatus,
                      browserPageInfo: browserPageInfo,
                      androidRuntime: controller.androidRuntime,
                      androidOnline: _androidOnline,
                      usingBrowserExtension: usingExtension,
                      browserExtensionConnected: extensionConnected,
                    ),
                    const SizedBox(height: 16),
                    _DeviceLaunchBar(
                      surface: _surface,
                      controller: _isBrowser
                          ? _browserUrlController
                          : _androidLaunchController,
                      active: _isBrowser
                          ? browserStatus['launched'] == true
                          : _androidOnline || _androidStarting,
                      starting: !_isBrowser && _androidStarting,
                      busy: controller.isRunningDeviceAction,
                      onSubmit: _openPrimary,
                      onSleep: _sleepPrimary,
                    ),
                    const SizedBox(height: 18),
                    _InteractiveSurfacePreview(
                      surface: _surface,
                      controller: controller,
                      screenshotPath: _activeScreenshotPath,
                      busy: controller.isRunningDeviceAction,
                      wakingUp: !_isBrowser && _androidStarting,
                      enabled: _isBrowser || _androidOnline,
                      connectRequired:
                          _isBrowser && usingExtension && !extensionConnected,
                      onTapPoint: _handleTap,
                      onSwipe: _handleSwipe,
                      onWakeRequested: _openPrimary,
                    ),
                    if (!_isBrowser) ...<Widget>[
                      const SizedBox(height: 12),
                      _AndroidNavDock(
                        busy: controller.isRunningDeviceAction,
                        androidOnline: _androidOnline,
                        onAction: _runQuickAction,
                      ),
                      if (kIsWeb) ...<Widget>[
                        const SizedBox(height: 14),
                        AndroidApkDropZone(
                          enabled: _androidOnline,
                          busy: controller.isRunningDeviceAction,
                          onInstall: ({required filename, required bytes}) {
                            return controller.installAndroidApkRuntime(
                              filename: filename,
                              bytes: bytes,
                            );
                          },
                        ),
                      ],
                    ],
                    const SizedBox(height: 18),
                    _DeviceTypeDock(
                      controller: _textEntryController,
                      busy: controller.isRunningDeviceAction,
                      surface: _surface,
                      onSubmit: _sendText,
                    ),
                    if (_isBrowser) ...<Widget>[
                      const SizedBox(height: 14),
                      _DeviceQuickActions(
                        surface: _surface,
                        androidOnline: _androidOnline,
                        busy: controller.isRunningDeviceAction,
                        onAction: _runQuickAction,
                      ),
                    ],
                    const SizedBox(height: 14),
                    _SurfaceSwitcher(
                      surface: _surface,
                      onPrevious: () => _switchSurface(-1),
                      onNext: () => _switchSurface(1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _DeviceSurface { browser, android }

extension _DeviceSurfaceX on _DeviceSurface {
  String get label => this == _DeviceSurface.browser ? 'Browser' : 'Phone';

  String get helper => this == _DeviceSurface.browser
      ? 'Tap to click. Drag to scroll.'
      : 'Tap to touch. Drag to swipe.';

  IconData get icon => this == _DeviceSurface.browser
      ? Icons.language_outlined
      : Icons.smartphone_outlined;
}

class _DeviceSurfaceHeader extends StatelessWidget {
  const _DeviceSurfaceHeader({
    required this.surface,
    required this.browserStatus,
    required this.browserPageInfo,
    required this.androidRuntime,
    required this.androidOnline,
    required this.usingBrowserExtension,
    required this.browserExtensionConnected,
  });

  final _DeviceSurface surface;
  final Map<String, dynamic> browserStatus;
  final Map<String, dynamic> browserPageInfo;
  final Map<String, dynamic> androidRuntime;
  final bool androidOnline;
  final bool usingBrowserExtension;
  final bool browserExtensionConnected;

  @override
  Widget build(BuildContext context) {
    final androidStarting = androidRuntime['starting'] == true;
    final androidVersion = _androidRuntimeVersionLabel(androidRuntime);
    final title = surface == _DeviceSurface.browser
        ? (browserPageInfo['title']?.toString().trim().isNotEmpty ?? false)
              ? browserPageInfo['title'].toString()
              : 'Live Browser'
        : 'Android Phone';
    final subtitle = surface == _DeviceSurface.browser
        ? usingBrowserExtension && !browserExtensionConnected
              ? 'Chrome extension backend selected. Pair and connect the extension before using the live surface.'
              : (browserPageInfo['url']?.toString() ?? 'Ready for navigation')
        : (androidOnline
              ? androidVersion == null
                    ? 'Tap and swipe directly on the preview.'
                    : '$androidVersion · Tap and swipe directly on the preview.'
              : androidStarting
              ? (androidRuntime['startupPhase']?.toString().trim().isNotEmpty ??
                        false)
                    ? androidRuntime['startupPhase'].toString()
                    : 'Starting the phone. This can take a little while.'
              : (androidRuntime['lastLogLine']?.toString().trim().isNotEmpty ??
                    false)
              ? androidRuntime['lastLogLine'].toString()
              : androidVersion != null
              ? '$androidVersion selected. Phone is offline.'
              : 'Phone is offline. Open or start it from below.');

    return Row(
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _accentMuted,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(surface.icon, color: _textPrimary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _DotStatus(
          label: surface == _DeviceSurface.browser
              ? usingBrowserExtension
                    ? (browserExtensionConnected ? 'Extension' : 'Pairing')
                    : (browserStatus['launched'] == true ? 'Live' : 'Sleeping')
              : (androidOnline
                    ? 'Live'
                    : androidStarting
                    ? 'Starting'
                    : 'Offline'),
          color:
              (surface == _DeviceSurface.browser
                  ? browserStatus['launched'] == true
                  : androidOnline)
              ? _success
              : (surface == _DeviceSurface.android && androidStarting)
              ? _accent
              : _warning,
        ),
      ],
    );
  }
}

class _DeviceLaunchBar extends StatelessWidget {
  const _DeviceLaunchBar({
    required this.surface,
    required this.controller,
    required this.active,
    required this.starting,
    required this.busy,
    required this.onSubmit,
    required this.onSleep,
  });

  final _DeviceSurface surface;
  final TextEditingController controller;
  final bool active;
  final bool starting;
  final bool busy;
  final Future<void> Function() onSubmit;
  final Future<void> Function() onSleep;

  @override
  Widget build(BuildContext context) {
    final hint = surface == _DeviceSurface.browser
        ? _browserUrlPlaceholder
        : _packageOrUrlHint;
    final buttonLabel = surface == _DeviceSurface.browser
        ? 'Open'
        : starting
        ? 'Starting...'
        : 'Launch';
    final sleepLabel = surface == _DeviceSurface.browser
        ? 'Sleep Browser'
        : 'Sleep Phone';
    final narrow = MediaQuery.sizeOf(context).width < 720;

    final input = TextField(
      controller: controller,
      onSubmitted: (_) => onSubmit(),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(
          surface == _DeviceSurface.browser
              ? Icons.travel_explore
              : Icons.open_in_new,
        ),
      ),
    );

    final button = FilledButton.icon(
      onPressed: busy || starting ? null : onSubmit,
      icon: Icon(
        surface == _DeviceSurface.browser
            ? Icons.arrow_forward
            : Icons.play_arrow,
      ),
      label: Text(buttonLabel),
    );
    final sleepButton = OutlinedButton.icon(
      onPressed: busy || !active ? null : onSleep,
      icon: Icon(Icons.bedtime_outlined),
      label: Text(sleepLabel),
    );

    if (narrow) {
      return Column(
        children: <Widget>[
          input,
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(child: button),
              const SizedBox(width: 10),
              Expanded(child: sleepButton),
            ],
          ),
        ],
      );
    }

    return Row(
      children: <Widget>[
        Expanded(child: input),
        const SizedBox(width: 10),
        sleepButton,
        const SizedBox(width: 10),
        button,
      ],
    );
  }
}

class _DeviceTypeDock extends StatelessWidget {
  const _DeviceTypeDock({
    required this.controller,
    required this.busy,
    required this.surface,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool busy;
  final _DeviceSurface surface;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final hint = surface == _DeviceSurface.browser
        ? 'Type into the currently focused field'
        : 'Type into the current phone field';
    final narrow = MediaQuery.sizeOf(context).width < 720;

    final input = TextField(
      controller: controller,
      onSubmitted: (_) => onSubmit(),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(Icons.keyboard_outlined),
      ),
    );

    final button = FilledButton.icon(
      onPressed: busy ? null : onSubmit,
      icon: Icon(Icons.send_rounded),
      label: Text('Send'),
    );

    if (narrow) {
      return Column(
        children: <Widget>[
          input,
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: button),
        ],
      );
    }

    return Row(
      children: <Widget>[
        Expanded(child: input),
        const SizedBox(width: 10),
        button,
      ],
    );
  }
}

class _DeviceQuickActions extends StatelessWidget {
  const _DeviceQuickActions({
    required this.surface,
    required this.androidOnline,
    required this.busy,
    required this.onAction,
  });

  final _DeviceSurface surface;
  final bool androidOnline;
  final bool busy;
  final Future<void> Function(String action) onAction;

  @override
  Widget build(BuildContext context) {
    final actions = const <MapEntry<String, IconData>>[
      MapEntry<String, IconData>('surface_refresh', Icons.refresh_rounded),
      MapEntry<String, IconData>('browser_refresh', Icons.replay_rounded),
      MapEntry<String, IconData>(
        'browser_enter',
        Icons.keyboard_return_rounded,
      ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: actions.map((entry) {
        final disabled =
            busy ||
            (surface != _DeviceSurface.browser &&
                entry.key.startsWith('browser_')) ||
            (!androidOnline && entry.key.startsWith('android_'));
        return InkWell(
          onTap: disabled ? null : () => onAction(entry.key),
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: disabled ? _bgSecondary : _bgTertiary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borderLight),
            ),
            child: Icon(
              entry.value,
              color: disabled ? _textMuted : _textPrimary,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _AndroidNavDock extends StatelessWidget {
  const _AndroidNavDock({
    required this.busy,
    required this.androidOnline,
    required this.onAction,
  });

  final bool busy;
  final bool androidOnline;
  final Future<void> Function(String action) onAction;

  @override
  Widget build(BuildContext context) {
    const actions = <MapEntry<String, IconData>>[
      MapEntry<String, IconData>('surface_refresh', Icons.refresh_rounded),
      MapEntry<String, IconData>('android_back', Icons.arrow_back_rounded),
      MapEntry<String, IconData>('android_home', Icons.home_rounded),
      MapEntry<String, IconData>('android_recent', Icons.crop_square_rounded),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: actions.map((entry) {
          final disabled =
              busy || (!androidOnline && entry.key.startsWith('android_'));
          return IconButton.filledTonal(
            onPressed: disabled ? null : () => onAction(entry.key),
            icon: Icon(entry.value),
          );
        }).toList(),
      ),
    );
  }
}

class _SurfaceSwitcher extends StatelessWidget {
  const _SurfaceSwitcher({
    required this.surface,
    required this.onPrevious,
    required this.onNext,
  });

  final _DeviceSurface surface;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        IconButton.filledTonal(
          onPressed: onPrevious,
          icon: Icon(Icons.arrow_back_ios_new_rounded),
        ),
        const SizedBox(width: 14),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              surface.label,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(surface.helper, style: TextStyle(color: _textSecondary)),
          ],
        ),
        const SizedBox(width: 14),
        IconButton.filledTonal(
          onPressed: onNext,
          icon: Icon(Icons.arrow_forward_ios_rounded),
        ),
      ],
    );
  }
}

class _InteractiveSurfacePreview extends StatefulWidget {
  const _InteractiveSurfacePreview({
    required this.surface,
    required this.controller,
    required this.screenshotPath,
    required this.busy,
    required this.wakingUp,
    required this.enabled,
    required this.connectRequired,
    required this.onTapPoint,
    required this.onSwipe,
    required this.onWakeRequested,
  });

  final _DeviceSurface surface;
  final NeoAgentController controller;
  final String? screenshotPath;
  final bool busy;
  final bool wakingUp;
  final bool enabled;
  final bool connectRequired;
  final Future<void> Function(Offset point) onTapPoint;
  final Future<void> Function(Offset start, Offset end) onSwipe;
  final Future<void> Function() onWakeRequested;

  @override
  State<_InteractiveSurfacePreview> createState() =>
      _InteractiveSurfacePreviewState();
}

class _InteractiveSurfacePreviewState
    extends State<_InteractiveSurfacePreview> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  Size? _pixelSize;
  Uint8List? _imageBytes;
  Object? _imageError;
  Offset? _dragStart;
  Offset? _dragEnd;

  @override
  void initState() {
    super.initState();
    unawaited(_loadImage());
  }

  @override
  void didUpdateWidget(covariant _InteractiveSurfacePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.screenshotPath != widget.screenshotPath) {
      unawaited(_loadImage());
    }
  }

  @override
  void dispose() {
    _detachImageListener();
    super.dispose();
  }

  void _detachImageListener() {
    if (_imageStream != null && _imageListener != null) {
      _imageStream!.removeListener(_imageListener!);
    }
    _imageStream = null;
    _imageListener = null;
  }

  Future<void> _loadImage() async {
    _detachImageListener();
    final path = widget.screenshotPath;
    if (path == null || path.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pixelSize = null;
        _imageBytes = null;
        _imageError = null;
      });
      return;
    }
    try {
      final bytes = await widget.controller.fetchRuntimeAssetBytes(path);
      if (!mounted || widget.screenshotPath != path) {
        return;
      }
      setState(() {
        _imageBytes = bytes;
        _imageError = null;
        _pixelSize = null;
      });
      final provider = MemoryImage(bytes);
      final stream = provider.resolve(const ImageConfiguration());
      final listener = ImageStreamListener((image, _) {
        if (!mounted || widget.screenshotPath != path) {
          return;
        }
        setState(() {
          _pixelSize = Size(
            image.image.width.toDouble(),
            image.image.height.toDouble(),
          );
        });
      });
      _imageStream = stream;
      _imageListener = listener;
      stream.addListener(listener);
    } catch (error) {
      if (!mounted || widget.screenshotPath != path) {
        return;
      }
      setState(() {
        _imageBytes = null;
        _pixelSize = null;
        _imageError = error;
      });
    }
  }

  Offset? _mapToPixels(Offset localPosition, Size boxSize) {
    final pixelSize = _pixelSize;
    if (pixelSize == null) {
      return null;
    }
    final boxAspect = boxSize.width / boxSize.height;
    final imageAspect = pixelSize.width / pixelSize.height;
    late final double renderWidth;
    late final double renderHeight;
    late final double offsetX;
    late final double offsetY;

    if (boxAspect > imageAspect) {
      renderHeight = boxSize.height;
      renderWidth = renderHeight * imageAspect;
      offsetX = (boxSize.width - renderWidth) / 2;
      offsetY = 0;
    } else {
      renderWidth = boxSize.width;
      renderHeight = renderWidth / imageAspect;
      offsetX = 0;
      offsetY = (boxSize.height - renderHeight) / 2;
    }

    if (localPosition.dx < offsetX ||
        localPosition.dx > offsetX + renderWidth ||
        localPosition.dy < offsetY ||
        localPosition.dy > offsetY + renderHeight) {
      return null;
    }

    return Offset(
      ((localPosition.dx - offsetX) / renderWidth) * pixelSize.width,
      ((localPosition.dy - offsetY) / renderHeight) * pixelSize.height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.screenshotPath;
    final hasImage = path != null && path.isNotEmpty;
    final aspectRatio = widget.surface == _DeviceSurface.browser
        ? 16 / 10
        : 10 / 16;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[_bgTertiary, _bgSecondary],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderLight),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: <Widget>[
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: widget.surface == _DeviceSurface.browser ? 560 : 640,
            ),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final boxSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    if (!hasImage) {
                      return _EmptySurfaceState(
                        surface: widget.surface,
                        enabled: widget.enabled,
                        busy: widget.busy,
                        isLoadingPreview: widget.wakingUp,
                        connectRequired: widget.connectRequired,
                        errorMessage: _imageError?.toString(),
                        onPressed: widget.onWakeRequested,
                      );
                    }
                    final imageBytes = _imageBytes;
                    if (imageBytes == null) {
                      return _EmptySurfaceState(
                        surface: widget.surface,
                        enabled: widget.enabled,
                        busy: widget.busy,
                        isLoadingPreview: _imageError == null,
                        connectRequired: widget.connectRequired,
                        errorMessage: _imageError?.toString(),
                        onPressed: widget.onWakeRequested,
                      );
                    }
                    return GestureDetector(
                      onTapUp: widget.busy
                          ? null
                          : (details) async {
                              final point = _mapToPixels(
                                details.localPosition,
                                boxSize,
                              );
                              if (point != null) {
                                await widget.onTapPoint(point);
                              }
                            },
                      onPanStart: widget.busy
                          ? null
                          : (details) {
                              _dragStart = details.localPosition;
                              _dragEnd = details.localPosition;
                            },
                      onPanUpdate: widget.busy
                          ? null
                          : (details) {
                              _dragEnd = details.localPosition;
                            },
                      onPanEnd: widget.busy
                          ? null
                          : (_) async {
                              final start = _dragStart;
                              final end = _dragEnd;
                              _dragStart = null;
                              _dragEnd = null;
                              if (start == null || end == null) {
                                return;
                              }
                              if ((start - end).distance < 12) {
                                return;
                              }
                              final mappedStart = _mapToPixels(start, boxSize);
                              final mappedEnd = _mapToPixels(end, boxSize);
                              if (mappedStart != null && mappedEnd != null) {
                                await widget.onSwipe(mappedStart, mappedEnd);
                              }
                            },
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          Container(color: _bgSecondary),
                          Image.memory(
                            imageBytes,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xB205080D),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _borderLight),
                              ),
                              child: Text(
                                widget.surface.helper,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: _textPrimary),
                              ),
                            ),
                          ),
                          if (widget.busy)
                            const Center(child: CircularProgressIndicator()),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySurfaceState extends StatelessWidget {
  const _EmptySurfaceState({
    required this.surface,
    required this.enabled,
    required this.busy,
    required this.isLoadingPreview,
    required this.connectRequired,
    this.errorMessage,
    required this.onPressed,
  });

  final _DeviceSurface surface;
  final bool enabled;
  final bool busy;
  final bool isLoadingPreview;
  final bool connectRequired;
  final String? errorMessage;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final label = surface == _DeviceSurface.browser
        ? connectRequired
              ? 'Open Settings'
              : (busy ? 'Opening Browser...' : 'Wake Browser')
        : busy
        ? 'Starting Phone...'
        : (enabled ? 'Refresh Phone' : 'Start Phone');
    final message = switch ((surface, busy, isLoadingPreview)) {
      (_DeviceSurface.browser, true, _) =>
        'Opening the browser and downloading the first preview...',
      (_DeviceSurface.browser, false, true) =>
        'Downloading the latest browser preview...',
      (_DeviceSurface.android, true, _) =>
        'Waking the phone and downloading the first preview. This can take a little while.',
      (_DeviceSurface.android, false, true) =>
        'Downloading the latest phone preview...',
      _ =>
        surface == _DeviceSurface.browser
            ? connectRequired
                  ? 'Chrome extension is not connected. Use Settings to download, load, and pair the extension on the remote machine.'
                  : 'Browser is sleeping. Press Open to start it.'
            : (errorMessage != null && errorMessage!.trim().isNotEmpty)
            ? errorMessage!
            : 'Phone is offline. Press Start Phone to boot it.',
    };
    return Container(
      color: _bgSecondary,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (busy || isLoadingPreview) ...<Widget>[
            const SizedBox(
              width: 38,
              height: 38,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 14),
          ] else
            Icon(surface.icon, size: 46, color: _textSecondary),
          if (!(busy || isLoadingPreview)) const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: _textSecondary),
            textAlign: TextAlign.center,
          ),
          if (errorMessage != null &&
              surface == _DeviceSurface.browser &&
              errorMessage!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: _textMuted, fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: busy ? null : onPressed,
            icon: Icon(Icons.play_arrow_rounded),
            label: Text(label),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _RuntimeControlCard extends StatelessWidget {
  const _RuntimeControlCard({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget status;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(color: _textSecondary, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                status,
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _BrowserControls extends StatelessWidget {
  const _BrowserControls({
    required this.controller,
    required this.browserStatus,
    required this.browserPageInfo,
    required this.urlController,
    required this.waitForController,
    required this.clickSelectorController,
    required this.clickTextController,
    required this.fillSelectorController,
    required this.fillValueController,
  });

  final NeoAgentController controller;
  final Map<String, dynamic> browserStatus;
  final Map<String, dynamic> browserPageInfo;
  final TextEditingController urlController;
  final TextEditingController waitForController;
  final TextEditingController clickSelectorController;
  final TextEditingController clickTextController;
  final TextEditingController fillSelectorController;
  final TextEditingController fillValueController;

  @override
  Widget build(BuildContext context) {
    final launched = browserStatus['launched'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _MetaPill(
              label: launched ? 'Launched' : 'Idle',
              icon: Icons.language_outlined,
            ),
            _MetaPill(
              label: 'Pages ${browserStatus['pages'] ?? 0}',
              icon: Icons.filter_none_outlined,
            ),
            _MetaPill(
              label: browserStatus['headless'] == false
                  ? 'Visible window'
                  : 'Headless',
              icon: Icons.visibility_outlined,
            ),
          ],
        ),
        if ((browserPageInfo['url']?.toString().isNotEmpty ?? false) ||
            (browserPageInfo['title']?.toString().isNotEmpty ??
                false)) ...<Widget>[
          const SizedBox(height: 14),
          SelectableText(
            '${browserPageInfo['title'] ?? 'Untitled'}\n${browserPageInfo['url'] ?? ''}',
            style: TextStyle(color: _textSecondary, height: 1.5),
          ),
        ],
        const SizedBox(height: 18),
        _DeviceFieldRow(
          children: <Widget>[
            _DeviceField(
              label: 'URL',
              child: TextField(controller: urlController),
            ),
            _DeviceField(
              label: 'Wait For Selector',
              child: TextField(controller: waitForController),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            FilledButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : controller.launchBrowserRuntime,
              icon: Icon(Icons.rocket_launch_outlined),
              label: Text('Launch'),
            ),
            FilledButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : () => controller.navigateBrowserRuntime(
                      url: urlController.text.trim(),
                      waitFor: waitForController.text.trim(),
                    ),
              icon: Icon(Icons.open_in_browser_outlined),
              label: Text('Navigate'),
            ),
            OutlinedButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : controller.screenshotBrowserRuntime,
              icon: Icon(Icons.photo_camera_back_outlined),
              label: Text('Screenshot'),
            ),
            OutlinedButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : controller.closeBrowserRuntime,
              icon: Icon(Icons.close),
              label: Text('Close'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _DeviceFieldRow(
          children: <Widget>[
            _DeviceField(
              label: 'Click Selector',
              child: TextField(controller: clickSelectorController),
            ),
            _DeviceField(
              label: 'Click Text',
              child: TextField(controller: clickTextController),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            OutlinedButton(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : () => controller.clickBrowserRuntime(
                      selector: clickSelectorController.text.trim(),
                    ),
              child: Text('Click Selector'),
            ),
            OutlinedButton(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : () => controller.clickBrowserRuntime(
                      text: clickTextController.text.trim(),
                    ),
              child: Text('Click Text'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _DeviceFieldRow(
          children: <Widget>[
            _DeviceField(
              label: 'Type Selector',
              child: TextField(controller: fillSelectorController),
            ),
            _DeviceField(
              label: 'Value',
              child: TextField(controller: fillValueController),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: controller.isRunningDeviceAction
              ? null
              : () => controller.fillBrowserRuntime(
                  selector: fillSelectorController.text.trim(),
                  value: fillValueController.text,
                ),
          icon: Icon(Icons.keyboard_outlined),
          label: Text('Type Into Field'),
        ),
        const SizedBox(height: 18),
        _RuntimePreview(
          title: 'Latest Browser Screenshot',
          screenshotPath: controller.browserScreenshotPath,
          controller: controller,
        ),
        if (controller.browserLastResult?.trim().isNotEmpty ??
            false) ...<Widget>[
          const SizedBox(height: 14),
          _ResultBlock(
            label: 'Last browser result',
            value: controller.browserLastResult!,
          ),
        ],
      ],
    );
  }
}

// ignore: unused_element
class _AndroidControls extends StatelessWidget {
  const _AndroidControls({
    required this.controller,
    required this.androidStatus,
    required this.androidDevices,
    required this.packageController,
    required this.activityController,
    required this.intentActionController,
    required this.intentDataController,
    required this.tapTextController,
    required this.tapDescriptionController,
    required this.tapResourceIdController,
    required this.tapXController,
    required this.tapYController,
    required this.typeTextController,
    required this.typeFieldTextController,
    required this.typeFieldDescriptionController,
    required this.waitTextController,
    required this.keyController,
    required this.swipeX1Controller,
    required this.swipeY1Controller,
    required this.swipeX2Controller,
    required this.swipeY2Controller,
    required this.toInt,
  });

  final NeoAgentController controller;
  final Map<String, dynamic> androidStatus;
  final List<Map<String, dynamic>> androidDevices;
  final TextEditingController packageController;
  final TextEditingController activityController;
  final TextEditingController intentActionController;
  final TextEditingController intentDataController;
  final TextEditingController tapTextController;
  final TextEditingController tapDescriptionController;
  final TextEditingController tapResourceIdController;
  final TextEditingController tapXController;
  final TextEditingController tapYController;
  final TextEditingController typeTextController;
  final TextEditingController typeFieldTextController;
  final TextEditingController typeFieldDescriptionController;
  final TextEditingController waitTextController;
  final TextEditingController keyController;
  final TextEditingController swipeX1Controller;
  final TextEditingController swipeY1Controller;
  final TextEditingController swipeX2Controller;
  final TextEditingController swipeY2Controller;
  final int? Function(String text) toInt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _MetaPill(
              label: androidStatus['bootstrapped'] == true
                  ? 'SDK Ready'
                  : 'Bootstrap Needed',
              icon: Icons.adb_outlined,
            ),
            _MetaPill(
              label: androidStatus['serial']?.toString().isNotEmpty == true
                  ? androidStatus['serial'].toString()
                  : 'No active serial',
              icon: Icons.phone_android_outlined,
            ),
            _MetaPill(
              label: '${androidDevices.length} device(s)',
              icon: Icons.devices_other_outlined,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            FilledButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : controller.startAndroidRuntime,
              icon: Icon(Icons.play_arrow_outlined),
              label: Text('Start Emulator'),
            ),
            OutlinedButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : controller.stopAndroidRuntime,
              icon: Icon(Icons.stop_circle_outlined),
              label: Text('Stop'),
            ),
            OutlinedButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : controller.screenshotAndroidRuntime,
              icon: Icon(Icons.photo_camera_outlined),
              label: Text('Screenshot'),
            ),
            OutlinedButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : controller.dumpAndroidUiRuntime,
              icon: Icon(Icons.data_object_outlined),
              label: Text('Dump UI'),
            ),
            OutlinedButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : controller.refreshAndroidApps,
              icon: Icon(Icons.apps_outlined),
              label: Text('Load Apps'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _DeviceFieldRow(
          children: <Widget>[
            _DeviceField(
              label: 'Package',
              child: TextField(controller: packageController),
            ),
            _DeviceField(
              label: 'Activity',
              child: TextField(controller: activityController),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : () => controller.openAndroidAppRuntime(
                      packageName: packageController.text.trim(),
                      activity: activityController.text.trim(),
                    ),
              icon: Icon(Icons.apps),
              label: Text('Open App'),
            ),
            if (controller.androidInstalledApps.isNotEmpty)
              SizedBox(width: 1, height: 1, child: Container()),
          ],
        ),
        if (controller.androidInstalledApps.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: controller.androidInstalledApps.take(10).map((appId) {
              return ActionChip(
                label: Text(appId),
                onPressed: () => packageController.text = appId,
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 18),
        _DeviceFieldRow(
          children: <Widget>[
            _DeviceField(
              label: 'Intent Action',
              child: TextField(controller: intentActionController),
            ),
            _DeviceField(
              label: 'Intent Data',
              child: TextField(controller: intentDataController),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: controller.isRunningDeviceAction
              ? null
              : () => controller.openAndroidIntentRuntime(
                  action: intentActionController.text.trim(),
                  dataUri: intentDataController.text.trim(),
                  packageName: packageController.text.trim(),
                ),
          icon: Icon(Icons.route_outlined),
          label: Text('Open Intent'),
        ),
        const SizedBox(height: 18),
        _DeviceFieldRow(
          children: <Widget>[
            _DeviceField(
              label: 'Wait For Text',
              child: TextField(controller: waitTextController),
            ),
            _DeviceField(
              label: 'Key',
              child: TextField(controller: keyController),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            OutlinedButton(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : () => controller.waitForAndroidRuntime(<String, dynamic>{
                      'text': waitTextController.text.trim(),
                      'timeoutMs': 20000,
                      'intervalMs': 1200,
                    }),
              child: Text('Wait For UI'),
            ),
            OutlinedButton(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : () => controller.pressAndroidKeyRuntime(
                      keyController.text.trim(),
                    ),
              child: Text('Press Key'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _DeviceFieldRow(
          children: <Widget>[
            _DeviceField(
              label: 'Tap Text',
              child: TextField(controller: tapTextController),
            ),
            _DeviceField(
              label: 'Tap Description',
              child: TextField(controller: tapDescriptionController),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _DeviceFieldRow(
          children: <Widget>[
            _DeviceField(
              label: 'Tap Resource Id',
              child: TextField(controller: tapResourceIdController),
            ),
            _DeviceField(
              label: 'Tap X / Y',
              child: Row(
                children: <Widget>[
                  Expanded(child: TextField(controller: tapXController)),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: tapYController)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: controller.isRunningDeviceAction
              ? null
              : () => controller.tapAndroidRuntime(<String, dynamic>{
                  if (tapTextController.text.trim().isNotEmpty)
                    'text': tapTextController.text.trim(),
                  if (tapDescriptionController.text.trim().isNotEmpty)
                    'description': tapDescriptionController.text.trim(),
                  if (tapResourceIdController.text.trim().isNotEmpty)
                    'resourceId': tapResourceIdController.text.trim(),
                  if (toInt(tapXController.text) != null)
                    'x': toInt(tapXController.text),
                  if (toInt(tapYController.text) != null)
                    'y': toInt(tapYController.text),
                }),
          icon: Icon(Icons.touch_app_outlined),
          label: Text('Tap'),
        ),
        const SizedBox(height: 18),
        _DeviceFieldRow(
          children: <Widget>[
            _DeviceField(
              label: 'Type Text',
              child: TextField(controller: typeTextController),
            ),
            _DeviceField(
              label: 'Focus Field Text / Description',
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(controller: typeFieldTextController),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: typeFieldDescriptionController,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: controller.isRunningDeviceAction
              ? null
              : () => controller.typeAndroidRuntime(<String, dynamic>{
                  'text': typeTextController.text,
                  if (typeFieldTextController.text.trim().isNotEmpty)
                    'textSelector': typeFieldTextController.text.trim(),
                  if (typeFieldDescriptionController.text.trim().isNotEmpty)
                    'description': typeFieldDescriptionController.text.trim(),
                  'pressEnter': true,
                }),
          icon: Icon(Icons.keyboard_outlined),
          label: Text('Type'),
        ),
        const SizedBox(height: 18),
        _DeviceFieldRow(
          children: <Widget>[
            _DeviceField(
              label: 'Swipe X1 / Y1',
              child: Row(
                children: <Widget>[
                  Expanded(child: TextField(controller: swipeX1Controller)),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: swipeY1Controller)),
                ],
              ),
            ),
            _DeviceField(
              label: 'Swipe X2 / Y2',
              child: Row(
                children: <Widget>[
                  Expanded(child: TextField(controller: swipeX2Controller)),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: swipeY2Controller)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: controller.isRunningDeviceAction
              ? null
              : () => controller.swipeAndroidRuntime(<String, dynamic>{
                  'x1': toInt(swipeX1Controller.text),
                  'y1': toInt(swipeY1Controller.text),
                  'x2': toInt(swipeX2Controller.text),
                  'y2': toInt(swipeY2Controller.text),
                }),
          icon: Icon(Icons.swipe_outlined),
          label: Text('Swipe'),
        ),
        const SizedBox(height: 18),
        _RuntimePreview(
          title: 'Latest Android Screenshot',
          screenshotPath: controller.androidScreenshotPath,
          controller: controller,
        ),
        if (controller.androidUiPreview.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          Text(
            'Latest UI dump preview',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...controller.androidUiPreview.take(6).map((node) {
            final title = node['text']?.toString().trim().isNotEmpty == true
                ? node['text'].toString()
                : node['description']?.toString().trim().isNotEmpty == true
                ? node['description'].toString()
                : node['resourceId']?.toString().trim().isNotEmpty == true
                ? node['resourceId'].toString()
                : node['className']?.toString() ?? 'node';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _bgSecondary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Text(
                '$title\n${node['packageName'] ?? ''}',
                style: TextStyle(color: _textSecondary, height: 1.5),
              ),
            );
          }),
        ],
        if (controller.androidLastResult?.trim().isNotEmpty ??
            false) ...<Widget>[
          const SizedBox(height: 14),
          _ResultBlock(
            label: 'Last Android result',
            value: controller.androidLastResult!,
          ),
        ],
      ],
    );
  }
}

class _DeviceFieldRow extends StatelessWidget {
  const _DeviceFieldRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    final stacked = MediaQuery.sizeOf(context).width < 860;
    if (stacked) {
      return Column(
        children: children
            .map(
              (child) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: child,
              ),
            )
            .toList(),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var index = 0; index < children.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(width: 12),
          Expanded(child: children[index]),
        ],
      ],
    );
  }
}

class _DeviceField extends StatelessWidget {
  const _DeviceField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: _textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _RuntimePreview extends StatelessWidget {
  const _RuntimePreview({
    required this.title,
    required this.screenshotPath,
    required this.controller,
  });

  final String title;
  final String? screenshotPath;
  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    if (screenshotPath == null || screenshotPath!.isEmpty) {
      return _EmptyCard(
        title: title,
        subtitle:
            'Run a screenshot-capable action to preview the live runtime.',
      );
    }

    final uri = controller.resolveRuntimeAsset(screenshotPath!);
    return Card(
      color: _bgSecondary,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              screenshotPath!,
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                uri.toString(),
                headers: controller.authenticatedImageHeaders,
                fit: BoxFit.cover,
                errorBuilder: (context, _, __) {
                  return Container(
                    height: 220,
                    color: _bgCard,
                    alignment: Alignment.center,
                    child: Text(
                      'Could not load preview image',
                      style: TextStyle(color: _textSecondary),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultBlock extends StatelessWidget {
  const _ResultBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          SelectableText(
            value,
            style: TextStyle(
              fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
              fontSize: 12,
              color: _textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class WearablesPanel extends StatelessWidget {
  const WearablesPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    final service = controller.wearableService;

    String formatHeyPocketFileMetric(int value) {
      if (value <= 0) {
        return 'unknown length';
      }
      if (value < 36000) {
        return '${value}s';
      }
      return 'len $value';
    }

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final hasBleConnected = service.connectedDevice != null;
        final hasBackgroundOnly =
            service.backgroundBridgeConnected && !hasBleConnected;
        final bridgeWaitingForDevice =
            service.backgroundBridgeActive &&
            !service.backgroundBridgeConnected;
        return ListView(
          padding: _pagePadding(context),
          children: <Widget>[
            const _PageTitle(
              title: 'Wearables (Beta)',
              subtitle: 'Connect and manage your recording hardware devices.',
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 760;
                        final actions = Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            if (!hasBleConnected && service.hasReconnectTarget)
                              OutlinedButton.icon(
                                onPressed: service.isConnecting
                                    ? null
                                    : service.reconnectToPreferredDevice,
                                icon: service.isConnecting
                                    ? const SizedBox.square(
                                        dimension: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(Icons.refresh_rounded),
                                label: Text('Reconnect'),
                              ),
                            if (service.canRequestOfflineSync)
                              FilledButton.tonalIcon(
                                onPressed: service.isOfflineSyncRequestInFlight
                                    ? null
                                    : service.requestHeyPocketOfflineSync,
                                icon: service.isOfflineSyncRequestInFlight
                                    ? const SizedBox.square(
                                        dimension: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(Icons.cloud_sync_outlined),
                                label: Text(
                                  service.isOfflineSyncRequestInFlight
                                      ? 'Requesting sync...'
                                      : 'Sync from device',
                                ),
                              ),
                            OutlinedButton(
                              onPressed:
                                  (hasBleConnected ||
                                      hasBackgroundOnly ||
                                      bridgeWaitingForDevice)
                                  ? service.disconnect
                                  : null,
                              child: Text('Disconnect'),
                            ),
                          ],
                        );

                        final headline = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              hasBleConnected
                                  ? 'Connected: ${service.connectedDevice!.name ?? 'Wearable'}'
                                  : hasBackgroundOnly
                                  ? 'Connected via background bridge: ${service.backgroundBridgeDeviceId ?? 'Wearable'}'
                                  : bridgeWaitingForDevice
                                  ? 'Background bridge enabled (waiting for device)'
                                  : 'No device connected',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            if (!hasBleConnected &&
                                !hasBackgroundOnly &&
                                !bridgeWaitingForDevice)
                              Text(
                                'Scan for nearby Bluetooth recording devices.',
                                style: TextStyle(color: _textSecondary),
                              ),
                          ],
                        );

                        if (!hasBleConnected &&
                            !hasBackgroundOnly &&
                            !bridgeWaitingForDevice) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.watch_off_outlined,
                                    color: _textSecondary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: headline),
                                ],
                              ),
                              const SizedBox(height: 12),
                              actions,
                            ],
                          );
                        }

                        if (compact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Icon(Icons.watch_outlined, color: _success),
                                  const SizedBox(width: 12),
                                  Expanded(child: headline),
                                ],
                              ),
                              const SizedBox(height: 12),
                              actions,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(Icons.watch_outlined, color: _success),
                            const SizedBox(width: 12),
                            Expanded(child: headline),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: actions,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.favorite_outline,
                          color: _textSecondary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            hasBleConnected || hasBackgroundOnly
                                ? 'Your wearable is connected and ready.'
                                : bridgeWaitingForDevice
                                ? 'Bridge is active. Waiting for your wearable to reconnect.'
                                : 'Connect a wearable to start recording from it.',
                            style: TextStyle(color: _textSecondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 8),
                      title: Text(
                        'Technical details',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      children: <Widget>[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            _SyncStatPill(
                              label: 'BLE state',
                              value: service.connectionState.name,
                              icon: Icons.bluetooth_searching,
                            ),
                            _SyncStatPill(
                              label: 'Bridge active',
                              value: service.backgroundBridgeActive
                                  ? 'yes'
                                  : 'no',
                              icon: Icons.settings_ethernet,
                            ),
                            _SyncStatPill(
                              label: 'Bridge connected',
                              value: service.backgroundBridgeConnected
                                  ? 'yes'
                                  : 'no',
                              icon: Icons.link,
                            ),
                            _SyncStatPill(
                              label: 'Device id',
                              value:
                                  service.connectedDevice?.deviceId ??
                                  service.backgroundBridgeDeviceId ??
                                  '-',
                              icon: Icons.badge_outlined,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (service.connectedDevice != null &&
                service.canRequestOfflineSync) ...<Widget>[
              const SizedBox(height: 12),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Container(
                  decoration: BoxDecoration(
                    color: _bgSecondary,
                    border: Border.all(color: _borderLight),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(Icons.sync_alt_rounded, color: _info),
                            SizedBox(width: 8),
                            Text(
                              'HeyPocket Offline Sync',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (service.isOfflineSyncRequestInFlight)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: service.cancelHeyPocketOfflineSync,
                              icon: Icon(Icons.cancel_outlined),
                              label: Text('Cancel sync'),
                            ),
                          ),
                        if (service.isOfflineSyncRequestInFlight)
                          const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            _SyncStatPill(
                              label: 'Status',
                              value: service.heypocketSyncStatus,
                              icon: Icons.info_outline,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: EdgeInsets.zero,
                          title: Text(
                            'Sync details (advanced)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          children: <Widget>[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                _SyncStatPill(
                                  label: 'Listed files',
                                  value:
                                      '${service.heypocketSyncListedFilesCount}',
                                  icon: Icons.queue_music_outlined,
                                ),
                                _SyncStatPill(
                                  label: 'Upload requests',
                                  value:
                                      '${service.heypocketSyncUploadCommandsSent}',
                                  icon: Icons.cloud_upload_outlined,
                                ),
                              ],
                            ),
                            if (service
                                .heypocketSyncListedFiles
                                .isNotEmpty) ...<Widget>[
                              const SizedBox(height: 12),
                              Text(
                                'On-device sync files',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...service.heypocketSyncListedFiles.map((file) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _bgCard,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: _borderLight),
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Text(
                                                file.fileId,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${file.date} • ${formatHeyPocketFileMetric(file.size)}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: _textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () => service
                                              .deleteHeyPocketOfflineFile(file),
                                          icon: Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                          ),
                                          tooltip: 'Delete from device',
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                            if (service
                                .heypocketSyncLastControlMessage
                                .isNotEmpty) ...<Widget>[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _bgPrimary,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _borderLight),
                                ),
                                child: Text(
                                  'Last response: ${service.heypocketSyncLastControlMessage}',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _textSecondary,
                                    fontFamily:
                                        GoogleFonts.jetBrainsMono().fontFamily,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _bgCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _borderLight),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                Icons.tune_rounded,
                                size: 16,
                                color: _textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'Mode',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      service.heypocketModeLabel,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Switch(
                                value: service.heypocketCallModeEnabled,
                                onChanged: service.heypocketModeSwitchInFlight
                                    ? null
                                    : service.setHeyPocketCallMode,
                              ),
                              Text(
                                service.heypocketCallModeEnabled
                                    ? 'Call'
                                    : 'Normal',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Nearby Devices',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                if (service.isScanning)
                  const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton.icon(
                    onPressed: service.startScan,
                    icon: Icon(Icons.search),
                    label: Text('Scan'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (service.scanResults.isEmpty)
              const _EmptyCard(
                title: 'No devices found',
                subtitle:
                    'Ensure your wearable is in pairing mode and Bluetooth is enabled.',
              )
            else
              ...service.scanResults.map((device) {
                final isConnectingThisDevice =
                    service.connectingDeviceId == device.deviceId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      leading: Icon(Icons.bluetooth),
                      title: Text(device.name ?? 'Unknown Device'),
                      subtitle: Text(device.deviceId),
                      trailing: FilledButton(
                        onPressed: isConnectingThisDevice
                            ? null
                            : () => service.connect(device),
                        child: isConnectingThisDevice
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text('Connect'),
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _SyncStatPill extends StatelessWidget {
  const _SyncStatPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 340),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 14, color: _textSecondary),
            const SizedBox(width: 6),
            Text(
              '$label: ',
              style: TextStyle(
                fontSize: 12,
                color: _textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: _textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecordingsPanel extends StatefulWidget {
  const RecordingsPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<RecordingsPanel> createState() => _RecordingsPanelState();
}

class _RecordingsPanelState extends State<RecordingsPanel> {
  @override
  void initState() {
    super.initState();
    widget.controller.wearableService.addListener(_onWearableServiceChanged);
  }

  @override
  void didUpdateWidget(covariant RecordingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(
      oldWidget.controller.wearableService,
      widget.controller.wearableService,
    )) {
      oldWidget.controller.wearableService.removeListener(
        _onWearableServiceChanged,
      );
      widget.controller.wearableService.addListener(_onWearableServiceChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.wearableService.removeListener(_onWearableServiceChanged);
    super.dispose();
  }

  void _onWearableServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _deleteSegment(
    BuildContext context,
    RecordingSessionItem session,
    RecordingTranscriptSegment segment,
  ) async {
    await _confirmDelete(
      context,
      title: 'Delete segment?',
      message:
          'Remove the transcript segment at ${segment.timestampLabel} from "${session.title}"?',
      onConfirm: () =>
          widget.controller.deleteRecordingSegment(session.id, segment.id),
    );
  }

  Future<void> _deleteRecording(
    BuildContext context,
    RecordingSessionItem session,
  ) async {
    await _confirmDelete(
      context,
      title: 'Delete recording?',
      message:
          'Remove the full recording "${session.title}", including audio chunks and transcript data?',
      onConfirm: () => widget.controller.deleteRecordingSession(session.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final runtime = widget.controller.recordingRuntime;
    final wearableService = widget.controller.wearableService;
    final heypocketConnected = wearableService.canStartHeyPocketRecording;
    final heypocketRecordingActive =
        heypocketConnected && wearableService.heypocketRecordingActive;
    final heypocketStartInFlight = wearableService.heypocketStartInFlight;
    final anyRecordingActive = runtime.active || heypocketRecordingActive;
    Future<void> handleWearableRecordingToggle() async {
      if (heypocketRecordingActive) {
        await wearableService.stopHeyPocketRecordingFromApp();
      } else {
        await wearableService.startHeyPocketRecordingFromApp();
      }
      await widget.controller.refreshRecordings();
    }

    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        const _SectionTitle('Record meetings and conversations'),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    _DotStatus(
                      label: anyRecordingActive
                          ? (runtime.paused ? 'Paused' : 'Recording')
                          : 'Idle',
                      color: anyRecordingActive
                          ? (runtime.paused ? _warning : _danger)
                          : _success,
                    ),
                    if (heypocketRecordingActive)
                      Text(
                        wearableService.heypocketActiveRecordingId.isNotEmpty
                            ? 'Wearable live: ${wearableService.heypocketActiveRecordingId}'
                            : 'Wearable live recording',
                        style: TextStyle(color: _textSecondary),
                      ),
                    if (runtime.platformLabel != null &&
                        runtime.platformLabel!.isNotEmpty)
                      Text(
                        runtime.platformLabel!,
                        style: TextStyle(color: _textSecondary),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    if (runtime.supportsScreenAndMic)
                      FilledButton.icon(
                        onPressed:
                            widget.controller.isStartingRecording ||
                                runtime.active
                            ? null
                            : widget.controller.startWebRecording,
                        icon: Icon(Icons.desktop_windows_outlined),
                        label: Text('Start screen + mic'),
                      ),
                    if (runtime.supportsBackgroundMic)
                      FilledButton.icon(
                        onPressed:
                            widget.controller.isStartingRecording ||
                                runtime.active ||
                                heypocketStartInFlight
                            ? null
                            : (heypocketConnected
                                  ? handleWearableRecordingToggle
                                  : widget.controller.startBackgroundRecording),
                        icon: Icon(
                          heypocketConnected
                              ? (heypocketRecordingActive
                                    ? Icons.stop_circle_outlined
                                    : Icons.watch_outlined)
                              : Icons.mic_none_outlined,
                        ),
                        label: Text(
                          heypocketConnected
                              ? (heypocketStartInFlight
                                    ? 'Starting wearable recording...'
                                    : (heypocketRecordingActive
                                          ? 'Stop wearable recording'
                                          : 'Start recording on wearable'))
                              : 'Start background mic',
                        ),
                      ),
                    if (runtime.supportsBackgroundMic && runtime.active)
                      OutlinedButton.icon(
                        onPressed: runtime.paused
                            ? widget.controller.resumeBackgroundRecording
                            : widget.controller.pauseBackgroundRecording,
                        icon: Icon(
                          runtime.paused ? Icons.play_arrow : Icons.pause,
                        ),
                        label: Text(runtime.paused ? 'Resume' : 'Pause'),
                      ),
                    if (runtime.active)
                      OutlinedButton.icon(
                        onPressed: widget.controller.isStoppingRecording
                            ? null
                            : widget.controller.stopRecording,
                        icon: Icon(Icons.stop_circle_outlined),
                        label: Text('Stop'),
                      ),
                    OutlinedButton.icon(
                      onPressed: widget.controller.refreshRecordings,
                      icon: Icon(Icons.refresh),
                      label: Text('Refresh'),
                    ),
                  ],
                ),
                if (runtime.errorMessage != null &&
                    runtime.errorMessage!.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  Text(runtime.errorMessage!, style: TextStyle(color: _danger)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const _SectionTitle('Transcription history'),
        const SizedBox(height: 12),
        if (widget.controller.recordingSessions.isEmpty)
          const _EmptyCard(
            title: 'No recordings yet',
            subtitle:
                'Start a recording and your persisted transcripts will appear here with timestamps.',
          )
        else
          ...widget.controller.recordingSessions.map(
            (session) => Padding(
              key: ValueKey<String>(session.id),
              padding: const EdgeInsets.only(bottom: 12),
              child: _RecordingSessionCard(
                controller: widget.controller,
                session: session,
                onRetry:
                    (session.status == 'failed' ||
                        (session.status == 'completed' &&
                            session.transcriptText.trim().isEmpty &&
                            session.transcriptSegments.isEmpty &&
                            session.structuredContent.isEmpty))
                    ? () => widget.controller.retryRecording(session.id)
                    : null,
                onDeleteSegment: (segment) =>
                    _deleteSegment(context, session, segment),
                onDeleteRecording: () => _deleteRecording(context, session),
              ),
            ),
          ),
      ],
    );
  }
}

class VoiceAssistantPanel extends StatefulWidget {
  const VoiceAssistantPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<VoiceAssistantPanel> createState() => _VoiceAssistantPanelState();
}

class _VoiceAssistantPanelState extends State<VoiceAssistantPanel> {
  late final AudioPlayer _assistantPlayer;
  bool _pttPressed = false;
  bool _isRunningAssistant = false;
  bool _isAssistantPlaying = false;
  String _assistantReply = '';
  String _assistantTranscript = '';
  String? _voiceError;
  Uint8List? _assistantAudioBytes;
  String? _assistantAudioMimeType;
  String? _lastCapturedSessionId;

  @override
  void initState() {
    super.initState();
    _assistantPlayer = AudioPlayer();
    _assistantPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isAssistantPlaying = false;
      });
    });
  }

  @override
  void dispose() {
    unawaited(_assistantPlayer.dispose());
    super.dispose();
  }

  Future<void> _startPttCapture() async {
    final runtime = widget.controller.recordingRuntime;
    if (runtime.active || widget.controller.isStartingRecording) {
      return;
    }

    setState(() {
      _pttPressed = true;
    });

    try {
      if (runtime.supportsBackgroundMic) {
        await widget.controller.startBackgroundRecording();
      } else if (runtime.supportsScreenAndMic) {
        await widget.controller.startWebRecording();
      }
      _lastCapturedSessionId = widget.controller.recordingRuntime.sessionId;
    } finally {
      if (mounted) {
        setState(() {
          _pttPressed = false;
        });
      }
    }
  }

  Future<void> _stopPttCapture() async {
    final runtime = widget.controller.recordingRuntime;
    if (!runtime.active || widget.controller.isStoppingRecording) {
      return;
    }

    final capturedSessionId = runtime.sessionId;

    await widget.controller.stopRecording();

    final targetSessionId = capturedSessionId ?? _lastCapturedSessionId;
    if (targetSessionId != null && targetSessionId.trim().isNotEmpty) {
      await _runAssistantTurn(targetSessionId.trim());
    }
  }

  Future<void> _runAssistantTurn(String sessionId) async {
    if (_isRunningAssistant) {
      return;
    }

    setState(() {
      _isRunningAssistant = true;
      _voiceError = null;
    });

    try {
      final result = await widget.controller.runVoiceAssistantTurn(
        sessionId: sessionId,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _assistantReply = result.replyText;
        _assistantTranscript = result.transcript;
        _assistantAudioBytes = result.audioBytes;
        _assistantAudioMimeType = result.audioMimeType;
      });

      await _playAssistantAudio();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _voiceError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRunningAssistant = false;
        });
      }
    }
  }

  Future<void> _playAssistantAudio() async {
    final bytes = _assistantAudioBytes;
    if (bytes == null || bytes.isEmpty) {
      return;
    }

    await _assistantPlayer.stop();
    final mimeType = (_assistantAudioMimeType?.trim().isNotEmpty ?? false)
        ? _assistantAudioMimeType!.trim()
        : null;
    await _assistantPlayer.play(BytesSource(bytes, mimeType: mimeType));
    if (!mounted) {
      return;
    }
    setState(() {
      _isAssistantPlaying = true;
    });
  }

  Future<void> _stopAssistantAudio() async {
    await _assistantPlayer.stop();
    if (!mounted) {
      return;
    }
    setState(() {
      _isAssistantPlaying = false;
    });
  }

  RecordingSessionItem? _latestVoiceSession() {
    for (final session in widget.controller.recordingSessions) {
      final hasAudioSource = session.sources.any(
        (source) => source.mediaKind == 'audio' && source.chunkCount > 0,
      );
      if (hasAudioSource) {
        return session;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final runtime = controller.recordingRuntime;
    final supportsPtt =
        runtime.supportsBackgroundMic || runtime.supportsScreenAndMic;
    final isBusy =
        controller.isStartingRecording || controller.isStoppingRecording;
    final canStart = supportsPtt && !isBusy && !runtime.active;
    final canStop = runtime.active && !controller.isStoppingRecording;
    final latestSession = _latestVoiceSession();
    final canGenerate =
        !_isRunningAssistant && latestSession != null && !runtime.active;
    final hasAssistantAudio =
        _assistantAudioBytes != null && _assistantAudioBytes!.isNotEmpty;

    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Voice Assistant',
          subtitle:
              'Push-to-talk capture with instant playback, using the same recording flow as voice integrations.',
          trailing: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _DotStatus(
                label: runtime.active
                    ? (runtime.paused ? 'Paused' : 'Listening')
                    : 'Standby',
                color: runtime.active ? _danger : _success,
              ),
              if (runtime.platformLabel != null &&
                  runtime.platformLabel!.isNotEmpty)
                _MetaPill(
                  label: runtime.platformLabel!,
                  icon: Icons.memory_outlined,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Press and hold to talk',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  supportsPtt
                      ? 'Hold the button while speaking. Release to stop, process, and make playback available below.'
                      : 'Push-to-talk is available on Android (background mic) or in browser mode with screen+mic capture.',
                  style: TextStyle(color: _textSecondary, height: 1.45),
                ),
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onLongPressStart: canStart
                        ? (_) => unawaited(_startPttCapture())
                        : null,
                    onLongPressEnd: canStop
                        ? (_) => unawaited(_stopPttCapture())
                        : null,
                    onLongPressCancel: canStop
                        ? () => unawaited(_stopPttCapture())
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      width: 188,
                      height: 188,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: <Color>[
                            (runtime.active || _pttPressed)
                                ? _danger.withValues(alpha: 0.95)
                                : _accent.withValues(alpha: 0.95),
                            (runtime.active || _pttPressed)
                                ? _danger
                                : _accentHover,
                          ],
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: (runtime.active || _pttPressed)
                                ? _danger.withValues(alpha: 0.35)
                                : _accent.withValues(alpha: 0.34),
                            blurRadius: 28,
                            spreadRadius: 5,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            runtime.active ? Icons.hearing : Icons.mic,
                            color: Colors.white,
                            size: 46,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            runtime.active
                                ? 'Release to stop'
                                : (supportsPtt
                                      ? 'Hold to talk'
                                      : 'Unsupported'),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: canStart ? _startPttCapture : null,
                        icon: Icon(Icons.fiber_manual_record),
                        label: Text('Start'),
                      ),
                      OutlinedButton.icon(
                        onPressed: canStop ? _stopPttCapture : null,
                        icon: Icon(Icons.stop_circle_outlined),
                        label: Text('Stop'),
                      ),
                      OutlinedButton.icon(
                        onPressed: canGenerate
                            ? () => _runAssistantTurn(latestSession.id)
                            : null,
                        icon: Icon(Icons.auto_awesome_outlined),
                        label: Text(
                          _isRunningAssistant
                              ? 'Thinking...'
                              : 'Generate reply',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: hasAssistantAudio
                            ? (_isAssistantPlaying
                                  ? _stopAssistantAudio
                                  : _playAssistantAudio)
                            : null,
                        icon: Icon(
                          _isAssistantPlaying
                              ? Icons.stop_circle_outlined
                              : Icons.play_arrow,
                        ),
                        label: Text(
                          _isAssistantPlaying
                              ? 'Stop reply audio'
                              : 'Play reply audio',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: controller.refreshRecordings,
                        icon: Icon(Icons.refresh),
                        label: Text('Refresh'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => controller.setSelectedSection(
                          AppSection.recordings,
                        ),
                        icon: Icon(Icons.library_music_outlined),
                        label: Text('Open recordings'),
                      ),
                    ],
                  ),
                ),
                if (controller.errorMessage != null &&
                    controller.errorMessage!.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  _InlineError(message: controller.errorMessage!),
                ],
                if (_voiceError != null &&
                    _voiceError!.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  _InlineError(message: _voiceError!),
                ],
                if (_assistantReply.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _bgSecondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Assistant reply',
                          style: TextStyle(
                            color: _textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(_assistantReply, style: TextStyle(height: 1.45)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const _SectionTitle('Latest voice playback'),
        const SizedBox(height: 12),
        if (latestSession == null)
          const _EmptyCard(
            title: 'No playable voice capture yet',
            subtitle:
                'Record a push-to-talk sample and it will appear here for immediate playback.',
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    latestSession.title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${latestSession.startedAtLabel} • ${latestSession.statusLabel}',
                    style: TextStyle(color: _textSecondary),
                  ),
                  const SizedBox(height: 12),
                  _RecordingSourceAudioControls(
                    controller: controller,
                    session: latestSession,
                  ),
                  if (_assistantTranscript.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 14),
                    Text(
                      'Detected transcript',
                      style: TextStyle(
                        color: _textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_assistantTranscript, style: TextStyle(height: 1.45)),
                  ],
                  if (latestSession.transcriptText
                      .trim()
                      .isNotEmpty) ...<Widget>[
                    const SizedBox(height: 14),
                    Text(
                      latestSession.transcriptText,
                      style: TextStyle(height: 1.45),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RecordingSessionCard extends StatelessWidget {
  const _RecordingSessionCard({
    required this.controller,
    required this.session,
    this.onRetry,
    this.onDeleteSegment,
    this.onDeleteRecording,
  });

  final NeoAgentController controller;
  final RecordingSessionItem session;
  final VoidCallback? onRetry;
  final Future<void> Function(RecordingTranscriptSegment segment)?
  onDeleteSegment;
  final Future<void> Function()? onDeleteRecording;

  @override
  Widget build(BuildContext context) {
    final runtime = controller.recordingRuntime;
    final isLiveSession = runtime.active && runtime.sessionId == session.id;
    final canDeleteRecording = onDeleteRecording != null && !isLiveSession;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        session.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${session.startedAtLabel} • ${session.platformLabel} • ${session.durationLabel}',
                        style: TextStyle(color: _textSecondary),
                      ),
                    ],
                  ),
                ),
                _StatusPill(
                  label: session.statusLabel,
                  color: session.statusColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: session.sources
                  .map(
                    (source) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _bgSecondary,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _border),
                      ),
                      child: Text(
                        '${source.label} • ${source.durationLabel}',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  )
                  .toList(),
            ),
            if (session.sources.any(
              (source) => source.mediaKind == 'audio',
            )) ...<Widget>[
              const SizedBox(height: 12),
              _RecordingSourceAudioControls(
                controller: controller,
                session: session,
              ),
            ],
            if (session.lastError != null &&
                session.lastError!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  session.lastError!,
                  style: TextStyle(color: _danger),
                ),
              ),
            if (session.structuredContent.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _bgSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.auto_awesome, size: 16, color: _accent),
                        const SizedBox(width: 8),
                        Text(
                          'Smart Segments',
                          style: TextStyle(
                            color: _accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (session.structuredContent['summary'] !=
                        null) ...<Widget>[
                      const SizedBox(height: 10),
                      Text(
                        'Summary',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.structuredContent['summary'].toString(),
                        style: TextStyle(height: 1.45),
                      ),
                    ],
                    if (session.structuredContent['action_items'] != null &&
                        _getStructuredList(
                          session,
                          'action_items',
                        ).isNotEmpty) ...<Widget>[
                      const SizedBox(height: 10),
                      Text(
                        'Action Items',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ..._getStructuredList(session, 'action_items').map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _accent,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  item.toString(),
                                  style: TextStyle(height: 1.35),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (session.structuredContent['events'] != null &&
                        _getStructuredList(
                          session,
                          'events',
                        ).isNotEmpty) ...<Widget>[
                      const SizedBox(height: 10),
                      Text(
                        'Events Mentioned',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ..._getStructuredList(session, 'events').map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _accent,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  item.toString(),
                                  style: TextStyle(height: 1.35),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (session.transcriptSegments.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              ...session.transcriptSegments.map(
                (segment) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 88,
                        child: Text(
                          segment.timestampLabel,
                          style: TextStyle(color: _textSecondary),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          segment.displayText,
                          style: TextStyle(height: 1.45),
                        ),
                      ),
                      if (onDeleteSegment != null &&
                          segment.id > 0) ...<Widget>[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () async {
                            await onDeleteSegment!(segment);
                          },
                          icon: Icon(Icons.delete_outline),
                          tooltip: 'Delete segment',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ] else if (session.transcriptText.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Text(session.transcriptText, style: TextStyle(height: 1.45)),
            ] else ...<Widget>[
              const SizedBox(height: 16),
              Text(
                session.status == 'processing'
                    ? 'Transcription is being processed.'
                    : session.status == 'failed'
                    ? 'Transcription failed. Check the error above and retry.'
                    : session.status == 'completed'
                    ? 'Transcription completed but no speech text was returned. You can retry transcription.'
                    : 'Transcript is not available yet.',
                style: TextStyle(color: _textSecondary),
              ),
            ],
            if (onRetry != null || canDeleteRecording) ...<Widget>[
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  if (onRetry != null)
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: Icon(Icons.replay),
                      label: Text('Retry transcription'),
                    ),
                  if (canDeleteRecording)
                    OutlinedButton.icon(
                      onPressed: () async {
                        await onDeleteRecording!();
                      },
                      icon: Icon(Icons.delete_forever_outlined),
                      label: Text('Delete recording'),
                      style: OutlinedButton.styleFrom(foregroundColor: _danger),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<dynamic> _getStructuredList(RecordingSessionItem session, String key) {
    final value = session.structuredContent[key];
    if (value is List) {
      return value;
    }
    return const [];
  }
}

class _RecordingSourceAudioControls extends StatefulWidget {
  const _RecordingSourceAudioControls({
    required this.controller,
    required this.session,
  });

  final NeoAgentController controller;
  final RecordingSessionItem session;

  @override
  State<_RecordingSourceAudioControls> createState() =>
      _RecordingSourceAudioControlsState();
}

class _RecordingSourceAudioControlsState
    extends State<_RecordingSourceAudioControls> {
  late final AudioPlayer _player;
  String? _activeSourceKey;
  bool _isPlaying = false;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.onPlayerComplete.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = false;
        _activeSourceKey = null;
      });
    });
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _toggleSource(RecordingSourceItem source) async {
    final token = ++_loadToken;
    bool isStale() => !mounted || token != _loadToken;
    if (_isPlaying && _activeSourceKey == source.sourceKey) {
      await _player.stop();
      if (isStale()) {
        return;
      }
      setState(() {
        _isPlaying = false;
        _activeSourceKey = null;
      });
      return;
    }

    try {
      await _player.stop();
      if (isStale()) {
        return;
      }
      final bytes = await widget.controller.fetchRecordingSourceAudioBytes(
        widget.session.id,
        source.sourceKey,
      );
      if (isStale()) {
        return;
      }
      if (bytes.isEmpty) {
        throw StateError('Audio source is empty.');
      }
      final mime = source.mimeType.trim().isNotEmpty
          ? source.mimeType.trim()
          : null;
      await _player.play(BytesSource(bytes, mimeType: mime));
      if (isStale()) {
        await _player.stop();
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = true;
        _activeSourceKey = source.sourceKey;
      });
    } catch (e) {
      if (isStale()) {
        return;
      }
      AppDiagnostics.log(
        'recording.playback',
        'source.play.failed',
        data: <String, Object?>{
          'sessionId': widget.session.id,
          'sourceKey': source.sourceKey,
          'mimeType': source.mimeType,
        },
        error: e,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = false;
        _activeSourceKey = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioSources = widget.session.sources
        .where((source) => source.mediaKind == 'audio')
        .toList();
    if (audioSources.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: audioSources.map((source) {
        final isActive = _isPlaying && _activeSourceKey == source.sourceKey;
        return OutlinedButton.icon(
          onPressed: () => _toggleSource(source),
          icon: Icon(isActive ? Icons.stop_circle_outlined : Icons.play_arrow),
          label: Text(
            isActive ? 'Stop ${source.label}' : 'Play ${source.label}',
          ),
        );
      }).toList(),
    );
  }
}

class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  late final TextEditingController _composerController;
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = 0;
  int _lastToolCount = 0;
  String _lastStream = '';

  @override
  void initState() {
    super.initState();
    _composerController = TextEditingController();
  }

  @override
  void dispose() {
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final messages = controller.visibleChatMessages;
    if (_lastMessageCount != messages.length ||
        _lastToolCount != controller.toolEvents.length ||
        _lastStream != controller.streamingAssistant) {
      _lastMessageCount = messages.length;
      _lastToolCount = controller.toolEvents.length;
      _lastStream = controller.streamingAssistant;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        }
      });
    }

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: _pagePadding(context),
            children: <Widget>[
              _PageTitle(
                title: 'Chat',
                subtitle: 'Live agent chat with tool and stream status.',
                trailing: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    _MetaPill(
                      label: controller.modelIndicator,
                      icon: Icons.memory_outlined,
                    ),
                    _MetaPill(
                      label: 'Agent: ${controller.activeAgentLabel}',
                      icon: Icons.smart_toy_outlined,
                    ),
                  ],
                ),
              ),
              if (controller.errorMessage != null) ...<Widget>[
                _InlineError(message: controller.errorMessage!),
                const SizedBox(height: 16),
              ],
              if (controller.activeRun != null ||
                  controller.toolEvents.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _RunStatusPanel(
                    run: controller.activeRun,
                    tools: controller.toolEvents,
                  ),
                ),
              if (messages.isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 64),
                  child: Center(
                    child: _EmptyState(
                      title: 'How can I help?',
                      subtitle:
                          'Runs, tools, memory, scheduling, skills, and MCP are all available here.',
                    ),
                  ),
                )
              else
                ...messages.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: _ChatBubble(entry: entry),
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          decoration: BoxDecoration(
            color: _bgPrimary,
            border: Border(top: BorderSide(color: _border)),
          ),
          child: Column(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                decoration: BoxDecoration(
                  color: _bgTertiary,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _composerController,
                        minLines: 1,
                        maxLines: 6,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: controller.chatComposerHint,
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: () async {
                        final task = _composerController.text;
                        _composerController.clear();
                        await controller.sendMessage(task);
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(46, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        backgroundColor: _accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Icon(
                        controller.hasLiveRun
                            ? Icons.alt_route_rounded
                            : Icons.north_east_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    controller.chatStatusLabel,
                    style: TextStyle(fontSize: 11, color: _textSecondary),
                  ),
                  Text(
                    controller.hasLiveRun
                        ? 'Steering mode'
                        : controller.modelIndicator,
                    style: TextStyle(fontSize: 11, color: _textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MessagingPanel extends StatefulWidget {
  const MessagingPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<MessagingPanel> createState() => _MessagingPanelState();
}

MessagingPlatformDescriptor? _messagingPlatformById(String id) {
  for (final platform in messagingPlatforms) {
    if (platform.id == id) return platform;
  }
  return null;
}

class _MessagingPanelState extends State<MessagingPanel> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final groups = [
      const (
        'Text & Chat',
        'Personal channels and direct support surfaces.',
        [
          'whatsapp',
          'signal',
          'imessage',
          'bluebubbles',
          'line',
          'zalo_personal',
        ],
      ),
      const (
        'Community & ChatOps',
        'Team spaces, rooms, channels, and live communities.',
        [
          'discord',
          'telegram',
          'slack',
          'google_chat',
          'teams',
          'matrix',
          'mattermost',
          'irc',
          'twitch',
        ],
      ),
      const (
        'Configurable Webhooks',
        'Bridge any provider that can post and receive webhook payloads.',
        [
          'feishu',
          'nextcloud_talk',
          'nostr',
          'synology_chat',
          'tlon',
          'zalo',
          'wechat',
          'webchat',
        ],
      ),
      const (
        'Voice',
        'Telephony and wearable integrations.',
        ['telnyx', 'waveshare_wearable'],
      ),
    ];
    final query = _searchController.text.trim().toLowerCase();
    final counts = _MessagingStatusCounts.from(controller.messagingStatuses);
    final hasMatches = _hasMessagingMatches(controller, groups, query);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _PageTitle(
          title: 'Messaging',
          subtitle:
              'Connect channels, limit who can reach the agent, and monitor activity.',
          trailing: OutlinedButton.icon(
            onPressed: controller.refreshMessaging,
            icon: Icon(Icons.refresh_rounded),
            label: Text('Refresh'),
          ),
        ),
        const SizedBox(height: 18),
        _MessagingOverviewStrip(counts: counts),
        const SizedBox(height: 16),
        _MessagingToolbar(
          controller: _searchController,
          selectedFilter: _statusFilter,
          onFilterChanged: (value) => setState(() => _statusFilter = value),
          counts: counts,
        ),
        if (controller.pendingMessagingQr != null) ...[
          const SizedBox(height: 18),
          _MessagingQrPanel(qrState: controller.pendingMessagingQr!),
        ],
        const SizedBox(height: 18),
        for (final group in groups)
          Builder(
            builder: (context) {
              final platforms = group.$3
                  .map(_messagingPlatformById)
                  .nonNulls
                  .where((platform) {
                    final status =
                        controller.messagingStatuses[platform.id] ??
                        MessagingPlatformStatus.empty(platform.id);
                    final haystack =
                        '${platform.label} ${platform.subtitle} ${group.$1}'
                            .toLowerCase();
                    return _matchesMessagingStatusFilter(status) &&
                        (query.isEmpty || haystack.contains(query));
                  })
                  .toList(growable: false);
              if (platforms.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MessagingGroupHeader(
                      title: group.$1,
                      subtitle: group.$2,
                      count: platforms.length,
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final crossAxisCount = width >= 1380
                            ? 4
                            : width >= 1020
                            ? 3
                            : width >= 700
                            ? 2
                            : 1;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: platforms.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                mainAxisExtent: 268,
                              ),
                          itemBuilder: (context, index) {
                            final platform = platforms[index];
                            return _MessagingCard(
                              platform: platform,
                              status:
                                  controller.messagingStatuses[platform.id] ??
                                  MessagingPlatformStatus.empty(platform.id),
                              whitelist: controller.currentMessagingWhitelist(
                                platform.id,
                              ),
                              controller: controller,
                              onConnect: () => _openMessagingConfig(platform),
                              onDisconnect: () => controller
                                  .disconnectMessagingPlatform(platform.id),
                              onLogout: () => controller
                                  .logoutMessagingPlatform(platform.id),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        if (!hasMatches) ...[
          const SizedBox(height: 10),
          const _EmptyCard(
            title: 'No platforms match',
            subtitle:
                'Adjust the search or status filter to see more messaging channels.',
          ),
          const SizedBox(height: 22),
        ],
        _MessagingActivityPanel(messages: controller.messagingMessages),
      ],
    );
  }

  bool _hasMessagingMatches(
    NeoAgentController controller,
    List<(String, String, List<String>)> groups,
    String query,
  ) {
    for (final group in groups) {
      for (final key in group.$3) {
        final platform = _messagingPlatformById(key);
        if (platform == null) continue;
        final status =
            controller.messagingStatuses[platform.id] ??
            MessagingPlatformStatus.empty(platform.id);
        final haystack = '${platform.label} ${platform.subtitle} ${group.$1}'
            .toLowerCase();
        if (_matchesMessagingStatusFilter(status) &&
            (query.isEmpty || haystack.contains(query))) {
          return true;
        }
      }
    }
    return false;
  }

  bool _matchesMessagingStatusFilter(MessagingPlatformStatus? status) {
    final effective = status ?? MessagingPlatformStatus.empty('unknown');
    return switch (_statusFilter) {
      'connected' => effective.isConnected,
      'configured' => effective.status != 'not_configured',
      'attention' => const {
        'connecting',
        'awaiting_qr',
        'logged_out',
        'disconnected',
        'error',
      }.contains(effective.status),
      _ => true,
    };
  }

  Future<void> _openMessagingConfig(
    MessagingPlatformDescriptor platform,
  ) async {
    switch (platform.id) {
      case 'whatsapp':
        await widget.controller.connectMessagingPlatform(platform: 'whatsapp');
        return;
      case 'telnyx':
        return _openTelnyxConfig();
      case 'waveshare_wearable':
        return _openWaveshareWearableConfig();
      default:
        return _openGenericMessagingConfig(platform);
    }
  }

  Future<void> _openWaveshareWearableConfig() async {
    final saved = _jsonMap(
      _decodeMaybeJson(widget.controller.settings['waveshare_wearable_config']),
    );
    final deviceLabel = TextEditingController(
      text: saved['deviceLabel']?.toString() ?? 'NeoOS Wearable',
    );
    final ttlController = TextEditingController(text: '10');
    String pairingCode = '';
    String expiresAt = '';
    final status =
        widget.controller.messagingStatuses['waveshare_wearable'] ??
        MessagingPlatformStatus.empty('waveshare_wearable');
    final isConnected = status.isConnected;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              backgroundColor: _bgCard,
              title: const Text('NeoOS Wearable'),
              content: SizedBox(
                width: 620,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Generate a one-time pairing code, then enter it on the wearable setup AP page.',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: deviceLabel,
                      decoration: const InputDecoration(
                        labelText: 'Device Label',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ttlController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Code TTL (minutes)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (pairingCode.isNotEmpty)
                      SelectableText(
                        'Pairing code: $pairingCode\nExpires: $expiresAt',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      )
                    else
                      Text(
                        'No active code generated yet.',
                        style: TextStyle(color: _textSecondary),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final ttl = int.tryParse(ttlController.text.trim()) ?? 10;
                    final result = await widget.controller
                        .createWearablePairingCode(
                          ttlMinutes: ttl,
                          deviceHint: deviceLabel.text.trim(),
                        );
                    setLocalState(() {
                      pairingCode = (result['code'] ?? '').toString();
                      expiresAt = (result['expiresAt'] ?? '').toString();
                    });
                  },
                  child: const Text('Generate Pairing Code'),
                ),
                if (!isConnected)
                  FilledButton(
                    onPressed: () async {
                      final config = <String, dynamic>{
                        'deviceLabel': deviceLabel.text.trim(),
                      };
                      await widget.controller.connectMessagingPlatform(
                        platform: 'waveshare_wearable',
                        config: config,
                        configSnapshot: <String, dynamic>{
                          'waveshare_wearable_config': jsonEncode(config),
                        },
                      );
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Text('Enable Provider'),
                  )
                else
                  FilledButton.tonal(
                    onPressed: null,
                    child: const Text('Provider Enabled'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openTelnyxConfig() async {
    final saved = _jsonMap(
      _decodeMaybeJson(widget.controller.settings['telnyx_config']),
    );
    final apiKey = TextEditingController(
      text: saved['apiKey']?.toString() ?? '',
    );
    final phoneNumber = TextEditingController(
      text: saved['phoneNumber']?.toString() ?? '',
    );
    final connectionId = TextEditingController(
      text: saved['connectionId']?.toString() ?? '',
    );
    final webhookUrl = TextEditingController(
      text: saved['webhookUrl']?.toString() ?? widget.controller.backendUrl,
    );
    String ttsVoice = saved['ttsVoice']?.toString() ?? 'alloy';
    String ttsModel = saved['ttsModel']?.toString() ?? 'tts-1';
    String sttModel = saved['sttModel']?.toString() ?? 'whisper-1';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              backgroundColor: _bgCard,
              title: Text('Telnyx Voice'),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextField(
                        controller: apiKey,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'API Key'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneNumber,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: connectionId,
                        decoration: const InputDecoration(
                          labelText: 'Connection ID',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: webhookUrl,
                        decoration: const InputDecoration(
                          labelText: 'Webhook Base URL',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: ttsVoice,
                        items:
                            const <String>[
                                  'alloy',
                                  'echo',
                                  'fable',
                                  'onyx',
                                  'nova',
                                  'shimmer',
                                ]
                                .map(
                                  (value) => DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  ),
                                )
                                .toList(),
                        decoration: const InputDecoration(
                          labelText: 'TTS Voice',
                        ),
                        onChanged: (value) {
                          if (value != null) {
                            setLocalState(() => ttsVoice = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: ttsModel,
                        items:
                            const <String>[
                                  'tts-1',
                                  'tts-1-hd',
                                  'gpt-4o-mini-tts',
                                ]
                                .map(
                                  (value) => DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  ),
                                )
                                .toList(),
                        decoration: const InputDecoration(
                          labelText: 'TTS Model',
                        ),
                        onChanged: (value) {
                          if (value != null) {
                            setLocalState(() => ttsModel = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: sttModel,
                        items: const <String>['whisper-1', 'gpt-4o-transcribe']
                            .map(
                              (value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        decoration: const InputDecoration(
                          labelText: 'STT Model',
                        ),
                        onChanged: (value) {
                          if (value != null) {
                            setLocalState(() => sttModel = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final config = <String, dynamic>{
                      'apiKey': apiKey.text.trim(),
                      'phoneNumber': phoneNumber.text.trim(),
                      'connectionId': connectionId.text.trim(),
                      'webhookUrl': webhookUrl.text.trim(),
                      'ttsVoice': ttsVoice,
                      'ttsModel': ttsModel,
                      'sttModel': sttModel,
                    };
                    await widget.controller.connectMessagingPlatform(
                      platform: 'telnyx',
                      config: config,
                      configSnapshot: <String, dynamic>{
                        'telnyx_config': jsonEncode(config),
                      },
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text('Connect'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openGenericMessagingConfig(
    MessagingPlatformDescriptor platform,
  ) async {
    final saved = _jsonMap(
      _decodeMaybeJson(widget.controller.settings[platform.settingsKey]),
    );
    final textControllers = <String, TextEditingController>{};
    final boolValues = <String, bool>{};
    for (final field in platform.configFields) {
      final savedValue = saved[field.key];
      if (field.kind == MessagingConfigFieldKind.boolean) {
        boolValues[field.key] =
            savedValue == true || savedValue?.toString() == 'true';
      } else {
        textControllers[field.key] = TextEditingController(
          text: savedValue?.toString() ?? field.defaultValue ?? '',
        );
      }
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              backgroundColor: _bgCard,
              title: Text(platform.label),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (platform.configFields.isEmpty)
                        Text(
                          'No extra settings are required.',
                          style: TextStyle(color: _textSecondary),
                        )
                      else
                        ...platform.configFields.map((field) {
                          if (field.kind == MessagingConfigFieldKind.boolean) {
                            return SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(field.label),
                              value: boolValues[field.key] ?? false,
                              onChanged: (value) {
                                setLocalState(() {
                                  boolValues[field.key] = value;
                                });
                              },
                            );
                          }
                          final controller = textControllers[field.key]!;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextField(
                              controller: controller,
                              obscureText:
                                  field.obscure ||
                                  field.kind ==
                                      MessagingConfigFieldKind.password,
                              minLines:
                                  field.kind ==
                                      MessagingConfigFieldKind.multiline
                                  ? 4
                                  : 1,
                              maxLines:
                                  field.kind ==
                                      MessagingConfigFieldKind.multiline
                                  ? 8
                                  : 1,
                              decoration: InputDecoration(
                                labelText: field.label,
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 8),
                      SelectableText(
                        'Inbound webhook: ${widget.controller.backendUrl}/api/messaging/webhook/${platform.id}',
                        style: TextStyle(color: _textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final config = <String, dynamic>{};
                    for (final entry in textControllers.entries) {
                      final value = entry.value.text.trim();
                      if (value.isNotEmpty) config[entry.key] = value;
                    }
                    for (final entry in boolValues.entries) {
                      config[entry.key] = entry.value;
                    }
                    await widget.controller.connectMessagingPlatform(
                      platform: platform.id,
                      config: config,
                      configSnapshot: <String, dynamic>{
                        platform.settingsKey: jsonEncode(config),
                      },
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text('Connect'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MessagingStatusCounts {
  const _MessagingStatusCounts({
    required this.total,
    required this.connected,
    required this.configured,
    required this.attention,
  });

  final int total;
  final int connected;
  final int configured;
  final int attention;

  factory _MessagingStatusCounts.from(
    Map<String, MessagingPlatformStatus> statuses,
  ) {
    var connected = 0;
    var configured = 0;
    var attention = 0;
    for (final platform in messagingPlatforms) {
      final status =
          statuses[platform.id] ?? MessagingPlatformStatus.empty(platform.id);
      if (status.isConnected) connected++;
      if (status.status != 'not_configured') configured++;
      if (const {
        'connecting',
        'awaiting_qr',
        'logged_out',
        'disconnected',
        'error',
      }.contains(status.status)) {
        attention++;
      }
    }
    return _MessagingStatusCounts(
      total: messagingPlatforms.length,
      connected: connected,
      configured: configured,
      attention: attention,
    );
  }
}

class _MessagingOverviewStrip extends StatelessWidget {
  const _MessagingOverviewStrip({required this.counts});

  final _MessagingStatusCounts counts;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MessagingMetricCard(
        icon: Icons.link_rounded,
        label: 'Connected',
        value: '${counts.connected}',
        helper: '${counts.configured} configured',
        color: _success,
      ),
      _MessagingMetricCard(
        icon: Icons.error_outline_rounded,
        label: 'Needs attention',
        value: '${counts.attention}',
        helper: 'Reconnect or finish setup',
        color: counts.attention > 0 ? _warning : _textSecondary,
      ),
      _MessagingMetricCard(
        icon: Icons.apps_rounded,
        label: 'Available',
        value: '${counts.total}',
        helper: 'Native and webhook channels',
        color: _info,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        if (compact) {
          return Column(
            children: [
              for (var index = 0; index < cards.length; index++) ...[
                if (index > 0) const SizedBox(height: 10),
                cards[index],
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              if (index > 0) const SizedBox(width: 12),
              Expanded(child: cards[index]),
            ],
          ],
        );
      },
    );
  }
}

class _MessagingMetricCard extends StatelessWidget {
  const _MessagingMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.helper,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String helper;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: _textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  helper,
                  style: TextStyle(color: _textMuted, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagingToolbar extends StatelessWidget {
  const _MessagingToolbar({
    required this.controller,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.counts,
  });

  final TextEditingController controller;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;
  final _MessagingStatusCounts counts;

  @override
  Widget build(BuildContext context) {
    final filters = <(String, String)>[
      ('all', 'All ${counts.total}'),
      ('connected', 'Connected ${counts.connected}'),
      ('configured', 'Configured ${counts.configured}'),
      ('attention', 'Attention ${counts.attention}'),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderLight),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 780;
          final search = TextField(
            controller: controller,
            style: TextStyle(color: _textPrimary),
            decoration: InputDecoration(
              labelText: 'Find a platform',
              prefixIcon: Icon(Icons.search_rounded),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: controller.clear,
                      icon: Icon(Icons.close_rounded),
                    ),
            ),
          );
          final chips = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final filter in filters)
                ChoiceChip(
                  label: Text(filter.$2),
                  selected: selectedFilter == filter.$1,
                  onSelected: (_) => onFilterChanged(filter.$1),
                  selectedColor: _accent.withValues(alpha: 0.18),
                  backgroundColor: _bgCard,
                  side: BorderSide(
                    color: selectedFilter == filter.$1
                        ? _accent.withValues(alpha: 0.42)
                        : _borderLight,
                  ),
                  labelStyle: TextStyle(
                    color: selectedFilter == filter.$1
                        ? _textPrimary
                        : _textSecondary,
                    fontWeight: selectedFilter == filter.$1
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [search, const SizedBox(height: 12), chips],
            );
          }
          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 14),
              Flexible(child: chips),
            ],
          );
        },
      ),
    );
  }
}

class _MessagingQrPanel extends StatelessWidget {
  const _MessagingQrPanel({required this.qrState});

  final MessagingQrState qrState;

  @override
  Widget build(BuildContext context) {
    final qrImage = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Image.network(
        'https://api.qrserver.com/v1/create-qr-code/?data=${Uri.encodeComponent(qrState.qr)}&size=280x280',
        width: 168,
        height: 168,
        fit: BoxFit.contain,
      ),
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusPill(label: 'Awaiting scan', color: _warning),
        const SizedBox(height: 12),
        Text(
          'Scan to finish ${qrState.platformLabel}',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Keep this panel open until the platform confirms the connection.',
          style: TextStyle(color: _textSecondary, height: 1.45),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _warning.withValues(alpha: 0.3)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 680) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                copy,
                const SizedBox(height: 16),
                Center(child: qrImage),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: 24),
              qrImage,
            ],
          );
        },
      ),
    );
  }
}

class _MessagingGroupHeader extends StatelessWidget {
  const _MessagingGroupHeader({
    required this.title,
    required this.subtitle,
    required this.count,
  });

  final String title;
  final String subtitle;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: _textSecondary, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _StatusPill(label: '$count shown', color: _textSecondary),
      ],
    );
  }
}

class _MessagingActivityPanel extends StatelessWidget {
  const _MessagingActivityPanel({required this.messages});

  final List<MessagingMessage> messages;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent Channel Activity',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusPill(label: '${messages.length} events', color: _info),
            ],
          ),
          const SizedBox(height: 14),
          if (messages.isEmpty)
            const _EmptyCard(
              title: 'No recent channel activity',
              subtitle:
                  'Incoming and outgoing channel messages will appear here.',
            )
          else
            Column(
              children: [
                for (final message in messages.take(12))
                  _MessagingActivityItem(message: message),
              ],
            ),
        ],
      ),
    );
  }
}

class _MessagingActivityItem extends StatelessWidget {
  const _MessagingActivityItem({required this.message});

  final MessagingMessage message;

  @override
  Widget build(BuildContext context) {
    final isOutbound = message.outgoing;
    final color = isOutbound ? _accent : _success;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isOutbound ? Icons.north_east_rounded : Icons.south_west_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _StatusPill(
                      label: message.platform.toUpperCase(),
                      color: _info,
                    ),
                    Text(
                      message.senderLabel,
                      style: TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      message.createdAtLabel,
                      style: TextStyle(color: _textMuted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  message.content.ifEmpty('[empty]'),
                  style: TextStyle(color: _textSecondary, height: 1.35),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RunsPanel extends StatefulWidget {
  const RunsPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<RunsPanel> createState() => _RunsPanelState();
}

class _RunsPanelState extends State<RunsPanel> {
  late final TextEditingController _searchController;
  String? _selectedRunId;
  String _statusFilter = 'all';
  RunDetailSnapshot? _detail;
  bool _loadingDetail = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(_handleSearchChanged);
    _syncSelection();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RunsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSelection();
  }

  void _handleSearchChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
    _syncSelection();
  }

  List<RunSummary> get _filteredRuns {
    final query = _searchController.text.trim().toLowerCase();
    return widget.controller.recentRuns.where((run) {
      final statusMatches =
          _statusFilter == 'all' ||
          (_statusFilter == 'failed'
              ? run.isFailure
              : run.status.toLowerCase() == _statusFilter);
      if (!statusMatches) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final haystack = <String>[
        run.title,
        run.status,
        run.model,
        run.triggerSource,
        run.error,
        run.id,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  void _syncSelection() {
    final runs = _filteredRuns;
    if (runs.isEmpty) {
      _selectedRunId = null;
      _detail = null;
      return;
    }
    if (_selectedRunId == null ||
        !runs.any((run) => run.id == _selectedRunId)) {
      _selectRun(runs.first.id);
    }
  }

  Future<void> _selectRun(String runId, {bool force = false}) async {
    setState(() {
      _selectedRunId = runId;
      _loadingDetail = true;
    });
    try {
      final detail = await widget.controller.fetchRunDetail(
        runId,
        force: force,
      );
      if (!mounted || _selectedRunId != runId) {
        return;
      }
      setState(() {
        _detail = detail;
        _loadingDetail = false;
      });
    } catch (_) {
      if (!mounted || _selectedRunId != runId) {
        return;
      }
      setState(() {
        _loadingDetail = false;
      });
    }
  }

  Future<void> _refreshRuns() async {
    await widget.controller.refreshRunsOnly();
    if (!mounted) {
      return;
    }
    final selectedRunId = _selectedRunId;
    if (selectedRunId != null &&
        _filteredRuns.any((run) => run.id == selectedRunId)) {
      await _selectRun(selectedRunId, force: true);
    } else {
      _syncSelection();
    }
    setState(() {});
  }

  void _setStatusFilter(String value) {
    setState(() {
      _statusFilter = value;
    });
    _syncSelection();
  }

  Future<void> _copyResponse(String response) async {
    if (response.trim().isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: response));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied final response')));
  }

  Future<void> _deleteSelectedRun() async {
    final run = widget.controller.recentRuns.cast<RunSummary?>().firstWhere(
      (item) => item?.id == _selectedRunId,
      orElse: () => null,
    );
    if (run == null) {
      return;
    }
    await _confirmDelete(
      context,
      title: 'Delete run?',
      message:
          'Remove "${run.title}" and its recorded steps from the run history?',
      onConfirm: () async {
        await widget.controller.deleteRun(run.id);
        if (!mounted) {
          return;
        }
        _syncSelection();
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final filteredRuns = _filteredRuns;
    final selected = filteredRuns.cast<RunSummary?>().firstWhere(
      (run) => run?.id == _selectedRunId,
      orElse: () => null,
    );
    final detail = _detail?.run.id == selected?.id ? _detail : null;

    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Runs',
          subtitle:
              'Inspect recent runs, failures, tool steps, and final responses.',
          trailing: OutlinedButton.icon(
            onPressed: _refreshRuns,
            icon: Icon(Icons.refresh),
            label: Text('Refresh'),
          ),
        ),
        if (controller.errorMessage != null) ...<Widget>[
          _InlineError(message: controller.errorMessage!),
          const SizedBox(height: 16),
        ],
        if (controller.activeRun != null ||
            controller.toolEvents.isNotEmpty) ...<Widget>[
          _RunStatusPanel(
            run: controller.activeRun,
            tools: controller.toolEvents,
          ),
          const SizedBox(height: 16),
        ],
        if (controller.recentRuns.isEmpty)
          const _EmptyCard(
            title: 'No runs yet',
            subtitle:
                'Send a task from chat and its execution history will show up here.',
          )
        else ...<Widget>[
          _RunsMetricsStrip(
            runs: filteredRuns,
            totalLoaded: controller.recentRuns.length,
          ),
          const SizedBox(height: 16),
          _RunsFilterBar(
            searchController: _searchController,
            statusFilter: _statusFilter,
            onStatusChanged: _setStatusFilter,
          ),
          const SizedBox(height: 16),
          if (filteredRuns.isEmpty)
            const _EmptyCard(
              title: 'No matching runs',
              subtitle:
                  'Try clearing the search or switching the status filter.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1120;
                final historyPane = _RunsHistoryPane(
                  runs: filteredRuns,
                  selectedRunId: _selectedRunId,
                  onSelect: _selectRun,
                );
                final detailPane = _RunDetailWorkspace(
                  run: selected,
                  detail: detail,
                  loading: _loadingDetail,
                  onDelete: _deleteSelectedRun,
                  onCopyResponse: _copyResponse,
                );
                if (!wide) {
                  return Column(
                    children: <Widget>[
                      detailPane,
                      const SizedBox(height: 16),
                      historyPane,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(width: 360, child: historyPane),
                    const SizedBox(width: 16),
                    Expanded(child: detailPane),
                  ],
                );
              },
            ),
        ],
      ],
    );
  }
}

class _MessagingCard extends StatelessWidget {
  const _MessagingCard({
    required this.platform,
    required this.status,
    required this.whitelist,
    required this.controller,
    required this.onConnect,
    required this.onDisconnect,
    required this.onLogout,
  });

  final MessagingPlatformDescriptor platform;
  final MessagingPlatformStatus? status;
  final List<String> whitelist;
  final NeoAgentController controller;
  final Future<void> Function() onConnect;
  final Future<void> Function() onDisconnect;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final connected = status?.isConnected ?? false;
    final configured = status != null && status!.status != 'not_configured';
    final accent = platform.accent;
    final actionLabel = connected
        ? 'Connected'
        : configured
        ? 'Reconnect'
        : 'Connect';
    final accessLabel = whitelist.isEmpty
        ? 'Open access'
        : '${whitelist.length} allowed';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: connected ? accent.withValues(alpha: 0.48) : _borderLight,
        ),
        boxShadow: [
          if (connected)
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(platform.icon, color: accent, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      platform.label,
                      style: TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      status?.authLabel ?? 'Not configured',
                      style: TextStyle(color: _textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StatusPill(
                label: connected
                    ? 'Live'
                    : configured
                    ? 'Ready'
                    : 'Setup',
                color: connected
                    ? _success
                    : configured
                    ? _warning
                    : _textMuted,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            platform.subtitle,
            style: TextStyle(color: _textSecondary, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MessagingMiniPill(
                icon: Icons.admin_panel_settings_outlined,
                label: accessLabel,
              ),
              if (configured && !connected)
                const _MessagingMiniPill(
                  icon: Icons.tune_rounded,
                  label: 'Configured',
                ),
              if (platform.configFields.isNotEmpty)
                _MessagingMiniPill(
                  icon: Icons.edit_note_rounded,
                  label: '${platform.configFields.length} fields',
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: connected
                    ? OutlinedButton.icon(
                        onPressed: onDisconnect,
                        icon: Icon(Icons.link_off_rounded, size: 18),
                        label: Text(
                          'Disconnect',
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: onConnect,
                        icon: Icon(Icons.power_settings_new_rounded, size: 18),
                        label: Text(
                          actionLabel,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: FilledButton.styleFrom(backgroundColor: accent),
                      ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Access list',
                onPressed: () => _editWhitelist(context, controller),
                icon: Icon(Icons.group_add_outlined),
              ),
              if (platform.id == 'waveshare_wearable') ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Pairing code',
                  onPressed: onConnect,
                  icon: Icon(Icons.key_rounded),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Connected devices',
                  onPressed: () => _showWearableDevices(context, controller),
                  icon: Icon(Icons.watch_rounded),
                ),
              ],
              if (platform.id == 'telnyx') ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Voice PIN',
                  onPressed: () => _editTelnyxSecret(context, controller),
                  icon: Icon(Icons.password_outlined),
                ),
              ],
              if (connected) ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Logout',
                  onPressed: onLogout,
                  icon: Icon(Icons.logout_rounded),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editWhitelist(
    BuildContext context,
    NeoAgentController controller,
  ) async {
    switch (platform.id) {
      case 'whatsapp':
        await _showStringListDialog(
          context,
          title: 'WhatsApp allowlist',
          subtitle:
              'Only listed phone numbers can trigger the agent. Leave empty to allow any sender.',
          values: controller.currentMessagingWhitelist('whatsapp'),
          label: 'Phone number',
          onSave: controller.saveWhatsAppWhitelist,
        );
        break;
      case 'telnyx':
        await _showStringListDialog(
          context,
          title: 'Telnyx allowlist',
          subtitle:
              'Only listed caller numbers can reach voice automation. Leave empty to allow any caller.',
          values: controller.currentMessagingWhitelist('telnyx'),
          label: 'Phone number',
          onSave: controller.saveTelnyxWhitelist,
        );
        break;
      case 'discord':
        await _showStringListDialog(
          context,
          title: 'Discord allowlist',
          subtitle:
              'Use user:, channel:, guild:, role: prefixes to decide who can trigger the agent.',
          values: controller.currentMessagingWhitelist('discord'),
          label: 'user:123 or channel:456',
          onSave: controller.saveDiscordWhitelist,
        );
        break;
      case 'telegram':
        await _showStringListDialog(
          context,
          title: 'Telegram allowlist',
          subtitle:
              'Only listed Telegram chat IDs can trigger the agent. Leave empty to allow any chat.',
          values: controller.currentMessagingWhitelist('telegram'),
          label: 'Chat ID',
          onSave: controller.saveTelegramWhitelist,
        );
        break;
      default:
        await _showStringListDialog(
          context,
          title: '${platform.label} access list',
          subtitle:
              'Limit who can trigger the agent from this channel. Leave empty to allow any sender.',
          values: controller.currentMessagingWhitelist(platform.id),
          label: 'Allowed sender or channel',
          onSave: (values) =>
              controller.saveMessagingWhitelist(platform.id, values),
        );
    }
  }

  Future<void> _showWearableDevices(
    BuildContext context,
    NeoAgentController controller,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final devices = await controller.fetchMessagingPlatformDevices(
        platform.id,
      );
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Wearable devices'),
            content: SizedBox(
              width: 420,
              child: devices.isEmpty
                  ? const Text('No wearable devices have reported yet.')
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: devices.length,
                      separatorBuilder: (_, __) => const Divider(height: 14),
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        final name = (device['name'] ?? 'Unnamed').toString();
                        final status = (device['status'] ?? 'unknown')
                            .toString();
                        final battery = device['batteryLevel'];
                        final mac = (device['macAddress'] ?? 'n/a').toString();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text('Status: $status'),
                            Text('Battery: ${battery ?? 'n/a'}'),
                            Text('MAC: $mac'),
                          ],
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to load devices: $error')),
      );
    }
  }

  Future<void> _editTelnyxSecret(
    BuildContext context,
    NeoAgentController controller,
  ) async {
    final initial =
        controller.settings['platform_voice_secret_telnyx']?.toString() ?? '';
    final saved = await _showTextSettingDialog(
      context,
      title: 'Voice PIN',
      subtitle:
          'Set the PIN callers must enter before the voice agent answers.',
      label: 'PIN or passphrase',
      initialValue: initial,
      obscureText: true,
    );
    if (saved != null) {
      await controller.saveTelnyxVoiceSecret(saved);
    }
  }
}

Future<void> _showStringListDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
  required List<String> values,
  required String label,
  required Future<void> Function(List<String> values) onSave,
}) async {
  final controller = TextEditingController(text: values.join('\n'));
  try {
    final saved = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _bgCard,
        title: Text(title),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(subtitle, style: TextStyle(color: _textSecondary)),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                minLines: 5,
                maxLines: 10,
                decoration: InputDecoration(
                  labelText: label,
                  helperText: 'One entry per line',
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final values = controller.text
                  .split(RegExp(r'\r?\n'))
                  .map((value) => value.trim())
                  .where((value) => value.isNotEmpty)
                  .toSet()
                  .toList();
              Navigator.of(context).pop(values);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
    if (saved != null) {
      await onSave(saved);
    }
  } finally {
    controller.dispose();
  }
}

Future<String?> _showTextSettingDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String label,
  required String initialValue,
  bool obscureText = false,
}) async {
  final controller = TextEditingController(text: initialValue);
  try {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _bgCard,
        title: Text(title),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(subtitle, style: TextStyle(color: _textSecondary)),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                obscureText: obscureText,
                decoration: InputDecoration(labelText: label),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text('Save'),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}

class _MessagingMiniPill extends StatelessWidget {
  const _MessagingMiniPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RunsMetricsStrip extends StatelessWidget {
  const _RunsMetricsStrip({required this.runs, required this.totalLoaded});

  final List<RunSummary> runs;
  final int totalLoaded;

  @override
  Widget build(BuildContext context) {
    final running = runs.where((run) => run.status == 'running').length;
    final failed = runs.where((run) => run.isFailure).length;
    final completed = runs.where((run) => run.status == 'completed').length;
    final tokens = runs.fold<int>(0, (sum, run) => sum + run.totalTokens);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        _RunMetricCard(
          title: 'Showing',
          value: '${runs.length}',
          helper: totalLoaded == runs.length
              ? 'Recent runs loaded'
              : 'Filtered from $totalLoaded loaded runs',
          color: _info,
        ),
        _RunMetricCard(
          title: 'Completed',
          value: '$completed',
          helper: 'Finished successfully',
          color: _success,
        ),
        _RunMetricCard(
          title: 'Failed',
          value: '$failed',
          helper: 'Need attention',
          color: _danger,
        ),
        _RunMetricCard(
          title: 'Tokens',
          value: _formatNumber(tokens),
          helper: 'Across visible runs',
          color: _accentHover,
        ),
        if (running > 0)
          _RunMetricCard(
            title: 'Running',
            value: '$running',
            helper: 'Still in progress',
            color: _warning,
          ),
      ],
    );
  }
}

class _RunMetricCard extends StatelessWidget {
  const _RunMetricCard({
    required this.title,
    required this.value,
    required this.helper,
    required this.color,
  });

  final String title;
  final String value;
  final String helper;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 220),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: TextStyle(color: _textSecondary)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(helper, style: TextStyle(color: _textSecondary)),
        ],
      ),
    );
  }
}

class _RunsFilterBar extends StatelessWidget {
  const _RunsFilterBar({
    required this.searchController,
    required this.statusFilter,
    required this.onStatusChanged,
  });

  final TextEditingController searchController;
  final String statusFilter;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    const filters = <String>['all', 'running', 'completed', 'failed'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _SectionTitle('Filter Runs'),
            const SizedBox(height: 12),
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search title, model, trigger, error, or run id',
                suffixIcon: searchController.text.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: searchController.clear,
                        icon: Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: filters.map((filter) {
                return FilterChip(
                  label: Text(_titleCase(filter)),
                  selected: statusFilter == filter,
                  selectedColor: _accentMuted,
                  checkmarkColor: _accent,
                  backgroundColor: _bgSecondary,
                  side: BorderSide(color: _border),
                  onSelected: (_) => onStatusChanged(filter),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunsHistoryPane extends StatelessWidget {
  const _RunsHistoryPane({
    required this.runs,
    required this.selectedRunId,
    required this.onSelect,
  });

  final List<RunSummary> runs;
  final String? selectedRunId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: _SectionTitle('Run History')),
                Text(
                  '${runs.length} items',
                  style: TextStyle(color: _textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...runs.map((run) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RunHistoryRow(
                  run: run,
                  selected: run.id == selectedRunId,
                  onTap: () => onSelect(run.id),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _RunHistoryRow extends StatelessWidget {
  const _RunHistoryRow({
    required this.run,
    required this.selected,
    required this.onTap,
  });

  final RunSummary run;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? _accentMuted : _bgSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? _accent : _border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(
                color: run.statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    run.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, height: 1.2),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${run.triggerLabel} • ${run.createdAtLabel}${run.durationLabel == 'In progress' ? '' : ' • ${run.durationLabel}'}',
                    style: TextStyle(color: _textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${run.modelLabel} • ${run.totalTokensLabel} tokens',
                    style: TextStyle(color: _textSecondary, fontSize: 12),
                  ),
                  if (run.error.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      run.error,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _danger,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                _StatusPill(label: run.statusLabel, color: run.statusColor),
                const SizedBox(height: 12),
                Icon(
                  Icons.chevron_right,
                  color: selected ? _textPrimary : _textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RunDetailWorkspace extends StatelessWidget {
  const _RunDetailWorkspace({
    required this.run,
    required this.detail,
    required this.loading,
    required this.onDelete,
    required this.onCopyResponse,
  });

  final RunSummary? run;
  final RunDetailSnapshot? detail;
  final bool loading;
  final Future<void> Function() onDelete;
  final Future<void> Function(String response) onCopyResponse;

  @override
  Widget build(BuildContext context) {
    if (run == null) {
      return const _EmptyCard(
        title: 'Select a run',
        subtitle: 'Pick a run from the history list to inspect its steps.',
      );
    }

    final selectedRun = run!;
    final snapshot = detail;
    return Column(
      children: <Widget>[
        _RunHeroCard(run: selectedRun, onDelete: onDelete),
        const SizedBox(height: 16),
        if (loading && snapshot == null)
          Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Row(
                children: <Widget>[
                  SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Loading run detail...',
                    style: TextStyle(color: _textSecondary),
                  ),
                ],
              ),
            ),
          )
        else if (snapshot != null) ...<Widget>[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _RunMetricCard(
                title: 'Steps',
                value: '${snapshot.steps.length}',
                helper: 'Recorded events',
                color: _info,
              ),
              _RunMetricCard(
                title: 'Completed tools',
                value: '${snapshot.completedTools}',
                helper: 'Successful tool calls',
                color: _success,
              ),
              _RunMetricCard(
                title: 'Failures',
                value: '${snapshot.failedTools}',
                helper: 'Tool errors',
                color: _danger,
              ),
              _RunMetricCard(
                title: 'Helpers',
                value: '${snapshot.helperCount}',
                helper: 'Subagents or helpers',
                color: _accentHover,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _RunResponseCard(
            response: snapshot.response,
            onCopy: () => onCopyResponse(snapshot.response),
          ),
          const SizedBox(height: 16),
          _RunTimelineCard(steps: snapshot.steps, loading: loading),
        ] else
          const _EmptyCard(
            title: 'No detail available',
            subtitle: 'This run does not have step detail yet.',
          ),
      ],
    );
  }
}

class _RunHeroCard extends StatelessWidget {
  const _RunHeroCard({required this.run, required this.onDelete});

  final RunSummary run;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            run.statusColor.withValues(alpha: 0.18),
            _bgSecondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        _StatusPill(
                          label: run.statusLabel,
                          color: run.statusColor,
                        ),
                        _MetaPill(
                          label: run.triggerLabel,
                          icon: Icons.bolt_outlined,
                        ),
                        _MetaPill(
                          label: run.modelLabel,
                          icon: Icons.memory_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      run.title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        _MetaPill(
                          label: 'Started ${run.createdAtLabel}',
                          icon: Icons.schedule_outlined,
                        ),
                        _MetaPill(
                          label: run.durationLabel,
                          icon: Icons.timer_outlined,
                        ),
                        _MetaPill(
                          label: '${run.totalTokensLabel} tokens',
                          icon: Icons.toll_outlined,
                        ),
                        _MetaPill(
                          label: run.id.length <= 12
                              ? run.id
                              : '${run.id.substring(0, 12)}…',
                          icon: Icons.tag_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline),
                label: Text('Delete'),
              ),
            ],
          ),
          if (run.error.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0x19EF4444),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x4CEF4444)),
              ),
              child: Text(run.error, style: TextStyle(height: 1.45)),
            ),
          ],
        ],
      ),
    );
  }
}

class _RunResponseCard extends StatelessWidget {
  const _RunResponseCard({required this.response, required this.onCopy});

  final String response;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: _SectionTitle('Final Response')),
                OutlinedButton.icon(
                  onPressed: response.trim().isEmpty ? null : onCopy,
                  icon: Icon(Icons.copy_all_outlined),
                  label: Text('Copy'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (response.trim().isEmpty)
              Text(
                'No final response was captured for this run.',
                style: TextStyle(color: _textSecondary),
              )
            else
              MarkdownBody(
                data: response,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                    .copyWith(
                      p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _textPrimary,
                        height: 1.6,
                      ),
                      code: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                        backgroundColor: _bgSecondary,
                        color: _textPrimary,
                      ),
                      blockquoteDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: _bgSecondary,
                        border: Border.all(color: _border),
                      ),
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RunTimelineCard extends StatelessWidget {
  const _RunTimelineCard({required this.steps, required this.loading});

  final List<RunStepItem> steps;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: _SectionTitle('Step Timeline')),
                if (loading)
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (steps.isEmpty)
              Text(
                'No run steps recorded yet.',
                style: TextStyle(color: _textSecondary),
              )
            else
              ...steps.map((step) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RunStepCard(step: step),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _RunStepCard extends StatelessWidget {
  const _RunStepCard({required this.step});

  final RunStepItem step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          initiallyExpanded:
              step.status == 'failed' || step.status == 'running',
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: step.statusColor.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${step.displayIndex}',
                style: TextStyle(
                  color: step.statusColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(step.label, style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                step.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _StatusPill(label: step.statusLabel, color: step.statusColor),
                  _MetaPill(label: step.typeLabel, icon: Icons.layers_outlined),
                  if (step.startedAt != null)
                    _MetaPill(
                      label: step.startedAtLabel!,
                      icon: Icons.schedule_outlined,
                    ),
                  if (step.durationLabel != null)
                    _MetaPill(
                      label: step.durationLabel!,
                      icon: Icons.timer_outlined,
                    ),
                  if (step.tokensUsed > 0)
                    _MetaPill(
                      label: '${_formatNumber(step.tokensUsed)} tokens',
                      icon: Icons.toll_outlined,
                    ),
                ],
              ),
            ],
          ),
          children: <Widget>[
            if (step.description.trim().isNotEmpty &&
                step.description.trim() != step.summary.trim())
              _RunDetailBlock(label: 'Description', value: step.description),
            if (step.inputSummary.trim().isNotEmpty)
              _RunDetailBlock(label: 'Input summary', value: step.inputSummary),
            if (step.toolInput.trim().isNotEmpty)
              _RunDetailBlock(
                label: 'Tool input',
                value: _truncateRunText(step.toolInput),
                monospace: true,
              ),
            if (step.error.trim().isNotEmpty)
              _RunDetailBlock(
                label: 'Error',
                value: step.error,
                monospace: true,
              )
            else if (step.result.trim().isNotEmpty)
              _RunDetailBlock(
                label: 'Result',
                value: _truncateRunText(step.result),
                monospace: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _RunDetailBlock extends StatelessWidget {
  const _RunDetailBlock({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: _textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _bgPrimary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: SelectableText(
              value,
              style: TextStyle(
                height: 1.5,
                fontSize: 12.5,
                color: _textPrimary,
                fontFamily: monospace
                    ? GoogleFonts.jetBrainsMono().fontFamily
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
  final lower = RegExp(r'[a-z]').hasMatch(value);
  final upper = RegExp(r'[A-Z]').hasMatch(value);
  final digits = RegExp(r'[0-9]').hasMatch(value);
  final symbols = RegExp(r'[^A-Za-z0-9]').hasMatch(value);
  final variety = <bool>[
    lower,
    upper,
    digits,
    symbols,
  ].where((item) => item).length;
  final normalized = value.toLowerCase();
  final userHints = <String>{
    username.trim().toLowerCase(),
    email.trim().toLowerCase(),
    email.trim().toLowerCase().split('@').first,
  }.where((item) => item.length >= 3);
  final containsUserInfo = userHints.any(normalized.contains);
  final obviousPattern =
      RegExp(r'(.)\1\1').hasMatch(value) ||
      normalized.contains('password') ||
      normalized.contains('1234') ||
      normalized.contains('qwerty');

  var score = 0;
  if (value.length >= 8) score += 1;
  if (value.length >= 12) score += 1;
  if (variety >= 3) score += 1;
  if (variety == 4 || value.length >= 16) score += 1;
  if (containsUserInfo || obviousPattern) score -= 1;
  score = score.clamp(0, 4);

  if (value.length < 8) {
    return _PasswordStrengthInfo(
      score: 1,
      label: 'Weak',
      message: 'Use at least 8 characters.',
      color: _danger,
    );
  }
  if (containsUserInfo) {
    return _PasswordStrengthInfo(
      score: 2,
      label: 'Fair',
      message: 'Do not include your username or email.',
      color: _warning,
    );
  }
  if (obviousPattern) {
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

enum AccountSettingsTab { account, security }

class AccountSettingsPanel extends StatefulWidget {
  const AccountSettingsPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<AccountSettingsPanel> createState() => _AccountSettingsPanelState();
}

class _AccountSettingsPanelState extends State<AccountSettingsPanel> {
  AccountSettingsTab _selectedTab = AccountSettingsTab.account;
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
  String? _emailSuccessMessage;
  String? _emailInlineError;
  String? _passwordSuccessMessage;
  String? _passwordInlineError;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 860;
    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Account settings',
          subtitle:
              'Manage your account email, two-factor authentication, and active sessions.',
          trailing: OutlinedButton.icon(
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
          ),
        ),
        if (widget.controller.errorMessage != null) ...<Widget>[
          _InlineError(message: widget.controller.errorMessage!),
          const SizedBox(height: 16),
        ],
        if (compact)
          _AccountSettingsTabs(
            selected: _selectedTab,
            onSelected: (value) => setState(() => _selectedTab = value),
          )
        else
          const SizedBox.shrink(),
        if (compact) const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: compact
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
      case AccountSettingsTab.security:
        return _buildSecurityPanel();
    }
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
                  final saved = await controller.updateAccountEmail(
                    email: _emailController.text,
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

  Widget _buildSecurityPanel() {
    final controller = widget.controller;
    final twoFactorEnabled = controller.accountTwoFactor['enabled'] == true;
    final recoveryCount = _asInt(
      controller.accountTwoFactor['recoveryCodesRemaining'],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
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
            session.current ? Icons.devices_outlined : Icons.public_outlined,
            color: session.current ? _success : _textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  session.current
                      ? '${session.location} · Current session'
                      : session.location,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (session.ipAddress.isNotEmpty) session.ipAddress,
                    'Last seen ${session.lastSeenLabel}',
                  ].join(' · '),
                  style: TextStyle(color: _textSecondary),
                ),
                if (session.userAgent.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    session.userAgent,
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

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  late bool _headlessBrowser;
  late String _browserBackend;
  late bool _smarterSelector;
  late Set<String> _enabledModels;
  late String _defaultChatModel;
  late String _defaultSubagentModel;
  late String _fallbackModel;
  final Map<String, bool> _providerEnabled = <String, bool>{};
  final Map<String, TextEditingController> _providerBaseUrlControllers =
      <String, TextEditingController>{};
  final Set<String> _expandedProviderIds = <String>{};

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  @override
  void dispose() {
    for (final controller in _providerBaseUrlControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller.settings != widget.controller.settings ||
        oldWidget.controller.aiProviders != widget.controller.aiProviders ||
        oldWidget.controller.supportedModels !=
            widget.controller.supportedModels) {
      _hydrate();
    }
  }

  void _hydrate() {
    final controller = widget.controller;
    final knownModels = controller.supportedModels
        .map((model) => model.id)
        .toSet();
    final availableModels = controller.supportedModels
        .where((model) => model.available)
        .map((model) => model.id)
        .toSet();
    _headlessBrowser = controller.headlessBrowser;
    _browserBackend = _normalizeBrowserBackend(controller.browserBackend);
    _smarterSelector = controller.smarterSelector;
    _enabledModels = controller.enabledModelIds
        .where((id) => knownModels.contains(id))
        .toSet();
    if (_enabledModels.isEmpty && availableModels.isNotEmpty) {
      _enabledModels = availableModels;
    }
    _defaultChatModel = controller.defaultChatModel;
    _defaultSubagentModel = controller.defaultSubagentModel;
    _fallbackModel = controller.fallbackModel;

    final providerConfigs = controller.aiProviderConfigs;
    final providerIds = <String>{
      ...providerConfigs.keys,
      ...controller.aiProviders.map((provider) => provider.id),
    };

    for (final providerId in providerIds) {
      final config =
          providerConfigs[providerId] ?? AiProviderConfig.empty(providerId);
      _providerEnabled[providerId] = config.enabled;
      _syncTextController(
        _providerBaseUrlControllers,
        providerId,
        config.baseUrl,
      );
    }

    _pruneControllers(_providerBaseUrlControllers, providerIds);
    _providerEnabled.removeWhere((id, _) => !providerIds.contains(id));
  }

  String _normalizeBrowserBackend(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'extension' ? 'extension' : 'cloud';
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final availableModels = controller.supportedModels
        .where((model) => model.available)
        .toList();
    final routingModels = availableModels.isEmpty
        ? controller.supportedModels
        : availableModels;
    final modelChoices = <DropdownMenuItem<String>>[
      const DropdownMenuItem<String>(
        value: 'auto',
        child: Text('Smart Selector (Auto)'),
      ),
      ...routingModels.map(
        (model) =>
            DropdownMenuItem<String>(value: model.id, child: Text(model.label)),
      ),
    ];
    final enabledSmartModels = _enabledModels
        .where((id) => routingModels.any((model) => model.id == id))
        .length;

    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Settings',
          subtitle:
              'Configure model access, routing, and runtime behavior from one place.',
          trailing: FilledButton.icon(
            onPressed: controller.isSavingSettings
                ? null
                : () => controller.saveSettings(
                    headlessBrowser: _headlessBrowser,
                    browserBackend: _browserBackend == 'extension'
                        ? 'extension'
                        : controller.cloudBrowserBackend,
                    smarterSelector: _smarterSelector,
                    enabledModels: _enabledModels.toList(),
                    defaultChatModel: _defaultChatModel,
                    defaultSubagentModel: _defaultSubagentModel,
                    fallbackModel: _fallbackModel,
                    aiProviderConfigs: _buildProviderPayload(),
                  ),
            style: FilledButton.styleFrom(backgroundColor: _accent),
            icon: controller.isSavingSettings
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(Icons.save_outlined),
            label: Text('Save'),
          ),
        ),
        if (controller.errorMessage != null) ...<Widget>[
          _InlineError(message: controller.errorMessage!),
          const SizedBox(height: 16),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('AI Providers'),
                const SizedBox(height: 14),
                if (controller.aiProviders.isEmpty)
                  Text(
                    'Provider metadata is unavailable on this server version.',
                    style: TextStyle(color: _textSecondary),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 960;
                      final cardWidth = compact
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 16) / 2;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: controller.aiProviders.map((provider) {
                          return SizedBox(
                            width: cardWidth,
                            child: _AiProviderCard(
                              provider: provider,
                              enabled:
                                  _providerEnabled[provider.id] ??
                                  controller
                                      .aiProviderConfigs[provider.id]
                                      ?.enabled ??
                                  true,
                              models: controller.supportedModels
                                  .where(
                                    (model) => model.provider == provider.id,
                                  )
                                  .toList(),
                              baseUrlController:
                                  _providerBaseUrlControllers[provider.id]!,
                              expanded: _expandedProviderIds.contains(
                                provider.id,
                              ),
                              onEnabledChanged: (value) {
                                setState(() {
                                  _providerEnabled[provider.id] = value;
                                });
                              },
                              onExpandToggle: () {
                                setState(() {
                                  if (_expandedProviderIds.contains(
                                    provider.id,
                                  )) {
                                    _expandedProviderIds.remove(provider.id);
                                  } else {
                                    _expandedProviderIds.add(provider.id);
                                  }
                                });
                              },
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Model Routing'),
                const SizedBox(height: 14),
                if (routingModels.isNotEmpty) ...<Widget>[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 940;
                      final cardWidth = compact
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 24) / 3;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: <Widget>[
                          SizedBox(
                            width: cardWidth,
                            child: _RoutingSelectCard(
                              label: 'Chat',
                              icon: Icons.chat_bubble_outline,
                              value: _ensureModelValue(
                                _defaultChatModel,
                                routingModels,
                                allowAuto: true,
                              ),
                              items: modelChoices,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _defaultChatModel = value);
                                }
                              },
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _RoutingSelectCard(
                              label: 'Sub-agent',
                              icon: Icons.bolt_outlined,
                              value: _ensureModelValue(
                                _defaultSubagentModel,
                                routingModels,
                                allowAuto: true,
                              ),
                              items: modelChoices,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _defaultSubagentModel = value);
                                }
                              },
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _RoutingSelectCard(
                              label: 'Fallback',
                              icon: Icons.shield_outlined,
                              value: _ensureModelValue(
                                _fallbackModel,
                                routingModels,
                                allowAuto: false,
                              ),
                              items: routingModels
                                  .map(
                                    (model) => DropdownMenuItem<String>(
                                      value: model.id,
                                      child: Text(model.label),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _fallbackModel = value);
                                }
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Smart Selector Allowed Models',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: controller.supportedModels.map((model) {
                    final selected = _enabledModels.contains(model.id);
                    return FilterChip(
                      label: Text(
                        model.available
                            ? model.label
                            : '${model.label} (${model.providerStatusLabel})',
                      ),
                      selected: selected,
                      selectedColor: _accentMuted,
                      checkmarkColor: _accent,
                      backgroundColor: _bgSecondary,
                      side: BorderSide(
                        color: model.available
                            ? _border
                            : _warning.withValues(alpha: 0.35),
                      ),
                      onSelected: model.available
                          ? (value) {
                              setState(() {
                                if (value) {
                                  _enabledModels.add(model.id);
                                } else if (_enabledModels.length > 1) {
                                  _enabledModels.remove(model.id);
                                }
                              });
                            }
                          : null,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Text(
                  availableModels.isEmpty
                      ? 'Enable a ready provider above to unlock model routing.'
                      : '$enabledSmartModels models are currently eligible for smart routing.',
                  style: TextStyle(color: _textSecondary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Automation'),
                const SizedBox(height: 12),
                _SettingToggle(
                  title: 'Browser',
                  subtitle: 'Run browser headless (no visible window)',
                  value: _headlessBrowser,
                  onChanged: (value) =>
                      setState(() => _headlessBrowser = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _browserBackend,
                  decoration: const InputDecoration(
                    labelText: 'Browser backend',
                    helperText:
                        'Cloud uses this deployment. Extension uses a paired Chrome browser.',
                  ),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: 'cloud',
                      child: Text('Cloud (local)'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'extension',
                      child: Text('Chrome extension'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _browserBackend = value);
                    }
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  _browserBackend == 'extension'
                      ? (controller.browserExtensionConnected
                            ? 'Chrome extension connected.'
                            : 'Chrome extension selected. Download it here, load it unpacked in Chrome on the remote machine, then pair after login.')
                      : controller.cloudBrowserBackend == 'vm'
                      ? "Cloud uses this deployment's isolated VM browser runtime."
                      : "Cloud uses this deployment's local host browser runtime.",
                  style: TextStyle(color: _textSecondary, height: 1.4),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: controller.downloadBrowserExtension,
                      icon: Icon(Icons.download_outlined),
                      label: Text('Download extension'),
                    ),
                    OutlinedButton.icon(
                      onPressed: controller.refreshBrowserExtensionStatus,
                      icon: Icon(Icons.sync),
                      label: Text('Refresh status'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SettingToggle(
                  title: 'Smart Selection',
                  subtitle:
                      'Automatically select the best model based on task type',
                  value: _smarterSelector,
                  onChanged: (value) =>
                      setState(() => _smarterSelector = value),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _SectionTitle('Token Usage'),
                    SizedBox(width: 8),
                    Icon(Icons.info_outline, size: 16, color: _textSecondary),
                  ],
                ),
                const SizedBox(height: 12),
                if (controller.tokenUsage == null)
                  Text(
                    'Token usage unavailable on this server version.',
                    style: TextStyle(color: _textSecondary),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Total: ${controller.tokenUsage!.totalTokensLabel} tokens across ${controller.tokenUsage!.totalRunsLabel} runs',
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Last 7 days: ${controller.tokenUsage!.last7DaysTokensLabel} tokens in ${controller.tokenUsage!.last7DaysRunsLabel} runs',
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Avg/run: ${controller.tokenUsage!.avgTokensPerRunLabel} tokens',
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (controller.updateStatus.allowSelfUpdate) ...<Widget>[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 780;
                      final channelPicker = DropdownButtonFormField<String>(
                        initialValue: controller.updateStatus.releaseChannel,
                        decoration: const InputDecoration(
                          labelText: 'Release Channel',
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem<String>(
                            value: 'stable',
                            child: Text('Stable'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'beta',
                            child: Text('Beta'),
                          ),
                        ],
                        onChanged:
                            controller.isSavingReleaseChannel ||
                                controller.isTriggeringUpdate ||
                                controller.updateStatus.state == 'running'
                            ? null
                            : (value) {
                                if (value != null) {
                                  unawaited(
                                    controller.setReleaseChannel(value),
                                  );
                                }
                              },
                      );

                      final channelHelper = Text(
                        controller.updateStatus.releaseChannel == 'beta'
                            ? 'Beta follows the preview release stream.'
                            : 'Stable follows the production release stream.',
                        style: TextStyle(color: _textSecondary),
                      );

                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            channelPicker,
                            const SizedBox(height: 8),
                            channelHelper,
                            const SizedBox(height: 16),
                          ],
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(child: channelPicker),
                            const SizedBox(width: 12),
                            Expanded(child: channelHelper),
                          ],
                        ),
                      );
                    },
                  ),
                  Row(
                    children: <Widget>[
                      Expanded(child: _SectionTitle('Runtime Updates')),
                      FilledButton.icon(
                        onPressed:
                            controller.isSavingReleaseChannel ||
                                controller.isTriggeringUpdate ||
                                controller.updateStatus.state == 'running'
                            ? null
                            : controller.triggerUpdate,
                        style: FilledButton.styleFrom(backgroundColor: _accent),
                        icon: controller.isTriggeringUpdate
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(Icons.system_update),
                        label: Text('Update'),
                      ),
                    ],
                  ),
                ] else ...<Widget>[
                  const _SectionTitle('Runtime Updates'),
                  const SizedBox(height: 10),
                  Text(
                    'Updates and release tracks are managed for this deployment.',
                    style: TextStyle(color: _textSecondary),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    _StatusPill(
                      label: controller.updateStatus.badgeLabel,
                      color: controller.updateStatus.badgeColor,
                    ),
                    const SizedBox(width: 10),
                    _StatusPill(
                      label: controller.updateStatus.releaseChannelLabel,
                      color: controller.updateStatus.releaseChannel == 'beta'
                          ? _warning
                          : _accent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        controller.updateStatus.message,
                        style: TextStyle(color: _textSecondary),
                      ),
                    ),
                    Text('${controller.updateStatus.progress}%'),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: controller.updateStatus.progress / 100,
                    backgroundColor: _bgSecondary,
                    color: _accent,
                  ),
                ),
                const SizedBox(height: 12),
                Text(controller.updateStatus.versionLine),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _buildProviderPayload() {
    final providerIds = <String>{
      ...widget.controller.aiProviders.map((provider) => provider.id),
      ...widget.controller.aiProviderConfigs.keys,
    };

    return <String, dynamic>{
      for (final providerId in providerIds)
        providerId: <String, dynamic>{
          'enabled':
              _providerEnabled[providerId] ??
              widget.controller.aiProviderConfigs[providerId]?.enabled ??
              true,
          'baseUrl': _providerBaseUrlControllers[providerId]?.text.trim() ?? '',
        },
    };
  }

  void _syncTextController(
    Map<String, TextEditingController> controllers,
    String id,
    String value,
  ) {
    final controller = controllers.putIfAbsent(
      id,
      () => TextEditingController(text: value),
    );
    if (controller.text != value) {
      controller.text = value;
    }
  }

  void _pruneControllers(
    Map<String, TextEditingController> controllers,
    Set<String> activeIds,
  ) {
    final staleIds = controllers.keys
        .where((id) => !activeIds.contains(id))
        .toList();
    for (final id in staleIds) {
      controllers.remove(id)?.dispose();
    }
  }
}

class _AiProviderCard extends StatelessWidget {
  const _AiProviderCard({
    required this.provider,
    required this.enabled,
    required this.expanded,
    required this.models,
    required this.baseUrlController,
    required this.onEnabledChanged,
    required this.onExpandToggle,
  });

  final AiProviderMeta provider;
  final bool enabled;
  final bool expanded;
  final List<ModelMeta> models;
  final TextEditingController baseUrlController;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onExpandToggle;

  @override
  Widget build(BuildContext context) {
    final availableCount = models.where((model) => model.available).length;
    final hasAdvancedFields = provider.supportsBaseUrl || models.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _accentMuted,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(provider.icon, color: _accentHover),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      provider.label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  _StatusPill(
                    label: enabled ? provider.statusLabel : 'Disabled',
                    color: enabled ? provider.statusColor : _textSecondary,
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: hasAdvancedFields || models.isNotEmpty
                        ? onExpandToggle
                        : null,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _bgCard,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            expanded ? 'Hide' : 'Setup',
                            style: TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 16,
                            color: _textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _MetaPill(
                label: '$availableCount of ${models.length} models ready',
                icon: Icons.memory_outlined,
              ),
              if (provider.supportsApiKey && provider.credentialConfigured)
                const _MetaPill(
                  label: 'Credentials ready',
                  icon: Icons.lock_outline,
                ),
              if (provider.supportsApiKey && !provider.credentialConfigured)
                const _MetaPill(
                  label: 'Credentials needed',
                  icon: Icons.admin_panel_settings_outlined,
                ),
              if (provider.supportsBaseUrl &&
                  baseUrlController.text.trim().isNotEmpty)
                _MetaPill(
                  label: _friendlyBaseUrlLabel(baseUrlController.text.trim()),
                  icon: Icons.link_outlined,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    provider.availabilityReason,
                    style: TextStyle(color: _textSecondary, height: 1.35),
                  ),
                ),
                const SizedBox(width: 12),
                Switch(value: enabled, onChanged: onEnabledChanged),
              ],
            ),
          ),
          if (expanded) ...<Widget>[
            const SizedBox(height: 14),
            if (provider.supportsApiKey)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: _bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Text(
                  provider.credentialConfigured
                      ? 'Credentials for this provider are already available to the runtime.'
                      : 'Credentials for this provider are managed outside this workspace UI. Finish the server or admin setup, then return here to enable routing.',
                  style: TextStyle(color: _textSecondary, height: 1.35),
                ),
              ),
            if (provider.supportsBaseUrl) ...<Widget>[
              TextField(
                controller: baseUrlController,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: provider.id == 'ollama'
                      ? 'Server URL'
                      : 'Base URL',
                  helperText: provider.defaultBaseUrl.trim().isEmpty
                      ? 'Optional override.'
                      : 'Default: ${provider.defaultBaseUrl}',
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (models.isNotEmpty) ...<Widget>[
              Text('Models', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: models
                    .map(
                      (model) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: model.available ? _bgCard : _bgPrimary,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: model.available ? _border : _borderLight,
                          ),
                        ),
                        child: Text(
                          model.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: model.available
                                ? _textPrimary
                                : _textSecondary,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _RoutingSelectCard extends StatelessWidget {
  const _RoutingSelectCard({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 16, color: _accentHover),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: value,
            items: items,
            decoration: const InputDecoration(isDense: true),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class LogsPanel extends StatefulWidget {
  const LogsPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<LogsPanel> createState() => _LogsPanelState();
}

class _LogsPanelState extends State<LogsPanel> {
  static const JsonEncoder _debugJsonEncoder = JsonEncoder.withIndent('  ');

  String _recentLogsText() =>
      widget.controller.logs.map((log) => log.clipboardLine).join('\n');

  String _prettyJson(Object? value) => _debugJsonEncoder.convert(value);

  String _buildDebugInfo() {
    final controller = widget.controller;
    final now = DateTime.now().toIso8601String();
    final versionInfo = controller.versionInfo;
    final backendStatus = controller.backendHealthStatus;
    final lastRun = _jsonMap(backendStatus?['lastRun']);
    final lastNonEmptyRun = _jsonMap(backendStatus?['lastNonEmptyRun']);

    final snapshot = <String, dynamic>{
      'generatedAt': now,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'session': <String, dynamic>{
        'backendUrl': controller.backendUrl,
        'authenticated': controller.isAuthenticated,
        'socketConnected': controller.socketConnected,
        'selectedSection': controller.selectedSection.label,
        'account': controller.accountLabel,
      },
      'version': <String, dynamic>{
        'name': versionInfo?['name'],
        'version': versionInfo?['version'],
        'packageVersion': versionInfo?['packageVersion'],
        'gitVersion': versionInfo?['gitVersion'],
        'gitBranch': versionInfo?['gitBranch'],
        'gitSha': versionInfo?['gitSha'],
        'deploymentMode':
            versionInfo?['deploymentMode'] ??
            controller.updateStatus.deploymentMode,
        'deploymentProfile':
            versionInfo?['deploymentProfile'] ??
            controller.updateStatus.deploymentProfile,
        'allowSelfUpdate':
            versionInfo?['allowSelfUpdate'] ??
            controller.updateStatus.allowSelfUpdate,
        'releaseChannel':
            versionInfo?['releaseChannel'] ??
            controller.updateStatus.releaseChannel,
        'targetBranch':
            versionInfo?['targetBranch'] ??
            controller.updateStatus.targetBranch,
        'npmDistTag':
            versionInfo?['npmDistTag'] ?? controller.updateStatus.npmDistTag,
      },
      'ai': <String, dynamic>{
        'defaultChatModel': controller.defaultChatModel,
        'defaultSubagentModel': controller.defaultSubagentModel,
        'fallbackModel': controller.fallbackModel,
        'smarterSelector': controller.smarterSelector,
        'enabledModelCount': controller.enabledModelIds.length,
        'availableModelCount': controller.supportedModels
            .where((model) => model.available)
            .length,
        'providerStatus': controller.aiProviders
            .map(
              (provider) => <String, dynamic>{
                'id': provider.id,
                'enabled': provider.enabled,
                'available': provider.available,
                'status': provider.status,
                'statusLabel': provider.statusLabel,
                'modelCount': provider.modelCount,
                'availableModelCount': provider.availableModelCount,
                'baseUrl': provider.supportsBaseUrl ? provider.baseUrl : null,
                'credentialConfigured': provider.credentialConfigured,
              },
            )
            .toList(),
      },
      'runtime': <String, dynamic>{
        'headlessBrowser': controller.headlessBrowser,
        'browserBackend': controller.browserBackend,
        'browserExtensionConnected': controller.browserExtensionConnected,
        'hasLiveRun': controller.hasLiveRun,
        'activeRun': controller.activeRun == null
            ? null
            : <String, dynamic>{
                'runId': controller.activeRun!.runId,
                'title': controller.activeRun!.title,
                'model': controller.activeRun!.model,
                'phase': controller.activeRun!.phase,
                'iteration': controller.activeRun!.iteration,
                'pendingSteeringCount':
                    controller.activeRun!.pendingSteeringCount,
                'triggerSource': controller.activeRun!.triggerSource,
              },
      },
      'updateStatus': <String, dynamic>{
        'state': controller.updateStatus.state,
        'progress': controller.updateStatus.progress,
        'message': controller.updateStatus.message,
        'deploymentProfile': controller.updateStatus.deploymentProfile,
        'versionBefore': controller.updateStatus.versionBefore,
        'versionAfter': controller.updateStatus.versionAfter,
        'installedVersion': controller.updateStatus.installedVersion,
        'backendVersion': controller.updateStatus.backendVersion,
        'runtimeValidationReady':
            controller.updateStatus.runtimeValidationReady,
        'runtimeValidationIssues':
            controller.updateStatus.runtimeValidationIssues,
        'releaseChannel': controller.updateStatus.releaseChannel,
        'targetBranch': controller.updateStatus.targetBranch,
        'npmDistTag': controller.updateStatus.npmDistTag,
        'changelog': controller.updateStatus.changelog,
        'updateLogs': controller.updateStatus.logs,
      },
      'health': <String, dynamic>{
        'status': backendStatus?['status'],
        'timestamp': backendStatus?['timestamp'],
        'metricsCount':
            (backendStatus?['metrics'] as List<dynamic>?)?.length ?? 0,
        'lastRun': lastRun.isEmpty
            ? null
            : <String, dynamic>{
                'startedAt': lastRun['started_at'],
                'completedAt': lastRun['completed_at'],
                'recordCount': lastRun['record_count'],
                'syncWindowEnd': lastRun['sync_window_end'],
                'summary': _jsonMap(lastRun['summary']),
              },
        'lastNonEmptyRun': lastNonEmptyRun.isEmpty
            ? null
            : <String, dynamic>{
                'startedAt': lastNonEmptyRun['started_at'],
                'completedAt': lastNonEmptyRun['completed_at'],
                'recordCount': lastNonEmptyRun['record_count'],
                'syncWindowEnd': lastNonEmptyRun['sync_window_end'],
                'summary': _jsonMap(lastNonEmptyRun['summary']),
              },
      },
      'recentLogs': controller.logs
          .map(
            (log) => <String, dynamic>{
              'time': log.timeLabel,
              'type': log.type,
              'message': log.message,
            },
          )
          .toList(),
    };

    return ['NeoAgent debug info', _prettyJson(snapshot)].join('\n\n');
  }

  Future<void> _copyLogs() async {
    final logsText = _recentLogsText();
    if (logsText.trim().isEmpty) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: logsText));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied logs')));
  }

  Future<void> _copyDebugInfo() async {
    await Clipboard.setData(ClipboardData(text: _buildDebugInfo()));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied debug info')));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Logs',
          subtitle: 'Live backend console output from this server session.',
          trailing: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _copyDebugInfo,
                icon: Icon(Icons.bug_report_outlined),
                label: Text('Copy debug info'),
              ),
              OutlinedButton.icon(
                onPressed: widget.controller.logs.isEmpty ? null : _copyLogs,
                icon: Icon(Icons.copy_all_outlined),
                label: Text('Copy logs'),
              ),
              OutlinedButton.icon(
                onPressed: widget.controller.clearLogs,
                icon: Icon(Icons.clear_all),
                label: Text('Clear'),
              ),
            ],
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: widget.controller.logs.isEmpty
                ? Text(
                    'Waiting for log output…',
                    style: TextStyle(color: _textSecondary),
                  )
                : Column(
                    children: widget.controller.logs.map((log) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: _border)),
                        ),
                        child: Text.rich(
                          TextSpan(
                            children: <InlineSpan>[
                              TextSpan(
                                text: '[${log.timeLabel}] ',
                                style: TextStyle(color: _textMuted),
                              ),
                              TextSpan(
                                text: log.message,
                                style: TextStyle(color: log.color),
                              ),
                            ],
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ),
      ],
    );
  }
}

class SkillsPanel extends StatefulWidget {
  const SkillsPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<SkillsPanel> createState() => _SkillsPanelState();
}

class _SkillsPanelState extends State<SkillsPanel>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _searchController;
  late final TabController _tabController;
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final query = _searchController.text.trim().toLowerCase();
    final categories = <String>{
      'all',
      ...controller.storeSkills.map((item) => item.category),
    }.toList();
    final filteredStore =
        controller.storeSkills.where((item) {
          final matchesQuery =
              query.isEmpty ||
              item.name.toLowerCase().contains(query) ||
              item.description.toLowerCase().contains(query) ||
              item.category.toLowerCase().contains(query);
          final matchesCategory =
              _selectedCategory == 'all' || item.category == _selectedCategory;
          return matchesQuery && matchesCategory;
        }).toList()..sort((a, b) {
          if (a.installed != b.installed) {
            return a.installed ? -1 : 1;
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });

    return Padding(
      padding: _pagePadding(context),
      child: Column(
        children: <Widget>[
          _PageTitle(
            title: 'Skills',
            subtitle:
                'Manage installed skills and browse the store. Official integrations live in their own section.',
            trailing: FilledButton.icon(
              onPressed: () => _openCreateSkill(context),
              icon: Icon(Icons.add),
              label: Text('New Skill'),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: _bgSecondary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: TextStyle(fontWeight: FontWeight.w700),
              tabs: <Widget>[
                Tab(text: 'Installed Skills (${controller.skills.length})'),
                Tab(text: 'Store (${filteredStore.length})'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                _buildInstalledTab(controller),
                _buildStoreTab(controller, categories, filteredStore),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstalledTab(NeoAgentController controller) {
    if (controller.skills.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.extension_off_outlined,
                size: 34,
                color: _textSecondary,
              ),
              SizedBox(height: 12),
              Text(
                'No current skills yet. Install from Store or create a new one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: controller.skills.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final skill = controller.skills[index];
          return LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _bgSecondary,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  skill.name,
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Switch(
                                value: skill.enabled,
                                onChanged: (value) => controller
                                    .setSkillEnabled(skill.name, value),
                              ),
                            ],
                          ),
                          Text(
                            skill.description.ifEmpty('No description'),
                            style: TextStyle(color: _textSecondary),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              _MetaPill(
                                label: skill.category,
                                icon: Icons.folder_outlined,
                              ),
                              _MetaPill(
                                label: skill.source,
                                icon: Icons.source_outlined,
                              ),
                              if (skill.draft)
                                const _MetaPill(
                                  label: 'Draft',
                                  icon: Icons.edit_note_outlined,
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              const Spacer(),
                              OutlinedButton(
                                onPressed: () =>
                                    _openSkillEditor(context, skill.name),
                                child: Text('Open'),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () =>
                                    _confirmDeleteSkill(context, skill.name),
                                icon: Icon(Icons.delete_outline),
                                style: TextButton.styleFrom(
                                  foregroundColor: _danger,
                                ),
                                label: Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  skill.name,
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  skill.description.ifEmpty('No description'),
                                  style: TextStyle(color: _textSecondary),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: <Widget>[
                                    _MetaPill(
                                      label: skill.category,
                                      icon: Icons.folder_outlined,
                                    ),
                                    _MetaPill(
                                      label: skill.source,
                                      icon: Icons.source_outlined,
                                    ),
                                    if (skill.draft)
                                      const _MetaPill(
                                        label: 'Draft',
                                        icon: Icons.edit_note_outlined,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            children: <Widget>[
                              Switch(
                                value: skill.enabled,
                                onChanged: (value) => controller
                                    .setSkillEnabled(skill.name, value),
                              ),
                              OutlinedButton(
                                onPressed: () =>
                                    _openSkillEditor(context, skill.name),
                                child: Text('Open'),
                              ),
                              const SizedBox(height: 6),
                              TextButton.icon(
                                onPressed: () =>
                                    _confirmDeleteSkill(context, skill.name),
                                icon: Icon(Icons.delete_outline),
                                style: TextButton.styleFrom(
                                  foregroundColor: _danger,
                                ),
                                label: Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStoreTab(
    NeoAgentController controller,
    List<String> categories,
    List<StoreSkillItem> filteredStore,
  ) {
    final featured = filteredStore.take(6).toList();
    return Card(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[_bgSecondary, _accentMuted],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Skill Store',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 6),
                Text(
                  'Discover, install, and manage skills in a compact catalog.',
                  style: TextStyle(color: _textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Search skills',
              prefixIcon: Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = categories[index];
                final selected = category == _selectedCategory;
                return FilterChip(
                  selected: selected,
                  label: Text(category == 'all' ? 'All' : category),
                  selectedColor: _accentMuted,
                  checkmarkColor: _accent,
                  backgroundColor: _bgSecondary,
                  side: BorderSide(color: _border),
                  onSelected: (_) =>
                      setState(() => _selectedCategory = category),
                );
              },
            ),
          ),
          if (featured.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            const _SectionTitle('Featured'),
            const SizedBox(height: 10),
            SizedBox(
              height: 170,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: featured.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final item = featured[index];
                  return Container(
                    width: 280,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _bgSecondary,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: item.installed ? _accentMuted : _border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(item.icon, style: TextStyle(fontSize: 24)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            item.installed
                                ? _StatusPill(
                                    label: 'Installed',
                                    color: _success,
                                  )
                                : _StatusPill(label: 'Get', color: _info),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _textSecondary, height: 1.35),
                        ),
                        const Spacer(),
                        Align(
                          alignment: Alignment.centerRight,
                          child: item.installed
                              ? OutlinedButton(
                                  onPressed: () =>
                                      controller.uninstallStoreSkill(item.id),
                                  child: Text('Uninstall'),
                                )
                              : FilledButton(
                                  onPressed: () =>
                                      controller.installStoreSkill(item.id),
                                  child: Text('Install'),
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              const _SectionTitle('All Skills'),
              const Spacer(),
              Text(
                '${filteredStore.length} results',
                style: TextStyle(color: _textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (filteredStore.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No store skills match the current filter.',
                style: TextStyle(color: _textSecondary),
              ),
            )
          else
            ...filteredStore.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 740;
                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Text(item.icon, style: TextStyle(fontSize: 22)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                _StatusPill(
                                  label: item.installed ? 'Installed' : 'Get',
                                  color: item.installed ? _success : _info,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.description,
                              style: TextStyle(color: _textSecondary),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: <Widget>[
                                _MetaPill(
                                  label: item.category,
                                  icon: Icons.grid_view_rounded,
                                ),
                                const Spacer(),
                                item.installed
                                    ? OutlinedButton(
                                        onPressed: () => controller
                                            .uninstallStoreSkill(item.id),
                                        child: Text('Uninstall'),
                                      )
                                    : FilledButton(
                                        onPressed: () => controller
                                            .installStoreSkill(item.id),
                                        child: Text('Install'),
                                      ),
                              ],
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: <Widget>[
                          Text(item.icon, style: TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  item.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _textSecondary,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _MetaPill(
                                  label: item.category,
                                  icon: Icons.grid_view_rounded,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          item.installed
                              ? OutlinedButton(
                                  onPressed: () =>
                                      controller.uninstallStoreSkill(item.id),
                                  child: Text('Uninstall'),
                                )
                              : FilledButton(
                                  onPressed: () =>
                                      controller.installStoreSkill(item.id),
                                  child: Text('Install'),
                                ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openSkillEditor(BuildContext context, String name) async {
    final document = await widget.controller.fetchSkillDocument(name);
    final contentController = TextEditingController(text: document.content);
    if (!context.mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _bgCard,
          title: Text(name),
          content: SizedBox(
            width: 720,
            child: TextField(
              controller: contentController,
              minLines: 16,
              maxLines: 24,
              decoration: const InputDecoration(labelText: 'Skill Content'),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await widget.controller.saveSkillContent(
                  name: name,
                  content: contentController.text,
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openCreateSkill(BuildContext context) async {
    final nameController = TextEditingController();
    final contentController = TextEditingController(
      text: '''---
name: New Skill
description: Describe what this skill does
---
Write the instructions for this skill here.
''',
    );

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _bgCard,
          title: Text('New Skill'),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Filename'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentController,
                    minLines: 16,
                    maxLines: 24,
                    decoration: const InputDecoration(labelText: 'Content'),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await widget.controller.createSkill(
                  filename: nameController.text.trim(),
                  content: contentController.text,
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteSkill(BuildContext context, String name) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _bgCard,
          title: Text('Delete skill?'),
          content: Text('"$name" will be removed permanently.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _danger),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await widget.controller.deleteSkill(name);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Deleted "$name".')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete "$name": $error')),
      );
    }
  }
}

class MemoryPanel extends StatefulWidget {
  const MemoryPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<MemoryPanel> createState() => _MemoryPanelState();
}

class _MemoryPanelState extends State<MemoryPanel> {
  late final TextEditingController _searchController;
  final Set<String> _selectedMemoryIds = <String>{};
  bool _bulkActionInFlight = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MemoryItem> get _visibleMemories {
    final controller = widget.controller;
    return controller.memoryRecallResults.isNotEmpty
        ? controller.memoryRecallResults
        : controller.memories;
  }

  List<String> get _selectedVisibleMemoryIds {
    final visibleIds = _visibleMemories.map((memory) => memory.id).toSet();
    return _selectedMemoryIds
        .where(visibleIds.contains)
        .toList(growable: false);
  }

  void _toggleMemorySelection(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedMemoryIds.add(id);
      } else {
        _selectedMemoryIds.remove(id);
      }
    });
  }

  void _clearMemorySelection() {
    if (_selectedMemoryIds.isEmpty) {
      return;
    }
    setState(() {
      _selectedMemoryIds.clear();
    });
  }

  void _selectAllVisibleMemories(List<MemoryItem> memories) {
    if (memories.isEmpty) {
      return;
    }
    setState(() {
      _selectedMemoryIds.addAll(memories.map((memory) => memory.id));
    });
  }

  Future<void> _runMemorySearch(NeoAgentController controller) async {
    _clearMemorySelection();
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      controller.clearMemorySearch();
    } else {
      await controller.searchMemories(query);
    }
  }

  void _resetMemorySearch(NeoAgentController controller) {
    _searchController.clear();
    _clearMemorySelection();
    controller.clearMemorySearch();
  }

  Future<void> _deleteSingleMemory(
    NeoAgentController controller,
    String id,
  ) async {
    await controller.deleteMemory(id);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedMemoryIds.remove(id);
    });
  }

  Future<void> _runBulkMemoryAction({
    required String title,
    required String message,
    required String confirmLabel,
    required Future<void> Function(List<String> ids) onConfirm,
  }) async {
    final ids = _selectedVisibleMemoryIds;
    if (ids.isEmpty || _bulkActionInFlight) {
      return;
    }
    await _confirmDelete(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      onConfirm: () async {
        setState(() {
          _bulkActionInFlight = true;
        });
        try {
          await onConfirm(ids);
          if (!mounted) {
            return;
          }
          setState(() {
            _selectedMemoryIds.removeAll(ids);
          });
        } finally {
          if (mounted) {
            setState(() {
              _bulkActionInFlight = false;
            });
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final memoriesToShow = _visibleMemories;
    final selectedMemoryIds = _selectedVisibleMemoryIds.toSet();
    final selectedCount = selectedMemoryIds.length;
    final allVisibleSelected =
        memoriesToShow.isNotEmpty &&
        memoriesToShow.every((memory) => selectedMemoryIds.contains(memory.id));
    final showingSearchResults = controller.memoryRecallResults.isNotEmpty;

    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Memory',
          subtitle:
              'Core memory, thread context, long-term recall, daily logs, and behavior notes.',
          trailing: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () => _openBehaviorNotesEditor(context, controller),
                icon: Icon(Icons.edit_outlined),
                label: Text('Behavior Notes'),
              ),
              FilledButton.icon(
                onPressed: () => _openMemoryCreator(context, controller),
                icon: Icon(Icons.add),
                label: Text('Add Memory'),
              ),
            ],
          ),
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: _OverviewCard(
                title: 'Behavior Notes',
                value: '${controller.memoryOverview.behaviorNotesLength} chars',
                helper: 'Durable assistant style guidance',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OverviewCard(
                title: 'Core Memory',
                value: '${controller.memoryOverview.coreCount}',
                helper: 'Pinned key/value entries',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OverviewCard(
                title: 'Daily Logs',
                value: '${controller.memoryOverview.dailyLogCount}',
                helper: 'Recent captured log files',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OverviewCard(
                title: 'API Keys',
                value: '${controller.memoryOverview.apiKeyCount}',
                helper: 'Masked agent-managed credentials',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Recall Search'),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: 'Search memory',
                        ),
                        onSubmitted: (_) => _runMemorySearch(controller),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: () => _runMemorySearch(controller),
                      child: Text('Search'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () => _resetMemorySearch(controller),
                      child: Text('Reset'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(child: _SectionTitle('Core Memory')),
                    TextButton.icon(
                      onPressed: () =>
                          _openCoreMemoryEditor(context, controller),
                      icon: Icon(Icons.add),
                      label: Text('Add Entry'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (controller.memoryOverview.coreEntries.isEmpty)
                  Text(
                    'No core memory entries yet.',
                    style: TextStyle(color: _textSecondary),
                  )
                else
                  ...controller.memoryOverview.coreEntries.entries.map((entry) {
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _bgSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  entry.key,
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(entry.value.toString()),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _openCoreMemoryEditor(
                              context,
                              controller,
                              keyValue: entry,
                            ),
                            icon: Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: () => _confirmDelete(
                              context,
                              title: 'Delete core memory entry?',
                              message:
                                  'Remove "${entry.key}" from core memory.',
                              onConfirm: () =>
                                  controller.deleteCoreMemory(entry.key),
                            ),
                            icon: Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Memories'),
                const SizedBox(height: 6),
                Text(
                  showingSearchResults
                      ? 'Showing search results. Select memories to archive or delete them together.'
                      : 'Select one or more memories to archive or delete them together.',
                  style: TextStyle(color: _textSecondary),
                ),
                const SizedBox(height: 10),
                if (memoriesToShow.isNotEmpty)
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: allVisibleSelected || _bulkActionInFlight
                            ? null
                            : () => _selectAllVisibleMemories(memoriesToShow),
                        icon: Icon(Icons.done_all_outlined),
                        label: Text(
                          allVisibleSelected ? 'All Selected' : 'Select All',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: selectedCount == 0 || _bulkActionInFlight
                            ? null
                            : _clearMemorySelection,
                        icon: Icon(Icons.deselect_outlined),
                        label: Text('Clear Selection'),
                      ),
                      if (selectedCount > 0)
                        FilledButton.icon(
                          onPressed: _bulkActionInFlight
                              ? null
                              : () => _runBulkMemoryAction(
                                  title: 'Archive selected memories?',
                                  message:
                                      'Archive $selectedCount selected ${selectedCount == 1 ? 'memory' : 'memories'}? Archived memories are removed from the main list.',
                                  confirmLabel: 'Archive',
                                  onConfirm: controller.archiveMemories,
                                ),
                          icon: Icon(Icons.archive_outlined),
                          label: Text('Archive ($selectedCount)'),
                        ),
                      if (selectedCount > 0)
                        OutlinedButton.icon(
                          onPressed: _bulkActionInFlight
                              ? null
                              : () => _runBulkMemoryAction(
                                  title: 'Delete selected memories?',
                                  message:
                                      'Delete $selectedCount selected ${selectedCount == 1 ? 'memory' : 'memories'} permanently?',
                                  confirmLabel: 'Delete',
                                  onConfirm: controller.deleteMemories,
                                ),
                          icon: Icon(Icons.delete_sweep_outlined),
                          label: Text('Delete ($selectedCount)'),
                        ),
                    ],
                  ),
                if (selectedCount > 0) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    '$selectedCount selected',
                    style: TextStyle(
                      color: _textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (memoriesToShow.isNotEmpty) const SizedBox(height: 10),
                if (memoriesToShow.isEmpty)
                  Text(
                    'No memory entries found.',
                    style: TextStyle(color: _textSecondary),
                  )
                else
                  ...memoriesToShow.map((memory) {
                    final isSelected = selectedMemoryIds.contains(memory.id);
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? _accentMuted : _bgSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? _accent : _border,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () =>
                              _toggleMemorySelection(memory.id, !isSelected),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (value) => _toggleMemorySelection(
                                    memory.id,
                                    value ?? false,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Expanded(
                                            child: Wrap(
                                              spacing: 10,
                                              runSpacing: 10,
                                              children: <Widget>[
                                                _MetaPill(
                                                  label: memory.category,
                                                  icon: Icons.label_outline,
                                                ),
                                                _MetaPill(
                                                  label:
                                                      'Importance ${memory.importance}',
                                                  icon: Icons
                                                      .priority_high_outlined,
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: _bulkActionInFlight
                                                ? null
                                                : () => _confirmDelete(
                                                    context,
                                                    title: 'Delete memory?',
                                                    message:
                                                        'This memory entry will be removed permanently.',
                                                    onConfirm: () =>
                                                        _deleteSingleMemory(
                                                          controller,
                                                          memory.id,
                                                        ),
                                                  ),
                                            icon: Icon(Icons.delete_outline),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(memory.content),
                                      const SizedBox(height: 8),
                                      Text(
                                        memory.createdAtLabel,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Recent Conversations'),
                const SizedBox(height: 10),
                if (controller.memoryConversations.isEmpty)
                  Text(
                    'No recent conversations found.',
                    style: TextStyle(color: _textSecondary),
                  )
                else
                  ...controller.memoryConversations.map(
                    (conversation) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _bgSecondary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              conversation.title,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              conversation.preview,
                              style: TextStyle(color: _textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openMemoryCreator(
    BuildContext context,
    NeoAgentController controller,
  ) async {
    final contentController = TextEditingController();
    final importanceController = TextEditingController(text: '5');
    String category = 'episodic';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _bgCard,
          title: Text('Add Memory'),
          content: SizedBox(
            width: 620,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DropdownButtonFormField<String>(
                  initialValue: category,
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(
                      value: 'episodic',
                      child: Text('episodic'),
                    ),
                    DropdownMenuItem(
                      value: 'user_fact',
                      child: Text('user_fact'),
                    ),
                    DropdownMenuItem(
                      value: 'preference',
                      child: Text('preference'),
                    ),
                    DropdownMenuItem(
                      value: 'personality',
                      child: Text('personality'),
                    ),
                  ],
                  decoration: const InputDecoration(labelText: 'Category'),
                  onChanged: (value) {
                    if (value != null) {
                      category = value;
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: importanceController,
                  decoration: const InputDecoration(labelText: 'Importance'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  minLines: 6,
                  maxLines: 10,
                  decoration: const InputDecoration(labelText: 'Content'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await controller.createMemory(
                  content: contentController.text.trim(),
                  category: category,
                  importance:
                      int.tryParse(importanceController.text.trim()) ?? 5,
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openBehaviorNotesEditor(
    BuildContext context,
    NeoAgentController controller,
  ) async {
    final contentController = TextEditingController(
      text: controller.memoryOverview.assistantBehaviorNotes,
    );
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _bgCard,
          title: Text('Edit Assistant Behavior Notes'),
          content: SizedBox(
            width: 720,
            child: TextField(
              controller: contentController,
              minLines: 16,
              maxLines: 24,
              decoration: const InputDecoration(
                labelText: 'assistant_behavior_notes',
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await controller.updateAssistantBehaviorNotes(
                  contentController.text,
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openCoreMemoryEditor(
    BuildContext context,
    NeoAgentController controller, {
    MapEntry<String, dynamic>? keyValue,
  }) async {
    final keyController = TextEditingController(text: keyValue?.key ?? '');
    final valueController = TextEditingController(
      text: keyValue?.value?.toString() ?? '',
    );
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _bgCard,
          title: Text(
            keyValue == null
                ? 'Add Core Memory Entry'
                : 'Edit Core Memory Entry',
          ),
          content: SizedBox(
            width: 620,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: keyController,
                  decoration: const InputDecoration(labelText: 'Key'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valueController,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(labelText: 'Value'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await controller.updateCoreMemory(
                  keyController.text.trim(),
                  valueController.text.trim(),
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

class SchedulerPanel extends StatefulWidget {
  const SchedulerPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<SchedulerPanel> createState() => _SchedulerPanelState();
}

class _SchedulerPanelState extends State<SchedulerPanel> {
  String? _agentFilterId;

  NeoAgentController get controller => widget.controller;

  @override
  void didUpdateWidget(covariant SchedulerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_agentFilterId == null) return;
    final stillExists = controller.agentProfiles.any(
      (agent) => agent.id == _agentFilterId,
    );
    if (!stillExists) {
      _agentFilterId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredTasks = _agentFilterId == null
        ? controller.schedulerTasks
        : controller.schedulerTasks
              .where((task) => task.agentId == _agentFilterId)
              .toList();
    final selectedAgentLabel = controller.agentLabelFor(_agentFilterId);
    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Scheduler',
          subtitle: 'Recurring tasks and one-click manual runs.',
          trailing: FilledButton.icon(
            onPressed: () => _openTaskEditor(
              context,
              defaultAgentId: _agentFilterId ?? controller.selectedAgentId,
            ),
            icon: Icon(Icons.add),
            label: Text('Add Task'),
          ),
        ),
        if (controller.agentProfiles.isNotEmpty) ...<Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Assigned agent',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      ChoiceChip(
                        label: Text(
                          'All agents (${controller.schedulerTasks.length})',
                        ),
                        selected: _agentFilterId == null,
                        onSelected: (_) =>
                            setState(() => _agentFilterId = null),
                      ),
                      ...controller.agentProfiles.map((agent) {
                        final count = controller.schedulerTasks
                            .where((task) => task.agentId == agent.id)
                            .length;
                        return ChoiceChip(
                          label: Text('${agent.displayName} ($count)'),
                          selected: _agentFilterId == agent.id,
                          onSelected: (_) =>
                              setState(() => _agentFilterId = agent.id),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (controller.schedulerTasks.isEmpty)
          const _EmptyCard(
            title: 'No scheduled tasks',
            subtitle: 'Create a cron-based task to automate regular work.',
          )
        else if (filteredTasks.isEmpty)
          _EmptyCard(
            title: 'No tasks for $selectedAgentLabel',
            subtitle: 'Create a task while this agent is selected.',
          )
        else
          ...filteredTasks.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              task.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _StatusPill(
                            label: task.enabled ? 'Active' : 'Paused',
                            color: task.enabled ? _success : _textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        task.scheduleLabel,
                        style: TextStyle(
                          color: _textSecondary,
                          fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                        ),
                      ),
                      if (task.hasModelOverride) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          'Model: ${_modelLabelForValue(task.model, controller.supportedModels)}',
                          style: TextStyle(color: _textSecondary),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Assigned agent: ${controller.agentLabelFor(task.agentId)}',
                        style: TextStyle(color: _textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Text(task.prompt, style: TextStyle(color: _textPrimary)),
                      if (task.lastRunLabel.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          'Last run: ${task.lastRunLabel}',
                          style: TextStyle(color: _textSecondary),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          OutlinedButton(
                            onPressed: () =>
                                _openTaskEditor(context, task: task),
                            child: Text('Edit'),
                          ),
                          OutlinedButton(
                            onPressed: () =>
                                controller.toggleSchedulerTask(task),
                            child: Text(task.enabled ? 'Pause' : 'Enable'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                controller.runSchedulerTask(task.id),
                            child: Text('Run Now'),
                          ),
                          OutlinedButton(
                            onPressed: () => _confirmDelete(
                              context,
                              title: 'Delete task?',
                              message: 'This will remove "${task.name}".',
                              onConfirm: () =>
                                  controller.deleteSchedulerTask(task.id),
                            ),
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openTaskEditor(
    BuildContext context, {
    SchedulerTask? task,
    String? defaultAgentId,
  }) async {
    final nameController = TextEditingController(text: task?.name ?? '');
    final cronController = TextEditingController(
      text: task?.cronExpression ?? '*/30 * * * *',
    );
    final promptController = TextEditingController(text: task?.prompt ?? '');
    var enabled = task?.enabled ?? true;
    var selectedModel = _ensureModelValue(
      task?.model ?? 'auto',
      controller.supportedModels,
      allowAuto: true,
    );
    var selectedAgentId =
        task?.agentId ?? defaultAgentId ?? controller.selectedAgentId;
    if (selectedAgentId != null &&
        !controller.agentProfiles.any((agent) => agent.id == selectedAgentId)) {
      selectedAgentId = controller.selectedAgentId;
    }
    if (selectedAgentId != null &&
        !controller.agentProfiles.any((agent) => agent.id == selectedAgentId)) {
      selectedAgentId = controller.agentProfiles.isEmpty
          ? null
          : controller.agentProfiles.first.id;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              backgroundColor: _bgCard,
              title: Text(task == null ? 'Add Task' : 'Edit Task'),
              content: SizedBox(
                width: 680,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: cronController,
                        decoration: const InputDecoration(
                          labelText: 'Cron Expression',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: promptController,
                        minLines: 5,
                        maxLines: 10,
                        decoration: const InputDecoration(labelText: 'Prompt'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedModel,
                        decoration: const InputDecoration(
                          labelText: 'Model Override',
                        ),
                        items: <DropdownMenuItem<String>>[
                          const DropdownMenuItem<String>(
                            value: 'auto',
                            child: Text('Auto (default routing)'),
                          ),
                          ...controller.supportedModels.map(
                            (model) => DropdownMenuItem<String>(
                              value: model.id,
                              child: Text(model.label),
                            ),
                          ),
                        ],
                        onChanged: (value) => setLocalState(
                          () => selectedModel = value ?? 'auto',
                        ),
                      ),
                      if (controller.agentProfiles.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedAgentId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Assigned Agent',
                          ),
                          items: controller.agentProfiles
                              .map(
                                (agent) => DropdownMenuItem<String>(
                                  value: agent.id,
                                  child: Text(agent.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setLocalState(() => selectedAgentId = value),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: enabled,
                        contentPadding: EdgeInsets.zero,
                        title: Text('Enabled'),
                        onChanged: (value) =>
                            setLocalState(() => enabled = value),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    await controller.saveSchedulerTask(
                      id: task?.id,
                      name: nameController.text.trim(),
                      cronExpression: cronController.text.trim(),
                      prompt: promptController.text.trim(),
                      model: selectedModel == 'auto' ? null : selectedModel,
                      enabled: enabled,
                      agentId: selectedAgentId,
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class AgentsPanel extends StatelessWidget {
  const AgentsPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Agents',
          subtitle:
              'Create specialist bots with separate memory, settings, tools, and account assignments.',
          trailing: FilledButton.icon(
            onPressed: () => openAgentEditor(context, controller),
            icon: Icon(Icons.add),
            label: Text('Add Agent'),
          ),
        ),
        if (controller.errorMessage != null) ...<Widget>[
          _InlineError(message: controller.errorMessage!),
          const SizedBox(height: 16),
        ],
        if (controller.agentProfiles.isEmpty)
          const _EmptyCard(
            title: 'No agents yet',
            subtitle: 'The main agent is created automatically when needed.',
          )
        else
          ...controller.agentProfiles.map(
            (agent) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              agent.displayName,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (agent.isDefault)
                            _StatusPill(label: 'Default', color: _accentHover),
                          const SizedBox(width: 8),
                          _StatusPill(
                            label: agent.status,
                            color: agent.status == 'active'
                                ? _success
                                : _textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '@${agent.slug}',
                        style: TextStyle(color: _textSecondary),
                      ),
                      if (agent.description.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(agent.description),
                      ],
                      if (agent.responsibilities.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(
                          agent.responsibilities,
                          style: TextStyle(color: _textSecondary),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        _communicationSummary(controller, agent),
                        style: TextStyle(color: _textSecondary),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          OutlinedButton(
                            onPressed: () => controller.switchAgent(agent.id),
                            child: Text(
                              controller.selectedAgentId == agent.id
                                  ? 'Selected'
                                  : 'Switch',
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () => openAgentEditor(
                              context,
                              controller,
                              agent: agent,
                            ),
                            child: Text('Edit'),
                          ),
                          if (!agent.isDefault)
                            OutlinedButton(
                              onPressed: () =>
                                  controller.makeAgentDefault(agent.id),
                              child: Text('Make default'),
                            ),
                          if (!agent.isMain && !agent.isDefault)
                            TextButton(
                              onPressed: () => _confirmDelete(
                                context,
                                title: 'Archive agent?',
                                message:
                                    'This hides "${agent.displayName}" from routing and selection.',
                                onConfirm: () =>
                                    controller.archiveAgent(agent.id),
                              ),
                              child: Text('Archive'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  static Future<void> openAgentEditor(
    BuildContext context,
    NeoAgentController controller, {
    AgentProfile? agent,
  }) async {
    final nameController = TextEditingController(
      text: agent?.displayName ?? '',
    );
    final slugController = TextEditingController(text: agent?.slug ?? '');
    final descriptionController = TextEditingController(
      text: agent?.description ?? '',
    );
    final responsibilitiesController = TextEditingController(
      text: agent?.responsibilities ?? '',
    );
    final instructionsController = TextEditingController(
      text: agent?.instructions ?? '',
    );
    var status = agent?.status ?? 'active';
    var canDelegate = agent?.canDelegate ?? false;
    var canBeDelegatedTo = agent?.canBeDelegatedTo ?? true;
    var restrictDelegateTargets =
        agent != null && agent.delegateTargets.isNotEmpty;
    final delegateTargets = <String>{...?agent?.delegateTargets};

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              backgroundColor: _bgCard,
              title: Text(agent == null ? 'Add Agent' : 'Edit Agent'),
              content: SizedBox(
                width: 720,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        onChanged: (value) {
                          if (agent == null && slugController.text.isEmpty) {
                            slugController.text = value
                                .trim()
                                .toLowerCase()
                                .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
                                .replaceAll(RegExp(r'^-+|-+$'), '');
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: slugController,
                        decoration: const InputDecoration(labelText: 'Slug'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: responsibilitiesController,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Responsibilities',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: instructionsController,
                        minLines: 4,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'Instructions',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value: 'active',
                            child: Text('Active'),
                          ),
                          DropdownMenuItem(
                            value: 'paused',
                            child: Text('Paused'),
                          ),
                        ],
                        onChanged: (value) =>
                            setLocalState(() => status = value ?? 'active'),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Agent communication',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: canDelegate,
                        title: Text('Can delegate tasks to other agents'),
                        subtitle: Text(
                          'Use this for orchestrator agents. Leave off for isolated work bots that should finish direct messages themselves.',
                        ),
                        onChanged: (value) =>
                            setLocalState(() => canDelegate = value),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: canBeDelegatedTo,
                        title: Text('Can receive delegated tasks'),
                        subtitle: Text(
                          'Turn this off to keep this agent fully separate from other agents.',
                        ),
                        onChanged: (value) =>
                            setLocalState(() => canBeDelegatedTo = value),
                      ),
                      if (canDelegate) ...<Widget>[
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: restrictDelegateTargets,
                          title: Text('Restrict delegation targets'),
                          subtitle: Text(
                            restrictDelegateTargets
                                ? 'Only selected agents can receive tasks from this agent.'
                                : 'This agent can delegate to any eligible receiving agent.',
                          ),
                          onChanged: (value) => setLocalState(() {
                            restrictDelegateTargets = value;
                            if (!value) delegateTargets.clear();
                          }),
                        ),
                        if (restrictDelegateTargets) ...<Widget>[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: controller.agentProfiles
                                  .where((target) => target.id != agent?.id)
                                  .map((target) {
                                    final selected = delegateTargets.contains(
                                      target.id,
                                    );
                                    return FilterChip(
                                      label: Text(target.displayName),
                                      selected: selected,
                                      onSelected: (value) => setLocalState(() {
                                        if (value) {
                                          delegateTargets.add(target.id);
                                        } else {
                                          delegateTargets.remove(target.id);
                                        }
                                      }),
                                    );
                                  })
                                  .toList(),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final saved = await controller.saveAgentProfile(
                      id: agent?.id,
                      displayName: nameController.text.trim(),
                      slug: slugController.text.trim(),
                      description: descriptionController.text.trim(),
                      responsibilities: responsibilitiesController.text.trim(),
                      instructions: instructionsController.text.trim(),
                      status: status,
                      canDelegate: canDelegate,
                      canBeDelegatedTo: canBeDelegatedTo,
                      delegateTargets: restrictDelegateTargets
                          ? delegateTargets.toList(growable: false)
                          : const <String>[],
                    );
                    if (saved && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static String _communicationSummary(
    NeoAgentController controller,
    AgentProfile agent,
  ) {
    final parts = <String>[];
    parts.add(
      agent.canDelegate
          ? (agent.delegatesToAnyEligibleAgent
                ? 'Can delegate to any receiving agent'
                : 'Can delegate to ${agent.delegateTargets.map(controller.agentLabelFor).join(', ')}')
          : 'Handles direct tasks itself',
    );
    parts.add(
      agent.canBeDelegatedTo
          ? 'can receive delegated tasks'
          : 'cannot receive delegated tasks',
    );
    return 'Agent communication: ${parts.join('; ')}.';
  }
}

class McpPanel extends StatelessWidget {
  const McpPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'MCP',
          subtitle: 'Configured MCP servers and live server status.',
          trailing: FilledButton.icon(
            onPressed: () => _openMcpEditor(context),
            icon: Icon(Icons.add),
            label: Text('Add Server'),
          ),
        ),
        if (controller.mcpServers.isEmpty)
          const _EmptyCard(
            title: 'No MCP servers configured',
            subtitle: 'Add an MCP server URL and choose an auth method.',
          )
        else
          ...controller.mcpServers.map(
            (server) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              server.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _StatusPill(
                            label: server.status,
                            color: server.status == 'running'
                                ? _success
                                : _textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        server.command,
                        style: TextStyle(
                          fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                          color: _textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          _MetaPill(
                            label: server.enabled ? 'Enabled' : 'Disabled',
                            icon: Icons.toggle_on_outlined,
                          ),
                          _MetaPill(
                            label: '${server.toolCount} tools',
                            icon: Icons.build_outlined,
                          ),
                          _MetaPill(
                            label: server.authMethodLabel,
                            icon: Icons.lock_outline,
                          ),
                          _MetaPill(
                            label:
                                'Agent: ${controller.agentLabelFor(server.agentId)}',
                            icon: Icons.smart_toy_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          OutlinedButton(
                            onPressed: () =>
                                _openMcpEditor(context, server: server),
                            child: Text('Edit'),
                          ),
                          if (server.status == 'running')
                            FilledButton(
                              onPressed: () =>
                                  controller.stopMcpServer(server.id),
                              child: Text('Stop'),
                            )
                          else
                            FilledButton(
                              onPressed: () =>
                                  controller.startMcpServer(server.id),
                              child: Text('Start'),
                            ),
                          OutlinedButton(
                            onPressed: () => _confirmDelete(
                              context,
                              title: 'Delete MCP server?',
                              message:
                                  'This will remove "${server.name}" from the server list.',
                              onConfirm: () =>
                                  controller.deleteMcpServer(server.id),
                            ),
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openMcpEditor(
    BuildContext context, {
    McpServerItem? server,
  }) async {
    final nameController = TextEditingController(text: server?.name ?? '');
    final urlController = TextEditingController(text: server?.command ?? '');
    final auth = _jsonMap(server?.config['auth']);
    String authType = auth['type']?.toString().ifEmpty('none') ?? 'none';
    final tokenController = TextEditingController(
      text: auth['token']?.toString() ?? '',
    );
    final clientIdController = TextEditingController(
      text: auth['clientId']?.toString() ?? '',
    );
    final authServerUrlController = TextEditingController(
      text: auth['authServerUrl']?.toString() ?? '',
    );
    var enabled = server?.enabled ?? true;
    var selectedAgentId = server?.agentId ?? controller.selectedAgentId;
    if (selectedAgentId != null &&
        !controller.agentProfiles.any((agent) => agent.id == selectedAgentId)) {
      selectedAgentId = controller.selectedAgentId;
    }
    if (selectedAgentId != null &&
        !controller.agentProfiles.any((agent) => agent.id == selectedAgentId)) {
      selectedAgentId = controller.agentProfiles.isEmpty
          ? null
          : controller.agentProfiles.first.id;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              backgroundColor: _bgCard,
              title: Text(
                server == null ? 'Add MCP Server' : 'Edit MCP Server',
              ),
              content: SizedBox(
                width: 720,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: urlController,
                        decoration: const InputDecoration(
                          labelText: 'MCP Server URL',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: authType,
                        decoration: const InputDecoration(
                          labelText: 'Auth Method',
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(value: 'none', child: Text('None')),
                          DropdownMenuItem(
                            value: 'bearer',
                            child: Text('Bearer Token'),
                          ),
                          DropdownMenuItem(
                            value: 'oauth',
                            child: Text('OAuth'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setLocalState(() => authType = value);
                          }
                        },
                      ),
                      if (authType == 'bearer') ...<Widget>[
                        const SizedBox(height: 12),
                        TextField(
                          controller: tokenController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Bearer Token',
                          ),
                        ),
                      ],
                      if (authType == 'oauth') ...<Widget>[
                        const SizedBox(height: 12),
                        TextField(
                          controller: clientIdController,
                          decoration: const InputDecoration(
                            labelText: 'OAuth Client ID',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: authServerUrlController,
                          decoration: const InputDecoration(
                            labelText: 'Auth Server URL',
                          ),
                        ),
                      ],
                      if (controller.agentProfiles.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedAgentId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Assigned Agent',
                          ),
                          items: controller.agentProfiles
                              .map(
                                (agent) => DropdownMenuItem<String>(
                                  value: agent.id,
                                  child: Text(agent.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setLocalState(() => selectedAgentId = value),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Matches the old NeoAgent MCP flow: URL plus auth method.',
                          style: TextStyle(color: _textSecondary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: enabled,
                        contentPadding: EdgeInsets.zero,
                        title: Text('Enabled'),
                        onChanged: (value) =>
                            setLocalState(() => enabled = value),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Start the server later from the list once the config is saved.',
                          style: TextStyle(color: _textSecondary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final config = <String, dynamic>{
                      'auth': <String, dynamic>{
                        'type': authType,
                        if (authType == 'bearer' &&
                            tokenController.text.trim().isNotEmpty)
                          'token': tokenController.text.trim(),
                        if (authType == 'oauth' &&
                            clientIdController.text.trim().isNotEmpty)
                          'clientId': clientIdController.text.trim(),
                        if (authType == 'oauth' &&
                            authServerUrlController.text.trim().isNotEmpty)
                          'authServerUrl': authServerUrlController.text.trim(),
                      },
                    };
                    await controller.saveMcpServer(
                      id: server?.id,
                      name: nameController.text.trim(),
                      command: urlController.text.trim(),
                      config: config,
                      enabled: enabled,
                      agentId: selectedAgentId,
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class HealthPanel extends StatelessWidget {
  const HealthPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    final deviceStatus = controller.deviceHealthStatus;
    final backendStatus = controller.backendHealthStatus;
    final metrics = backendStatus?['metrics'] as List<dynamic>? ?? const [];
    final lastRun = backendStatus?['lastRun'] as Map<String, dynamic>?;
    final lastNonEmptyRun =
        backendStatus?['lastNonEmptyRun'] as Map<String, dynamic>?;
    final lastSummary = _jsonMap(lastRun?['summary']);
    final lastNonEmptySummary = _jsonMap(lastNonEmptyRun?['summary']);
    final lastRunRecordCount = _asInt(lastRun?['record_count']);
    final lastSyncEmpty = lastRun != null && lastRunRecordCount == 0;
    final lastWindowEnd = _parseOptionalTimestamp(
      lastRun?['sync_window_end']?.toString(),
    );
    final lastNonEmptyWindowEnd = _parseOptionalTimestamp(
      lastNonEmptyRun?['sync_window_end']?.toString(),
    );

    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        const _PageTitle(
          title: 'Health',
          subtitle: 'Health Connect sync status and stored backend metrics.',
        ),
        if (controller.errorMessage != null) ...<Widget>[
          _InlineError(message: controller.errorMessage!),
          const SizedBox(height: 16),
        ],
        Row(
          children: <Widget>[
            Expanded(
              child: _OverviewCard(
                title: 'Device access',
                value: deviceStatus == null
                    ? 'Checking...'
                    : !deviceStatus.available
                    ? 'Unavailable'
                    : deviceStatus.permissionsGranted
                    ? 'Ready'
                    : 'Permissions needed',
                helper:
                    deviceStatus?.message ??
                    'Reads steps, heart rate, sleep, exercise, and weight.',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OverviewCard(
                title: 'Backend sync',
                value: lastRun == null
                    ? 'No sync yet'
                    : lastSyncEmpty
                    ? 'No new data'
                    : '$lastRunRecordCount records',
                helper: lastRun == null
                    ? 'Sync once to seed your backend.'
                    : lastWindowEnd == null
                    ? 'Last window end is unknown.'
                    : 'Last window ended ${_formatTimestamp(lastWindowEnd)}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: controller.requestHealthPermissions,
                  icon: Icon(Icons.health_and_safety_outlined),
                  label: Text('Request permissions'),
                ),
                FilledButton.icon(
                  onPressed: controller.isSyncingHealth
                      ? null
                      : controller.syncHealthNow,
                  style: FilledButton.styleFrom(
                    backgroundColor: _accentHover,
                    foregroundColor: _bgPrimary,
                  ),
                  icon: controller.isSyncingHealth
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.sync),
                  label: Text('Sync now'),
                ),
                _MetaPill(
                  label: 'Background sync stays scheduled on Android',
                  icon: Icons.sync_lock_outlined,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Last Sync Summary'),
                const SizedBox(height: 12),
                if (lastSummary.isEmpty)
                  Text(
                    'No detailed sync summary yet.',
                    style: TextStyle(color: _textSecondary),
                  )
                else ...<Widget>[
                  if (lastSyncEmpty && metrics.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        lastWindowEnd == null
                            ? 'The latest sync completed successfully but did not find any new Health Connect records. Stored metrics below came from earlier syncs.'
                            : 'The latest sync window ended ${_formatTimestamp(lastWindowEnd)} and did not find any new Health Connect records. Stored metrics below came from earlier syncs.',
                        style: TextStyle(color: _textSecondary),
                      ),
                    ),
                  _buildHealthSummaryPills(lastSummary),
                ],
                if (lastSyncEmpty &&
                    lastNonEmptySummary.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 18),
                  Text(
                    lastNonEmptyWindowEnd == null
                        ? 'Last non-empty sync'
                        : 'Last non-empty sync · ${_formatTimestamp(lastNonEmptyWindowEnd)}',
                    style: TextStyle(
                      color: _textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildHealthSummaryPills(lastNonEmptySummary),
                ],
                const SizedBox(height: 18),
                const _SectionTitle('Stored Metrics'),
                const SizedBox(height: 12),
                if (metrics.isEmpty)
                  Text('No health samples stored yet.')
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: metrics.map((item) {
                      final map = item as Map<dynamic, dynamic>;
                      return _MetaPill(
                        icon: Icons.favorite_border,
                        label:
                            '${map['metricType']} · ${map['sampleCount']} samples',
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
