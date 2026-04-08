import 'oauth_launcher_stub.dart'
    if (dart.library.html) 'oauth_launcher_web.dart'
    if (dart.library.io) 'oauth_launcher_io.dart';

OAuthLauncher createOAuthLauncher() => createPlatformOAuthLauncher();

abstract class OAuthLauncher {
  Future<OAuthLaunchResult> launch({
    required String url,
    required String provider,
    Duration timeout = const Duration(minutes: 2),
  });

  Future<OAuthLaunchResult> openExternal({
    required String url,
    required String label,
    Duration timeout = const Duration(seconds: 10),
  });

  void dispose() {}
}

class OAuthLaunchResult {
  const OAuthLaunchResult({
    required this.launched,
    required this.completed,
    this.error,
  });

  final bool launched;
  final bool completed;
  final String? error;
}
