import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/slash_commands.dart';
import 'package:osia_mobile/theme.dart';
import 'package:osia_mobile/widgets/glass_input_bar.dart';
import 'package:osia_mobile/widgets/slash_command_palette.dart';

void main() {
  testWidgets('tap selects one row without creating a send action', (
    tester,
  ) async {
    final controller = SlashCommandPaletteController();
    SlashPaletteSelection? selected;
    controller.show(const [
      SlashPaletteSelection(
        type: SlashPaletteSelectionType.command,
        id: 'web.current',
        alias: 'web',
        title: 'Current web',
      ),
    ], (value) => selected = value);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SlashCommandPalette(controller: controller, locale: 'en'),
        ),
      ),
    );
    await tester.tap(find.textContaining('/web'));
    expect(selected?.id, 'web.current');
  });

  testWidgets('disabled connector is visible but cannot be selected', (
    tester,
  ) async {
    final controller = SlashCommandPaletteController();
    var selected = false;
    controller.show(const [
      SlashPaletteSelection(
        type: SlashPaletteSelectionType.connector,
        id: 'connector.linear',
        alias: 'linear',
        title: 'Linear',
        enabled: false,
      ),
    ], (_) => selected = true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SlashCommandPalette(controller: controller, locale: 'en'),
        ),
      ),
    );
    expect(find.textContaining('/linear'), findsOneWidget);
    await tester.tap(find.textContaining('/linear'));
    expect(selected, isFalse);
  });

  testWidgets(
    'tap outside closes the palette and directive chips are removable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final paletteController = SlashCommandPaletteController();
      final textController = TextEditingController(text: '/web');
      final focusNode = FocusNode();
      addTearDown(textController.dispose);
      addTearDown(focusNode.dispose);
      var removed = '';
      paletteController.show(const [
        SlashPaletteSelection(
          type: SlashPaletteSelectionType.command,
          id: 'web.current',
          alias: 'web',
          title: 'Current web',
        ),
      ], (_) {});

      await tester.pumpWidget(
        _host(
          Stack(
            children: [
              const Center(
                child: TextButton(onPressed: null, child: Text('Outside')),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: TextFieldTapRegion(
                  child: SlashCommandPalette(
                    controller: paletteController,
                    locale: 'en',
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: GlassInputBar(
                  textController: textController,
                  focusNode: focusNode,
                  isRecording: false,
                  hasText: true,
                  onSend: () {},
                  onMicTap: () {},
                  onAttach: () {},
                  modelLabel: 'Test model',
                  onModelTap: () {},
                  onTapOutside: (_) => paletteController.close(),
                  directives: const [
                    ComposerDirective(id: 'web', label: '/web'),
                  ],
                  onRemoveDirective: (id) => removed = id,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.tap(find.text('Outside'));
      await tester.pump();
      expect(paletteController.isOpen, isFalse);
      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(removed, 'web');
    },
  );

  testWidgets('system back closes an open palette before navigation', (
    tester,
  ) async {
    final controller = SlashCommandPaletteController();
    controller.show(const [
      SlashPaletteSelection(
        type: SlashPaletteSelectionType.command,
        id: 'help.info',
        alias: 'help',
        title: 'Help',
      ),
    ], (_) {});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              PopScope<Object?>(
                canPop: !controller.isOpen,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop) controller.close();
                },
                child: const SizedBox.shrink(),
              ),
              SlashCommandPalette(controller: controller, locale: 'en'),
            ],
          ),
        ),
      ),
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(controller.isOpen, isFalse);
  });
}

Widget _host(Widget child) => OsiaTheme(
  palette: osiaPaletteViolet,
  child: OsiaL10n(
    strings: osiaStringsForCode('en'),
    child: MaterialApp(home: Scaffold(body: child)),
  ),
);
