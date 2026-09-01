import 'package:flutter/material.dart';

/// Brand palette for the School Portal app.
///
/// The primary ramp mirrors the emerald scale used by the companion web app so
/// both products read as one product family.
class AppColors {
  const AppColors._();

  // ---------------------------------------------------------------- primary
  static const Color primary50 = Color(0xFFF0FDF4);
  static const Color primary100 = Color(0xFFDCFCE7);
  static const Color primary200 = Color(0xFFBBF7D0);
  static const Color primary300 = Color(0xFF86EFAC);
  static const Color primary400 = Color(0xFF4ADE80);
  static const Color primary500 = Color(0xFF22C55E);
  static const Color primary600 = Color(0xFF16A34A);
  static const Color primary700 = Color(0xFF15803D);
  static const Color primary800 = Color(0xFF166534);
  static const Color primary900 = Color(0xFF14532D);

  // ------------------------------------------------------------ accent hues
  static const Color blue = Color(0xFF3B82F6);
  static const Color indigo = Color(0xFF6366F1);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color purple = Color(0xFFA855F7);
  static const Color pink = Color(0xFFEC4899);
  static const Color rose = Color(0xFFF43F5E);
  static const Color red = Color(0xFFEF4444);
  static const Color orange = Color(0xFFF97316);
  static const Color amber = Color(0xFFF59E0B);
  static const Color yellow = Color(0xFFEAB308);
  static const Color teal = Color(0xFF14B8A6);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color slate = Color(0xFF64748B);

  // ------------------------------------------------------------ light theme
  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE6EAF0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextTertiary = Color(0xFF94A3B8);

  // ------------------------------------------------------------- dark theme
  static const Color darkBackground = Color(0xFF0B0F14);
  static const Color darkSurface = Color(0xFF151B23);
  static const Color darkSurfaceAlt = Color(0xFF1D242E);
  static const Color darkBorder = Color(0xFF283040);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextTertiary = Color(0xFF64748B);

  /// Gradient used by hero headers and the primary call-to-action.
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary600, primary800],
  );

  /// Deterministic accent for a subject name, so a subject keeps the same
  /// colour everywhere it appears.
  static Color forSubject(String subject) {
    const map = <String, Color>{
      'Mathematics': blue,
      'Physics': violet,
      'Chemistry': orange,
      'English': primary500,
      'Biology': pink,
      'History': red,
      'Geography': teal,
      'Computer Science': cyan,
      'Physical Education': yellow,
      'Art': indigo,
      'Music': rose,
      'Library': amber,
      'Science Quiz': violet,
      'Sports Practice': yellow,
      'Club Activities': slate,
    };
    return map[subject] ?? slate;
  }
}
