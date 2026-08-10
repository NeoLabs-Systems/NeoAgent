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

void main() {
  for (final width in <double>[420, 900, 1400]) {
    testWidgets('security key panel shows the add button at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = NeoAgentController(
        backendClient: BackendClient(),
        healthBridge: HealthBridge(),
        webAuthnClient: _SupportedWebAuthnClient(),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettingsPanel(
            controller: controller,
            initialTab: AccountSettingsTab.security,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('SECURITY KEYS'), findsOneWidget);
      expect(find.text('Add security key'), findsOneWidget);
      expect(find.text('Name (optional)'), findsOneWidget);

      // Size.fromHeight on a button inside a Row demands infinite width, which
      // starves the name field beside it and pushes the button off the panel.
      final button = tester.getRect(find.text('Add security key'));
      expect(button.right, lessThanOrEqualTo(width));
      final field = tester.getSize(find.byType(TextField).last);
      expect(field.width, greaterThan(40));
    });
  }
}
