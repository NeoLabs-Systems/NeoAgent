import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'app_http_client.dart';

AppHttpClient createPlatformHttpClient() => IoAppHttpClient();

class IoAppHttpClient implements AppHttpClient {
  final http.Client _client = http.Client();
  String? _sessionCookie;

  HttpResponseData _toResponseData(http.Response response) {
    return HttpResponseData(
      statusCode: response.statusCode,
      body: response.body,
      bodyBytes: response.bodyBytes,
      headers: response.headers,
    );
  }

  @override
  Future<HttpResponseData> get(Uri uri, {Map<String, String>? headers}) async {
    final response = await _client.get(uri, headers: _withCookie(headers));
    _storeCookie(response.headers);
    return _toResponseData(response);
  }

  @override
  Future<HttpResponseData> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final response = await _client.post(
      uri,
      headers: _withCookie(headers),
      body: body,
    );
    _storeCookie(response.headers);
    return _toResponseData(response);
  }

  @override
  Future<HttpResponseData> postMultipart(
    Uri uri, {
    Map<String, String>? headers,
    required String fieldName,
    required String filename,
    required Uint8List bytes,
  }) async {
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_withCookie(headers));
    request.files.add(
      http.MultipartFile.fromBytes(fieldName, bytes, filename: filename),
    );
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    _storeCookie(response.headers);
    return _toResponseData(response);
  }

  @override
  Future<HttpResponseData> put(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final response = await _client.put(
      uri,
      headers: _withCookie(headers),
      body: body,
    );
    _storeCookie(response.headers);
    return _toResponseData(response);
  }

  @override
  Future<HttpResponseData> delete(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final response = await _client.delete(
      uri,
      headers: _withCookie(headers),
      body: body,
    );
    _storeCookie(response.headers);
    return _toResponseData(response);
  }

  Map<String, String> _withCookie(Map<String, String>? headers) {
    final next = <String, String>{...?headers};
    if (_sessionCookie != null && _sessionCookie!.isNotEmpty) {
      next['Cookie'] = _sessionCookie!;
    }
    return next;
  }

  void _storeCookie(Map<String, String> headers) {
    final rawCookie = headers['set-cookie'];
    if (rawCookie == null || rawCookie.isEmpty) {
      return;
    }
    _sessionCookie = rawCookie
        .split(',')
        .map((part) => part.trim().split(';').first)
        .where((part) => part.isNotEmpty)
        .join('; ');
  }

  @override
  Future<void> close() async {
    _client.close();
  }

  @override
  void clearSession() {
    _sessionCookie = null;
  }

  @override
  String? get sessionCookie => _sessionCookie;
}
