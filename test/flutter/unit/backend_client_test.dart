import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/network/app_http_client.dart';

class FakeHttpClient implements AppHttpClient {
  Uri? lastUri;
  Object? lastBody;
  String? _sessionCookie;

  @override
  String? get sessionCookie => _sessionCookie;

  @override
  void clearSession() {
    _sessionCookie = null;
  }

  @override
  Future<void> close() async {}

  @override
  Future<HttpResponseData> delete(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    lastUri = uri;
    return _json(<String, dynamic>{'success': true});
  }

  @override
  Future<HttpResponseData> get(Uri uri, {Map<String, String>? headers}) async {
    lastUri = uri;
    return _json(<String, dynamic>{'ok': true});
  }

  @override
  Future<HttpResponseData> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    lastUri = uri;
    lastBody = body;
    return _json(<String, dynamic>{'ok': true});
  }

  @override
  Future<HttpResponseData> patch(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    lastUri = uri;
    lastBody = body;
    return _json(<String, dynamic>{'ok': true});
  }

  @override
  Future<HttpResponseData> postMultipart(
    Uri uri, {
    Map<String, String>? headers,
    required String fieldName,
    required String filename,
    required Uint8List bytes,
  }) async {
    lastUri = uri;
    return _json(<String, dynamic>{'ok': true});
  }

  @override
  Future<HttpResponseData> put(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    lastUri = uri;
    lastBody = body;
    return _json(<String, dynamic>{'ok': true});
  }

  @override
  void restoreSession(String? sessionCookie) {
    _sessionCookie = sessionCookie;
  }

  HttpResponseData _json(Map<String, dynamic> value) {
    final body = jsonEncode(value);
    return HttpResponseData(
      statusCode: 200,
      body: body,
      bodyBytes: Uint8List.fromList(utf8.encode(body)),
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }
}

void main() {
  test('BackendClient appends encoded agentId query values', () async {
    final fake = FakeHttpClient();
    final client = BackendClient(httpClient: fake);

    await client.fetchRuns('https://neo.test', agentId: 'agent one/two');
    expect(
      fake.lastUri.toString(),
      'https://neo.test/api/agents?limit=20&agentId=agent+one%2Ftwo',
    );

    await client.fetchSettings('https://neo.test', agentId: '   ');
    expect(fake.lastUri.toString(), 'https://neo.test/api/settings');
  });

  test('BackendClient encodes timeline filters and cursor params', () async {
    final fake = FakeHttpClient();
    final client = BackendClient(httpClient: fake);

    await client.fetchTimeline(
      'https://neo.test',
      sources: const <String>['screen', 'runs'],
      agentId: 'agent one/two',
      beforeOccurredAt: '2026-06-23T10:00:00.000Z',
      beforeId: 42,
      limit: 25,
    );

    expect(
      fake.lastUri.toString(),
      'https://neo.test/api/timeline?limit=25&agentId=agent+one%2Ftwo&beforeOccurredAt=2026-06-23T10%3A00%3A00.000Z&beforeId=42&source=screen&source=runs',
    );
  });

  test(
    'BackendClient sends user-facing integration test and Bitwarden login requests',
    () async {
      final fake = FakeHttpClient();
      final client = BackendClient(httpClient: fake);

      await client.testOfficialIntegration(
        'https://neo.test',
        'google_workspace',
        connectionId: 42,
        agentId: 'main agent',
      );
      expect(
        fake.lastUri.toString(),
        'https://neo.test/api/integrations/google_workspace/test',
      );
      expect(jsonDecode(fake.lastBody! as String), <String, dynamic>{
        'connectionId': 42,
        'agentId': 'main agent',
      });

      await client.unlockBitwarden(
        'https://neo.test',
        masterPassword: 'master-password',
        persistSession: true,
        twoStepMethod: '0',
        twoStepCode: '123456',
        agentId: 'main agent',
      );
      expect(
        fake.lastUri.toString(),
        'https://neo.test/api/integrations/bitwarden/unlock',
      );
      expect(jsonDecode(fake.lastBody! as String), <String, dynamic>{
        'masterPassword': 'master-password',
        'persistSession': true,
        'twoStepMethod': '0',
        'twoStepCode': '123456',
        'agentId': 'main agent',
      });
    },
  );

  test('BackendClient saves AI provider credentials without leaking extra fields', () async {
    final fake = FakeHttpClient();
    final client = BackendClient(httpClient: fake);

    await client.saveAiProviderCredentials(
      'https://neo.test',
      'openai-compatible',
      apiKey: 'sk-test',
      baseUrlOverride: 'https://models.example.test/v1',
      agentId: 'main agent',
    );

    expect(
      fake.lastUri.toString(),
      'https://neo.test/api/settings/ai-providers/openai-compatible/credentials?agentId=main+agent',
    );
    expect(jsonDecode(fake.lastBody! as String), <String, dynamic>{
      'apiKey': 'sk-test',
      'baseUrl': 'https://models.example.test/v1',
    });
  });
}
