import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/auth/auth_provider_icon.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';

import '../support/scripted_http_client.dart';

class RegistrationController extends NeoAgentController {
  RegistrationController(ScriptedHttpClient http)
    : super(
        backendClient: BackendClient(httpClient: http),
        healthBridge: HealthBridge(),
      );

  @override
  Future<void> refresh() async {}
}

void main() {
  testWidgets('provider errors retain the platform name', (tester) async {
    final controller = RegistrationController(
      ScriptedHttpClient((m, u, b) => jsonResponse(200, <String, dynamic>{})),
    );
    addTearDown(controller.dispose);
    for (final provider in <String>['OpenRouter', 'Google', 'New Provider']) {
      final message =
          'No NeoAgent account is linked to this $provider account. Register first or sign in and link it from account settings.';
      expect(
        controller.friendlyErrorMessage(
          BackendException(message, statusCode: 400),
        ),
        message,
      );
      final linked =
          'This $provider account is already linked to another NeoAgent account.';
      expect(
        controller.friendlyErrorMessage(
          BackendException(linked, statusCode: 400),
        ),
        linked,
      );
    }
  });

  testWidgets(
    'username selection retries taken names and completes registration with the chosen name',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final submissions = <String>[];
      final http = ScriptedHttpClient((method, uri, body) {
        if (uri.path == '/api/auth/providers/register') {
          final data = jsonDecode(body! as String) as Map<String, dynamic>;
          expect(data['state'], 'registration-state');
          final username = data['username'] as String;
          submissions.add(username);
          return username == 'taken_name'
              ? jsonResponse(409, <String, dynamic>{
                  'error': 'Username is already taken',
                  'code': 'USERNAME_TAKEN',
                })
              : jsonResponse(200, <String, dynamic>{'status': 'completed'});
        }
        return jsonResponse(200, <String, dynamic>{
          'success': true,
          'user': <String, dynamic>{'id': 8, 'username': 'chosen_name'},
        });
      });
      final controller = RegistrationController(http)
        ..backendUrl = 'http://localhost:3333'
        ..pendingProviderRegistrationState = 'registration-state'
        ..pendingRegistrationProvider = 'openrouter';
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => controller.isAuthenticated
                ? const SizedBox.shrink()
                : AuthView(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Choose your username'), findsOneWidget);
      expect(find.byType(AuthProviderIcon), findsOneWidget);
      final field = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Username',
      );
      await tester.enterText(field, 'taken_name');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(controller.isAwaitingProviderUsername, true);
      expect(find.text('That username is already taken.'), findsOneWidget);
      await tester.enterText(field, ' chosen_name ');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(submissions, <String>['taken_name', 'chosen_name']);
      expect(controller.isAwaitingProviderUsername, false);
      expect(controller.isAuthenticated, true);
      expect(controller.user?['username'], 'chosen_name');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('the OpenRouter icon uses official assets for both themes', (
    tester,
  ) async {
    for (final brightness in <Brightness>[Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: const AuthProviderIcon(provider: 'openrouter'),
        ),
      );
      await tester.pumpAndSettle();
      final image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as AssetImage).assetName,
        'assets/branding/providers/openrouter_${brightness == Brightness.dark ? 'dark' : 'light'}.png',
      );
    }
  });
}
