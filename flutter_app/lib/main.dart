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

import 'src/android_apk_drop_zone.dart';
import 'src/backend_client.dart';
import 'src/health_bridge.dart';
import 'src/recording_bridge.dart';
import 'wearables/wearable_service.dart';

part 'main_app_shell.dart';
part 'main_models.dart';
part 'main_shared.dart';

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
  wearables,
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
      case AppSection.wearables:
        return 'Wearables';
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
      case AppSection.wearables:
        return Icons.watch_outlined;
    }
  }

  SidebarGroup get group {
    switch (this) {
      case AppSection.chat:
        return SidebarGroup.chat;
      case AppSection.recordings:
      case AppSection.wearables:
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
    if (this == AppSection.wearables) {
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
    required WearableService wearableService,
  }) : _backendClient = backendClient,
       _healthBridge = healthBridge,
       _recordingBridge = recordingBridge,
       _wearableService = wearableService {
    _recordingBridge.onRecordingStopped = _handleRecordingStopped;
    _recordingBridge.addListener(_handleRecordingBridgeChanged);
  }

  final BackendClient _backendClient;
  final HealthBridge _healthBridge;
  final RecordingBridge _recordingBridge;
  final WearableService _wearableService;

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
  bool isSavingReleaseChannel = false;
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

  WearableService get wearableService => _wearableService;

  bool get hasLiveRun => isSendingMessage && activeRun != null;

  String get chatComposerHint => hasLiveRun
      ? 'Send a steering update or next-up note for the current run...'
      : 'Ask a question or start a task...';

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
      final providersFuture = _backendClient.fetchAiProviders(backendUrl);
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
      'heartbeat_enabled': heartbeatEnabled,
      'headless_browser': headlessBrowser,
      'smarter_model_selector': smarterSelector,
      'enabled_models': enabledModels,
      'default_chat_model': defaultChatModel,
      'default_subagent_model': defaultSubagentModel,
      'fallback_model_id': fallbackModel,
      'ai_provider_configs': aiProviderConfigs,
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

  bool get heartbeatEnabled =>
      settings['heartbeat_enabled'] == true ||
      settings['heartbeat_enabled'] == 'true';

  bool get headlessBrowser =>
      settings['headless_browser'] != false &&
      settings['headless_browser'] != 'false';

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

  /// Whether to show the wearables section - currently always enabled but can be
  /// restricted to native platforms if needed (like health section)
  bool get showWearablesSection =>
      true; // Could restrict to !kIsWeb if we want to disable on web like health

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
      if (runId.isNotEmpty && activeRun?.runId == runId) {
        final phase = payload['phase']?.toString().trim() ?? '';
        if (phase.isNotEmpty) {
          activeRun = activeRun!.copyWith(phase: phase);
        }
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
  });

  final _DeviceSurface surface;
  final Map<String, dynamic> browserStatus;
  final Map<String, dynamic> browserPageInfo;
  final Map<String, dynamic> androidRuntime;
  final bool androidOnline;

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
        ? (browserPageInfo['url']?.toString() ?? 'Ready for navigation')
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
        ? 'https://example.com'
        : 'Package name or URL';
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
    required this.wakingUp,
    required this.enabled,
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
                        isLoadingPreview: widget.wakingUp,
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
    required this.isLoadingPreview,
    this.errorMessage,
    required this.onPressed,
  });

  final _DeviceSurface surface;
  final bool enabled;
  final bool busy;
  final bool isLoadingPreview;
  final String? errorMessage;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final label = surface == _DeviceSurface.browser
        ? (busy ? 'Opening Browser...' : 'Wake Browser')
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
            ? 'Browser is sleeping. Press Open to start it.'
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

class WearablesPanel extends StatelessWidget {
  const WearablesPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    final service = controller.wearableService;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
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
                    Row(
                      children: <Widget>[
                        Icon(
                          service.connectedDevice != null
                              ? Icons.watch_outlined
                              : Icons.watch_off_outlined,
                          color: service.connectedDevice != null
                              ? _success
                              : _textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                service.connectedDevice != null
                                    ? 'Connected: ${service.connectedDevice!.name ?? 'Wearable'}'
                                    : 'No device connected',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              if (service.connectedDevice == null)
                                const Text(
                                  'Scan for nearby Bluetooth recording devices.',
                                  style: TextStyle(color: _textSecondary),
                                ),
                            ],
                          ),
                        ),
                        if (service.connectedDevice != null)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              if (service.canRequestOfflineSync)
                                FilledButton.tonalIcon(
                                  onPressed: service.isOfflineSyncRequestInFlight
                                      ? null
                                      : service.requestPacketOfflineSync,
                                  icon: service.isOfflineSyncRequestInFlight
                                      ? const SizedBox.square(
                                          dimension: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.cloud_sync_outlined),
                                  label: Text(
                                    service.isOfflineSyncRequestInFlight
                                        ? 'Requesting sync...'
                                        : 'Sync from device',
                                  ),
                                ),
                              OutlinedButton(
                                onPressed: service.disconnect,
                                child: const Text('Disconnect'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (service.connectedDevice != null && service.canRequestOfflineSync) ...<Widget>[
              const SizedBox(height: 12),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        Color(0xFFF4FAF8),
                        Color(0xFFEAF3FF),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Row(
                          children: <Widget>[
                            Icon(Icons.sync_alt_rounded, color: Color(0xFF14532D)),
                            SizedBox(width: 8),
                            Text(
                              'Packet Offline Sync',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            _SyncStatPill(
                              label: 'Status',
                              value: service.packetSyncStatus,
                              icon: Icons.info_outline,
                            ),
                            _SyncStatPill(
                              label: 'Listed files',
                              value: '${service.packetSyncListedFilesCount}',
                              icon: Icons.queue_music_outlined,
                            ),
                            _SyncStatPill(
                              label: 'Upload requests',
                              value: '${service.packetSyncUploadCommandsSent}',
                              icon: Icons.cloud_upload_outlined,
                            ),
                          ],
                        ),
                        if (service.packetSyncLastControlMessage.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFD1E3F7)),
                            ),
                            child: Text(
                              'Last response: ${service.packetSyncLastControlMessage}',
                              style: const TextStyle(fontSize: 12, color: _textSecondary),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD1E3F7)),
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(Icons.tune_rounded, size: 16, color: _textSecondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    const Text(
                                      'Mode',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      service.packetModeLabel,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Switch(
                                value: service.packetCallModeEnabled,
                                onChanged: service.packetModeSwitchInFlight
                                    ? null
                                    : service.setPacketCallMode,
                              ),
                              Text(
                                service.packetCallModeEnabled ? 'Call' : 'Normal',
                                style: const TextStyle(
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
                const Text(
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
                    icon: const Icon(Icons.search),
                    label: const Text('Scan'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (service.scanResults.isEmpty)
              const _EmptyCard(
                title: 'No devices found',
                subtitle: 'Ensure your wearable is in pairing mode and Bluetooth is enabled.',
              )
            else
              ...service.scanResults.map((device) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.bluetooth),
                      title: Text(device.name ?? 'Unknown Device'),
                      subtitle: Text(device.deviceId),
                      trailing: FilledButton(
                        onPressed: () => service.connect(device),
                        child: const Text('Connect'),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD9E6FA)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: _textSecondary),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              color: _textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
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
            if (session.structuredContent.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _bgSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accent.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.auto_awesome, size: 16, color: _accent),
                        const SizedBox(width: 8),
                        Text('Smart Segments', style: TextStyle(color: _accent, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    if (session.structuredContent['summary'] != null) ...<Widget>[
                      const SizedBox(height: 10),
                      Text('Summary', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _textSecondary)),
                      const SizedBox(height: 4),
                      Text(session.structuredContent['summary'].toString(), style: const TextStyle(height: 1.45)),
                    ],
                    if (session.structuredContent['action_items'] != null && _getStructuredList(session, 'action_items').isNotEmpty) ...<Widget>[
                      const SizedBox(height: 10),
                      Text('Action Items', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _textSecondary)),
                      const SizedBox(height: 4),
                      ..._getStructuredList(session, 'action_items').map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(fontWeight: FontWeight.w700, color: _accent)),
                            Expanded(child: Text(item.toString(), style: const TextStyle(height: 1.35))),
                          ],
                        ),
                      )),
                    ],
                    if (session.structuredContent['events'] != null && _getStructuredList(session, 'events').isNotEmpty) ...<Widget>[
                      const SizedBox(height: 10),
                      Text('Events Mentioned', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _textSecondary)),
                      const SizedBox(height: 4),
                      ..._getStructuredList(session, 'events').map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(fontWeight: FontWeight.w700, color: _accent)),
                            Expanded(child: Text(item.toString(), style: const TextStyle(height: 1.35))),
                          ],
                        ),
                      )),
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

  List<dynamic> _getStructuredList(RecordingSessionItem session, String key) {
    final value = session.structuredContent[key];
    if (value is List) {
      return value;
    }
    return const [];
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
                    style: const TextStyle(fontSize: 11, color: _textSecondary),
                  ),
                  Text(
                    controller.hasLiveRun
                        ? 'Steering mode'
                        : controller.modelIndicator,
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
  late bool _smarterSelector;
  late Set<String> _enabledModels;
  late String _defaultChatModel;
  late String _defaultSubagentModel;
  late String _fallbackModel;
  final Map<String, bool> _providerEnabled = <String, bool>{};
  final Map<String, TextEditingController> _providerApiKeyControllers =
      <String, TextEditingController>{};
  final Map<String, TextEditingController> _providerBaseUrlControllers =
      <String, TextEditingController>{};
  final Set<String> _revealedProviderIds = <String>{};
  final Set<String> _expandedProviderIds = <String>{};

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  @override
  void dispose() {
    for (final controller in _providerApiKeyControllers.values) {
      controller.dispose();
    }
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
    _heartbeatEnabled = controller.heartbeatEnabled;
    _headlessBrowser = controller.headlessBrowser;
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
        _providerApiKeyControllers,
        providerId,
        config.apiKey,
      );
      _syncTextController(
        _providerBaseUrlControllers,
        providerId,
        config.baseUrl,
      );
    }

    _pruneControllers(_providerApiKeyControllers, providerIds);
    _pruneControllers(_providerBaseUrlControllers, providerIds);
    _providerEnabled.removeWhere((id, _) => !providerIds.contains(id));
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
              'Configure providers, routing, runtime behavior, and app updates from one place.',
          trailing: FilledButton.icon(
            onPressed: controller.isSavingSettings
                ? null
                : () => controller.saveSettings(
                    heartbeatEnabled: _heartbeatEnabled,
                    headlessBrowser: _headlessBrowser,
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
                const _SectionTitle('AI Providers'),
                const SizedBox(height: 14),
                if (controller.aiProviders.isEmpty)
                  const Text(
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
                              apiKeyController:
                                  _providerApiKeyControllers[provider.id]!,
                              baseUrlController:
                                  _providerBaseUrlControllers[provider.id]!,
                              revealSecret: _revealedProviderIds.contains(
                                provider.id,
                              ),
                              expanded: _expandedProviderIds.contains(
                                provider.id,
                              ),
                              onRevealToggle: () {
                                setState(() {
                                  if (_revealedProviderIds.contains(
                                    provider.id,
                                  )) {
                                    _revealedProviderIds.remove(provider.id);
                                  } else {
                                    _revealedProviderIds.add(provider.id);
                                  }
                                });
                              },
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
                      ? 'Enable a provider above to unlock model routing.'
                      : '$enabledSmartModels models are currently eligible for smart routing.',
                  style: const TextStyle(color: _textSecondary),
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 780;
                    final channelPicker = DropdownButtonFormField<String>(
                      value: controller.updateStatus.releaseChannel,
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
                                unawaited(controller.setReleaseChannel(value));
                              }
                            },
                    );

                    final channelHelper = Text(
                      controller.updateStatus.releaseChannel == 'beta'
                          ? 'Beta tracks the `beta` branch and npm `beta` releases.'
                          : 'Stable tracks the `main` branch and npm `latest` releases.',
                      style: const TextStyle(color: _textSecondary),
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
                    const Expanded(child: _SectionTitle('App Update')),
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
          'apiKey': _providerApiKeyControllers[providerId]?.text.trim() ?? '',
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
    required this.apiKeyController,
    required this.baseUrlController,
    required this.revealSecret,
    required this.onRevealToggle,
    required this.onEnabledChanged,
    required this.onExpandToggle,
  });

  final AiProviderMeta provider;
  final bool enabled;
  final bool expanded;
  final List<ModelMeta> models;
  final TextEditingController apiKeyController;
  final TextEditingController baseUrlController;
  final bool revealSecret;
  final VoidCallback onRevealToggle;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onExpandToggle;

  @override
  Widget build(BuildContext context) {
    final availableCount = models.where((model) => model.available).length;
    final hasAdvancedFields =
        provider.supportsApiKey || provider.supportsBaseUrl;
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textSecondary,
                        height: 1.4,
                      ),
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
                            style: const TextStyle(fontSize: 12),
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
              if (provider.usesEnvironmentApiKey)
                const _MetaPill(
                  label: 'Env fallback active',
                  icon: Icons.lock_outline,
                ),
              if (provider.hasStoredApiKey)
                const _MetaPill(
                  label: 'Key saved in UI',
                  icon: Icons.key_outlined,
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
                    style: const TextStyle(color: _textSecondary, height: 1.35),
                  ),
                ),
                const SizedBox(width: 12),
                Switch(value: enabled, onChanged: onEnabledChanged),
              ],
            ),
          ),
          if (expanded) ...<Widget>[
            const SizedBox(height: 14),
            if (provider.supportsApiKey) ...<Widget>[
              TextField(
                controller: apiKeyController,
                obscureText: !revealSecret,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  hintText: provider.hasEnvironmentApiKey
                      ? 'Leave blank to keep server env fallback'
                      : 'Paste API key',
                  helperText: provider.hasEnvironmentApiKey
                      ? 'Blank keeps the current server environment fallback.'
                      : 'Stored on this NeoAgent server for your account.',
                  suffixIcon: IconButton(
                    onPressed: onRevealToggle,
                    icon: Icon(
                      revealSecret ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
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
              const Text(
                'Models',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
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
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
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
                'hasStoredApiKey': provider.hasStoredApiKey,
                'hasEnvironmentApiKey': provider.hasEnvironmentApiKey,
              },
            )
            .toList(),
      },
      'runtime': <String, dynamic>{
        'heartbeatEnabled': controller.heartbeatEnabled,
        'headlessBrowser': controller.headlessBrowser,
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
        'versionBefore': controller.updateStatus.versionBefore,
        'versionAfter': controller.updateStatus.versionAfter,
        'installedVersion': controller.updateStatus.installedVersion,
        'backendVersion': controller.updateStatus.backendVersion,
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
                icon: const Icon(Icons.bug_report_outlined),
                label: const Text('Copy debug info'),
              ),
              OutlinedButton.icon(
                onPressed: widget.controller.logs.isEmpty ? null : _copyLogs,
                icon: const Icon(Icons.copy_all_outlined),
                label: const Text('Copy logs'),
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
