import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/features/shared_messaging/shared_link_dialog.dart';
import 'package:neoagent_flutter/features/shared_messaging/shared_link_flow.dart';
import 'package:neoagent_flutter/features/shared_messaging/shared_messaging_models.dart';

class _Harness {
  _Harness({this.movesExistingLink = false});

  final bool movesExistingLink;
  final ValueNotifier<int> updates = ValueNotifier<int>(0);
  String? identity;
  String? failure;
  int starts = 0;
  Duration validFor = const Duration(minutes: 10);
  Object? startError;
  bool returned = false;

  SharedLinkSession session() => SharedLinkSession(
    platformLabel: 'Telegram',
    platformIcon: Icons.send,
    platformColor: Colors.blue,
    option: const SharedMessagingOption(
      platform: 'telegram',
      personalAllowed: true,
      accountLabel: '@shared_bot',
    ),
    movesExistingLink: movesExistingLink,
    updates: updates,
    startLink: () async {
      starts += 1;
      if (startError != null) throw startError!;
      return SharedMessagingLink(
        code: 'NeoAgent-ABCDEFGH$starts$starts',
        expiresAt: DateTime.now().add(validFor),
        url: 'https://t.me/shared_bot?start=NEO',
      );
    },
    linkedIdentity: () => identity,
    failure: () => failure,
    describeError: (error) => 'failed: $error',
  );

  void notify() => updates.value += 1;

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(1000, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                await showSharedLinkDialog(context, session());
                returned = true;
              },
              child: const Text('page underneath'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('page underneath'));
    await settle(tester);
  }
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> closeDialog(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Close'));
  await settle(tester);
}

void main() {
  testWidgets(
    'asking to link goes straight to the code, with no choice first',
    (tester) async {
      final harness = _Harness();
      await harness.open(tester);
      expect(harness.starts, 1);
      expect(find.text('NeoAgent-ABCDEFGH11'), findsOneWidget);
      expect(find.text('Open Telegram'), findsOneWidget);
      expect(find.text('Use my own account'), findsNothing);
      await closeDialog(tester);
    },
  );

  testWidgets('says so when finishing would move a link from another agent', (
    tester,
  ) async {
    final harness = _Harness(movesExistingLink: true);
    await harness.open(tester);
    expect(find.textContaining('linked to another agent'), findsOneWidget);
    await closeDialog(tester);
  });

  testWidgets(
    'repeated updates after linking leave the page underneath alone',
    (tester) async {
      final harness = _Harness();
      await harness.open(tester);

      harness.identity = 'Sam';
      harness.notify();
      harness.notify();
      harness.notify();
      await settle(tester);
      harness.notify();
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Telegram linked as Sam'), findsOneWidget);
      expect(harness.returned, isFalse, reason: 'it stays until dismissed');

      await tester.tap(find.text('Done'));
      await settle(tester);
      expect(harness.returned, isTrue);
      expect(find.text('page underneath'), findsOneWidget);
    },
  );

  testWidgets('a refused identity shows why and offers a new code', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.open(tester);

    harness.failure = 'That account is taken.';
    harness.notify();
    await settle(tester);
    expect(find.text('That account is taken.'), findsOneWidget);
    expect(find.text('Waiting for your message…'), findsNothing);

    harness.failure = null;
    await tester.tap(find.text('Get a new code'));
    await settle(tester);
    expect(find.text('NeoAgent-ABCDEFGH22'), findsOneWidget);
    await closeDialog(tester);
  });

  testWidgets('an expired code stops offering the link', (tester) async {
    final harness = _Harness()..validFor = const Duration(seconds: 2);
    await harness.open(tester);
    expect(find.text('Open Telegram'), findsOneWidget);

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 3)),
    );
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(find.text('This code has expired.'), findsOneWidget);
    expect(find.text('Open Telegram'), findsNothing);
    await closeDialog(tester);
  });

  testWidgets('a failure to start offers a retry that works', (tester) async {
    final harness = _Harness()..startError = 'offline';
    await harness.open(tester);
    expect(find.text('failed: offline'), findsOneWidget);

    harness.startError = null;
    await tester.tap(find.text('Try again'));
    await settle(tester);
    expect(find.text('NeoAgent-ABCDEFGH22'), findsOneWidget);
    await closeDialog(tester);
  });

  for (final size in const <Size>[Size(320, 568), Size(412, 915)]) {
    testWidgets('every step fits ${size.width.toInt()} wide', (tester) async {
      final harness = _Harness();
      await harness.open(tester, size: size);
      expect(tester.takeException(), isNull);
      harness.identity = 'A person with quite a long display name indeed';
      harness.notify();
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('scanning is only offered where the screen is not the phone', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.open(tester, size: const Size(400, 800));
    expect(find.textContaining('Scan with your phone'), findsNothing);
    await closeDialog(tester);
  });
}
