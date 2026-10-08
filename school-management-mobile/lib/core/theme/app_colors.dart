import 'package:flutter/material.dart';

/// Brand palette for पाठशाला.
///
/// Every value here is taken from the web app's design tokens in
/// `school-erp-frontend/src/styles.scss`, so the two products are literally the
/// same colours rather than two designers' idea of "blue". The web file is the
/// source of truth; the comment beside each constant names the token it mirrors.
///
/// The ramp used to be emerald. The web app was rethemed to royal blue, which
/// left the phone app looking like a different product from the same school.
class AppColors {
  const AppColors._();

  // ---------------------------------------------------------------- primary
  // Royal blue. 500/600/700 are the web's --brand-light / --brand / --brand-dark;
  // the rest of the ramp fills in around them for states Flutter needs and CSS
  // did not.
  static const Color primary50 = Color(0xFFEFF6FF);
  static const Color primary100 = Color(0xFFDBEAFE);
  static const Color primary200 = Color(0xFFBFDBFE);
  static const Color primary300 = Color(0xFF93C5FD);
  static const Color primary400 = Color(0xFF60A5FA);
  static const Color primary500 = Color(0xFF3B82F6); // --brand-light
  static const Color primary600 = Color(0xFF2563EB); // --brand
  static const Color primary700 = Color(0xFF1D4ED8); // --brand-dark
  static const Color primary800 = Color(0xFF1E40AF);
  static const Color primary900 = Color(0xFF1E3A8A);

  /// --brand-tint: the wash behind selected rows and active nav items.
  static const Color primaryTint = Color(0x1A2563EB);

  // ------------------------------------------------------------ accent hues
  static const Color blue = primary600;
  static const Color indigo = Color(0xFF6366F1);
  static const Color violet = Color(0xFF7C3AED);
  static const Color purple = Color(0xFFA855F7);
  static const Color pink = Color(0xFFEC4899);
  static const Color rose = Color(0xFFF43F5E);
  static const Color red = Color(0xFFEF4444);
  static const Color orange = Color(0xFFF97316);
  static const Color amber = Color(0xFFFAB219);
  static const Color yellow = Color(0xFFEAB308);
  static const Color green = Color(0xFF0CA30C); // --good
  static const Color teal = Color(0xFF14B8A6);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color slate = Color(0xFF64748B);

  // ------------------------------------------------------------ light theme
  static const Color lightBackground = Color(0xFFF7F8FA); // --page
  static const Color lightSurface = Color(0xFFFFFFFF); // --surface
  static const Color lightSurfaceAlt = Color(0xFFF2F4F7); // --neutral-tint
  static const Color lightBorder = Color(0xFFE8EBF0); // --border
  static const Color lightTextPrimary = Color(0xFF111827); // --ink
  static const Color lightTextSecondary = Color(0xFF4B5563); // --ink-2
  static const Color lightTextTertiary = Color(0xFF9299A5); // --muted

  // ------------------------------------------------------------- dark theme
  // The web app is light-only, so there is nothing to mirror here. These are
  // the existing dark values, re-tuned to sit under a blue brand rather than a
  // green one — the surfaces carry a slight blue cast so the primary does not
  // look pasted onto a neutral grey.
  static const Color darkBackground = Color(0xFF0B0F17);
  static const Color darkSurface = Color(0xFF151A23);
  static const Color darkSurfaceAlt = Color(0xFF1D2430);
  static const Color darkBorder = Color(0xFF2A3242);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextTertiary = Color(0xFF64748B);

  // ------------------------------------------------- pastel stat-card fills
  // --tile-1..4 and their borders, cycled by position exactly as the web
  // dashboard cycles them.
  static const List<Color> tileFills = <Color>[
    Color(0xFFEFF6FF),
    Color(0xFFECFDF3),
    Color(0xFFF5F3FF),
    Color(0xFFFFFAEB),
  ];
  static const List<Color> tileBorders = <Color>[
    Color(0xFFDBEAFE),
    Color(0xFFD3F4E0),
    Color(0xFFE6E1FB),
    Color(0xFFFBEECB),
  ];

  /// Pastel fill for a card at [index], cycling through the four web tints.
  static Color tileFill(int index) => tileFills[index % tileFills.length];

  /// The border that pairs with [tileFill] at the same index.
  static Color tileBorder(int index) => tileBorders[index % tileBorders.length];

  // ------------------------------------------------------- semantic pairings
  // Each status is a tint plus the text colour that is legible on it. Taken as
  // pairs from the web so a "paid" chip is the same green in both products.
  static const Color goodText = Color(0xFF006300); // --good-text
  static const Color goodTint = Color(0x1A0CA30C); // --good-tint
  static const Color warnText = Color(0xFF7A5200); // --warn-text
  static const Color warnTint = Color(0x24FAB219); // --warn-tint
  static const Color seriousText = Color(0xFF9A3D16); // --serious-text
  static const Color seriousTint = Color(0x24EC835A); // --serious-tint
  static const Color critText = Color(0xFFB42318); // --crit-text
  static const Color critTint = Color(0x1AD03B3B); // --crit-tint
  static const Color infoText = Color(0xFF1C5CAB); // --info-text
  static const Color infoTint = Color(0x1A2A78D6); // --info-tint
  static const Color neutralTint = Color(0xFFF2F4F7); // --neutral-tint

  /// Gradient used by hero headers, the brand mark and the primary call to
  /// action — the web's `linear-gradient(135deg, --brand-light, --brand-dark)`.
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[primary500, primary700],
  );

  /// Deterministic accent for a subject name, so a subject keeps the same
  /// colour everywhere it appears.
  ///
  /// Nothing here is allowed to be the brand blue: a subject chip that matches
  /// the primary reads as "selected" rather than as a subject.
  static Color forSubject(String subject) {
    const Map<String, Color> map = <String, Color>{
      'Mathematics': indigo,
      'Physics': violet,
      'Chemistry': orange,
      'English': teal,
      'Biology': pink,
      'History': red,
      'Geography': green,
      'Computer Science': cyan,
      'Physical Education': yellow,
      'Art': purple,
      'Music': rose,
      'Library': amber,
      'Science': violet,
      'Social Studies': orange,
      'EVS': green,
      'Science Quiz': violet,
      'Sports Practice': yellow,
      'Club Activities': slate,
    };
    return map[subject] ?? slate;
  }
}
