class BackendDiscoveryCandidate {
  const BackendDiscoveryCandidate({
    required this.backendUrl,
    required this.instanceId,
    required this.displayName,
    required this.serverVersion,
    required this.claimed,
    required this.source,
    required this.isLocal,
  });

  final String backendUrl;
  final String instanceId;
  final String displayName;
  final String serverVersion;
  final bool claimed;
  final String source;
  final bool isLocal;

  factory BackendDiscoveryCandidate.fromHandshake({
    required String backendUrl,
    required Map<String, dynamic> handshake,
    required String source,
    required bool isLocal,
  }) {
    if (handshake['product'] != 'NeoAgent') {
      throw const FormatException('The discovered service is not NeoAgent.');
    }
    final protocolVersion = int.tryParse(
      handshake['protocolVersion']?.toString() ?? '',
    );
    if (protocolVersion != 1) {
      throw const FormatException(
        'The discovered NeoAgent uses an unsupported setup protocol.',
      );
    }
    final instanceId = handshake['instanceId']?.toString().trim() ?? '';
    final displayName = handshake['displayName']?.toString().trim() ?? '';
    if (instanceId.isEmpty || displayName.isEmpty) {
      throw const FormatException(
        'The discovered NeoAgent returned incomplete identity data.',
      );
    }
    return BackendDiscoveryCandidate(
      backendUrl: backendUrl.replaceFirst(RegExp(r'/$'), ''),
      instanceId: instanceId,
      displayName: displayName,
      serverVersion: handshake['serverVersion']?.toString().trim() ?? '',
      claimed: handshake['claimed'] == true,
      source: source,
      isLocal: isLocal,
    );
  }
}

List<BackendDiscoveryCandidate> rankBackendCandidates(
  Iterable<BackendDiscoveryCandidate> candidates,
) {
  final byInstanceId = <String, BackendDiscoveryCandidate>{};
  for (final candidate in candidates) {
    final existing = byInstanceId[candidate.instanceId];
    if (existing == null ||
        _candidatePriority(candidate) < _candidatePriority(existing)) {
      byInstanceId[candidate.instanceId] = candidate;
    }
  }
  final ranked = byInstanceId.values.toList(growable: false);
  ranked.sort((left, right) {
    final priority = _candidatePriority(
      left,
    ).compareTo(_candidatePriority(right));
    if (priority != 0) return priority;
    return left.displayName.toLowerCase().compareTo(
      right.displayName.toLowerCase(),
    );
  });
  return ranked;
}

int _candidatePriority(BackendDiscoveryCandidate candidate) {
  if (candidate.source == 'managed-runtime') return 0;
  if (candidate.isLocal) return 1;
  if (candidate.source == 'mdns') return 2;
  return 3;
}
