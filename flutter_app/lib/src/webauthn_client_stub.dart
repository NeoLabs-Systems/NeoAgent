import 'webauthn_client.dart';

WebAuthnClient createPlatformWebAuthnClient() => _UnsupportedWebAuthnClient();

class _UnsupportedWebAuthnClient implements WebAuthnClient {
  @override
  bool get isSupported => false;

  @override
  Future<Map<String, dynamic>> createCredential(
    Map<String, dynamic> options,
  ) async {
    throw const WebAuthnException(
      'Security keys are only available in the NeoAgent web app.',
    );
  }

  @override
  Future<Map<String, dynamic>> getAssertion(
    Map<String, dynamic> options,
  ) async {
    throw const WebAuthnException(
      'Security keys are only available in the NeoAgent web app.',
    );
  }
}
