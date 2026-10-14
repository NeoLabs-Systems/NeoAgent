import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/backend_client.dart';

import '../support/scripted_http_client.dart';

void main() {
  test('a 401 outside /api/auth reports the session as expired', () async {
    var expired = 0;
    final client = BackendClient(
      httpClient: ScriptedHttpClient(
        (method, uri, body) =>
            jsonResponse(401, <String, dynamic>{'error': 'Unauthorized'}),
      ),
    )..onSessionExpired = () => expired += 1;

    await expectLater(
      client.getMap('http://localhost:3333', '/api/settings'),
      throwsA(isA<BackendException>()),
    );
    expect(expired, 1);

    await expectLater(
      client.login(
        baseUrl: 'http://localhost:3333',
        username: 'a',
        password: 'b',
      ),
      throwsA(isA<BackendException>()),
    );
    expect(expired, 1, reason: 'a failed sign-in is not an expired session');
  });

  test('probeServer rejects pages and APIs that are not NeoAgent', () async {
    Future<Object?> probe(ScriptedResponder responder) async {
      try {
        await BackendClient(
          httpClient: ScriptedHttpClient(responder),
        ).probeServer('http://localhost:3333');
        return null;
      } on BackendException catch (error) {
        return error.code;
      }
    }

    expect(
      await probe(
        (m, u, b) => textResponse(200, '<!doctype html><html></html>'),
      ),
      BackendException.notNeoAgentServer,
    );
    expect(
      await probe(
        (m, u, b) => jsonResponse(200, <String, dynamic>{'ok': true}),
      ),
      BackendException.notNeoAgentServer,
    );
    expect(
      await probe(
        (m, u, b) => jsonResponse(401, <String, dynamic>{'error': 'Login'}),
      ),
      BackendException.notNeoAgentServer,
    );
    expect(
      await probe(
        (m, u, b) => jsonResponse(200, <String, dynamic>{'hasUser': true}),
      ),
      isNull,
    );
  });

  test(
    'error codes and the https address survive into BackendException',
    () async {
      final client = BackendClient(
        httpClient: ScriptedHttpClient(
          (m, u, b) => jsonResponse(400, <String, dynamic>{
            'error': 'Use HTTPS',
            'code': 'INSECURE_TRANSPORT',
            'httpsUrl': 'https://agent.example.com',
          }),
        ),
      );
      try {
        await client.login(
          baseUrl: 'http://agent.example.com',
          username: 'a',
          password: 'b',
        );
        fail('expected an error');
      } on BackendException catch (error) {
        expect(error.code, 'INSECURE_TRANSPORT');
        expect(error.httpsUrl, 'https://agent.example.com');
      }
    },
  );
}
