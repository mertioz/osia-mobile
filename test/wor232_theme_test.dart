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
