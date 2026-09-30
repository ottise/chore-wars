import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_models.dart';
import '../../domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remote: AuthRemoteDataSource(ref.watch(dioProvider)),
    secureStorage: ref.watch(secureStorageProvider),
  );
});

// Sealed auth state
sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final AuthUser user;
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthStateNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthInitial();

  AuthRepository get _repo => ref.read(authRepositoryProvider);
  SecureStorage get _storage => ref.read(secureStorageProvider);

  Future<void> init() async {
    final token = await _storage.getAccessToken();
    if (token == null) {
      state = const AuthUnauthenticated();
    }
    // We keep the token; the router redirects based on token presence.
    // Actual validation happens on first API call (401 → refresh flow).
  }

  Future<void> login({required String email, required String password}) async {
    final user = await _repo.login(email: email, password: password);
    state = AuthAuthenticated(user);
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) => _repo.register(
    email: email,
    password: password,
    displayName: displayName,
  );

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthUnauthenticated();
  }

  void onRefreshed(AuthUser refreshed) {
    state = AuthAuthenticated(refreshed);
  }

  void onSessionExpired() {
    state = const AuthUnauthenticated();
  }
}

final authStateProvider = NotifierProvider<AuthStateNotifier, AuthState>(
  AuthStateNotifier.new,
);

final userProfileProvider = FutureProvider.autoDispose<UserProfile>((ref) {
  return ref.watch(authRepositoryProvider).getProfile();
});
