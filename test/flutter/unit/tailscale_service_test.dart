import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/tailscale_service.dart';
import 'package:neoagent_flutter/src/network/app_http_client.dart';

class _Client implements AppHttpClient {
  final List<Uri> requests = <Uri>[];
  Map<String, Object?> response = <String, Object?>{'status': 'connected'};

  HttpResponseData json() {
    final body = jsonEncode(response);
    return HttpResponseData(
      statusCode: 200,
      body: body,
      bodyBytes: Uint8List.fromList(utf8.encode(body)),
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }

  @override
  Future<HttpResponseData> get(Uri uri, {Map<String, String>? headers}) async {
    requests.add(uri);
    return json();
  }

  @override
  Future<HttpResponseData> delete(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    requests.add(uri);
    return json();
  }

  @override
  String? get sessionCookie => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'sign-in polling and cancellation stay bound to the agent that started login',
    () async {
      final http = _Client();
      final service = TailscaleService(BackendClient(httpClient: http));
      expect(
        await service.waitForSignIn(
          'https://neo.example',
          'session-123',
          'agent-two',
          () => true,
        ),
        isTrue,
      );
      await service.cancelSignIn(
        'https://neo.example',
        'session-123',
        'agent-two',
      );
      expect(
        http.requests.map((uri) => uri.queryParameters['agentId']),
        everyElement('agent-two'),
      );
      expect(
        http.requests.first.path,
        '/api/integrations/tailscale/connect/session-123/status',
      );
      expect(
        http.requests.last.path,
        '/api/integrations/tailscale/connect/session-123',
      );
    },
  );

  test('canceled sign-in stops polling without another request', () async {
    final http = _Client();
    final service = TailscaleService(BackendClient(httpClient: http));
    expect(
      await service.waitForSignIn(
        'https://neo.example',
        'session-123',
        'agent-two',
        () => false,
      ),
      isFalse,
    );
    expect(http.requests, isEmpty);
  });

  test('the service rejects malformed peer data at the API boundary', () async {
    final http = _Client()
      ..response = <String, Object?>{
        'peers': <Object?>[
          <String, Object?>{'id': 3},
        ],
        'services': <Object?>[],
      };
    final service = TailscaleService(BackendClient(httpClient: http));
    await expectLater(
      service.load('https://neo.example', 1, 'agent-two'),
      throwsFormatException,
    );
  });
}
