import 'setup_contract.g.dart';

enum LocalBackendSetupProfile { quick, full }

enum LocalBackendInstallStage {
  prepare,
  download,
  verify,
  install,
  service,
  connect,
  complete,
}

class LocalBackendInstallEvent {
  const LocalBackendInstallEvent({
    required this.stage,
    required this.state,
    required this.message,
    this.progress,
    this.errorCode,
    this.retryable = true,
  });

  final LocalBackendInstallStage stage;
  final String state;
  final String message;
  final double? progress;
  final String? errorCode;
  final bool retryable;
}

class LocalBackendInstallResult {
  const LocalBackendInstallResult({
    required this.backendUrl,
    required this.instanceId,
    required this.serverVersion,
    this.claimToken,
    this.claimExpiresAt,
  });

  final String backendUrl;
  final String instanceId;
  final String serverVersion;
  final String? claimToken;
  final DateTime? claimExpiresAt;
}

class LocalBackendInstallerException implements Exception {
  const LocalBackendInstallerException(
    this.code,
    this.message, {
    this.retryable = true,
  });

  final String code;
  final String message;
  final bool retryable;

  @override
  String toString() => message;
}

class RuntimeArtifactManifest {
  const RuntimeArtifactManifest({
    required this.schemaVersion,
    required this.version,
    required this.artifacts,
  });

  final int schemaVersion;
  final String version;
  final List<RuntimeArtifact> artifacts;

  factory RuntimeArtifactManifest.fromJson(Map<String, dynamic> json) {
    final schemaVersion =
        int.tryParse(json['schemaVersion']?.toString() ?? '') ?? 0;
    final version = json['version']?.toString().trim() ?? '';
    final rawArtifacts = json['artifacts'];
    if (schemaVersion != setupContractSchemaVersion ||
        version.isEmpty ||
        rawArtifacts is! List) {
      throw const FormatException('Invalid NeoAgent runtime manifest.');
    }
    final artifacts = rawArtifacts
        .whereType<Map>()
        .map(
          (entry) => RuntimeArtifact.fromJson(Map<String, dynamic>.from(entry)),
        )
        .toList(growable: false);
    if (artifacts.isEmpty) {
      throw const FormatException(
        'The NeoAgent runtime manifest has no artifacts.',
      );
    }
    return RuntimeArtifactManifest(
      schemaVersion: schemaVersion,
      version: version,
      artifacts: artifacts,
    );
  }

  RuntimeArtifact select({
    required String platform,
    required String architecture,
  }) {
    final supportedArchitectures = setupRuntimeTargets[platform];
    if (supportedArchitectures == null ||
        !supportedArchitectures.contains(architecture)) {
      throw LocalBackendInstallerException(
        'SETUP_PLATFORM_UNSUPPORTED',
        'No NeoAgent backend runtime is available for this computer.',
        retryable: false,
      );
    }
    for (final artifact in artifacts) {
      if (artifact.platform == platform &&
          artifact.architecture == architecture) {
        return artifact;
      }
    }
    throw LocalBackendInstallerException(
      'SETUP_PLATFORM_UNSUPPORTED',
      'No NeoAgent backend runtime is available for this computer.',
      retryable: false,
    );
  }
}

class RuntimeArtifact {
  const RuntimeArtifact({
    required this.platform,
    required this.architecture,
    required this.assetName,
    required this.sha256,
    required this.sizeBytes,
  });

  final String platform;
  final String architecture;
  final String assetName;
  final String sha256;
  final int sizeBytes;

  factory RuntimeArtifact.fromJson(Map<String, dynamic> json) {
    final platform = json['platform']?.toString().trim() ?? '';
    final architecture = json['architecture']?.toString().trim() ?? '';
    final assetName = json['assetName']?.toString().trim() ?? '';
    final sha256 = json['sha256']?.toString().trim().toLowerCase() ?? '';
    final sizeBytes = int.tryParse(json['sizeBytes']?.toString() ?? '') ?? 0;
    if (platform.isEmpty ||
        architecture.isEmpty ||
        assetName.isEmpty ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256) ||
        sizeBytes <= 0) {
      throw const FormatException(
        'The NeoAgent runtime artifact metadata is invalid.',
      );
    }
    return RuntimeArtifact(
      platform: platform,
      architecture: architecture,
      assetName: assetName,
      sha256: sha256,
      sizeBytes: sizeBytes,
    );
  }
}
