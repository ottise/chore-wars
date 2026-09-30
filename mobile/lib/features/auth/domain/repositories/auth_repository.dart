import '../entities/auth_models.dart';

abstract interface class AuthRepository {
  Future<AuthUser> login({required String email, required String password});
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  });
  Future<AuthUser> refreshToken(String refreshToken);
  Future<void> logout();
  Future<UserProfile> getProfile();
  Future<UserProfile> updateProfile({required String displayName});
}
