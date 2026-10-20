import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/screens/providers_screen.dart';
import 'package:osia_mobile/services/websocket_service.dart';

void main() {
  test('Grok and Groq remain different API configuration entries', () {
    final entries = providersFor(ProviderCategory.ai);
    final grok = entries.singleWhere((entry) => entry.apiProvider == 'xai');
    final groq = entries.singleWhere((entry) => entry.apiProvider == 'groq');
    expect(grok.name, 'Grok / xAI');
    expect(groq.name, 'GroqCloud');
    expect(grok.apiKeyUrl, contains('x.ai'));
    expect(groq.apiKeyUrl, contains('groq.com'));
    expect(osiaStringsEn.grokApiInfo, contains('separate'));
    expect(osiaStringsEn.grokApiInfo, contains('unavailable'));
    expect(osiaStringsFr.grokApiInfo, contains('indisponible'));
  });

  test('PC Grok catalogue is projected with exact provider and effort', () {
    final model = OsiaModel.fromJson({
      'providerId': 'xai',
      'id': 'grok-4.7',
      'displayName': 'Grok 4.7',
      'source': 'provider_discovery',
      'availability': 'listed',
      'inputModalities': ['text', 'image'],
      'reasoning': {
        'selected': 'xhigh',
        'options': [
          {'id': 'auto', 'label': 'Default'},
          {'id': 'xhigh', 'label': 'Extra high'},
        ],
      },
    });
    expect(model.provider, 'xai');
    expect(model.id, 'grok-4.7');
    expect(model.selectedReasoning, 'xhigh');
    expect(model.catalogueSource, 'provider_discovery');
    expect(model.inputModalities, ['text', 'image']);
  });
}
