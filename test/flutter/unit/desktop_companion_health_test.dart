import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/desktop_companion_health.dart';

void main() {
  final now = DateTime.utc(2026, 4, 1, 12);

  test('local companion reconnects when the socket is gone or stuck connecting', () {
    expect(
      desktopCompanionNeedsReconnect(
        enabled: true,
        authenticated: true,
        connected: true,
        connecting: false,
        socketOpen: true,
      ),
      isFalse,
    );
    expect(
      desktopCompanionNeedsReconnect(
        enabled: true,
        authenticated: true,
        connected: true,
        connecting: false,
        socketOpen: false,
      ),
      isTrue,
    );
    expect(
      desktopCompanionNeedsReconnect(
        enabled: true,
        authenticated: true,
        connected: false,
        connecting: false,
        socketOpen: false,
      ),
      isTrue,
    );
    expect(
      desktopCompanionNeedsReconnect(
        enabled: true,
        authenticated: true,
        connected: false,
        connecting: true,
        socketOpen: false,
        connectingSince: now.subtract(const Duration(seconds: 5)),
        now: now,
      ),
      isFalse,
    );
    expect(
      desktopCompanionNeedsReconnect(
        enabled: true,
        authenticated: true,
        connected: false,
        connecting: true,
        socketOpen: false,
        connectingSince: now.subtract(const Duration(seconds: 21)),
        now: now,
      ),
      isTrue,
    );
    expect(
      desktopCompanionNeedsReconnect(
        enabled: false,
        authenticated: true,
        connected: false,
        connecting: false,
        socketOpen: false,
      ),
      isFalse,
    );
  });

  test('resume force-reconnects a silent local companion after sleep', () {
    expect(
      desktopCompanionShouldForceReconnectOnResume(
        connected: true,
        socketOpen: true,
        lastInboundAt: now.subtract(const Duration(seconds: 10)),
        now: now,
      ),
      isFalse,
    );
    expect(
      desktopCompanionShouldForceReconnectOnResume(
        connected: true,
        socketOpen: true,
        lastInboundAt: now.subtract(const Duration(seconds: 31)),
        now: now,
      ),
      isTrue,
    );
    expect(
      desktopCompanionShouldForceReconnectOnResume(
        connected: true,
        socketOpen: false,
        lastInboundAt: now,
        now: now,
      ),
      isTrue,
    );
  });
}
