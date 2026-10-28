import 'package:dio/dio.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/auth_models.dart';

class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._dio);
  final Dio _dio;

  Future<AuthUser> googleLogin(String idToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.googleLogin,
      data: {'idToken': idToken},
    );
    return AuthUser.fromJson(response.data!);
  }

  Future<void> linkGoogle(String idToken) async {
    await _dio.post<void>(ApiEndpoints.googleLink, data: {'idToken': idToken});
  }

  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.login,
      data: {'email': email, 'password': password},
    );
    return AuthUser.fromJson(response.data!);
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await _dio.post<void>(
      ApiEndpoints.register,
      data: {'email': email, 'password': password, 'displayName': displayName},
    );
  }

  Future<AuthUser> refreshToken(String refreshToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.refreshToken,
      data: {'refreshToken': refreshToken},
    );
    return AuthUser.fromJson(response.data!);
  }

  Future<void> logout() async {
    await _dio.post<void>(ApiEndpoints.logout);
  }

  Future<UserProfile> getProfile() async {
    final response = await _dio.get<Map<String, dynamic>>(ApiEndpoints.profile);
    return UserProfile.fromJson(response.data!);
  }

  Future<UserProfile> updateProfile({required String displayName}) async {
    final response = await _dio.put<Map<String, dynamic>>(
      ApiEndpoints.profile,
      data: {'displayName': displayName},
    );
    return UserProfile.fromJson(response.data!);
  }

  Future<UserProfile> uploadAvatar(List<int> bytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.avatar,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return UserProfile.fromJson(response.data!);
  }
}
