import 'package:http/browser_client.dart';

import 'app_http_client.dart';

AppHttpClient createPlatformHttpClient() => WebAppHttpClient();

class WebAppHttpClient implements AppHttpClient {
  WebAppHttpClient() : _client = BrowserClient()..withCredentials = true;

  final BrowserClient _client;

  @override
  Future<HttpResponseData> get(Uri uri, {Map<String, String>? headers}) async {
    final response = await _client.get(uri, headers: headers);
    return HttpResponseData(
      statusCode: response.statusCode,
      body: response.body,
      headers: response.headers,
    );
  }

  @override
  Future<HttpResponseData> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final response = await _client.post(uri, headers: headers, body: body);
    return HttpResponseData(
      statusCode: response.statusCode,
      body: response.body,
      headers: response.headers,
    );
  }

  @override
  Future<HttpResponseData> put(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final response = await _client.put(uri, headers: headers, body: body);
    return HttpResponseData(
      statusCode: response.statusCode,
      body: response.body,
      headers: response.headers,
    );
  }

  @override
  Future<HttpResponseData> delete(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final response = await _client.delete(uri, headers: headers, body: body);
    return HttpResponseData(
      statusCode: response.statusCode,
      body: response.body,
      headers: response.headers,
    );
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
