import 'dart:async';
import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import 'oauth_launcher.dart';
import 'error_text.dart';
import 'package:neoagent_flutter/src/l10n/app_language.dart';

OAuthLauncher createPlatformOAuthLauncher() => _IoOAuthLauncher();

class _IoOAuthLauncher extends OAuthLauncher {
  _IoOAuthLauncher();

  @override
  Future<OAuthLaunchResult> launch({
    required String url,
    required String provider,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    try {
      late final ProcessResult result;
      if (Platform.isMacOS) {
        result = await Process.run(
          'open',
          <String>[url],
        ).timeout(timeout);
      } else if (Platform.isLinux) {
        result = await Process.run(
          'xdg-open',
          <String>[url],
        ).timeout(timeout);
      } else if (Platform.isWindows) {
        result = await Process.run(
          'start',
          <String>[url],
          runInShell: true,
        ).timeout(timeout);
      } else if (Platform.isAndroid || Platform.isIOS) {
        final uri = Uri.parse(url);
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        ).timeout(timeout);
        
        if (launched) {
          return const OAuthLaunchResult(launched: true, completed: false);
        } else {
          return OAuthLaunchResult(
            launched: false,
            completed: false,
            error: appStrings.failedToLaunchExternalBrowserVia,
          );
        }
      } else {
        return OAuthLaunchResult(
          launched: false,
          completed: false,
          error: appStrings.externalBrowserLaunchIsNotSupported,
        );
      }

      if (result.exitCode != 0) {
        return OAuthLaunchResult(
          launched: false,
          completed: false,
          error: (result.stderr?.toString().trim().isNotEmpty ?? false)
              ? result.stderr.toString().trim()
              : appStrings.externalBrowserLaunchFailedWithExit(result.exitCode),
        );
      }

      return const OAuthLaunchResult(launched: true, completed: false);
    } on TimeoutException {
      return OAuthLaunchResult(
        launched: false,
        completed: false,
        error: appStrings.externalBrowserLaunchTimedOut,
      );
    } catch (error) {
      return OAuthLaunchResult(
        launched: false,
        completed: false,
        error: formatCaughtError(error),
      );
    }
  }

  @override
  Future<OAuthLaunchResult> openExternal({
    required String url,
    required String label,
    Duration timeout = const Duration(seconds: 10),
  }) {
    return launch(url: url, provider: label, timeout: timeout);
  }
}
