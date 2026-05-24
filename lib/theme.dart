import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── OSIA Design Tokens ────────────────────────────────────────────────────

/// Deep black background.
const Color osiaBackground = Color(0xFF0D0B12);

/// Light violet accent (primary).
const Color osiaAccent = Color(0xFFC4B5F5);

/// Strong violet (secondary / thinking indicator).
const Color osiaViolet = Color(0xFF7C3AED);

/// Softer violet for glassmorphism surfaces.
const Color osiaSurface = Color(0xFF1A1625);

/// Subtle border / divider.
const Color osiaBorder = Color(0xFF2A2438);

/// Muted text.
const Color osiaTextMuted = Color(0xFF8B8A90);

/// Bright text on dark backgrounds.
const Color osiaTextPrimary = Color(0xFFF5F3FF);

/// Thinking indicator — VIOLET (never orange).
const Color osiaThinking = Color(0xFF7C3AED);

/// Error red.
const Color osiaError = Color(0xFFEF4444);

/// User chat bubble background.
const Color osiaUserBubble = Color(0xFF2A2438);

/// OSIA (assistant) chat bubble background.
const Color osiaAssistantBubble = Color(0xFF1A1625);

// ── OSIA ThemeData ────────────────────────────────────────────────────────

/// Full dark ThemeData for the OSIA Mobile app.
ThemeData buildOsiaTheme() {
  final textTheme = GoogleFonts.interTextTheme(
    ThemeData.dark().textTheme,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: osiaBackground,

    // Color scheme
    colorScheme: const ColorScheme.dark(
      primary: osiaAccent,
      secondary: osiaViolet,
      surface: osiaSurface,
      error: osiaError,
      onPrimary: osiaBackground,
      onSecondary: Colors.white,
      onSurface: osiaTextPrimary,
      onError: Colors.white,
    ),

    // Text theme
    textTheme: textTheme.copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: osiaTextPrimary,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: osiaTextPrimary,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: osiaTextPrimary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: osiaTextPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: osiaTextPrimary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: osiaTextPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: osiaTextPrimary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: osiaTextMuted,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: osiaAccent,
      ),
    ),

    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: osiaBackground,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: osiaTextPrimary,
      ),
      iconTheme: const IconThemeData(color: osiaAccent),
    ),

    // Cards / surfaces
    cardTheme: CardThemeData(
      color: osiaSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: osiaBorder, width: 0.5),
      ),
    ),

    // Input fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: osiaSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: osiaBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: osiaBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: osiaAccent, width: 1.5),
      ),
      hintStyle: GoogleFonts.inter(
        color: osiaTextMuted,
        fontSize: 15,
      ),
      labelStyle: GoogleFonts.inter(
        color: osiaTextMuted,
        fontSize: 14,
      ),
    ),

    // Elevated buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: osiaViolet,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Icon buttons
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: osiaAccent,
      ),
    ),

    // Bottom sheet
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: osiaSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),

    // Snackbar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: osiaSurface,
      contentTextStyle: GoogleFonts.inter(
        color: osiaTextPrimary,
        fontSize: 14,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),

    // Dialog
    dialogTheme: DialogThemeData(
      backgroundColor: osiaSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: osiaTextPrimary,
      ),
    ),
  );
}
