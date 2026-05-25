import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/security/password_strength.dart';

void main() {
  test('password scoring handles empty, weak, strong, and personal passwords', () {
    expect(evaluatePasswordStrength(password: '').score, 0);
    expect(evaluatePasswordStrength(password: 'password123').score, lessThan(3));

    final strong = evaluatePasswordStrength(password: 'CorrectHorse9!Battery');
    expect(strong.score, 4);
    expect(strong.hasMinimumLength, isTrue);
    expect(strong.obviousPattern, isFalse);

    final personal = evaluatePasswordStrength(
      password: 'NeoUser2026!',
      username: 'neouser',
      email: 'neo@example.com',
    );
    expect(personal.containsUserInfo, isTrue);
    expect(personal.score, lessThan(strong.score));
  });
}
