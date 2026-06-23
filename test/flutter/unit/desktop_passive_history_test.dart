import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/desktop_companion_actions.dart';
import 'package:neoagent_flutter/src/desktop_ocr_bridge.dart';
import 'package:neoagent_flutter/src/desktop_passive_history.dart';
import 'package:neoagent_flutter/src/desktop_screen_capture.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeScreenCapture implements DesktopScreenCapture {
  @override
  bool get isSupported => true;

  @override
  Future<DesktopScreenCaptureResult?> captureCurrentScreen() async => null;
}

class _FakeActions extends DesktopCompanionActions {
  _FakeActions({
    required this.statusProvider,
    required this.snapshotProvider,
  }) : super(screenCapture: _FakeScreenCapture());

  final Map<String, Object?> Function() statusProvider;
  final DesktopCompanionSnapshot? Function() snapshotProvider;

  @override
  Future<Map<String, Object?>> getStatus({
    required String label,
    required bool paused,
    String? activeDisplayId,
  }) async {
    return statusProvider();
  }

  @override
  Future<DesktopCompanionSnapshot?> captureSnapshot({
    String? activeDisplayId,
  }) async {
    return snapshotProvider();
  }
}

class _FakeOcrBridge extends DesktopOcrBridge {
  _FakeOcrBridge({
    this.unavailableReasonValue,
    List<String> texts = const <String>[],
  }) : _texts = List<String>.from(texts);

  final String? unavailableReasonValue;
  final List<String> _texts;

  @override
  Future<String?> unavailableReason() async => unavailableReasonValue;

  @override
  Future<DesktopOcrResult> recognize({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final text = _texts.isEmpty ? 'default text' : _texts.removeAt(0);
    return DesktopOcrResult(text: text, engine: 'fake', confidence: 0.9);
  }
}

class _FakeHttpHeaders implements HttpHeaders {
  @override
  ContentType? contentType;

  final Map<String, Object> values = <String, Object>{};

  @override
  void set(
    String name,
    Object value, {
    bool preserveHeaderCase = false,
  }) {
    values[name.toLowerCase()] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse(this.statusCode, String body)
    : _bytes = <List<int>>[utf8.encode(body)];

  final List<List<int>> _bytes;

  @override
  final int statusCode;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable(_bytes).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this.client, this.uri);

  final _FakeHttpClient client;
  final BytesBuilder _body = BytesBuilder(copy: false);

  @override
  final _FakeHttpHeaders headers = _FakeHttpHeaders();

  @override
  final Uri uri;

  @override
  void add(List<int> data) {
    _body.add(data);
  }

  @override
  Future<HttpClientResponse> close() async {
    final payload = utf8.decode(_body.takeBytes());
    client.requests.add(
      jsonDecode(payload) as Map<String, dynamic>,
    );
    if (client.outcomes.isEmpty) {
      return _FakeHttpClientResponse(201, '{"ok":true}');
    }
    final next = client.outcomes.removeAt(0);
    if (next is Exception) {
      throw next;
    }
    return _FakeHttpClientResponse(next as int, '{"ok":true}');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClient implements HttpClient {
  _FakeHttpClient({
    required this.requests,
    required List<Object> outcomes,
  }) : outcomes = List<Object>.from(outcomes);

  final List<Map<String, dynamic>> requests;
  final List<Object> outcomes;

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    return _FakeHttpClientRequest(this, url);
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _drain() async {
  await Future<void>.delayed(const Duration(milliseconds: 150));
}

void main() {
  test('disabling passive history clears queued entries before the next enable', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final requests = <Map<String, dynamic>>[];

    final actions = _FakeActions(
      statusProvider: () => <String, Object?>{
        'frontmostApp': 'Cursor',
        'frontmostWindowTitle': 'NeoAgent',
        'permissions': const <String, Object?>{'screenCapture': 'available'},
      },
      snapshotProvider: () => DesktopCompanionSnapshot(
        screenshotBase64: base64Encode(Uint8List.fromList(const <int>[1, 2, 3])),
        contentType: 'image/png',
        width: 1,
        height: 1,
        displays: const <Map<String, Object?>>[],
        activeDisplayId: 'primary',
      ),
    );
    final ocr = _FakeOcrBridge(texts: <String>['first upload', 'second upload']);
    final manager = DesktopPassiveHistoryManager(actions: actions, ocrBridge: ocr);
    await manager.bootstrap(prefs);

    await HttpOverrides.runZoned(() async {
      manager.updateRuntimeState(
        backendUrl: 'http://neo.test',
        sessionCookie: 'sid=abc',
        authenticated: true,
        connected: true,
        paused: false,
        deviceId: 'device-a',
        activationId: 'activation-a',
        label: 'Desk',
      );
      await manager.setEnabled(true, prefs);
      await _drain();

      await manager.setEnabled(false, prefs);

      manager.updateRuntimeState(
        backendUrl: 'http://neo.test',
        sessionCookie: 'sid=abc',
        authenticated: true,
        connected: true,
        paused: false,
        deviceId: 'device-a',
        activationId: 'activation-a',
        label: 'Desk',
      );
      await manager.setEnabled(true, prefs);
      await _drain();
    }, createHttpClient: (_) {
      return _FakeHttpClient(
        requests: requests,
        outcomes: <Object>[const SocketException('offline'), 201],
      );
    });

    expect(requests, hasLength(2));
    expect(requests.last['entries'], hasLength(1));
    expect((requests.last['entries'] as List<dynamic>).single['text'], 'second upload');

    manager.dispose();
  });

  test('passive history skips locked, idle, and unavailable OCR states', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final requests = <Map<String, dynamic>>[];
    var status = <String, Object?>{
      'frontmostApp': 'Cursor',
      'frontmostWindowTitle': 'NeoAgent',
      'permissions': const <String, Object?>{'screenCapture': 'available'},
      'sessionLocked': true,
    };
    final actions = _FakeActions(
      statusProvider: () => status,
      snapshotProvider: () => DesktopCompanionSnapshot(
        screenshotBase64: base64Encode(Uint8List.fromList(const <int>[1, 2, 3])),
        contentType: 'image/png',
        width: 1,
        height: 1,
        displays: const <Map<String, Object?>>[],
        activeDisplayId: 'primary',
      ),
    );
    final manager = DesktopPassiveHistoryManager(
      actions: actions,
      ocrBridge: _FakeOcrBridge(unavailableReasonValue: 'Missing OCR runtime.'),
    );
    await manager.bootstrap(prefs);
    await HttpOverrides.runZoned(() async {
      manager.updateRuntimeState(
        backendUrl: 'http://neo.test',
        sessionCookie: 'sid=xyz',
        authenticated: true,
        connected: true,
        paused: false,
        deviceId: 'device-a',
        activationId: 'activation-a',
        label: 'Desk',
      );

      await manager.setEnabled(true, prefs);
      await _drain();
      expect(requests, isEmpty);

      await manager.setEnabled(false, prefs);
      status = <String, Object?>{
        ...status,
        'sessionLocked': false,
        'userIdle': true,
      };
      await manager.setEnabled(true, prefs);
      await _drain();
      expect(requests, isEmpty);

      await manager.setEnabled(false, prefs);
      status = <String, Object?>{
        ...status,
        'userIdle': false,
      };
      await manager.setEnabled(true, prefs);
      await _drain();
      expect(requests, isEmpty);
      expect(manager.lastError, 'Missing OCR runtime.');
    }, createHttpClient: (_) {
      return _FakeHttpClient(requests: requests, outcomes: const <Object>[201]);
    });

    manager.dispose();
  });
}
