import 'package:flutter/material.dart';

class AppTheme {
  static const Color ink = Color(0xFF0B0F10);
  static const Color muted = Color(0xFF9EA3A5);
  static const Color paper = Color(0xFFF5EFE6);
  static const Color paperSoft = Color(0xFFEFE7DB);
  static const Color accent = Color(0xFFFF6B3D);
  static const Color accentDark = Color(0xFFB3421F);
  static const Color bg = Color(0xFF0F1A1C);
  static const Color bgAccent = Color(0xFF142526);
  static const Color line = Color(0x33F5EFE6);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'DM Sans', 
      
      colorScheme: const ColorScheme.dark(
        primary: accent,
        onPrimary: ink,
        secondary: accentDark,
        surface: bgAccent,
        onSurface: paper,
        background: bg,
        onBackground: paper,
        error: Color(0xFFEB4D2C),
      ),
      
      scaffoldBackgroundColor: bg, 
      
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: paper),
        bodyLarge: TextStyle(color: paper),
        titleMedium: TextStyle(color: paper, fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(color: paper, fontWeight: FontWeight.bold),
      ),

      // cardTheme parametresi hata verdiği için kaldırıldı. 
      // Kart stilleri manuel olarak verilecek.

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paper,
        floatingLabelBehavior: FloatingLabelBehavior.never, // Labels won't float up
        labelStyle: const TextStyle(color: Color(0xFF5A6164), fontSize: 14), 
        hintStyle: const TextStyle(color: Color(0xFF9EA3A5)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x1F0B0F10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: ink,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(color: paper, fontSize: 24, fontWeight: FontWeight.bold),
        iconTheme: IconThemeData(color: paper),
      ),

      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: bgAccent, 
        indicatorColor: Color(0x33FF6B3D),
        selectedIconTheme: IconThemeData(color: accent),
        unselectedIconTheme: IconThemeData(color: Color(0xFF9EA3A5)),
        labelType: NavigationRailLabelType.all,
        selectedLabelTextStyle: TextStyle(color: accent, fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelTextStyle: TextStyle(color: Color(0xFF9EA3A5), fontSize: 12),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bgAccent,
        indicatorColor: const Color(0x33FF6B3D),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 12);
          }
          return const TextStyle(color: Color(0xFF9EA3A5), fontSize: 12);
        }),
      ),
    );
  }
}