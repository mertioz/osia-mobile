import 'package:flutter_test/flutter_test.dart';

import 'package:osia_mobile/l10n.dart';

void main() {
  group('osiaStringsForCode', () {
    test('resolves every supported language', () {
      for (final code in osiaSupportedLanguages) {
        expect(osiaStringsForCode(code).languageCode, code);
      }
    });

    test('falls back to English for unknown or null codes', () {
      expect(osiaStringsForCode('xx').languageCode, 'en');
      expect(osiaStringsForCode(null).languageCode, 'en');
      expect(osiaStringsForCode('').languageCode, 'en');
    });
  });

  group('OsiaStrings templates', () {
    test('substitute their placeholders', () {
      for (final s in osiaAllStrings) {
        expect(s.deleteConversationBody('Foo'), contains('Foo'));
        expect(s.deleteConversationBody('Foo'), isNot(contains('{title}')));
        expect(s.daysAgo(3), contains('3'));
        expect(s.daysAgo(3), isNot(contains('{n}')));
        expect(s.hereIsFile('a.txt'), contains('a.txt'));
        expect(s.filePickFailed('boom'), contains('boom'));
        expect(s.fileReadFailed('boom'), contains('boom'));
      }
    });

    test('theme names cover all palette keys', () {
      for (final s in osiaAllStrings) {
        for (final key in [
          'violet',
          'rose',
          'noir',
          'blanc',
          'dore',
          'red',
          'green',
        ]) {
          expect(s.themeName(key), isNotEmpty);
          // Unknown keys fall back to the raw key rather than crashing.
          expect(s.themeName('unknown'), 'unknown');
        }
      }
    });
  });

  group('LanguageController', () {
    test('switches language and notifies once per change', () {
      final controller = LanguageController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      expect(controller.code, 'en');
      controller.setLanguageByCode('fr');
      expect(controller.code, 'fr');
      expect(notifications, 1);

      // Setting the same language again must not notify.
      controller.setLanguageByCode('fr');
      expect(notifications, 1);

      // Unknown codes resolve to English.
      controller.setLanguageByCode('xx');
      expect(controller.code, 'en');
      expect(notifications, 2);
    });
  });
}
