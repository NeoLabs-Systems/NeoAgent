import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';
import 'package:neoagent_flutter/src/backend_client.dart';
import 'package:neoagent_flutter/src/health_bridge.dart';
import 'package:neoagent_flutter/src/network/app_http_client.dart';
import 'package:neoagent_flutter/src/recording_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DevicesPanel', () {
    testWidgets('builds in stacked layout without framework exceptions', (
      tester,
    ) async {
      final controller = _buildController()
        ..isBooting = false
        ..isAuthenticated = true
        ..browserRuntime = <String, dynamic>{
          'launched': false,
          'pages': 0,
          'headless': true,
          'pageInfo': null,
        }
        ..androidRuntime = <String, dynamic>{
          'bootstrapped': false,
          'serial': null,
          'devices': null,
        };

      await tester.pumpWidget(
        _testHarness(width: 820, child: DevicesPanel(controller: controller)),
      );
      await tester.pump();

      expect(find.text('Remote Device'), findsOneWidget);
      expect(find.text('Browser'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('builds in wide layout with runtime data and previews', (
      tester,
    ) async {
      final controller = _buildController()
        ..isBooting = false
        ..isAuthenticated = true
        ..browserRuntime = <String, dynamic>{
          'launched': true,
          'pages': 1,
          'headless': false,
          'pageInfo': <String, dynamic>{
            'title': 'Example Domain',
            'url': 'https://example.com',
          },
        }
        ..androidRuntime = <String, dynamic>{
          'bootstrapped': true,
          'serial': 'emulator-5554',
          'devices': <Map<String, dynamic>>[
            <String, dynamic>{'serial': 'emulator-5554', 'status': 'device'},
          ],
        }
        ..browserLastResult = '{"ok":true}'
        ..androidLastResult = '{"ok":true}';

      await tester.pumpWidget(
        _testHarness(width: 1440, child: DevicesPanel(controller: controller)),
      );
      await tester.pump();

      expect(find.textContaining('Example Domain'), findsOneWidget);
      expect(find.text('Tap to click. Drag to scroll.'), findsOneWidget);
      expect(find.text('Browser'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

NeoAgentController _buildController() {
  return NeoAgentController(
    backendClient: _FakeBackendClient(),
    healthBridge: HealthBridge(),
    recordingBridge: _FakeRecordingBridge(),
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
  Future<void> Function(String sessionId)? _onRecordingStopped;

  @override
  Future<void> Function(String sessionId)? get onRecordingStopped =>
      _onRecordingStopped;

  @override
  set onRecordingStopped(Future<void> Function(String sessionId)? value) {
    _onRecordingStopped = value;
  }

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
    _status = _status.copyWith(
      active: true,
      sessionId: sessionId,
      platformLabel: 'test',
    );
    notifyListeners();
  }

  @override
  Future<void> startWebRecording({
    required String baseUrl,
    required String sessionId,
  }) async {
    _status = _status.copyWith(
      active: true,
      sessionId: sessionId,
      platformLabel: 'test',
    );
    notifyListeners();
  }

  @override
  Future<void> stopActiveRecording({bool notifyEnded = false}) async {
    final sessionId = _status.sessionId;
    _status = _status.copyWith(
      active: false,
      paused: false,
      sessionId: null,
      platformLabel: null,
    );
    notifyListeners();
    if (notifyEnded && sessionId != null && _onRecordingStopped != null) {
      await _onRecordingStopped!(sessionId);
    }
  }
}
