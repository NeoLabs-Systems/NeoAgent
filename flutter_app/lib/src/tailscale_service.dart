import 'backend_client.dart';

class TailscalePeer {
  const TailscalePeer({required this.id, required this.name});
  final String id;
  final String name;
}

class TailscaleGrant {
  const TailscaleGrant({
    required this.peerId,
    required this.port,
    required this.scheme,
    required this.path,
    required this.methods,
  });
  final String peerId;
  final int port;
  final String scheme;
  final String path;
  final List<String> methods;

  Map<String, Object> toJson() => <String, Object>{
    'peerId': peerId,
    'port': port,
    'scheme': scheme,
    'path': path,
    'methods': methods,
  };
}

class TailscaleAccess {
  const TailscaleAccess({required this.peers, required this.services});
  final List<TailscalePeer> peers;
  final List<TailscaleGrant> services;
}

class TailscaleService {
  const TailscaleService(this.client);
  final BackendClient client;

  Future<bool> waitForSignIn(
    String baseUrl,
    String sessionId,
    String? agentId,
    bool Function() isActive,
  ) async {
    final query = agentId == null
        ? ''
        : '?agentId=${Uri.encodeQueryComponent(agentId)}';
    final deadline = DateTime.now().add(const Duration(minutes: 5));
    while (isActive() && DateTime.now().isBefore(deadline)) {
      final result = await client.getMap(
        baseUrl,
        '/api/integrations/tailscale/connect/${Uri.encodeComponent(sessionId)}/status$query',
      );
      if (!isActive()) return false;
      if (result['status'] == 'connected') return true;
      if (result['status'] == 'failed') {
        throw StateError(
          result['error']?.toString() ?? 'Tailscale sign-in ended.',
        );
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    if (!isActive()) return false;
    throw StateError('Tailscale sign-in expired. Please connect again.');
  }

  Future<void> cancelSignIn(
    String baseUrl,
    String sessionId,
    String? agentId,
  ) async {
    final query = agentId == null
        ? ''
        : '?agentId=${Uri.encodeQueryComponent(agentId)}';
    await client.deleteMap(
      baseUrl,
      '/api/integrations/tailscale/connect/${Uri.encodeComponent(sessionId)}$query',
    );
  }

  Future<TailscaleAccess> load(
    String baseUrl,
    int connectionId,
    String? agentId,
  ) async {
    final query = agentId == null
        ? ''
        : '?agentId=${Uri.encodeQueryComponent(agentId)}';
    final response = await client.getMap(
      baseUrl,
      '/api/integrations/tailscale/connections/$connectionId/services$query',
    );
    final rawPeers = response['peers'];
    final rawServices = response['services'];
    if (rawPeers is! List || rawServices is! List) {
      throw const FormatException('Invalid Tailscale service configuration.');
    }
    return TailscaleAccess(
      peers: rawPeers.map((Object? value) {
        if (value is! Map ||
            value['id'] is! String ||
            value['name'] is! String) {
          throw const FormatException('Invalid Tailscale peer.');
        }
        return TailscalePeer(
          id: value['id'] as String,
          name: value['name'] as String,
        );
      }).toList(),
      services: rawServices.map((Object? value) {
        if (value is! Map ||
            value['peerId'] is! String ||
            value['port'] is! int ||
            value['scheme'] is! String ||
            value['path'] is! String ||
            value['methods'] is! List) {
          throw const FormatException('Invalid Tailscale service.');
        }
        return TailscaleGrant(
          peerId: value['peerId'] as String,
          port: value['port'] as int,
          scheme: value['scheme'] as String,
          path: value['path'] as String,
          methods: (value['methods'] as List).cast<String>(),
        );
      }).toList(),
    );
  }

  Future<void> save(
    String baseUrl,
    int connectionId,
    String? agentId,
    List<TailscaleGrant> grants,
  ) async {
    await client.putMap(
      baseUrl,
      '/api/integrations/tailscale/connections/$connectionId/services',
      <String, Object?>{
        'agentId': agentId,
        'services': grants.map((grant) => grant.toJson()).toList(),
      },
    );
  }
}
