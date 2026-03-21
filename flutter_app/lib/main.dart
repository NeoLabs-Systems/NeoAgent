import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'src/backend_client.dart';
import 'src/health_bridge.dart';
import 'src/recording_bridge.dart';

const Color _bgPrimary = Color(0xFF07070F);
const Color _bgSecondary = Color(0xFF0C0C18);
const Color _bgTertiary = Color(0xFF111120);
const Color _bgCard = Color(0xFF181828);
const Color _textPrimary = Color(0xFFEAEAF4);
const Color _textSecondary = Color(0xFF8080A8);
const Color _textMuted = Color(0xFF4D4D6A);
const Color _accent = Color(0xFF6366F1);
const Color _accentHover = Color(0xFF818CF8);
const Color _accentMuted = Color(0x266366F1);
const Color _border = Color(0x12FFFFFF);
const Color _borderLight = Color(0x22FFFFFF);
const Color _success = Color(0xFF22C55E);
const Color _warning = Color(0xFFF59E0B);
const Color _danger = Color(0xFFEF4444);
const Color _info = Color(0xFF38BDF8);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NeoAgentApp());
}

enum AppSection {
  chat,
  devices,
  recordings,
  messaging,
  runs,
  settings,
  logs,
  skills,
  memory,
  scheduler,
  mcp,
  health,
}

enum SidebarGroup { chat, recordings, activity, automation, settings }

extension SidebarGroupX on SidebarGroup {
  String get label {
    switch (this) {
      case SidebarGroup.chat:
        return 'Chat';
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
      case AppSection.logs:
        return 'Logs';
      case AppSection.skills:
        return 'Skills';
      case AppSection.memory:
        return 'Memory';
      case AppSection.scheduler:
        return 'Scheduler';
      case AppSection.mcp:
        return 'MCP';
      case AppSection.health:
        return 'Health';
    }
  }

  IconData get icon {
    switch (this) {
      case AppSection.chat:
        return Icons.chat_bubble_outline;
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
      case AppSection.logs:
        return Icons.article_outlined;
      case AppSection.skills:
        return Icons.extension_outlined;
      case AppSection.memory:
        return Icons.psychology_outlined;
      case AppSection.scheduler:
        return Icons.schedule_outlined;
      case AppSection.mcp:
        return Icons.hub_outlined;
      case AppSection.health:
        return Icons.favorite_border;
    }
  }

  SidebarGroup get group {
    switch (this) {
      case AppSection.chat:
        return SidebarGroup.chat;
      case AppSection.recordings:
        return SidebarGroup.recordings;
      case AppSection.runs:
      case AppSection.logs:
        return SidebarGroup.activity;
      case AppSection.devices:
      case AppSection.skills:
      case AppSection.memory:
      case AppSection.scheduler:
      case AppSection.mcp:
      case AppSection.health:
        return SidebarGroup.automation;
      case AppSection.settings:
      case AppSection.messaging:
        return SidebarGroup.settings;
    }
  }

  String get navigationTitle {
    final groupLabel = group.label;
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
    _controller = NeoAgentController(
      backendClient: BackendClient(),
      healthBridge: HealthBridge(),
      recordingBridge: createRecordingBridge(),
    )..bootstrap();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _accent,
        brightness: Brightness.dark,
      ),
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'NeoAgent',
          debugShowCheckedModeBanner: false,
          theme: base.copyWith(
            scaffoldBackgroundColor: _bgPrimary,
            colorScheme: base.colorScheme.copyWith(
              primary: _accent,
              secondary: _accentHover,
              surface: _bgCard,
              onSurface: _textPrimary,
              error: _danger,
            ),
            textTheme: GoogleFonts.interTextTheme(
              base.textTheme,
            ).apply(bodyColor: _textPrimary, displayColor: _textPrimary),
            cardTheme: CardThemeData(
              color: _bgCard,
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: _border),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: _bgSecondary,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _accent),
              ),
              labelStyle: const TextStyle(
                color: _textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              hintStyle: const TextStyle(color: _textMuted),
            ),
            dividerColor: _border,
            iconTheme: const IconThemeData(color: _textSecondary),
            appBarTheme: AppBarTheme(
              backgroundColor: _bgPrimary,
              surfaceTintColor: Colors.transparent,
              foregroundColor: _textPrimary,
              elevation: 0,
              titleTextStyle: GoogleFonts.inter(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            snackBarTheme: const SnackBarThemeData(
              backgroundColor: _bgCard,
              contentTextStyle: TextStyle(color: _textPrimary),
            ),
          ),
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
  }) : _backendClient = backendClient,
       _healthBridge = healthBridge,
       _recordingBridge = recordingBridge {
    _recordingBridge.onRecordingStopped = _handleRecordingStopped;
    _recordingBridge.addListener(_handleRecordingBridgeChanged);
  }

  final BackendClient _backendClient;
  final HealthBridge _healthBridge;
  final RecordingBridge _recordingBridge;

  static const String _configuredBackendUrl = String.fromEnvironment(
    'NEOAGENT_BACKEND_URL',
  );

  SharedPreferences? _prefs;
  io.Socket? _socket;
  Timer? _updatePollTimer;
  final Set<String> _backgroundRunIds = <String>{};

  bool isBooting = true;
  bool isAuthenticated = false;
  bool isAuthenticating = false;
  bool isRefreshing = false;
  bool isRefreshingDevices = false;
  bool isSendingMessage = false;
  bool isSavingSettings = false;
  bool isTriggeringUpdate = false;
  bool isSyncingHealth = false;
  bool isRunningDeviceAction = false;
  bool socketConnected = false;

  bool hasUser = true;
  String backendUrl = _defaultBackendUrl;
  String username = '';
  String password = '';
  String? errorMessage;

  AppSection selectedSection = AppSection.chat;
  Map<String, dynamic>? user;
  Map<String, dynamic> settings = const <String, dynamic>{};
  Map<String, dynamic>? versionInfo;
  Map<String, dynamic>? backendHealthStatus;
  HealthBridgeStatus? deviceHealthStatus;
  List<RecordingSessionItem> recordingSessions = const <RecordingSessionItem>[];

  List<ChatEntry> chatMessages = const <ChatEntry>[];
  List<ModelMeta> supportedModels = const <ModelMeta>[];
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
  MemoryOverview memoryOverview = const MemoryOverview();
  List<MemoryItem> memories = const <MemoryItem>[];
  List<MemoryItem> memoryRecallResults = const <MemoryItem>[];
  List<ConversationItem> memoryConversations = const <ConversationItem>[];
  List<SchedulerTask> schedulerTasks = const <SchedulerTask>[];
  List<McpServerItem> mcpServers = const <McpServerItem>[];
  Map<String, dynamic> browserRuntime = const <String, dynamic>{};
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

    return 'http://10.0.2.2:3333';
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
    super.dispose();
  }

  RecordingRuntimeStatus get recordingRuntime => _recordingBridge.status;

  BlockedSenderNotice? get pendingBlockedSenderNotice =>
      _blockedSenderQueue.isEmpty ? null : _blockedSenderQueue.first;

  void _handleRecordingBridgeChanged() {
    notifyListeners();
  }

  Future<void> _handleRecordingStopped(String sessionId) async {
    try {
      await _backendClient.finalizeRecordingSession(
        backendUrl,
        sessionId,
        stopReason: 'ended',
      );
      await refreshRecordings();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> bootstrap() async {
    _prefs = await SharedPreferences.getInstance();
    backendUrl = _defaultBackendUrl;
    username = _prefs?.getString('username') ?? '';
    password = _prefs?.getString('password') ?? '';
    await _recordingBridge.refreshStatus();
    notifyListeners();

    try {
      final status = await _backendClient.getAuthStatus(backendUrl);
      hasUser = status['hasUser'] != false;

      final me = await _backendClient.getCurrentUser(backendUrl);
      if (me != null && me['user'] is Map<String, dynamic>) {
        user = Map<String, dynamic>.from(me['user'] as Map<String, dynamic>);
        isAuthenticated = true;
      } else if (!kIsWeb && username.isNotEmpty && password.isNotEmpty) {
        await _authenticate(register: false, silent: true);
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
    required String password,
  }) async {
    this.username = username.trim();
    this.password = password;
    await _authenticate(register: true);
  }

  Future<void> _authenticate({
    required bool register,
    bool silent = false,
  }) async {
    isAuthenticating = true;
    errorMessage = null;
    if (!silent) {
      notifyListeners();
    }

    try {
      final response = register
          ? await _backendClient.register(
              baseUrl: backendUrl,
              username: username,
              password: password,
            )
          : await _backendClient.login(
              baseUrl: backendUrl,
              username: username,
              password: password,
            );
      user = Map<String, dynamic>.from(
        response['user'] as Map<dynamic, dynamic>? ??
            <String, dynamic>{'username': username},
      );
      hasUser = true;
      isAuthenticated = true;
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
    try {
      await _backendClient.logout(backendUrl);
    } catch (_) {}
    _disconnectSocket();
    _updatePollTimer?.cancel();
    isAuthenticated = false;
    user = null;
    settings = const <String, dynamic>{};
    chatMessages = const <ChatEntry>[];
    supportedModels = const <ModelMeta>[];
    recentRuns = const <RunSummary>[];
    tokenUsage = null;
    updateStatus = const UpdateStatusSnapshot();
    logs = const <LogEntry>[];
    messagingStatuses = const <String, MessagingPlatformStatus>{};
    messagingMessages = const <MessagingMessage>[];
    pendingMessagingQr = null;
    skills = const <SkillItem>[];
    storeSkills = const <StoreSkillItem>[];
    memoryOverview = const MemoryOverview();
    memories = const <MemoryItem>[];
    memoryRecallResults = const <MemoryItem>[];
    memoryConversations = const <ConversationItem>[];
    schedulerTasks = const <SchedulerTask>[];
    mcpServers = const <McpServerItem>[];
    browserRuntime = const <String, dynamic>{};
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
    _runDetailsCache.clear();
    unawaited(
      _healthBridge.configureBackgroundSync(
        enabled: false,
        backendUrl: backendUrl,
        sessionCookie: '',
      ),
    );
    notifyListeners();
  }

  Future<void> _persistCredentials() async {
    await _prefs?.setString('username', username);
    await _prefs?.setString('password', password);
  }

  void setSelectedSection(AppSection section) {
    selectedSection = section;
    if (section == AppSection.devices) {
      unawaited(refreshDevices());
    }
    notifyListeners();
  }

  void showInlineError(String message) {
    errorMessage = message;
    notifyListeners();
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
        raw = const <dynamic>[];
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
          return;
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

  Future<void> refresh() async {
    if (!isAuthenticated) {
      return;
    }

    isRefreshing = true;
    errorMessage = null;
    notifyListeners();

    try {
      final me = await _backendClient.getCurrentUser(backendUrl);
      if (me == null || me['user'] is! Map<String, dynamic>) {
        isAuthenticated = false;
        _disconnectSocket();
        return;
      }

      user = Map<String, dynamic>.from(me['user'] as Map<String, dynamic>);

      final historyFuture = _backendClient.fetchChatHistory(backendUrl);
      final modelsFuture = _backendClient.fetchSupportedModels(backendUrl);
      final settingsFuture = _backendClient.fetchSettings(backendUrl);
      final runsFuture = _backendClient.fetchRuns(backendUrl);
      final versionFuture = _backendClient.fetchVersion(backendUrl);
      final tokenFuture = _backendClient.fetchTokenUsageSummary(backendUrl);
      final updateFuture = _backendClient.fetchUpdateStatus(backendUrl);
      final messagingFuture = _backendClient.fetchMessagingStatus(backendUrl);
      final messagingMessagesFuture = _backendClient.fetchMessagingMessages(
        backendUrl,
      );
      final skillsFuture = _backendClient.fetchSkills(backendUrl);
      final storeSkillsFuture = _backendClient.fetchSkillStore(backendUrl);
      final memoryFuture = _backendClient.fetchMemoryOverview(backendUrl);
      final memoriesFuture = _backendClient.fetchMemories(backendUrl);
      final conversationsFuture = _backendClient.fetchConversations(backendUrl);
      final schedulerFuture = _backendClient.fetchSchedulerTasks(backendUrl);
      final mcpFuture = _backendClient.fetchMcpServers(backendUrl);
      final recordingsFuture = _backendClient.fetchRecordingSessions(
        backendUrl,
      );
      final browserFuture = _backendClient.fetchBrowserStatus(backendUrl);
      final androidFuture = _backendClient.fetchAndroidStatus(backendUrl);

      Map<String, dynamic>? healthResponse;
      try {
        healthResponse = await _backendClient.fetchHealthStatus(backendUrl);
      } catch (_) {
        healthResponse = null;
      }

      final history = await historyFuture;
      final modelsResponse = await modelsFuture;
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
      final androidResponse = await androidFuture;

      chatMessages = (history['messages'] as List<dynamic>? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((item) => ChatEntry.fromJson(item))
          .toList();

      supportedModels =
          (modelsResponse['models'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<dynamic, dynamic>>()
              .map((item) => ModelMeta.fromJson(item))
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
      androidRuntime = Map<String, dynamic>.from(androidResponse);
      await _recordingBridge.refreshStatus();
      deviceHealthStatus = await _healthBridge.getStatus();
      await _syncBackgroundHealthConfig();
      _ensureSocketConnected();
      _ensureUpdatePolling();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> refreshRunsOnly() async {
    try {
      final runsResponse = await _backendClient.fetchRuns(backendUrl);
      recentRuns = (runsResponse['runs'] as List<dynamic>? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((item) => RunSummary.fromJson(item))
          .toList();
      _runDetailsCache.clear();
      tokenUsage = TokenUsageSnapshot.fromJson(
        await _backendClient.fetchTokenUsageSummary(backendUrl),
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshMessaging() async {
    final statuses = await _backendClient.fetchMessagingStatus(backendUrl);
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
    messagingMessages = (await _backendClient.fetchMessagingMessages(
      backendUrl,
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
    notifyListeners();
  }

  Future<void> refreshMemory() async {
    memoryOverview = MemoryOverview.fromJson(
      await _backendClient.fetchMemoryOverview(backendUrl),
    );
    memories = (await _backendClient.fetchMemories(
      backendUrl,
    )).map(MemoryItem.fromJson).toList();
    memoryConversations = (await _backendClient.fetchConversations(
      backendUrl,
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
    recordingSessions = (await _backendClient.fetchRecordingSessions(
      backendUrl,
    )).map(RecordingSessionItem.fromJson).toList();
    await _recordingBridge.refreshStatus();
    notifyListeners();
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
      final androidResponse = await _backendClient.fetchAndroidStatus(
        backendUrl,
      );
      browserRuntime = Map<String, dynamic>.from(browserResponse);
      androidRuntime = Map<String, dynamic>.from(androidResponse);
      errorMessage = null;
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isRefreshingDevices = false;
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
    bool refreshApps = false,
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
      await refreshDevices();
      if (refreshApps) {
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
      refreshApps: true,
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
      ),
      browser: false,
      refreshApps: true,
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
      ),
      browser: false,
    );
  }

  Future<void> tapAndroidRuntime(Map<String, dynamic> payload) async {
    await _runDeviceAction(
      () => _backendClient.tapAndroid(backendUrl, payload),
      browser: false,
    );
  }

  Future<void> typeAndroidRuntime(Map<String, dynamic> payload) async {
    await _runDeviceAction(
      () => _backendClient.typeAndroid(backendUrl, payload),
      browser: false,
    );
  }

  Future<void> swipeAndroidRuntime(Map<String, dynamic> payload) async {
    await _runDeviceAction(
      () => _backendClient.swipeAndroid(backendUrl, payload),
      browser: false,
    );
  }

  Future<void> pressAndroidKeyRuntime(String key) async {
    await _runDeviceAction(
      () => _backendClient.pressAndroidKey(backendUrl, key: key),
      browser: false,
    );
  }

  Future<void> waitForAndroidRuntime(Map<String, dynamic> payload) async {
    await _runDeviceAction(
      () => _backendClient.waitForAndroid(backendUrl, payload),
      browser: false,
    );
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

  Future<void> startWebRecording() async {
    if (isStartingRecording || recordingRuntime.active) {
      return;
    }
    isStartingRecording = true;
    errorMessage = null;
    notifyListeners();

    String? sessionId;
    try {
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
      notifyListeners();
    } catch (error) {
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
      notifyListeners();
    } catch (error) {
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
      await _recordingBridge.pauseBackgroundRecording();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> resumeBackgroundRecording() async {
    try {
      await _recordingBridge.resumeBackgroundRecording();
    } catch (error) {
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
    } catch (error) {
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

  Future<void> refreshUpdateStatus() async {
    try {
      updateStatus = UpdateStatusSnapshot.fromJson(
        await _backendClient.fetchUpdateStatus(backendUrl),
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<RunDetailSnapshot> fetchRunDetail(String runId) async {
    final cached = _runDetailsCache[runId];
    if (cached != null) {
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
    if (trimmed.isEmpty || isSendingMessage) {
      return;
    }

    final optimistic = ChatEntry(
      role: 'user',
      content: trimmed,
      platform: 'flutter',
      createdAt: DateTime.now(),
    );
    chatMessages = <ChatEntry>[...chatMessages, optimistic];
    isSendingMessage = true;
    errorMessage = null;
    toolEvents = const <ToolEventItem>[];
    streamingAssistant = '';
    activeRun = ActiveRunState.pending(trimmed);
    notifyListeners();

    try {
      if (_socket != null && socketConnected) {
        _socket!.emit('agent:run', <String, dynamic>{
          'task': trimmed,
          'options': const <String, dynamic>{},
        });
        return;
      }

      final response = await _backendClient.runTask(backendUrl, trimmed);
      final content = response['content']?.toString().trim();
      if (content != null && content.isNotEmpty) {
        chatMessages = <ChatEntry>[
          ...chatMessages,
          ChatEntry(
            role: 'assistant',
            content: content,
            platform: 'web',
            createdAt: DateTime.now(),
          ),
        ];
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
    required bool heartbeatEnabled,
    required bool headlessBrowser,
    required bool autoSkillLearning,
    required bool smarterSelector,
    required List<String> enabledModels,
    required String defaultChatModel,
    required String defaultSubagentModel,
    required String fallbackModel,
  }) async {
    isSavingSettings = true;
    errorMessage = null;
    notifyListeners();

    final payload = <String, dynamic>{
      'heartbeat_enabled': heartbeatEnabled,
      'headless_browser': headlessBrowser,
      'auto_skill_learning': autoSkillLearning,
      'smarter_model_selector': smarterSelector,
      'enabled_models': enabledModels,
      'default_chat_model': defaultChatModel,
      'default_subagent_model': defaultSubagentModel,
      'fallback_model_id': fallbackModel,
    };

    try {
      await _backendClient.saveSettings(backendUrl, payload);
      settings = <String, dynamic>{...settings, ...payload};
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isSavingSettings = false;
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

  Future<void> connectMessagingPlatform({
    required String platform,
    Map<String, dynamic>? config,
    Map<String, dynamic>? configSnapshot,
  }) async {
    if (configSnapshot != null) {
      await _backendClient.saveSettings(backendUrl, configSnapshot);
      settings = <String, dynamic>{...settings, ...configSnapshot};
    }
    await _backendClient.connectMessagingPlatform(
      backendUrl,
      platform: platform,
      config: config,
    );
    await refreshMessaging();
  }

  Future<void> disconnectMessagingPlatform(String platform) async {
    await _backendClient.disconnectMessagingPlatform(
      backendUrl,
      platform: platform,
    );
    await refreshMessaging();
  }

  Future<void> logoutMessagingPlatform(String platform) async {
    await _backendClient.logoutMessagingPlatform(
      backendUrl,
      platform: platform,
    );
    await refreshMessaging();
  }

  Future<void> saveWhatsAppWhitelist(List<String> values) async {
    final normalized = values
        .map((value) => value.replaceAll(RegExp(r'[^0-9]'), ''))
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    await _backendClient.saveSettings(backendUrl, <String, dynamic>{
      'platform_whitelist_whatsapp': jsonEncode(normalized),
    });
    settings = <String, dynamic>{
      ...settings,
      'platform_whitelist_whatsapp': jsonEncode(normalized),
    };
    notifyListeners();
  }

  Future<void> saveTelnyxWhitelist(List<String> values) async {
    await _backendClient.saveTelnyxWhitelist(backendUrl, values);
    settings = <String, dynamic>{
      ...settings,
      'platform_whitelist_telnyx': values,
    };
    notifyListeners();
  }

  Future<void> saveTelnyxVoiceSecret(String secret) async {
    await _backendClient.saveTelnyxVoiceSecret(backendUrl, secret);
    settings = <String, dynamic>{
      ...settings,
      'platform_voice_secret_telnyx': secret,
    };
    notifyListeners();
  }

  Future<void> saveDiscordWhitelist(List<String> values) async {
    await _backendClient.saveDiscordWhitelist(backendUrl, values);
    settings = <String, dynamic>{
      ...settings,
      'platform_whitelist_discord': values,
    };
    notifyListeners();
  }

  Future<void> saveTelegramWhitelist(List<String> values) async {
    await _backendClient.saveTelegramWhitelist(backendUrl, values);
    settings = <String, dynamic>{
      ...settings,
      'platform_whitelist_telegram': values,
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
    );
    memoryRecallResults = const <MemoryItem>[];
    await refreshMemory();
  }

  Future<void> deleteMemory(int id) async {
    await _backendClient.deleteMemory(backendUrl, id);
    await refreshMemory();
  }

  Future<void> searchMemories(String query) async {
    memoryRecallResults = (await _backendClient.recallMemories(
      backendUrl,
      query,
    )).map(MemoryItem.fromJson).toList();
    notifyListeners();
  }

  void clearMemorySearch() {
    memoryRecallResults = const <MemoryItem>[];
    notifyListeners();
  }

  Future<void> updateSoul(String content) async {
    await _backendClient.updateSoul(backendUrl, content);
    await refreshMemory();
  }

  Future<void> updateCoreMemory(String key, String value) async {
    await _backendClient.updateCoreMemory(backendUrl, key: key, value: value);
    await refreshMemory();
  }

  Future<void> deleteCoreMemory(String key) async {
    await _backendClient.deleteCoreMemory(backendUrl, key);
    await refreshMemory();
  }

  Future<void> saveSchedulerTask({
    int? id,
    required String name,
    required String cronExpression,
    required String prompt,
    String? model,
    bool enabled = true,
  }) async {
    await _backendClient.saveSchedulerTask(
      backendUrl,
      id: id,
      name: name,
      cronExpression: cronExpression,
      prompt: prompt,
      model: model,
      enabled: enabled,
    );
    await refreshScheduler();
  }

  Future<void> toggleSchedulerTask(SchedulerTask task) async {
    await _backendClient.updateSchedulerTask(
      backendUrl,
      task.id,
      <String, dynamic>{'enabled': !task.enabled},
    );
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
  }) async {
    await _backendClient.saveMcpServer(
      backendUrl,
      id: id,
      name: name,
      command: command,
      config: config,
      enabled: enabled,
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
    final text = error.toString().trim();
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
    if (lower.contains('cors') ||
        lower.contains('xmlhttprequest error') ||
        lower.contains('failed to fetch') ||
        lower.contains('network request failed') ||
        lower.contains('clientexception') ||
        lower.contains('socketexception')) {
      return 'The app could not reach the NeoAgent server. Check that the backend is running and that this build points at the correct server.';
    }
    if (lower.contains('origin not allowed')) {
      return 'This build is not allowed to talk to that NeoAgent server.';
    }
    if (lower.contains('not authenticated')) {
      return 'Your session expired. Please sign in again.';
    }
    if (lower.contains('health connect')) {
      return text;
    }

    return 'Something went wrong. Please try again.';
  }

  bool get heartbeatEnabled =>
      settings['heartbeat_enabled'] == true ||
      settings['heartbeat_enabled'] == 'true';

  bool get headlessBrowser =>
      settings['headless_browser'] != false &&
      settings['headless_browser'] != 'false';

  bool get autoSkillLearning =>
      settings['auto_skill_learning'] != false &&
      settings['auto_skill_learning'] != 'false';

  bool get smarterSelector => settings['smarter_model_selector'] != false;

  List<String> get enabledModelIds {
    final raw = settings['enabled_models'];
    if (raw is List) {
      return raw.map((item) => item.toString()).toList();
    }
    return supportedModels.map((model) => model.id).toList();
  }

  String get defaultChatModel =>
      settings['default_chat_model']?.toString() ?? 'auto';

  String get defaultSubagentModel =>
      settings['default_subagent_model']?.toString() ?? 'auto';

  String get fallbackModel =>
      settings['fallback_model_id']?.toString() ??
      (supportedModels.isNotEmpty ? supportedModels.first.id : 'auto');

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
    socket.on('messaging:sent', (dynamic data) {
      messagingMessages = <MessagingMessage>[
        MessagingMessage.fromSocket(_jsonMap(data), outgoing: true),
        ...messagingMessages,
      ];
      notifyListeners();
    });
    socket.on('messaging:message', (dynamic data) {
      messagingMessages = <MessagingMessage>[
        MessagingMessage.fromSocket(_jsonMap(data), outgoing: false),
        ...messagingMessages,
      ];
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
    socket.on('run:start', (dynamic data) {
      final payload = _jsonMap(data);
      final triggerSource = payload['triggerSource']?.toString() ?? '';
      final runId = payload['runId']?.toString() ?? '';
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
    socket.on('run:interim', (dynamic data) {
      final payload = _jsonMap(data);
      toolEvents = <ToolEventItem>[
        ...toolEvents,
        ToolEventItem(
          id: 'note-${DateTime.now().microsecondsSinceEpoch}',
          toolName: 'note',
          type: 'note',
          status: 'completed',
          summary: payload['message']?.toString() ?? '',
        ),
      ];
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
        return;
      }
      final content = payload['content']?.toString().trim() ?? '';
      if (content.isNotEmpty) {
        chatMessages = <ChatEntry>[
          ...chatMessages,
          ChatEntry(
            role: 'assistant',
            content: content,
            platform: 'web',
            createdAt: DateTime.now(),
          ),
        ];
      }
      streamingAssistant = '';
      isSendingMessage = false;
      if (activeRun?.runId == runId) {
        activeRun = activeRun!.copyWith(phase: 'Completed');
      }
      unawaited(refreshRunsOnly());
      notifyListeners();
    });
    socket.on('run:error', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString();
      if (runId != null) {
        _backgroundRunIds.remove(runId);
      }
      streamingAssistant = '';
      activeRun = null;
      isSendingMessage = false;
      errorMessage =
          'I could not complete that request right now. Please try again in a moment.';
      notifyListeners();
    });
    socket.on('skill:draft_created', (dynamic _) {
      unawaited(refreshSkills());
    });
    socket.on('recordings:updated', (dynamic _) {
      unawaited(refreshRecordings());
    });
    socket.connect();
    _socket = socket;
  }

  bool _isBackgroundRun(String triggerSource) {
    return triggerSource == 'scheduler' ||
        triggerSource == 'heartbeat' ||
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

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.4, -0.6),
          radius: 1.3,
          colors: <Color>[_accent, _bgSecondary, _bgPrimary],
        ),
      ),
      child: const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _LogoBadge(size: 52),
              SizedBox(height: 18),
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading NeoAgent'),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthView extends StatefulWidget {
  const AuthView({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  bool _registerMode = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.controller.username,
    );
    _passwordController = TextEditingController(
      text: widget.controller.password,
    );
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (!controller.hasUser) {
      _registerMode = true;
    }

    final title = _registerMode ? 'Create the first account' : 'Sign in';
    final subtitle = _registerMode
        ? 'This account will unlock the workspace.'
        : 'Enter your NeoAgent account details.';

    return Scaffold(
      backgroundColor: _bgPrimary,
      body: Stack(
        children: <Widget>[
          const Positioned(
            top: -100,
            left: -100,
            child: _BlurOrb(size: 500, color: _accent),
          ),
          const Positioned(
            right: -80,
            bottom: -80,
            child: _BlurOrb(size: 400, color: Color(0xFF8B5CF6)),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Card(
                    color: const Color.fromRGBO(12, 12, 24, 0.92),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: _borderLight),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(36),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const Column(
                            children: <Widget>[
                              _LogoBadge(size: 52),
                              SizedBox(height: 16),
                              Text(
                                'NeoAgent',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: const TextStyle(color: _textSecondary),
                          ),
                          const SizedBox(height: 20),
                          if (!controller.hasUser) ...<Widget>[
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: _bgPrimary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: _AuthTabButton(
                                      label: 'Sign In',
                                      active: !_registerMode,
                                      onTap: () =>
                                          setState(() => _registerMode = false),
                                    ),
                                  ),
                                  Expanded(
                                    child: _AuthTabButton(
                                      label: 'Setup',
                                      active: _registerMode,
                                      onTap: () =>
                                          setState(() => _registerMode = true),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (controller.errorMessage != null) ...<Widget>[
                            _InlineError(message: controller.errorMessage!),
                            const SizedBox(height: 16),
                          ],
                          TextField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                            ),
                          ),
                          if (_registerMode) ...<Widget>[
                            const SizedBox(height: 14),
                            TextField(
                              controller: _confirmPasswordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Confirm Password',
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: controller.isAuthenticating
                                ? null
                                : () async {
                                    if (_registerMode &&
                                        _passwordController.text !=
                                            _confirmPasswordController.text) {
                                      widget.controller.showInlineError(
                                        'Passwords do not match.',
                                      );
                                      return;
                                    }
                                    if (_registerMode) {
                                      await controller.register(
                                        username: _usernameController.text,
                                        password: _passwordController.text,
                                      );
                                    } else {
                                      await controller.login(
                                        username: _usernameController.text,
                                        password: _passwordController.text,
                                      );
                                    }
                                  },
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                              backgroundColor: _accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: controller.isAuthenticating
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _registerMode
                                        ? 'Create account'
                                        : 'Sign in',
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeView extends StatefulWidget {
  const HomeView({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  bool _blockedDialogOpen = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final pendingBlockedSender = controller.pendingBlockedSenderNotice;

    if (!_blockedDialogOpen && pendingBlockedSender != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _blockedDialogOpen) {
          return;
        }
        _showBlockedSenderDialog(pendingBlockedSender);
      });
    }

    final wide = MediaQuery.sizeOf(context).width >= 1080;

    if (wide) {
      return Scaffold(
        backgroundColor: _bgPrimary,
        body: SafeArea(
          child: Row(
            children: <Widget>[
              _Sidebar(controller: controller),
              Expanded(child: _SectionBody(controller: controller)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bgPrimary,
      drawer: _MobileDrawer(controller: controller),
      appBar: AppBar(
        title: Text(controller.selectedSection.navigationTitle),
        actions: <Widget>[
          IconButton(
            onPressed: controller.isRefreshing ? null : controller.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(child: _SectionBody(controller: controller)),
    );
  }

  Future<void> _showBlockedSenderDialog(BlockedSenderNotice notice) async {
    _blockedDialogOpen = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: _bgCard,
            title: Text('Allow sender on ${notice.platform.toUpperCase()}?'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      notice.senderLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (notice.meta.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        notice.meta,
                        style: const TextStyle(color: _textSecondary),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'This sender is currently blocked by the access list. You can allow them now or jump to Messaging to edit the full list.',
                      style: TextStyle(color: _textSecondary, height: 1.45),
                    ),
                    if (notice.suggestions.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 18),
                      ...notice.suggestions.map(
                        (suggestion) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () async {
                                Navigator.of(dialogContext).pop();
                                await widget.controller.allowMessagingEntry(
                                  notice.platform,
                                  suggestion.entry,
                                );
                              },
                              icon: const Icon(Icons.verified_user_outlined),
                              label: Text(suggestion.label),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  widget.controller.setSelectedSection(AppSection.messaging);
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Open Messaging'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Dismiss'),
              ),
            ],
          );
        },
      );
    } finally {
      widget.controller.consumeBlockedSenderNotice(notice.id);
      if (mounted) {
        setState(() => _blockedDialogOpen = false);
      } else {
        _blockedDialogOpen = false;
      }
    }
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 232,
      decoration: const BoxDecoration(
        color: _bgSecondary,
        border: Border(right: BorderSide(color: _border)),
      ),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(
              children: <Widget>[
                const _LogoBadge(size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'NeoAgent',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        controller.accountLabel,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: _buildSidebarItems(
                controller,
                onSelect: controller.setSelectedSection,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _border)),
            ),
            child: Column(
              children: <Widget>[
                _SidebarButton(
                  label: 'Refresh',
                  icon: Icons.refresh,
                  onTap: controller.isRefreshing ? null : controller.refresh,
                ),
                _SidebarButton(
                  label: 'Logout',
                  icon: Icons.logout,
                  onTap: controller.logout,
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: controller.socketConnected ? _success : _warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      controller.socketConnected ? 'Live' : 'Offline',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileDrawer extends StatelessWidget {
  const _MobileDrawer({required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: _bgSecondary,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: <Widget>[
                  const _LogoBadge(size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      controller.accountLabel,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: _buildSidebarItems(
                  controller,
                  onSelect: (section) {
                    controller.setSelectedSection(section);
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: <Widget>[
                  _SidebarButton(
                    label: 'Refresh',
                    icon: Icons.refresh,
                    onTap: () {
                      Navigator.of(context).pop();
                      controller.refresh();
                    },
                  ),
                  _SidebarButton(
                    label: 'Logout',
                    icon: Icons.logout,
                    onTap: () {
                      Navigator.of(context).pop();
                      controller.logout();
                    },
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

class _SectionBody extends StatelessWidget {
  const _SectionBody({required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    switch (controller.selectedSection) {
      case AppSection.chat:
        return ChatPanel(controller: controller);
      case AppSection.devices:
        return DevicesPanel(controller: controller);
      case AppSection.recordings:
        return RecordingsPanel(controller: controller);
      case AppSection.messaging:
        return MessagingPanel(controller: controller);
      case AppSection.runs:
        return RunsPanel(controller: controller);
      case AppSection.settings:
        return SettingsPanel(controller: controller);
      case AppSection.logs:
        return LogsPanel(controller: controller);
      case AppSection.skills:
        return SkillsPanel(controller: controller);
      case AppSection.memory:
        return MemoryPanel(controller: controller);
      case AppSection.scheduler:
        return SchedulerPanel(controller: controller);
      case AppSection.mcp:
        return McpPanel(controller: controller);
      case AppSection.health:
        return controller.showHealthSection
            ? HealthPanel(controller: controller)
            : ChatPanel(controller: controller);
    }
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
    _browserUrlController = TextEditingController(text: 'https://example.com');
    _androidLaunchController = TextEditingController(
      text: 'com.android.settings',
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
            icon: const Icon(Icons.sync),
            label: const Text('Sync Surface'),
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
              color: const Color(0xFF131520),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: const BorderSide(color: _borderLight),
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
                    ),
                    const SizedBox(height: 16),
                    _DeviceLaunchBar(
                      surface: _surface,
                      controller: _isBrowser
                          ? _browserUrlController
                          : _androidLaunchController,
                      active: _isBrowser
                          ? browserStatus['launched'] == true
                          : _androidOnline,
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
                      enabled: _isBrowser || _androidOnline,
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
  });

  final _DeviceSurface surface;
  final Map<String, dynamic> browserStatus;
  final Map<String, dynamic> browserPageInfo;
  final Map<String, dynamic> androidRuntime;
  final bool androidOnline;

  @override
  Widget build(BuildContext context) {
    final title = surface == _DeviceSurface.browser
        ? (browserPageInfo['title']?.toString().trim().isNotEmpty ?? false)
              ? browserPageInfo['title'].toString()
              : 'Live Browser'
        : 'Android Phone';
    final subtitle = surface == _DeviceSurface.browser
        ? (browserPageInfo['url']?.toString() ?? 'Ready for navigation')
        : (androidOnline
              ? 'Tap and swipe directly on the preview.'
              : (androidRuntime['lastLogLine']?.toString().trim().isNotEmpty ??
                    false)
              ? androidRuntime['lastLogLine'].toString()
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
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _DotStatus(
          label: surface == _DeviceSurface.browser
              ? (browserStatus['launched'] == true ? 'Live' : 'Sleeping')
              : (androidOnline ? 'Live' : 'Offline'),
          color:
              (surface == _DeviceSurface.browser
                  ? browserStatus['launched'] == true
                  : androidOnline)
              ? _success
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
    required this.busy,
    required this.onSubmit,
    required this.onSleep,
  });

  final _DeviceSurface surface;
  final TextEditingController controller;
  final bool active;
  final bool busy;
  final Future<void> Function() onSubmit;
  final Future<void> Function() onSleep;

  @override
  Widget build(BuildContext context) {
    final hint = surface == _DeviceSurface.browser
        ? 'https://example.com'
        : 'Package name or URL';
    final buttonLabel = surface == _DeviceSurface.browser ? 'Open' : 'Launch';
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
      onPressed: busy ? null : onSubmit,
      icon: Icon(
        surface == _DeviceSurface.browser
            ? Icons.arrow_forward
            : Icons.play_arrow,
      ),
      label: Text(buttonLabel),
    );
    final sleepButton = OutlinedButton.icon(
      onPressed: busy || !active ? null : onSleep,
      icon: const Icon(Icons.bedtime_outlined),
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
        prefixIcon: const Icon(Icons.keyboard_outlined),
      ),
    );

    final button = FilledButton.icon(
      onPressed: busy ? null : onSubmit,
      icon: const Icon(Icons.send_rounded),
      label: const Text('Send'),
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
              color: disabled ? _bgSecondary : const Color(0xFF1B1F2D),
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
        color: const Color(0xFF121624),
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        const SizedBox(width: 14),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              surface.label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(surface.helper, style: const TextStyle(color: _textSecondary)),
          ],
        ),
        const SizedBox(width: 14),
        IconButton.filledTonal(
          onPressed: onNext,
          icon: const Icon(Icons.arrow_forward_ios_rounded),
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
    required this.enabled,
    required this.onTapPoint,
    required this.onSwipe,
    required this.onWakeRequested,
  });

  final _DeviceSurface surface;
  final NeoAgentController controller;
  final String? screenshotPath;
  final bool busy;
  final bool enabled;
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF171B29), Color(0xFF0E111A)],
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
                                color: const Color(0xB20A0C12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _borderLight),
                              ),
                              child: Text(
                                widget.surface.helper,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: _textPrimary),
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
    this.errorMessage,
    required this.onPressed,
  });

  final _DeviceSurface surface;
  final bool enabled;
  final bool busy;
  final String? errorMessage;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final label = surface == _DeviceSurface.browser
        ? 'Wake Browser'
        : (enabled ? 'Refresh Phone' : 'Start Phone');
    final message = surface == _DeviceSurface.browser
        ? 'Browser is sleeping. Press Open to start it.'
        : (errorMessage != null && errorMessage!.trim().isNotEmpty)
        ? errorMessage!
        : 'Phone is offline. Press Start Phone to boot it.';
    return Container(
      color: _bgSecondary,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(surface.icon, size: 46, color: _textSecondary),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: _textSecondary),
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
                style: const TextStyle(color: _textMuted, fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: busy ? null : onPressed,
            icon: const Icon(Icons.play_arrow_rounded),
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
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _textSecondary,
                          height: 1.5,
                        ),
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
            style: const TextStyle(color: _textSecondary, height: 1.5),
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
              icon: const Icon(Icons.rocket_launch_outlined),
              label: const Text('Launch'),
            ),
            FilledButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : () => controller.navigateBrowserRuntime(
                      url: urlController.text.trim(),
                      waitFor: waitForController.text.trim(),
                    ),
              icon: const Icon(Icons.open_in_browser_outlined),
              label: const Text('Navigate'),
            ),
            OutlinedButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : controller.screenshotBrowserRuntime,
              icon: const Icon(Icons.photo_camera_back_outlined),
              label: const Text('Screenshot'),
            ),
            OutlinedButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : controller.closeBrowserRuntime,
              icon: const Icon(Icons.close),
              label: const Text('Close'),
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
              child: const Text('Click Selector'),
            ),
            OutlinedButton(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : () => controller.clickBrowserRuntime(
                      text: clickTextController.text.trim(),
                    ),
              child: const Text('Click Text'),
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
          icon: const Icon(Icons.keyboard_outlined),
          label: const Text('Type Into Field'),
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
              icon: const Icon(Icons.play_arrow_outlined),
              label: const Text('Start Emulator'),
            ),
            OutlinedButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : controller.stopAndroidRuntime,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Stop'),
            ),
            OutlinedButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : controller.screenshotAndroidRuntime,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Screenshot'),
            ),
            OutlinedButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : controller.dumpAndroidUiRuntime,
              icon: const Icon(Icons.data_object_outlined),
              label: const Text('Dump UI'),
            ),
            OutlinedButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : controller.refreshAndroidApps,
              icon: const Icon(Icons.apps_outlined),
              label: const Text('Load Apps'),
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
              icon: const Icon(Icons.apps),
              label: const Text('Open App'),
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
          icon: const Icon(Icons.route_outlined),
          label: const Text('Open Intent'),
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
              child: const Text('Wait For UI'),
            ),
            OutlinedButton(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : () => controller.pressAndroidKeyRuntime(
                      keyController.text.trim(),
                    ),
              child: const Text('Press Key'),
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
          icon: const Icon(Icons.touch_app_outlined),
          label: const Text('Tap'),
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
          icon: const Icon(Icons.keyboard_outlined),
          label: const Text('Type'),
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
          icon: const Icon(Icons.swipe_outlined),
          label: const Text('Swipe'),
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
            style: const TextStyle(fontWeight: FontWeight.w700),
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
                style: const TextStyle(color: _textSecondary, height: 1.5),
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
          style: const TextStyle(
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
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              screenshotPath!,
              style: const TextStyle(color: _textSecondary, fontSize: 12),
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
                    child: const Text(
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
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
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

class RecordingsPanel extends StatelessWidget {
  const RecordingsPanel({super.key, required this.controller});

  final NeoAgentController controller;

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
          controller.deleteRecordingSegment(session.id, segment.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final runtime = controller.recordingRuntime;

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
                      label: runtime.active
                          ? (runtime.paused ? 'Paused' : 'Recording')
                          : 'Idle',
                      color: runtime.active
                          ? (runtime.paused ? _warning : _danger)
                          : _success,
                    ),
                    if (runtime.platformLabel != null &&
                        runtime.platformLabel!.isNotEmpty)
                      Text(
                        runtime.platformLabel!,
                        style: const TextStyle(color: _textSecondary),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Web can capture screen share plus microphone at the same time. Android can keep a microphone recording running in the background through a foreground service.',
                  style: TextStyle(color: _textSecondary),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    if (runtime.supportsScreenAndMic)
                      FilledButton.icon(
                        onPressed:
                            controller.isStartingRecording || runtime.active
                            ? null
                            : controller.startWebRecording,
                        icon: const Icon(Icons.desktop_windows_outlined),
                        label: const Text('Start screen + mic'),
                      ),
                    if (runtime.supportsBackgroundMic)
                      FilledButton.icon(
                        onPressed:
                            controller.isStartingRecording || runtime.active
                            ? null
                            : controller.startBackgroundRecording,
                        icon: const Icon(Icons.mic_none_outlined),
                        label: const Text('Start background mic'),
                      ),
                    if (runtime.supportsBackgroundMic && runtime.active)
                      OutlinedButton.icon(
                        onPressed: runtime.paused
                            ? controller.resumeBackgroundRecording
                            : controller.pauseBackgroundRecording,
                        icon: Icon(
                          runtime.paused ? Icons.play_arrow : Icons.pause,
                        ),
                        label: Text(runtime.paused ? 'Resume' : 'Pause'),
                      ),
                    if (runtime.active)
                      OutlinedButton.icon(
                        onPressed: controller.isStoppingRecording
                            ? null
                            : controller.stopRecording,
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('Stop'),
                      ),
                    OutlinedButton.icon(
                      onPressed: controller.refreshRecordings,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
                if (runtime.errorMessage != null &&
                    runtime.errorMessage!.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  Text(
                    runtime.errorMessage!,
                    style: const TextStyle(color: _danger),
                  ),
                ],
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Capture pipeline',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Each session stores screen and microphone as separate sources, uploads chunked media with ordering, and persists transcript segments with timestamps for replay and retry.',
                        style: TextStyle(color: _textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const _SectionTitle('Transcription history'),
        const SizedBox(height: 12),
        if (controller.recordingSessions.isEmpty)
          const _EmptyCard(
            title: 'No recordings yet',
            subtitle:
                'Start a recording and your persisted transcripts will appear here with timestamps.',
          )
        else
          ...controller.recordingSessions.map(
            (session) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RecordingSessionCard(
                session: session,
                onRetry: session.status == 'failed'
                    ? () => controller.retryRecording(session.id)
                    : null,
                onDeleteSegment: (segment) =>
                    _deleteSegment(context, session, segment),
              ),
            ),
          ),
      ],
    );
  }
}

class _RecordingSessionCard extends StatelessWidget {
  const _RecordingSessionCard({
    required this.session,
    this.onRetry,
    this.onDeleteSegment,
  });

  final RecordingSessionItem session;
  final VoidCallback? onRetry;
  final Future<void> Function(RecordingTranscriptSegment segment)?
  onDeleteSegment;

  @override
  Widget build(BuildContext context) {
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${session.startedAtLabel} • ${session.platformLabel} • ${session.durationLabel}',
                        style: const TextStyle(color: _textSecondary),
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
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  )
                  .toList(),
            ),
            if (session.lastError != null &&
                session.lastError!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  session.lastError!,
                  style: const TextStyle(color: _danger),
                ),
              ),
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
                          style: const TextStyle(color: _textSecondary),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          segment.displayText,
                          style: const TextStyle(height: 1.45),
                        ),
                      ),
                      if (onDeleteSegment != null &&
                          segment.id > 0) ...<Widget>[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () async {
                            await onDeleteSegment!(segment);
                          },
                          icon: const Icon(Icons.delete_outline),
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
              Text(
                session.transcriptText,
                style: const TextStyle(height: 1.45),
              ),
            ] else ...<Widget>[
              const SizedBox(height: 16),
              Text(
                session.status == 'processing'
                    ? 'Transcription is being processed.'
                    : 'Transcript is not available yet.',
                style: const TextStyle(color: _textSecondary),
              ),
            ],
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.replay),
                label: const Text('Retry transcription'),
              ),
            ],
          ],
        ),
      ),
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
                    _DotStatus(
                      label: controller.socketConnected ? 'Live' : 'Offline',
                      color: controller.socketConnected ? _success : _warning,
                    ),
                    _MetaPill(
                      label: controller.modelIndicator,
                      icon: Icons.memory_outlined,
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
                const Padding(
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
          decoration: const BoxDecoration(
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
                        decoration: const InputDecoration(
                          hintText: 'say something...',
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: controller.isSendingMessage
                          ? null
                          : () async {
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
                      child: controller.isSendingMessage
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.north_east_rounded,
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
                    controller.activeRun == null
                        ? 'Idle'
                        : '${controller.activeRun!.phase} (${controller.toolEvents.where((event) => event.status == 'running').length} active tools)',
                    style: const TextStyle(fontSize: 11, color: _textSecondary),
                  ),
                  Text(
                    controller.modelIndicator,
                    style: const TextStyle(fontSize: 11, color: _textSecondary),
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

class _MessagingPanelState extends State<MessagingPanel> {
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final groups = <MessagingPlatformGroup>[
      const MessagingPlatformGroup(
        label: 'Text & Chat',
        subtitle: 'Send and receive messages',
        ids: <String>['whatsapp', 'telegram', 'discord'],
      ),
      const MessagingPlatformGroup(
        label: 'Voice',
        subtitle: 'Inbound and outbound phone calls',
        ids: <String>['telnyx'],
      ),
    ];

    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        const _PageTitle(
          title: 'Messaging',
          subtitle: 'Connect platforms, manage access, and keep channels live.',
        ),
        if (controller.pendingMessagingQr != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: <Widget>[
                    Text(
                      'Scan to finish ${controller.pendingMessagingQr!.platformLabel}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: Image.network(
                        'https://api.qrserver.com/v1/create-qr-code/?data=${Uri.encodeComponent(controller.pendingMessagingQr!.qr)}&size=280x280',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ...groups.map((group) {
          final platforms = messagingPlatforms
              .where((platform) => group.ids.contains(platform.id))
              .toList();
          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: <Widget>[
                      Text(
                        group.label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        group.subtitle,
                        style: const TextStyle(color: _textSecondary),
                      ),
                    ],
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final crossAxisCount = width >= 1200
                        ? 3
                        : width >= 760
                        ? 2
                        : 1;
                    return GridView.builder(
                      itemCount: platforms.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 1.08,
                      ),
                      itemBuilder: (context, index) {
                        final platform = platforms[index];
                        final status =
                            controller.messagingStatuses[platform.id] ??
                            MessagingPlatformStatus.empty(platform.id);
                        return _MessagingCard(
                          controller: controller,
                          platform: platform,
                          status: status,
                          onConfigure: () => _openMessagingConfig(platform),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        }),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Recent Channel Activity'),
                const SizedBox(height: 12),
                if (controller.messagingMessages.isEmpty)
                  const Text(
                    'No platform traffic has been captured yet.',
                    style: TextStyle(color: _textSecondary),
                  )
                else
                  ...controller.messagingMessages.take(12).map((message) {
                    return Padding(
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
                            Row(
                              children: <Widget>[
                                _StatusPill(
                                  label: message.platform.toUpperCase(),
                                  color: message.outgoing ? _accent : _info,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    message.senderLabel,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  message.createdAtLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(message.content.ifEmpty('[empty]')),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
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
      case 'discord':
        return _openDiscordConfig();
      case 'telegram':
        return _openTelegramConfig();
    }
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
              title: const Text('Telnyx Voice'),
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
                  child: const Text('Cancel'),
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
                  child: const Text('Connect'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openDiscordConfig() async {
    final saved = _jsonMap(
      _decodeMaybeJson(widget.controller.settings['discord_config']),
    );
    final token = TextEditingController(text: saved['token']?.toString() ?? '');
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _bgCard,
          title: const Text('Discord'),
          content: SizedBox(
            width: 520,
            child: TextField(
              controller: token,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Bot Token'),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final config = <String, dynamic>{'token': token.text.trim()};
                await widget.controller.connectMessagingPlatform(
                  platform: 'discord',
                  config: config,
                  configSnapshot: <String, dynamic>{
                    'discord_config': jsonEncode(config),
                  },
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Connect'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openTelegramConfig() async {
    final saved = _jsonMap(
      _decodeMaybeJson(widget.controller.settings['telegram_config']),
    );
    final token = TextEditingController(
      text: saved['botToken']?.toString() ?? '',
    );
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _bgCard,
          title: const Text('Telegram'),
          content: SizedBox(
            width: 520,
            child: TextField(
              controller: token,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Bot Token'),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final config = <String, dynamic>{'botToken': token.text.trim()};
                await widget.controller.connectMessagingPlatform(
                  platform: 'telegram',
                  config: config,
                  configSnapshot: <String, dynamic>{
                    'telegram_config': jsonEncode(config),
                  },
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Connect'),
            ),
          ],
        );
      },
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

  Future<void> _selectRun(String runId) async {
    setState(() {
      _selectedRunId = runId;
      _loadingDetail = true;
    });
    try {
      final detail = await widget.controller.fetchRunDetail(runId);
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
    _syncSelection();
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
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
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
    required this.controller,
    required this.platform,
    required this.status,
    required this.onConfigure,
  });

  final NeoAgentController controller;
  final MessagingPlatformDescriptor platform;
  final MessagingPlatformStatus status;
  final Future<void> Function() onConfigure;

  @override
  Widget build(BuildContext context) {
    final whitelist = controller.currentMessagingWhitelist(platform.id);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            platform.accent.withValues(alpha: 0.16),
            const Color(0xFF111625),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderLight),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: platform.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: platform.accent.withValues(alpha: 0.35),
              ),
            ),
            child: Icon(platform.icon, color: Colors.white),
          ),
          title: Text(
            platform.label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              status.authLabel,
              style: const TextStyle(color: _textSecondary),
            ),
          ),
          trailing: _StatusPill(
            label: status.statusLabel,
            color: status.badgeColor,
          ),
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                platform.subtitle,
                style: const TextStyle(color: _textSecondary, height: 1.45),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                if (status.isConnected) ...<Widget>[
                  FilledButton.icon(
                    onPressed: () =>
                        controller.disconnectMessagingPlatform(platform.id),
                    style: FilledButton.styleFrom(
                      backgroundColor: platform.accent,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.link_off),
                    label: const Text('Disconnect'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        controller.logoutMessagingPlatform(platform.id),
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                  ),
                ] else
                  FilledButton.icon(
                    onPressed: onConfigure,
                    style: FilledButton.styleFrom(
                      backgroundColor: platform.accent,
                      foregroundColor: Colors.white,
                    ),
                    icon: Icon(
                      platform.connectMethod == MessagingConnectMethod.qr
                          ? Icons.qr_code_rounded
                          : Icons.link_rounded,
                    ),
                    label: const Text('Connect'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _editWhitelist(context, whitelist),
                  icon: const Icon(Icons.verified_user_outlined),
                  label: Text(
                    whitelist.isEmpty
                        ? 'Access list'
                        : 'Access list (${whitelist.length})',
                  ),
                ),
                if (platform.id == 'telnyx')
                  OutlinedButton.icon(
                    onPressed: () => _editTelnyxSecret(context),
                    icon: const Icon(Icons.password_rounded),
                    label: const Text('Voice PIN'),
                  ),
              ],
            ),
            if (whitelist.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: whitelist
                    .take(8)
                    .map(
                      (entry) =>
                          _MetaPill(label: entry, icon: Icons.shield_outlined),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editWhitelist(
    BuildContext context,
    List<String> initialValues,
  ) async {
    final controllerText = TextEditingController(
      text: initialValues.join('\n'),
    );
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _bgCard,
          title: Text('${platform.label} access'),
          content: SizedBox(
            width: 620,
            child: TextField(
              controller: controllerText,
              minLines: 10,
              maxLines: 16,
              decoration: const InputDecoration(
                labelText: 'One entry per line',
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final values = controllerText.text
                    .split('\n')
                    .map((value) => value.trim())
                    .where((value) => value.isNotEmpty)
                    .toList();
                switch (platform.id) {
                  case 'whatsapp':
                    await controller.saveWhatsAppWhitelist(values);
                    break;
                  case 'telnyx':
                    await controller.saveTelnyxWhitelist(values);
                    break;
                  case 'discord':
                    await controller.saveDiscordWhitelist(values);
                    break;
                  case 'telegram':
                    await controller.saveTelegramWhitelist(values);
                    break;
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editTelnyxSecret(BuildContext context) async {
    final controllerText = TextEditingController(
      text:
          controller.settings['platform_voice_secret_telnyx']?.toString() ?? '',
    );
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _bgCard,
          title: const Text('Voice secret code'),
          content: SizedBox(
            width: 520,
            child: TextField(
              controller: controllerText,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Digits-only PIN'),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await controller.saveTelnyxVoiceSecret(controllerText.text);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
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
          Text(title, style: const TextStyle(color: _textSecondary)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(helper, style: const TextStyle(color: _textSecondary)),
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
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search title, model, trigger, error, or run id',
                suffixIcon: searchController.text.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: searchController.clear,
                        icon: const Icon(Icons.close),
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
                  side: const BorderSide(color: _border),
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
                const Expanded(child: _SectionTitle('Run History')),
                Text(
                  '${runs.length} items',
                  style: const TextStyle(color: _textSecondary),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${run.triggerLabel} • ${run.createdAtLabel}${run.durationLabel == 'In progress' ? '' : ' • ${run.durationLabel}'}',
                    style: const TextStyle(color: _textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${run.modelLabel} • ${run.totalTokensLabel} tokens',
                    style: const TextStyle(color: _textSecondary, fontSize: 12),
                  ),
                  if (run.error.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      run.error,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
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
          const Card(
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
            const Color(0xFF101626),
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
                      style: const TextStyle(
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
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
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
              child: Text(run.error, style: const TextStyle(height: 1.45)),
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
                const Expanded(child: _SectionTitle('Final Response')),
                OutlinedButton.icon(
                  onPressed: response.trim().isEmpty ? null : onCopy,
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('Copy'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (response.trim().isEmpty)
              const Text(
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
                const Expanded(child: _SectionTitle('Step Timeline')),
                if (loading)
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (steps.isEmpty)
              const Text(
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
              Text(
                step.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                step.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
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
            style: const TextStyle(
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

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  late bool _heartbeatEnabled;
  late bool _headlessBrowser;
  late bool _autoSkillLearning;
  late bool _smarterSelector;
  late Set<String> _enabledModels;
  late String _defaultChatModel;
  late String _defaultSubagentModel;
  late String _fallbackModel;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  @override
  void didUpdateWidget(covariant SettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller.settings != widget.controller.settings ||
        oldWidget.controller.supportedModels !=
            widget.controller.supportedModels) {
      _hydrate();
    }
  }

  void _hydrate() {
    final controller = widget.controller;
    _heartbeatEnabled = controller.heartbeatEnabled;
    _headlessBrowser = controller.headlessBrowser;
    _autoSkillLearning = controller.autoSkillLearning;
    _smarterSelector = controller.smarterSelector;
    _enabledModels = controller.enabledModelIds.toSet();
    _defaultChatModel = controller.defaultChatModel;
    _defaultSubagentModel = controller.defaultSubagentModel;
    _fallbackModel = controller.fallbackModel;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final modelChoices = <DropdownMenuItem<String>>[
      const DropdownMenuItem<String>(
        value: 'auto',
        child: Text('Smart Selector (Auto)'),
      ),
      ...controller.supportedModels.map(
        (model) =>
            DropdownMenuItem<String>(value: model.id, child: Text(model.label)),
      ),
    ];

    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Settings',
          subtitle: 'Routing, runtime behavior, token usage, and app updates.',
          trailing: FilledButton.icon(
            onPressed: controller.isSavingSettings
                ? null
                : () => controller.saveSettings(
                    heartbeatEnabled: _heartbeatEnabled,
                    headlessBrowser: _headlessBrowser,
                    autoSkillLearning: _autoSkillLearning,
                    smarterSelector: _smarterSelector,
                    enabledModels: _enabledModels.toList(),
                    defaultChatModel: _defaultChatModel,
                    defaultSubagentModel: _defaultSubagentModel,
                    fallbackModel: _fallbackModel,
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
                : const Icon(Icons.save_outlined),
            label: const Text('Save'),
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
                const _SectionTitle('Automation'),
                const SizedBox(height: 12),
                _SettingToggle(
                  title: 'Heartbeat',
                  subtitle: 'Enable scheduled heartbeat checks',
                  value: _heartbeatEnabled,
                  onChanged: (value) =>
                      setState(() => _heartbeatEnabled = value),
                ),
                _SettingToggle(
                  title: 'Browser',
                  subtitle: 'Run browser headless (no visible window)',
                  value: _headlessBrowser,
                  onChanged: (value) =>
                      setState(() => _headlessBrowser = value),
                ),
                _SettingToggle(
                  title: 'Skill Learning',
                  subtitle:
                      'Create disabled draft skills from successful multi-step runs',
                  value: _autoSkillLearning,
                  onChanged: (value) =>
                      setState(() => _autoSkillLearning = value),
                ),
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
                const _SectionTitle('Model Routing'),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _ensureModelValue(
                    _defaultChatModel,
                    controller.supportedModels,
                    allowAuto: true,
                  ),
                  items: modelChoices,
                  decoration: const InputDecoration(
                    labelText: 'Default Chat Model',
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _defaultChatModel = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _ensureModelValue(
                    _defaultSubagentModel,
                    controller.supportedModels,
                    allowAuto: true,
                  ),
                  items: modelChoices,
                  decoration: const InputDecoration(
                    labelText: 'Default Sub-agent Model',
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _defaultSubagentModel = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _ensureModelValue(
                    _fallbackModel,
                    controller.supportedModels,
                    allowAuto: false,
                  ),
                  items: controller.supportedModels
                      .map(
                        (model) => DropdownMenuItem<String>(
                          value: model.id,
                          child: Text(model.label),
                        ),
                      )
                      .toList(),
                  decoration: const InputDecoration(
                    labelText: 'Fallback Model',
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _fallbackModel = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text(
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
                      label: Text(model.label),
                      selected: selected,
                      selectedColor: _accentMuted,
                      checkmarkColor: _accent,
                      backgroundColor: _bgSecondary,
                      side: const BorderSide(color: _border),
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            _enabledModels.add(model.id);
                          } else if (_enabledModels.length > 1) {
                            _enabledModels.remove(model.id);
                          }
                        });
                      },
                    );
                  }).toList(),
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
                const Row(
                  children: <Widget>[
                    _SectionTitle('Token Usage'),
                    SizedBox(width: 8),
                    Icon(Icons.info_outline, size: 16, color: _textSecondary),
                  ],
                ),
                const SizedBox(height: 12),
                if (controller.tokenUsage == null)
                  const Text(
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
                Row(
                  children: <Widget>[
                    const Expanded(child: _SectionTitle('App Update')),
                    FilledButton.icon(
                      onPressed:
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
                          : const Icon(Icons.system_update),
                      label: const Text('Update'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    _StatusPill(
                      label: controller.updateStatus.badgeLabel,
                      color: controller.updateStatus.badgeColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        controller.updateStatus.message,
                        style: const TextStyle(color: _textSecondary),
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
                const SizedBox(height: 16),
                const Text(
                  'Changelog',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (controller.updateStatus.changelog.isEmpty)
                  const Text(
                    'No commit changes captured',
                    style: TextStyle(color: _textSecondary),
                  )
                else
                  ...controller.updateStatus.changelog.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• $line'),
                    ),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Live Output',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 180),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: SelectableText(
                    controller.updateStatus.logsText,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: _textPrimary,
                      fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
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
}

class LogsPanel extends StatefulWidget {
  const LogsPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<LogsPanel> createState() => _LogsPanelState();
}

class _LogsPanelState extends State<LogsPanel> {
  Future<void> _copyLogs() async {
    final logsText = widget.controller.logs
        .map((log) => log.clipboardLine)
        .join('\n');
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
                onPressed: widget.controller.logs.isEmpty ? null : _copyLogs,
                icon: const Icon(Icons.copy_all_outlined),
                label: const Text('Copy'),
              ),
              OutlinedButton.icon(
                onPressed: widget.controller.clearLogs,
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear'),
              ),
            ],
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: widget.controller.logs.isEmpty
                ? const Text(
                    'Waiting for log output…',
                    style: TextStyle(color: _textSecondary),
                  )
                : Column(
                    children: widget.controller.logs.map((log) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: _border)),
                        ),
                        child: Text.rich(
                          TextSpan(
                            children: <InlineSpan>[
                              TextSpan(
                                text: '[${log.timeLabel}] ',
                                style: const TextStyle(color: _textMuted),
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

class _SkillsPanelState extends State<SkillsPanel> {
  late final TextEditingController _searchController;
  String _selectedCategory = 'all';

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

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final query = _searchController.text.trim().toLowerCase();
    final categories = <String>{
      'all',
      ...controller.storeSkills.map((item) => item.category),
    }.toList();
    final filteredStore = controller.storeSkills.where((item) {
      final matchesQuery =
          query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query);
      final matchesCategory =
          _selectedCategory == 'all' || item.category == _selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();
    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Skills',
          subtitle:
              'Installed skills, draft skills, local skill files, and the skill store.',
          trailing: FilledButton.icon(
            onPressed: () => _openCreateSkill(context),
            icon: const Icon(Icons.add),
            label: const Text('New Skill'),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Installed'),
                const SizedBox(height: 12),
                if (controller.skills.isEmpty)
                  const Text(
                    'No skills installed yet. Drafts from successful runs will appear here too.',
                    style: TextStyle(color: _textSecondary),
                  )
                else
                  ...controller.skills.map(
                    (skill) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _bgSecondary,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    skill.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    skill.description.ifEmpty('No description'),
                                    style: const TextStyle(
                                      color: _textSecondary,
                                    ),
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
                            const SizedBox(width: 12),
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
                                  child: const Text('Open'),
                                ),
                              ],
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
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Store'),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xFF17142A), Color(0xFF111827)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _borderLight),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Skill Store',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Browse installable skills in an app-style catalog with categories, search, and one-click installs.',
                        style: TextStyle(color: _textSecondary, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Search skills',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories.map((category) {
                    final selected = category == _selectedCategory;
                    return FilterChip(
                      selected: selected,
                      label: Text(category == 'all' ? 'All' : category),
                      selectedColor: _accentMuted,
                      checkmarkColor: _accent,
                      backgroundColor: _bgSecondary,
                      side: const BorderSide(color: _border),
                      onSelected: (_) {
                        setState(() => _selectedCategory = category);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                if (filteredStore.isEmpty)
                  const Text(
                    'No store skills match the current filter.',
                    style: TextStyle(color: _textSecondary),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final columns = width >= 1200
                          ? 3
                          : width >= 760
                          ? 2
                          : 1;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredStore.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.96,
                        ),
                        itemBuilder: (context, index) {
                          final item = filteredStore[index];
                          return Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: <Color>[
                                  item.installed
                                      ? const Color(0xFF12202A)
                                      : const Color(0xFF17142A),
                                  item.installed
                                      ? const Color(0xFF101A24)
                                      : const Color(0xFF0E1320),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: item.installed ? _accentMuted : _border,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Container(
                                      width: 52,
                                      height: 52,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.18,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: _border),
                                      ),
                                      child: Text(
                                        item.icon,
                                        style: const TextStyle(fontSize: 22),
                                      ),
                                    ),
                                    const Spacer(),
                                    _StatusPill(
                                      label: item.installed
                                          ? 'Installed'
                                          : 'Available',
                                      color: item.installed ? _success : _info,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.category.toUpperCase(),
                                  style: const TextStyle(
                                    color: _textMuted,
                                    fontSize: 11,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: Text(
                                    item.description,
                                    style: const TextStyle(
                                      color: _textSecondary,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: <Widget>[
                                    Icon(
                                      Icons.storefront_outlined,
                                      size: 15,
                                      color: item.installed ? _success : _info,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      item.installed
                                          ? 'Ready in workspace'
                                          : 'Available to install',
                                      style: const TextStyle(
                                        color: _textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: item.installed
                                      ? OutlinedButton(
                                          onPressed: () => controller
                                              .uninstallStoreSkill(item.id),
                                          child: const Text('Uninstall'),
                                        )
                                      : FilledButton(
                                          onPressed: () => controller
                                              .installStoreSkill(item.id),
                                          child: const Text('Install'),
                                        ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
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
              child: const Text('Cancel'),
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
              child: const Text('Save'),
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
          title: const Text('New Skill'),
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
              child: const Text('Cancel'),
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
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final memoriesToShow = controller.memoryRecallResults.isNotEmpty
        ? controller.memoryRecallResults
        : controller.memories;

    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Memory',
          subtitle: 'Core memory, semantic recall, daily logs, and SOUL.md.',
          trailing: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () => _openSoulEditor(context, controller),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit SOUL'),
              ),
              FilledButton.icon(
                onPressed: () => _openMemoryCreator(context, controller),
                icon: const Icon(Icons.add),
                label: const Text('Add Memory'),
              ),
            ],
          ),
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: _OverviewCard(
                title: 'SOUL.md',
                value: '${controller.memoryOverview.soulLength} chars',
                helper: 'Current self-document length',
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
                        onSubmitted: (value) async {
                          if (value.trim().isEmpty) {
                            controller.clearMemorySearch();
                          } else {
                            await controller.searchMemories(value.trim());
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: () async {
                        final query = _searchController.text.trim();
                        if (query.isEmpty) {
                          controller.clearMemorySearch();
                        } else {
                          await controller.searchMemories(query);
                        }
                      },
                      child: const Text('Search'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () {
                        _searchController.clear();
                        controller.clearMemorySearch();
                      },
                      child: const Text('Reset'),
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
                    const Expanded(child: _SectionTitle('Core Memory')),
                    TextButton.icon(
                      onPressed: () =>
                          _openCoreMemoryEditor(context, controller),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Entry'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (controller.memoryOverview.coreEntries.isEmpty)
                  const Text(
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
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
                            icon: const Icon(Icons.edit_outlined),
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
                            icon: const Icon(Icons.delete_outline),
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
                const SizedBox(height: 10),
                if (memoriesToShow.isEmpty)
                  const Text(
                    'No memory entries found.',
                    style: TextStyle(color: _textSecondary),
                  )
                else
                  ...memoriesToShow.map((memory) {
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _bgSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              _MetaPill(
                                label: memory.category,
                                icon: Icons.label_outline,
                              ),
                              const SizedBox(width: 10),
                              _MetaPill(
                                label: 'Importance ${memory.importance}',
                                icon: Icons.priority_high_outlined,
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => _confirmDelete(
                                  context,
                                  title: 'Delete memory?',
                                  message:
                                      'This memory entry will be removed permanently.',
                                  onConfirm: () =>
                                      controller.deleteMemory(memory.id),
                                ),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(memory.content),
                          const SizedBox(height: 8),
                          Text(
                            memory.createdAtLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _textSecondary,
                            ),
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
                const _SectionTitle('Recent Conversations'),
                const SizedBox(height: 10),
                if (controller.memoryConversations.isEmpty)
                  const Text(
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              conversation.preview,
                              style: const TextStyle(color: _textSecondary),
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
          title: const Text('Add Memory'),
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
                      value: 'semantic',
                      child: Text('semantic'),
                    ),
                    DropdownMenuItem(
                      value: 'procedural',
                      child: Text('procedural'),
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
              child: const Text('Cancel'),
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
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openSoulEditor(
    BuildContext context,
    NeoAgentController controller,
  ) async {
    final contentController = TextEditingController(
      text: controller.memoryOverview.soul,
    );
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _bgCard,
          title: const Text('Edit SOUL.md'),
          content: SizedBox(
            width: 720,
            child: TextField(
              controller: contentController,
              minLines: 16,
              maxLines: 24,
              decoration: const InputDecoration(labelText: 'SOUL.md'),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await controller.updateSoul(contentController.text);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
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
              child: const Text('Cancel'),
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
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

class SchedulerPanel extends StatelessWidget {
  const SchedulerPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Scheduler',
          subtitle: 'Recurring tasks and one-click manual runs.',
          trailing: FilledButton.icon(
            onPressed: () => _openTaskEditor(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Task'),
          ),
        ),
        if (controller.schedulerTasks.isEmpty)
          const _EmptyCard(
            title: 'No scheduled tasks',
            subtitle: 'Create a cron-based task to automate regular work.',
          )
        else
          ...controller.schedulerTasks.map(
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
                              style: const TextStyle(
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
                        task.cronExpression,
                        style: TextStyle(
                          color: _textSecondary,
                          fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                        ),
                      ),
                      if (task.hasModelOverride) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          'Model: ${_modelLabelForValue(task.model, controller.supportedModels)}',
                          style: const TextStyle(color: _textSecondary),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        task.prompt,
                        style: const TextStyle(color: _textPrimary),
                      ),
                      if (task.lastRunLabel.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          'Last run: ${task.lastRunLabel}',
                          style: const TextStyle(color: _textSecondary),
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
                            child: const Text('Edit'),
                          ),
                          OutlinedButton(
                            onPressed: () =>
                                controller.toggleSchedulerTask(task),
                            child: Text(task.enabled ? 'Pause' : 'Enable'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                controller.runSchedulerTask(task.id),
                            child: const Text('Run Now'),
                          ),
                          OutlinedButton(
                            onPressed: () => _confirmDelete(
                              context,
                              title: 'Delete task?',
                              message: 'This will remove "${task.name}".',
                              onConfirm: () =>
                                  controller.deleteSchedulerTask(task.id),
                            ),
                            child: const Text('Delete'),
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
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: enabled,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enabled'),
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
                  child: const Text('Cancel'),
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
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
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
            icon: const Icon(Icons.add),
            label: const Text('Add Server'),
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
                              style: const TextStyle(
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
                            child: const Text('Edit'),
                          ),
                          if (server.status == 'running')
                            FilledButton(
                              onPressed: () =>
                                  controller.stopMcpServer(server.id),
                              child: const Text('Stop'),
                            )
                          else
                            FilledButton(
                              onPressed: () =>
                                  controller.startMcpServer(server.id),
                              child: const Text('Start'),
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
                            child: const Text('Delete'),
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
                      const SizedBox(height: 12),
                      const Align(
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
                        title: const Text('Enabled'),
                        onChanged: (value) =>
                            setLocalState(() => enabled = value),
                      ),
                      const SizedBox(height: 4),
                      const Align(
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
                  child: const Text('Cancel'),
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
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Save'),
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
              child: _HealthSummary(
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
              child: _HealthSummary(
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
                  icon: const Icon(Icons.health_and_safety_outlined),
                  label: const Text('Request permissions'),
                ),
                FilledButton.icon(
                  onPressed: controller.isSyncingHealth
                      ? null
                      : controller.syncHealthNow,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF5EEAD4),
                    foregroundColor: const Color(0xFF063238),
                  ),
                  icon: controller.isSyncingHealth
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: const Text('Sync now'),
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
                  const Text(
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
                        style: const TextStyle(color: _textSecondary),
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
                    style: const TextStyle(
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
                  const Text('No health samples stored yet.')
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

Widget _buildHealthSummaryPills(Map<String, dynamic> summary) {
  return Wrap(
    spacing: 10,
    runSpacing: 10,
    children: <Widget>[
      _MetaPill(
        icon: Icons.directions_walk_outlined,
        label: 'Steps ${_asInt(summary['stepsTotal'])}',
      ),
      _MetaPill(
        icon: Icons.favorite_outline,
        label: 'Heart ${_asInt(summary['heartRateRecordCount'])} records',
      ),
      _MetaPill(
        icon: Icons.bedtime_outlined,
        label: 'Sleep ${_asInt(summary['sleepSessionCount'])} sessions',
      ),
      _MetaPill(
        icon: Icons.fitness_center_outlined,
        label: 'Exercise ${_asInt(summary['exerciseSessionCount'])} sessions',
      ),
      _MetaPill(
        icon: Icons.monitor_weight_outlined,
        label: 'Weight ${_asInt(summary['weightRecordCount'])} records',
      ),
    ],
  );
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(subtitle, style: const TextStyle(color: _textSecondary)),
                if (trailing != null) ...<Widget>[
                  const SizedBox(height: 14),
                  trailing!,
                ],
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
                        title,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(color: _textSecondary),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
    );
  }
}

class _RunStatusPanel extends StatelessWidget {
  const _RunStatusPanel({required this.run, required this.tools});

  final ActiveRunState? run;
  final List<ToolEventItem> tools;

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        run?.title ?? 'Live run',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        run == null
                            ? 'Waiting for run events...'
                            : '${run!.phase}${run!.iteration > 0 ? ' · step ${run!.iteration}' : ''}',
                        style: const TextStyle(color: _textSecondary),
                      ),
                    ],
                  ),
                ),
                if (run != null && run!.model.isNotEmpty)
                  _MetaPill(label: run!.model, icon: Icons.memory_outlined),
              ],
            ),
            if (tools.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: tools.map((tool) => _ToolChip(tool: tool)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({required this.tool});

  final ToolEventItem tool;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (tool.status) {
      case 'running':
        color = _warning;
        break;
      case 'failed':
        color = _danger;
        break;
      default:
        color = _success;
    }
    return Container(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 340),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                tool.type == 'note' ? Icons.info_outline : Icons.build_outlined,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tool.toolName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _StatusPill(label: tool.status, color: color),
            ],
          ),
          if (tool.summary.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              tool.summary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingToggle extends StatelessWidget {
  const _SettingToggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      onChanged: onChanged,
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.title,
    required this.value,
    required this.helper,
  });

  final String title;
  final String value;
  final String helper;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: const TextStyle(color: _textSecondary)),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(helper, style: const TextStyle(color: _textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: _EmptyState(title: title, subtitle: subtitle),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }
}

class _DotStatus extends StatelessWidget {
  const _DotStatus({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({
    required this.label,
    required this.icon,
    this.active = false,
    this.indent = 0,
    this.iconSize = 18,
    this.fontSize = 13,
    this.trailing,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final double indent;
  final double iconSize;
  final double fontSize;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: active ? _accentMuted : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(10 + indent, 9, 10, 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: active
                  ? const Border(left: BorderSide(color: _accent, width: 3))
                  : null,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  icon,
                  size: iconSize,
                  color: active ? _accent : _textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w500,
                      color: active ? _accent : _textSecondary,
                    ),
                  ),
                ),
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: 8),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BlurOrb extends StatelessWidget {
  const _BlurOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color.withValues(alpha: 0.18),
              blurRadius: 120,
              spreadRadius: 30,
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthTabButton extends StatelessWidget {
  const _AuthTabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? _accent : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: active ? Colors.white : _textSecondary,
          ),
        ),
      ),
    );
  }
}

class _LogoBadge extends StatelessWidget {
  const _LogoBadge({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[_accent, Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x736366F1),
            blurRadius: 24,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: _borderLight),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.18),
        child: CustomPaint(painter: _NeoAgentLogoPainter()),
      ),
    );
  }
}

class _NeoAgentLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final top = Path()
      ..moveTo(size.width * 0.5, size.height * 0.08)
      ..lineTo(size.width * 0.1, size.height * 0.3)
      ..lineTo(size.width * 0.5, size.height * 0.52)
      ..lineTo(size.width * 0.9, size.height * 0.3)
      ..close();
    canvas.drawPath(top, fillPaint);

    final middle = Path()
      ..moveTo(size.width * 0.1, size.height * 0.52)
      ..lineTo(size.width * 0.5, size.height * 0.74)
      ..lineTo(size.width * 0.9, size.height * 0.52);
    canvas.drawPath(middle, strokePaint);

    final bottom = Path()
      ..moveTo(size.width * 0.1, size.height * 0.72)
      ..lineTo(size.width * 0.5, size.height * 0.94)
      ..lineTo(size.width * 0.9, size.height * 0.72);
    canvas.drawPath(bottom, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const _LogoBadge(size: 52),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: _textMuted),
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.entry});

  final ChatEntry entry;

  @override
  Widget build(BuildContext context) {
    final isUser = entry.role == 'user';
    final isTransient = entry.transient;

    return Opacity(
      opacity: isTransient ? 0.92 : 1,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: <Widget>[
          if (!isUser) ...<Widget>[
            const _MessageAvatar(assistant: true),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: isUser ? _accent : _bgCard,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isUser ? 14 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 14),
                ),
                border: isUser ? null : Border.all(color: _border),
                boxShadow: isUser
                    ? const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x4D6366F1),
                          blurRadius: 12,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: <Widget>[
                  if (!isUser && entry.platformTag != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _StatusPill(
                        label: entry.platformTag!,
                        color: entry.platform == 'live' ? _info : _warning,
                      ),
                    ),
                  MarkdownBody(
                    data: entry.content,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                        .copyWith(
                          p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isUser ? Colors.white : _textPrimary,
                            height: 1.65,
                          ),
                          code: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontFamily:
                                    GoogleFonts.jetBrainsMono().fontFamily,
                                backgroundColor: _bgPrimary,
                                color: isUser ? Colors.white : _textPrimary,
                              ),
                          blockquoteDecoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: const Color(0x22000000),
                          ),
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    entry.createdAtLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isUser ? const Color(0xCCFFFFFF) : _textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...<Widget>[
            const SizedBox(width: 12),
            const _MessageAvatar(assistant: false),
          ],
        ],
      ),
    );
  }
}

class _MessageAvatar extends StatelessWidget {
  const _MessageAvatar({required this.assistant});

  final bool assistant;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: assistant
            ? const LinearGradient(colors: <Color>[_accent, Color(0xFF8B5CF6)])
            : null,
        color: assistant ? null : const Color(0xFF1E1E32),
        boxShadow: assistant
            ? const <BoxShadow>[
                BoxShadow(
                  color: Color(0x596366F1),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Icon(
        assistant ? Icons.auto_awesome : Icons.person,
        size: 16,
        color: assistant ? Colors.white : _textSecondary,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: const Color(0xFF5EEAD4)),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x19EF4444),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x4CEF4444)),
      ),
      child: Text(message, style: const TextStyle(fontSize: 13)),
    );
  }
}

class _HealthSummary extends StatelessWidget {
  const _HealthSummary({
    required this.title,
    required this.value,
    required this.helper,
  });

  final String title;
  final String value;
  final String helper;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: const TextStyle(color: _textSecondary)),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(helper),
          ],
        ),
      ),
    );
  }
}

const List<MessagingPlatformDescriptor> messagingPlatforms =
    <MessagingPlatformDescriptor>[
      MessagingPlatformDescriptor(
        id: 'whatsapp',
        label: 'WhatsApp',
        subtitle: 'QR-based phone linking',
        accent: Color(0xFF25D366),
        connectMethod: MessagingConnectMethod.qr,
        icon: Icons.chat_bubble,
      ),
      MessagingPlatformDescriptor(
        id: 'telegram',
        label: 'Telegram',
        subtitle: 'Bot token and approved chats',
        accent: Color(0xFF2AABEE),
        connectMethod: MessagingConnectMethod.config,
        icon: Icons.send_rounded,
      ),
      MessagingPlatformDescriptor(
        id: 'discord',
        label: 'Discord',
        subtitle: 'Bot token and server/channel access',
        accent: Color(0xFF5865F2),
        connectMethod: MessagingConnectMethod.config,
        icon: Icons.sports_esports_rounded,
      ),
      MessagingPlatformDescriptor(
        id: 'telnyx',
        label: 'Telnyx Voice',
        subtitle: 'Inbound and outbound calling',
        accent: Color(0xFF00C8A0),
        connectMethod: MessagingConnectMethod.config,
        icon: Icons.call_rounded,
      ),
    ];

enum MessagingConnectMethod { qr, config }

class MessagingPlatformDescriptor {
  const MessagingPlatformDescriptor({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.accent,
    required this.connectMethod,
    required this.icon,
  });

  final String id;
  final String label;
  final String subtitle;
  final Color accent;
  final MessagingConnectMethod connectMethod;
  final IconData icon;
}

class MessagingPlatformGroup {
  const MessagingPlatformGroup({
    required this.label,
    required this.subtitle,
    required this.ids,
  });

  final String label;
  final String subtitle;
  final List<String> ids;
}

class MessagingPlatformStatus {
  const MessagingPlatformStatus({
    required this.platform,
    required this.status,
    this.lastConnected,
    this.authInfo = const <String, dynamic>{},
  });

  factory MessagingPlatformStatus.fromJson(
    String platform,
    Map<String, dynamic> json,
  ) {
    return MessagingPlatformStatus(
      platform: platform,
      status:
          json['status']?.toString().ifEmpty('not_configured') ??
          'not_configured',
      lastConnected: _parseOptionalTimestamp(json['lastConnected']?.toString()),
      authInfo: _jsonMap(json['authInfo']),
    );
  }

  factory MessagingPlatformStatus.empty(String platform) {
    return MessagingPlatformStatus(
      platform: platform,
      status: 'not_configured',
    );
  }

  final String platform;
  final String status;
  final DateTime? lastConnected;
  final Map<String, dynamic> authInfo;

  bool get isConnected => status == 'connected';
  bool get isConnecting => status == 'connecting' || status == 'awaiting_qr';

  String get statusLabel => status.replaceAll('_', ' ');

  String get authLabel {
    for (final key in <String>['phoneNumber', 'tag', 'username']) {
      final value = authInfo[key]?.toString();
      if (value != null && value.trim().isNotEmpty) {
        return key == 'username' ? '@$value' : value;
      }
    }
    if (lastConnected != null) {
      return 'Last seen ${_formatTimestamp(lastConnected!)}';
    }
    return 'Not connected';
  }

  Color get badgeColor {
    switch (status) {
      case 'connected':
        return _success;
      case 'awaiting_qr':
      case 'connecting':
        return _warning;
      case 'logged_out':
        return _danger;
      default:
        return _textSecondary;
    }
  }
}

class MessagingMessage {
  const MessagingMessage({
    required this.platform,
    required this.content,
    required this.createdAt,
    required this.outgoing,
    this.chatId,
    this.sender,
    this.senderName,
    this.target,
  });

  factory MessagingMessage.fromJson(Map<dynamic, dynamic> json) {
    final metadata = _decodeMaybeJson(json['metadata']);
    return MessagingMessage(
      platform: json['platform']?.toString() ?? 'web',
      content: json['content']?.toString() ?? '',
      createdAt: _parseTimestamp(json['created_at']?.toString()),
      outgoing: json['role']?.toString() == 'assistant',
      chatId: json['platform_chat_id']?.toString(),
      sender: metadata['sender']?.toString(),
      senderName: metadata['senderName']?.toString(),
      target: json['platform_chat_id']?.toString(),
    );
  }

  factory MessagingMessage.fromSocket(
    Map<String, dynamic> json, {
    required bool outgoing,
  }) {
    return MessagingMessage(
      platform: json['platform']?.toString() ?? 'web',
      content: json['content']?.toString() ?? '',
      createdAt: DateTime.now(),
      outgoing: outgoing,
      chatId: json['chatId']?.toString() ?? json['to']?.toString(),
      sender: json['sender']?.toString(),
      senderName: json['senderName']?.toString(),
      target: json['to']?.toString(),
    );
  }

  factory MessagingMessage.fromBlockedNotice(BlockedSenderNotice notice) {
    final summary = <String>[
      'Blocked incoming message from ${notice.senderLabel}.',
      if (notice.meta.isNotEmpty) notice.meta,
      if (notice.suggestions.isNotEmpty)
        'Suggestions: ${notice.suggestions.map((item) => item.label).join(', ')}',
      'Update the access list to allow replies.',
    ].join('\n');

    return MessagingMessage(
      platform: notice.platform,
      content: summary,
      createdAt: DateTime.now(),
      outgoing: false,
      chatId: notice.chatId,
      sender: notice.sender,
      senderName: notice.senderName,
    );
  }

  final String platform;
  final String content;
  final DateTime createdAt;
  final bool outgoing;
  final String? chatId;
  final String? sender;
  final String? senderName;
  final String? target;

  String get createdAtLabel => _formatTimestamp(createdAt);

  String get senderLabel {
    if (outgoing) {
      return target?.ifEmpty('Outgoing message') ?? 'Outgoing message';
    }
    return senderName?.ifEmpty(sender ?? platform.toUpperCase()) ??
        sender?.ifEmpty(platform.toUpperCase()) ??
        platform.toUpperCase();
  }
}

class MessagingQrState {
  const MessagingQrState({required this.platform, required this.qr});

  final String platform;
  final String qr;

  String get platformLabel {
    for (final item in messagingPlatforms) {
      if (item.id == platform) {
        return item.label;
      }
    }
    return platform;
  }
}

class BlockedSenderNotice {
  const BlockedSenderNotice({
    required this.id,
    required this.platform,
    required this.chatId,
    required this.sender,
    required this.senderName,
    required this.meta,
    required this.suggestions,
  });

  factory BlockedSenderNotice.fromSocket(Map<String, dynamic> json) {
    final platform = json['platform']?.toString() ?? 'web';
    final sender = json['sender']?.toString();
    final senderName = json['senderName']?.toString();
    final chatId = json['chatId']?.toString();
    final meta = (json['meta']?.toString() ?? '').trim();
    final suggestionsRaw = json['suggestions'];
    final suggestions = suggestionsRaw is List
        ? suggestionsRaw
              .whereType<Map>()
              .map(
                (item) => QuickAllowSuggestion.fromJson(
                  platform,
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((item) => item.entry.isNotEmpty)
              .toList()
        : const <QuickAllowSuggestion>[];

    return BlockedSenderNotice(
      id: '$platform:${chatId ?? ''}:${sender ?? ''}',
      platform: platform,
      chatId: chatId,
      sender: sender,
      senderName: senderName,
      meta: meta,
      suggestions: suggestions,
    );
  }

  final String id;
  final String platform;
  final String? chatId;
  final String? sender;
  final String? senderName;
  final String meta;
  final List<QuickAllowSuggestion> suggestions;

  String get senderLabel =>
      senderName?.ifEmpty(sender ?? platform.toUpperCase()) ??
      sender?.ifEmpty(platform.toUpperCase()) ??
      platform.toUpperCase();
}

class QuickAllowSuggestion {
  const QuickAllowSuggestion({required this.label, required this.entry});

  factory QuickAllowSuggestion.fromJson(
    String platform,
    Map<String, dynamic> json,
  ) {
    final prefixedId = json['prefixedId']?.toString().trim() ?? '';
    return QuickAllowSuggestion(
      label:
          json['label']?.toString().ifEmpty('Allow sender') ?? 'Allow sender',
      entry: _normalizeSuggestedWhitelistEntry(platform, prefixedId),
    );
  }

  final String label;
  final String entry;
}

class RecordingSessionItem {
  const RecordingSessionItem({
    required this.id,
    required this.title,
    required this.platform,
    required this.status,
    required this.startedAt,
    required this.endedAt,
    required this.durationMs,
    required this.transcriptText,
    required this.lastError,
    required this.sources,
    required this.transcriptSegments,
  });

  factory RecordingSessionItem.fromJson(Map<dynamic, dynamic> json) {
    return RecordingSessionItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString().ifEmpty('Recording') ?? 'Recording',
      platform: json['platform']?.toString() ?? 'unknown',
      status: json['status']?.toString() ?? 'recording',
      startedAt: _parseTimestamp(json['startedAt']?.toString()),
      endedAt: _parseOptionalTimestamp(json['endedAt']?.toString()),
      durationMs: _asInt(json['durationMs']),
      transcriptText: json['transcriptText']?.toString() ?? '',
      lastError: json['lastError']?.toString(),
      sources: (json['sources'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<dynamic, dynamic>>()
          .map(RecordingSourceItem.fromJson)
          .toList(),
      transcriptSegments:
          (json['transcriptSegments'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<dynamic, dynamic>>()
              .map(RecordingTranscriptSegment.fromJson)
              .toList(),
    );
  }

  final String id;
  final String title;
  final String platform;
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationMs;
  final String transcriptText;
  final String? lastError;
  final List<RecordingSourceItem> sources;
  final List<RecordingTranscriptSegment> transcriptSegments;

  String get startedAtLabel => _formatTimestamp(startedAt);

  String get platformLabel {
    switch (platform) {
      case 'web':
        return 'Web';
      case 'android':
        return 'Android';
      default:
        return platform.ifEmpty('Unknown');
    }
  }

  String get durationLabel => _formatDuration(durationMs);

  String get statusLabel {
    switch (status) {
      case 'recording':
        return 'Recording';
      case 'processing':
        return 'Processing';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'recording':
        return _danger;
      case 'processing':
        return _warning;
      case 'completed':
        return _success;
      case 'failed':
        return _danger;
      case 'cancelled':
        return _textSecondary;
      default:
        return _textSecondary;
    }
  }
}

class RecordingSourceItem {
  const RecordingSourceItem({
    required this.sourceKey,
    required this.sourceKind,
    required this.mediaKind,
    required this.durationMs,
    required this.chunkCount,
  });

  factory RecordingSourceItem.fromJson(Map<dynamic, dynamic> json) {
    return RecordingSourceItem(
      sourceKey: json['sourceKey']?.toString() ?? '',
      sourceKind: json['sourceKind']?.toString() ?? '',
      mediaKind: json['mediaKind']?.toString() ?? '',
      durationMs: _asInt(json['durationMs']),
      chunkCount: _asInt(json['chunkCount']),
    );
  }

  final String sourceKey;
  final String sourceKind;
  final String mediaKind;
  final int durationMs;
  final int chunkCount;

  String get label {
    switch (sourceKind) {
      case 'screen-share':
        return 'Screen';
      case 'microphone':
        return 'Microphone';
      default:
        return sourceKind.ifEmpty(sourceKey);
    }
  }

  String get durationLabel => _formatDuration(durationMs);
}

class RecordingTranscriptSegment {
  const RecordingTranscriptSegment({
    required this.id,
    required this.speaker,
    required this.text,
    required this.startMs,
  });

  factory RecordingTranscriptSegment.fromJson(Map<dynamic, dynamic> json) {
    return RecordingTranscriptSegment(
      id: _asInt(json['id']),
      speaker:
          json['speaker']?.toString() ?? json['sourceKey']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      startMs: _asInt(json['startMs']),
    );
  }

  final int id;
  final String speaker;
  final String text;
  final int startMs;

  String get timestampLabel => _formatDuration(startMs);

  String get displayText {
    if (speaker.trim().isEmpty) {
      return text;
    }
    return '${speaker.replaceAll('-', ' ')}: $text';
  }
}

class RunDetailSnapshot {
  const RunDetailSnapshot({
    required this.run,
    required this.steps,
    required this.response,
  });

  factory RunDetailSnapshot.fromJson(Map<dynamic, dynamic> json) {
    return RunDetailSnapshot(
      run: RunSummary.fromJson(_jsonMap(json['run'])),
      steps: (json['steps'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<dynamic, dynamic>>()
          .map(RunStepItem.fromJson)
          .toList(),
      response: json['response']?.toString() ?? '',
    );
  }

  final RunSummary run;
  final List<RunStepItem> steps;
  final String response;

  int get completedTools => steps
      .where((step) => step.toolName.isNotEmpty && step.status == 'completed')
      .length;

  int get failedTools => steps.where((step) => step.status == 'failed').length;

  int get helperCount => steps.where((step) {
    final label = '${step.type} ${step.toolName}'.toLowerCase();
    return label.contains('subagent') || label.contains('helper');
  }).length;
}

class RunStepItem {
  const RunStepItem({
    required this.id,
    required this.index,
    required this.type,
    required this.description,
    required this.status,
    required this.toolName,
    required this.toolInput,
    required this.result,
    required this.error,
    required this.tokensUsed,
    required this.startedAt,
    required this.completedAt,
  });

  factory RunStepItem.fromJson(Map<dynamic, dynamic> json) {
    return RunStepItem(
      id: json['id']?.toString() ?? '',
      index: _asInt(json['step_index']),
      type: json['type']?.toString().ifEmpty('step') ?? 'step',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString().ifEmpty('pending') ?? 'pending',
      toolName: json['tool_name']?.toString() ?? '',
      toolInput: json['tool_input']?.toString() ?? '',
      result: json['result']?.toString() ?? '',
      error: json['error']?.toString() ?? '',
      tokensUsed: _asInt(json['tokens_used']),
      startedAt: _parseOptionalTimestamp(json['started_at']?.toString()),
      completedAt: _parseOptionalTimestamp(json['completed_at']?.toString()),
    );
  }

  final String id;
  final int index;
  final String type;
  final String description;
  final String status;
  final String toolName;
  final String toolInput;
  final String result;
  final String error;
  final int tokensUsed;
  final DateTime? startedAt;
  final DateTime? completedAt;

  int get displayIndex => index + 1;

  String get label => toolName.ifEmpty(type.replaceAll('_', ' '));

  String get typeLabel => _titleCase(type.replaceAll('_', ' '));

  String get statusLabel => _titleCase(status.replaceAll('_', ' '));

  String get inputSummary =>
      _summarizeToolArgs(_decodeMaybeJson(toolInput)).ifEmpty('');

  String? get startedAtLabel =>
      startedAt == null ? null : _formatTimestamp(startedAt!);

  Duration? get duration => startedAt == null || completedAt == null
      ? null
      : completedAt!.difference(startedAt!);

  String? get durationLabel =>
      duration == null ? null : _formatElapsed(duration!);

  String get summary {
    final resultText = _summarizeToolResult(_decodeMaybeJson(result));
    if (error.trim().isNotEmpty) {
      return error;
    }
    if (resultText.trim().isNotEmpty) {
      return resultText;
    }
    return description.ifEmpty('No details captured.');
  }

  Color get statusColor {
    switch (status) {
      case 'completed':
        return _success;
      case 'failed':
        return _danger;
      case 'running':
        return _warning;
      default:
        return _textSecondary;
    }
  }
}

Map<String, dynamic> _decodeMaybeJson(dynamic value) {
  if (value == null) {
    return const <String, dynamic>{};
  }
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
  }
  return const <String, dynamic>{};
}

class ChatEntry {
  const ChatEntry({
    required this.role,
    required this.content,
    required this.platform,
    required this.createdAt,
    this.senderName,
    this.transient = false,
  });

  factory ChatEntry.fromJson(Map<dynamic, dynamic> json) {
    return ChatEntry(
      role: json['role']?.toString() ?? 'assistant',
      content: json['content']?.toString() ?? '',
      platform: json['platform']?.toString() ?? 'web',
      senderName: json['sender_name']?.toString(),
      createdAt: _parseTimestamp(json['created_at']?.toString()),
    );
  }

  final String role;
  final String content;
  final String platform;
  final String? senderName;
  final DateTime createdAt;
  final bool transient;

  String get createdAtLabel => _formatTimestamp(createdAt);

  String? get platformTag {
    if (platform == 'live') {
      return 'LIVE';
    }
    if (platform != 'web' && platform != 'flutter' && platform.isNotEmpty) {
      return platform.toUpperCase();
    }
    return null;
  }
}

class ModelMeta {
  const ModelMeta({
    required this.id,
    required this.label,
    required this.provider,
    required this.purpose,
  });

  factory ModelMeta.fromJson(Map<dynamic, dynamic> json) {
    return ModelMeta(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? '',
    );
  }

  final String id;
  final String label;
  final String provider;
  final String purpose;
}

class RunSummary {
  const RunSummary({
    required this.id,
    required this.title,
    required this.status,
    required this.model,
    required this.triggerSource,
    required this.totalTokens,
    required this.createdAt,
    this.completedAt,
    this.error = '',
  });

  factory RunSummary.fromJson(Map<dynamic, dynamic> json) {
    return RunSummary(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled',
      status: json['status']?.toString() ?? 'unknown',
      model: json['model']?.toString() ?? '',
      triggerSource: json['trigger_source']?.toString() ?? '',
      totalTokens: _asInt(json['total_tokens']),
      createdAt: _parseTimestamp(json['created_at']?.toString()),
      completedAt: _parseOptionalTimestamp(json['completed_at']?.toString()),
      error: json['error']?.toString() ?? '',
    );
  }

  final String id;
  final String title;
  final String status;
  final String model;
  final String triggerSource;
  final int totalTokens;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String error;

  bool get isFailure => status == 'failed' || status == 'error';

  String get createdAtLabel => _formatTimestamp(createdAt);

  String get totalTokensLabel => _formatNumber(totalTokens);

  String get statusLabel => _titleCase(status.replaceAll('_', ' '));

  String get triggerLabel => triggerSource.ifEmpty('web');

  String get modelLabel => model.ifEmpty('Model pending');

  Duration? get duration => completedAt?.difference(createdAt);

  String get durationLabel =>
      completedAt == null ? 'In progress' : _formatElapsed(duration!);

  Color get statusColor {
    switch (status) {
      case 'completed':
        return _success;
      case 'failed':
      case 'error':
        return _danger;
      case 'running':
        return _warning;
      default:
        return _textSecondary;
    }
  }
}

class TokenUsageSnapshot {
  const TokenUsageSnapshot({
    required this.totalTokens,
    required this.totalRuns,
    required this.avgTokensPerRun,
    required this.last7DaysTokens,
    required this.last7DaysRuns,
  });

  factory TokenUsageSnapshot.fromJson(Map<dynamic, dynamic> json) {
    final totals = json['totals'] is Map
        ? Map<String, dynamic>.from(json['totals'] as Map)
        : const <String, dynamic>{};
    return TokenUsageSnapshot(
      totalTokens: _asInt(totals['totalTokens']),
      totalRuns: _asInt(totals['totalRuns']),
      avgTokensPerRun: _asInt(totals['avgTokensPerRun']),
      last7DaysTokens: _asInt(totals['last7DaysTokens']),
      last7DaysRuns: _asInt(totals['last7DaysRuns']),
    );
  }

  final int totalTokens;
  final int totalRuns;
  final int avgTokensPerRun;
  final int last7DaysTokens;
  final int last7DaysRuns;

  String get totalTokensLabel => _formatNumber(totalTokens);
  String get totalRunsLabel => _formatNumber(totalRuns);
  String get avgTokensPerRunLabel => _formatNumber(avgTokensPerRun);
  String get last7DaysTokensLabel => _formatNumber(last7DaysTokens);
  String get last7DaysRunsLabel => _formatNumber(last7DaysRuns);
}

class UpdateStatusSnapshot {
  const UpdateStatusSnapshot({
    this.state = 'idle',
    this.progress = 0,
    this.message = 'No update running',
    this.versionBefore,
    this.versionAfter,
    this.backendVersion,
    this.installedVersion,
    this.changelog = const <String>[],
    this.logs = const <String>[],
  });

  factory UpdateStatusSnapshot.fromJson(Map<dynamic, dynamic> json) {
    return UpdateStatusSnapshot(
      state: json['state']?.toString() ?? 'idle',
      progress: _asInt(json['progress']).clamp(0, 100),
      message: json['message']?.toString() ?? 'No update running',
      versionBefore: json['versionBefore']?.toString(),
      versionAfter: json['versionAfter']?.toString(),
      backendVersion: json['backendVersion']?.toString(),
      installedVersion:
          json['installedVersion']?.toString() ??
          json['packageVersion']?.toString(),
      changelog: (json['changelog'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      logs: (json['logs'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }

  final String state;
  final int progress;
  final String message;
  final String? versionBefore;
  final String? versionAfter;
  final String? backendVersion;
  final String? installedVersion;
  final List<String> changelog;
  final List<String> logs;

  String get badgeLabel {
    switch (state) {
      case 'running':
        return 'Running';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      default:
        return 'Idle';
    }
  }

  Color get badgeColor {
    switch (state) {
      case 'running':
        return _info;
      case 'completed':
        return _success;
      case 'failed':
        return _danger;
      default:
        return _textSecondary;
    }
  }

  String get versionLine {
    final before = versionBefore?.ifEmpty('—') ?? '—';
    final after = versionAfter?.ifEmpty('—') ?? '—';
    final updateVersion = after == '—' ? before : '$before -> $after';
    final installed = installedVersion == null
        ? ''
        : ' | Installed: $installedVersion';
    final backend = backendVersion == null ? '' : ' | Runtime: $backendVersion';
    return 'Update Version: $updateVersion$installed$backend';
  }

  String get logsText =>
      logs.isEmpty ? 'Waiting for update job output…' : logs.join('\n');
}

class LogEntry {
  const LogEntry({
    required this.type,
    required this.message,
    required this.timestamp,
  });

  factory LogEntry.fromJson(Map<dynamic, dynamic> json) {
    return LogEntry(
      type: json['type']?.toString() ?? 'log',
      message: json['message']?.toString() ?? '',
      timestamp: _parseTimestamp(json['timestamp']?.toString()),
    );
  }

  final String type;
  final String message;
  final DateTime timestamp;

  String get timeLabel => _formatTimeOnly(timestamp);

  String get clipboardLine => '[$timeLabel] $message';

  Color get color {
    switch (type) {
      case 'error':
        return _danger;
      case 'warn':
        return _warning;
      case 'info':
        return _info;
      default:
        return _textPrimary;
    }
  }
}

class SkillItem {
  const SkillItem({
    required this.name,
    required this.description,
    required this.enabled,
    required this.draft,
    required this.category,
    required this.source,
  });

  factory SkillItem.fromJson(Map<dynamic, dynamic> json) {
    return SkillItem(
      name: json['name']?.toString() ?? 'Skill',
      description: json['description']?.toString() ?? '',
      enabled: json['enabled'] != false,
      draft: json['draft'] == true,
      category: json['category']?.toString().ifEmpty('general') ?? 'general',
      source: json['source']?.toString().ifEmpty('local') ?? 'local',
    );
  }

  final String name;
  final String description;
  final bool enabled;
  final bool draft;
  final String category;
  final String source;
}

class StoreSkillItem {
  const StoreSkillItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    required this.installed,
  });

  factory StoreSkillItem.fromJson(Map<dynamic, dynamic> json) {
    return StoreSkillItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Skill',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString().ifEmpty('general') ?? 'general',
      icon: json['icon']?.toString().ifEmpty('🧩') ?? '🧩',
      installed: json['installed'] == true,
    );
  }

  final String id;
  final String name;
  final String description;
  final String category;
  final String icon;
  final bool installed;
}

class SkillDocument {
  const SkillDocument({required this.name, required this.content});

  factory SkillDocument.fromJson(Map<dynamic, dynamic> json) {
    return SkillDocument(
      name: json['name']?.toString() ?? 'Skill',
      content: json['content']?.toString() ?? '',
    );
  }

  final String name;
  final String content;
}

class MemoryOverview {
  const MemoryOverview({
    this.soul = '',
    this.dailyLogs = const <String>[],
    this.apiKeys = const <String, String>{},
    this.coreEntries = const <String, dynamic>{},
  });

  factory MemoryOverview.fromJson(Map<dynamic, dynamic> json) {
    final apiKeysRaw = json['apiKeys'];
    final coreRaw = json['coreMemory'];
    return MemoryOverview(
      soul: json['soul']?.toString() ?? '',
      dailyLogs: (json['dailyLogs'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      apiKeys: apiKeysRaw is Map
          ? Map<String, String>.from(
              apiKeysRaw.map(
                (key, value) =>
                    MapEntry(key.toString(), value?.toString() ?? ''),
              ),
            )
          : const <String, String>{},
      coreEntries: coreRaw is Map
          ? Map<String, dynamic>.from(coreRaw)
          : const <String, dynamic>{},
    );
  }

  final String soul;
  final List<String> dailyLogs;
  final Map<String, String> apiKeys;
  final Map<String, dynamic> coreEntries;

  int get soulLength => soul.length;
  int get dailyLogCount => dailyLogs.length;
  int get apiKeyCount => apiKeys.length;
  int get coreCount => coreEntries.length;
}

class MemoryItem {
  const MemoryItem({
    required this.id,
    required this.content,
    required this.category,
    required this.importance,
    required this.createdAt,
  });

  factory MemoryItem.fromJson(Map<dynamic, dynamic> json) {
    return MemoryItem(
      id: _asInt(json['id']),
      content: json['content']?.toString() ?? '',
      category: json['category']?.toString().ifEmpty('memory') ?? 'memory',
      importance: _asInt(json['importance']),
      createdAt: _parseTimestamp(json['created_at']?.toString()),
    );
  }

  final int id;
  final String content;
  final String category;
  final int importance;
  final DateTime createdAt;

  String get createdAtLabel => _formatTimestamp(createdAt);
}

class ConversationItem {
  const ConversationItem({required this.title, required this.preview});

  factory ConversationItem.fromJson(Map<dynamic, dynamic> json) {
    final raw =
        json['summary']?.toString().ifEmpty(
          json['content']?.toString() ?? '',
        ) ??
        '';
    return ConversationItem(
      title:
          json['title']?.toString().ifEmpty('Conversation') ?? 'Conversation',
      preview: raw.ifEmpty('No summary available.'),
    );
  }

  final String title;
  final String preview;
}

class SchedulerTask {
  const SchedulerTask({
    required this.id,
    required this.name,
    required this.cronExpression,
    required this.prompt,
    required this.model,
    required this.enabled,
    required this.lastRun,
  });

  factory SchedulerTask.fromJson(Map<dynamic, dynamic> json) {
    final config = json['config'] is Map
        ? Map<String, dynamic>.from(json['config'] as Map)
        : const <String, dynamic>{};
    return SchedulerTask(
      id: _asInt(json['id']),
      name: json['name']?.toString() ?? 'Task',
      cronExpression: json['cronExpression']?.toString() ?? '',
      prompt:
          json['prompt']?.toString().ifEmpty(
            config['prompt']?.toString() ?? '',
          ) ??
          '',
      model:
          json['model']?.toString().ifEmpty(
            config['model']?.toString() ?? '',
          ) ??
          '',
      enabled: json['enabled'] != false,
      lastRun: _parseOptionalTimestamp(json['lastRun']?.toString()),
    );
  }

  final int id;
  final String name;
  final String cronExpression;
  final String prompt;
  final String model;
  final bool enabled;
  final DateTime? lastRun;

  String get lastRunLabel => lastRun == null ? '' : _formatTimestamp(lastRun!);
  bool get hasModelOverride => model.trim().isNotEmpty;
}

class McpServerItem {
  const McpServerItem({
    required this.id,
    required this.name,
    required this.command,
    required this.config,
    required this.enabled,
    required this.status,
    required this.toolCount,
  });

  factory McpServerItem.fromJson(Map<dynamic, dynamic> json) {
    return McpServerItem(
      id: _asInt(json['id']),
      name: json['name']?.toString() ?? 'MCP Server',
      command: json['command']?.toString() ?? '',
      config: json['config'] is Map
          ? Map<String, dynamic>.from(json['config'] as Map)
          : const <String, dynamic>{},
      enabled: json['enabled'] == true,
      status: json['status']?.toString().ifEmpty('stopped') ?? 'stopped',
      toolCount: _asInt(json['toolCount']),
    );
  }

  final int id;
  final String name;
  final String command;
  final Map<String, dynamic> config;
  final bool enabled;
  final String status;
  final int toolCount;

  String get authMethodLabel {
    final auth = _jsonMap(config['auth']);
    final type = auth['type']?.toString().ifEmpty('none') ?? 'none';
    switch (type) {
      case 'bearer':
        return 'Bearer token';
      case 'oauth':
        return 'OAuth';
      default:
        return 'No auth';
    }
  }
}

class ActiveRunState {
  const ActiveRunState({
    required this.runId,
    required this.title,
    required this.model,
    required this.triggerSource,
    required this.phase,
    required this.iteration,
  });

  factory ActiveRunState.pending(String task) {
    return ActiveRunState(
      runId: 'pending',
      title: task,
      model: '',
      triggerSource: 'web',
      phase: 'Queued',
      iteration: 0,
    );
  }

  final String runId;
  final String title;
  final String model;
  final String triggerSource;
  final String phase;
  final int iteration;

  ActiveRunState copyWith({
    String? runId,
    String? title,
    String? model,
    String? triggerSource,
    String? phase,
    int? iteration,
  }) {
    return ActiveRunState(
      runId: runId ?? this.runId,
      title: title ?? this.title,
      model: model ?? this.model,
      triggerSource: triggerSource ?? this.triggerSource,
      phase: phase ?? this.phase,
      iteration: iteration ?? this.iteration,
    );
  }
}

class ToolEventItem {
  const ToolEventItem({
    required this.id,
    required this.toolName,
    required this.type,
    required this.status,
    required this.summary,
  });

  final String id;
  final String toolName;
  final String type;
  final String status;
  final String summary;
}

EdgeInsets _pagePadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 1280) {
    return const EdgeInsets.fromLTRB(36, 28, 36, 36);
  }
  if (width >= 900) {
    return const EdgeInsets.fromLTRB(28, 24, 28, 28);
  }
  return const EdgeInsets.fromLTRB(18, 18, 18, 26);
}

List<AppSection> _mainSections(NeoAgentController controller) {
  return <AppSection>[
    AppSection.chat,
    AppSection.recordings,
    AppSection.runs,
    AppSection.logs,
    AppSection.devices,
    AppSection.scheduler,
    AppSection.skills,
    AppSection.mcp,
    AppSection.memory,
    if (controller.showHealthSection) AppSection.health,
    AppSection.settings,
    AppSection.messaging,
  ];
}

List<Widget> _buildSidebarItems(
  NeoAgentController controller, {
  required ValueChanged<AppSection> onSelect,
}) {
  final List<Widget> widgets = <Widget>[];
  for (final group in SidebarGroup.values) {
    final sections = _mainSections(
      controller,
    ).where((section) => section.group == group).toList();
    if (sections.isEmpty) {
      continue;
    }

    final active = controller.selectedSection.group == group;
    final defaultSection = sections.first;
    final hasChildren = sections.length > 1;

    widgets.add(
      _SidebarButton(
        label: group.label,
        icon: group.icon,
        active: active,
        trailing: hasChildren
            ? Icon(
                active ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: active ? _accent : _textMuted,
              )
            : null,
        onTap: () => onSelect(defaultSection),
      ),
    );

    if (!hasChildren || !active) {
      continue;
    }

    for (final section in sections) {
      widgets.add(
        _SidebarButton(
          label: section.label,
          icon: section.icon,
          active: controller.selectedSection == section,
          indent: 18,
          iconSize: 16,
          fontSize: 12,
          onTap: () => onSelect(section),
        ),
      );
    }
  }
  return widgets;
}

Future<void> _confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
  required Future<void> Function() onConfirm,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: _bgCard,
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
  if (confirmed == true) {
    await onConfirm();
  }
}

String _ensureModelValue(
  String value,
  List<ModelMeta> models, {
  required bool allowAuto,
}) {
  if (allowAuto && value == 'auto') {
    return 'auto';
  }
  for (final model in models) {
    if (model.id == value) {
      return value;
    }
  }
  if (allowAuto) {
    return 'auto';
  }
  return models.isNotEmpty ? models.first.id : value;
}

String _modelLabelForValue(String value, List<ModelMeta> models) {
  if (value == 'auto' || value.trim().isEmpty) {
    return 'Auto';
  }
  for (final model in models) {
    if (model.id == value) {
      return model.label;
    }
  }
  return value;
}

Map<String, dynamic> _jsonMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const <String, dynamic>{};
}

String _normalizeSuggestedWhitelistEntry(String platform, String entry) {
  final trimmed = entry.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  switch (platform) {
    case 'whatsapp':
      return trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    case 'telnyx':
      return trimmed.replaceAll(RegExp(r'[^0-9+]'), '');
    case 'discord':
    case 'telegram':
      return trimmed.replaceAll(
        RegExp(r'[^0-9a-z:_-]', caseSensitive: false),
        '',
      );
    default:
      return trimmed;
  }
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _parseTimestamp(String? raw) {
  if (raw == null || raw.isEmpty) {
    return DateTime.now();
  }
  final normalized = raw.contains('T') ? raw : '${raw.replaceFirst(' ', 'T')}Z';
  return DateTime.tryParse(normalized)?.toLocal() ?? DateTime.now();
}

DateTime? _parseOptionalTimestamp(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return _parseTimestamp(raw);
}

String _formatTimestamp(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$month/$day $hour:$minute';
}

String _formatTimeOnly(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}

String _formatDuration(int milliseconds) {
  final totalSeconds = math.max(0, milliseconds ~/ 1000);
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String _formatElapsed(Duration value) {
  final totalSeconds = math.max(0, value.inSeconds);
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  if (minutes > 0) {
    return '${minutes}m ${seconds}s';
  }
  return '${seconds}s';
}

String _formatNumber(int value) {
  final chars = value.abs().toString().split('').reversed.toList();
  final buffer = StringBuffer();
  for (var i = 0; i < chars.length; i++) {
    if (i > 0 && i % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(chars[i]);
  }
  final formatted = buffer.toString().split('').reversed.join();
  return value < 0 ? '-$formatted' : formatted;
}

String _summarizeToolArgs(dynamic raw) {
  if (raw is Map && raw.isNotEmpty) {
    final first = raw.entries.first;
    return '${first.key}: ${first.value}'.trim();
  }
  return '';
}

String _summarizeToolResult(dynamic raw) {
  if (raw == null) {
    return '';
  }
  if (raw is Map) {
    if (raw['error'] != null) {
      return raw['error'].toString();
    }
    if (raw['message'] != null) {
      return raw['message'].toString();
    }
    if (raw['content'] != null) {
      return raw['content'].toString();
    }
    return raw.entries
        .take(2)
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(' • ');
  }
  final text = raw.toString();
  return text.length > 140 ? '${text.substring(0, 140)}…' : text;
}

String _titleCase(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return '';
  }
  return normalized
      .split(RegExp(r'\s+'))
      .map((part) {
        if (part.isEmpty) {
          return part;
        }
        return '${part[0].toUpperCase()}${part.substring(1)}';
      })
      .join(' ');
}

String _truncateRunText(String value, {int maxLength = 1400}) {
  final trimmed = value.trim();
  if (trimmed.length <= maxLength) {
    return trimmed;
  }
  return '${trimmed.substring(0, maxLength)}\n\n…truncated…';
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}
