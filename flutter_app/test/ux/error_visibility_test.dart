import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/error_text.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';
import 'package:neoagent_flutter/src/l10n/app_language.dart';

const _raw = 'SqliteError: no such table: secrets at /Users/x/db.js:3';

NeoAgentController _controller({bool? admin}) {
  final controller = NeoAgentController(
    backendClient: BackendClient(),
    healthBridge: HealthBridge(),
  );
  if (admin != null) controller.user = <String, dynamic>{'isAdmin': admin};
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    currentAppLanguage = AppLanguage.english;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          (_) async => null,
        );
  });

  final generic = appStrings.somethingWentWrongPleaseTryAgain;

  group('non-admin and unknown-role readers', () {
    for (final entry in <String, bool?>{
      'non-admin': false,
      'signed out': null,
    }.entries) {
      test('${entry.key} never sees a raw cause', () {
        final controller = _controller(admin: entry.value);
        final unexpected = <Object>[
          const BackendException(_raw),
          const BackendException('Upstream exploded', statusCode: 500),
          Exception(_raw),
          TypeError(),
          const FormatException('Unexpected character at offset 3'),
          PlatformException(code: 'E1', message: 'native failure'),
        ];
        for (final error in unexpected) {
          expect(controller.friendlyErrorMessage(error), generic);
          expect(formatCaughtError(error), generic);
        }
        expect(TechnicalErrorDetails.forMessage(generic), isNull);
      });

      test('${entry.key} keeps validation and recovery messages', () {
        final controller = _controller(admin: entry.value);
        expect(
          controller.friendlyErrorMessage(
            const BackendException('That name is taken.', statusCode: 409),
          ),
          'That name is taken.',
        );
        expect(
          controller.friendlyErrorMessage(StateError('Allow the microphone.')),
          'Allow the microphone.',
        );
        expect(
          controller.friendlyErrorMessage(
            const BackendException(
              'Invalid credentials',
              statusCode: 401,
            ),
          ),
          appStrings.yourUsernameOrPasswordIsIncorrect,
        );
      });
    }

    test('server setup advice is for admins', () {
      const proxied = BackendException('Payment gateway', statusCode: 402);
      expect(_controller(admin: false).friendlyErrorMessage(proxied), generic);
      expect(
        _controller(admin: true).friendlyErrorMessage(proxied),
        isNot(generic),
      );
    });

    test('the server\'s withheld message shows in the reader\'s language', () {
      expect(
        plainErrorText('Something went wrong. Please try again.'),
        isNull,
      );
    });

    test('a streamed failure is plain', () {
      _controller(admin: false);
      expect(formatCaughtError(_raw), generic);
      expect(formatCaughtError('The line dropped.'), 'The line dropped.');
    });
  });

  group('admins', () {
    test('see the cause of an unexpected failure', () {
      final controller = _controller(admin: true);
      const error = BackendException('Upstream exploded', statusCode: 500);
      expect(controller.friendlyErrorMessage(error), 'Upstream exploded');
      expect(formatCaughtError(error), 'Upstream exploded');
    });

    test('get details behind a plain message, without credentials', () {
      final controller = _controller(admin: true);
      final message = controller.friendlyErrorMessage(
        const BackendException('SocketException: refused token=abc123'),
      );
      expect(message, appStrings.theAppCouldNotReachThis);
      expect(
        TechnicalErrorDetails.forMessage(message),
        'SocketException: refused token=[hidden]',
      );
    });

    test('losing admin hides details already remembered', () {
      final controller = _controller(admin: true);
      final message = controller.friendlyErrorMessage(
        const BackendException('SocketException: refused'),
      );
      controller.user = <String, dynamic>{'isAdmin': false};
      expect(TechnicalErrorDetails.forMessage(message), isNull);
    });
  });

  group('error banner', () {
    Future<void> pumpBanner(WidgetTester tester, NeoAgentController controller) async {
      tester.view.physicalSize = const Size(1100, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      controller.errorMessage = controller.friendlyErrorMessage(
        const BackendException('SocketException: refused'),
      );
      await tester.pumpWidget(
        MaterialApp(home: AuthView(controller: controller)),
      );
      await tester.pump();
    }

    testWidgets('offers admins the cause on request', (tester) async {
      await pumpBanner(tester, _controller(admin: true));
      expect(find.text(appStrings.theAppCouldNotReachThis), findsOneWidget);
      expect(find.text('SocketException: refused'), findsNothing);

      await tester.tap(find.text(appStrings.technicalDetails));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('SocketException: refused'), findsOneWidget);
    });

    testWidgets('shows others only the plain message', (tester) async {
      await pumpBanner(tester, _controller(admin: false));
      expect(find.text(appStrings.theAppCouldNotReachThis), findsOneWidget);
      expect(find.text(appStrings.technicalDetails), findsNothing);
    });
  });

  test('redactSecrets hides credentials and keeps the rest', () {
    expect(
      redactSecrets('401 Bearer abc.def key sk-abcdefghijkl api_key=xyz ok'),
      '401 Bearer [hidden] key [hidden] api_key=[hidden] ok',
    );
  });
}
