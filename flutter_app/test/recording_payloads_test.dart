import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/recording_payloads.dart';

void main() {
  group('recording payload builders', () {
    test('web screen and mic payload keeps both sources', () {
      final payload = buildWebScreenAndMicRecordingPayload();
      final sources = payload['sources'] as List<dynamic>;

      expect(payload['platform'], 'web');
      expect(payload['screenAnalysisReady'], true);
      expect(sources, hasLength(2));
      expect(
        sources.map((item) => (item as Map<String, dynamic>)['sourceKey']),
        containsAll(<String>['screen', 'microphone']),
      );
    });

    test('android background payload keeps background metadata', () {
      final payload = buildAndroidBackgroundRecordingPayload();
      final source = (payload['sources'] as List<dynamic>).single
          as Map<String, dynamic>;

      expect(payload['platform'], 'android');
      expect(source['sourceKey'], 'microphone');
      expect(source['mimeType'], 'audio/wav');
      expect(
        (source['metadata'] as Map<String, dynamic>)['backgroundCapable'],
        true,
      );
    });

    test('desktop payload advertises dual-source desktop capture metadata', () {
      final payload = buildDesktopRecordingPayload();
      final sources = (payload['sources'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final systemSource = sources.firstWhere(
        (source) => source['sourceKey'] == 'system',
      );

      expect(payload['platform'], 'desktop');
      expect(payload['capturePlan'], 'desktop-dual-source');
      expect(
        sources.map((source) => source['sourceKey']),
        containsAll(<String>['microphone', 'system']),
      );
      expect(
        (systemSource['metadata'] as Map<String, dynamic>)['globalHotkeyReady'],
        true,
      );
    });
  });
}
