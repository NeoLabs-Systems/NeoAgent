import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';

void main() {
  test('voice state defaults to push-to-talk composed transport', () {
    final state = VoiceAssistantLiveState();

    expect(state.inputMode, 'ptt');
    expect(state.mediaMode, 'composed');
    expect(state.inputSampleRate, 24000);
    expect(state.timeline, isEmpty);
  });

  test('voice timeline remains chronological and derives latest turn text', () {
    final started = DateTime.utc(2026, 8, 9, 12);
    final timeline = <VoiceTimelineItem>[
      VoiceTimelineItem(
        id: 'turn-1-user',
        sessionId: 'session-1',
        turnId: 'turn-1',
        role: 'user',
        kind: 'transcript_final',
        content: 'Check the deployment.',
        isFinal: true,
        createdAt: started,
      ),
      VoiceTimelineItem(
        id: 'delivery-progress',
        sessionId: 'session-1',
        turnId: 'turn-1',
        runId: 'run-1',
        messageId: 'delivery-progress',
        role: 'assistant',
        kind: 'progress',
        content: 'The service health check passed.',
        isFinal: false,
        createdAt: started.add(const Duration(seconds: 15)),
      ),
      VoiceTimelineItem(
        id: 'delivery-final',
        sessionId: 'session-1',
        turnId: 'turn-1',
        runId: 'run-1',
        messageId: 'delivery-final',
        role: 'assistant',
        kind: 'final',
        content: 'Deployment is healthy.',
        isFinal: true,
        createdAt: started.add(const Duration(seconds: 30)),
      ),
    ];
    final state = VoiceAssistantLiveState(
      sessionId: 'session-1',
      activeRunId: 'run-1',
      state: 'working',
      timeline: timeline,
      audioQueue: <Uint8List>[
        Uint8List.fromList(<int>[1, 2]),
      ],
    );

    expect(state.finalTranscript, 'Check the deployment.');
    expect(state.interimAssistantText, 'The service health check passed.');
    expect(state.finalAssistantText, 'Deployment is healthy.');
    expect(state.isBusy, isTrue);

    final interrupted = state.copyWith(clearAudio: true, state: 'interrupted');
    expect(interrupted.audioQueue, isEmpty);
    expect(interrupted.timeline.map((item) => item.id), <String>[
      'turn-1-user',
      'delivery-progress',
      'delivery-final',
    ]);
    expect(interrupted.activeRunId, 'run-1');
  });

  test(
    'voice busy state covers durable run and reconnect presentation states',
    () {
      for (final state in <String>[
        'transcribing',
        'triaging',
        'working',
        'waiting',
        'blocked',
        'speaking',
      ]) {
        expect(VoiceAssistantLiveState(state: state).isBusy, isTrue);
      }
      expect(VoiceAssistantLiveState(state: 'listening').isBusy, isFalse);
    },
  );
}
