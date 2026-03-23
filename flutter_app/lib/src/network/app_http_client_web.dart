import 'dart:typed_data';

import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

import 'app_http_client.dart';

AppHttpClient createPlatformHttpClient() => WebAppHttpClient();

class WebAppHttpClient implements AppHttpClient {
  WebAppHttpClient() : _client = BrowserClient()..withCredentials = true;

  final BrowserClient _client;

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
    final response = await _client.get(uri, headers: headers);
    return _toResponseData(response);
  }

  @override
  Future<HttpResponseData> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final response = await _client.post(uri, headers: headers, body: body);
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
    if (headers != null) {
      request.headers.addAll(headers);
    }
    request.files.add(
      http.MultipartFile.fromBytes(fieldName, bytes, filename: filename),
    );
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    return _toResponseData(response);
  }

  @override
  Future<HttpResponseData> put(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final response = await _client.put(uri, headers: headers, body: body);
    return _toResponseData(response);
  }

  @override
  Future<HttpResponseData> delete(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final response = await _client.delete(uri, headers: headers, body: body);
    return _toResponseData(response);
  }

  @override
  Future<void> close() async {
    _client.close();
  }

  @override
  void clearSession() {}

  @override
  String? get sessionCookie => null;
}
