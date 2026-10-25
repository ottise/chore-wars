class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    required this.metadata,
  });

  bool get isChat => type == 'CHAT_MESSAGE' || type == 'CHAT_MENTION';
  bool get isTaskRequest => metadata['targetType'] == 'AI_REQUEST';
  String? get houseId => metadata['houseId']?.toString();
  String? get targetId => metadata['targetId']?.toString();
  String? get destination {
    final house = houseId;
    if (house == null || house.isEmpty) return null;
    final base = '/houses/${Uri.encodeComponent(house)}';
    if (isChat) return '$base/chat/everyone';
    final target = targetId;
    return switch (metadata['targetType']) {
      'AI_REQUEST' => '$base/chat/assistant',
      'ActionProposal' => '$base/chat/everyone',
      'BOUNTY' when target != null && target.isNotEmpty =>
        '/bounties/${Uri.encodeComponent(target)}?houseId=${Uri.encodeQueryComponent(house)}',
      'CHORE' when target != null && target.isNotEmpty =>
        '$base/chores/${Uri.encodeComponent(target)}',
      'SEASON' when target != null && target.isNotEmpty =>
        '$base/seasons/${Uri.encodeComponent(target)}/leaderboard',
      _ => null,
    };
  }

  AppNotification asRead() => AppNotification(
    id: id,
    userId: userId,
    title: title,
    message: message,
    type: type,
    isRead: true,
    createdAt: createdAt,
    metadata: metadata,
  );

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: json['type']?.toString() ?? '',
      isRead: json['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      metadata: {
        if (json['metadata'] is Map)
          ...Map<String, dynamic>.from(json['metadata'] as Map),
        if (json['houseId'] != null) 'houseId': json['houseId'],
        if (json['targetType'] != null) 'targetType': json['targetType'],
        if (json['targetId'] != null) 'targetId': json['targetId'],
      },
    );
  }
}
