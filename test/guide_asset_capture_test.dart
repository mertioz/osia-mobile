import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/theme.dart';

/// Deterministic, plugin-free capture harness for curated guide screenshots.
/// The scenes use Flutter-native OSIA colors, spacing, icons and control shapes
/// with synthetic content only. Run explicitly with:
///
///   flutter test --update-goldens test/guide_asset_capture_test.dart
Widget _app(Widget home) => OsiaTheme(
  palette: osiaPaletteViolet,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: osiaPaletteViolet.background,
      colorScheme: ColorScheme.dark(
        primary: osiaPaletteViolet.accent,
        surface: osiaPaletteViolet.surface,
      ),
      fontFamily: 'GuideRoboto',
      appBarTheme: AppBarTheme(
        backgroundColor: osiaPaletteViolet.background,
        foregroundColor: osiaPaletteViolet.textPrimary,
        elevation: 0,
      ),
    ),
    home: home,
  ),
);

class _DemoChat extends StatelessWidget {
  const _DemoChat();

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    return Scaffold(
      drawer: Drawer(
        backgroundColor: palette.background,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/osia_logo_mark.png',
                      width: 34,
                      height: 34,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Conversations',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New chat'),
                ),
                const SizedBox(height: 16),
                const _DemoConversation(
                  icon: Icons.calendar_today_rounded,
                  title: 'Tomorrow plan',
                  selected: true,
                ),
                const _DemoConversation(
                  icon: Icons.notes_rounded,
                  title: 'Project notes',
                ),
                const _DemoConversation(
                  icon: Icons.code_rounded,
                  title: 'Explain an error',
                ),
                const Spacer(),
                Text(
                  'Synthetic demo profile',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Conversations',
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu_rounded),
          ),
        ),
        title: const Text('Tomorrow plan'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF183121),
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Row(
                children: [
                  Icon(Icons.circle, color: Color(0xFF6FCF97), size: 8),
                  SizedBox(width: 5),
                  Text('Connected', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Conversations',
            onPressed: () {},
            icon: const Icon(Icons.chat_bubble_outline_rounded),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () {},
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 130),
              children: const [
                Align(
                  alignment: Alignment.centerRight,
                  child: _DemoBubble(
                    user: true,
                    text: 'Help me plan tomorrow from these demo appointments.',
                  ),
                ),
                SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _DemoBubble(
                    text:
                        'Here is a short plan:\n\n• Review priorities\n• Reserve a focus block\n• Leave time between appointments',
                  ),
                ),
              ],
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _DemoComposer(palette: palette),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoConversation extends StatelessWidget {
  const _DemoConversation({
    required this.icon,
    required this.title,
    this.selected = false,
  });

  final IconData icon;
  final String title;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
        color: selected
            ? palette.accent.withValues(alpha: 0.13)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: selected ? palette.accent : palette.textMuted,
          ),
          const SizedBox(width: 11),
          Expanded(child: Text(title)),
          Icon(Icons.more_horiz_rounded, size: 18, color: palette.textMuted),
        ],
      ),
    );
  }
}

class _DemoBubble extends StatelessWidget {
  const _DemoBubble({required this.text, this.user = false});

  final String text;
  final bool user;

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 310),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: user ? palette.accent.withValues(alpha: 0.16) : palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: user ? palette.accent.withValues(alpha: 0.35) : palette.border,
        ),
      ),
      child: Text(text, style: const TextStyle(fontSize: 15, height: 1.4)),
    );
  }
}

class _DemoComposer extends StatelessWidget {
  const _DemoComposer({required this.palette});

  final OsiaPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 7, 9, 9),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: palette.accent.withValues(alpha: 0.25)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 22,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 15, color: palette.accent),
              const SizedBox(width: 6),
              const Text('Demo model', style: TextStyle(fontSize: 12)),
              const Spacer(),
              Icon(Icons.keyboard_arrow_down_rounded, color: palette.textMuted),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.attach_file_rounded),
              ),
              Expanded(
                child: Text(
                  'Message OSIA…',
                  style: TextStyle(color: palette.textMuted, fontSize: 14),
                ),
              ),
              IconButton(onPressed: () {}, icon: const Icon(Icons.mic_rounded)),
              CircleAvatar(
                radius: 18,
                backgroundColor: palette.accent,
                child: Icon(
                  Icons.arrow_upward_rounded,
                  color: palette.background,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DemoSettings extends StatelessWidget {
  const _DemoSettings();

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const Icon(Icons.arrow_back_rounded),
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          children: [
            const _DemoSectionTitle(
              title: 'General',
              subtitle: 'Phone notifications, background and voice',
            ),
            Container(
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: palette.border),
              ),
              child: const Column(
                children: [
                  _DemoToggle(
                    icon: Icons.notifications_active_rounded,
                    title: 'OSIA notifications',
                    subtitle:
                        'Scheduled tasks and reminders received from the PC',
                  ),
                  Divider(height: 1, indent: 55),
                  _DemoToggle(
                    icon: Icons.sync_rounded,
                    title: 'Background connection',
                    subtitle:
                        'Android foreground service with a visible notification',
                  ),
                  Divider(height: 1, indent: 55),
                  _DemoToggle(
                    icon: Icons.volume_up_rounded,
                    title: 'Read responses aloud',
                    subtitle: 'Play response audio automatically',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _DemoSectionTitle(
              title: 'Help',
              subtitle: 'Learn at your own pace',
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.menu_book_rounded, color: palette.accent),
                  const SizedBox(width: 13),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Show OSIA Mobile guide'),
                        SizedBox(height: 3),
                        Text(
                          'Offline · progress preserved',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFA6A0B4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: palette.textMuted),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _DemoSectionTitle(
              title: 'Connection',
              subtitle: 'The demo contains no device or network data',
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoSectionTitle extends StatelessWidget {
  const _DemoSectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: palette.accent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(color: palette.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DemoToggle extends StatelessWidget {
  const _DemoToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Row(
        children: [
          Icon(icon, color: palette.accent, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(color: palette.textMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          Switch(value: false, onChanged: (_) {}),
        ],
      ),
    );
  }
}

// These canonical documentation captures remain in normal local test runs.
// The internal TestFlight workflow excludes only this tag because exact pixel
// rasterization differs between host platforms.
const _guideGoldenTag = 'guide-golden';

void main() {
  setUpAll(() async {
    final separator = Platform.pathSeparator;
    var flutterCache = File(Platform.resolvedExecutable).parent;
    while (flutterCache.path.split(separator).last.toLowerCase() != 'cache' &&
        flutterCache.parent.path != flutterCache.path) {
      flutterCache = flutterCache.parent;
    }
    final font = File(
      '${flutterCache.path}${separator}artifacts${separator}material_fonts'
      '${separator}roboto-regular.ttf',
    );
    final icons = File(
      '${flutterCache.path}${separator}artifacts${separator}material_fonts'
      '${separator}MaterialIcons-Regular.otf',
    );
    final bytes = await font.readAsBytes();
    final iconBytes = await icons.readAsBytes();
    await (FontLoader(
      'GuideRoboto',
    )..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future<ByteData>.value(ByteData.sublistView(iconBytes)))).load();
  });

  testWidgets('capture sanitized mobile Chat', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(const _DemoChat()));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('../assets/guide/mobile-chat.png'),
    );
  }, tags: _guideGoldenTag);

  testWidgets('capture sanitized mobile navigation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(const _DemoChat()));
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('../assets/guide/mobile-navigation.png'),
    );
  }, tags: _guideGoldenTag);

  testWidgets('capture sanitized Android Settings', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(const _DemoSettings()));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('../assets/guide/mobile-settings.png'),
    );
  }, tags: _guideGoldenTag);
}
