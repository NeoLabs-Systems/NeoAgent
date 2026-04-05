import 'dart:io';

import 'oauth_launcher.dart';

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
      if (Platform.isMacOS) {
        await Process.run('open', <String>[url]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', <String>[url]);
      } else if (Platform.isWindows) {
        await Process.run('cmd', <String>['/c', 'start', '', url]);
      } else {
        return const OAuthLaunchResult(
          launched: false,
          completed: false,
          error: 'External browser launch is not supported on this platform.',
        );
      }

      return const OAuthLaunchResult(launched: true, completed: false);
    } catch (error) {
      return OAuthLaunchResult(
        launched: false,
        completed: false,
        error: error.toString(),
      );
    }
  }
}
