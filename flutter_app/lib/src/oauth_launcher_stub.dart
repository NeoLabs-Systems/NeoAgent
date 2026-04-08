import 'oauth_launcher.dart';

OAuthLauncher createPlatformOAuthLauncher() => _StubOAuthLauncher();

class _StubOAuthLauncher extends OAuthLauncher {
  _StubOAuthLauncher();

  @override
  Future<OAuthLaunchResult> launch({
    required String url,
    required String provider,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    return const OAuthLaunchResult(
      launched: false,
      completed: false,
      error: 'OAuth launch is not supported on this platform.',
    );
  }

  @override
  Future<OAuthLaunchResult> openExternal({
    required String url,
    required String label,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return const OAuthLaunchResult(
      launched: false,
      completed: false,
      error: 'External browser launch is not supported on this platform.',
    );
  }
}
