import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Light Theme Colors ──────────────────────────────────────────────────
  static const Color bgColor       = Color(0xFFF0F4F8); // Soft off-white
  static const Color cardColor     = Colors.white;
  static const Color accentCyan    = Color(0xFF0284C7); // Vivid Sky Blue
  static const Color accentEmerald = Color(0xFF059669); // Vivid Emerald
  static const Color accentPurple  = Color(0xFF7C3AED); // Vivid Purple
  static const Color accentOrange  = Color(0xFFEA580C); // Vivid Orange
  static const Color accentRed     = Color(0xFFDC2626); // Vivid Red
  static const Color textPrimary   = Color(0xFF0F172A); // Near-black
  static const Color textSecondary = Color(0xFF64748B); // Slate gray

  // Card gradient colors for dashboard cards
  static const List<List<Color>> cardGradients = [
    [Color(0xFF0284C7), Color(0xFF0EA5E9)],  // Blue
    [Color(0xFF059669), Color(0xFF10B981)],  // Green
    [Color(0xFF7C3AED), Color(0xFFA855F7)],  // Purple
    [Color(0xFFEA580C), Color(0xFFF97316)],  // Orange
    [Color(0xFFDC2626), Color(0xFFEF4444)],  // Red
    [Color(0xFF0F766E), Color(0xFF14B8A6)],  // Teal
  ];

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgColor,
      primaryColor: accentCyan,
      colorScheme: ColorScheme.light(
        primary: accentCyan,
        secondary: accentEmerald,
        surface: cardColor,
        background: bgColor,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textPrimary),
        titleTextStyle: GoogleFonts.outfit(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        shadowColor: Colors.black.withAlpha(20),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withAlpha(15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentCyan, width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        prefixIconColor: accentCyan,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: accentCyan,
        unselectedItemColor: textSecondary,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentCyan,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accentCyan),
      ),
      dividerColor: Colors.grey.shade200,
      chipTheme: ChipThemeData(
        backgroundColor: accentCyan.withAlpha(20),
        labelStyle: const TextStyle(color: accentCyan),
        side: BorderSide(color: accentCyan.withAlpha(60)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // Keep dark theme as fallback for any screen that explicitly uses it
  static const Color darkBg   = Color(0xFF0F172A);
  static const Color darkCard = Color(0xFF1E293B);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      primaryColor: accentCyan,
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        elevation: 0,
        centerTitle: true,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkCard,
        selectedItemColor: accentCyan,
        unselectedItemColor: Colors.grey,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentEmerald,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}
