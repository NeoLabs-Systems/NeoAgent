import 'package:flutter/material.dart';

/// What a person needs to know about one app, grouped from the server's
/// finer-grained statuses.
enum HubAppState { live, connecting, attention, available, disabled }

/// HubAppState from a raw connection status.
HubAppState hubStateFor(String status) {
  return switch (status) {
    'connected' => HubAppState.live,
    'connecting' || 'reconnecting' || 'awaiting_qr' => HubAppState.connecting,
    // Disconnecting is a person's own choice, so the app goes back to the list
    // rather than sitting among theirs asking to be fixed.
    'not_configured' || 'disconnected' => HubAppState.available,
    'disabled' => HubAppState.disabled,
    _ => HubAppState.attention,
  };
}

/// One rarely-needed action behind an app's ⋮ menu.
class HubMenuAction {
  const HubMenuAction({
    required this.label,
    required this.onSelected,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onSelected;
  final bool destructive;
}

class HubApp {
  const HubApp({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.state,
    required this.onConnect,
    this.identity,
    this.isShared = false,
    this.menu = const <HubMenuAction>[],
  });

  final String id;
  final String label;

  /// What connecting takes, for an app not connected yet.
  final String subtitle;
  final IconData icon;
  final Color color;
  final HubAppState state;

  /// Who it is connected as, when the platform says.
  final String? identity;
  final bool isShared;
  final VoidCallback onConnect;
  final List<HubMenuAction> menu;

  /// Set up already, so it belongs with the person's own apps.
  bool get isMine =>
      state == HubAppState.live ||
      state == HubAppState.connecting ||
      state == HubAppState.attention;
}

/// An account this server provides: one button away, nothing to configure.
class HubLinkOffer {
  const HubLinkOffer({
    required this.app,
    required this.accountLabel,
    required this.onLink,
    this.onUseOwnAccount,
  });

  final HubApp app;
  final String? accountLabel;
  final VoidCallback onLink;

  /// Null when this server only allows the shared account, which also leaves
  /// nothing under Advanced.
  final VoidCallback? onUseOwnAccount;
}
