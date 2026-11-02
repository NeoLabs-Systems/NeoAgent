/// An instance-wide account a user can link to on one platform.
class SharedMessagingOption {
  const SharedMessagingOption({
    required this.platform,
    required this.personalAllowed,
    this.accountLabel,
    this.linkedAgentId,
  });

  factory SharedMessagingOption.fromJson(Map<String, dynamic> json) {
    final link = json['link'];
    return SharedMessagingOption(
      platform: json['platform']?.toString() ?? '',
      personalAllowed: json['personalAllowed'] != false,
      accountLabel: json['accountLabel']?.toString(),
      linkedAgentId: link is Map ? link['agentId']?.toString() : null,
    );
  }

  final String platform;
  final bool personalAllowed;
  final String? accountLabel;
  final String? linkedAgentId;
}

/// A one-time code the user sends from the account they want to link.
class SharedMessagingLink {
  const SharedMessagingLink({
    required this.code,
    required this.expiresAt,
    this.url,
  });

  factory SharedMessagingLink.fromJson(Map<String, dynamic> json) {
    return SharedMessagingLink(
      code: json['code']?.toString() ?? '',
      expiresAt:
          DateTime.tryParse(json['expiresAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      url: json['url']?.toString(),
    );
  }

  final String code;
  final DateTime expiresAt;
  final String? url;
}

/// What the admin screen does with a connection, grouped from the server's
/// finer-grained status values.
enum SharedAccountState { notSetUp, off, starting, awaitingScan, live, failed }

/// One platform's instance-wide account, as an admin sees it.
class SharedAccount {
  const SharedAccount({
    required this.platform,
    required this.usesToken,
    required this.configured,
    required this.enabled,
    required this.available,
    required this.allowPersonal,
    required this.status,
    required this.linkedUsers,
    this.accountLabel,
    this.qr,
  });

  factory SharedAccount.fromJson(Map<String, dynamic> json) {
    final linked = json['linkedUsers'];
    return SharedAccount(
      platform: json['platform']?.toString() ?? '',
      usesToken: json['authMethod'] == 'token',
      configured: json['configured'] == true,
      enabled: json['enabled'] == true,
      available: json['available'] != false,
      allowPersonal: json['allowPersonal'] != false,
      status: json['status']?.toString() ?? 'not_configured',
      linkedUsers: linked is num ? linked.toInt() : 0,
      accountLabel: _nonEmpty(json['accountLabel']),
      qr: _nonEmpty(json['qr']),
    );
  }

  final String platform;
  final bool usesToken;
  final bool configured;
  final bool enabled;
  final bool available;
  final bool allowPersonal;
  final String status;
  final int linkedUsers;
  final String? accountLabel;
  final String? qr;

  SharedAccountState get state {
    if (!configured) return SharedAccountState.notSetUp;
    return switch (status) {
      'connected' => SharedAccountState.live,
      'awaiting_qr' => SharedAccountState.awaitingScan,
      'connecting' || 'reconnecting' => SharedAccountState.starting,
      'error' || 'logged_out' => SharedAccountState.failed,
      _ => SharedAccountState.off,
    };
  }
}

/// A partial update: fields left null keep their value on the server.
class SharedAccountChanges {
  const SharedAccountChanges({
    this.botToken,
    this.enabled,
    this.available,
    this.allowPersonal,
    this.reconnect,
  });

  final String? botToken;
  final bool? enabled;
  final bool? available;
  final bool? allowPersonal;
  final bool? reconnect;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (botToken != null) 'botToken': botToken,
    if (enabled != null) 'enabled': enabled,
    if (available != null) 'available': available,
    if (allowPersonal != null) 'allowPersonal': allowPersonal,
    if (reconnect != null) 'reconnect': reconnect,
  };
}

String? _nonEmpty(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
