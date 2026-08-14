import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/cupertino.dart';

class AppColors {
  // Primary
  static const teal = Color(0xFF00D4AA);
  static const tealDim = Color(0xFF00A886);
  static const tealGlow = Color(0x2900D4AA);
  static const tealSubtle = Color(0x1400D4AA);

  // Accent
  static const blue = Color(0xFF0099FF);
  static const yellow = Color(0xFFFFC845);
  static const red = Color(0xFFFF5566);
  static const redSubtle = Color(0x1FFF5566);
  static const greenSubtle = Color(0x1400D4AA);

  // Dark surfaces
  static const bg = Color(0xFF0C0F13);
  static const bgDeep = Color(0xFF080B0F);
  static const surface = Color(0xFF131820);
  static const surface2 = Color(0xFF1A2130);
  static const surface3 = Color(0xFF202838);

  // Light surfaces
  static const bgLight = Color(0xFFF5F7FA);
  static const bgLightDeep = Color(0xFFEBEEF3);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surface2Light = Color(0xFFF0F3F7);
  static const surface3Light = Color(0xFFE5E9F0);

  // Text dark
  static const textDark = Color(0xFFF0F4F8);
  static const textDimDark = Color(0xFF8A9BB0);
  static const textMutedDark = Color(0xFF4A5568);

  // Text light
  static const textLight = Color(0xFF111827);
  static const textDimLight = Color(0xFF4B5563);
  static const textMutedLight = Color(0xFF9CA3AF);

  // Borders dark
  static const borderDark = Color(0x12FFFFFF);
  static const borderTealDark = Color(0x3F00D4AA);

  // Borders light
  static const borderLight = Color(0x1A000000);
  static const borderTealLight = Color(0x4D00A886);

  // Gradient
  static const gradientTealBlue = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [teal, blue],
  );

  static const gradientTealBlueSubtle = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x1F00D4AA), Color(0x0F0099FF)],
  );
}

class AppTheme {
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.teal,
        secondary: AppColors.blue,
        surface: AppColors.surface,
        error: AppColors.red,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: AppColors.textDark,
        onError: Colors.white,
      ),
      textTheme: _buildTextTheme(isDark: true),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textDimDark),
        titleTextStyle: TextStyle(
          color: AppColors.textDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFamily: 'Outfit',
          letterSpacing: -0.5,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.teal,
        unselectedItemColor: AppColors.textMutedDark,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderDark, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderDark,
        thickness: 1,
        space: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.black;
          return AppColors.textMutedDark;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.teal;
          return AppColors.surface2;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.transparent;
          return AppColors.borderDark;
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderTealDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderTealDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
        ),
        hintStyle: const TextStyle(
          color: AppColors.textMutedDark,
          fontStyle: FontStyle.italic,
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bgLight,
      colorScheme: const ColorScheme.light(
        primary: AppColors.tealDim,
        secondary: AppColors.blue,
        surface: AppColors.surfaceLight,
        error: AppColors.red,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textLight,
        onError: Colors.white,
      ),
      textTheme: _buildTextTheme(isDark: false),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textDimLight),
        titleTextStyle: TextStyle(
          color: AppColors.textLight,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFamily: 'Outfit',
          letterSpacing: -0.5,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedItemColor: AppColors.tealDim,
        unselectedItemColor: AppColors.textMutedLight,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
        space: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return AppColors.textMutedLight;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.tealDim;
          return AppColors.surface2Light;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.transparent;
          return AppColors.borderLight;
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface2Light,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderTealLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderTealLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.tealDim, width: 1.5),
        ),
        hintStyle: const TextStyle(
          color: AppColors.textMutedLight,
          fontStyle: FontStyle.italic,
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _buildTextTheme({required bool isDark}) {
    final baseColor = isDark ? AppColors.textDark : AppColors.textLight;
    final dimColor = isDark ? AppColors.textDimDark : AppColors.textDimLight;

    return TextTheme(
      // Display — Outfit ExtraBold
      displayLarge: TextStyle(
        fontFamily: 'Outfit', fontSize: 57, fontWeight: FontWeight.w800,
        color: baseColor, letterSpacing: -2,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Outfit', fontSize: 45, fontWeight: FontWeight.w800,
        color: baseColor, letterSpacing: -1.5,
      ),
      displaySmall: TextStyle(
        fontFamily: 'Outfit', fontSize: 36, fontWeight: FontWeight.w800,
        color: baseColor, letterSpacing: -1,
      ),
      // Headline — Outfit Bold
      headlineLarge: TextStyle(
        fontFamily: 'Outfit', fontSize: 32, fontWeight: FontWeight.w700,
        color: baseColor, letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Outfit', fontSize: 28, fontWeight: FontWeight.w700,
        color: baseColor, letterSpacing: -0.5,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.w700,
        color: baseColor, letterSpacing: -0.5,
      ),
      // Title — Outfit SemiBold
      titleLarge: TextStyle(
        fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.w600,
        color: baseColor, letterSpacing: -0.3,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w600,
        color: baseColor, letterSpacing: -0.2,
      ),
      titleSmall: TextStyle(
        fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      // Body — DM Sans
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 16, fontWeight: FontWeight.w400, color: baseColor,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 14, fontWeight: FontWeight.w400, color: baseColor,
      ),
      bodySmall: GoogleFonts.dmSans(
        fontSize: 12, fontWeight: FontWeight.w400, color: dimColor,
      ),
      // Label
      labelLarge: GoogleFonts.dmSans(
        fontSize: 14, fontWeight: FontWeight.w500, color: baseColor,
      ),
      labelMedium: GoogleFonts.dmSans(
        fontSize: 12, fontWeight: FontWeight.w500, color: dimColor,
      ),
      labelSmall: GoogleFonts.dmSans(
        fontSize: 10, fontWeight: FontWeight.w500, color: dimColor,
        letterSpacing: 1.5,
      ),
    );
  }
}
