/// Whether focusing the Cost field should clear the current text for easy entry.
///
/// Clears when the parsed numeric value is exactly 0 (including `0`, `0.0`,
/// `0.00`). Keeps any value already greater than zero. Non-numeric text is
/// left alone so the user can fix it.
bool shouldClearCostOnFocus(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return false;
  final parsed = double.tryParse(trimmed);
  if (parsed == null) return false;
  return parsed == 0;
}

// ---------------------------------------------------------------------------
// Quantity / cost-per-item money helpers (SPEC v5.2 §3.2–§3.4, §5.0b).
// All arithmetic is done in integers: cents for totals, ten-thousandths (bp)
// for cost per item. Rounding is half-up.
// ---------------------------------------------------------------------------

/// Max units on one row.
const int kMaxQty = 9999;

/// Dollars → integer cents, half-up.
int toCents(double dollars) => (dollars * 100 + (dollars >= 0 ? 0.5 : -0.5)).truncate();

/// Dollars → integer ten-thousandths, half-up.
int toBp(double dollars) => (dollars * 10000 + (dollars >= 0 ? 0.5 : -0.5)).truncate();

double centsToDollars(int cents) => cents / 100;
double bpToDollars(int bp) => bp / 10000;

/// Round a per-item cost to 4 dp (half-up).
double round4(double x) => bpToDollars(toBp(x));

/// Round to cents (half-up).
double round2(double x) => centsToDollars(toCents(x));

/// Line total in cents for [qty] units at [cpi] (4 dp): round(qty × cpi, 2).
int lineTotalCents(int qty, double cpi) {
  final bpTotal = qty * toBp(cpi); // exact integer ten-thousandths
  // half-up division by 100
  return bpTotal >= 0 ? (bpTotal + 50) ~/ 100 : -((-bpTotal + 50) ~/ 100);
}

/// round(qty × cpi, 2) as dollars.
double lineTotal(int qty, double cpi) => centsToDollars(lineTotalCents(qty, cpi));

/// Cost per item derived from an existing total: round4(cost / qty).
double cpiFromTotal(double cost, int qty) {
  final q = qty < 1 ? 1 : qty;
  final bp = toCents(cost) * 100; // total in bp
  // half-up integer division
  final r = bp >= 0 ? (2 * bp + q) ~/ (2 * q) : -((-2 * bp + q) ~/ (2 * q));
  return bpToDollars(r);
}

/// Result of a partial-sale money split (§3.4).
class SplitMoney {
  final double childCost;
  final double parentCost;
  const SplitMoney(this.childCost, this.parentCost);
}

/// Split [parentTotal] when selling [n] units at [cpi]: child = round(n × cpi),
/// parent = total − child (exact cents subtraction, never negative).
SplitMoney splitMoney({required double parentTotal, required double cpi, required int n}) {
  final total = toCents(parentTotal);
  var child = lineTotalCents(n, cpi);
  if (child > total) child = total;
  return SplitMoney(centsToDollars(child), centsToDollars(total - child));
}

/// "$X.XX ea" — plain 2 dp, no ≈ / < markers (Steve, v5.2).
String formatEach(double cpi) => '\$${round2(cpi).toStringAsFixed(2)} ea';

/// Field text for a stored cost per item: min 2, max 4 decimals.
String formatCpiField(double cpi) {
  var s = round4(cpi).toStringAsFixed(4);
  while (s.endsWith('0') && s.length - s.indexOf('.') > 3) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// Scanner-style cost validator (v5.2 shared by Edit Item + scanner).
String? validateCostInput(String? value) {
  final t = value?.trim() ?? '';
  if (t.isEmpty) return 'Cost is required';
  final v = double.tryParse(t);
  if (v == null) return 'Enter a valid amount';
  if (v < 0) return 'Cost cannot be negative';
  return null;
}

/// Leading-count qty suggestion for Review lots: "17 comics", "lot of 12 ...",
/// "95 comics from x". Returns null when no count 2…9999 is found.
int? suggestQtyFromDescription(String description) {
  final d = description.trim().toLowerCase();
  final patterns = [
    RegExp(r'^\(?(\d{1,4})\)?\s*x?\s+[a-z]'),
    RegExp(r'\blot\s+of\s+(\d{1,4})\b'),
    RegExp(r'^(\d{1,4})x\s'),
  ];
  for (final p in patterns) {
    final m = p.firstMatch(d);
    if (m != null) {
      final n = int.tryParse(m.group(1)!);
      // Skip likely years ("2019 Topps ...").
      if (n != null && n >= 1900 && n <= 2099) continue;
      if (n != null && n >= 2 && n <= kMaxQty) return n;
    }
  }
  return null;
}
