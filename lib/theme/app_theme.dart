import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AccentColor {
  red('Red', Color(0xFFFF3B30)),
  electricYellow('Electric Yellow', Color(0xFFE8FF47)),
  blue('Blue', Color(0xFF0A84FF)),
  green('Green', Color(0xFF30D158)),
  orange('Orange', Color(0xFFFF9F0A)),
  purple('Purple', Color(0xFFBF5AF2)),
  pink('Pink', Color(0xFFFF375F));

  final String label;
  final Color color;
  const AccentColor(this.label, this.color);
}

const Color primary = Color(0xFFFFFFFF);
const Color background = Color(0xFF0D0D0D);
const Color surface = Color(0xFF1C1C1E);
const Color surfaceVariant = Color(0xFF2C2C2E);
const Color textPrimary = Color(0xFFFFFFFF);
const Color textSecondary = Color(0xFF8E8E93);
const Color textTertiary = Color(0xFF48484A);

ThemeData appTheme({AccentColor accent = AccentColor.red}) {
  final accentColor = accent.color;

  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.dark(
      primary: primary,
      secondary: accentColor,
      surface: surface,
      onSurface: textPrimary,
      onPrimary: background,
    ),
    textTheme: TextTheme(
      displayLarge: GoogleFonts.sora(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      displayMedium: GoogleFonts.sora(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      ),
      bodySmall: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textTertiary,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: GoogleFonts.sora(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      iconTheme: const IconThemeData(color: textPrimary),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    iconTheme: const IconThemeData(color: textPrimary),
    dividerColor: surfaceVariant,
  );
}
