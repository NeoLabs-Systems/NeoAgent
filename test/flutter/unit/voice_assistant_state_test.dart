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
      tasks: const <VoiceCallTask>[
        VoiceCallTask(runId: 'run-1', request: 'Check the deployment'),
      ],
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
      tasks: const <VoiceCallTask>[],
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

  test('a call can run several tasks and shows the newest', () {
    final state = VoiceAssistantLiveState(
      tasks: const <VoiceCallTask>[
        VoiceCallTask(runId: 'run-1', request: 'Book the table'),
        VoiceCallTask(runId: 'run-2', request: 'Compare laptops'),
      ],
    );
    expect(state.hasActiveTask, isTrue);
    expect(state.activeRunId, 'run-2');
    expect(state.activeTaskRequest, 'Compare laptops');
    final first = state.copyWith(tasks: <VoiceCallTask>[state.tasks.first]);
    expect(first.activeRunId, 'run-1');
    expect(first.activeTaskRequest, 'Book the table');
  });

  test('keyboard clicks belong only to a silent in-progress voice task', () {
    final working = VoiceAssistantLiveState(
      sessionId: 'session-1',
      tasks: const <VoiceCallTask>[VoiceCallTask(runId: 'run-1')],
      state: 'listening',
    );
    expect(working.isWorkingSilently, isTrue);
    expect(working.copyWith(state: 'speaking').isWorkingSilently, isFalse);
    expect(working.copyWith(state: 'connecting').isWorkingSilently, isFalse);
    expect(
      working.copyWith(tasks: const <VoiceCallTask>[]).isWorkingSilently,
      isFalse,
    );
    expect(
      working
          .copyWith(error: 'The live voice connection ended.')
          .isWorkingSilently,
      isFalse,
    );
    expect(
      VoiceAssistantLiveState(
        tasks: const <VoiceCallTask>[VoiceCallTask(runId: 'run-1')],
        state: 'listening',
      ).isWorkingSilently,
      isFalse,
    );
  });
}
