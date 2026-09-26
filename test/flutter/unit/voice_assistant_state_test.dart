import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';

void main() {
  test('voice state defaults to a hands-free live call', () {
    final state = VoiceAssistantLiveState();

    expect(state.inputMode, 'hands_free');
    expect(state.isHandsFree, isTrue);
    expect(state.inputSampleRate, 24000);
    expect(state.outputSampleRate, 24000);
    expect(state.hasActiveSession, isFalse);
    expect(state.hasActiveTask, isFalse);
    expect(state.timeline, isEmpty);
  });

  test('voice timeline stays chronological and derives the latest turns', () {
    final started = DateTime.utc(2026, 9, 26, 12);
    final state = VoiceAssistantLiveState(
      sessionId: 'session-1',
      activeRunId: 'run-1',
      activeTaskRequest: 'Check the deployment',
      state: 'speaking',
      timeline: <VoiceTimelineItem>[
        VoiceTimelineItem(
          id: 'user-1',
          role: 'user',
          content: 'Check the deployment.',
          isFinal: true,
          createdAt: started,
        ),
        VoiceTimelineItem(
          id: 'assistant-1',
          role: 'assistant',
          content: 'On it, checking now.',
          isFinal: false,
          createdAt: started.add(const Duration(seconds: 1)),
        ),
      ],
    );

    expect(state.finalTranscript, 'Check the deployment.');
    expect(state.assistantText, 'On it, checking now.');
    expect(state.isSpeaking, isTrue);
    expect(state.hasActiveTask, isTrue);

    final settled = state.copyWith(
      state: 'listening',
      activeRunId: '',
      activeTaskRequest: '',
      timeline: <VoiceTimelineItem>[
        state.timeline.first,
        state.timeline.last.copyWith(isFinal: true),
      ],
    );
    expect(settled.isSpeaking, isFalse);
    expect(settled.hasActiveTask, isFalse);
    expect(settled.timeline.map((item) => item.id), <String>[
      'user-1',
      'assistant-1',
    ]);
    expect(settled.timeline.last.isFinal, isTrue);
  });

  test('connecting states are reported while the live model starts', () {
    expect(VoiceAssistantLiveState(state: 'connecting').isConnecting, isTrue);
    expect(VoiceAssistantLiveState(state: 'reconnecting').isConnecting, isTrue);
    expect(VoiceAssistantLiveState(state: 'listening').isConnecting, isFalse);
  });
}
