import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';

void main() {
  test(
    'incoming call payload does not require or expose an opening message',
    () {
      final call = IncomingAgentCall.fromJson(<String, dynamic>{
        'callId': 'call-1',
        'agentId': 'agent-1',
        'agentName': 'Research Agent',
        'expiresAt': DateTime.now()
            .add(const Duration(seconds: 30))
            .toIso8601String(),
        'openingMessage': 'private until answered',
      });

      expect(call.callId, 'call-1');
      expect(call.agentName, 'Research Agent');
    },
  );
}
