import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;
import 'package:osia_mobile/widgets/model_selector_sheet.dart';

void main() {
  group('reasoningOptionsForModel', () {
    List<String> ids(String provider, String modelId) =>
        reasoningOptionsForModel(
          ws.OsiaModel(id: modelId, label: modelId, provider: provider),
        ).map((option) => option.id).toList();

    test('matches verified provider/model option sets', () {
      expect(ids('deepseek', 'deepseek-v4-pro'), [
        'auto',
        'off',
        'normal',
        'max',
      ]);
      expect(ids('deepseek', 'deepseek-v4-pro'), isNot(contains('low')));
      expect(ids('deepseek', 'deepseek-v4-pro'), isNot(contains('medium')));
      expect(ids('deepseek', 'deepseek-v4-pro'), isNot(contains('high')));

      expect(ids('google', 'gemini-3.5-flash'), [
        'auto',
        'minimal',
        'low',
        'medium',
        'high',
      ]);
      expect(ids('google', 'gemini-2.5-flash'), [
        'auto',
        'off',
        'minimal',
        'low',
        'medium',
        'high',
      ]);
      expect(ids('groq', 'openai/gpt-oss-120b'), [
        'auto',
        'low',
        'medium',
        'high',
      ]);
      expect(ids('mistral', 'mistral-medium-3-5'), [
        'auto',
        'off',
        'minimal',
        'low',
        'medium',
        'high',
        'xhigh',
      ]);
    });

    test('exposes OpenAI reasoning options for supported GPT models', () {
      expect(ids('openai', 'gpt-5.5'), [
        'auto',
        'off',
        'minimal',
        'low',
        'medium',
        'high',
        'xhigh',
      ]);
      expect(ids('openai', 'gpt-4.1'), isEmpty);
    });

    test('exposes Claude reasoning options by model support', () {
      expect(ids('anthropic', 'claude-opus-4-8'), [
        'auto',
        'off',
        'low',
        'medium',
        'high',
        'xhigh',
        'max',
      ]);

      expect(ids('anthropic', 'claude-sonnet-4-6'), [
        'auto',
        'off',
        'low',
        'medium',
        'high',
        'max',
      ]);
      expect(ids('anthropic', 'claude-sonnet-4-6'), contains('max'));
      expect(ids('anthropic', 'claude-sonnet-4-6'), isNot(contains('xhigh')));
      expect(ids('anthropic', 'claude-haiku-4-5-20251001'), isEmpty);
    });

    test('does not expose controls for unsupported models', () {
      expect(ids('xai', 'grok-3'), isEmpty);
      expect(ids('groq', 'llama-3.3-70b-versatile'), isEmpty);
      expect(ids('mistral', 'mistral-large-2512'), isEmpty);
    });
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
