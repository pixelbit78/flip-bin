/// Helpers for barcode / UPC matching (search + scanner equality).
///
/// Inventory search and scanner lookups must treat leading-zero variants as
/// the same code (e.g. `013388550265` ↔ `13388550265`) while still supporting
/// ordinary substring / LIKE matches on the raw barcode text.
class BarcodeNormalize {
  BarcodeNormalize._();

  static final RegExp _nonDigits = RegExp(r'\D');
  static final RegExp _spacesOrHyphens = RegExp(r'[\s-]');
  static final RegExp _leadingZeros = RegExp(r'^0+');

  /// Keep only digit characters from [input].
  static String digitsOnly(String input) => input.replaceAll(_nonDigits, '');

  /// Strip leading zeros from a digit string. Returns `''` if all zeros.
  static String stripLeadingZeros(String digits) {
    final stripped = digits.replaceFirst(_leadingZeros, '');
    return stripped;
  }

  /// Significant digit form: digits only, then strip leading zeros.
  ///
  /// Returns `null` when there are no significant digits (empty / all zeros).
  static String? significantDigits(String raw) {
    final digits = digitsOnly(raw.trim());
    if (digits.isEmpty) return null;
    final stripped = stripLeadingZeros(digits);
    return stripped.isEmpty ? null : stripped;
  }

  /// True when [raw] looks like a numeric UPC/EAN (mostly digits, length ≥ 8).
  static bool isNumericUpcLike(String raw) {
    final compact = raw.trim().replaceAll(_spacesOrHyphens, '');
    if (compact.length < 8) return false;
    return RegExp(r'^\d+$').hasMatch(compact);
  }

  /// Whether two barcode strings refer to the same UPC after zero-normalization.
  ///
  /// Non-numeric codes fall back to trimmed string equality.
  static bool equalsFlexible(String? stored, String query) {
    if (stored == null) return false;
    final a = stored.trim();
    final b = query.trim();
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return true;

    if (!isNumericUpcLike(a) || !isNumericUpcLike(b)) {
      return false;
    }
    final sigA = significantDigits(a);
    final sigB = significantDigits(b);
    return sigA != null && sigA == sigB;
  }

  /// Whether [stored] barcode should match inventory [query] search text.
  ///
  /// Uses case-insensitive substring on the raw strings, and when [query] is
  /// UPC-like also compares significant-digit forms (contains / equality).
  static bool matchesSearch(String? stored, String query) {
    final q = query.trim();
    if (q.isEmpty) return false;
    if (stored == null || stored.isEmpty) return false;

    final storedLower = stored.toLowerCase();
    final qLower = q.toLowerCase();
    if (storedLower.contains(qLower)) return true;

    if (!isNumericUpcLike(q)) return false;
    final qSig = significantDigits(q);
    if (qSig == null) return false;

    final storedDigits = digitsOnly(stored);
    if (storedDigits.isEmpty) return false;
    final storedSig = stripLeadingZeros(storedDigits);
    if (storedSig.isEmpty) return false;

    // Significant form equality (leading-zero variants) or digit substring.
    if (storedSig == qSig) return true;
    if (storedDigits.contains(qSig) || storedSig.contains(qSig)) return true;
    // Query with extra leading zeros vs shorter stored: compare via sig of stored.
    final qDigits = digitsOnly(q);
    if (qDigits.contains(storedSig) && storedSig.length >= 8) return true;
    return false;
  }
}
