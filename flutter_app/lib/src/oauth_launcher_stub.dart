import 'oauth_launcher.dart';
import 'package:neoagent_flutter/src/l10n/app_language.dart';

OAuthLauncher createPlatformOAuthLauncher() => _StubOAuthLauncher();

class _StubOAuthLauncher extends OAuthLauncher {
  _StubOAuthLauncher();

  @override
  Future<OAuthLaunchResult> launch({
    required String url,
    required String provider,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    return OAuthLaunchResult(
      launched: false,
      completed: false,
      error: appStrings.oauthLaunchIsNotSupportedOn,
    );
  }

  @override
  Future<OAuthLaunchResult> openExternal({
    required String url,
    required String label,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return OAuthLaunchResult(
      launched: false,
      completed: false,
      error: appStrings.externalBrowserLaunchIsNotSupported,
    );
  }
}
