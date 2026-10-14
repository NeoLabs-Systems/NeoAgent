/// One-time sign-up keys as the admin API returns them
/// (server/services/access/signup_keys.js).
enum SignupKeyStatus { unused, used, revoked }

class SignupKey {
  const SignupKey({
    required this.id,
    required this.code,
    required this.label,
    required this.status,
    required this.createdAt,
    this.createdBy,
    this.usedAt,
    this.usedByUsername,
    this.usedByDeletedAccount = false,
  });

  factory SignupKey.fromJson(Map<String, dynamic> json) {
    final usedBy = json['usedBy'];
    final status = SignupKeyStatus.values.firstWhere(
      (value) => value.name == json['status'],
      orElse: () => SignupKeyStatus.revoked,
    );
    return SignupKey(
      id: (json['id'] as num).toInt(),
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      status: status,
      createdAt: _parseServerTime(json['createdAt']),
      createdBy: json['createdBy']?.toString(),
      usedAt: _parseServerTime(json['usedAt']),
      usedByUsername: usedBy is Map ? usedBy['username']?.toString() : null,
      // The redeeming account is set to null when it is erased.
      usedByDeletedAccount: status == SignupKeyStatus.used && usedBy == null,
    );
  }

  final int id;
  final String code;
  final String label;
  final SignupKeyStatus status;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? usedAt;
  final String? usedByUsername;
  final bool usedByDeletedAccount;
}

List<SignupKey> signupKeysFromResponse(Map<String, dynamic> response) {
  final rows = response['keys'];
  if (rows is! List) return const <SignupKey>[];
  return rows
      .whereType<Map<dynamic, dynamic>>()
      .map((row) => SignupKey.fromJson(Map<String, dynamic>.from(row)))
      .toList(growable: false);
}

/// The plain-text export: one key per line, ready to hand out.
String signupKeysAsText(Iterable<SignupKey> keys) {
  return '${keys.map((key) => key.code).join('\n')}\n';
}

// SQLite `datetime('now')` values are UTC without a zone marker.
DateTime? _parseServerTime(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  final iso = text.contains('T') ? text : text.replaceFirst(' ', 'T');
  return DateTime.tryParse(iso.endsWith('Z') ? iso : '${iso}Z');
}
