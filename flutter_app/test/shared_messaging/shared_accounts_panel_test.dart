import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/features/shared_messaging/shared_accounts_panel.dart';
import 'package:neoagent_flutter/features/shared_messaging/shared_accounts_repository.dart';
import 'package:neoagent_flutter/features/shared_messaging/shared_messaging_models.dart';

Map<String, dynamic> _row(String platform, Map<String, dynamic> fields) =>
    <String, dynamic>{
      'platform': platform,
      'authMethod': platform == 'telegram' ? 'token' : 'qr',
      'configured': false,
      'enabled': false,
      'available': true,
      'allowPersonal': true,
      'status': 'not_configured',
      'linkedUsers': 0,
      ...fields,
    };

class _FakeRepository implements SharedAccountsRepository {
  _FakeRepository(this.rows);

  List<Map<String, dynamic>> rows;
  final List<Map<String, dynamic>> saves = <Map<String, dynamic>>[];
  final List<String> removed = <String>[];
  Object? saveError;
  Completer<void>? holdFetch;
  int fetches = 0;

  List<SharedAccount> get _accounts =>
      rows.map(SharedAccount.fromJson).toList(growable: false);

  @override
  Future<List<SharedAccount>> fetch() async {
    fetches += 1;
    final snapshot = _accounts;
    await holdFetch?.future;
    return snapshot;
  }

  @override
  Future<List<SharedAccount>> save(
    String platform,
    SharedAccountChanges changes,
  ) async {
    if (saveError != null) throw saveError!;
    saves.add(<String, dynamic>{'platform': platform, ...changes.toJson()});
    rows = rows.map((row) {
      if (row['platform'] != platform) return row;
      return <String, dynamic>{
        ...row,
        'configured': true,
        if (changes.available != null) 'available': changes.available,
        if (changes.allowPersonal != null)
          'allowPersonal': changes.allowPersonal,
        if (changes.enabled != null) 'enabled': changes.enabled,
        if (changes.enabled == false) 'status': 'disconnected',
      };
    }).toList();
    return _accounts;
  }

  @override
  Future<List<SharedAccount>> remove(String platform) async {
    removed.add(platform);
    rows = rows
        .map(
          (row) => row['platform'] == platform ? _row(platform, const {}) : row,
        )
        .toList();
    return _accounts;
  }
}

Future<void> _pumpPanel(
  WidgetTester tester,
  _FakeRepository repository, {
  Size size = const Size(1000, 1600),
  Duration poll = const Duration(hours: 1),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SharedAccountsPanel(
            repository: repository,
            pollInterval: poll,
            describeError: (error) => 'failed: $error',
            lookFor: (platform) => SharedPlatformLook(
              label: platform == 'telegram' ? 'Telegram' : 'WhatsApp',
              icon: Icons.chat,
              color: Colors.blue,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

final _live = _row('telegram', <String, dynamic>{
  'configured': true,
  'enabled': true,
  'status': 'connected',
  'accountLabel': '@shared_bot',
  'linkedUsers': 3,
});

void main() {
  test('server statuses group into what the screen does next', () {
    SharedAccountState stateOf(String status) => SharedAccount.fromJson(
      _row('telegram', <String, dynamic>{'configured': true, 'status': status}),
    ).state;
    expect(stateOf('connected'), SharedAccountState.live);
    expect(stateOf('reconnecting'), SharedAccountState.starting);
    expect(stateOf('awaiting_qr'), SharedAccountState.awaitingScan);
    expect(stateOf('logged_out'), SharedAccountState.failed);
    expect(stateOf('disconnected'), SharedAccountState.off);
    expect(
      SharedAccount.fromJson(_row('whatsapp', const {})).state,
      SharedAccountState.notSetUp,
    );
  });

  test('a partial change only sends what was changed', () {
    expect(
      const SharedAccountChanges(available: false).toJson(),
      <String, dynamic>{'available': false},
    );
  });

  testWidgets('a fresh install shows guided setup and no account controls', (
    tester,
  ) async {
    await _pumpPanel(
      tester,
      _FakeRepository(<Map<String, dynamic>>[
        _row('telegram', const {}),
        _row('whatsapp', const {}),
      ]),
    );
    expect(find.text('Not set up'), findsNWidgets(2));
    expect(find.text('@BotFather'), findsOneWidget);
    expect(find.text('Show QR code'), findsOneWidget);
    expect(find.text('Offer to users'), findsNothing);
    expect(find.byTooltip('More'), findsNothing);
  });

  testWidgets('connecting Telegram needs a token, then sends it once', (
    tester,
  ) async {
    final repository = _FakeRepository(<Map<String, dynamic>>[
      _row('telegram', const {}),
    ]);
    await _pumpPanel(tester, repository);

    await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
    await tester.pump();
    expect(find.text('Paste the bot token first.'), findsOneWidget);
    expect(repository.saves, isEmpty);

    await tester.enterText(find.byType(TextField), ' 123:abc ');
    await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
    await tester.pump();
    await tester.pump();
    expect(repository.saves.single['botToken'], '123:abc');
    expect(repository.saves.single['enabled'], true);
  });

  testWidgets('the token is hidden until asked for', (tester) async {
    await _pumpPanel(
      tester,
      _FakeRepository(<Map<String, dynamic>>[_row('telegram', const {})]),
    );
    bool obscured() =>
        tester.widget<TextField>(find.byType(TextField)).obscureText;
    expect(obscured(), isTrue);
    await tester.tap(find.byTooltip('Show token'));
    await tester.pump();
    expect(obscured(), isFalse);
  });

  testWidgets('a live account shows its name, count and rules, not setup', (
    tester,
  ) async {
    await _pumpPanel(tester, _FakeRepository(<Map<String, dynamic>>[_live]));
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('@shared_bot · 3 linked'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Offer to users'), findsOneWidget);
    expect(find.text('Allow personal accounts'), findsOneWidget);
  });

  testWidgets('a rule change saves only that rule', (tester) async {
    final repository = _FakeRepository(<Map<String, dynamic>>[_live]);
    await _pumpPanel(tester, repository);
    await tester.tap(find.text('Allow personal accounts'));
    await tester.pump();
    await tester.pump();
    expect(repository.saves.single, <String, dynamic>{
      'platform': 'telegram',
      'allowPersonal': false,
    });
    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches[1].value, isFalse);
  });

  testWidgets('a failed save reports inside that card', (tester) async {
    final repository = _FakeRepository(<Map<String, dynamic>>[_live])
      ..saveError = 'nope';
    await _pumpPanel(tester, repository);
    await tester.tap(find.text('Offer to users'));
    await tester.pump();
    await tester.pump();
    expect(find.text('failed: nope'), findsOneWidget);
  });

  testWidgets('the menu holds the rarer actions and removal asks first', (
    tester,
  ) async {
    final repository = _FakeRepository(<Map<String, dynamic>>[_live]);
    await _pumpPanel(tester, repository);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Reconnect'), findsOneWidget);
    expect(find.text('Replace token'), findsOneWidget);
    expect(find.text('Turn off'), findsOneWidget);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(repository.removed, isEmpty);
    expect(find.textContaining('3 linked people'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(repository.removed, <String>['telegram']);
    expect(find.text('Not set up'), findsOneWidget);
  });

  testWidgets('replacing a token opens only on request and can be cancelled', (
    tester,
  ) async {
    await _pumpPanel(tester, _FakeRepository(<Map<String, dynamic>>[_live]));
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replace token'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('@BotFather'), findsNothing);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('a rejected token leads straight to pasting a new one', (
    tester,
  ) async {
    await _pumpPanel(
      tester,
      _FakeRepository(<Map<String, dynamic>>[
        _row('telegram', <String, dynamic>{
          'configured': true,
          'enabled': true,
          'status': 'error',
        }),
      ]),
    );
    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.textContaining('rejected this token'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('a pairing shows the QR with its steps', (tester) async {
    await _pumpPanel(
      tester,
      _FakeRepository(<Map<String, dynamic>>[
        _row('whatsapp', <String, dynamic>{
          'configured': true,
          'enabled': true,
          'status': 'awaiting_qr',
          'qr': 'qr-data',
        }),
      ]),
    );
    expect(find.textContaining('Linked devices'), findsOneWidget);
    expect(find.text('Show QR code'), findsNothing);
  });

  testWidgets('a logged-out number offers a new QR', (tester) async {
    final repository = _FakeRepository(<Map<String, dynamic>>[
      _row('whatsapp', <String, dynamic>{
        'configured': true,
        'enabled': true,
        'status': 'logged_out',
      }),
    ]);
    await _pumpPanel(tester, repository);
    await tester.tap(find.text('Show QR code'));
    await tester.pump();
    await tester.pump();
    expect(repository.saves.single['reconnect'], true);
  });

  testWidgets('a poll that started before a save cannot undo it', (
    tester,
  ) async {
    final repository = _FakeRepository(<Map<String, dynamic>>[_live]);
    await _pumpPanel(tester, repository, poll: const Duration(seconds: 1));

    repository.holdFetch = Completer<void>();
    await tester.pump(const Duration(seconds: 1));
    repository.holdFetch!.complete();
    repository.holdFetch = null;
    await tester.pump();

    await tester.tap(find.text('Offer to users'));
    await tester.pump();
    await tester.pump();
    final first = tester.widgetList<Switch>(find.byType(Switch)).first;
    expect(first.value, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a load failure offers a retry', (tester) async {
    final repository = _ThrowingOnce(<Map<String, dynamic>>[_live]);
    await _pumpPanel(tester, repository);
    expect(find.text('failed: down'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Live'), findsOneWidget);
  });

  final states = <String, Map<String, dynamic>>{
    'live': _live,
    'pairing': _row('whatsapp', <String, dynamic>{
      'configured': true,
      'enabled': true,
      'status': 'awaiting_qr',
      'qr': 'qr-data',
    }),
    'failed': _row('telegram', <String, dynamic>{
      'configured': true,
      'enabled': true,
      'status': 'error',
    }),
    'telegram setup': _row('telegram', const {}),
    'whatsapp setup': _row('whatsapp', const {}),
  };
  for (final width in const <double>[320, 412]) {
    for (final entry in states.entries) {
      testWidgets('${entry.key} fits ${width.toInt()} wide', (tester) async {
        await _pumpPanel(
          tester,
          _FakeRepository(<Map<String, dynamic>>[entry.value]),
          size: Size(width, 1600),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}

class _ThrowingOnce extends _FakeRepository {
  _ThrowingOnce(super.rows);
  bool _thrown = false;

  @override
  Future<List<SharedAccount>> fetch() {
    if (!_thrown) {
      _thrown = true;
      throw 'down';
    }
    return super.fetch();
  }
}
