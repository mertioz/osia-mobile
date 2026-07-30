import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── OSIA Palettes ─────────────────────────────────────────────────────────

/// A complete color palette for one OSIA theme variant. Several palettes
/// are bundled (violet/rose/noir/blanc/doré) and the active one is held by
/// [ThemeController] and exposed to widgets through [OsiaTheme.of].
class OsiaPalette {
  final String key;
  final String label;
  final Color background;
  final Color accent;
  final Color secondary;
  final Color surface;
  final Color surfaceElevated;
  final Color border;
  final Color textPrimary;
  final Color textMuted;
  final Color userBubble;
  final Color assistantBubble;
  final Color thinking;
  final Color error;
  final bool isDark;
  final Color swatch;

  const OsiaPalette({
    required this.key,
    required this.label,
    required this.background,
    required this.accent,
    required this.secondary,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.textPrimary,
    required this.textMuted,
    required this.userBubble,
    required this.assistantBubble,
    required this.thinking,
    required this.error,
    required this.isDark,
    required this.swatch,
  });
}

/// Indicator violet — must stay this exact value regardless of palette,
/// per the OSIA design spec.
const Color _kIndicatorViolet = Color(0xFFC4B5F5);

const OsiaPalette osiaPaletteViolet = OsiaPalette(
  key: 'violet',
  label: 'Violet',
  background: Color(0xFF0D0B12),
  accent: Color(0xFFC4B5F5),
  secondary: Color(0xFF7C3AED),
  surface: Color(0xFF1A1625),
  surfaceElevated: Color(0xFF221C30),
  border: Color(0xFF2A2438),
  textPrimary: Color(0xFFF5F3FF),
  textMuted: Color(0xFF8B8A90),
  userBubble: Color(0xFF2A2440),
  assistantBubble: Color(0xFF181426),
  thinking: _kIndicatorViolet,
  error: Color(0xFFEF4444),
  isDark: true,
  swatch: Color(0xFFC4B5F5),
);

const OsiaPalette osiaPaletteRose = OsiaPalette(
  key: 'rose',
  label: 'Rose',
  background: Color(0xFF120B0E),
  accent: Color(0xFFF5B5C4),
  secondary: Color(0xFFED4F87),
  surface: Color(0xFF22161B),
  surfaceElevated: Color(0xFF2E1B22),
  border: Color(0xFF3A2530),
  textPrimary: Color(0xFFFFF3F6),
  textMuted: Color(0xFF9C8B91),
  userBubble: Color(0xFF38222A),
  assistantBubble: Color(0xFF22161B),
  thinking: _kIndicatorViolet,
  error: Color(0xFFEF4444),
  isDark: true,
  swatch: Color(0xFFF5B5C4),
);

const OsiaPalette osiaPaletteNoir = OsiaPalette(
  key: 'noir',
  label: 'Noir',
  background: Color(0xFF000000),
  accent: Color(0xFFEDEDED),
  secondary: Color(0xFF6B6B6B),
  surface: Color(0xFF101010),
  surfaceElevated: Color(0xFF1A1A1A),
  border: Color(0xFF262626),
  textPrimary: Color(0xFFFFFFFF),
  textMuted: Color(0xFF8A8A8A),
  userBubble: Color(0xFF1F1F1F),
  assistantBubble: Color(0xFF101010),
  thinking: _kIndicatorViolet,
  error: Color(0xFFEF4444),
  isDark: true,
  swatch: Color(0xFF1A1A1A),
);

const OsiaPalette osiaPaletteBlanc = OsiaPalette(
  key: 'blanc',
  label: 'Blanc',
  background: Color(0xFFFAF8FF),
  accent: Color(0xFF7C3AED),
  secondary: Color(0xFF5B21B6),
  surface: Color(0xFFFFFFFF),
  surfaceElevated: Color(0xFFF3EFFB),
  border: Color(0xFFE5DEF6),
  textPrimary: Color(0xFF14101F),
  textMuted: Color(0xFF6E6B7A),
  userBubble: Color(0xFFEDE5FE),
  assistantBubble: Color(0xFFFFFFFF),
  thinking: _kIndicatorViolet,
  error: Color(0xFFD93030),
  isDark: false,
  swatch: Color(0xFFFFFFFF),
);

const OsiaPalette osiaPaletteDore = OsiaPalette(
  key: 'dore',
  label: 'Doré',
  background: Color(0xFF110E0A),
  accent: Color(0xFFE6C97A),
  secondary: Color(0xFFC79D3E),
  surface: Color(0xFF1F1A12),
  surfaceElevated: Color(0xFF2B2419),
  border: Color(0xFF3A301F),
  textPrimary: Color(0xFFFAF1DC),
  textMuted: Color(0xFF9C8C6E),
  userBubble: Color(0xFF2B2419),
  assistantBubble: Color(0xFF1F1A12),
  thinking: _kIndicatorViolet,
  error: Color(0xFFEF4444),
  isDark: true,
  swatch: Color(0xFFE6C97A),
);

const List<OsiaPalette> osiaPalettes = <OsiaPalette>[
  osiaPaletteViolet,
  osiaPaletteRose,
  osiaPaletteNoir,
  osiaPaletteBlanc,
  osiaPaletteDore,
];

/// Resolve a palette by its [OsiaPalette.key]. Falls back to violet for
/// any unknown or null key.
OsiaPalette paletteForKey(String? key) {
  for (final p in osiaPalettes) {
    if (p.key == key) return p;
  }
  return osiaPaletteViolet;
}

// ── Theme controller ──────────────────────────────────────────────────────

/// A [ChangeNotifier] that owns the currently active [OsiaPalette].
///
/// The app builds one of these at startup, restores the saved palette key,
/// and rebuilds the [MaterialApp] whenever the user picks a new theme from
/// the settings screen.
class ThemeController extends ChangeNotifier {
  OsiaPalette _palette;
  ThemeController({OsiaPalette initial = osiaPaletteViolet})
    : _palette = initial;

  OsiaPalette get palette => _palette;

  void setPaletteByKey(String key) {
    final next = paletteForKey(key);
    if (next.key == _palette.key) return;
    _palette = next;
    notifyListeners();
  }
}

// ── Inherited palette accessor ────────────────────────────────────────────

/// Provides the active [OsiaPalette] to widgets through `OsiaTheme.of(ctx)`.
class OsiaTheme extends InheritedWidget {
  final OsiaPalette palette;

  const OsiaTheme({super.key, required this.palette, required super.child});

  static OsiaPalette of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<OsiaTheme>();
    return widget?.palette ?? osiaPaletteViolet;
  }

  @override
  bool updateShouldNotify(OsiaTheme old) => old.palette != palette;
}

// ── ThemeData builder ─────────────────────────────────────────────────────

ThemeData buildOsiaTheme([OsiaPalette palette = osiaPaletteViolet]) {
  final base = palette.isDark ? ThemeData.dark() : ThemeData.light();
  final textTheme = GoogleFonts.interTextTheme(base.textTheme);

  return ThemeData(
    useMaterial3: true,
    brightness: palette.isDark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: palette.background,
    colorScheme: ColorScheme(
      brightness: palette.isDark ? Brightness.dark : Brightness.light,
      primary: palette.accent,
      onPrimary: palette.isDark ? palette.background : Colors.white,
      secondary: palette.secondary,
      onSecondary: Colors.white,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      error: palette.error,
      onError: Colors.white,
    ),
    textTheme: textTheme.copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: palette.textPrimary,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: palette.textPrimary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: palette.textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: palette.textPrimary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: palette.textMuted,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: palette.accent,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
      ),
      iconTheme: IconThemeData(color: palette.accent),
    ),
    cardTheme: CardThemeData(
      color: palette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.border, width: 0.5),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: palette.accent, width: 1.5),
      ),
      hintStyle: GoogleFonts.inter(color: palette.textMuted, fontSize: 15),
      labelStyle: GoogleFonts.inter(color: palette.textMuted, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: palette.secondary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: palette.accent),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.surface,
      contentTextStyle: GoogleFonts.inter(
        color: palette.textPrimary,
        fontSize: 14,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: palette.accent,
      textColor: palette.textPrimary,
    ),
    dividerTheme: DividerThemeData(
      color: palette.border,
      thickness: 0.5,
      space: 0,
    ),
  );
}
