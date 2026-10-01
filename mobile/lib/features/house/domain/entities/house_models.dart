enum HouseRole {
  member(0, 'Member'),
  owner(1, 'Owner');

  const HouseRole(this.apiValue, this.label);
  final int apiValue;
  final String label;

  static HouseRole fromJson(Object? value) {
    if (value == 1 || value == 'OWNER') return owner;
    return member;
  }
}

enum HouseMemberStatus {
  pending(0),
  active(1),
  left(2),
  banned(3);

  const HouseMemberStatus(this.apiValue);
  final int apiValue;

  static HouseMemberStatus fromJson(Object? value) {
    if (value is int && value >= 0 && value < values.length) {
      return values[value];
    }
    final normalized = value.toString().toUpperCase();
    return switch (normalized) {
      'ACTIVE' => active,
      'LEFT' => left,
      'BANNED' => banned,
      _ => pending,
    };
  }
}

class House {
  const House({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.createdAt,
    this.avatarUrl,
    this.myRole = HouseRole.member,
  });

  final String id;
  final String name;
  final String inviteCode;
  final DateTime createdAt;
  final String? avatarUrl;
  final HouseRole myRole;

  factory House.fromJson(Map<String, dynamic> json, {HouseRole? role}) =>
      House(
        id: json['id'].toString(),
        name: json['name']?.toString() ?? '',
        inviteCode: json['inviteCode']?.toString() ?? '',
        avatarUrl: json['avatarUrl']?.toString(),
        createdAt: DateTime.parse(
          json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
        ).toLocal(),
        myRole: role ?? HouseRole.member,
      );
}

class HouseMember {
  const HouseMember({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.role,
    required this.status,
  });

  final String id;
  final String userId;
  final String displayName;
  final HouseRole role;
  final HouseMemberStatus status;

  factory HouseMember.fromJson(Map<String, dynamic> json) => HouseMember(
    id: json['id'].toString(),
    userId: json['userId'].toString(),
    displayName: json['displayName']?.toString() ?? '',
    role: HouseRole.fromJson(json['role']),
    status: HouseMemberStatus.fromJson(json['status']),
  );

  bool get isOwner => role == HouseRole.owner;
  bool get isActive => status == HouseMemberStatus.active;
}

enum PreferenceType {
  neutral(0),
  liked(1),
  disliked(2);

  const PreferenceType(this.apiValue);
  final int apiValue;

  static PreferenceType fromJson(Object? value) {
    if (value is int && value >= 0 && value < values.length) {
      return values[value];
    }
    return switch (value?.toString().toUpperCase()) {
      'LIKED' => liked,
      'DISLIKED' => disliked,
      _ => neutral,
    };
  }
}

class MemberPreference {
  const MemberPreference({
    required this.choreId,
    required this.choreName,
    required this.type,
  });

  final String choreId;
  final String choreName;
  final PreferenceType type;

  factory MemberPreference.fromJson(Map<String, dynamic> json) =>
      MemberPreference(
        choreId: json['choreId'].toString(),
        choreName: json['choreName']?.toString() ?? '',
        type: PreferenceType.fromJson(json['type']),
      );
}

class MemberConstraint {
  const MemberConstraint({
    required this.maxChoresPerWeek,
    required this.maxEffortMinutesPerDay,
  });

  final int maxChoresPerWeek;
  final int maxEffortMinutesPerDay;

  factory MemberConstraint.fromJson(Map<String, dynamic> json) =>
      MemberConstraint(
        maxChoresPerWeek: json['maxChoresPerWeek'] as int? ?? 10,
        maxEffortMinutesPerDay: json['maxEffortMinutesPerDay'] as int? ?? 120,
      );

  Map<String, dynamic> toJson() => {
    'maxChoresPerWeek': maxChoresPerWeek,
    'maxEffortMinutesPerDay': maxEffortMinutesPerDay,
  };
}
