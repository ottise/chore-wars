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
