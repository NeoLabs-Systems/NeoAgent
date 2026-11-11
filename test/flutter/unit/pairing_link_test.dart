import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/pairing/pairing_link.dart';

const String _code = 'Q2hhbmdlTWVQbGVhc2VJdHNBVGVzdENvZGVYeXo';

void main() {
  test('the app link gives the server and the code', () {
    final link = parsePairingLink(
      'neoagent://pair?server=https%3A%2F%2Fagent.example.com%2F&code=$_code',
    )!;
    expect(link.server.toString(), 'https://agent.example.com');
    expect(link.code, _code);
    expect(parsePairingLink(link.appLink.toString())!.code, _code);
  });

  test('the web fallback works, also under a base path, and round-trips', () {
    final link = parsePairingLink(
      'https://example.com/neo/app/pair?code=$_code',
    )!;
    expect(link.server.toString(), 'https://example.com/neo');
    final web = pairingWebLink(link.server, link.code);
    expect(web.toString(), 'https://example.com/neo/app/pair?code=$_code');
    expect(parsePairingLink(web.toString())!.server, link.server);
    expect(
      parsePairingLink(link.appLink.toString())!.server.toString(),
      'https://example.com/neo',
    );
  });

  test('other codes, schemes, short codes and credentials are refused', () {
    expect(parsePairingLink('https://example.com/some/page?code=$_code'), isNull);
    expect(
      parsePairingLink('neoagent://qr-login?backend=https://a.example&challenge=x&secret=y'),
      isNull,
    );
    expect(
      parsePairingLink('neoagent://pair?server=ftp://a.example&code=$_code'),
      isNull,
    );
    expect(
      parsePairingLink('neoagent://pair?server=https://user:pw@a.example&code=$_code'),
      isNull,
    );
    expect(
      parsePairingLink('neoagent://pair?server=https://a.example&code=short'),
      isNull,
    );
    expect(parsePairingLink('WIFI:S:home;T:WPA;P:secret;;'), isNull);
  });

  test('the landing page code is read from /app/pair only', () {
    expect(
      pairCodeFromLaunchUri(Uri.parse('https://a.example/app/pair?code=$_code')),
      _code,
    );
    expect(
      pairCodeFromLaunchUri(Uri.parse('https://a.example/neo/app/pair/?code=x')),
      'x',
    );
    expect(pairCodeFromLaunchUri(Uri.parse('https://a.example/app/chat')), isNull);
    expect(pairCodeFromLaunchUri(Uri.parse('https://a.example/pair?code=x')), isNull);
    expect(pairCodeFromLaunchUri(null), isNull);
  });

  test('the countdown reads minutes and seconds and stops at zero', () {
    expect(formatCountdown(const Duration(minutes: 5)), '5:00');
    expect(formatCountdown(const Duration(seconds: 61)), '1:01');
    expect(formatCountdown(const Duration(milliseconds: 1500)), '0:02');
    expect(formatCountdown(const Duration(seconds: -3)), '0:00');
  });
}
