import 'app_http_client.dart';
import 'app_http_client_stub.dart'
    if (dart.library.html) 'app_http_client_web.dart'
    if (dart.library.io) 'app_http_client_io.dart';

AppHttpClient createAppHttpClient() => createPlatformHttpClient();
