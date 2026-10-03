import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/screens/settings_screen.dart';
import 'package:osia_mobile/theme.dart';

void main() {
  test('theme keys and protected OSIA default match the PC catalog', () {
    expect(osiaPalettes.map((palette) => palette.key), <String>[
      'osia',
      'azure',
      'emerald',
      'rose',
      'amber',
      'neutral',
    ]);
    expect(osiaPalette.background, const Color(0xFF0D0B12));
    expect(osiaPalette.accent, const Color(0xFFC4B5F5));
    expect(paletteForKey('violet'), same(osiaPalette));
    expect(paletteForKey('red'), same(osiaPalette));
    expect(paletteForKey('green'), same(osiaPalette));
  });

  test('shared theme status colors match the PC palette', () {
    for (final palette in osiaPalettes) {
      expect(palette.thinking, palette.accent, reason: palette.key);
      expect(palette.error, const Color(0xFFE0A3A3), reason: palette.key);
      expect(palette.success, const Color(0xFF6FCF97), reason: palette.key);
      expect(
        palette.warning,
        palette.key == 'amber'
            ? const Color(0xFFE6C97A)
            : const Color(0xFFE0A23C),
        reason: palette.key,
      );
    }
  });

  testWidgets('selector exposes only PC themes and updates the active key', (
    tester,
  ) async {
    final controller = ThemeController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final palette = controller.palette;
          return MaterialApp(
            home: OsiaTheme(
              palette: palette,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: AccentThemeSelector(
                    currentKey: palette.key,
                    onTap: controller.setPaletteByKey,
                    palette: palette,
                    strings: osiaStringsEn,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    await tester.pump();

    for (final key in <String>[
      'osia',
      'azure',
      'emerald',
      'rose',
      'amber',
      'neutral',
    ]) {
      expect(find.byKey(Key('theme-option-$key')), findsOneWidget);
    }
    for (final key in <String>[
      'violet',
      'noir',
      'blanc',
      'dore',
      'red',
      'green',
    ]) {
      expect(find.byKey(Key('theme-option-$key')), findsNothing);
    }

    await tester.tap(find.byKey(const Key('theme-option-amber')));
    await tester.pump();
    expect(controller.palette.key, 'amber');
  });
}
