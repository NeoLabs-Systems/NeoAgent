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

  test('looksLikeStackTrace ignores prose that merely contains "at"', () {
    expect(
      looksLikeStackTrace(
        'No AI providers are configured. Add a provider API key in the admin '
        'dashboard, then try again.',
      ),
      isFalse,
    );
    expect(looksLikeStackTrace('The backend is not answering at the moment.'), isFalse);
  });

  test('looksLikeStackTrace detects JavaScript and Dart frames', () {
    expect(
      looksLikeStackTrace(
        'TypeError: x is not a function\n    at Object.run (/app/server/index.js:12:9)',
      ),
      isTrue,
    );
    expect(
      looksLikeStackTrace('Bad state\n#0      main (package:neoagent/main.dart:10:3)'),
      isTrue,
    );
  });
}
