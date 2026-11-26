
const String runtimeReleaseChannel = String.fromEnvironment(
  'NEOAGENT_RELEASE_CHANNEL',
  defaultValue: 'stable',
);

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
