import 'package:flutter/material.dart';

/// Centralized color palette for the Sisters Directory app.
/// Keep all raw color values here so screens/widgets never
/// hardcode colors directly.
class AppColors {
  AppColors._(); // prevent instantiation

  // Brand colors
  static const Color primary = Color(0xFF6A1B9A); // deep purple - sisterhood theme
  static const Color primaryLight = Color(0xFF9C4DCC);
  static const Color primaryDark = Color(0xFF38006B);

  static const Color secondary = Color(0xFFFFC107); // warm gold accent
  static const Color secondaryLight = Color(0xFFFFF350);
  static const Color secondaryDark = Color(0xFFC79100);

  // Backgrounds
  static const Color background = Color(0xFFF7F5FA);
  static const Color surface = Colors.white;
  static const Color cardBackground = Colors.white;

  // Text
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textOnPrimary = Colors.white;
  static const Color textHint = Color(0xFFBDBDBD);

  // Status colors
  static const Color success = Color(0xFF43A047);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFB8C00);
  static const Color info = Color(0xFF1E88E5);

  // Borders / dividers
  static const Color border = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFEEEEEE);

  // Input fields
  static const Color inputFill = Color(0xFFF2F0F5);
  static const Color inputBorder = Color(0xFFDDD6E5);
  static const Color inputFocusedBorder = primary;

  // Status chips (for member approval states used in admin pages)
  static const Color pending = Color(0xFFFFA000);
  static const Color approved = Color(0xFF43A047);
  static const Color rejected = Color(0xFFE53935);
}