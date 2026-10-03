import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── OSIA Palettes ─────────────────────────────────────────────────────────

/// A complete color palette for one OSIA theme variant. The PC theme catalog
/// supplies the bundled choices and the active one is held by
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
  final Color success;
  final Color warning;
  final Color info;
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
    required this.success,
    required this.warning,
    required this.info,
    required this.isDark,
    required this.swatch,
  });

  /// Pick the existing palette text token with the strongest contrast on
  /// [fill]. This keeps button/icon foregrounds semantic across every theme.
  Color foregroundOn(Color fill) {
    final candidates = <Color>[textPrimary, background, surface];
    return candidates.reduce(
      (best, candidate) =>
          _contrastRatio(candidate, fill) > _contrastRatio(best, fill)
          ? candidate
          : best,
    );
  }
}

double _contrastRatio(Color foreground, Color background) {
  final lighter = foreground.computeLuminance() > background.computeLuminance()
      ? foreground.computeLuminance()
      : background.computeLuminance();
  final darker = foreground.computeLuminance() > background.computeLuminance()
      ? background.computeLuminance()
      : foreground.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}

const OsiaPalette osiaPalette = OsiaPalette(
  key: 'osia',
  label: 'OSIA',
  background: Color(0xFF0D0B12),
  accent: Color(0xFFC4B5F5),
  secondary: Color(0xFF8C6EDC),
  surface: Color(0xFF0F0D16),
  surfaceElevated: Color(0xFF13111A),
  border: Color(0xFF2A2438),
  textPrimary: Color(0xFFE8E6F0),
  textMuted: Color(0xFF9D9AAD),
  userBubble: Color(0xFF2A2440),
  assistantBubble: Color(0xFF0F0D16),
  thinking: Color(0xFFC4B5F5),
  error: Color(0xFFE0A3A3),
  success: Color(0xFF6FCF97),
  warning: Color(0xFFE0A23C),
  info: Color(0xFF38BDF8),
  isDark: true,
  swatch: Color(0xFFC4B5F5),
);

const OsiaPalette osiaPaletteAzure = OsiaPalette(
  key: 'azure',
  label: 'Azure',
  background: Color(0xFF09111A),
  accent: Color(0xFF8AC7FF),
  secondary: Color(0xFF378FE5),
  surface: Color(0xFF0E1A26),
  surfaceElevated: Color(0xFF132536),
  border: Color(0xFF294057),
  textPrimary: Color(0xFFF1F7FF),
  textMuted: Color(0xFF8DA0B3),
  userBubble: Color(0xFF183B59),
  assistantBubble: Color(0xFF0E1A26),
  thinking: Color(0xFF8AC7FF),
  error: Color(0xFFE0A3A3),
  success: Color(0xFF6FCF97),
  warning: Color(0xFFE0A23C),
  info: Color(0xFF38BDF8),
  isDark: true,
  swatch: Color(0xFF8AC7FF),
);

const OsiaPalette osiaPaletteEmerald = OsiaPalette(
  key: 'emerald',
  label: 'Emerald',
  background: Color(0xFF08130F),
  accent: Color(0xFF8EE6BD),
  secondary: Color(0xFF2CA875),
  surface: Color(0xFF0D1D17),
  surfaceElevated: Color(0xFF132A21),
  border: Color(0xFF27483A),
  textPrimary: Color(0xFFEFFCF6),
  textMuted: Color(0xFF88A598),
  userBubble: Color(0xFF174331),
  assistantBubble: Color(0xFF0D1D17),
  thinking: Color(0xFF8EE6BD),
  error: Color(0xFFE0A3A3),
  success: Color(0xFF6FCF97),
  warning: Color(0xFFE0A23C),
  info: Color(0xFF38BDF8),
  isDark: true,
  swatch: Color(0xFF8EE6BD),
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
  thinking: Color(0xFFF5B5C4),
  error: Color(0xFFE0A3A3),
  success: Color(0xFF6FCF97),
  warning: Color(0xFFE0A23C),
  info: Color(0xFF38BDF8),
  isDark: true,
  swatch: Color(0xFFF5B5C4),
);

const OsiaPalette osiaPaletteAmber = OsiaPalette(
  key: 'amber',
  label: 'Amber',
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
  thinking: Color(0xFFE6C97A),
  error: Color(0xFFE0A3A3),
  success: Color(0xFF6FCF97),
  warning: Color(0xFFE6C97A),
  info: Color(0xFF38BDF8),
  isDark: true,
  swatch: Color(0xFFE6C97A),
);

const OsiaPalette osiaPaletteNeutral = OsiaPalette(
  key: 'neutral',
  label: 'Neutral',
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
  thinking: Color(0xFFEDEDED),
  error: Color(0xFFE0A3A3),
  success: Color(0xFF6FCF97),
  warning: Color(0xFFE0A23C),
  info: Color(0xFF38BDF8),
  isDark: true,
  swatch: Color(0xFFEDEDED),
);

// Legacy identifiers remain aliases to the canonical PC palette set.
const OsiaPalette osiaPaletteViolet = osiaPalette;
const OsiaPalette osiaPaletteNoir = osiaPaletteNeutral;
const OsiaPalette osiaPaletteBlanc = osiaPaletteAzure;
const OsiaPalette osiaPaletteDore = osiaPaletteAmber;
const OsiaPalette osiaPaletteRed = osiaPaletteEmerald;
const OsiaPalette osiaPaletteGreen = osiaPaletteEmerald;

const List<OsiaPalette> osiaPalettes = <OsiaPalette>[
  osiaPalette,
  osiaPaletteAzure,
  osiaPaletteEmerald,
  osiaPaletteRose,
  osiaPaletteAmber,
  osiaPaletteNeutral,
];

/// Resolve a palette by its [OsiaPalette.key]. Falls back to OSIA for
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
  final onSecondary = palette.foregroundOn(palette.secondary);

  return ThemeData(
    useMaterial3: true,
    brightness: palette.isDark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: palette.background,
    colorScheme: ColorScheme(
      brightness: palette.isDark ? Brightness.dark : Brightness.light,
      primary: palette.accent,
      onPrimary: palette.isDark ? palette.background : Colors.white,
      secondary: palette.secondary,
      onSecondary: onSecondary,
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
        foregroundColor: onSecondary,
        disabledBackgroundColor: palette.surfaceElevated,
        disabledForegroundColor: palette.textMuted,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: palette.accent,
        disabledForegroundColor: palette.textMuted,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: palette.accent,
        disabledForegroundColor: palette.textMuted,
      ),
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
      actionTextColor: palette.accent,
      disabledActionTextColor: palette.textMuted,
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
