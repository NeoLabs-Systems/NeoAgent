import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'local_runtime_paths.dart';
import 'runtime_activation_service.dart';

enum LocalRuntimeAction { start, stop, restart }

class LocalRuntimeStatus {
  const LocalRuntimeStatus({
    required this.installed,
    required this.running,
    this.version,
    this.backendUrl,
    this.errorCode,
  });

  final bool installed;
  final bool running;
  final String? version;
  final String? backendUrl;
  final String? errorCode;
}

class LocalRuntimeManager {
  LocalRuntimeManager({
    LocalRuntimePaths? paths,
    RuntimeActivationService? activationService,
  }) : _paths =
           paths ??
           LocalRuntimePaths.fromEnvironment(
             Platform.environment,
             isWindows: Platform.isWindows,
           ),
       _activationService =
           activationService ?? RuntimeActivationService(onEvent: (_) {});

  final LocalRuntimePaths _paths;
  final RuntimeActivationService _activationService;

  Future<LocalRuntimeStatus> inspect() async {
    final runtimeRoot = Directory(_paths.runtimeHome);
    final version = _activationService.readCurrentVersion(runtimeRoot);
    if (version == null) {
      return const LocalRuntimeStatus(installed: false, running: false);
    }
    final versionDirectory = _versionDirectory(version);
    if (!_runtimeFilesExist(versionDirectory)) {
      return LocalRuntimeStatus(
        installed: true,
        running: false,
        version: version,
        errorCode: 'SETUP_RUNTIME_INCOMPLETE',
      );
    }
    try {
      final events = await _runCli(versionDirectory, const <String>[
        'status',
        '--json',
      ]);
      for (final event in events.reversed) {
        final result = event['result'];
        if (event['state'] != 'ready' || result is! Map) continue;
        return LocalRuntimeStatus(
          installed: true,
          running: result['running'] == true,
          version: result['version']?.toString().trim().isNotEmpty == true
              ? result['version'].toString().trim()
              : version,
          backendUrl: result['backendUrl']?.toString().trim(),
        );
      }
      return LocalRuntimeStatus(
        installed: true,
        running: false,
        version: version,
        errorCode: 'SETUP_STATUS_INVALID',
      );
    } on LocalRuntimeManagerException catch (error) {
      return LocalRuntimeStatus(
        installed: true,
        running: false,
        version: version,
        errorCode: error.code,
      );
    }
  }

  Future<LocalRuntimeStatus> runAction(LocalRuntimeAction action) async {
    final runtimeRoot = Directory(_paths.runtimeHome);
    final version = _activationService.readCurrentVersion(runtimeRoot);
    if (version == null) {
      throw const LocalRuntimeManagerException(
        'SETUP_RUNTIME_NOT_INSTALLED',
        'NeoAgent is not installed on this computer.',
      );
    }
    final versionDirectory = _versionDirectory(version);
    if (!_runtimeFilesExist(versionDirectory)) {
      throw const LocalRuntimeManagerException(
        'SETUP_RUNTIME_INCOMPLETE',
        'The local NeoAgent runtime needs repair.',
      );
    }
    await _runCli(versionDirectory, <String>[
      action.name,
      '--json',
    ], timeout: const Duration(seconds: 45));
    return inspect();
  }

  Directory _versionDirectory(String version) {
    return Directory(
      '${_paths.runtimeHome}${_paths.separator}app'
      '${_paths.separator}versions${_paths.separator}$version',
    );
  }

  bool _runtimeFilesExist(Directory versionDirectory) {
    final node = _activationService.nodeExecutable(versionDirectory);
    final cli = File(
      '${versionDirectory.path}${_paths.separator}app'
      '${_paths.separator}bin${_paths.separator}neoagent.js',
    );
    return node.existsSync() && cli.existsSync();
  }

  Future<List<Map<String, dynamic>>> _runCli(
    Directory versionDirectory,
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final node = _activationService.nodeExecutable(versionDirectory);
    final cli =
        '${versionDirectory.path}${_paths.separator}app'
        '${_paths.separator}bin${_paths.separator}neoagent.js';
    final process = await Process.start(
      node.path,
      <String>[cli, ...arguments],
      environment: <String, String>{
        ...Platform.environment,
        'NEOAGENT_HOME': _paths.runtimeHome,
      },
      workingDirectory: '${versionDirectory.path}${_paths.separator}app',
    );
    final events = <Map<String, dynamic>>[];
    final stdoutSubscription = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          try {
            final decoded = jsonDecode(line);
            if (decoded is Map<String, dynamic>) events.add(decoded);
          } on FormatException {
            // Human-readable CLI lines are intentionally ignored.
          }
        });
    final stderrSubscription = process.stderr.listen((_) {});
    int exitCode;
    try {
      exitCode = await process.exitCode.timeout(
        timeout,
        onTimeout: () {
          process.kill(ProcessSignal.sigterm);
          throw const LocalRuntimeManagerException(
            'SETUP_COMMAND_TIMEOUT',
            'The local NeoAgent command timed out.',
          );
        },
      );
    } finally {
      await stdoutSubscription.cancel();
      await stderrSubscription.cancel();
    }
    if (exitCode != 0) {
      throw LocalRuntimeManagerException(
        'SETUP_COMMAND_FAILED',
        'The local NeoAgent command exited with code $exitCode.',
      );
    }
    return events;
  }
}

class LocalRuntimeManagerException implements Exception {
  const LocalRuntimeManagerException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}
