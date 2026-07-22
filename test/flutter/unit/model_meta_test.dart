import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';

void main() {
  test(
    'ModelMeta keeps selection identity separate from provider model id',
    () {
      final model = ModelMeta.fromJson(<String, dynamic>{
        'id': 'openai::gpt-5.3',
        'modelId': 'gpt-5.3',
        'label': 'GPT-5.3 (OpenAI)',
        'provider': 'openai',
        'purpose': 'general',
      });

      expect(model.id, 'openai::gpt-5.3');
      expect(model.modelId, 'gpt-5.3');
    },
  );

  test('ModelMeta accepts catalogs from older servers', () {
    final model = ModelMeta.fromJson(<String, dynamic>{
      'id': 'gpt-5.3',
      'label': 'GPT-5.3',
      'provider': 'openai',
      'purpose': 'general',
    });

    expect(model.id, 'gpt-5.3');
    expect(model.modelId, 'gpt-5.3');
  });
}
