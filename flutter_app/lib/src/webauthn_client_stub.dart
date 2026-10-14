import 'webauthn_client.dart';
import 'package:neoagent_flutter/src/l10n/app_language.dart';

WebAuthnClient createPlatformWebAuthnClient() => _UnsupportedWebAuthnClient();

class _UnsupportedWebAuthnClient implements WebAuthnClient {
  @override
  bool get isSupported => false;

  @override
  Future<Map<String, dynamic>> createCredential(
    Map<String, dynamic> options,
  ) async {
    throw WebAuthnException(
      appStrings.securityKeysAreOnlyAvailableIn,
    );
  }

  @override
  Future<Map<String, dynamic>> getAssertion(
    Map<String, dynamic> options,
  ) async {
    throw WebAuthnException(
      appStrings.securityKeysAreOnlyAvailableIn,
    );
  }
}
