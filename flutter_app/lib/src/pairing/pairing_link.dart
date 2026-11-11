/// QR pairing links: what a phone scans to sign in, and the web page that
/// stands in for the app when the code is opened in a browser. The server
/// mints them in server/services/account/pairing.js.
library;

/// `neoagent://pair?server=<server>&code=<code>`, parsed.
class PairingLinkData {
  const PairingLinkData({required this.server, required this.code});

  /// The server, e.g. `https://agent.example.com` or
  /// `https://example.com/neo`, without a trailing slash.
  final Uri server;

  /// The single-use pairing code (32+ base64url characters).
  final String code;

  /// The link again, as the signed-in screen's QR code carries it.
  Uri get appLink => Uri(
    scheme: 'neoagent',
    host: 'pair',
    queryParameters: <String, String>{
      'server': server.toString(),
      'code': code,
    },
  );
}

final RegExp _codePattern = RegExp(r'^[A-Za-z0-9_-]{32,}$');

/// Reads a scanned or pasted pairing link: the app link
/// (`neoagent://pair?server=…&code=…`) or the web page that carries the same
/// code (`https://<server>/app/pair?code=…`). Null for anything else,
/// including servers that aren't http(s) or carry credentials.
PairingLinkData? parsePairingLink(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return null;
  final Uri? server;
  switch (uri.scheme) {
    case 'neoagent':
      if (uri.host != 'pair' || (uri.path.isNotEmpty && uri.path != '/')) {
        return null;
      }
      server = _server(uri.queryParameters['server'] ?? '');
    case 'http' || 'https':
      final path = _trimSlash(uri.path);
      if (!path.endsWith('/app/pair')) return null;
      server = _server(
        uri
            .replace(
              path: path.substring(0, path.length - '/app/pair'.length),
              query: '',
              fragment: '',
            )
            .toString(),
      );
    default:
      return null;
  }
  final code = uri.queryParameters['code'] ?? '';
  if (server == null || !_codePattern.hasMatch(code)) return null;
  return PairingLinkData(server: server, code: code);
}

/// The web page a phone without the in-app scanner can open: it explains the
/// app and hands the code to it.
Uri pairingWebLink(Uri server, String code) => server.replace(
  path: '${_trimSlash(server.path)}/app/pair',
  queryParameters: <String, String>{'code': code},
);

/// The pairing code of a launch address `…/app/pair?code=…`, or null when
/// the address is some other page.
String? pairCodeFromLaunchUri(Uri? uri) {
  if (uri == null) return null;
  final segments = uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (segments.length < 2 ||
      segments.last != 'pair' ||
      segments[segments.length - 2] != 'app') {
    return null;
  }
  return (uri.queryParameters['code'] ?? '').trim();
}

Uri? _server(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: _trimSlash(uri.path),
  );
}

String _trimSlash(String path) =>
    path.endsWith('/') ? path.substring(0, path.length - 1) : path;

/// "4:59" for the time a code has left; "0:00" once it is up.
String formatCountdown(Duration left) {
  final seconds = left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil();
  final minutes = seconds ~/ 60;
  return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
}
