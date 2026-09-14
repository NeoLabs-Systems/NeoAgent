String formatCaughtError(Object error) {
  var text = error.toString().trim();
  for (final prefix in const [
    'BackendException: ',
    'HealthBridgeException: ',
    'Exception: ',
    'Bad state: ',
    'Invalid argument(s): ',
    'StateError: ',
  ]) {
    if (text.startsWith(prefix)) {
      text = text.substring(prefix.length).trim();
    }
  }
  return text;
}

/// Matches JavaScript (`    at Object.foo (...)`) and Dart (`#0  main (...)`)
/// stack frames. Substring checks for `' at '` also match ordinary prose such
/// as "configure at least one provider", which silently hid actionable backend
/// errors behind the generic failure copy.
final RegExp _stackFramePattern = RegExp(
  r'(?:^|\n)\s*(?:at\s+\S|#\d+\s)',
);

bool looksLikeStackTrace(String text) => _stackFramePattern.hasMatch(text);
