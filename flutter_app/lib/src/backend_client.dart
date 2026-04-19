import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'diagnostics_logger.dart';
import 'network/app_http_client.dart';
import 'network/app_http_client_factory.dart';

class BackendClient {
  BackendClient({AppHttpClient? httpClient})
    : _httpClient = httpClient ?? createAppHttpClient();

  static const Duration _requestTimeout = Duration(seconds: 20);

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

  void restoreSessionCookie(String? sessionCookie) {
    _httpClient.restoreSession(sessionCookie);
  }

  void clearSessionCookie() {
    _httpClient.clearSession();
  }

  String? _normalizedAgentId(String? agentId) {
    final normalized = agentId?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  String _agentQuery(String? agentId) {
    final normalized = _normalizedAgentId(agentId);
    if (normalized == null) return '';
    return 'agentId=${Uri.encodeQueryComponent(normalized)}';
  }

  String _withAgentQuery(String path, String? agentId) {
    final query = _agentQuery(agentId);
    if (query.isEmpty) return path;
    return path.contains('?') ? '$path&$query' : '$path?$query';
  }

  Map<String, dynamic> _withAgentId(
    Map<String, dynamic> payload,
    String? agentId,
  ) {
    final normalized = _normalizedAgentId(agentId);
    if (normalized == null) return payload;
    return <String, dynamic>{...payload, 'agentId': normalized};
  }

  Future<Map<String, dynamic>> _saveByOptionalId(
    String baseUrl,
    String path,
    int? id,
    Map<String, dynamic> payload,
  ) async {
    if (id == null) {
      return postMap(baseUrl, path, payload);
    }
    return putMap(baseUrl, '$path/$id', payload);
  }

  Future<Map<String, dynamic>> _postEmpty(String baseUrl, String path) {
    return postMap(baseUrl, path, const <String, dynamic>{});
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
    return postMap(
      baseUrl,
      '/api/auth/providers/$provider/begin',
      <String, dynamic>{'mode': mode},
      allowUnauthorized: mode != 'link',
    );
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
    return putMap(baseUrl, '/api/settings', _withAgentId(payload, agentId));
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
    return _postEmpty(baseUrl, '/api/settings/update');
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
    return _postEmpty(baseUrl, '/api/browser/close');
  }

  Future<Map<String, dynamic>> fetchAndroidStatus(String baseUrl) async {
    return getMap(baseUrl, '/api/android/status');
  }

  Future<Map<String, dynamic>> fetchDesktopStatus(String baseUrl) async {
    return getMap(baseUrl, '/api/desktop/status');
  }

  Future<Map<String, dynamic>> fetchRateLimitDiagnostics(String baseUrl) async {
    return getMap(baseUrl, '/api/diagnostics/rate-limits');
  }

  Future<Map<String, dynamic>> fetchDesktopDevices(String baseUrl) async {
    return getMap(baseUrl, '/api/desktop/devices');
  }

  Future<Map<String, dynamic>> selectDesktopDevice(
    String baseUrl, {
    required String deviceId,
  }) async {
    return postMap(baseUrl, '/api/desktop/select-device', <String, dynamic>{
      'deviceId': deviceId,
    });
  }

  Future<Map<String, dynamic>> screenshotDesktop(
    String baseUrl, {
    String? deviceId,
  }) async {
    return postMap(baseUrl, '/api/desktop/screenshot', <String, dynamic>{
      if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
    });
  }

  Future<Map<String, dynamic>> observeDesktop(
    String baseUrl, {
    String? deviceId,
    bool includeTree = false,
  }) async {
    return postMap(baseUrl, '/api/desktop/observe', <String, dynamic>{
      if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
      'includeTree': includeTree,
    });
  }

  Future<Map<String, dynamic>> clickDesktop(
    String baseUrl, {
    String? deviceId,
    required int x,
    required int y,
    String? button,
  }) async {
    return postMap(baseUrl, '/api/desktop/click', <String, dynamic>{
      if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
      'x': x,
      'y': y,
      if (button != null && button.isNotEmpty) 'button': button,
    });
  }

  Future<Map<String, dynamic>> dragDesktop(
    String baseUrl, {
    String? deviceId,
    required int x1,
    required int y1,
    required int x2,
    required int y2,
    int durationMs = 280,
  }) async {
    return postMap(baseUrl, '/api/desktop/drag', <String, dynamic>{
      if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
      'x1': x1,
      'y1': y1,
      'x2': x2,
      'y2': y2,
      'durationMs': durationMs,
    });
  }

  Future<Map<String, dynamic>> scrollDesktop(
    String baseUrl, {
    String? deviceId,
    int deltaX = 0,
    int deltaY = 0,
  }) async {
    return postMap(baseUrl, '/api/desktop/scroll', <String, dynamic>{
      if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
      'deltaX': deltaX,
      'deltaY': deltaY,
    });
  }

  Future<Map<String, dynamic>> typeDesktopText(
    String baseUrl, {
    String? deviceId,
    required String text,
    bool pressEnter = false,
  }) async {
    return postMap(baseUrl, '/api/desktop/type-text', <String, dynamic>{
      if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
      'text': text,
      'pressEnter': pressEnter,
    });
  }

  Future<Map<String, dynamic>> pressDesktopKey(
    String baseUrl, {
    String? deviceId,
    required String key,
  }) async {
    return postMap(baseUrl, '/api/desktop/press-key', <String, dynamic>{
      if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
      'key': key,
    });
  }

  Future<Map<String, dynamic>> launchDesktopApp(
    String baseUrl, {
    String? deviceId,
    required String app,
  }) async {
    return postMap(baseUrl, '/api/desktop/launch-app', <String, dynamic>{
      if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
      'app': app,
    });
  }

  Future<Map<String, dynamic>> fetchDesktopDisplays(
    String baseUrl, {
    String? deviceId,
  }) async {
    final query = deviceId != null && deviceId.isNotEmpty
        ? '?deviceId=${Uri.encodeQueryComponent(deviceId)}'
        : '';
    return getMap(baseUrl, '/api/desktop/displays$query');
  }

  Future<Map<String, dynamic>> selectDesktopDisplay(
    String baseUrl, {
    String? deviceId,
    required String displayId,
  }) async {
    return postMap(baseUrl, '/api/desktop/select-display', <String, dynamic>{
      if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
      'displayId': displayId,
    });
  }

  Future<Map<String, dynamic>> revokeDesktopDevice(
    String baseUrl, {
    required String deviceId,
  }) async {
    return postMap(baseUrl, '/api/desktop/revoke-device', <String, dynamic>{
      'deviceId': deviceId,
    });
  }

  Future<Map<String, dynamic>> pauseDesktopDevice(
    String baseUrl, {
    required String deviceId,
    bool paused = true,
  }) async {
    return postMap(baseUrl, '/api/desktop/pause-device', <String, dynamic>{
      'deviceId': deviceId,
      'paused': paused,
    });
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
    return _postEmpty(baseUrl, '/api/android/stop');
  }

  Future<Map<String, dynamic>> screenshotAndroid(String baseUrl) async {
    return _postEmpty(baseUrl, '/api/android/screenshot');
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
      _withAgentId(<String, dynamic>{'appId': appId}, agentId),
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
      _withAgentId(<String, dynamic>{'connectionId': connectionId}, agentId),
    );
  }

  Future<Map<String, dynamic>> setOfficialIntegrationAccessMode(
    String baseUrl,
    String providerId, {
    required int connectionId,
    required String accessMode,
    String? agentId,
  }) async {
    return postMap(
      baseUrl,
      '/api/integrations/$providerId/access-mode',
      _withAgentId(<String, dynamic>{
        'connectionId': connectionId,
        'accessMode': accessMode,
      }, agentId),
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
    return postMap(
      baseUrl,
      '/api/messaging/connect',
      _withAgentId(<String, dynamic>{
        'platform': platform,
        'config': config ?? const <String, dynamic>{},
      }, agentId),
    );
  }

  Future<Map<String, dynamic>> disconnectMessagingPlatform(
    String baseUrl, {
    required String platform,
    String? agentId,
  }) async {
    return postMap(
      baseUrl,
      '/api/messaging/disconnect',
      _withAgentId(<String, dynamic>{'platform': platform}, agentId),
    );
  }

  Future<Map<String, dynamic>> logoutMessagingPlatform(
    String baseUrl, {
    required String platform,
    String? agentId,
  }) async {
    return postMap(
      baseUrl,
      '/api/messaging/logout',
      _withAgentId(<String, dynamic>{'platform': platform}, agentId),
    );
  }

  Future<Map<String, dynamic>> fetchMessagingPlatformDevices(
    String baseUrl, {
    required String platform,
    String? agentId,
  }) async {
    return getMap(
      baseUrl,
      _withAgentQuery('/api/messaging/$platform/devices', agentId),
    );
  }

  Future<Map<String, dynamic>> createWearablePairingCode(
    String baseUrl, {
    int ttlMinutes = 10,
    String? deviceHint,
    String? agentId,
  }) async {
    return postMap(
      baseUrl,
      '/api/wearable-device/pairing/code',
      _withAgentId(<String, dynamic>{
        'ttlMinutes': ttlMinutes,
        if (deviceHint != null && deviceHint.isNotEmpty)
          'deviceHint': deviceHint,
      }, agentId),
    );
  }

  Future<Map<String, dynamic>> saveTelnyxWhitelist(
    String baseUrl,
    List<String> numbers, {
    String? agentId,
  }) async {
    return putMap(
      baseUrl,
      '/api/messaging/telnyx/whitelist',
      _withAgentId(<String, dynamic>{'numbers': numbers}, agentId),
    );
  }

  Future<Map<String, dynamic>> saveTelnyxVoiceSecret(
    String baseUrl,
    String secret, {
    String? agentId,
  }) async {
    return putMap(
      baseUrl,
      '/api/messaging/telnyx/voice-secret',
      _withAgentId(<String, dynamic>{'secret': secret}, agentId),
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
      _withAgentId(<String, dynamic>{'ids': ids}, agentId),
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
      _withAgentId(<String, dynamic>{'ids': ids}, agentId),
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
      _withAgentId(<String, dynamic>{'ids': ids}, agentId),
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
    return postList(
      baseUrl,
      '/api/memory/memories/recall',
      _withAgentId(<String, dynamic>{'query': query, 'limit': 8}, agentId),
    );
  }

  Future<Map<String, dynamic>> createMemory(
    String baseUrl, {
    required String content,
    required String category,
    required int importance,
    String? agentId,
  }) async {
    return postMap(
      baseUrl,
      '/api/memory/memories',
      _withAgentId(<String, dynamic>{
        'content': content,
        'category': category,
        'importance': importance,
      }, agentId),
    );
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
      _withAgentId(<String, dynamic>{'ids': ids}, agentId),
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
      _withAgentId(<String, dynamic>{
        'ids': ids,
        'archived': archived,
      }, agentId),
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
    return putMap(
      baseUrl,
      '/api/memory/core/$key',
      _withAgentId(<String, dynamic>{'value': value}, agentId),
    );
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
    final payload = _withAgentId(<String, dynamic>{
      'name': name,
      'cronExpression': cronExpression,
      'prompt': prompt,
      'model': model,
      'enabled': enabled,
    }, agentId);
    return _saveByOptionalId(baseUrl, '/api/scheduler', id, payload);
  }

  Future<Map<String, dynamic>> updateSchedulerTask(
    String baseUrl,
    int id,
    Map<String, dynamic> payload,
  ) async {
    return putMap(baseUrl, '/api/scheduler/$id', payload);
  }

  Future<Map<String, dynamic>> runSchedulerTask(String baseUrl, int id) async {
    return _postEmpty(baseUrl, '/api/scheduler/$id/run');
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

  Future<Map<String, dynamic>> runVoiceAssistantTurn(
    String baseUrl, {
    required String sessionId,
    String ttsProvider = 'openai',
    String ttsVoice = 'alloy',
    String ttsModel = 'gpt-4o-mini-tts',
    String? agentId,
    String? screenshotBase64,
    String? screenshotMimeType,
  }) async {
    final payload = <String, dynamic>{
      'sessionId': sessionId,
      'ttsProvider': ttsProvider,
      'ttsVoice': ttsVoice,
      'ttsModel': ttsModel,
      if ((screenshotBase64?.trim().isNotEmpty ?? false))
        'screenshotBase64': screenshotBase64!.trim(),
      if ((screenshotMimeType?.trim().isNotEmpty ?? false))
        'screenshotMimeType': screenshotMimeType!.trim(),
    };
    return postMap(
      baseUrl,
      _withAgentQuery('/api/voice-assistant/respond', agentId),
      payload,
    );
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
    final payload = _withAgentId(<String, dynamic>{
      'name': name,
      'command': command,
      'config': config,
      'enabled': enabled,
    }, agentId);
    return _saveByOptionalId(baseUrl, '/api/mcp', id, payload);
  }

  Future<Map<String, dynamic>> startMcpServer(String baseUrl, int id) async {
    return _postEmpty(baseUrl, '/api/mcp/$id/start');
  }

  Future<Map<String, dynamic>> stopMcpServer(String baseUrl, int id) async {
    return _postEmpty(baseUrl, '/api/mcp/$id/stop');
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
    final response = await _httpClient
        .get(_resolveUri(baseUrl, path))
        .timeout(_requestTimeout);
    _throwIfError(response);
    return response.bodyBytes;
  }

  Future<HttpResponseData> _request(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
    bool allowUnauthorized = false,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final encodedBody = body == null ? null : jsonEncode(body);
    late final Future<HttpResponseData> request;
    switch (method) {
      case 'GET':
        request = _httpClient.get(uri, headers: headers);
      case 'POST':
        request = _httpClient.post(uri, headers: headers, body: encodedBody);
      case 'PUT':
        request = _httpClient.put(uri, headers: headers, body: encodedBody);
      case 'DELETE':
        request = _httpClient.delete(uri, headers: headers, body: encodedBody);
      default:
        throw BackendException('Unsupported method: $method');
    }
    try {
      return await request.timeout(_requestTimeout);
    } on TimeoutException catch (error, stackTrace) {
      _log(
        'request.timeout',
        data: <String, Object?>{
          'method': method,
          'uri': uri.toString(),
          'allowUnauthorized': allowUnauthorized,
          'timeoutMs': _requestTimeout.inMilliseconds,
        },
        error: error,
        stackTrace: stackTrace,
      );
      throw BackendException(
        'The NeoAgent backend took too long to respond for ${uri.path}.',
      );
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
