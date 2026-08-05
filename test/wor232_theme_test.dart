import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/screens/settings_screen.dart';
import 'package:osia_mobile/services/storage_service.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;
import 'package:osia_mobile/theme.dart';
import 'package:osia_mobile/widgets/connection_badge.dart';

const _existingPaletteKeys = <String>[
  'violet',
  'rose',
  'noir',
  'blanc',
  'dore',
];

const _previousRedAccent = Color(0xFFF29B93);

List<Object> _paletteSnapshot(OsiaPalette palette) => <Object>[
  palette.key,
  palette.label,
  palette.background,
  palette.accent,
  palette.secondary,
  palette.surface,
  palette.surfaceElevated,
  palette.border,
  palette.textPrimary,
  palette.textMuted,
  palette.userBubble,
  palette.assistantBubble,
  palette.thinking,
  palette.error,
  palette.success,
  palette.warning,
  palette.info,
  palette.isDark,
  palette.swatch,
];

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

Future<void> _pumpSelector(
  WidgetTester tester, {
  required ThemeController controller,
  required StorageService storage,
  double width = 360,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final palette = controller.palette;
        return MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: palette.accent,
              brightness: palette.isDark ? Brightness.dark : Brightness.light,
            ).copyWith(primary: palette.accent),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: OsiaTheme(
            palette: palette,
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  child: SingleChildScrollView(
                    child: AccentThemeSelector(
                      currentKey: palette.key,
                      onTap: (key) {
                        controller.setPaletteByKey(key);
                        unawaited(storage.setThemeKey(key));
                      },
                      palette: palette,
                      strings: osiaStringsEn,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('palette model and persistence', () {
    test('existing and WOR-232 palette IDs round-trip unchanged', () {
      expect(osiaPalettes.map((palette) => palette.key), <String>[
        ..._existingPaletteKeys,
        'red',
        'green',
      ]);
      for (final key in _existingPaletteKeys) {
        expect(paletteForKey(key).key, key);
      }
      expect(paletteForKey('red'), same(osiaPaletteRed));
      expect(paletteForKey('green'), same(osiaPaletteGreen));
    });

    test('unknown and null values fall back to the unchanged default', () {
      expect(paletteForKey(null), same(osiaPaletteViolet));
      expect(paletteForKey('obsolete'), same(osiaPaletteViolet));
      expect(ThemeController().palette, same(osiaPaletteViolet));
    });

    test(
      'red and green persist and restore through the existing key',
      () async {
        final storage = StorageService();
        for (final key in <String>['red', 'green']) {
          await storage.setThemeKey(key);
          final restored = ThemeController();
          restored.setPaletteByKey(await storage.getThemeKey() ?? '');
          expect(restored.palette.key, key);
          restored.dispose();
        }
      },
    );

    test('appearance palette changes do not mutate a restored accent', () {
      final controller = ThemeController(initial: osiaPaletteGreen);
      expect(controller.palette.isDark, isTrue);
      expect(controller.palette.key, 'green');
      controller.setPaletteByKey('blanc');
      expect(controller.palette.isDark, isFalse);
      controller.setPaletteByKey('green');
      expect(controller.palette.key, 'green');
      controller.dispose();
    });

    test(
      'new palette tokens resolve with semantic distinction and contrast',
      () {
        for (final palette in <OsiaPalette>[osiaPaletteRed, osiaPaletteGreen]) {
          expect(palette.accent, isNot(palette.error));
          expect(palette.accent, isNot(palette.success));
          expect(palette.error, isNot(palette.success));
          expect(palette.warning, isNot(palette.info));
          expect(
            _contrastRatio(palette.accent, palette.surface),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            _contrastRatio(
              palette.foregroundOn(palette.secondary),
              palette.secondary,
            ),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            _contrastRatio(
              palette.foregroundOn(palette.swatch),
              palette.swatch,
            ),
            greaterThanOrEqualTo(4.5),
          );
          expect(palette.foregroundOn(palette.accent), isNotNull);
        }
        expect(osiaPaletteRed.accent, isNot(osiaPaletteRed.error));
        expect(osiaPaletteGreen.accent, isNot(osiaPaletteGreen.success));
      },
    );

    test('red uses a deeper saturated ruby palette', () {
      expect(_paletteSnapshot(osiaPaletteRed), <Object>[
        'red',
        'Red',
        const Color(0xFF10090B),
        const Color(0xFFE64256),
        const Color(0xFFA72D3C),
        const Color(0xFF201214),
        const Color(0xFF2B171B),
        const Color(0xFF482128),
        const Color(0xFFFFF4F3),
        const Color(0xFFA18E8D),
        const Color(0xFF36191E),
        const Color(0xFF201214),
        const Color(0xFFC4B5F5),
        const Color(0xFFFF5D73),
        const Color(0xFF3DDC84),
        const Color(0xFFF4C15D),
        const Color(0xFF62B7F5),
        true,
        const Color(0xFFE64256),
      ]);
      expect(osiaPaletteRed.accent, isNot(_previousRedAccent));

      final previous = HSVColor.fromColor(_previousRedAccent);
      final ruby = HSVColor.fromColor(osiaPaletteRed.accent);
      expect(ruby.saturation, greaterThan(previous.saturation + 0.25));
      expect(ruby.value, lessThan(previous.value - 0.04));
    });

    test('red accent remains distinct from its brighter error token', () {
      final ruby = HSVColor.fromColor(osiaPaletteRed.accent);
      final error = HSVColor.fromColor(osiaPaletteRed.error);
      final rubyHsl = HSLColor.fromColor(osiaPaletteRed.accent);
      final errorHsl = HSLColor.fromColor(osiaPaletteRed.error);

      expect(osiaPaletteRed.accent, isNot(osiaPaletteRed.error));
      expect(error.value, greaterThanOrEqualTo(ruby.value + 0.09));
      expect(errorHsl.saturation, greaterThan(rubyHsl.saturation));
    });

    test('all non-red palette tokens remain unchanged', () {
      expect(
        <List<Object>>[
          _paletteSnapshot(osiaPaletteViolet),
          _paletteSnapshot(osiaPaletteRose),
          _paletteSnapshot(osiaPaletteNoir),
          _paletteSnapshot(osiaPaletteBlanc),
          _paletteSnapshot(osiaPaletteDore),
          _paletteSnapshot(osiaPaletteGreen),
        ],
        <List<Object>>[
          <Object>[
            'violet',
            'Violet',
            const Color(0xFF0D0B12),
            const Color(0xFFC4B5F5),
            const Color(0xFF7C3AED),
            const Color(0xFF1A1625),
            const Color(0xFF221C30),
            const Color(0xFF2A2438),
            const Color(0xFFF5F3FF),
            const Color(0xFF8B8A90),
            const Color(0xFF2A2440),
            const Color(0xFF181426),
            const Color(0xFFC4B5F5),
            const Color(0xFFEF4444),
            const Color(0xFF22C55E),
            const Color(0xFFEAB308),
            const Color(0xFF38BDF8),
            true,
            const Color(0xFFC4B5F5),
          ],
          <Object>[
            'rose',
            'Rose',
            const Color(0xFF120B0E),
            const Color(0xFFF5B5C4),
            const Color(0xFFED4F87),
            const Color(0xFF22161B),
            const Color(0xFF2E1B22),
            const Color(0xFF3A2530),
            const Color(0xFFFFF3F6),
            const Color(0xFF9C8B91),
            const Color(0xFF38222A),
            const Color(0xFF22161B),
            const Color(0xFFC4B5F5),
            const Color(0xFFEF4444),
            const Color(0xFF22C55E),
            const Color(0xFFEAB308),
            const Color(0xFF38BDF8),
            true,
            const Color(0xFFF5B5C4),
          ],
          <Object>[
            'noir',
            'Noir',
            const Color(0xFF000000),
            const Color(0xFFEDEDED),
            const Color(0xFF6B6B6B),
            const Color(0xFF101010),
            const Color(0xFF1A1A1A),
            const Color(0xFF262626),
            const Color(0xFFFFFFFF),
            const Color(0xFF8A8A8A),
            const Color(0xFF1F1F1F),
            const Color(0xFF101010),
            const Color(0xFFC4B5F5),
            const Color(0xFFEF4444),
            const Color(0xFF22C55E),
            const Color(0xFFEAB308),
            const Color(0xFF38BDF8),
            true,
            const Color(0xFF1A1A1A),
          ],
          <Object>[
            'blanc',
            'Blanc',
            const Color(0xFFFAF8FF),
            const Color(0xFF7C3AED),
            const Color(0xFF5B21B6),
            const Color(0xFFFFFFFF),
            const Color(0xFFF3EFFB),
            const Color(0xFFE5DEF6),
            const Color(0xFF14101F),
            const Color(0xFF6E6B7A),
            const Color(0xFFEDE5FE),
            const Color(0xFFFFFFFF),
            const Color(0xFFC4B5F5),
            const Color(0xFFD93030),
            const Color(0xFF168A4B),
            const Color(0xFF9A6700),
            const Color(0xFF006E9C),
            false,
            const Color(0xFFFFFFFF),
          ],
          <Object>[
            'dore',
            'Doré',
            const Color(0xFF110E0A),
            const Color(0xFFE6C97A),
            const Color(0xFFC79D3E),
            const Color(0xFF1F1A12),
            const Color(0xFF2B2419),
            const Color(0xFF3A301F),
            const Color(0xFFFAF1DC),
            const Color(0xFF9C8C6E),
            const Color(0xFF2B2419),
            const Color(0xFF1F1A12),
            const Color(0xFFC4B5F5),
            const Color(0xFFEF4444),
            const Color(0xFF22C55E),
            const Color(0xFFEAB308),
            const Color(0xFF38BDF8),
            true,
            const Color(0xFFE6C97A),
          ],
          <Object>[
            'green',
            'Green',
            const Color(0xFF0A110E),
            const Color(0xFF8BD7A5),
            const Color(0xFF3A9564),
            const Color(0xFF142019),
            const Color(0xFF1B2B22),
            const Color(0xFF263A2E),
            const Color(0xFFF1FBF4),
            const Color(0xFF8FA298),
            const Color(0xFF1F3428),
            const Color(0xFF142019),
            const Color(0xFFC4B5F5),
            const Color(0xFFFF667A),
            const Color(0xFF38C77A),
            const Color(0xFFF1BC57),
            const Color(0xFF65B8F7),
            true,
            const Color(0xFF8BD7A5),
          ],
        ],
      );
    });
  });

  group('accent selector', () {
    testWidgets('shows every option with one non-color selected marker', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final controller = ThemeController();
      addTearDown(controller.dispose);
      await _pumpSelector(
        tester,
        controller: controller,
        storage: StorageService(),
      );

      for (final palette in osiaPalettes) {
        expect(find.byKey(Key('theme-option-${palette.key}')), findsOneWidget);
      }
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      final selectedNodes = osiaPalettes.where((palette) {
        final data = tester
            .getSemantics(find.byKey(Key('theme-option-${palette.key}')))
            .getSemanticsData();
        return data.flagsCollection.isSelected == Tristate.isTrue;
      });
      expect(selectedNodes.map((palette) => palette.key), ['violet']);
      semantics.dispose();
    });

    testWidgets('red and green update live and persist', (tester) async {
      final controller = ThemeController();
      addTearDown(controller.dispose);
      final storage = StorageService();
      await _pumpSelector(tester, controller: controller, storage: storage);

      for (final palette in <OsiaPalette>[osiaPaletteRed, osiaPaletteGreen]) {
        await tester.tap(find.byKey(Key('theme-option-${palette.key}')));
        await tester.pumpAndSettle();
        expect(controller.palette, same(palette));
        expect(await storage.getThemeKey(), palette.key);
        expect(
          Theme.of(
            tester.element(find.byKey(Key('theme-option-${palette.key}'))),
          ).colorScheme.primary,
          palette.accent,
        );
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      }
    });

    testWidgets('has no overflow at narrow width or enlarged text', (
      tester,
    ) async {
      final controller = ThemeController(initial: osiaPaletteRed);
      addTearDown(controller.dispose);
      final storage = StorageService();
      await _pumpSelector(
        tester,
        controller: controller,
        storage: storage,
        width: 240,
      );
      expect(tester.takeException(), isNull);

      await _pumpSelector(
        tester,
        controller: controller,
        storage: storage,
        width: 280,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Green'), findsOneWidget);
    });
  });

  group('semantic status identity', () {
    for (final palette in <OsiaPalette>[osiaPaletteRed, osiaPaletteGreen]) {
      testWidgets('${palette.key} keeps success and error status identity', (
        tester,
      ) async {
        Future<void> pumpBadge(ws.ConnectionState state) async {
          await tester.pumpWidget(
            MaterialApp(
              home: OsiaTheme(
                palette: palette,
                child: OsiaL10n(
                  strings: osiaStringsEn,
                  child: Scaffold(body: ConnectionBadge(state: state)),
                ),
              ),
            ),
          );
        }

        await pumpBadge(ws.ConnectionState.connected);
        expect(find.byTooltip(osiaStringsEn.connected), findsOneWidget);
        final successDot = tester
            .widgetList<Container>(find.byType(Container))
            .map((container) => container.decoration)
            .whereType<BoxDecoration>()
            .singleWhere((decoration) => decoration.shape == BoxShape.circle);
        expect(successDot.color, palette.success);

        await pumpBadge(ws.ConnectionState.disconnected);
        expect(find.byTooltip(osiaStringsEn.disconnected), findsOneWidget);
        final errorDot = tester
            .widgetList<Container>(find.byType(Container))
            .map((container) => container.decoration)
            .whereType<BoxDecoration>()
            .singleWhere((decoration) => decoration.shape == BoxShape.circle);
        expect(errorDot.color, palette.error);
        expect(errorDot.color, isNot(successDot.color));
      });
    }
  });
}
