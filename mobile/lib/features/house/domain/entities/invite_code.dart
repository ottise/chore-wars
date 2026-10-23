String? parseInviteCode(String raw) {
  var value = raw.trim();
  final uri = Uri.tryParse(value);
  if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
    value =
        uri.queryParameters['inviteCode'] ?? uri.queryParameters['code'] ?? '';
  }
  value = value.toUpperCase();
  return RegExp(r'^[A-Z0-9]{8}$').hasMatch(value) ? value : null;
}
