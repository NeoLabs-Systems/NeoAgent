/// Turns what a user types or pastes into the server field into the backend
/// base URL.
///
/// People paste the address bar of the web app, so the app's own paths
/// (`/app`, `/login`), query, fragment and trailing slashes are dropped. A
/// bare `host[:port]` gets `http://` when the host can only be a private
/// network address (loopback, RFC 1918, Tailscale CGNAT, `.local`, `.lan`,
/// `.ts.net`) and `https://` otherwise.
String normalizeBackendUrl(String rawValue) {
  final trimmed = rawValue.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final hasScheme = trimmed.contains('://');
  final uri = Uri.tryParse(hasScheme ? trimmed : 'http://$trimmed');
  if (uri == null || uri.host.isEmpty) {
    return trimmed.replaceFirst(RegExp(r'/+$'), '');
  }
  final scheme = hasScheme
      ? uri.scheme.toLowerCase()
      : (isPrivateNetworkHost(uri.host) ? 'http' : 'https');
  final path = _stripAppPath(uri.path);
  final host = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
  final port = uri.hasPort ? ':${uri.port}' : '';
  return '$scheme://${host.toLowerCase()}$port$path';
}

/// Whether [rawValue] names no scheme, so [normalizeBackendUrl] picked one.
bool backendUrlSchemeWasInferred(String rawValue) =>
    !rawValue.trim().contains('://');

String _stripAppPath(String path) {
  var result = path.replaceFirst(RegExp(r'/+$'), '');
  for (final suffix in const <String>['/login', '/app']) {
    if (result.toLowerCase().endsWith(suffix)) {
      result = result.substring(0, result.length - suffix.length);
      result = result.replaceFirst(RegExp(r'/+$'), '');
    }
  }
  return result;
}

bool isPrivateNetworkHost(String rawHost) {
  final host = rawHost.trim().toLowerCase();
  if (host == 'localhost' ||
      host.endsWith('.localhost') ||
      host == '::1' ||
      host == '[::1]' ||
      host.endsWith('.local') ||
      host.endsWith('.lan') ||
      host.endsWith('.ts.net')) {
    return true;
  }
  final octets = host.split('.');
  if (octets.length != 4) {
    return false;
  }
  final parts = octets.map(int.tryParse).toList(growable: false);
  if (parts.any((part) => part == null || part < 0 || part > 255)) {
    return false;
  }
  final first = parts[0]!;
  final second = parts[1]!;
  return first == 127 ||
      first == 10 ||
      (first == 192 && second == 168) ||
      (first == 172 && second >= 16 && second <= 31) ||
      (first == 169 && second == 254) ||
      // 100.64.0.0/10 — carrier-grade NAT, which Tailscale uses.
      (first == 100 && second >= 64 && second <= 127);
}
