class AuthUser {
  const AuthUser({
    required this.userId,
    required this.displayName,
    required this.accessToken,
    required this.refreshToken,
  });

  final String userId;
  final String displayName;
  final String accessToken;
  final String refreshToken;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    userId: json['userId'].toString(),
    displayName: json['displayName']?.toString() ?? '',
    accessToken: json['token'].toString(),
    refreshToken: json['refreshToken'].toString(),
  );
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
  });

  final String id;
  final String email;
  final String displayName;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'].toString(),
    email: json['email']?.toString() ?? '',
    displayName: json['displayName']?.toString() ?? '',
  );

  UserProfile copyWith({String? displayName}) => UserProfile(
    id: id,
    email: email,
    displayName: displayName ?? this.displayName,
  );
}
