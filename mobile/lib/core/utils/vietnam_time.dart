/// API timestamps are instants. Keep UTC+7 wall-clock fields independent of the
/// device timezone; callers format these fields and must not call toLocal().
DateTime vietnamTime(Object? value) {
  final text = value?.toString() ?? '';
  if (!RegExp(
    r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$',
  ).hasMatch(text)) {
    throw const FormatException('Missing or invalid API timestamp');
  }
  final wall = text.substring(0, 19);
  final normalized = DateTime.parse('${wall}Z')
      .toIso8601String()
      .substring(0, 19);
  if (normalized != wall) throw const FormatException('Invalid API timestamp');
  return DateTime.parse(text).toUtc().add(const Duration(hours: 7));
}
