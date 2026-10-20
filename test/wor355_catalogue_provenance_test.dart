import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/websocket_service.dart';

void main() {
  test('PC discovery provenance and exact identity survive Mobile parsing', () {
    final model = OsiaModel.fromJson({
      'id': 'gpt-6.1-sol',
      'displayName': 'GPT-6.1 Sol',
      'providerId': 'openai',
      'source': 'provider_discovery',
      'availability': 'listed',
      'inputModalities': ['text', 'image'],
      'selectable': true,
      'reasoning': {
        'options': [
          {'id': 'max', 'label': 'Max'},
        ],
        'selected': 'max',
      },
    });
    expect(model.id, 'gpt-6.1-sol');
    expect(model.provider, 'openai');
    expect(model.label, 'GPT-6.1 Sol');
    expect(model.catalogueSource, 'provider_discovery');
    expect(model.availability, 'listed');
    expect(model.selectedReasoning, 'max');
    expect(model.selectable, isTrue);
  });

  for (final state in ['unverified', 'stale']) {
    test('$state PC entries cannot become selectable on Mobile', () {
      final model = OsiaModel.fromJson({
        'id': 'gpt-6.1-sol',
        'providerId': 'openai',
        'availability': state,
        'selectable': false,
        'usable': false,
      });
      expect(model.selectable, isFalse);
      expect(model.availability, state);
    });
  }
}
