import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/screens/chat_screen.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;
import 'package:osia_mobile/theme.dart';
import 'package:osia_mobile/widgets/accent_logo.dart';
import 'package:osia_mobile/widgets/chat_bubble.dart';
import 'package:osia_mobile/widgets/connection_badge.dart';
import 'package:osia_mobile/widgets/thinking_indicator.dart';

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

List<Color?> _circleColorsWithin(WidgetTester tester, Finder ancestor) {
  return tester
      .widgetList<Container>(
        find.descendant(of: ancestor, matching: find.byType(Container)),
      )
      .map((container) => container.decoration)
      .whereType<BoxDecoration>()
      .where((decoration) => decoration.shape == BoxShape.circle)
      .map((decoration) => decoration.color)
      .toList();
}

Widget _accentHarness(
  ThemeController controller, {
  required VoidCallback onSpeak,
}) {
  return AnimatedBuilder(
    animation: controller,
    child: OsiaL10n(
      strings: osiaStringsEn,
      child: Scaffold(
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ChatBubble(text: 'Assistant response', onSpeak: onSpeak),
            const ThinkingIndicator(),
            const InlineThinkingDots(),
            const AccentLogo(width: 64, height: 64),
          ],
        ),
      ),
    ),
    builder: (context, child) {
      final palette = controller.palette;
      return MaterialApp(
        theme: buildOsiaTheme(palette),
        home: OsiaTheme(palette: palette, child: child!),
      );
    },
  );
}

void _expectAccentSurfaces(WidgetTester tester, OsiaPalette palette) {
  final speakIcon = tester.widget<Icon>(find.byIcon(Icons.volume_up_rounded));
  expect(speakIcon.color, palette.accent);

  expect(
    _circleColorsWithin(tester, find.byType(ThinkingIndicator)),
    everyElement(palette.accent),
  );
  expect(
    _circleColorsWithin(tester, find.byType(InlineThinkingDots)),
    everyElement(palette.accent),
  );

  final logo = tester.widget<Image>(
    find.descendant(of: find.byType(AccentLogo), matching: find.byType(Image)),
  );
  expect(logo.color, palette.accent);
  expect(logo.colorBlendMode, BlendMode.srcIn);
  expect((logo.image as AssetImage).assetName, 'assets/osia_logo_mark.png');
}

void main() {
  testWidgets(
    'all supported accents tint TTS, both thinking animations, and the logo',
    (tester) async {
      final controller = ThemeController();
      addTearDown(controller.dispose);
      var speakCount = 0;

      await tester.pumpWidget(
        _accentHarness(controller, onSpeak: () => speakCount++),
      );
      await tester.pump();

      for (final palette in osiaPalettes) {
        controller.setPaletteByKey(palette.key);
        await tester.pump();
        _expectAccentSurfaces(tester, palette);
        expect(
          _contrastRatio(palette.accent, palette.background),
          greaterThanOrEqualTo(3),
        );
      }

      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      await tester.pump();
      expect(speakCount, 1);

      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(tester.takeException(), isNull);
      expect(
        _circleColorsWithin(tester, find.byType(ThinkingIndicator)),
        hasLength(3),
      );
      expect(
        _circleColorsWithin(tester, find.byType(InlineThinkingDots)),
        hasLength(3),
      );
    },
  );

  testWidgets('mounted accent surfaces update immediately at runtime', (
    tester,
  ) async {
    final controller = ThemeController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_accentHarness(controller, onSpeak: () {}));
    await tester.pump();

    final bubbleState = tester.state(find.byType(ChatBubble));
    final thinkingState = tester.state(find.byType(ThinkingIndicator));
    final inlineState = tester.state(find.byType(InlineThinkingDots));
    final logoElement = tester.element(find.byType(AccentLogo));

    for (final palette in <OsiaPalette>[
      osiaPaletteAzure,
      osiaPaletteEmerald,
      osiaPaletteRose,
      osiaPalette,
    ]) {
      controller.setPaletteByKey(palette.key);
      await tester.pump();
      _expectAccentSurfaces(tester, palette);
      expect(tester.state(find.byType(ChatBubble)), same(bubbleState));
      expect(tester.state(find.byType(ThinkingIndicator)), same(thinkingState));
      expect(tester.state(find.byType(InlineThinkingDots)), same(inlineState));
      expect(tester.element(find.byType(AccentLogo)), same(logoElement));
    }
  });

  for (final palette in osiaPalettes) {
    testWidgets('${palette.key} keeps connectivity semantic colors', (
      tester,
    ) async {
      Future<Color?> pumpState(ws.ConnectionState state) async {
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
        return _circleColorsWithin(tester, find.byType(ConnectionBadge)).single;
      }

      expect(await pumpState(ws.ConnectionState.connected), palette.success);
      expect(await pumpState(ws.ConnectionState.disconnected), palette.error);
    });
  }
}
