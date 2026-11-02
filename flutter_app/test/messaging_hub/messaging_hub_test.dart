import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/features/messaging_hub/messaging_hub.dart';
import 'package:neoagent_flutter/features/messaging_hub/messaging_hub_models.dart';

HubApp _app(
  String id, {
  HubAppState state = HubAppState.available,
  String? identity,
  bool isShared = false,
  VoidCallback? onConnect,
  List<HubMenuAction> menu = const <HubMenuAction>[],
}) {
  return HubApp(
    id: id,
    label: id,
    subtitle: '$id subtitle',
    icon: Icons.chat,
    color: Colors.blue,
    state: state,
    identity: identity,
    isShared: isShared,
    onConnect: onConnect ?? () {},
    menu: menu,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required List<HubApp> apps,
  List<HubLinkOffer> offers = const <HubLinkOffer>[],
  bool expanded = false,
  Size size = const Size(1000, 1600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MessagingHub(
            agentName: 'Main',
            apps: apps,
            offers: offers,
            moreSettingsExpanded: expanded,
            moreSettings: const <Widget>[Text('group chat rules')],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final catalog = <HubApp>[for (var i = 0; i < 10; i += 1) _app('app$i')];

  test('raw statuses group into what a person cares about', () {
    expect(hubStateFor('connected'), HubAppState.live);
    expect(hubStateFor('awaiting_qr'), HubAppState.connecting);
    expect(hubStateFor('reconnecting'), HubAppState.connecting);
    expect(hubStateFor('not_configured'), HubAppState.available);
    expect(hubStateFor('disabled'), HubAppState.disabled);
    expect(hubStateFor('logged_out'), HubAppState.attention);
    expect(hubStateFor('disconnected'), HubAppState.available);
    expect(hubStateFor('error'), HubAppState.attention);
  });

  testWidgets('with no shared account there is no offer or Advanced', (
    tester,
  ) async {
    await _pump(tester, apps: catalog);
    expect(find.text('Advanced'), findsNothing);
    expect(find.byIcon(Icons.link_rounded), findsNothing);
    expect(find.text('Your apps'), findsNothing);
    expect(find.text('Add an app'), findsOneWidget);
  });

  testWidgets('the catalogue starts short, and search comes with the rest', (
    tester,
  ) async {
    await _pump(tester, apps: catalog);
    expect(find.text('app3'), findsOneWidget);
    expect(find.text('app4'), findsNothing);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Show all 10 apps'));
    await tester.pump();
    expect(find.text('app9'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'APP7');
    await tester.pump();
    expect(find.text('app7'), findsOneWidget);
    expect(find.text('app1'), findsNothing);
  });

  testWidgets('tapping an app connects it', (tester) async {
    var connected = 0;
    await _pump(
      tester,
      apps: <HubApp>[_app('one', onConnect: () => connected++)],
    );
    await tester.tap(find.text('one'));
    expect(connected, 1);
  });

  testWidgets('an offer is one button; your own account waits under Advanced', (
    tester,
  ) async {
    var linked = 0;
    var own = 0;
    await _pump(
      tester,
      apps: <HubApp>[_app('Telegram'), _app('other')],
      offers: <HubLinkOffer>[
        HubLinkOffer(
          app: _app('Telegram'),
          accountLabel: '@shared_bot',
          onLink: () => linked++,
          onUseOwnAccount: () => own++,
        ),
      ],
    );
    expect(find.text('Link Telegram'), findsOneWidget);
    expect(find.text('@shared_bot'), findsOneWidget);
    expect(find.text('Use my own account'), findsNothing);
    expect(
      find.text('other'),
      findsOneWidget,
      reason: 'other apps stay listed',
    );
    expect(
      find.descendant(
        of: find.byType(Column),
        matching: find.text('Telegram subtitle'),
      ),
      findsNothing,
      reason: 'an offered app is not listed twice',
    );

    await tester.tap(find.text('Link Telegram'));
    expect(linked, 1);

    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use my own account'));
    expect(own, 1);
  });

  testWidgets('no Advanced when the server only allows the shared account', (
    tester,
  ) async {
    await _pump(
      tester,
      apps: <HubApp>[_app('Telegram')],
      offers: <HubLinkOffer>[
        HubLinkOffer(app: _app('Telegram'), accountLabel: null, onLink: () {}),
      ],
    );
    expect(find.text('Advanced'), findsNothing);
  });

  testWidgets('connected apps come first, working ones on top', (tester) async {
    await _pump(
      tester,
      apps: <HubApp>[
        _app('broken', state: HubAppState.attention),
        _app('spare'),
        _app('working', state: HubAppState.live, identity: 'Sam'),
      ],
    );
    expect(find.text('Your apps'), findsOneWidget);
    expect(find.text('Connected as Sam'), findsOneWidget);
    expect(find.text('Reconnect'), findsOneWidget);
    final working = tester.getTopLeft(find.text('working')).dy;
    final broken = tester.getTopLeft(find.text('broken')).dy;
    final spare = tester.getTopLeft(find.text('spare')).dy;
    expect(working, lessThan(broken));
    expect(broken, lessThan(spare));
  });

  testWidgets('a working app does nothing on tap; its menu holds the rest', (
    tester,
  ) async {
    var connects = 0;
    var disconnects = 0;
    await _pump(
      tester,
      apps: <HubApp>[
        _app(
          'working',
          state: HubAppState.live,
          onConnect: () => connects++,
          menu: <HubMenuAction>[
            HubMenuAction(
              label: 'Disconnect',
              destructive: true,
              onSelected: () => disconnects++,
            ),
          ],
        ),
      ],
    );
    await tester.tap(find.text('working'));
    expect(connects, 0);
    await tester.tap(find.byTooltip('Manage working'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    expect(disconnects, 1);
  });

  testWidgets('more settings stay folded until asked for', (tester) async {
    await _pump(tester, apps: catalog);
    expect(find.text('group chat rules'), findsNothing);
    await tester.tap(find.text('More settings'));
    await tester.pumpAndSettle();
    expect(find.text('group chat rules'), findsOneWidget);
  });

  testWidgets('a search result inside opens more settings by itself', (
    tester,
  ) async {
    await _pump(tester, apps: catalog, expanded: true);
    await tester.pumpAndSettle();
    expect(find.text('group chat rules'), findsOneWidget);
  });

  for (final width in const <double>[320, 412, 900]) {
    testWidgets('fits ${width.toInt()} wide with everything showing', (
      tester,
    ) async {
      await _pump(
        tester,
        size: Size(width, 2400),
        apps: <HubApp>[
          _app(
            'A platform with a really long name',
            state: HubAppState.live,
            identity: 'Somebody with a very long display name indeed',
            isShared: true,
            menu: <HubMenuAction>[
              HubMenuAction(label: 'Disconnect', onSelected: () {}),
            ],
          ),
          _app('broken', state: HubAppState.attention),
          ...catalog,
        ],
        offers: <HubLinkOffer>[
          for (final id in <String>['Telegram', 'WhatsApp'])
            HubLinkOffer(
              app: _app(id),
              accountLabel: '@a_rather_long_shared_bot_username_here',
              onLink: () {},
              onUseOwnAccount: () {},
            ),
        ],
      );
      expect(tester.takeException(), isNull);
    });
  }
}
