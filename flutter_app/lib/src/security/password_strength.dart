class PasswordStrengthEvaluation {
  const PasswordStrengthEvaluation({
    required this.score,
    required this.containsUserInfo,
    required this.obviousPattern,
    required this.hasMinimumLength,
  });

  final int score;
  final bool containsUserInfo;
  final bool obviousPattern;
  final bool hasMinimumLength;
}

bool hasSequentialPattern(String input) {
  if (input.length < 4) return false;
  
  // check for ascending/descending sequences of length >= 4
  for (int i = 0; i <= input.length - 4; i++) {
    bool asc = true;
    bool desc = true;
    for (int j = 0; j < 3; j++) {
      if (input.codeUnitAt(i + j + 1) != input.codeUnitAt(i + j) + 1) asc = false;
      if (input.codeUnitAt(i + j + 1) != input.codeUnitAt(i + j) - 1) desc = false;
    }
    if (asc || desc) return true;
  }
  return false;
}

PasswordStrengthEvaluation evaluatePasswordStrength({
  required String password,
  String username = '',
  String email = '',
}) {
  final value = password.trim();
  if (value.isEmpty) {
    return const PasswordStrengthEvaluation(
      score: 0,
      containsUserInfo: false,
      obviousPattern: false,
      hasMinimumLength: false,
    );
  }

  final lower = RegExp(r'[a-z]').hasMatch(value);
  final upper = RegExp(r'[A-Z]').hasMatch(value);
  final digits = RegExp(r'[0-9]').hasMatch(value);
  final symbols = RegExp(r'[^A-Za-z0-9]').hasMatch(value);
  final variety = <bool>[lower, upper, digits, symbols]
      .where((item) => item)
      .length;
  final normalized = value.toLowerCase();
  final userHints = <String>{
    username.trim().toLowerCase(),
    email.trim().toLowerCase(),
    email.trim().toLowerCase().split('@').first,
  }.where((item) => item.length >= 3);
  final containsUserInfo = userHints.any(normalized.contains);
  final obviousPattern =
      RegExp(r'(.)\1\1').hasMatch(value) ||
      normalized.contains('password') ||
      normalized.contains('123456') ||
      normalized.contains('qwerty') ||
      normalized.contains('letmein') ||
      normalized.contains('welcome') ||
      normalized.contains('admin') ||
      normalized.contains('neoagent') ||
      hasSequentialPattern(normalized);

  var score = 0;
  if (value.length >= 8) score += 1;
  if (value.length >= 12) score += 1;
  if (variety >= 3) score += 1;
  if (variety == 4 || value.length >= 16) score += 1;
  if (containsUserInfo || obviousPattern) score -= 1;

  return PasswordStrengthEvaluation(
    score: score.clamp(0, 4),
    containsUserInfo: containsUserInfo,
    obviousPattern: obviousPattern,
    hasMinimumLength: value.length >= 8,
  );
}
