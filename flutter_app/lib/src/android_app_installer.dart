import 'android_app_installer_stub.dart'
    if (dart.library.io) 'android_app_installer_io.dart';

AndroidAppInstaller createAndroidAppInstaller() =>
    createPlatformAndroidAppInstaller();

abstract class AndroidAppInstaller {
  bool get supported;

  Future<AndroidAppInstallResult> installApkFromUrl({
    required String downloadUrl,
    required String fileName,
    Map<String, String> headers = const <String, String>{},
  });
}

class AndroidAppInstallResult {
  const AndroidAppInstallResult({required this.launched, this.error});

  final bool launched;
  final String? error;
}
