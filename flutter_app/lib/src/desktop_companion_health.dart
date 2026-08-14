bool desktopCompanionNeedsReconnect({
  required bool enabled,
  required bool authenticated,
  required bool connected,
  required bool connecting,
  required bool socketOpen,
  DateTime? connectingSince,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  if (!enabled || !authenticated) return false;
  if (connecting) {
    return connectingSince == null ||
        clock.difference(connectingSince) > const Duration(seconds: 20);
  }
  return !connected || !socketOpen;
}

bool desktopCompanionShouldForceReconnectOnResume({
  required bool connected,
  required bool socketOpen,
  DateTime? lastInboundAt,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  if (!connected || !socketOpen) return true;
  if (lastInboundAt == null) return true;
  return clock.difference(lastInboundAt) > const Duration(seconds: 30);
}
