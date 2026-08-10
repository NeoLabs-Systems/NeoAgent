// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

import 'webauthn_client.dart';

WebAuthnClient createPlatformWebAuthnClient() => _BrowserWebAuthnClient();

class _BrowserWebAuthnClient implements WebAuthnClient {
  @override
  bool get isSupported {
    if (!html.window.isSecureContext!) {
      return false;
    }
    return js_util.hasProperty(html.window, 'PublicKeyCredential') &&
        js_util.getProperty<Object?>(html.window.navigator, 'credentials') !=
            null;
  }

  Object get _credentials =>
      js_util.getProperty<Object>(html.window.navigator, 'credentials');

  @override
  Future<Map<String, dynamic>> createCredential(
    Map<String, dynamic> options,
  ) async {
    final Object publicKey = js_util.jsify(options) as Object;
    js_util.setProperty(
      publicKey,
      'challenge',
      _decodeBase64Url(options['challenge']),
    );
    final Object user = js_util.getProperty<Object>(publicKey, 'user');
    js_util.setProperty(
      user,
      'id',
      _decodeBase64Url(_asMap(options['user'])['id']),
    );
    _decodeDescriptorIds(publicKey, options, 'excludeCredentials');

    final Object credential = await _runCeremony('create', publicKey);
    final Object response = js_util.getProperty<Object>(credential, 'response');
    return <String, dynamic>{
      ..._commonCredentialFields(credential),
      'response': <String, dynamic>{
        'clientDataJSON': _encodeBuffer(
          js_util.getProperty<Object?>(response, 'clientDataJSON'),
        ),
        'attestationObject': _encodeBuffer(
          js_util.getProperty<Object?>(response, 'attestationObject'),
        ),
        'transports': _readTransports(response),
      },
    };
  }

  @override
  Future<Map<String, dynamic>> getAssertion(
    Map<String, dynamic> options,
  ) async {
    final Object publicKey = js_util.jsify(options) as Object;
    js_util.setProperty(
      publicKey,
      'challenge',
      _decodeBase64Url(options['challenge']),
    );
    _decodeDescriptorIds(publicKey, options, 'allowCredentials');

    final Object credential = await _runCeremony('get', publicKey);
    final Object response = js_util.getProperty<Object>(credential, 'response');
    final Object? userHandle = js_util.getProperty<Object?>(
      response,
      'userHandle',
    );
    return <String, dynamic>{
      ..._commonCredentialFields(credential),
      'response': <String, dynamic>{
        'clientDataJSON': _encodeBuffer(
          js_util.getProperty<Object?>(response, 'clientDataJSON'),
        ),
        'authenticatorData': _encodeBuffer(
          js_util.getProperty<Object?>(response, 'authenticatorData'),
        ),
        'signature': _encodeBuffer(
          js_util.getProperty<Object?>(response, 'signature'),
        ),
        'userHandle': userHandle == null ? null : _encodeBuffer(userHandle),
      },
    };
  }

  Future<Object> _runCeremony(String method, Object publicKey) async {
    final Object request = js_util.newObject<Object>();
    js_util.setProperty(request, 'publicKey', publicKey);
    try {
      final Object? credential = await js_util.promiseToFuture<Object?>(
        js_util.callMethod(_credentials, method, <Object>[request]),
      );
      if (credential == null) {
        throw const WebAuthnException('No security key was provided.');
      }
      return credential;
    } on WebAuthnException {
      rethrow;
    } catch (error) {
      throw _describeFailure(error);
    }
  }

  WebAuthnException _describeFailure(Object error) {
    final String name =
        js_util.getProperty<Object?>(error, 'name')?.toString() ?? '';
    final String message =
        js_util.getProperty<Object?>(error, 'message')?.toString() ?? '';
    if (name == 'NotAllowedError' || name == 'AbortError') {
      return const WebAuthnException(
        'Security key prompt was dismissed.',
        cancelled: true,
      );
    }
    if (name == 'InvalidStateError') {
      return const WebAuthnException(
        'That security key is already registered on this account.',
      );
    }
    return WebAuthnException(
      message.isEmpty ? 'The security key could not be used.' : message,
    );
  }

  Map<String, dynamic> _commonCredentialFields(Object credential) {
    return <String, dynamic>{
      'id': js_util.getProperty<Object?>(credential, 'id')?.toString() ?? '',
      'rawId': _encodeBuffer(js_util.getProperty<Object?>(credential, 'rawId')),
      'type':
          js_util.getProperty<Object?>(credential, 'type')?.toString() ??
          'public-key',
      'clientExtensionResults': const <String, dynamic>{},
    };
  }

  void _decodeDescriptorIds(
    Object publicKey,
    Map<String, dynamic> options,
    String field,
  ) {
    final Object? descriptors = options[field];
    if (descriptors is! List || descriptors.isEmpty) {
      return;
    }
    final Object jsDescriptors = js_util.getProperty<Object>(publicKey, field);
    for (int index = 0; index < descriptors.length; index++) {
      final Object jsDescriptor = js_util.getProperty<Object>(
        jsDescriptors,
        index,
      );
      js_util.setProperty(
        jsDescriptor,
        'id',
        _decodeBase64Url(_asMap(descriptors[index])['id']),
      );
    }
  }

  List<String> _readTransports(Object response) {
    if (!js_util.hasProperty(response, 'getTransports')) {
      return const <String>[];
    }
    final Object? transports = js_util.dartify(
      js_util.callMethod(response, 'getTransports', const <Object>[]),
    );
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

  String _encodeBuffer(Object? value) {
    final Uint8List bytes;
    if (value is ByteBuffer) {
      bytes = Uint8List.view(value);
    } else if (value is TypedData) {
      bytes = Uint8List.view(
        value.buffer,
        value.offsetInBytes,
        value.lengthInBytes,
      );
    } else {
      return '';
    }
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
