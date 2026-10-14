// Mirrors server/services/account/password_policy.js rule for rule, so the
// client accepts exactly the passwords the server will accept. Change both
// together.

const int minPasswordLength = 8;
const int minPasswordScore = 3;

const List<String> _commonPatterns = <String>[
  'password',
  '123456',
  'qwerty',
  'letmein',
  'welcome',
  'admin',
  'neoagent',
];

const List<String> _sequences = <String>[
  'abcdefghijklmnopqrstuvwxyz',
  '0123456789',
  'qwertyuiopasdfghjklzxcvbnm',
];

class PasswordStrengthEvaluation {
  const PasswordStrengthEvaluation({
    required this.score,
    required this.containsUserInfo,
    required this.obviousPattern,
    required this.hasMinimumLength,
    required this.isAcceptable,
  });

  final int score;
  final bool containsUserInfo;
  final bool obviousPattern;
  final bool hasMinimumLength;

  /// Whether the server's policy accepts this password.
  final bool isAcceptable;
}

bool hasSequentialPattern(String password) {
  final value = password.toLowerCase();
  for (final sequence in _sequences) {
    for (var index = 0; index <= sequence.length - 4; index += 1) {
      final fragment = sequence.substring(index, index + 4);
      final reverse = fragment.split('').reversed.join();
      if (value.contains(fragment) || value.contains(reverse)) {
        return true;
      }
    }
  }
  return false;
}

String _normalizeContextValue(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

PasswordStrengthEvaluation evaluatePasswordStrength({
  required String password,
  String username = '',
  String email = '',
}) {
  final value = password;
  final normalized = value.toLowerCase();
  final length = value.length;
  final varietyCount = <RegExp>[
    RegExp(r'[a-z]'),
    RegExp(r'[A-Z]'),
    RegExp(r'[0-9]'),
    RegExp(r'[^A-Za-z0-9]'),
  ].where((pattern) => pattern.hasMatch(value)).length;
  final uniqueChars = value.runes.toSet().length;

  final identifiers = <String>[
    _normalizeContextValue(username),
    _normalizeContextValue(email),
    _normalizeContextValue(email.split('@').first),
  ].where((item) => item.length >= 3);
  final containsUserInfo = identifiers.any(normalized.contains);
  final usesCommonPattern = _commonPatterns.any(normalized.contains);
  final sequential = hasSequentialPattern(value);
  final repeatedRuns = RegExp(r'(.)\1{2,}').hasMatch(value);
  final obviousPattern = usesCommonPattern || sequential || repeatedRuns;

  var score = 0;
  if (length >= minPasswordLength) score += 1;
  if (length >= 12) score += 1;
  if (varietyCount >= 3) score += 1;
  if (varietyCount == 4 || length >= 16 || uniqueChars >= 10) score += 1;
  if (containsUserInfo || obviousPattern) score -= 1;
  score = score.clamp(0, 4);

  final hasMinimumLength = length >= minPasswordLength;
  return PasswordStrengthEvaluation(
    score: score,
    containsUserInfo: containsUserInfo,
    obviousPattern: obviousPattern,
    hasMinimumLength: hasMinimumLength,
    isAcceptable:
        hasMinimumLength &&
        score >= minPasswordScore &&
        !containsUserInfo &&
        !obviousPattern,
  );
}
