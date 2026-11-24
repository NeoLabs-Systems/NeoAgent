import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/security/password_strength.dart';

void main() {
  test('repetition lowers the score without rejecting an otherwise strong password', () {
    final varied = evaluatePasswordStrength(password: 'ORCHID7772018!!WIND');
    expect(varied.score, 3);
    expect(varied.isAcceptable, isTrue);
    expect(evaluatePasswordStrength(password: 'aaaAAAA1').isAcceptable, isFalse);
  });
}
