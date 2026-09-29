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
