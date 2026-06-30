import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/recording_payloads.dart';

void main() {
  group('buildWebScreenAndMicRecordingPayload', () {
    final payload = buildWebScreenAndMicRecordingPayload();
    final sources = (payload['sources'] as List).cast<Map<String, dynamic>>();

    Map<String, dynamic> sourceFor(String key) =>
        sources.firstWhere((source) => source['sourceKey'] == key);

    test('captures screen, system audio, and microphone', () {
      expect(payload['platform'], 'web');
      expect(
        sources.map((source) => source['sourceKey']).toSet(),
        <String>{'screen', 'system', 'microphone'},
      );
    });

    test('system audio is a transcribable audio source', () {
      final system = sourceFor('system');
      expect(system['mediaKind'], 'audio');
      expect(system['mimeType'], 'audio/webm');
      expect((system['metadata'] as Map)['transcribe'], true);
    });

    test('screen stays a non-transcribed video source for analysis', () {
      final screen = sourceFor('screen');
      expect(screen['mediaKind'], 'video');
      expect((screen['metadata'] as Map)['transcribe'], false);
    });

    test('microphone remains an audio source', () {
      final microphone = sourceFor('microphone');
      expect(microphone['mediaKind'], 'audio');
      expect(microphone['mimeType'], 'audio/webm');
    });
  });
}
