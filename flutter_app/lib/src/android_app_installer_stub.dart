import 'android_app_installer.dart';

AndroidAppInstaller createPlatformAndroidAppInstaller() =>
    _UnsupportedAndroidAppInstaller();

class _UnsupportedAndroidAppInstaller implements AndroidAppInstaller {
  @override
  bool get supported => false;

  @override
  Future<AndroidAppInstallResult> installApkFromUrl({
    required String downloadUrl,
    required String fileName,
    Map<String, String> headers = const <String, String>{},
  }) async {
    return const AndroidAppInstallResult(
      launched: false,
      error: 'Android APK install is unavailable on this platform.',
    );
  }
}
