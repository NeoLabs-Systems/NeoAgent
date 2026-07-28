import 'local_backend_installer_models.dart';

class LocalBackendInstaller {
  Stream<LocalBackendInstallEvent> get events =>
      const Stream<LocalBackendInstallEvent>.empty();

  Future<LocalBackendInstallResult> install(LocalBackendSetupProfile profile) {
    throw const LocalBackendInstallerException(
      'SETUP_PLATFORM_UNSUPPORTED',
      'Local backend installation is not available on this platform.',
      retryable: false,
    );
  }

  void cancel() {}

  void dispose() {}
}
