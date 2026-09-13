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
