import 'backend_client.dart';
import 'local_runtime_manager.dart';

/// Bringing OpenClaw or Hermes Agent over from the app, through the admin
/// import API (server/services/admin/agent_import.js). Everything it writes
/// loads at the server's next start.

/// What one install holds of one part, e.g. 3 skills and their names.
class ImportContent {
  const ImportContent({
    required this.part,
    required this.count,
    required this.names,
    this.days = 0,
  });

  factory ImportContent.fromJson(Map<String, dynamic> json) {
    return ImportContent(
      part: json['part']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      names: _stringList(json['names']),
      days: (json['days'] as num?)?.toInt() ?? 0,
    );
  }

  /// `agents`, or one of [ImportSources.parts].
  final String part;
  final int count;
  final List<String> names;

  /// Days of daily notes, for `memories`.
  final int days;
}

class ImportSource {
  const ImportSource({
    required this.id,
    required this.label,
    required this.path,
    required this.contents,
    required this.needsHand,
  });

  factory ImportSource.fromJson(Map<String, dynamic> json) {
    return ImportSource(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      contents: _maps(json['contents']).map(ImportContent.fromJson).toList(),
      needsHand: (json['needsHand'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String label;
  final String path;
  final List<ImportContent> contents;

  /// Items the importer cannot translate and will list as left behind.
  final int needsHand;

  bool holds(String part) => contents.any((content) => content.part == part);
}

class ImportSources {
  const ImportSources({
    required this.sources,
    required this.parts,
    required this.aiReady,
  });

  factory ImportSources.fromJson(Map<String, dynamic> json) {
    return ImportSources(
      sources: _maps(json['sources']).map(ImportSource.fromJson).toList(),
      parts: _stringList(json['parts']),
      aiReady: json['aiReady'] == true,
    );
  }

  final List<ImportSource> sources;

  /// Every part the user can leave out, in the server's order.
  final List<String> parts;

  /// Whether an AI is connected, which the finish task needs.
  final bool aiReady;

  /// The parts at least one found install has something for.
  List<String> get offeredParts => parts
      .where((part) => sources.any((source) => source.holds(part)))
      .toList(growable: false);
}

/// What the user chose: which installs, which parts, and whether the agent
/// should finish what the importer leaves behind. Starts with everything.
class ImportSelection {
  ImportSelection.everything(ImportSources found)
    : sourceIds = found.sources.map((source) => source.id).toSet(),
      parts = found.parts.toSet();

  final Set<String> sourceIds;
  final Set<String> parts;
  bool finish = true;

  bool get canRun => sourceIds.isNotEmpty;

  void toggleSource(String id, bool selected) =>
      selected ? sourceIds.add(id) : sourceIds.remove(id);

  void togglePart(String part, bool selected) =>
      selected ? parts.add(part) : parts.remove(part);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sources': sourceIds.toList(),
    'parts': parts.toList(),
    'finish': finish,
  };
}

class ImportAttention {
  const ImportAttention({
    required this.kind,
    required this.name,
    required this.detail,
    required this.failed,
  });

  factory ImportAttention.fromJson(Map<String, dynamic> json) {
    return ImportAttention(
      kind: json['kind']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      detail: json['detail']?.toString() ?? '',
      failed: json['status'] == 'failed',
    );
  }

  final String kind;
  final String name;
  final String detail;
  final bool failed;
}

class ImportSummary {
  const ImportSummary({
    required this.broughtOver,
    required this.alreadyThere,
    required this.attention,
    required this.attentionTotal,
    required this.reportFile,
    required this.finishTask,
    required this.restartRequired,
  });

  factory ImportSummary.fromJson(Map<String, dynamic> json) {
    return ImportSummary(
      broughtOver: _stringList(json['broughtOver']),
      alreadyThere: (json['alreadyThere'] as num?)?.toInt() ?? 0,
      attention: _maps(
        json['attention'],
      ).map(ImportAttention.fromJson).toList(),
      attentionTotal: (json['attentionTotal'] as num?)?.toInt() ?? 0,
      reportFile: json['reportFile']?.toString() ?? '',
      finishTask: json['finishTask']?.toString(),
      restartRequired: json['restartRequired'] == true,
    );
  }

  /// Totals per kind, as the importer words them ("12 memories").
  final List<String> broughtOver;
  final int alreadyThere;
  final List<ImportAttention> attention;
  final int attentionTotal;

  /// The Markdown report on the server's disk.
  final String reportFile;

  /// The queued "finish moving in" automation, when one was queued.
  final String? finishTask;
  final bool restartRequired;
}

class AgentImportService {
  AgentImportService({
    required BackendClient client,
    required String baseUrl,
    LocalRuntimeManager? localRuntime,
    bool Function(String? runtimeBackendUrl)? isLocalBackend,
  }) : _client = client,
       _baseUrl = baseUrl,
       _localRuntime = localRuntime,
       _isLocalBackend = isLocalBackend;

  final BackendClient _client;
  final String _baseUrl;
  final LocalRuntimeManager? _localRuntime;
  final bool Function(String?)? _isLocalBackend;

  Future<ImportSources> fetchSources() async {
    return ImportSources.fromJson(
      await _client.getMap(_baseUrl, '/api/admin/import/sources'),
    );
  }

  Future<ImportSummary> run(ImportSelection selection) async {
    return ImportSummary.fromJson(
      await _client.postMap(_baseUrl, '/api/admin/import', selection.toJson()),
    );
  }

  /// Whether this app runs the server it imported into, so it can restart it
  /// itself instead of asking the user to.
  Future<bool> canRestartServer() async {
    final runtime = _localRuntime;
    final isLocal = _isLocalBackend;
    if (runtime == null || isLocal == null) return false;
    try {
      final status = await runtime.inspect();
      return status.running && isLocal(status.backendUrl);
    } on Object {
      return false;
    }
  }

  Future<void> restartServer() async {
    await _localRuntime?.runAction(LocalRuntimeAction.restart);
  }
}

List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map<dynamic, dynamic>>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value.map((item) => item.toString()).toList(growable: false);
}
