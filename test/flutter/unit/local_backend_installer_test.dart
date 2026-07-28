import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/local_backend_installer.dart';
import 'package:neoagent_flutter/src/local_runtime_manager.dart';
import 'package:neoagent_flutter/src/local_runtime_paths.dart';
import 'package:neoagent_flutter/src/local_setup_engine.dart';
import 'package:neoagent_flutter/src/runtime_activation_service.dart';
import 'package:neoagent_flutter/src/runtime_archive_service.dart';
import 'package:neoagent_flutter/src/runtime_release_service.dart';

void main() {
  test('runtime manifest selects an exact platform and architecture', () {
    final manifest = RuntimeArtifactManifest.fromJson(<String, dynamic>{
      'schemaVersion': 1,
      'version': '3.4.0',
      'artifacts': <Map<String, dynamic>>[
        <String, dynamic>{
          'platform': 'macos',
          'architecture': 'arm64',
          'assetName': 'neoagent-runtime-macos-arm64-3.4.0.zip',
          'sha256': List<String>.filled(64, 'a').join(),
          'sizeBytes': 1024,
        },
        <String, dynamic>{
          'platform': 'windows',
          'architecture': 'x64',
          'assetName': 'neoagent-runtime-windows-x64-3.4.0.zip',
          'sha256': List<String>.filled(64, 'b').join(),
          'sizeBytes': 2048,
        },
      ],
    });

    final artifact = manifest.select(platform: 'macos', architecture: 'arm64');
    expect(artifact.assetName, 'neoagent-runtime-macos-arm64-3.4.0.zip');
    expect(
      () => manifest.select(platform: 'linux', architecture: 'arm64'),
      throwsA(
        isA<LocalBackendInstallerException>().having(
          (error) => error.code,
          'code',
          'SETUP_PLATFORM_UNSUPPORTED',
        ),
      ),
    );
  });

  test('runtime manifest rejects unsafe version paths', () {
    expect(
      () => RuntimeArtifactManifest.fromJson(<String, dynamic>{
        'schemaVersion': 1,
        'version': '../../outside',
        'artifacts': <Map<String, dynamic>>[
          <String, dynamic>{
            'platform': 'macos',
            'architecture': 'arm64',
            'assetName': 'runtime.zip',
            'sha256': List<String>.filled(64, 'a').join(),
            'sizeBytes': 1024,
          },
        ],
      }),
      throwsFormatException,
    );
  });

  test('runtime manifest rejects unsafe artifact paths', () {
    expect(
      () => RuntimeArtifact.fromJson(<String, dynamic>{
        'platform': 'macos',
        'architecture': 'arm64',
        'assetName': '../../outside.zip',
        'sha256': List<String>.filled(64, 'a').join(),
        'sizeBytes': 1024,
      }),
      throwsFormatException,
    );
  });

  test('runtime archive paths cannot escape staging', () {
    expect(isSafeRuntimeArchivePath('app/bin/neoagent.js'), true);
    expect(isSafeRuntimeArchivePath('../outside'), false);
    expect(isSafeRuntimeArchivePath(r'C:\outside'), false);
    expect(
      isSafeRuntimeArchivePath('../../outside', basePath: 'app/bin'),
      true,
    );
    expect(
      isSafeRuntimeArchivePath('../../../outside', basePath: 'app/bin'),
      false,
    );
  });

  test('runtime downloads accept only HTTPS addresses', () {
    expect(
      validateRuntimeDownloadUri('https://github.com/NeoAgent').scheme,
      'https',
    );
    expect(
      () => validateRuntimeDownloadUri('http://github.com/NeoAgent'),
      throwsA(
        isA<LocalBackendInstallerException>().having(
          (error) => error.code,
          'code',
          'SETUP_DOWNLOAD_URL_INVALID',
        ),
      ),
    );
  });

  test(
    'runtime manifest signature accepts only the matching Ed25519 key',
    () async {
      final algorithm = Ed25519();
      final keyPair = await algorithm.newKeyPair();
      final publicKey = await keyPair.extractPublicKey();
      final manifestBytes = utf8.encode('{"schemaVersion":1}');
      final signature = await algorithm.sign(manifestBytes, keyPair: keyPair);

      await verifyRuntimeManifestSignature(
        manifestBytes: manifestBytes,
        signatureBase64: base64Encode(signature.bytes),
        publicKeyBase64: base64Encode(publicKey.bytes),
      );

      await expectLater(
        verifyRuntimeManifestSignature(
          manifestBytes: utf8.encode('{"schemaVersion":2}'),
          signatureBase64: base64Encode(signature.bytes),
          publicKeyBase64: base64Encode(publicKey.bytes),
        ),
        throwsA(
          isA<LocalBackendInstallerException>().having(
            (error) => error.code,
            'code',
            'SETUP_MANIFEST_SIGNATURE_INVALID',
          ),
        ),
      );
    },
  );

  test('setup engine parser accepts only versioned complete events', () {
    final parsed = parseSetupEngineEvent(
      jsonEncode(<String, dynamic>{
        'schemaVersion': 1,
        'runId': 'setup-run',
        'profile': 'quick',
        'stage': 'complete',
        'state': 'ready',
        'message': 'NeoAgent is ready',
        'result': <String, dynamic>{
          'backendUrl': 'http://localhost:4444',
          'instanceId': 'instance-id',
          'serverVersion': '3.4.0',
        },
      }),
    );
    expect(parsed, isNotNull);
    expect(parsed!.$1.stage, LocalBackendInstallStage.connect);
    expect(parsed.$2?.backendUrl, 'http://localhost:4444');
    expect(
      parseSetupEngineEvent(
        jsonEncode(<String, dynamic>{
          'schemaVersion': 2,
          'stage': 'complete',
          'state': 'ready',
        }),
      ),
      isNull,
    );
  });

  test(
    'runtime activation returns and restores the current version marker',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'neoagent-activation-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final events = <LocalBackendInstallEvent>[];
      final activation = RuntimeActivationService(onEvent: events.add);

      expect(await activation.activate(directory, '3.3.0'), isNull);
      expect(activation.readCurrentVersion(directory), '3.3.0');
      expect(await activation.activate(directory, '3.4.0'), '3.3.0');
      expect(activation.readCurrentVersion(directory), '3.4.0');
      expect(
        directory
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.tmp')),
        isEmpty,
      );
    },
  );

  test(
    'runtime manager reports a missing local runtime without prerequisites',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'neoagent-runtime-manager-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final paths = LocalRuntimePaths.fromEnvironment(<String, String>{
        if (Platform.isWindows) 'USERPROFILE': directory.path,
        if (!Platform.isWindows) 'HOME': directory.path,
        'NEOAGENT_HOME': '${directory.path}${Platform.pathSeparator}runtime',
      }, isWindows: Platform.isWindows);
      final manager = LocalRuntimeManager(paths: paths);

      final status = await manager.inspect();
      expect(status.installed, false);
      expect(status.running, false);
      expect(status.errorCode, isNull);
    },
  );
}
