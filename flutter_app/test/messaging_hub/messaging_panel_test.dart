import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';

/// The server side of the page: one shared Telegram bot, and connecting a
/// personal bot flips this agent to it.
class _FakeBackend extends BackendClient {
  Map<String, dynamic> statuses = <String, dynamic>{};
  bool sharedOffered = true;
  int connects = 0;

  @override
  Future<Map<String, dynamic>> fetchMessagingStatus(
    String baseUrl, {
    String? agentId,
  }) async => statuses;

  @override
  Future<Map<String, dynamic>> fetchSharedMessagingOptions(
    String baseUrl,
  ) async => <String, dynamic>{
    'options': sharedOffered
        ? <Map<String, dynamic>>[
            <String, dynamic>{
              'platform': 'telegram',
              'personalAllowed': true,
              'accountLabel': '@shared_bot',
            },
          ]
        : const <Map<String, dynamic>>[],
  };

  @override
  Future<List<Map<String, dynamic>>> fetchMessagingMessages(
    String baseUrl, {
    String? platform,
    String? chatId,
    String? agentId,
  }) async => const <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> fetchMessagingAccessPolicy(
    String baseUrl, {
    required String platform,
    String? agentId,
  }) async => const <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> saveSettings(
    String baseUrl,
    Map<String, dynamic> payload, {
    String? agentId,
  }) async => payload;

  @override
  Future<Map<String, dynamic>> connectMessagingPlatform(
    String baseUrl, {
    required String platform,
    Map<String, dynamic>? config,
    String? agentId,
  }) async {
    connects += 1;
    statuses = <String, dynamic>{
      platform: <String, dynamic>{
        'status': 'connected',
        'authInfo': <String, dynamic>{'username': 'my_own_bot'},
      },
    };
    return <String, dynamic>{'status': 'connected'};
  }
}

void main() {
  late _FakeBackend backend;
  late NeoAgentController controller;

  Future<void> pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    backend = _FakeBackend();
    controller = NeoAgentController(
      backendClient: backend,
      healthBridge: HealthBridge(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => MessagingPanel(controller: controller),
            ),
          ),
        ),
      ),
    );
    await controller.refreshMessaging();
    await tester.pumpAndSettle();
  }

  testWidgets('a shared account is one button, with your own under Advanced', (
    tester,
  ) async {
    await pumpPanel(tester);
    expect(find.text('Link Telegram'), findsOneWidget);
    expect(find.text('@shared_bot'), findsOneWidget);
    expect(find.text('Use my own account'), findsNothing);
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    expect(find.text('Use my own account'), findsOneWidget);
  });

  testWidgets('connecting your own account from Advanced lands cleanly', (
    tester,
  ) async {
    await pumpPanel(tester);
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use my own account'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'mine:token');
    await tester.tap(find.text('Connect').last);
    for (var i = 0; i < 12; i += 1) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(backend.connects, 1);
    expect(find.text('Connected as @my_own_bot'), findsOneWidget);
    expect(find.text('Link Telegram'), findsNothing);
  });
}
