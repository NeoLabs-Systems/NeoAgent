import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/local_runtime_paths.dart';

void main() {
  test('uses the same default runtime layout as the server on Unix', () {
    final paths = LocalRuntimePaths.fromEnvironment(const <String, String>{
      'HOME': '/Users/neo',
    }, isWindows: false);

    expect(paths.runtimeHome, '/Users/neo/.neoagent');
    expect(paths.envFile, '/Users/neo/.neoagent/.env');
    expect(paths.dataDirectory, '/Users/neo/.neoagent/data');
    expect(paths.logFile, '/Users/neo/.neoagent/data/logs/neoagent.log');
    expect(paths.pidFile, '/Users/neo/.neoagent/data/neoagent.pid');
  });

  test('uses Windows separators and supports runtime path overrides', () {
    final paths = LocalRuntimePaths.fromEnvironment(const <String, String>{
      'USERPROFILE': r'C:\Users\Neo',
      'NEOAGENT_HOME': r'D:\NeoAgent',
      'NEOAGENT_DATA_DIR': r'E:\NeoAgentData',
      'NEOAGENT_ENV_FILE': r'F:\NeoAgentConfig\.env',
    }, isWindows: true);

    expect(paths.homeDirectory, r'C:\Users\Neo');
    expect(paths.runtimeHome, r'D:\NeoAgent');
    expect(paths.envFile, r'F:\NeoAgentConfig\.env');
    expect(paths.logFile, r'E:\NeoAgentData\logs\neoagent.log');
    expect(paths.pidFile, r'E:\NeoAgentData\neoagent.pid');
  });

  test('requires a platform home directory', () {
    expect(
      () => LocalRuntimePaths.fromEnvironment(
        const <String, String>{},
        isWindows: false,
      ),
      throwsStateError,
    );
  });
}
