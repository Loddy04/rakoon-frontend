import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Class containing all core design tokens for colors defined in DESIGN.md (Shupatto style).
class AppColors {
  /// Graphite (#2D2D2D) - Primary text, hairline borders, structural lines
  static const Color graphite = Color(0xFF2D2D2D);

  /// Ink (#000000) - Strongest text and most emphatic borders
  static const Color ink = Color(0xFF000000);

  /// Paper (#FFFFFF) - Page canvas, card surfaces, nav background
  static const Color paper = Color(0xFFFFFFFF);

  /// Fog (#878887) - Muted helper text, secondary borders, dimmed metadata
  static const Color fog = Color(0xFF878887);

  /// Periwinkle (#7380A5 / #738AE5) - Sole chromatic accent for badges, active states, pressure points
  static const Color periwinkle = Color(0xFF7380A5);

  // --- Aliases for Shupatto Design Token Parity & Legacy Compatibility ---

  static const Color inkBlack = graphite;
  static const Color pureBlack = ink;
  static const Color boneWhite = paper;
  static const Color background = paper;
  static const Color card = paper;
  static const Color line = graphite;
  static const Color muted = fog;
  static const Color accent = periwinkle;
  static const Color accentSoft = Color(0xFFF0F2F7);

  static const Color duskViolet = paper;
  static const Color hiVisYellow = graphite;
  static const Color butteryYellow = paper;
  static const Color lilacShadow = fog;
  static const Color bubblegumPink = paper;
  static const Color matchaCream = paper;
  static const Color magentaPunch = periwinkle;
  static const Color firecrackerRed = graphite;
  static const Color error = graphite;
  static const Color errorSoft = paper;
  static const Color warning = fog;
  static const Color warningSoft = paper;

  static const Color onboardingAccent1 = periwinkle;
  static const Color onboardingAccent2 = graphite;
}

/// Spacing scale and layout constants aligned with DESIGN.md (Shupatto style).
class AppSpacing {
  static const double s5 = 5.0;
  static const double s10 = 10.0;
  static const double s12 = 12.0;
  static const double s14 = 14.0;
  static const double s16 = 16.0;
  static const double s17 = 17.0;
  static const double s19 = 19.0;
  static const double s21 = 21.0;
  static const double s22 = 22.0;
  static const double s23 = 23.0;
  static const double s27 = 27.0;
  static const double s60 = 60.0;

  /// Layout tokens
  static const double sectionGap = 40.0;
  static const double cardPadding = 20.0;
  static const double elementGap = 16.0;

  /// Legacy spacing aliases
  static const double xs = 4.0;
  static const double s = 8.0;
  static const double m = 12.0;
  static const double l = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;

  static const double s20 = 20.0;
  static const double s40 = 40.0;
  static const double s80 = 60.0;
  static const double s160 = 120.0;
}

/// Corner radius tokens aligned with DESIGN.md Shupatto style (3px sharp architecture).
class AppRadius {
  /// Shupatto signature 3px radius across cards, buttons, badges
  static const double cards = 3.0;
  static const double buttons = 3.0;
  static const double tags = 3.0;
  static const double md = 3.0;
  static const double sm = 3.0;
  static const double full = 3.0;

  /// Legacy radius aliases
  static const double s = 3.0;
  static const double m = 3.0;
  static const double l = 3.0;
  static const double xl = 3.0;
}

/// Motion and duration tokens supporting responsive, snappy micro-interactions.
class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration bouncy = Duration(milliseconds: 600);
}

/// Animation curves supporting subtle bouncy micro-animations.
class AppCurves {
  static const Curve bouncy = Curves.easeOutBack;
  static const Curve elastic = Curves.elasticOut;
  static const Curve snappy = Curves.easeOutCubic;
  static const Curve standard = Curves.easeInOut;
}

/// Typography styles based on DESIGN.md Shupatto substitutes (Outfit / Jost).
class AppTextStyles {
  /// Editorial Large Heading (28px, Uppercase, wide tracking)
  static TextStyle get headingLg => GoogleFonts.outfit(
        fontSize: 28.0,
        height: 1.0,
        letterSpacing: 2.24,
        fontWeight: FontWeight.w700,
        color: AppColors.graphite,
      );

  /// Editorial Small Heading (21px, Uppercase, wide tracking)
  static TextStyle get headingSm => GoogleFonts.outfit(
        fontSize: 21.0,
        height: 1.22,
        letterSpacing: 2.52,
        fontWeight: FontWeight.w700,
        color: AppColors.graphite,
      );

  /// Subheading (18px, Uppercase, wide tracking)
  static TextStyle get subheading => GoogleFonts.outfit(
        fontSize: 18.0,
        height: 1.25,
        letterSpacing: 1.44,
        fontWeight: FontWeight.w600,
        color: AppColors.graphite,
      );

  /// Body text (16px, editorial tracking)
  static TextStyle get body => GoogleFonts.outfit(
        fontSize: 16.0,
        height: 1.29,
        letterSpacing: 1.28,
        fontWeight: FontWeight.w400,
        color: AppColors.graphite,
      );

  /// Caption / Micro Label (10px, Uppercase, tracking)
  static TextStyle get caption => GoogleFonts.outfit(
        fontSize: 10.0,
        height: 1.0,
        letterSpacing: 1.0,
        fontWeight: FontWeight.w600,
        color: AppColors.fog,
      );

  /// Monospaced / Badge Tag (11px, Uppercase, tracking)
  static TextStyle get monoTag => GoogleFonts.outfit(
        fontSize: 11.0,
        height: 1.0,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
        color: AppColors.graphite,
      );

  /// Button label / CTA text (14px, Uppercase, wide tracking)
  static TextStyle get buttonLabel => GoogleFonts.outfit(
        fontSize: 14.0,
        height: 1.0,
        letterSpacing: 1.5,
        fontWeight: FontWeight.w600,
        color: AppColors.graphite,
      );

  // --- Legacy Getters for Compatibility ---

  static TextStyle get display => headingLg;

  static TextStyle get titleLarge => GoogleFonts.outfit(
        fontSize: 22.0,
        fontWeight: FontWeight.w700,
        color: AppColors.graphite,
        letterSpacing: 1.2,
      );

  static TextStyle get titleMedium => GoogleFonts.outfit(
        fontSize: 18.0,
        fontWeight: FontWeight.w700,
        color: AppColors.graphite,
        letterSpacing: 1.0,
      );

  static TextStyle get titleSmall => GoogleFonts.outfit(
        fontSize: 15.0,
        fontWeight: FontWeight.w600,
        color: AppColors.graphite,
        letterSpacing: 0.8,
      );

  static TextStyle get bodyLarge => GoogleFonts.outfit(
        fontSize: 15.0,
        fontWeight: FontWeight.w600,
        color: AppColors.graphite,
        letterSpacing: 0.8,
      );

  static TextStyle get bodyMedium => GoogleFonts.outfit(
        fontSize: 13.0,
        fontWeight: FontWeight.w400,
        color: AppColors.graphite,
        letterSpacing: 0.5,
      );

  static TextStyle get bodySmall => GoogleFonts.outfit(
        fontSize: 12.0,
        fontWeight: FontWeight.w400,
        color: AppColors.fog,
        letterSpacing: 0.4,
      );

  static TextStyle get labelSmall => GoogleFonts.outfit(
        fontSize: 10.0,
        fontWeight: FontWeight.w600,
        color: AppColors.periwinkle,
        letterSpacing: 1.0,
      );
}

/// Core theme configurations for the Rakoon application adopting Shupatto style.
class AppTheme {
  static ThemeData get light {
    final baseTheme = ThemeData.light(useMaterial3: true);
    return baseTheme.copyWith(
      scaffoldBackgroundColor: AppColors.paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.graphite,
        primary: AppColors.graphite,
        secondary: AppColors.periwinkle,
        surface: AppColors.paper,
        error: AppColors.graphite,
        onPrimary: AppColors.paper,
        onSecondary: AppColors.paper,
        onSurface: AppColors.graphite,
        brightness: Brightness.light,
      ),
      cardTheme: CardThemeData(
        color: AppColors.paper,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.cards),
          side: const BorderSide(color: AppColors.graphite, width: 1.0),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.paper,
          foregroundColor: AppColors.graphite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.cardPadding,
            vertical: AppSpacing.s14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.buttons),
            side: const BorderSide(color: AppColors.graphite, width: 1.0),
          ),
          textStyle: AppTextStyles.buttonLabel,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.graphite,
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: AppColors.graphite, width: 1.0),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.cardPadding,
            vertical: AppSpacing.s14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.buttons),
          ),
          textStyle: AppTextStyles.buttonLabel,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.paper,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.cardPadding,
          vertical: AppSpacing.s14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.cards),
          borderSide: const BorderSide(color: AppColors.graphite, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.cards),
          borderSide: const BorderSide(color: AppColors.graphite, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.cards),
          borderSide: const BorderSide(color: AppColors.periwinkle, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.graphite,
        thickness: 1.0,
        space: 1.0,
      ),
      textTheme: GoogleFonts.outfitTextTheme(baseTheme.textTheme)
          .copyWith(
            headlineLarge: GoogleFonts.outfit(
              textStyle: baseTheme.textTheme.headlineLarge,
              fontWeight: FontWeight.w700,
            ),
            headlineMedium: GoogleFonts.outfit(
              textStyle: baseTheme.textTheme.headlineMedium,
              fontWeight: FontWeight.w700,
            ),
            headlineSmall: GoogleFonts.outfit(
              textStyle: baseTheme.textTheme.headlineSmall,
              fontWeight: FontWeight.w600,
            ),
            titleLarge: GoogleFonts.outfit(
              textStyle: baseTheme.textTheme.titleLarge,
              fontWeight: FontWeight.w700,
            ),
            titleMedium: GoogleFonts.outfit(
              textStyle: baseTheme.textTheme.titleMedium,
              fontWeight: FontWeight.w600,
            ),
            titleSmall: GoogleFonts.outfit(
              textStyle: baseTheme.textTheme.titleSmall,
              fontWeight: FontWeight.w600,
            ),
          )
          .apply(
            bodyColor: AppColors.graphite,
            displayColor: AppColors.graphite,
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.graphite,
        elevation: 0,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18.0,
          fontWeight: FontWeight.w700,
          color: AppColors.graphite,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
