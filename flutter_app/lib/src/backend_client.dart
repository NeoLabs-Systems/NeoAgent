import 'dart:convert';

import 'network/app_http_client.dart';
import 'network/app_http_client_factory.dart';

class BackendClient {
  BackendClient({AppHttpClient? httpClient})
    : _httpClient = httpClient ?? createAppHttpClient();

  final AppHttpClient _httpClient;

  String? get sessionCookie => _httpClient.sessionCookie;

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
    required String password,
  }) async {
    return postMap(baseUrl, '/api/auth/register', <String, dynamic>{
      'username': username,
      'password': password,
    });
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

  Future<Map<String, dynamic>> fetchChatHistory(String baseUrl) async {
    return getMap(baseUrl, '/api/agents/chat-history?limit=120');
  }

  Future<Map<String, dynamic>> runTask(String baseUrl, String task) async {
    return postMap(baseUrl, '/api/agents', <String, dynamic>{
      'task': task,
      'options': const <String, dynamic>{},
    });
  }

  Future<Map<String, dynamic>> fetchSettings(String baseUrl) async {
    return getMap(baseUrl, '/api/settings');
  }

  Future<Map<String, dynamic>> fetchSupportedModels(String baseUrl) async {
    return getMap(baseUrl, '/api/settings/meta/models');
  }

  Future<Map<String, dynamic>> saveSettings(
    String baseUrl,
    Map<String, dynamic> payload,
  ) async {
    return putMap(baseUrl, '/api/settings', payload);
  }

  Future<Map<String, dynamic>> fetchTokenUsageSummary(String baseUrl) async {
    return getMap(baseUrl, '/api/settings/token-usage/summary');
  }

  Future<Map<String, dynamic>> fetchUpdateStatus(String baseUrl) async {
    return getMap(baseUrl, '/api/settings/update/status');
  }

  Future<Map<String, dynamic>> triggerUpdate(String baseUrl) async {
    return postMap(baseUrl, '/api/settings/update', const <String, dynamic>{});
  }

  Future<Map<String, dynamic>> fetchRuns(String baseUrl) async {
    return getMap(baseUrl, '/api/agents?limit=20');
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

  Future<Map<String, dynamic>> fetchMessagingStatus(String baseUrl) async {
    return getMap(baseUrl, '/api/messaging/status');
  }

  Future<List<Map<String, dynamic>>> fetchMessagingMessages(
    String baseUrl, {
    String? platform,
    String? chatId,
  }) async {
    final params = <String>[
      if (platform != null && platform.isNotEmpty)
        'platform=${Uri.encodeQueryComponent(platform)}',
      if (chatId != null && chatId.isNotEmpty)
        'chatId=${Uri.encodeQueryComponent(chatId)}',
      'limit=60',
    ];
    return getList(baseUrl, '/api/messaging/messages?${params.join('&')}');
  }

  Future<Map<String, dynamic>> connectMessagingPlatform(
    String baseUrl, {
    required String platform,
    Map<String, dynamic>? config,
  }) async {
    return postMap(baseUrl, '/api/messaging/connect', <String, dynamic>{
      'platform': platform,
      'config': config ?? const <String, dynamic>{},
    });
  }

  Future<Map<String, dynamic>> disconnectMessagingPlatform(
    String baseUrl, {
    required String platform,
  }) async {
    return postMap(baseUrl, '/api/messaging/disconnect', <String, dynamic>{
      'platform': platform,
    });
  }

  Future<Map<String, dynamic>> logoutMessagingPlatform(
    String baseUrl, {
    required String platform,
  }) async {
    return postMap(baseUrl, '/api/messaging/logout', <String, dynamic>{
      'platform': platform,
    });
  }

  Future<Map<String, dynamic>> saveTelnyxWhitelist(
    String baseUrl,
    List<String> numbers,
  ) async {
    return putMap(baseUrl, '/api/messaging/telnyx/whitelist', <String, dynamic>{
      'numbers': numbers,
    });
  }

  Future<Map<String, dynamic>> saveTelnyxVoiceSecret(
    String baseUrl,
    String secret,
  ) async {
    return putMap(
      baseUrl,
      '/api/messaging/telnyx/voice-secret',
      <String, dynamic>{'secret': secret},
    );
  }

  Future<Map<String, dynamic>> saveDiscordWhitelist(
    String baseUrl,
    List<String> ids,
  ) async {
    return putMap(
      baseUrl,
      '/api/messaging/discord/whitelist',
      <String, dynamic>{'ids': ids},
    );
  }

  Future<Map<String, dynamic>> saveTelegramWhitelist(
    String baseUrl,
    List<String> ids,
  ) async {
    return putMap(
      baseUrl,
      '/api/messaging/telegram/whitelist',
      <String, dynamic>{'ids': ids},
    );
  }

  Future<Map<String, dynamic>> fetchMemoryOverview(String baseUrl) async {
    return getMap(baseUrl, '/api/memory');
  }

  Future<List<Map<String, dynamic>>> fetchMemories(
    String baseUrl, {
    String? category,
  }) async {
    final query = category == null ? '' : '?category=$category';
    return getList(baseUrl, '/api/memory/memories$query');
  }

  Future<List<Map<String, dynamic>>> recallMemories(
    String baseUrl,
    String query,
  ) async {
    return postList(baseUrl, '/api/memory/memories/recall', <String, dynamic>{
      'query': query,
      'limit': 8,
    });
  }

  Future<Map<String, dynamic>> createMemory(
    String baseUrl, {
    required String content,
    required String category,
    required int importance,
  }) async {
    return postMap(baseUrl, '/api/memory/memories', <String, dynamic>{
      'content': content,
      'category': category,
      'importance': importance,
    });
  }

  Future<void> deleteMemory(String baseUrl, int id) async {
    await deleteMap(baseUrl, '/api/memory/memories/$id');
  }

  Future<Map<String, dynamic>> fetchCoreMemory(String baseUrl) async {
    return getMap(baseUrl, '/api/memory/core');
  }

  Future<Map<String, dynamic>> updateCoreMemory(
    String baseUrl, {
    required String key,
    required String value,
  }) async {
    return putMap(baseUrl, '/api/memory/core/$key', <String, dynamic>{
      'value': value,
    });
  }

  Future<void> deleteCoreMemory(String baseUrl, String key) async {
    await deleteMap(baseUrl, '/api/memory/core/$key');
  }

  Future<Map<String, dynamic>> fetchSoul(String baseUrl) async {
    return getMap(baseUrl, '/api/memory/soul');
  }

  Future<Map<String, dynamic>> updateSoul(
    String baseUrl,
    String content,
  ) async {
    return putMap(baseUrl, '/api/memory/soul', <String, dynamic>{
      'content': content,
    });
  }

  Future<List<Map<String, dynamic>>> fetchConversations(String baseUrl) async {
    return getList(baseUrl, '/api/memory/conversations?limit=12');
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
    bool enabled = true,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'cronExpression': cronExpression,
      'prompt': prompt,
      'enabled': enabled,
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
    return getList(baseUrl, '/api/recordings?limit=$limit');
  }

  Future<Map<String, dynamic>> fetchRecordingSession(
    String baseUrl,
    String sessionId,
  ) async {
    return getMap(baseUrl, '/api/recordings/$sessionId');
  }

  Future<Map<String, dynamic>> createRecordingSession(
    String baseUrl,
    Map<String, dynamic> payload,
  ) async {
    return postMap(baseUrl, '/api/recordings', payload);
  }

  Future<Map<String, dynamic>> finalizeRecordingSession(
    String baseUrl,
    String sessionId, {
    String stopReason = 'stopped',
  }) async {
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

  Future<Map<String, dynamic>> saveMcpServer(
    String baseUrl, {
    int? id,
    required String name,
    required String command,
    required Map<String, dynamic> config,
    required bool enabled,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'command': command,
      'config': config,
      'enabled': enabled,
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
