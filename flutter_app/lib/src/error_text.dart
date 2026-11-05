import 'dart:collection';

import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/l10n/app_language.dart';

/// Who is reading an error. Set by the app's controller; anyone it cannot
/// identify as an admin (signed out, role unknown) reads the plain version.
class ErrorAudience {
  ErrorAudience._();

  static bool Function() isAdmin = () => false;
}

/// The error's own text, for admins and for the person running a local install.
String rawErrorText(Object error) {
  var text = error.toString().trim();
  for (final prefix in [
    'BackendException: ',
    'HealthBridgeException: ',
    'Exception: ',
    appStrings.badState,
    appStrings.invalidArgumentS,
    'StateError: ',
  ]) {
    if (text.startsWith(prefix)) {
      text = text.substring(prefix.length).trim();
    }
  }
  return text;
}

/// What the current reader sees for [error]: everything for an admin, and for
/// anyone else a message written for people or a plain apology.
String formatCaughtError(Object error) {
  if (ErrorAudience.isAdmin()) return redactSecrets(rawErrorText(error));
  return plainErrorText(error) ?? appStrings.somethingWentWrongPleaseTryAgain;
}

/// [error]'s text when it was written for people, else null.
String? plainErrorText(Object error) {
  final written =
      error is String ||
      error is StateError ||
      (error is BackendException && (error.statusCode ?? 0) < 500) ||
      error.toString().startsWith('Exception: ') ||
      error.toString().startsWith('HealthBridgeException: ');
  if (!written) return null;
  final text = rawErrorText(error);
  if (text.isEmpty || text == _serverGenericMessage || looksTechnical(text)) {
    return null;
  }
  return text;
}

/// The server's answer when it withholds a cause; shown in the reader's language.
const String _serverGenericMessage = 'Something went wrong. Please try again.';

const int _maxReadableLength = 300;

/// Kept in step with `looksTechnical` in server/utils/public_error.js.
final List<RegExp> _technicalPatterns = <RegExp>[
  RegExp(
    r'\b\w*(?:Error|Exception):|\b(?:ECONN\w+|ENOTFOUND|ETIMEDOUT|EAI_AGAIN|EPIPE|ENOENT|EACCES|EPERM|EADDR\w+|EHOSTUNREACH|ENETUNREACH|ERR_[A-Z0-9_]+|SQLITE_[A-Z0-9_]+)\b',
  ),
  RegExp(
    r'''\[(?:path|module|app)\]|node_modules|(?:^|[\s'"(])(?:~/|/Users/|/home/|/var/|/tmp/|/etc/|[A-Za-z]:\\)''',
  ),
  RegExp(
    r'stack trace|traceback|cannot read propert|is not a function|is not defined|unexpected token|not valid json|getaddrinfo|socket hang up|fetch failed|constraint failed|no such (?:table|column)|\bsqlite\b|\bsql\b',
    caseSensitive: false,
  ),
  RegExp(
    r'\bHTTP\s*\d{3}\b|\bstatus(?: code)?:?\s*\d{3}\b|^\d{3}\b',
    caseSensitive: false,
  ),
  RegExp(r'[a-z]_(?:error|exception|failed)\b', caseSensitive: false),
  RegExp(r'[{\[]\s*"'),
];

bool looksTechnical(String text) {
  final value = text.trim();
  if (value.isEmpty) return false;
  if (value.contains('\n') || value.length > _maxReadableLength) return true;
  return looksLikeStackTrace(value) ||
      _technicalPatterns.any((pattern) => pattern.hasMatch(value));
}

/// Matches JavaScript (`    at Object.foo (...)`) and Dart (`#0  main (...)`)
/// stack frames. Substring checks for `' at '` also match ordinary prose such
/// as "configure at least one provider", which silently hid actionable backend
/// errors behind the generic failure copy.
final RegExp _stackFramePattern = RegExp(
  r'(?:^|\n)\s*(?:at\s+\S|#\d+\s)',
);

bool looksLikeStackTrace(String text) => _stackFramePattern.hasMatch(text);

final RegExp _bearerPattern = RegExp(r'\bBearer\s+[\w.~+/=-]+', caseSensitive: false);
final RegExp _secretValuePattern = RegExp(
  r'''\b(api[_-]?key|token|secret|password|authorization)(["']?\s*[=:]\s*["']?)[^\s"'&,]+''',
  caseSensitive: false,
);
final RegExp _providerKeyPattern = RegExp(r'\b(?:sk|pk|rk|gsk|xai)-[\w-]{8,}');

/// Diagnostics help an admin without handing them anyone's credentials.
String redactSecrets(String text) => text
    .replaceAll(_bearerPattern, 'Bearer [hidden]')
    .replaceAllMapped(_secretValuePattern, (m) => '${m[1]}${m[2]}[hidden]')
    .replaceAll(_providerKeyPattern, '[hidden]');

/// The cause behind the plain messages an admin was recently shown, so the
/// surface showing a message can offer its details. Holds nothing for others.
class TechnicalErrorDetails {
  TechnicalErrorDetails._();

  static const int _maxRemembered = 40;
  static final LinkedHashMap<String, String> _byMessage =
      LinkedHashMap<String, String>();

  static void remember(String message, Object error) {
    if (!ErrorAudience.isAdmin()) return;
    final details = redactSecrets(rawErrorText(error));
    if (details.isEmpty || details == message) return;
    _byMessage.remove(message);
    _byMessage[message] = details;
    if (_byMessage.length > _maxRemembered) {
      _byMessage.remove(_byMessage.keys.first);
    }
  }

  static String? forMessage(String message) =>
      ErrorAudience.isAdmin() ? _byMessage[message] : null;

  static void clear() => _byMessage.clear();
}
