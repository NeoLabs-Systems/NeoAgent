import 'webauthn_client_stub.dart'
    if (dart.library.html) 'webauthn_client_web.dart';

/// Raised when a security key ceremony fails or the user cancels it.
class WebAuthnException implements Exception {
  const WebAuthnException(this.message, {this.cancelled = false});

  final String message;
  final bool cancelled;

  @override
  String toString() => message;
}

/// Bridge to the platform authenticator API used for security key sign-in.
abstract class WebAuthnClient {
  /// Whether this build can run a security key ceremony at all.
  bool get isSupported;

  /// Runs `navigator.credentials.create` and returns the attestation as JSON.
  Future<Map<String, dynamic>> createCredential(Map<String, dynamic> options);

  /// Runs `navigator.credentials.get` and returns the assertion as JSON.
  Future<Map<String, dynamic>> getAssertion(Map<String, dynamic> options);
}

WebAuthnClient createWebAuthnClient() => createPlatformWebAuthnClient();
