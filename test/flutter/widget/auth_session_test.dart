import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';

import '../support/scripted_http_client.dart';

NeoAgentController _controller(ScriptedHttpClient http) {
  return NeoAgentController(
      backendClient: BackendClient(httpClient: http),
      healthBridge: HealthBridge(),
    )
    ..backendUrl = 'http://localhost:3333'
    ..hasUser = true;
}

Future<void> _pumpAuthView(
  WidgetTester tester,
  NeoAgentController controller,
) async {
  tester.view.physicalSize = const Size(1200, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: AuthView(controller: controller)));
  await tester.pump();
}

void main() {
  testWidgets('Enter in the password field signs in', (tester) async {
    final http = ScriptedHttpClient(
      (method, uri, body) => jsonResponse(401, <String, dynamic>{
        'error': 'Invalid credentials',
        'code': 'INVALID_CREDENTIALS',
      }),
    );
    final controller = _controller(http);
    addTearDown(controller.dispose);
    await _pumpAuthView(tester, controller);

    await tester.enterText(
      _fieldLabeled('Username or email'),
      'neo@example.com',
    );
    await tester.enterText(
      _fieldLabeled('Password'),
      'secret',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final login = http.requests.where((r) => r.$2.path == '/api/auth/login');
    expect(login, hasLength(1));
    expect(login.single.$3, contains('neo@example.com'));
    expect(
      find.text('Your username or password is incorrect.'),
      findsOneWidget,
    );
    // The card shows the code inline at this width, so exactly one challenge
    // is created for it, and signing in with a password does not add another.
    expect(
      http.requests.where((r) => r.$2.path.endsWith('/qr-login/challenge')),
      hasLength(1),
    );
  });

  testWidgets('registration shows every field problem at once', (tester) async {
    final http = ScriptedHttpClient(
      (method, uri, body) => jsonResponse(200, <String, dynamic>{}),
    );
    final controller = _controller(http);
    addTearDown(controller.dispose);
    await _pumpAuthView(tester, controller);

    await tester.tap(find.text('Need a new account? Register'));
    await tester.pump();
    await tester.enterText(_fieldLabeled('Username'), 'ab');
    await tester.enterText(_fieldLabeled('Email'), 'nope');
    await tester.enterText(
      _fieldLabeled('Confirm Password'),
      'x',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('Usernames need at least 3 characters.'), findsOneWidget);
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Enter a password.'), findsOneWidget);
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(
      http.requests.where((r) => r.$2.path == '/api/auth/register'),
      isEmpty,
    );
  });

  testWidgets('a server that needs a key asks for it before the form', (
    tester,
  ) async {
    var keyAccepted = false;
    final http = ScriptedHttpClient((method, uri, body) {
      if (uri.path == '/api/auth/signup-key/check') {
        if (!body.toString().contains('ABCD-EFGH-JKMN')) {
          return jsonResponse(403, <String, dynamic>{
            'error': 'invalid',
            'code': 'SIGNUP_KEY_INVALID',
          });
        }
        keyAccepted = true;
        return jsonResponse(200, <String, dynamic>{'valid': true});
      }
      if (uri.path == '/api/auth/register') {
        return jsonResponse(403, <String, dynamic>{
          'error': 'used',
          'code': 'SIGNUP_KEY_USED',
        });
      }
      return jsonResponse(200, <String, dynamic>{});
    });
    final controller = _controller(http)..signupKeyRequired = true;
    addTearDown(controller.dispose);
    await _pumpAuthView(tester, controller);

    await tester.tap(find.text('Need a new account? Register'));
    await tester.pump();
    expect(find.text('Username'), findsNothing);

    await tester.enterText(_fieldLabeled('Sign-up key'), 'wxyz-wxyz-wxyz');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(
      find.text('That sign-up key isn’t valid. Check it and try again.'),
      findsOneWidget,
    );
    expect(find.text('Username'), findsNothing);

    // Typed in lower case without dashes; the field formats it.
    await tester.enterText(_fieldLabeled('Sign-up key'), 'abcdefghjkmn');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(keyAccepted, isTrue);
    expect(find.text('ABCD-EFGH-JKMN'), findsOneWidget);

    await tester.enterText(_fieldLabeled('Username'), 'new_person');
    await tester.enterText(_fieldLabeled('Email'), 'new@example.com');
    await tester.enterText(_fieldLabeled('Password'), 'Correct-Horse-9-Battery');
    await tester.enterText(
      _fieldLabeled('Confirm Password'),
      'Correct-Horse-9-Battery',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final register = http.requests.where(
      (r) => r.$2.path == '/api/auth/register',
    );
    expect(register.single.$3.toString(), contains('ABCD-EFGH-JKMN'));
    // A key spent meanwhile sends the form back to the key step.
    expect(find.text('Sign-up key'), findsOneWidget);
    expect(
      find.text(
        'That sign-up key has already been used. Ask an admin for a new one.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('server error codes map to localized messages', (tester) async {
    final controller = _controller(
      ScriptedHttpClient((m, u, b) => jsonResponse(200, <String, dynamic>{})),
    );
    addTearDown(controller.dispose);
    String message(String code, {String? httpsUrl}) =>
        controller.friendlyErrorMessage(
          BackendException(
            'raw',
            statusCode: 400,
            code: code,
            httpsUrl: httpsUrl,
          ),
        );

    expect(message('SIGNUP_KEY_USED'), contains('already been used'));
    expect(message('USERNAME_TAKEN'), 'That username is already taken.');
    expect(
      message('INVALID_CREDENTIALS'),
      'Your username or password is incorrect.',
    );
    expect(
      message('INSECURE_TRANSPORT', httpsUrl: 'https://agent.example.com'),
      contains('https://agent.example.com'),
    );
    expect(
      controller.friendlyErrorMessage(
        const BackendException('Registration is closed', statusCode: 403),
      ),
      contains('Sign-ups are closed'),
    );
  });

  testWidgets('a mid-session 401 signs out once with the expiry message', (
    tester,
  ) async {
    final http = ScriptedHttpClient(
      (m, u, b) =>
          jsonResponse(401, <String, dynamic>{'error': 'Unauthorized'}),
    );
    final controller = _controller(http)
      ..isAuthenticated = true
      ..user = <String, dynamic>{'id': 7, 'username': 'neo'};
    addTearDown(controller.dispose);

    await expectLater(
      controller.backendClient.getMap(controller.backendUrl, '/api/settings'),
      throwsA(isA<BackendException>()),
    );
    expect(controller.isAuthenticated, isFalse);
    expect(
      controller.errorMessage,
      'Your session expired. Please sign in again.',
    );

    await expectLater(
      controller.backendClient.getMap(controller.backendUrl, '/api/runs'),
      throwsA(isA<BackendException>()),
    );
    expect(
      controller.errorMessage,
      'Your session expired. Please sign in again.',
    );
    expect(
      http.requests,
      hasLength(2),
      reason: 'expiry must not trigger requests',
    );
  });
}

/// The sign-in card puts each label above its field, in the same column.
Finder _fieldLabeled(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
  matching: find.byType(TextField),
);
