import 'dart:typed_data';

abstract class AppHttpClient {
  Future<HttpResponseData> get(Uri uri, {Map<String, String>? headers});

  Future<HttpResponseData> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  });

  Future<HttpResponseData> put(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  });

  Future<HttpResponseData> delete(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  });

  Future<void> close();

  void clearSession();

  String? get sessionCookie;
}

class HttpResponseData {
  const HttpResponseData({
    required this.statusCode,
    required this.body,
    required this.bodyBytes,
    required this.headers,
  });

  final int statusCode;
  final String body;
  final Uint8List bodyBytes;
  final Map<String, String> headers;
}
