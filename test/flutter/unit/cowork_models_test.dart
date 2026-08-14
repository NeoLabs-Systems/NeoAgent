import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';

void main() {
  test('Cowork chat keeps the per-chat mode and device override', () {
    final chat = CoworkChat.fromJson(<String, dynamic>{
      'id': 'chat-1',
      'agentId': 'agent-1',
      'agentName': 'Builder',
      'title': 'Implement desktop mode',
      'mode': 'plan',
      'device': <String, dynamic>{
        'override': 'local',
        'setting': 'cloud',
        'effective': 'local',
        'inherited': false,
        'available': true,
        'providers': <String, dynamic>{
          'cloud': <String, dynamic>{'available': true},
          'local': <String, dynamic>{'available': true, 'connected': true},
        },
      },
    });

    expect(chat.mode, CoworkInteractionMode.plan);
    expect(chat.device.override, 'local');
    expect(chat.device.setting, 'cloud');
    expect(chat.device.effective, 'local');
    expect(chat.device.inherited, isFalse);
    expect(chat.device.localAvailable, isTrue);
  });

  test('Cowork structured questions expose options and pending state', () {
    final request = CoworkInputRequest.fromJson(<String, dynamic>{
      'id': 'request-1',
      'conversationId': 'chat-1',
      'runId': 'run-1',
      'status': 'pending',
      'schema': <String, dynamic>{
        'questions': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'scope',
            'header': 'Scope',
            'question': 'Which scope?',
            'allowCustom': true,
            'options': <Map<String, dynamic>>[
              <String, dynamic>{
                'label': 'Desktop',
                'description': 'Desktop only.',
                'recommended': true,
              },
              <String, dynamic>{
                'label': 'All clients',
                'description': 'Every client.',
              },
            ],
          },
        ],
      },
    });

    expect(request.isPending, isTrue);
    expect(request.questions, hasLength(1));
    expect(request.questions.single.options.first.recommended, isTrue);
    expect(request.questions.single.allowCustom, isTrue);
  });
}
