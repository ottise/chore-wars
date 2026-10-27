String? parseInviteCode(String raw) {
  var value = raw.trim();
  final uri = Uri.tryParse(value);
  if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
    try {
      final fragment = Uri.tryParse(uri.fragment);
      value =
          uri.queryParameters['inviteCode'] ??
          uri.queryParameters['code'] ??
          fragment?.queryParameters['inviteCode'] ??
          fragment?.queryParameters['code'] ??
          '';
    } on FormatException {
      return null;
    }
  }
  value = value.toUpperCase();
  return RegExp(r'^[A-Z0-9]{8}$').hasMatch(value) ? value : null;
}
