import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;
import 'package:osia_mobile/widgets/model_selector_sheet.dart';

void main() {
  group('reasoningOptionsForModel', () {
    test('uses only authoritative PC catalogue metadata', () {
      final model = ws.OsiaModel(
        id: 'gpt-5.6-sol',
        label: 'GPT-5.6-Sol',
        provider: 'chatgpt_account',
        reasoningOptions: const [
          ws.OsiaModelReasoningOption(
            id: 'auto',
            label: 'Default',
            isDefault: true,
          ),
          ws.OsiaModelReasoningOption(id: 'max', label: 'Max'),
          ws.OsiaModelReasoningOption(id: 'ultra', label: 'Ultra'),
        ],
      );

      expect(reasoningOptionsForModel(model).map((option) => option.id), [
        'auto',
        'max',
        'ultra',
      ]);
    });

    test(
      'authoritative absence hides the selector without local inference',
      () {
        for (final model in [
          const ws.OsiaModel(
            id: 'deepseek-v4-pro',
            label: 'DeepSeek V4 Pro',
            provider: 'deepseek',
          ),
          const ws.OsiaModel(
            id: 'gpt-5.5',
            label: 'GPT-5.5',
            provider: 'openai',
          ),
          const ws.OsiaModel(
            id: 'gemini-3.5-flash',
            label: 'Gemini 3.5 Flash',
            provider: 'google',
          ),
        ]) {
          expect(reasoningOptionsForModel(model), isEmpty);
        }
      },
    );
  });

  group('OsiaReasoningConfig', () {
    test('parses absent and partial config safely', () {
      expect(ws.OsiaReasoningConfig.fromJson(null).toJson(), {
        'default': 'auto',
        'providers': <String, String>{},
        'models': <String, String>{},
      });

      final cfg = ws.ConfigData.fromJson({
        'reasoning': {
          'default': 'HIGH',
          'providers': {'Google': 'LOW'},
          'models': {'deepseek-v4-pro': 'MAX', 'gemini-3.5-flash': 'LOUD'},
        },
      });
      expect(cfg.reasoning.defaultLevel, 'high');
      expect(cfg.reasoning.providers, {'google': 'low'});
      expect(cfg.reasoning.models, {
        'deepseek-v4-pro': 'max',
        'gemini-3.5-flash': 'auto',
      });
    });

    test('builds set_setting reasoning payload shape', () {
      final next = const ws.OsiaReasoningConfig().withModelOverride(
        'deepseek-v4-pro',
        'max',
      );

      expect(next.toJson(), {
        'default': 'auto',
        'providers': <String, String>{},
        'models': {'deepseek-v4-pro': 'max'},
      });
    });
  });
}
