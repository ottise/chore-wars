enum KarmaTransactionType {
  choreCompleted,
  penalty,
  bountyReward,
  rewardRedeemed,
  bonus;

  static KarmaTransactionType fromJson(Object? value) {
    if (value is int && value >= 0 && value < values.length) {
      return values[value];
    }
    return switch (value.toString().toUpperCase()) {
      'PENALTY' => penalty,
      'BOUNTY_REWARD' => bountyReward,
      'REWARD_REDEEMED' => rewardRedeemed,
      'BONUS' => bonus,
      _ => choreCompleted,
    };
  }

  String get label => switch (this) {
    choreCompleted => 'Chore completed',
    penalty => 'Overdue penalty',
    bountyReward => 'Bounty reward',
    rewardRedeemed => 'Reward redeemed',
    bonus => 'Bonus Karma',
  };
}

class KarmaSummary {
  const KarmaSummary({
    required this.current,
    required this.normalChores,
    required this.bonus,
    required this.penalties,
  });

  final int current;
  final int normalChores;
  final int bonus;
  final int penalties;

  factory KarmaSummary.fromJson(Map<String, dynamic> json) => KarmaSummary(
    current: (json['current'] ?? json['karma'] as num?)?.toInt() ?? 0,
    normalChores: (json['normalChores'] as num?)?.toInt() ?? 0,
    bonus: (json['bonus'] as num?)?.toInt() ?? 0,
    penalties: (json['penalties'] as num?)?.toInt() ?? 0,
  );
}

class KarmaTransaction {
  const KarmaTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.createdAt,
    required this.description,
  });
  final String id;
  final int amount;
  final KarmaTransactionType type;
  final DateTime createdAt;
  final String description;

  factory KarmaTransaction.fromJson(Map<String, dynamic> json) {
    final type = KarmaTransactionType.fromJson(json['type']);
    return KarmaTransaction(
      id: json['id'].toString(),
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      type: type,
      createdAt: DateTime.parse(json['createdAt'].toString()).toLocal(),
      description: json['description']?.toString() ?? type.label,
    );
  }
}

class SeasonRanking {
  const SeasonRanking({
    required this.userId,
    required this.displayName,
    required this.totalKarma,
    required this.rank,
    required this.choresCompleted,
  });
  final String userId;
  final String displayName;
  final int totalKarma;
  final int rank;
  final int choresCompleted;

  factory SeasonRanking.fromJson(Map<String, dynamic> json) => SeasonRanking(
    userId: json['userId'].toString(),
    displayName: json['displayName']?.toString() ?? 'House member',
    totalKarma: (json['totalKarma'] as num?)?.toInt() ?? 0,
    rank: (json['rank'] as num?)?.toInt() ?? 0,
    choresCompleted: (json['choresCompleted'] as num?)?.toInt() ?? 0,
  );
}

class Achievement {
  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.conditionType,
    required this.threshold,
    required this.isUnlocked,
    this.unlockedAt,
  });
  final String id;
  final String name;
  final String description;
  final int conditionType;
  final int threshold;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
    id: json['id'].toString(),
    name: json['name']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    conditionType: (json['conditionType'] as num?)?.toInt() ?? 0,
    threshold: (json['threshold'] as num?)?.toInt() ?? 0,
    isUnlocked: json['isUnlocked'] as bool? ?? false,
    unlockedAt: json['unlockedAt'] == null
        ? null
        : DateTime.parse(json['unlockedAt'].toString()).toLocal(),
  );
}

enum RedemptionStatus {
  unclaimed,
  claimed,
  used,
  expired;

  static RedemptionStatus fromJson(Object? value) {
    if (value is int && value >= 0 && value < values.length) {
      return values[value];
    }
    return switch (value.toString().toUpperCase()) {
      'CLAIMED' => claimed,
      'USED' => used,
      'EXPIRED' => expired,
      _ => unclaimed,
    };
  }

  String get label => switch (this) {
    unclaimed => 'Ready to claim',
    claimed => 'Available',
    used => 'Used',
    expired => 'Expired',
  };
}

class SeasonReward {
  const SeasonReward({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.status,
    this.redemptionId,
    this.claimDeadline,
    this.usageDeadline,
  });
  final String id;
  final String name;
  final String description;
  final int type;
  final String? redemptionId;
  final RedemptionStatus status;
  final DateTime? claimDeadline;
  final DateTime? usageDeadline;

  bool get isChorePass => type == 0;

  factory SeasonReward.fromJson(Map<String, dynamic> json) => SeasonReward(
    id: json['id'].toString(),
    name: json['name']?.toString() ?? 'Season reward',
    description: json['description']?.toString() ?? '',
    type: (json['type'] as num?)?.toInt() ?? 0,
    redemptionId: json['redemptionId']?.toString(),
    status: RedemptionStatus.fromJson(json['status']),
    claimDeadline: json['claimDeadline'] == null
        ? null
        : DateTime.parse(json['claimDeadline'].toString()).toLocal(),
    usageDeadline: json['usageDeadline'] == null
        ? null
        : DateTime.parse(json['usageDeadline'].toString()).toLocal(),
  );
}
