import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/local_runtime_manager.dart';
import 'package:neoagent_flutter/src/local_runtime_paths.dart';

LocalRuntimeManager _managerFor(Directory runtimeHome) {
  return LocalRuntimeManager(
    paths: LocalRuntimePaths.fromEnvironment(<String, String>{
      'HOME': runtimeHome.path,
      'NEOAGENT_HOME': runtimeHome.path,
    }, isWindows: false),
  );
}

void main() {
  test('reads the tail of both local log files from disk', () async {
    final runtimeHome = Directory.systemTemp.createTempSync('neoagent-logs-');
    addTearDown(() => runtimeHome.deleteSync(recursive: true));
    final logDirectory = Directory('${runtimeHome.path}/data/logs')
      ..createSync(recursive: true);
    File(
      '${logDirectory.path}/neoagent.log',
    ).writeAsStringSync(List<String>.generate(20, (i) => 'line $i').join('\n'));
    File(
      '${logDirectory.path}/neoagent.error.log',
    ).writeAsStringSync('boom\n');

    final logs = await _managerFor(runtimeHome).readRecentLogs(maxLines: 5);

    expect(logs.length, 2);
    expect(logs.first.path, '${logDirectory.path}/neoagent.log');
    expect(logs.first.content, 'line 15\nline 16\nline 17\nline 18\nline 19');
    expect(logs.last.path, '${logDirectory.path}/neoagent.error.log');
    expect(logs.last.content, 'boom');
  });

  test('returns nothing when this computer has no runtime logs', () async {
    final runtimeHome = Directory.systemTemp.createTempSync('neoagent-logs-');
    addTearDown(() => runtimeHome.deleteSync(recursive: true));

    expect(await _managerFor(runtimeHome).readRecentLogs(), isEmpty);
  });
}
