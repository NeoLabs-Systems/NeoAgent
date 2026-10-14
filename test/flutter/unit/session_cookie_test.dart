import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/network/app_http_client_io.dart';

void main() {
  test('keeps the session cookie from merged set-cookie headers', () {
    const merged =
        'AWSALB=abc; Expires=Wed, 21 Oct 2026 07:28:00 GMT; Path=/,'
        'neoagent.sid=s%3Aabc.def; Path=/; Expires=Thu, 22 Oct 2026 07:28:00 GMT; HttpOnly';
    expect(sessionCookieFromSetCookie(merged), 'neoagent.sid=s%3Aabc.def');
  });

  test('ignores other and emptied cookies', () {
    expect(sessionCookieFromSetCookie('theme=dark; Path=/'), isNull);
    expect(sessionCookieFromSetCookie('neoagent.sid=; Path=/'), isNull);
  });
}
