/// Convert only for display/grouping; keep domain timestamps as UTC instants.
DateTime vietnamTime(Object? value) {
  if (value is DateTime) return value.toUtc().add(const Duration(hours: 7));
  final text = value?.toString() ?? '';
  if (!RegExp(
    r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$',
  ).hasMatch(text)) {
    throw const FormatException('Missing or invalid API timestamp');
  }
  final wall = text.substring(0, 19);
  if (DateTime.parse('${wall}Z').toIso8601String().substring(0, 19) != wall) {
    throw const FormatException('Invalid API timestamp');
  }
  return DateTime.parse(text).toUtc().add(const Duration(hours: 7));
}
