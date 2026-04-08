import 'dart:convert';
import 'dart:typed_data';

import 'diagnostics_logger.dart';
import 'network/app_http_client.dart';
import 'network/app_http_client_factory.dart';

class BackendClient {
  BackendClient({AppHttpClient? httpClient})
    : _httpClient = httpClient ?? createAppHttpClient();

  final AppHttpClient _httpClient;

  void _log(
    String event, {
    Map<String, Object?> data = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    AppDiagnostics.log(
      'backend.client',
      event,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  String? get sessionCookie => _httpClient.sessionCookie;

  String _agentQuery(String? agentId) {
    if (agentId == null || agentId.trim().isEmpty) {
      return '';
    }
    return 'agentId=${Uri.encodeQueryComponent(agentId.trim())}';
  }

  String _withAgentQuery(String path, String? agentId) {
    final query = _agentQuery(agentId);
    if (query.isEmpty) return path;
    return path.contains('?') ? '$path&$query' : '$path?$query';
  }

  Future<Map<String, dynamic>> getAuthStatus(String baseUrl) async {
    return getMap(baseUrl, '/api/auth/status', allowUnauthorized: true);
  }

  Future<Map<String, dynamic>?> getCurrentUser(String baseUrl) async {
    final response = await _request(
      'GET',
      _resolveUri(baseUrl, '/api/auth/me'),
      allowUnauthorized: true,
    );
    if (response.statusCode == 401) {
      return null;
    }
    _throwIfError(response);
    return _asMap(_decodeJson(response.body));
  }

  Future<Map<String, dynamic>> login({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    return postMap(baseUrl, '/api/auth/login', <String, dynamic>{
      'username': username,
      'password': password,
    });
  }

  Future<Map<String, dynamic>> register({
    required String baseUrl,
    required String username,
    required String email,
    required String password,
  }) async {
    return postMap(baseUrl, '/api/auth/register', <String, dynamic>{
      'username': username,
      'email': email,
      'password': password,
    });
  }

  Future<Map<String, dynamic>> beginProviderAuth({
    required String baseUrl,
    required String provider,
    required String mode,
  }) async {
    return postMap(baseUrl, '/api/auth/providers/$provider/begin', <String, dynamic>{
      'mode': mode,
    }, allowUnauthorized: mode != 'link');
  }

  Future<Map<String, dynamic>> completeProviderAuth({
    required String baseUrl,
    required String state,
  }) async {
    return getMap(
      baseUrl,
      '/api/auth/providers/complete?state=${Uri.encodeQueryComponent(state)}',
      allowUnauthorized: true,
    );
  }

  Future<Map<String, dynamic>> completeTwoFactorLogin({
    required String baseUrl,
    required String code,
  }) async {
    return postMap(baseUrl, '/api/auth/login/2fa', <String, dynamic>{
      'code': code,
    });
  }

  Future<Map<String, dynamic>> requestPasswordReset({
    required String baseUrl,
    required String account,
  }) async {
    return postMap(baseUrl, '/api/auth/password/forgot', <String, dynamic>{
      'account': account,
    }, allowUnauthorized: true);
  }

  Future<void> logout(String baseUrl) async {
    try {
      await postMap(
        baseUrl,
        '/api/auth/logout',
        const <String, dynamic>{},
        allowUnauthorized: true,
      );
    } finally {
      _httpClient.clearSession();
    }
  }

  Future<Map<String, dynamic>> fetchAgentProfiles(String baseUrl) async {
    return getMap(baseUrl, '/api/agent-profiles');
  }

  Future<Map<String, dynamic>> fetchAccount(String baseUrl) async {
    return getMap(baseUrl, '/api/account');
  }

  Future<Map<String, dynamic>> updateAccountEmail({
    required String baseUrl,
    required String email,
    required String currentPassword,
  }) async {
    return putMap(baseUrl, '/api/account/email', <String, dynamic>{
      'email': email,
      'currentPassword': currentPassword,
    });
  }

  Future<Map<String, dynamic>> updateAccountPassword({
    required String baseUrl,
    required String currentPassword,
    required String newPassword,
  }) async {
    return putMap(baseUrl, '/api/account/password', <String, dynamic>{
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  Future<Map<String, dynamic>> beginTwoFactorSetup({
    required String baseUrl,
    required String currentPassword,
  }) async {
    return postMap(baseUrl, '/api/account/2fa/setup', <String, dynamic>{
      'currentPassword': currentPassword,
    });
  }

  Future<Map<String, dynamic>> enableTwoFactor({
    required String baseUrl,
    required String code,
  }) async {
    return postMap(baseUrl, '/api/account/2fa/enable', <String, dynamic>{
      'code': code,
    });
  }

  Future<Map<String, dynamic>> disableTwoFactor({
    required String baseUrl,
    required String currentPassword,
    required String code,
  }) async {
    return postMap(baseUrl, '/api/account/2fa/disable', <String, dynamic>{
      'currentPassword': currentPassword,
      'code': code,
    });
  }

  Future<Map<String, dynamic>> regenerateRecoveryCodes({
    required String baseUrl,
    required String currentPassword,
    required String code,
  }) async {
    return postMap(
      baseUrl,
      '/api/account/2fa/recovery-codes',
      <String, dynamic>{'currentPassword': currentPassword, 'code': code},
    );
  }

  Future<Map<String, dynamic>> fetchAccountSessions(String baseUrl) async {
    return getMap(baseUrl, '/api/account/sessions');
  }

  Future<Map<String, dynamic>> unlinkAccountProvider({
    required String baseUrl,
    required int providerLinkId,
  }) async {
    return deleteMap(baseUrl, '/api/account/providers/$providerLinkId');
  }

  Future<Map<String, dynamic>> revokeAccountSession(
    String baseUrl,
    int sessionId,
  ) async {
    return deleteMap(baseUrl, '/api/account/sessions/$sessionId');
  }

  Future<Map<String, dynamic>> createAgentProfile(
    String baseUrl,
    Map<String, dynamic> payload,
  ) async {
    return postMap(baseUrl, '/api/agent-profiles', payload);
  }

  Future<Map<String, dynamic>> updateAgentProfile(
    String baseUrl,
    String id,
    Map<String, dynamic> payload,
  ) async {
    return putMap(baseUrl, '/api/agent-profiles/$id', payload);
  }

  Future<Map<String, dynamic>> setDefaultAgentProfile(
    String baseUrl,
    String id,
  ) async {
    return postMap(baseUrl, '/api/agent-profiles/$id/default', const {});
  }

  Future<void> archiveAgentProfile(String baseUrl, String id) async {
    await deleteMap(baseUrl, '/api/agent-profiles/$id');
  }

  Future<Map<String, dynamic>> fetchChatHistory(
    String baseUrl, {
    String? agentId,
  }) async {
    return getMap(
      baseUrl,
      _withAgentQuery('/api/agents/chat-history?limit=120', agentId),
    );
  }

  Future<Map<String, dynamic>> runTask(
    String baseUrl,
    String task, {
    String? agentId,
  }) async {
    return postMap(baseUrl, '/api/agents', <String, dynamic>{
      'task': task,
      'options': <String, dynamic>{
        if (agentId != null && agentId.trim().isNotEmpty)
          'agentId': agentId.trim(),
      },
    });
  }

  Future<Map<String, dynamic>> fetchSettings(
    String baseUrl, {
    String? agentId,
  }) async {
    return getMap(baseUrl, _withAgentQuery('/api/settings', agentId));
  }

  Future<Map<String, dynamic>> fetchSupportedModels(
    String baseUrl, {
    String? agentId,
  }) async {
    return getMap(
      baseUrl,
      _withAgentQuery('/api/settings/meta/models', agentId),
    );
  }

  Future<Map<String, dynamic>> fetchAiProviders(
    String baseUrl, {
    String? agentId,
  }) async {
    return getMap(
      baseUrl,
      _withAgentQuery('/api/settings/meta/ai-providers', agentId),
    );
  }

  Future<Map<String, dynamic>> saveSettings(
    String baseUrl,
    Map<String, dynamic> payload, {
    String? agentId,
  }) async {
    return putMap(baseUrl, '/api/settings', <String, dynamic>{
      ...payload,
      if (agentId != null && agentId.isNotEmpty) 'agentId': agentId,
    });
  }

  Future<Map<String, dynamic>> fetchTokenUsageSummary(
    String baseUrl, {
    String? agentId,
  }) async {
    return getMap(
      baseUrl,
      _withAgentQuery('/api/settings/token-usage/summary', agentId),
    );
  }

  Future<Map<String, dynamic>> fetchUpdateStatus(String baseUrl) async {
    return getMap(baseUrl, '/api/settings/update/status');
  }

  Future<Map<String, dynamic>> triggerUpdate(String baseUrl) async {
    return postMap(baseUrl, '/api/settings/update', const <String, dynamic>{});
  }

  Future<Map<String, dynamic>> setReleaseChannel(
    String baseUrl,
    String channel,
  ) async {
    return putMap(baseUrl, '/api/settings/update/channel', <String, dynamic>{
      'channel': channel,
    });
  }

  Future<Map<String, dynamic>> fetchRuns(
    String baseUrl, {
    String? agentId,
  }) async {
    return getMap(baseUrl, _withAgentQuery('/api/agents?limit=20', agentId));
  }

  Future<Map<String, dynamic>> fetchRunSteps(
    String baseUrl,
    String runId,
  ) async {
    return getMap(baseUrl, '/api/agents/$runId/steps');
  }

  Future<void> deleteRun(String baseUrl, String runId) async {
    await deleteMap(baseUrl, '/api/agents/$runId');
  }

  Future<Map<String, dynamic>> fetchVersion(String baseUrl) async {
    return getMap(baseUrl, '/api/version');
  }

  Future<Map<String, dynamic>> fetchBrowserStatus(String baseUrl) async {
    return getMap(baseUrl, '/api/browser/status');
  }

  Future<Map<String, dynamic>> fetchBrowserExtensionStatus(
    String baseUrl,
  ) async {
    return getMap(baseUrl, '/api/browser-extension/status');
  }

  Future<Map<String, dynamic>> launchBrowser(
    String baseUrl, {
    Map<String, dynamic>? payload,
  }) async {
    return postMap(
      baseUrl,
      '/api/browser/launch',
      payload ?? const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> navigateBrowser(
    String baseUrl, {
    required String url,
    String? waitFor,
  }) async {
    return postMap(baseUrl, '/api/browser/navigate', <String, dynamic>{
      'url': url,
      if (waitFor != null && waitFor.isNotEmpty) 'waitFor': waitFor,
    });
  }

  Future<Map<String, dynamic>> clickBrowser(
    String baseUrl, {
    String? selector,
    String? text,
    bool screenshot = true,
  }) async {
    return postMap(baseUrl, '/api/browser/click', <String, dynamic>{
      if (selector != null && selector.isNotEmpty) 'selector': selector,
      if (text != null && text.isNotEmpty) 'text': text,
      'screenshot': screenshot,
    });
  }

  Future<Map<String, dynamic>> clickBrowserPoint(
    String baseUrl, {
    required int x,
    required int y,
    bool screenshot = true,
  }) async {
    return postMap(baseUrl, '/api/browser/click-point', <String, dynamic>{
      'x': x,
      'y': y,
      'screenshot': screenshot,
    });
  }

  Future<Map<String, dynamic>> fillBrowser(
    String baseUrl, {
    required String selector,
    required String value,
    bool clear = true,
    bool pressEnter = false,
    bool screenshot = true,
  }) async {
    return postMap(baseUrl, '/api/browser/fill', <String, dynamic>{
      'selector': selector,
      'value': value,
      'clear': clear,
      'pressEnter': pressEnter,
      'screenshot': screenshot,
    });
  }

  Future<Map<String, dynamic>> typeBrowserText(
    String baseUrl, {
    required String text,
    bool pressEnter = false,
    bool screenshot = true,
  }) async {
    return postMap(baseUrl, '/api/browser/type-text', <String, dynamic>{
      'text': text,
      'pressEnter': pressEnter,
      'screenshot': screenshot,
    });
  }

  Future<Map<String, dynamic>> pressBrowserKey(
    String baseUrl, {
    required String key,
    bool screenshot = true,
  }) async {
    return postMap(baseUrl, '/api/browser/press-key', <String, dynamic>{
      'key': key,
      'screenshot': screenshot,
    });
  }

  Future<Map<String, dynamic>> scrollBrowser(
    String baseUrl, {
    int deltaX = 0,
    int deltaY = 0,
    bool screenshot = true,
  }) async {
    return postMap(baseUrl, '/api/browser/scroll', <String, dynamic>{
      'deltaX': deltaX,
      'deltaY': deltaY,
      'screenshot': screenshot,
    });
  }

  Future<Map<String, dynamic>> screenshotBrowser(
    String baseUrl, {
    bool fullPage = false,
    String? selector,
  }) async {
    return postMap(baseUrl, '/api/browser/screenshot', <String, dynamic>{
      'fullPage': fullPage,
      if (selector != null && selector.isNotEmpty) 'selector': selector,
    });
  }

  Future<Map<String, dynamic>> closeBrowser(String baseUrl) async {
    return postMap(baseUrl, '/api/browser/close', const <String, dynamic>{});
  }

  Future<Map<String, dynamic>> fetchAndroidStatus(String baseUrl) async {
    return getMap(baseUrl, '/api/android/status');
  }

  Future<Map<String, dynamic>> fetchAndroidApps(
    String baseUrl, {
    bool includeSystem = false,
  }) async {
    return getMap(baseUrl, '/api/android/apps?includeSystem=$includeSystem');
  }

  Future<Map<String, dynamic>> startAndroidEmulator(
    String baseUrl, {
    bool headless = true,
    int timeoutMs = 240000,
  }) async {
    return postMap(baseUrl, '/api/android/start', <String, dynamic>{
      'headless': headless,
      'timeoutMs': timeoutMs,
    });
  }

  Future<Map<String, dynamic>> stopAndroidEmulator(String baseUrl) async {
    return postMap(baseUrl, '/api/android/stop', const <String, dynamic>{});
  }

  Future<Map<String, dynamic>> screenshotAndroid(String baseUrl) async {
    return postMap(
      baseUrl,
      '/api/android/screenshot',
      const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> observeAndroid(
    String baseUrl, {
    bool includeNodes = true,
  }) async {
    return postMap(baseUrl, '/api/android/observe', <String, dynamic>{
      'includeNodes': includeNodes,
    });
  }

  Future<Map<String, dynamic>> dumpAndroidUi(
    String baseUrl, {
    bool includeNodes = true,
  }) async {
    return postMap(baseUrl, '/api/android/ui-dump', <String, dynamic>{
      'includeNodes': includeNodes,
    });
  }

  Future<Map<String, dynamic>> openAndroidApp(
    String baseUrl, {
    required String packageName,
    String? activity,
    bool screenshot = true,
    bool uiDump = true,
    bool includeNodes = true,
  }) async {
    return postMap(baseUrl, '/api/android/open-app', <String, dynamic>{
      'packageName': packageName,
      if (activity != null && activity.isNotEmpty) 'activity': activity,
      'screenshot': screenshot,
      'uiDump': uiDump,
      'includeNodes': includeNodes,
    });
  }

  Future<Map<String, dynamic>> openAndroidIntent(
    String baseUrl, {
    String? action,
    String? dataUri,
    String? packageName,
    String? component,
    bool screenshot = true,
    bool uiDump = true,
    bool includeNodes = true,
  }) async {
    return postMap(baseUrl, '/api/android/open-intent', <String, dynamic>{
      if (action != null && action.isNotEmpty) 'action': action,
      if (dataUri != null && dataUri.isNotEmpty) 'dataUri': dataUri,
      if (packageName != null && packageName.isNotEmpty)
        'packageName': packageName,
      if (component != null && component.isNotEmpty) 'component': component,
      'screenshot': screenshot,
      'uiDump': uiDump,
      'includeNodes': includeNodes,
    });
  }

  Future<Map<String, dynamic>> tapAndroid(
    String baseUrl,
    Map<String, dynamic> payload,
  ) async {
    return postMap(baseUrl, '/api/android/tap', payload);
  }

  Future<Map<String, dynamic>> typeAndroid(
    String baseUrl,
    Map<String, dynamic> payload,
  ) async {
    return postMap(baseUrl, '/api/android/type', payload);
  }

  Future<Map<String, dynamic>> swipeAndroid(
    String baseUrl,
    Map<String, dynamic> payload,
  ) async {
    return postMap(baseUrl, '/api/android/swipe', payload);
  }

  Future<Map<String, dynamic>> pressAndroidKey(
    String baseUrl, {
    required String key,
    bool screenshot = true,
    bool uiDump = true,
    bool includeNodes = true,
  }) async {
    return postMap(baseUrl, '/api/android/press-key', <String, dynamic>{
      'key': key,
      'screenshot': screenshot,
      'uiDump': uiDump,
      'includeNodes': includeNodes,
    });
  }

  Future<Map<String, dynamic>> waitForAndroid(
    String baseUrl,
    Map<String, dynamic> payload,
  ) async {
    return postMap(baseUrl, '/api/android/wait-for', payload);
  }

  Future<Map<String, dynamic>> installAndroidApk(
    String baseUrl, {
    required String filename,
    required Uint8List bytes,
  }) async {
    final response = await _httpClient.postMultipart(
      _resolveUri(baseUrl, '/api/android/install-apk'),
      fieldName: 'apk',
      filename: filename,
      bytes: bytes,
    );
    _throwIfError(response);
    return _asMap(_decodeJson(response.body));
  }

  Future<Map<String, dynamic>> fetchHealthStatus(String baseUrl) async {
    return getMap(baseUrl, '/api/mobile/health/status');
  }

  Future<Map<String, dynamic>> uploadHealthBatch(
    String baseUrl,
    Map<String, dynamic> payload,
  ) async {
    return postMap(baseUrl, '/api/mobile/health/sync', payload);
  }

  Future<List<Map<String, dynamic>>> fetchSkills(String baseUrl) async {
    return getList(baseUrl, '/api/skills');
  }

  Future<List<Map<String, dynamic>>> fetchSkillStore(String baseUrl) async {
    return getList(baseUrl, '/api/store');
  }

  Future<List<Map<String, dynamic>>> fetchOfficialIntegrations(
    String baseUrl, {
    String? agentId,
  }) async {
    return getList(baseUrl, _withAgentQuery('/api/integrations', agentId));
  }

  Future<Map<String, dynamic>> fetchSkillDocument(
    String baseUrl,
    String name,
  ) async {
    return getMap(baseUrl, '/api/skills/$name');
  }

  Future<Map<String, dynamic>> saveSkillContent(
    String baseUrl, {
    required String name,
    required String content,
  }) async {
    return putMap(baseUrl, '/api/skills/$name', <String, dynamic>{
      'content': content,
    });
  }

  Future<Map<String, dynamic>> setSkillEnabled(
    String baseUrl, {
    required String name,
    required bool enabled,
  }) async {
    return putMap(baseUrl, '/api/skills/$name', <String, dynamic>{
      'enabled': enabled,
    });
  }

  Future<Map<String, dynamic>> createSkill(
    String baseUrl, {
    required String filename,
    required String content,
  }) async {
    return postMap(baseUrl, '/api/skills', <String, dynamic>{
      'filename': filename,
      'content': content,
    });
  }

  Future<void> deleteSkill(String baseUrl, String name) async {
    await deleteMap(baseUrl, '/api/skills/$name');
  }

  Future<Map<String, dynamic>> installStoreSkill(
    String baseUrl,
    String id,
  ) async {
    return postMap(
      baseUrl,
      '/api/store/$id/install',
      const <String, dynamic>{},
    );
  }

  Future<void> uninstallStoreSkill(String baseUrl, String id) async {
    await deleteMap(baseUrl, '/api/store/$id/uninstall');
  }

  Future<Map<String, dynamic>> connectOfficialIntegration(
    String baseUrl,
    String providerId, {
    required String appId,
    String? agentId,
  }) async {
    return postMap(
      baseUrl,
      '/api/integrations/$providerId/connect',
      <String, dynamic>{
        'appId': appId,
        if (agentId != null && agentId.isNotEmpty) 'agentId': agentId,
      },
    );
  }

  Future<Map<String, dynamic>> disconnectOfficialIntegration(
    String baseUrl,
    String providerId, {
    required int connectionId,
    String? agentId,
  }) async {
    return postMap(
      baseUrl,
      '/api/integrations/$providerId/disconnect',
      <String, dynamic>{
        'connectionId': connectionId,
        if (agentId != null && agentId.isNotEmpty) 'agentId': agentId,
      },
    );
  }

  Future<Map<String, dynamic>> fetchMessagingStatus(
    String baseUrl, {
    String? agentId,
  }) async {
    return getMap(baseUrl, _withAgentQuery('/api/messaging/status', agentId));
  }

  Future<List<Map<String, dynamic>>> fetchMessagingMessages(
    String baseUrl, {
    String? platform,
    String? chatId,
    String? agentId,
  }) async {
    final params = <String>[
      if (platform != null && platform.isNotEmpty)
        'platform=${Uri.encodeQueryComponent(platform)}',
      if (chatId != null && chatId.isNotEmpty)
        'chatId=${Uri.encodeQueryComponent(chatId)}',
      if (agentId != null && agentId.isNotEmpty)
        'agentId=${Uri.encodeQueryComponent(agentId)}',
      'limit=60',
    ];
    return getList(baseUrl, '/api/messaging/messages?${params.join('&')}');
  }

  Future<Map<String, dynamic>> connectMessagingPlatform(
    String baseUrl, {
    required String platform,
    Map<String, dynamic>? config,
    String? agentId,
  }) async {
    return postMap(baseUrl, '/api/messaging/connect', <String, dynamic>{
      'platform': platform,
      'config': config ?? const <String, dynamic>{},
      if (agentId != null && agentId.isNotEmpty) 'agentId': agentId,
    });
  }

  Future<Map<String, dynamic>> disconnectMessagingPlatform(
    String baseUrl, {
    required String platform,
    String? agentId,
  }) async {
    return postMap(baseUrl, '/api/messaging/disconnect', <String, dynamic>{
      'platform': platform,
      if (agentId != null && agentId.isNotEmpty) 'agentId': agentId,
    });
  }

  Future<Map<String, dynamic>> logoutMessagingPlatform(
    String baseUrl, {
    required String platform,
    String? agentId,
  }) async {
    return postMap(baseUrl, '/api/messaging/logout', <String, dynamic>{
      'platform': platform,
      if (agentId != null && agentId.isNotEmpty) 'agentId': agentId,
    });
  }

  Future<Map<String, dynamic>> saveTelnyxWhitelist(
    String baseUrl,
    List<String> numbers, {
    String? agentId,
  }) async {
    return putMap(baseUrl, '/api/messaging/telnyx/whitelist', <String, dynamic>{
      'numbers': numbers,
      if (agentId != null && agentId.isNotEmpty) 'agentId': agentId,
    });
  }

  Future<Map<String, dynamic>> saveTelnyxVoiceSecret(
    String baseUrl,
    String secret, {
    String? agentId,
  }) async {
    return putMap(
      baseUrl,
      '/api/messaging/telnyx/voice-secret',
      <String, dynamic>{
        'secret': secret,
        if (agentId != null && agentId.isNotEmpty) 'agentId': agentId,
      },
    );
  }

  Future<Map<String, dynamic>> saveDiscordWhitelist(
    String baseUrl,
    List<String> ids, {
    String? agentId,
  }) async {
    return putMap(
      baseUrl,
      '/api/messaging/discord/whitelist',
      <String, dynamic>{
        'ids': ids,
        if (agentId != null && agentId.isNotEmpty) 'agentId': agentId,
      },
    );
  }

  Future<Map<String, dynamic>> saveTelegramWhitelist(
    String baseUrl,
    List<String> ids, {
    String? agentId,
  }) async {
    return putMap(
      baseUrl,
      '/api/messaging/telegram/whitelist',
      <String, dynamic>{
        'ids': ids,
        if (agentId != null && agentId.isNotEmpty) 'agentId': agentId,
      },
    );
  }

  Future<Map<String, dynamic>> saveMessagingWhitelist(
    String baseUrl, {
    required String platform,
    required List<String> ids,
    String? agentId,
  }) async {
    return putMap(
      baseUrl,
      '/api/messaging/$platform/whitelist',
      <String, dynamic>{
        'ids': ids,
        if (agentId != null && agentId.isNotEmpty) 'agentId': agentId,
      },
    );
  }

  Future<Map<String, dynamic>> fetchMemoryOverview(
    String baseUrl, {
    String? agentId,
  }) async {
    return getMap(baseUrl, _withAgentQuery('/api/memory', agentId));
  }

  Future<List<Map<String, dynamic>>> fetchMemories(
    String baseUrl, {
    String? category,
    String? agentId,
  }) async {
    final params = <String>[
      if (category != null) 'category=${Uri.encodeQueryComponent(category)}',
      if (agentId != null && agentId.isNotEmpty)
        'agentId=${Uri.encodeQueryComponent(agentId)}',
    ];
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    return getList(baseUrl, '/api/memory/memories$query');
  }

  Future<List<Map<String, dynamic>>> recallMemories(
    String baseUrl,
    String query, {
    String? agentId,
  }) async {
    return postList(baseUrl, '/api/memory/memories/recall', <String, dynamic>{
      'query': query,
      'limit': 8,
      if (agentId != null && agentId.isNotEmpty) 'agentId': agentId,
    });
  }

  Future<Map<String, dynamic>> createMemory(
    String baseUrl, {
    required String content,
    required String category,
    required int importance,
    String? agentId,
  }) async {
    return postMap(baseUrl, '/api/memory/memories', <String, dynamic>{
      'content': content,
      'category': category,
      'importance': importance,
      if (agentId != null && agentId.isNotEmpty) 'agentId': agentId,
    });
  }

  Future<void> deleteMemory(String baseUrl, String id) async {
    await deleteMap(baseUrl, '/api/memory/memories/$id');
  }

  Future<Map<String, dynamic>> deleteMemories(
    String baseUrl,
    List<String> ids, {
    String? agentId,
  }) async {
    return postMap(
      baseUrl,
      '/api/memory/memories/bulk-delete',
      <String, dynamic>{
        'ids': ids,
        if (agentId != null && agentId.isNotEmpty) 'agentId': agentId,
      },
    );
  }

  Future<Map<String, dynamic>> archiveMemories(
    String baseUrl,
    List<String> ids, {
    bool archived = true,
    String? agentId,
  }) async {
    return postMap(
      baseUrl,
      '/api/memory/memories/bulk-archive',
      <String, dynamic>{
        'ids': ids,
        'archived': archived,
        if (agentId != null && agentId.isNotEmpty) 'agentId': agentId,
      },
    );
  }

  Future<Map<String, dynamic>> fetchCoreMemory(
    String baseUrl, {
    String? agentId,
  }) async {
    return getMap(baseUrl, _withAgentQuery('/api/memory/core', agentId));
  }

  Future<Map<String, dynamic>> updateCoreMemory(
    String baseUrl, {
    required String key,
    required String value,
    String? agentId,
  }) async {
    return putMap(baseUrl, '/api/memory/core/$key', <String, dynamic>{
      'value': value,
      if (agentId != null && agentId.isNotEmpty) 'agentId': agentId,
    });
  }

  Future<void> deleteCoreMemory(
    String baseUrl,
    String key, {
    String? agentId,
  }) async {
    await deleteMap(baseUrl, _withAgentQuery('/api/memory/core/$key', agentId));
  }

  Future<List<Map<String, dynamic>>> fetchConversations(
    String baseUrl, {
    String? agentId,
  }) async {
    return getList(
      baseUrl,
      _withAgentQuery('/api/memory/conversations?limit=12', agentId),
    );
  }

  Future<List<Map<String, dynamic>>> fetchSchedulerTasks(String baseUrl) async {
    return getList(baseUrl, '/api/scheduler');
  }

  Future<Map<String, dynamic>> saveSchedulerTask(
    String baseUrl, {
    int? id,
    required String name,
    required String cronExpression,
    required String prompt,
    String? model,
    bool enabled = true,
    String? agentId,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'cronExpression': cronExpression,
      'prompt': prompt,
      'model': model,
      'enabled': enabled,
      if (agentId != null && agentId.isNotEmpty) 'agentId': agentId,
    };
    if (id == null) {
      return postMap(baseUrl, '/api/scheduler', payload);
    }
    return putMap(baseUrl, '/api/scheduler/$id', payload);
  }

  Future<Map<String, dynamic>> updateSchedulerTask(
    String baseUrl,
    int id,
    Map<String, dynamic> payload,
  ) async {
    return putMap(baseUrl, '/api/scheduler/$id', payload);
  }

  Future<Map<String, dynamic>> runSchedulerTask(String baseUrl, int id) async {
    return postMap(
      baseUrl,
      '/api/scheduler/$id/run',
      const <String, dynamic>{},
    );
  }

  Future<void> deleteSchedulerTask(String baseUrl, int id) async {
    await deleteMap(baseUrl, '/api/scheduler/$id');
  }

  Future<List<Map<String, dynamic>>> fetchMcpServers(String baseUrl) async {
    return getList(baseUrl, '/api/mcp');
  }

  Future<List<Map<String, dynamic>>> fetchRecordingSessions(
    String baseUrl, {
    int limit = 24,
  }) async {
    _log(
      'recording.fetch_sessions.request',
      data: <String, Object?>{'limit': limit},
    );
    return getList(baseUrl, '/api/recordings?limit=$limit');
  }

  Future<Map<String, dynamic>> fetchRecordingSession(
    String baseUrl,
    String sessionId,
  ) async {
    _log(
      'recording.fetch_session.request',
      data: <String, Object?>{'sessionId': sessionId},
    );
    return getMap(baseUrl, '/api/recordings/$sessionId');
  }

  Future<Map<String, dynamic>> createRecordingSession(
    String baseUrl,
    Map<String, dynamic> payload,
  ) async {
    _log(
      'recording.create.request',
      data: <String, Object?>{
        'platform': payload['platform']?.toString(),
        'sourceCount': (payload['sources'] as List?)?.length ?? 0,
      },
    );
    return postMap(baseUrl, '/api/recordings', payload);
  }

  Future<Map<String, dynamic>> finalizeRecordingSession(
    String baseUrl,
    String sessionId, {
    String stopReason = 'stopped',
  }) async {
    _log(
      'recording.finalize.request',
      data: <String, Object?>{'sessionId': sessionId, 'stopReason': stopReason},
    );
    return postMap(
      baseUrl,
      '/api/recordings/$sessionId/finalize',
      <String, dynamic>{'stopReason': stopReason},
    );
  }

  Future<Map<String, dynamic>> retryRecordingSession(
    String baseUrl,
    String sessionId,
  ) async {
    return postMap(
      baseUrl,
      '/api/recordings/$sessionId/retry',
      const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> deleteRecordingTranscriptSegment(
    String baseUrl,
    String sessionId,
    int segmentId,
  ) async {
    return deleteMap(baseUrl, '/api/recordings/$sessionId/segments/$segmentId');
  }

  Future<void> deleteRecordingSession(String baseUrl, String sessionId) async {
    await deleteMap(baseUrl, '/api/recordings/$sessionId');
  }

  Future<Map<String, dynamic>> streamWearableData(
    String baseUrl,
    String macAddress,
    String characteristicUuid,
    Uint8List data,
  ) async {
    _log(
      'wearable.stream.request',
      data: <String, Object?>{
        'macAddress': macAddress,
        'characteristicUuid': characteristicUuid,
        'size': data.length,
      },
    );
    final response = await _httpClient.post(
      _resolveUri(baseUrl, '/api/wearables/$macAddress/stream'),
      headers: <String, String>{
        'x-characteristic-uuid': characteristicUuid,
        'Content-Type': 'application/octet-stream',
      },
      body: data,
    );
    _throwIfError(response);
    final decoded = _asMap(_decodeJson(response.body));
    if (decoded['success'] != true) {
      throw StateError('Wearable stream call was not acknowledged by server.');
    }
    _log(
      'wearable.stream.response',
      data: <String, Object?>{
        'macAddress': macAddress,
        'statusCode': response.statusCode,
        'accepted': decoded['accepted'] == true,
        'ignored': decoded['ignored'] == true,
        'duplicate': decoded['duplicate'] == true,
      },
    );
    return decoded;
  }

  Future<Map<String, dynamic>> syncWearableData(
    String baseUrl,
    String macAddress,
    Uint8List data,
  ) async {
    _log(
      'wearable.sync.request',
      data: <String, Object?>{'macAddress': macAddress, 'size': data.length},
    );
    final response = await _httpClient.post(
      _resolveUri(baseUrl, '/api/wearables/$macAddress/sync'),
      headers: <String, String>{'Content-Type': 'application/octet-stream'},
      body: data,
    );
    _throwIfError(response);
    _log(
      'wearable.sync.response',
      data: <String, Object?>{
        'macAddress': macAddress,
        'statusCode': response.statusCode,
      },
    );
    return _asMap(_decodeJson(response.body));
  }

  Future<Map<String, dynamic>> stopWearableLiveStream(
    String baseUrl,
    String macAddress,
  ) async {
    _log(
      'wearable.stop_live.request',
      data: <String, Object?>{'macAddress': macAddress},
    );
    final candidates = <String>[
      '/api/wearables/$macAddress/stop-live',
      '/api/wearables/$macAddress/stop',
      '/api/wearables/stop-live',
    ];

    BackendException? lastError;
    for (final path in candidates) {
      final body =
          path.endsWith('/$macAddress/stop-live') ||
              path.endsWith('/$macAddress/stop')
          ? jsonEncode(const <String, dynamic>{})
          : jsonEncode(<String, dynamic>{'macAddress': macAddress});
      final response = await _httpClient.post(
        _resolveUri(baseUrl, path),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _log(
          'wearable.stop_live.response',
          data: <String, Object?>{
            'macAddress': macAddress,
            'statusCode': response.statusCode,
            'path': path,
          },
        );
        return _asMap(_decodeJson(response.body));
      }

      try {
        _throwIfError(response);
      } on BackendException catch (error) {
        lastError = error;
      }

      if (response.statusCode != 404) {
        break;
      }

      _log(
        'wearable.stop_live.fallback_404',
        data: <String, Object?>{'macAddress': macAddress, 'path': path},
      );
    }

    throw lastError ??
        const BackendException('Failed to stop wearable live stream');
  }

  /// Register a wearable device with the backend
  Future<Map<String, dynamic>> registerWearable(
    String baseUrl,
    String macAddress,
    String protocol,
    String name,
  ) async {
    _log(
      'wearable.register.request',
      data: <String, Object?>{
        'macAddress': macAddress,
        'protocol': protocol,
        'name': name,
      },
    );
    final response = await _httpClient.post(
      _resolveUri(baseUrl, '/api/wearables'),
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(<String, dynamic>{
        'macAddress': macAddress,
        'protocol': protocol,
        'name': name,
      }),
    );
    _throwIfError(response);
    _log(
      'wearable.register.response',
      data: <String, Object?>{
        'macAddress': macAddress,
        'statusCode': response.statusCode,
      },
    );
    return _asMap(_decodeJson(response.body));
  }

  Future<Map<String, dynamic>> saveMcpServer(
    String baseUrl, {
    int? id,
    required String name,
    required String command,
    required Map<String, dynamic> config,
    required bool enabled,
    String? agentId,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'command': command,
      'config': config,
      'enabled': enabled,
      if (agentId != null && agentId.isNotEmpty) 'agentId': agentId,
    };
    if (id == null) {
      return postMap(baseUrl, '/api/mcp', payload);
    }
    return putMap(baseUrl, '/api/mcp/$id', payload);
  }

  Future<Map<String, dynamic>> startMcpServer(String baseUrl, int id) async {
    return postMap(baseUrl, '/api/mcp/$id/start', const <String, dynamic>{});
  }

  Future<Map<String, dynamic>> stopMcpServer(String baseUrl, int id) async {
    return postMap(baseUrl, '/api/mcp/$id/stop', const <String, dynamic>{});
  }

  Future<void> deleteMcpServer(String baseUrl, int id) async {
    await deleteMap(baseUrl, '/api/mcp/$id');
  }

  Future<Map<String, dynamic>> getMap(
    String baseUrl,
    String path, {
    bool allowUnauthorized = false,
  }) async {
    final response = await _request(
      'GET',
      _resolveUri(baseUrl, path),
      allowUnauthorized: allowUnauthorized,
    );
    if (allowUnauthorized && response.statusCode == 401) {
      return const <String, dynamic>{};
    }
    _throwIfError(response);
    return _asMap(_decodeJson(response.body));
  }

  Future<List<Map<String, dynamic>>> getList(
    String baseUrl,
    String path,
  ) async {
    final response = await _request('GET', _resolveUri(baseUrl, path));
    _throwIfError(response);
    return _asList(_decodeJson(response.body));
  }

  Future<Map<String, dynamic>> postMap(
    String baseUrl,
    String path,
    Map<String, dynamic> payload, {
    bool allowUnauthorized = false,
  }) async {
    final response = await _request(
      'POST',
      _resolveUri(baseUrl, path),
      body: payload,
      allowUnauthorized: allowUnauthorized,
    );
    if (allowUnauthorized && response.statusCode == 401) {
      return const <String, dynamic>{};
    }
    _throwIfError(response);
    return _asMap(_decodeJson(response.body));
  }

  Future<List<Map<String, dynamic>>> postList(
    String baseUrl,
    String path,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      'POST',
      _resolveUri(baseUrl, path),
      body: payload,
    );
    _throwIfError(response);
    return _asList(_decodeJson(response.body));
  }

  Future<Map<String, dynamic>> putMap(
    String baseUrl,
    String path,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      'PUT',
      _resolveUri(baseUrl, path),
      body: payload,
    );
    _throwIfError(response);
    return _asMap(_decodeJson(response.body));
  }

  Future<Map<String, dynamic>> deleteMap(String baseUrl, String path) async {
    final response = await _request('DELETE', _resolveUri(baseUrl, path));
    _throwIfError(response);
    return _asMap(_decodeJson(response.body));
  }

  Uri _resolveUri(String baseUrl, String path) {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) {
      return Uri.parse(path);
    }
    return Uri.parse(trimmed.replaceFirst(RegExp(r'/$'), '') + path);
  }

  Uri resolveAssetUri(String baseUrl, String path) =>
      _resolveUri(baseUrl, path);

  Future<Uint8List> fetchBinary(String baseUrl, String path) async {
    final response = await _httpClient.get(_resolveUri(baseUrl, path));
    _throwIfError(response);
    return response.bodyBytes;
  }

  Future<HttpResponseData> _request(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
    bool allowUnauthorized = false,
  }) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final encodedBody = body == null ? null : jsonEncode(body);
    switch (method) {
      case 'GET':
        return _httpClient.get(uri, headers: headers);
      case 'POST':
        return _httpClient.post(uri, headers: headers, body: encodedBody);
      case 'PUT':
        return _httpClient.put(uri, headers: headers, body: encodedBody);
      case 'DELETE':
        return _httpClient.delete(uri, headers: headers, body: encodedBody);
      default:
        throw BackendException('Unsupported method: $method');
    }
  }

  dynamic _decodeJson(String body) {
    if (body.trim().isEmpty) {
      return const <String, dynamic>{};
    }
    return jsonDecode(body);
  }

  Map<String, dynamic> _asMap(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    if (decoded is List) {
      return <String, dynamic>{
        'items': decoded
            .whereType<Object?>()
            .map(
              (item) => item is Map
                  ? Map<String, dynamic>.from(item)
                  : <String, dynamic>{'value': item},
            )
            .toList(),
      };
    }
    return <String, dynamic>{'value': decoded};
  }

  List<Map<String, dynamic>> _asList(dynamic decoded) {
    if (decoded is List) {
      return decoded
          .map(
            (item) => item is Map
                ? Map<String, dynamic>.from(item)
                : <String, dynamic>{'value': item},
          )
          .toList();
    }
    if (decoded is Map<String, dynamic>) {
      final items = decoded['items'];
      if (items is List) {
        return items
            .map(
              (item) => item is Map
                  ? Map<String, dynamic>.from(item)
                  : <String, dynamic>{'value': item},
            )
            .toList();
      }
    }
    return const <Map<String, dynamic>>[];
  }

  void _throwIfError(HttpResponseData response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    var message = 'Request failed with HTTP ${response.statusCode}';
    try {
      final decoded = _asMap(_decodeJson(response.body));
      message = decoded['error']?.toString() ?? message;
    } catch (_) {}

    throw BackendException(message);
  }
}

class BackendException implements Exception {
  const BackendException(this.message);

  final String message;

  @override
  String toString() => message;
}
