import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Class containing all the core design colors for Rakoon.
class AppColors {
  /// Dark elements and primary text color (#0F172A)
  static const Color ink = Color(0xFF0F172A);

  /// Background card and surface color (#FFFFFF)
  static const Color paper = Color(0xFFFFFFFF);

  /// Secondary background color (#F8FAFC)
  static const Color card = Color(0xFFF8FAFC);

  /// Primary accent / green color for primary action and best value badge (#059669)
  static const Color accent = Color(0xFF059669);

  /// Soft green background for badge/success status (#ECFDF5)
  static const Color accentSoft = Color(0xFFECFDF5);

  /// Border and divider color (#E2E8F0)
  static const Color line = Color(0xFFE2E8F0);

  /// Secondary text color (#64748B)
  static const Color muted = Color(0xFF64748B);

  /// Scaffold/screen background color (#EEF2F6)
  static const Color background = Color(0xFFEEF2F6);

  /// Primary error red color (#DC2626)
  static const Color error = Color(0xFFDC2626);

  /// Soft error red background color (#FEF2F2)
  static const Color errorSoft = Color(0xFFFEF2F2);

  /// Warning orange/amber color (#D97706)
  static const Color warning = Color(0xFFD97706);

  /// Soft warning orange/amber background color (#FFFBEB)
  static const Color warningSoft = Color(0xFFFFFBEB);

  /// Sky blue accent color for onboarding slide 2 (#0369A1)
  static const Color onboardingAccent1 = Color(0xFF0369A1);

  /// Purple accent color for onboarding slide 3 (#6B21A8)
  static const Color onboardingAccent2 = Color(0xFF6B21A8);
}

/// Constant spacing values aligned with premium card visuals and layouts.
class AppSpacing {
  static const double xs = 4.0;
  static const double s = 8.0;
  static const double m = 12.0;
  static const double l = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
}

/// Constant corner radius values matching visual references.
class AppRadius {
  static const double s = 4.0;
  static const double m = 8.0;
  
  /// Equivalent to rounded-xl (12.0)
  static const double l = 12.0;
  
  /// Equivalent to rounded-2xl (16.0)
  static const double xl = 16.0;
  
  /// Large corner radius for fully rounded/capsule buttons/badges (999.0)
  static const double full = 999.0;
}

/// Premium typography styles using the Inter font.
class AppTextStyles {
  /// Header style used for main screens (e.g. "Rakoon", 26pt, bold)
  static TextStyle get titleLarge => GoogleFonts.inter(
        fontSize: 26.0,
        fontWeight: FontWeight.bold,
        color: AppColors.ink,
        letterSpacing: -0.5,
      );

  /// Title style for result header (19pt, bold)
  static TextStyle get titleMedium => GoogleFonts.inter(
        fontSize: 19.0,
        fontWeight: FontWeight.bold,
        color: AppColors.ink,
      );

  /// Sub-headers (15pt, semibold)
  static TextStyle get titleSmall => GoogleFonts.inter(
        fontSize: 15.0,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      );

  /// Standard card action titles (14pt, semibold)
  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 14.0,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      );

  /// Body content text (13pt, medium/regular)
  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 13.0,
        fontWeight: FontWeight.normal,
        color: AppColors.ink,
      );

  /// Small description and muted text (11pt/12pt)
  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 11.0,
        fontWeight: FontWeight.normal,
        color: AppColors.muted,
      );

  /// Text style specifically for badges and small labels
  static TextStyle get labelSmall => GoogleFonts.inter(
        fontSize: 11.0,
        fontWeight: FontWeight.w600,
        color: AppColors.accent,
      );
}

/// Core theme configurations for the Rakoon application.
class AppTheme {
  static ThemeData get light {
    final baseTheme = ThemeData.light(useMaterial3: true);
    return baseTheme.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        primary: AppColors.accent,
        surface: AppColors.paper,
        error: AppColors.error,
        errorContainer: AppColors.errorSoft,
        onPrimary: AppColors.paper,
        onSurface: AppColors.ink,
        brightness: Brightness.light,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1.0,
        space: 1.0,
      ),
      textTheme: GoogleFonts.interTextTheme(baseTheme.textTheme).apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18.0,
          fontWeight: FontWeight.bold,
          color: AppColors.ink,
        ),
      ),
    );
  }
}
