import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'android_app_installer.dart';

const MethodChannel _androidAppInstallerChannel = MethodChannel(
  'neoagent/app_update',
);

AndroidAppInstaller createPlatformAndroidAppInstaller() =>
    _IoAndroidAppInstaller();

class _IoAndroidAppInstaller implements AndroidAppInstaller {
  _IoAndroidAppInstaller({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  bool get supported =>
      defaultTargetPlatform == TargetPlatform.android && !kIsWeb;

  @override
  Future<AndroidAppInstallResult> installApkFromUrl({
    required String downloadUrl,
    required String fileName,
    Map<String, String> headers = const <String, String>{},
  }) async {
    if (!supported) {
      return const AndroidAppInstallResult(
        launched: false,
        error: 'Android APK install is unavailable on this platform.',
      );
    }

    try {
      final canInstall = await _androidAppInstallerChannel.invokeMethod<bool>(
        'canRequestPackageInstalls',
      );
      if (canInstall != true) {
        await _androidAppInstallerChannel.invokeMethod<void>(
          'openInstallUnknownAppsSettings',
        );
        return const AndroidAppInstallResult(
          launched: false,
          error:
              'Allow "Install unknown apps" for NeoAgent, then retry the update.',
        );
      }

      final apkFile = await _downloadApk(
        downloadUrl: downloadUrl,
        fileName: fileName,
        headers: headers,
      );
      final launched = await _androidAppInstallerChannel.invokeMethod<bool>(
        'installApk',
        <String, dynamic>{'apkPath': apkFile.path},
      );
      if (launched == true) {
        return const AndroidAppInstallResult(launched: true);
      }
      return const AndroidAppInstallResult(
        launched: false,
        error: 'Android package installer could not be opened.',
      );
    } on PlatformException catch (error) {
      return AndroidAppInstallResult(
        launched: false,
        error: error.message ?? error.code,
      );
    } catch (error) {
      return AndroidAppInstallResult(launched: false, error: error.toString());
    }
  }

  Future<File> _downloadApk({
    required String downloadUrl,
    required String fileName,
    required Map<String, String> headers,
  }) async {
    final request = http.Request('GET', Uri.parse(downloadUrl));
    request.headers.addAll(headers);
    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'APK download failed with HTTP ${response.statusCode}.',
        uri: Uri.parse(downloadUrl),
      );
    }

    final directory = await getTemporaryDirectory();
    final updatesDir = Directory('${directory.path}/app_updates');
    if (!updatesDir.existsSync()) {
      updatesDir.createSync(recursive: true);
    }
    final sanitized = _sanitizeFileName(fileName);
    final file = File('${updatesDir.path}/$sanitized');
    if (file.existsSync()) {
      file.deleteSync();
    }
    final sink = file.openWrite();
    try {
      await response.stream.pipe(sink);
    } finally {
      await sink.close();
    }
    return file;
  }

  String _sanitizeFileName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'neoagent-update.apk';
    }
    return trimmed.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }
}
