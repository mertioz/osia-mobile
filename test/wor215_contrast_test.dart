import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/screens/chat_screen.dart';
import 'package:osia_mobile/theme.dart';

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

void _expectTextContrast(Color? foreground, Color? background, String reason) {
  expect(foreground, isNotNull, reason: '$reason foreground');
  expect(background, isNotNull, reason: '$reason background');
  expect(
    _contrastRatio(foreground!, background!),
    greaterThanOrEqualTo(4.5),
    reason: reason,
  );
}

void main() {
  test('targeted mobile controls keep AA text contrast in every theme', () {
    final themeSource = File('lib/theme.dart').readAsStringSync();
    final chatSource = File('lib/screens/chat_screen.dart').readAsStringSync();
    final audioSource = File(
      'lib/services/audio_service.dart',
    ).readAsStringSync();
    expect(themeSource, contains('foregroundColor: onSecondary'));
    expect(themeSource, contains('disabledForegroundColor: palette.textMuted'));
    expect(themeSource, contains('actionTextColor: palette.accent'));
    expect(themeSource, contains('disabledActionTextColor: palette.textMuted'));
    expect(
      RegExp(
        r'onOpenSettings:\s*\(\)\s*=>\s*unawaited\(\s*'
        r'_audioService\.openMicrophoneSettings\(\)\s*\)\s*,',
      ).hasMatch(chatSource),
      isTrue,
    );
    expect(audioSource, contains('await openAppSettings();'));

    for (final palette in osiaPalettes) {
      for (final state in <String>['normal', 'pressed', 'focused']) {
        _expectTextContrast(
          palette.foregroundOn(palette.secondary),
          palette.secondary,
          '${palette.key}.elevated.$state',
        );
        _expectTextContrast(
          palette.accent,
          palette.surface,
          '${palette.key}.snackBarAction.$state',
        );
      }
      _expectTextContrast(
        palette.textMuted,
        palette.surfaceElevated,
        '${palette.key}.elevated.disabled',
      );
      _expectTextContrast(
        palette.textMuted,
        palette.surface,
        '${palette.key}.snackBarAction.disabled',
      );
      _expectTextContrast(
        palette.foregroundOn(palette.swatch),
        palette.swatch,
        '${palette.key}.themeSwatch.check',
      );
    }
  });

  testWidgets(
    'microphone denial popup renders, opens settings action and keeps host',
    (tester) async {
      var openSettingsCount = 0;
      const hostKey = Key('wor215-host');
      final palette = osiaPaletteViolet;
      final theme = ThemeData(
        useMaterial3: true,
        snackBarTheme: SnackBarThemeData(
          backgroundColor: palette.surface,
          actionTextColor: palette.accent,
          disabledActionTextColor: palette.textMuted,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: OsiaTheme(
            palette: osiaPaletteViolet,
            child: OsiaL10n(
              strings: osiaStringsEn,
              child: Scaffold(
                body: Builder(
                  builder: (context) => Center(
                    child: TextButton(
                      key: hostKey,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          buildMicrophonePermissionDeniedSnackBar(
                            strings: osiaStringsEn,
                            onOpenSettings: () => openSettingsCount += 1,
                          ),
                        );
                      },
                      child: const Text('Show permission popup'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(hostKey));
      await tester.pumpAndSettle();
      expect(find.text(osiaStringsEn.micPermissionDenied), findsOneWidget);
      expect(find.text(osiaStringsEn.openSettingsAction), findsOneWidget);

      await tester.tap(find.text(osiaStringsEn.openSettingsAction));
      await tester.pumpAndSettle();
      expect(openSettingsCount, 1);
      expect(find.byKey(hostKey), findsOneWidget);
    },
  );
}
