import 'dart:convert';
import 'dart:typed_data';

import 'package:neoagent_flutter/src/network/app_http_client.dart';

typedef ScriptedResponder =
    HttpResponseData Function(String method, Uri uri, Object? body);

HttpResponseData jsonResponse(int statusCode, Object body) {
  final text = jsonEncode(body);
  return textResponse(statusCode, text);
}

HttpResponseData textResponse(int statusCode, String text) {
  return HttpResponseData(
    statusCode: statusCode,
    body: text,
    bodyBytes: Uint8List.fromList(utf8.encode(text)),
    headers: const <String, String>{},
  );
}

/// An [AppHttpClient] that answers every request through [responder] and
/// records what was sent.
class ScriptedHttpClient implements AppHttpClient {
  ScriptedHttpClient(this.responder);

  final ScriptedResponder responder;
  final List<(String, Uri, Object?)> requests = <(String, Uri, Object?)>[];
  String? _sessionCookie;

  Future<HttpResponseData> _answer(String method, Uri uri, Object? body) async {
    requests.add((method, uri, body));
    return responder(method, uri, body);
  }

  @override
  Future<HttpResponseData> get(Uri uri, {Map<String, String>? headers}) =>
      _answer('GET', uri, null);

  @override
  Future<HttpResponseData> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) => _answer('POST', uri, body);

  @override
  Future<HttpResponseData> put(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) => _answer('PUT', uri, body);

  @override
  Future<HttpResponseData> patch(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) => _answer('PATCH', uri, body);

  @override
  Future<HttpResponseData> delete(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) => _answer('DELETE', uri, body);

  @override
  Future<HttpResponseData> postMultipart(
    Uri uri, {
    Map<String, String>? headers,
    required String fieldName,
    required String filename,
    required Uint8List bytes,
  }) => _answer('POST', uri, null);

  @override
  Future<void> close() async {}

  @override
  void clearSession() => _sessionCookie = null;

  @override
  void restoreSession(String? sessionCookie) => _sessionCookie = sessionCookie;

  @override
  String? get sessionCookie => _sessionCookie;
}
