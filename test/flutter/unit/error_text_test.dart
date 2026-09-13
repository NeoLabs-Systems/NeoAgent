import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/error_text.dart';

void main() {
  test('formatCaughtError strips framework exception prefixes', () {
    expect(formatCaughtError(Exception('Could not connect')), 'Could not connect');
    expect(
      formatCaughtError(StateError('Could not read the Android app package.')),
      'Could not read the Android app package.',
    );
    expect(formatCaughtError('plain message'), 'plain message');
  });
}
