import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'local_backend_installer_models.dart';
import 'local_runtime_paths.dart';
import 'local_setup_engine.dart';
import 'runtime_activation_service.dart';
import 'runtime_archive_service.dart';
import 'runtime_release_service.dart';

class LocalBackendInstaller {
  LocalBackendInstaller({http.Client? client})
    : _httpClient = client ?? http.Client() {
    _setupEngine = LocalSetupEngine(
      onEvent: (event) {
        if (!_events.isClosed) _events.add(event);
      },
    );
    _releaseService = RuntimeReleaseService(
      client: _httpClient,
      checkCancelled: _throwIfCancelled,
      onDownloadProgress: (progress) {
        _emit(
          LocalBackendInstallStage.download,
          'progress',
          'Downloading the NeoAgent backend',
          progress: 0.12 + progress * 0.36,
        );
      },
    );
    _activationService = RuntimeActivationService(
      onEvent: (event) {
        if (!_events.isClosed) _events.add(event);
      },
    );
  }

  final http.Client _httpClient;
  late final LocalSetupEngine _setupEngine;
  late final RuntimeReleaseService _releaseService;
  late final RuntimeActivationService _activationService;
  final StreamController<LocalBackendInstallEvent> _events =
      StreamController<LocalBackendInstallEvent>.broadcast();
  bool _cancelled = false;
  bool _disposed = false;

  Stream<LocalBackendInstallEvent> get events => _events.stream;

  Future<LocalBackendInstallResult> install(
    LocalBackendSetupProfile profile,
  ) async {
    if (_disposed) {
      throw const LocalBackendInstallerException(
        'SETUP_INSTALLER_DISPOSED',
        'The installer is no longer available.',
        retryable: false,
      );
    }
    _cancelled = false;
    _emit(
      LocalBackendInstallStage.prepare,
      'started',
      'Finding the correct NeoAgent runtime',
      progress: 0.02,
    );
    Directory? stagingDirectory;
    File? archiveFile;
    try {
      final release = await _releaseService.prepare(
        platform: _platformName(),
        architecture: _architectureName(),
      );
      final artifact = release.artifact;

      final paths = LocalRuntimePaths.fromEnvironment(
        Platform.environment,
        isWindows: Platform.isWindows,
      );
      final runtimeRoot = Directory(paths.runtimeHome);
      final versionsRoot = Directory(
        '${runtimeRoot.path}${Platform.pathSeparator}app'
        '${Platform.pathSeparator}versions',
      );
      versionsRoot.createSync(recursive: true);
      stagingDirectory = await Directory(
        '${versionsRoot.path}${Platform.pathSeparator}.staging-',
      ).createTemp();
      archiveFile = File(
        '${stagingDirectory.path}${Platform.pathSeparator}${artifact.assetName}',
      );

      _emit(
        LocalBackendInstallStage.download,
        'started',
        'Downloading the NeoAgent backend',
        progress: 0.12,
      );
      await _releaseService.downloadArtifact(release, archiveFile);
      _throwIfCancelled();

      _emit(
        LocalBackendInstallStage.verify,
        'started',
        'Verifying the downloaded runtime',
        progress: 0.5,
      );
      final digest = await sha256.bind(archiveFile.openRead()).first;
      if (digest.toString() != artifact.sha256) {
        throw const LocalBackendInstallerException(
          'SETUP_RUNTIME_HASH_MISMATCH',
          'The downloaded NeoAgent runtime did not pass verification.',
        );
      }

      final extractedDirectory = Directory(
        '${stagingDirectory.path}${Platform.pathSeparator}extracted',
      );
      extractedDirectory.createSync(recursive: true);
      _emit(
        LocalBackendInstallStage.install,
        'started',
        'Installing NeoAgent',
        progress: 0.58,
      );
      await extractVerifiedRuntimeArchive(
        archiveFile.path,
        extractedDirectory.path,
      );
      _activationService.validateExtractedRuntime(extractedDirectory);
      final versionDirectory = Directory(
        '${versionsRoot.path}${Platform.pathSeparator}${release.manifest.version}',
      );
      if (!versionDirectory.existsSync()) {
        extractedDirectory.renameSync(versionDirectory.path);
      }
      final previousVersion = await _activationService.activate(
        runtimeRoot,
        release.manifest.version,
      );
      _throwIfCancelled();

      LocalBackendInstallResult result;
      try {
        result = await _setupEngine.run(
          versionDirectory: versionDirectory,
          paths: paths,
          profile: profile,
          nodeExecutable: _activationService.nodeExecutable(versionDirectory),
        );
      } on Object {
        await _activationService.rollback(
          runtimeRoot: runtimeRoot,
          paths: paths,
          failedVersion: release.manifest.version,
          previousVersion: previousVersion,
        );
        rethrow;
      }
      _emit(
        LocalBackendInstallStage.complete,
        'completed',
        'NeoAgent is ready',
        progress: 1,
      );
      return result;
    } on LocalBackendInstallerException catch (error) {
      _emit(
        LocalBackendInstallStage.install,
        'failed',
        error.message,
        errorCode: error.code,
        retryable: error.retryable,
      );
      rethrow;
    } on Object catch (error) {
      final wrapped = LocalBackendInstallerException(
        'SETUP_INSTALL_FAILED',
        error.toString(),
      );
      _emit(
        LocalBackendInstallStage.install,
        'failed',
        wrapped.message,
        errorCode: wrapped.code,
      );
      throw wrapped;
    } finally {
      try {
        archiveFile?.deleteSync();
      } on Object {
        _emit(
          LocalBackendInstallStage.install,
          'message',
          'A temporary download will be cleaned up later.',
        );
      }
      try {
        stagingDirectory?.deleteSync(recursive: true);
      } on Object {
        _emit(
          LocalBackendInstallStage.install,
          'message',
          'Temporary setup files will be cleaned up later.',
        );
      }
    }
  }

  String _platformName() {
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    throw const LocalBackendInstallerException(
      'SETUP_PLATFORM_UNSUPPORTED',
      'Local backend installation is not available on this platform.',
      retryable: false,
    );
  }

  String _architectureName() {
    final abi = Abi.current().toString().toLowerCase();
    if (abi.contains('arm64')) {
      return 'arm64';
    }
    return 'x64';
  }

  void _emit(
    LocalBackendInstallStage stage,
    String state,
    String message, {
    double? progress,
    String? errorCode,
    bool retryable = true,
  }) {
    if (_events.isClosed) return;
    _events.add(
      LocalBackendInstallEvent(
        stage: stage,
        state: state,
        message: message,
        progress: progress,
        errorCode: errorCode,
        retryable: retryable,
      ),
    );
  }

  void _throwIfCancelled() {
    if (_cancelled) {
      throw const LocalBackendInstallerException(
        'SETUP_CANCELLED',
        'Setup was cancelled.',
      );
    }
  }

  void cancel() {
    _cancelled = true;
    _setupEngine.cancel();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    cancel();
    _httpClient.close();
    unawaited(_events.close());
  }
}

Future<void> verifyRuntimeManifestSignature({
  required List<int> manifestBytes,
  required String signatureBase64,
  required String publicKeyBase64,
}) {
  return verifyRuntimeManifestSignatureData(
    manifestBytes: manifestBytes,
    signatureBase64: signatureBase64,
    publicKeyBase64: publicKeyBase64,
  );
}
