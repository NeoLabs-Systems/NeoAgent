import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/backend_discovery_models.dart';

void main() {
  test('handshake parsing validates NeoAgent identity and protocol', () {
    final candidate = BackendDiscoveryCandidate.fromHandshake(
      backendUrl: 'http://neoagent.local:4444/',
      handshake: const <String, dynamic>{
        'product': 'NeoAgent',
        'protocolVersion': 1,
        'instanceId': 'instance-a',
        'displayName': 'Office NeoAgent',
        'serverVersion': '3.4.0',
        'claimed': true,
      },
      source: 'mdns',
      isLocal: true,
    );
    expect(candidate.backendUrl, 'http://neoagent.local:4444');
    expect(candidate.instanceId, 'instance-a');
    expect(candidate.claimed, isTrue);

    expect(
      () => BackendDiscoveryCandidate.fromHandshake(
        backendUrl: 'http://other.local',
        handshake: const <String, dynamic>{
          'product': 'Other',
          'protocolVersion': 1,
          'instanceId': 'instance-b',
          'displayName': 'Other',
        },
        source: 'mdns',
        isLocal: true,
      ),
      throwsFormatException,
    );
  });

  test(
    'candidate ranking deduplicates by instance and prefers managed runtime',
    () {
      const lan = BackendDiscoveryCandidate(
        backendUrl: 'http://192.168.1.10:3333',
        instanceId: 'same-instance',
        displayName: 'NeoAgent',
        serverVersion: '3.4.0',
        claimed: false,
        source: 'mdns',
        isLocal: true,
      );
      const managed = BackendDiscoveryCandidate(
        backendUrl: 'http://localhost:4444',
        instanceId: 'same-instance',
        displayName: 'NeoAgent',
        serverVersion: '3.4.0',
        claimed: false,
        source: 'managed-runtime',
        isLocal: true,
      );
      const remote = BackendDiscoveryCandidate(
        backendUrl: 'https://remote.neoagent.invalid',
        instanceId: 'remote-instance',
        displayName: 'Remote',
        serverVersion: '3.4.0',
        claimed: true,
        source: 'saved',
        isLocal: false,
      );

      final ranked = rankBackendCandidates(<BackendDiscoveryCandidate>[
        lan,
        remote,
        managed,
      ]);
      expect(ranked, hasLength(2));
      expect(ranked.first.backendUrl, managed.backendUrl);
    },
  );
}
