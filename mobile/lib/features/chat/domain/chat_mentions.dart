class ChatMentionTarget {
  const ChatMentionTarget({required this.id, required this.label});
  final String id, label;
  String get token => switch (id) {
    'all' => '@all',
    'agent' => '@agent',
    _ => '@{$id}',
  };
}

final chatMemberMentionPattern = RegExp(r'@\{([0-9a-fA-F-]{36})\}');
final chatAgentMentionPattern = RegExp(r'(^|\s)@agent\b', caseSensitive: false);

String displayChatMentions(String content, Map<String, String> names) => content
    .replaceAllMapped(
      chatMemberMentionPattern,
      (match) => '@${names[match[1]] ?? 'Member'}',
    )
    .replaceAllMapped(
      RegExp(r'(^|\s)@all\b', caseSensitive: false),
      (m) => '${m[1]}@Everyone',
    )
    .replaceAllMapped(chatAgentMentionPattern, (m) => '${m[1]}@Assistant');

String chatAgentPrompt(
  String content, {
  Map<String, String> memberNames = const {},
}) => content
    .replaceAllMapped(
      chatMemberMentionPattern,
      (match) => memberNames[match[1]] ?? '',
    )
    .replaceAll(RegExp(r'(^|\s)@(agent|all)\b', caseSensitive: false), ' ')
    .trim();
