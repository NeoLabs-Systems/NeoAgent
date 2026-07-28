import 'backend_discovery_models.dart';

class BackendDiscoveryService {
  Future<List<BackendDiscoveryCandidate>> discover({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    return const <BackendDiscoveryCandidate>[];
  }

  void dispose() {}
}
