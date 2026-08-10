/// Prisma's Decimal fields serialize as strings over JSON — this coerces
/// either a string or a number into a double so callers don't care which.
double parseNum(dynamic value, [double fallback = 0]) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

double? parseNumOrNull(dynamic value) {
  if (value == null) return null;
  return parseNum(value);
}

DateTime? parseDateOrNull(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
