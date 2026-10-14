import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/backend_url.dart';

void main() {
  test('pasted web app addresses lose app paths, query and fragment', () {
    expect(
      normalizeBackendUrl('https://agent.example.com/app/'),
      'https://agent.example.com',
    );
    expect(
      normalizeBackendUrl('https://agent.example.com/login?next=/app#top'),
      'https://agent.example.com',
    );
    expect(
      normalizeBackendUrl(' HTTPS://Agent.Example.com/neo/app// '),
      'https://agent.example.com/neo',
    );
    expect(
      normalizeBackendUrl('http://localhost:3333/'),
      'http://localhost:3333',
    );
    expect(normalizeBackendUrl('   '), '');
  });

  test('bare hosts use http only on private networks', () {
    expect(
      normalizeBackendUrl('agent.example.com'),
      'https://agent.example.com',
    );
    expect(normalizeBackendUrl('localhost:3333'), 'http://localhost:3333');
    expect(
      normalizeBackendUrl('192.168.1.20:3333/app'),
      'http://192.168.1.20:3333',
    );
    expect(normalizeBackendUrl('172.20.0.4:3333'), 'http://172.20.0.4:3333');
    expect(normalizeBackendUrl('172.32.0.4'), 'https://172.32.0.4');
    expect(normalizeBackendUrl('100.101.2.3:3333'), 'http://100.101.2.3:3333');
    expect(normalizeBackendUrl('100.128.2.3'), 'https://100.128.2.3');
    expect(normalizeBackendUrl('neo.local:3333'), 'http://neo.local:3333');
    expect(normalizeBackendUrl('box.lan'), 'http://box.lan');
    expect(
      normalizeBackendUrl('box.tail1234.ts.net:3333'),
      'http://box.tail1234.ts.net:3333',
    );
  });

  test('only a missing scheme counts as inferred', () {
    expect(backendUrlSchemeWasInferred('agent.example.com'), isTrue);
    expect(backendUrlSchemeWasInferred('https://agent.example.com'), isFalse);
  });
}
