import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/desktop_companion.dart';
import 'package:neoagent_flutter/src/desktop_companion_actions.dart';
import 'package:neoagent_flutter/src/desktop_command_output.dart';
import 'package:neoagent_flutter/src/desktop_screen_capture.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _UnsupportedScreenCapture implements DesktopScreenCapture {
  @override
  bool get isSupported => false;

  @override
  Future<DesktopScreenCaptureResult?> captureCurrentScreen() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('desktop display selection validates IDs and resolves primary', () {
    final displays = <Map<String, Object?>>[
      <String, Object?>{'id': 'left', 'primary': false},
      <String, Object?>{'id': 'main', 'primary': true},
    ];

    expect(resolveDesktopDisplaySelection(displays, 'primary'), 'main');
    expect(resolveDesktopDisplaySelection(displays, 'left'), 'left');
    expect(
      resolveDesktopDisplaySelection(
        <Map<String, Object?>>[
          <String, Object?>{'id': 'left'},
          <String, Object?>{'id': 'right'},
        ],
        'primary',
        activeDisplayId: 'right',
      ),
      'right',
    );
    expect(
      () => resolveDesktopDisplaySelection(displays, 'missing'),
      throwsArgumentError,
    );
    expect(
      () => resolveDesktopDisplaySelection(const <Object?>[], 'main'),
      throwsStateError,
    );
  });

  test(
    'desktop shell command captures output and reports PTY truthfully',
    () async {
      final actions = DesktopCompanionActions(
        screenCapture: _UnsupportedScreenCapture(),
      );

      final result = await actions.executeShellCommand(
        commandId: 'quick-command',
        command: Platform.isWindows ? 'echo ready' : 'printf ready',
        requestedPty: true,
      );

      expect(result['exitCode'], 0);
      expect(result['stdout'], 'ready');
      expect(result['ptyRequested'], isTrue);
      expect(result['ptyAllocated'], isFalse);
    },
  );

  test('desktop shell cancellation terminates the tracked process', () async {
    final actions = DesktopCompanionActions(
      screenCapture: _UnsupportedScreenCapture(),
    );
    final running = actions.executeShellCommand(
      commandId: 'cancel-command',
      command: Platform.isWindows ? 'ping -n 20 127.0.0.1 >NUL' : 'sleep 20',
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final cancellation = await actions.cancelShellCommand('cancel-command');
    final result = await running.timeout(const Duration(seconds: 5));

    expect(cancellation['cancelled'], isTrue);
    expect(result['cancelled'], isTrue);
    expect(result['killed'], isTrue);
  });

  test('desktop command output uses bounded head and tail evidence', () async {
    final output = DesktopCommandOutputAccumulator(
      maxArtifactBytes: 128,
      stdoutPreviewBytes: 20,
    );
    await output.initialize();
    output.add('stdout', <int>[
      ...'HEAD-'.codeUnits,
      ...List<int>.filled(300, 'x'.codeUnitAt(0)),
      ...'-TAIL'.codeUnits,
    ]);
    final result = await output.finalize();
    final file = File(result['_outputFilePath']! as String);
    try {
      expect(result['truncated'], isTrue);
      expect(result['_outputFileComplete'], isFalse);
      expect(await file.length(), lessThanOrEqualTo(128));
      final content = await file.readAsString();
      expect(content, startsWith('[stdout]\nHEAD-'));
      expect(content, contains('artifact bounded'));
      expect(content, endsWith('-TAIL'));
    } finally {
      await file.parent.delete(recursive: true);
    }
  });

  test(
    'local computer permissions distinguish once from remembered access',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final manager = DesktopCompanionManager(
        screenCapture: _UnsupportedScreenCapture(),
      );
      await manager.bootstrap(prefs);

      await manager.grantPermission('files', prefs, remember: false);
      expect(manager.grantedPermissions, contains('files'));
      expect(prefs.getStringList(localComputerPermissionsPrefsKey), isNull);

      await manager.grantPermission('shell', prefs, remember: true);
      expect(
        manager.grantedPermissions,
        containsAll(<String>['files', 'shell']),
      );
      expect(prefs.getStringList(localComputerPermissionsPrefsKey), <String>[
        'shell',
      ]);

      await manager.disconnect();
      expect(manager.grantedPermissions, isNot(contains('files')));
      expect(manager.grantedPermissions, contains('shell'));

      await manager.revokePermission('shell', prefs);
      expect(manager.grantedPermissions, isNot(contains('shell')));
      manager.dispose();
    },
  );
}
