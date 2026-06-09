import 'package:flutter_test/flutter_test.dart';

import '../../../flutter_app/lib/main.dart';

void main() {
  test('McpServerItem parses recovery details', () {
    final item = McpServerItem.fromJson(<String, dynamic>{
      'id': 12,
      'name': 'Research tools',
      'command': 'https://mcp.example.test/sse',
      'config': <String, dynamic>{},
      'enabled': true,
      'status': 'reconnecting',
      'toolCount': 0,
      'error': 'Connection refused',
      'consecutiveFails': 4,
      'nextRetryAt': '2026-06-06T12:30:00.000Z',
    });

    expect(item.status, 'reconnecting');
    expect(item.hasError, isTrue);
    expect(item.error, 'Connection refused');
    expect(item.consecutiveFails, 4);
    expect(item.nextRetryAt, isNotNull);
    expect(item.retryLabel, isNotEmpty);
  });
}
