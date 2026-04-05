import 'dart:async';
import 'dart:html' as html;

import 'oauth_launcher.dart';

OAuthLauncher createPlatformOAuthLauncher() => _WebOAuthLauncher();

class _WebOAuthLauncher extends OAuthLauncher {
  StreamSubscription<html.MessageEvent>? _messageSubscription;

  @override
  Future<OAuthLaunchResult> launch({
    required String url,
    required String provider,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final popup = html.window.open(
      url,
      'neoagent_oauth_${provider.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')}',
      'width=640,height=760',
    );
    if (popup == null) {
      return const OAuthLaunchResult(
        launched: false,
        completed: false,
        error: 'Popup blocked. Allow popups and try again.',
      );
    }

    final completer = Completer<OAuthLaunchResult>();
    Timer? timeoutTimer;

    void finish(OAuthLaunchResult result) {
      if (completer.isCompleted) return;
      timeoutTimer?.cancel();
      _messageSubscription?.cancel();
      _messageSubscription = null;
      completer.complete(result);
    }

    _messageSubscription = html.window.onMessage.listen((event) {
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

    timeoutTimer = Timer(timeout, () {
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
    _messageSubscription?.cancel();
    _messageSubscription = null;
  }
}
