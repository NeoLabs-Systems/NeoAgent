import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:multicast_dns/multicast_dns.dart';

import 'backend_discovery_models.dart';
import 'local_runtime_paths.dart';

class BackendDiscoveryService {
  BackendDiscoveryService({http.Client? client})
    : _httpClient = client ?? http.Client();

  static const String _serviceName = '_neoagent._tcp.local';
  final http.Client _httpClient;
  bool _disposed = false;

  Future<List<BackendDiscoveryCandidate>> discover({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_disposed) return const <BackendDiscoveryCandidate>[];
    final candidates = <BackendDiscoveryCandidate>[];
    final managedRuntimeUrl = _readManagedRuntimeUrl();
    final managedRuntimeFuture = managedRuntimeUrl == null
        ? Future<BackendDiscoveryCandidate?>.value()
        : _verify(managedRuntimeUrl, source: 'managed-runtime', isLocal: true);

    final mdns = MDnsClient();
    try {
      await mdns.start();
      final pointers = await mdns
          .lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer(_serviceName),
            timeout: timeout,
          )
          .toList();
      final serviceLists = await Future.wait(
        pointers.map(
          (pointer) => mdns
              .lookup<SrvResourceRecord>(
                ResourceRecordQuery.service(pointer.domainName),
                timeout: const Duration(milliseconds: 1500),
              )
              .toList(),
        ),
      );
      final verificationFutures = <Future<BackendDiscoveryCandidate?>>[];
      for (final service in serviceLists.expand((records) => records)) {
        final host = service.target.replaceFirst(RegExp(r'\.$'), '');
        if (host.isEmpty || service.port < 1 || service.port > 65535) {
          continue;
        }
        verificationFutures.add(
          _verify(
            'http://$host:${service.port}',
            source: 'mdns',
            isLocal: _isLocalHost(host),
          ),
        );
      }
      candidates.addAll(
        (await Future.wait(
          verificationFutures,
        )).whereType<BackendDiscoveryCandidate>(),
      );
    } on Object {
      // Discovery is best effort. Manual entry remains available.
    } finally {
      mdns.stop();
    }
    final managedRuntime = await managedRuntimeFuture;
    if (managedRuntime != null) candidates.add(managedRuntime);
    return rankBackendCandidates(candidates);
  }

  String? _readManagedRuntimeUrl() {
    try {
      final paths = LocalRuntimePaths.fromEnvironment(
        Platform.environment,
        isWindows: Platform.isWindows,
      );
      final envFile = File(paths.envFile);
      if (!envFile.existsSync()) return null;
      for (final line in envFile.readAsLinesSync()) {
        if (!line.startsWith('PORT=')) continue;
        final port = int.tryParse(line.substring('PORT='.length).trim());
        if (port != null && port > 0 && port <= 65535) {
          return 'http://localhost:$port';
        }
      }
    } on Object {
      return null;
    }
    return null;
  }

  Future<BackendDiscoveryCandidate?> _verify(
    String backendUrl, {
    required String source,
    required bool isLocal,
  }) async {
    try {
      final response = await _httpClient
          .get(Uri.parse('$backendUrl/api/setup/handshake'))
          .timeout(const Duration(milliseconds: 1500));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      return BackendDiscoveryCandidate.fromHandshake(
        backendUrl: backendUrl,
        handshake: decoded,
        source: source,
        isLocal: isLocal,
      );
    } on Object {
      return null;
    }
  }

  bool _isLocalHost(String host) {
    final lower = host.toLowerCase();
    return lower == 'localhost' ||
        lower.endsWith('.local') ||
        lower == '127.0.0.1' ||
        lower == '::1';
  }

  void dispose() {
    _disposed = true;
    _httpClient.close();
  }
}
