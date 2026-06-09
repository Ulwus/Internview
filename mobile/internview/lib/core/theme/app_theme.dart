import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData buildInternviewTheme() {
  final textTheme = GoogleFonts.spaceGroteskTextTheme();

  return ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF000000), // Black as primary for borders
      secondary: Color(0xFF00E5FF), // Cyan
      tertiary: Color(0xFFFFD600), // Yellow
      surface: Color(0xFFFAFAFA),
      error: Color(0xFFFF5252), // Pink/Red
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: Colors.black,
    ),
    scaffoldBackgroundColor: const Color(0xFFFAFAFA),
    textTheme: textTheme.copyWith(
      displayLarge: textTheme.displayLarge?.copyWith(fontWeight: FontWeight.w900, color: Colors.black),
      displayMedium: textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800, color: Colors.black),
      titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black),
      bodyLarge: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: Colors.black),
      bodyMedium: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500, color: Colors.black),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.black,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: Colors.black, size: 28),
      titleTextStyle: TextStyle(
        fontFamily: 'Space Grotesk',
        fontSize: 24,
        fontWeight: FontWeight.w900,
        color: Colors.black,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.black, width: 3),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.black, width: 3),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.black, width: 3),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFFFFD600), // Yellow
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Space Grotesk'),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.black54,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Space Grotesk'),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Space Grotesk'),
    ),
  );
}
