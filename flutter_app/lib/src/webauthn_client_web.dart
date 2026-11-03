import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'webauthn_client.dart';
import 'package:neoagent_flutter/src/l10n/app_language.dart';

WebAuthnClient createPlatformWebAuthnClient() => _BrowserWebAuthnClient();

class _BrowserWebAuthnClient implements WebAuthnClient {
  JSObject get _navigator => globalContext['navigator'] as JSObject;

  @override
  bool get isSupported {
    // Browsers only expose the authenticator API over HTTPS (or on localhost).
    if (globalContext.getProperty<JSBoolean?>('isSecureContext'.toJS)?.toDart !=
        true) {
      return false;
    }
    return globalContext.has('PublicKeyCredential') &&
        _navigator['credentials'] != null;
  }

  JSObject get _credentials => _navigator['credentials'] as JSObject;

  @override
  Future<Map<String, dynamic>> createCredential(
    Map<String, dynamic> options,
  ) async {
    final JSObject publicKey = options.jsify() as JSObject;
    publicKey['challenge'] = _decodeBase64Url(options['challenge']).toJS;
    final JSObject user = publicKey['user'] as JSObject;
    user['id'] = _decodeBase64Url(_asMap(options['user'])['id']).toJS;
    _decodeDescriptorIds(publicKey, options, 'excludeCredentials');

    final JSObject credential = await _runCeremony('create', publicKey);
    final JSObject response = credential['response'] as JSObject;
    return <String, dynamic>{
      ..._commonCredentialFields(credential),
      'response': <String, dynamic>{
        'clientDataJSON': _encodeBuffer(response['clientDataJSON']),
        'attestationObject': _encodeBuffer(response['attestationObject']),
        'transports': _readTransports(response),
      },
    };
  }

  @override
  Future<Map<String, dynamic>> getAssertion(
    Map<String, dynamic> options,
  ) async {
    final JSObject publicKey = options.jsify() as JSObject;
    publicKey['challenge'] = _decodeBase64Url(options['challenge']).toJS;
    _decodeDescriptorIds(publicKey, options, 'allowCredentials');

    final JSObject credential = await _runCeremony('get', publicKey);
    final JSObject response = credential['response'] as JSObject;
    final JSAny? userHandle = response['userHandle'];
    return <String, dynamic>{
      ..._commonCredentialFields(credential),
      'response': <String, dynamic>{
        'clientDataJSON': _encodeBuffer(response['clientDataJSON']),
        'authenticatorData': _encodeBuffer(response['authenticatorData']),
        'signature': _encodeBuffer(response['signature']),
        'userHandle': userHandle == null ? null : _encodeBuffer(userHandle),
      },
    };
  }

  Future<JSObject> _runCeremony(String method, JSObject publicKey) async {
    final JSObject request = JSObject();
    request['publicKey'] = publicKey;
    final JSObject? credential;
    try {
      credential = await _credentials
          .callMethod<JSPromise<JSObject?>>(method.toJS, request)
          .toDart;
    } catch (error) {
      throw _describeFailure(error);
    }
    if (credential == null) {
      throw WebAuthnException(appStrings.noSecurityKeyWasProvided);
    }
    return credential;
  }

  WebAuthnException _describeFailure(Object error) {
    final JSObject jsError = error as JSObject;
    final String name = _readString(jsError, 'name') ?? '';
    final String message = _readString(jsError, 'message') ?? '';
    if (name == 'NotAllowedError' || name == 'AbortError') {
      return WebAuthnException(
        appStrings.securityKeyPromptWasDismissed,
        cancelled: true,
      );
    }
    if (name == 'InvalidStateError') {
      return WebAuthnException(appStrings.thatSecurityKeyIsAlreadyRegistered);
    }
    return WebAuthnException(
      message.isEmpty ? appStrings.theSecurityKeyCouldNotBeUsed : message,
    );
  }

  Map<String, dynamic> _commonCredentialFields(JSObject credential) {
    return <String, dynamic>{
      'id': _readString(credential, 'id') ?? '',
      'rawId': _encodeBuffer(credential['rawId']),
      'type': _readString(credential, 'type') ?? 'public-key',
      'clientExtensionResults': const <String, dynamic>{},
    };
  }

  String? _readString(JSObject object, String property) =>
      object.getProperty<JSString?>(property.toJS)?.toDart;

  void _decodeDescriptorIds(
    JSObject publicKey,
    Map<String, dynamic> options,
    String field,
  ) {
    final Object? descriptors = options[field];
    if (descriptors is! List || descriptors.isEmpty) {
      return;
    }
    final JSObject jsDescriptors = publicKey[field] as JSObject;
    for (int index = 0; index < descriptors.length; index++) {
      final JSObject jsDescriptor =
          jsDescriptors.getProperty<JSObject>(index.toJS);
      jsDescriptor['id'] = _decodeBase64Url(
        _asMap(descriptors[index])['id'],
      ).toJS;
    }
  }

  List<String> _readTransports(JSObject response) {
    if (!response.has('getTransports')) {
      return const <String>[];
    }
    final Object? transports = response
        .callMethod<JSAny?>('getTransports'.toJS)
        .dartify();
    if (transports is! List) {
      return const <String>[];
    }
    return transports.map((dynamic entry) => entry.toString()).toList();
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return const <String, dynamic>{};
  }

  Uint8List _decodeBase64Url(Object? value) {
    final String raw = value?.toString() ?? '';
    final int remainder = raw.length % 4;
    final String padded = remainder == 0 ? raw : raw + ('=' * (4 - remainder));
    return base64Url.decode(padded);
  }

  String _encodeBuffer(JSAny? value) {
    if (value == null) return '';
    final Uint8List bytes = (value as JSArrayBuffer).toDart.asUint8List();
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
