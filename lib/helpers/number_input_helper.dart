/// Normalizes locale decimal separators (e.g. Indonesian keypad comma) to `.`
/// so [num.tryParse] / backend coercion accept the value.
String normalizeDecimalInput(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;

  // Keypads in some locales only offer `,` as the decimal separator.
  if (trimmed.contains(',') && !trimmed.contains('.')) {
    return trimmed.replaceAll(',', '.');
  }

  return trimmed;
}

num? parseLocalizedNumber(String? value) {
  if (value == null) return null;
  final normalized = normalizeDecimalInput(value);
  if (normalized.isEmpty) return null;
  return num.tryParse(normalized);
}

int? parseLocalizedInt(String? value) {
  final parsed = parseLocalizedNumber(value);
  if (parsed == null) return null;
  if (parsed % 1 != 0) return null;
  return parsed.toInt();
}
