import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/theme.dart';
import 'package:osia_mobile/widgets/glass_input_bar.dart';

void main() {
  testWidgets(
    'multi-file composer is accessible, removable, and preserves draft',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = TextEditingController(text: 'public draft');
      addTearDown(controller.dispose);
      var removed = -1;
      var cleared = 0;
      var attached = 0;

      await tester.pumpWidget(
        _host(
          GlassInputBar(
            textController: controller,
            isRecording: false,
            hasText: true,
            onSend: () {},
            onMicTap: () {},
            onAttach: () => attached++,
            modelLabel: 'Test model',
            onModelTap: () {},
            pendingAttachments: const [
              ComposerAttachment(displayName: 'public-one.txt', byteSize: 3),
              ComposerAttachment(displayName: 'public-two.txt', byteSize: 2048),
              ComposerAttachment(
                displayName: 'public-three.bin',
                byteSize: 1024 * 1024,
              ),
            ],
            onRemoveAttachment: (index) => removed = index,
            onClearAttachments: () => cleared++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('3/10'), findsOneWidget);
      expect(find.text('public-one.txt'), findsOneWidget);
      expect(find.text('public-two.txt'), findsOneWidget);
      expect(find.text('public-three.bin'), findsOneWidget);
      expect(
        _semanticsLabelStartsWith('3 selected attachments'),
        findsOneWidget,
      );
      expect(_semanticsLabel('Remove public-two.txt'), findsOneWidget);

      await tester.tap(_semanticsLabel('Remove public-two.txt'));
      expect(removed, 1);
      expect(controller.text, 'public draft');
      await tester.tap(find.text('Clear'));
      expect(cleared, 1);
      expect(controller.text, 'public draft');

      await tester.tap(find.byIcon(Icons.add_rounded));
      expect(attached, 1);
    },
  );

  testWidgets(
    'active upload locks duplicate actions and exposes cancel progress',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = TextEditingController(text: 'public draft');
      addTearDown(controller.dispose);
      var attached = 0;
      var canceled = 0;
      var removed = 0;
      var cleared = 0;

      await tester.pumpWidget(
        _host(
          GlassInputBar(
            textController: controller,
            enabled: true,
            isRecording: false,
            hasText: true,
            onSend: () {},
            onMicTap: () {},
            onAttach: () => attached++,
            modelLabel: 'Test model',
            onModelTap: () {},
            pendingAttachments: const [
              ComposerAttachment(
                displayName: 'public-upload.bin',
                byteSize: 1024 * 1024,
              ),
            ],
            onRemoveAttachment: (_) => removed++,
            onClearAttachments: () => cleared++,
            attachmentStatus: 'Uploading…',
            attachmentProgress: 0.5,
            attachmentBusy: true,
            onCancelAttachment: () => canceled++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Uploading…'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Clear'), findsNothing);
      expect(_semanticsLabel('Remove public-upload.bin'), findsNothing);
      await tester.tap(find.text('Cancel'));
      expect(canceled, 1);
      await tester.tap(find.byIcon(Icons.add_rounded));
      expect(attached, 0);
      expect(removed, 0);
      expect(cleared, 0);
      expect(controller.text, 'public draft');
    },
  );

  testWidgets('initial hashing exposes cancel before files are prepared', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = TextEditingController(text: 'public draft');
    addTearDown(controller.dispose);
    var canceled = 0;

    await tester.pumpWidget(
      _host(
        GlassInputBar(
          textController: controller,
          enabled: true,
          isRecording: false,
          hasText: true,
          onSend: () {},
          onMicTap: () {},
          onAttach: () {},
          modelLabel: 'Test model',
          onModelTap: () {},
          attachmentStatus: 'Hashing files…',
          attachmentProgress: 0.25,
          attachmentBusy: true,
          onCancelAttachment: () => canceled++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hashing files…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    expect(canceled, 1);
    expect(controller.text, 'public draft');
  });
}

Finder _semanticsLabel(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == label,
);

Finder _semanticsLabelStartsWith(String prefix) => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics && (widget.properties.label ?? '').startsWith(prefix),
);

Widget _host(Widget child) => OsiaTheme(
  palette: osiaPaletteViolet,
  child: OsiaL10n(
    strings: osiaStringsForCode('en'),
    child: MaterialApp(
      home: Scaffold(body: Align(child: child)),
    ),
  ),
);
