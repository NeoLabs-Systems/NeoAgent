import 'local_backend_installer_models.dart';
import 'package:neoagent_flutter/src/l10n/app_language.dart';

class LocalBackendInstaller {
  Stream<LocalBackendInstallEvent> get events =>
      const Stream<LocalBackendInstallEvent>.empty();

  Future<LocalBackendInstallResult> install(
    LocalBackendSetupProfile profile, {
    required String channel,
  }) {
    throw LocalBackendInstallerException(
      'SETUP_PLATFORM_UNSUPPORTED',
      appStrings.localBackendInstallationIsNotAvailable,
      retryable: false,
    );
  }

  void cancel() {}

  void dispose() {}
}
