import '../../src/backend_client.dart';
import 'shared_messaging_models.dart';

/// Where the admin screen reads and writes instance-wide accounts. Every write
/// answers with the full list, so the screen never shows a stale neighbour.
abstract class SharedAccountsRepository {
  Future<List<SharedAccount>> fetch();
  Future<List<SharedAccount>> save(
    String platform,
    SharedAccountChanges changes,
  );
  Future<List<SharedAccount>> remove(String platform);
}

class BackendSharedAccountsRepository implements SharedAccountsRepository {
  const BackendSharedAccountsRepository({
    required this.client,
    required this.baseUrl,
  });

  final BackendClient client;
  final String baseUrl;

  @override
  Future<List<SharedAccount>> fetch() async {
    return _decode(await client.fetchAdminMessaging(baseUrl));
  }

  @override
  Future<List<SharedAccount>> save(
    String platform,
    SharedAccountChanges changes,
  ) async {
    return _decode(
      await client.saveAdminMessaging(baseUrl, platform, changes.toJson()),
    );
  }

  @override
  Future<List<SharedAccount>> remove(String platform) async {
    return _decode(await client.removeAdminMessaging(baseUrl, platform));
  }

  List<SharedAccount> _decode(Map<String, dynamic> data) {
    final raw = data['connections'];
    if (raw is! List) return const <SharedAccount>[];
    return raw
        .whereType<Map>()
        .map(
          (entry) => SharedAccount.fromJson(Map<String, dynamic>.from(entry)),
        )
        .toList(growable: false);
  }
}
