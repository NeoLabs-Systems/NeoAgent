import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';
import 'package:neoagent_flutter/src/network/app_http_client.dart';
import 'package:neoagent_flutter/src/recording_bridge.dart';
import 'package:neoagent_flutter/wearables/wearable_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SkillsPanel renders official integrations tab', (tester) async {
    final controller = _buildController()
      ..isBooting = false
      ..isAuthenticated = true
      ..skills = const <SkillItem>[]
      ..storeSkills = const <StoreSkillItem>[
        StoreSkillItem(
          id: 'weather',
          name: 'Weather',
          description: 'Get weather',
          category: 'info',
          icon: 'W',
          installed: false,
        ),
      ]
      ..officialIntegrations = const <OfficialIntegrationItem>[
        OfficialIntegrationItem(
          id: 'google_workspace',
          label: 'Google Workspace',
          description:
              'Official Gmail, Calendar, Drive, Docs, and Sheets access.',
          icon: 'google',
          apps: <OfficialIntegrationAppItem>[
            OfficialIntegrationAppItem(id: 'gmail', label: 'Gmail'),
            OfficialIntegrationAppItem(id: 'calendar', label: 'Calendar'),
          ],
          env: OfficialIntegrationEnvStatus(
            configured: true,
            missing: <String>[],
            summary: 'Server OAuth credentials are configured.',
          ),
          connection: OfficialIntegrationConnectionStatus(
            status: 'not_connected',
            connected: false,
          ),
          availableToolCount: 0,
        ),
      ];

    await tester.pumpWidget(
      _testHarness(width: 1180, child: SkillsPanel(controller: controller)),
    );
    await tester.pump();

    expect(find.textContaining('Official Integrations'), findsOneWidget);
    expect(find.text('Current Skills (0)'), findsOneWidget);
    expect(find.text('Store (1)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

NeoAgentController _buildController() {
  final backendClient = _FakeBackendClient();
  return NeoAgentController(
    backendClient: backendClient,
    healthBridge: HealthBridge(),
    recordingBridge: _FakeRecordingBridge(),
    wearableService: WearableService(
      backendClient: backendClient,
      getBackendUrl: () => 'http://localhost:3333',
    ),
  );
}

Widget _testHarness({required double width, required Widget child}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 1200)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(body: child),
      ),
    ),
  );
}

class _FakeBackendClient extends BackendClient {
  _FakeBackendClient() : super(httpClient: _FakeAppHttpClient());
}

class _FakeAppHttpClient implements AppHttpClient {
  @override
  String? get sessionCookie => null;

  @override
  void clearSession() {}

  @override
  Future<void> close() async {}

  @override
  Future<HttpResponseData> delete(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<HttpResponseData> get(Uri uri, {Map<String, String>? headers}) async {
    throw UnimplementedError();
  }

  @override
  Future<HttpResponseData> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<HttpResponseData> postMultipart(
    Uri uri, {
    Map<String, String>? headers,
    required String fieldName,
    required String filename,
    required Uint8List bytes,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<HttpResponseData> put(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    throw UnimplementedError();
  }
}

class _FakeRecordingBridge extends RecordingBridge {
  RecordingRuntimeStatus _status = const RecordingRuntimeStatus(
    supportsScreenAndMic: false,
    supportsBackgroundMic: false,
  );

  @override
  Future<void> Function(String sessionId)? onRecordingStopped;

  @override
  RecordingRuntimeStatus get status => _status;

  @override
  Future<void> pauseBackgroundRecording() async {}

  @override
  Future<void> refreshStatus() async {}

  @override
  Future<void> resumeBackgroundRecording() async {}

  @override
  Future<void> startBackgroundRecording({
    required String baseUrl,
    required String sessionCookie,
    required String sessionId,
  }) async {
    _status = _status.copyWith(active: true, sessionId: sessionId);
    notifyListeners();
  }

  @override
  Future<void> startWebRecording({
    required String baseUrl,
    required String sessionId,
  }) async {
    _status = _status.copyWith(active: true, sessionId: sessionId);
    notifyListeners();
  }

  @override
  Future<void> stopActiveRecording({bool notifyEnded = false}) async {
    _status = _status.copyWith(active: false, paused: false, sessionId: null);
    notifyListeners();
  }
}
