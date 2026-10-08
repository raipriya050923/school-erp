/// Small formatting helpers. Kept dependency-free so the app builds offline
/// without pulling `intl`.
class Format {
  const Format._();

  /// `1234567` -> `1,234,567`
  static String thousands(num value) {
    final bool negative = value < 0;
    final String digits = value.abs().toStringAsFixed(0);
    final StringBuffer out = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i != 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return negative ? '-$out' : out.toString();
  }

  /// The school's currency symbol. Every school in the system is on NPR, and
  /// this used to be a dollar sign carried over from the demo data — a fee of
  /// Rs 12,000 was being shown to parents as $12,000.
  static const String currencySymbol = 'Rs ';

  /// `6650` -> `Rs 6,650`
  static String money(num value) => '$currencySymbol${thousands(value)}';

  /// `87.4` -> `87.4%`, `88.0` -> `88%`
  static String percent(double value, {int decimals = 1}) {
    final String text = value.toStringAsFixed(decimals);
    return '${text.endsWith('.0') ? text.substring(0, text.length - 2) : text}%';
  }
}
