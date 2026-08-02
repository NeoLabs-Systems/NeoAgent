// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;

import 'oauth_launcher.dart';

OAuthLauncher createPlatformOAuthLauncher() => _WebOAuthLauncher();

class _WebOAuthLauncher extends OAuthLauncher {
  StreamSubscription<html.MessageEvent>? _messageSubscription;
  StreamSubscription<html.MessageEvent>? _broadcastSubscription;
  Timer? _timeoutTimer;
  html.BroadcastChannel? _channel;

  @override
  Future<OAuthLaunchResult> launch({
    required String url,
    required String provider,
    // 2FA + consent can take longer than a bare password login.
    Duration timeout = const Duration(minutes: 5),
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
      _broadcastSubscription?.cancel();
      _broadcastSubscription = null;
      try {
        _channel?.close();
      } catch (_) {}
      _channel = null;
      completer.complete(result);
    }

    bool acceptOrigin(String origin) {
      if (expectedOrigin == null || expectedOrigin.isEmpty) return true;
      if (origin == expectedOrigin) return true;
      // PUBLIC_URL may be https://host while the app is opened at
      // http://localhost or 127.0.0.1 — still accept the live page origin.
      try {
        if (origin == html.window.location.origin) return true;
      } catch (_) {}
      return false;
    }

    void handlePayload(dynamic data) {
      if (data is! Map) return;
      final type = data['type']?.toString();
      final incomingProvider = data['provider']?.toString();
      if (incomingProvider != null &&
          incomingProvider.isNotEmpty &&
          incomingProvider != provider) {
        return;
      }
      if (type == 'integration_oauth_success' || type == 'auth_oauth_success') {
        finish(const OAuthLaunchResult(launched: true, completed: true));
      } else if (type == 'integration_oauth_error' ||
          type == 'auth_oauth_error') {
        finish(
          OAuthLaunchResult(
            launched: true,
            completed: false,
            error: data['error']?.toString() ?? 'Authentication failed.',
          ),
        );
      }
    }

    _messageSubscription = html.window.onMessage.listen((event) {
      if (!acceptOrigin(event.origin)) return;
      handlePayload(event.data);
    });

    // Callback pages also broadcast on this channel so completion works even
    // when postMessage origin filtering is too strict (localhost vs PUBLIC_URL).
    try {
      _channel = html.BroadcastChannel('neoagent_oauth');
      _broadcastSubscription = _channel!.onMessage.listen((event) {
        handlePayload(event.data);
      });
    } catch (_) {
      // BroadcastChannel is unavailable in some embedded WebViews.
    }

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
  Future<OAuthLaunchResult> openExternal({
    required String url,
    required String label,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    html.window.open(
      url,
      label.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_'),
      'noopener',
    );
    return const OAuthLaunchResult(launched: true, completed: false);
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _broadcastSubscription?.cancel();
    _broadcastSubscription = null;
    try {
      _channel?.close();
    } catch (_) {}
    _channel = null;
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
