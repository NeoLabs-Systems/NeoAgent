import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';
import 'package:neoagent_flutter/src/webauthn_client.dart';

class _SupportedWebAuthnClient implements WebAuthnClient {
  @override
  bool get isSupported => true;

  @override
  Future<Map<String, dynamic>> createCredential(Map<String, dynamic> options) async =>
      const <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> getAssertion(Map<String, dynamic> options) async =>
      const <String, dynamic>{};
}

NeoAgentController _controller({required bool supported}) {
  return NeoAgentController(
    backendClient: BackendClient(),
    healthBridge: HealthBridge(),
    webAuthnClient: supported ? _SupportedWebAuthnClient() : null,
  )
    ..hasUser = true
    ..authProviders = const <AuthProviderCatalogItem>[
      AuthProviderCatalogItem(
        id: 'google',
        label: 'Google',
        icon: 'google',
        configured: true,
        summary: '',
      ),
    ];
}

void main() {
  testWidgets('security key sign-in sits under the provider buttons', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _controller(supported: true);
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(home: AuthView(controller: controller)));
    await tester.pump();

    expect(find.text('or continue with'), findsOneWidget);
    final divider = tester.getRect(find.text('or continue with'));
    final google = tester.getRect(find.text('Sign in with Google'));
    final securityKey = tester.getRect(find.text('Sign in with a security key'));

    expect(divider.top, lessThan(google.top));
    expect(google.top, lessThan(securityKey.top));
  });

  testWidgets('unsupported platforms show no security key sign-in', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _controller(supported: false);
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(home: AuthView(controller: controller)));
    await tester.pump();

    expect(find.text('Sign in with a security key'), findsNothing);
    expect(find.text('Sign in with Google'), findsOneWidget);
  });
}
