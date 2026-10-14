import 'android_app_installer.dart';
import 'package:neoagent_flutter/src/l10n/app_language.dart';

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
    return AndroidAppInstallResult(
      launched: false,
      error: appStrings.androidApkInstallIsUnavailableOn,
    );
  }
}
