// ignore_for_file: prefer_initializing_formals
import '../../../../core/storage/secure_storage.dart';
import '../../domain/entities/auth_models.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required SecureStorage secureStorage,
  }) : _remote = remote,
       _secureStorage = secureStorage;

  final AuthRemoteDataSource _remote;
  final SecureStorage _secureStorage;

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final user = await _remote.login(email: email, password: password);
    await _secureStorage.saveTokens(
      accessToken: user.accessToken,
      refreshToken: user.refreshToken,
    );
    return user;
  }

  @override
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) => _remote.register(
    email: email,
    password: password,
    displayName: displayName,
  );

  @override
  Future<AuthUser> refreshToken(String refreshToken) async {
    final user = await _remote.refreshToken(refreshToken);
    await _secureStorage.saveTokens(
      accessToken: user.accessToken,
      refreshToken: user.refreshToken,
    );
    return user;
  }

  @override
  Future<void> logout() async {
    await _remote.logout();
    await _secureStorage.deleteTokens();
  }

  @override
  Future<UserProfile> getProfile() => _remote.getProfile();

  @override
  Future<UserProfile> updateProfile({required String displayName}) =>
      _remote.updateProfile(displayName: displayName);
}
