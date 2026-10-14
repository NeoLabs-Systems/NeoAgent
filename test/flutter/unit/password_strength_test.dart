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
    expect(strong.isAcceptable, isTrue);

    final personal = evaluatePasswordStrength(
      password: 'NeoUser2026!',
      username: 'neouser',
      email: 'neo@example.com',
    );
    expect(personal.containsUserInfo, isTrue);
    expect(personal.score, lessThan(strong.score));
    expect(personal.isAcceptable, isFalse);
  });

  test('matches the server policy on keyboard rows, spaces and unique chars', () {
    // Keyboard-row sequences reject like the server's qwerty string does.
    expect(evaluatePasswordStrength(password: 'Tasdf!9Lmno').isAcceptable, isFalse);
    expect(evaluatePasswordStrength(password: 'Bzxcv!9Kmpw').isAcceptable, isFalse);
    expect(hasSequentialPattern('dcba'), isTrue);
    // Ten unique characters earn the fourth point without a fourth class.
    expect(evaluatePasswordStrength(password: 'mightyriver42').score, 3);
    // Leading/trailing spaces count; the server does not trim.
    expect(evaluatePasswordStrength(password: '  abc1  ').hasMinimumLength, isTrue);
  });
}
