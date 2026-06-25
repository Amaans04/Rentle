import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rentle/core/constants/colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final poppins = GoogleFonts.poppinsTextTheme();
    final inter = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: RentleColors.warmSand,
      primaryColor: RentleColors.trustBlue,
      colorScheme: ColorScheme.fromSeed(
        seedColor: RentleColors.trustBlue,
        primary: RentleColors.trustBlue,
        secondary: RentleColors.coral,
        surface: RentleColors.white,
      ),
      textTheme: TextTheme(
        displayLarge: poppins.displayLarge?.copyWith(
          color: RentleColors.charcoal,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: poppins.displayMedium?.copyWith(
          color: RentleColors.charcoal,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: poppins.displaySmall?.copyWith(
          color: RentleColors.charcoal,
          fontWeight: FontWeight.w600,
        ),
        headlineLarge: poppins.headlineLarge?.copyWith(
          color: RentleColors.charcoal,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: poppins.headlineMedium?.copyWith(
          color: RentleColors.charcoal,
          fontWeight: FontWeight.bold,
        ),
        headlineSmall: poppins.headlineSmall?.copyWith(
          color: RentleColors.charcoal,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: poppins.titleLarge?.copyWith(
          color: RentleColors.charcoal,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: poppins.titleMedium?.copyWith(
          color: RentleColors.charcoal,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: inter.bodyLarge?.copyWith(color: RentleColors.charcoal),
        bodyMedium: inter.bodyMedium?.copyWith(color: RentleColors.charcoal),
        bodySmall: inter.bodySmall?.copyWith(color: RentleColors.charcoal),
        labelLarge: inter.labelLarge?.copyWith(
          color: RentleColors.charcoal,
          fontWeight: FontWeight.w500,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: RentleColors.trustBlue,
        foregroundColor: RentleColors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: RentleColors.white,
        ),
        iconTheme: const IconThemeData(color: RentleColors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: RentleColors.coral,
          foregroundColor: RentleColors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: RentleColors.trustBlue,
          side: const BorderSide(color: RentleColors.trustBlue),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: RentleColors.skyBlue.withValues(alpha: 0.25),
        labelStyle: GoogleFonts.inter(color: RentleColors.charcoal),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: RentleColors.trustBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        color: RentleColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: RentleColors.skyBlue, width: 1.2),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: RentleColors.white,
        selectedItemColor: RentleColors.trustBlue,
        unselectedItemColor: RentleColors.charcoal.withValues(alpha: 0.4),
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 12),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: RentleColors.charcoal,
        contentTextStyle: GoogleFonts.inter(color: RentleColors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: RentleColors.charcoal.withValues(alpha: 0.1),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: RentleColors.coral,
        foregroundColor: RentleColors.white,
      ),
    );
  }
}
