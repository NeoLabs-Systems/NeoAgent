import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/network/app_http_client.dart';

class FakeHttpClient implements AppHttpClient {
  Uri? lastUri;
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
    expect(fake.lastUri.toString(), 'https://neo.test/api/agents?limit=20&agentId=agent+one%2Ftwo');

    await client.fetchSettings('https://neo.test', agentId: '   ');
    expect(fake.lastUri.toString(), 'https://neo.test/api/settings');
  });
}
