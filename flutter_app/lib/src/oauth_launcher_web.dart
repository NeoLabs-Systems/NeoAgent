import 'dart:async';
import 'dart:html' as html;

import 'oauth_launcher.dart';

OAuthLauncher createPlatformOAuthLauncher() => _WebOAuthLauncher();

class _WebOAuthLauncher extends OAuthLauncher {
  StreamSubscription<html.MessageEvent>? _messageSubscription;
  Timer? _timeoutTimer;

  @override
  Future<OAuthLaunchResult> launch({
    required String url,
    required String provider,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final expectedOrigin = _deriveExpectedOrigin(url);
    html.window.open(
      url,
      'neoagent_oauth_${provider.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')}',
      'width=640,height=760',
    );

    final completer = Completer<OAuthLaunchResult>();

    void finish(OAuthLaunchResult result) {
      if (completer.isCompleted) return;
      _timeoutTimer?.cancel();
      _timeoutTimer = null;
      _messageSubscription?.cancel();
      _messageSubscription = null;
      completer.complete(result);
    }

    _messageSubscription = html.window.onMessage.listen((event) {
      if (expectedOrigin != null && event.origin != expectedOrigin) return;
      final data = event.data;
      if (data is! Map) return;
      final type = data['type']?.toString();
      final incomingProvider = data['provider']?.toString();
      if (incomingProvider != null && incomingProvider != provider) return;
      if (type == 'integration_oauth_success') {
        finish(const OAuthLaunchResult(launched: true, completed: true));
      } else if (type == 'integration_oauth_error') {
        finish(
          OAuthLaunchResult(
            launched: true,
            completed: false,
            error: data['error']?.toString() ?? 'Authentication failed.',
          ),
        );
      }
    });

    _timeoutTimer = Timer(timeout, () {
      finish(
        const OAuthLaunchResult(
          launched: true,
          completed: false,
          error: 'Authentication timed out.',
        ),
      );
    });

    return completer.future;
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _messageSubscription?.cancel();
    _messageSubscription = null;
  }

  String? _deriveExpectedOrigin(String url) {
    try {
      final uri = Uri.parse(url);
      final redirect = uri.queryParameters['redirect_uri'];
      if (redirect != null && redirect.trim().isNotEmpty) {
        final redirectUri = Uri.parse(redirect);
        return redirectUri.origin;
      }
      if (uri.hasScheme && uri.host.isNotEmpty) {
        return uri.origin;
      }
    } catch (_) {}
    return null;
  }
}
