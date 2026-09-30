import 'package:dio/dio.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/house_models.dart';

class HouseRemoteDataSource {
  const HouseRemoteDataSource(this._dio);
  final Dio _dio;

  Future<List<House>> getMyHouses() async {
    final response = await _dio.get<List<dynamic>>(ApiEndpoints.myHouses);
    return (response.data ?? const [])
        .map((item) => House.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<House> getHouse(String houseId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.houseDetails(houseId),
    );
    return House.fromJson(response.data!);
  }

  Future<List<HouseMember>> getMembers(String houseId) async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.houseMembers(houseId),
    );
    return (response.data ?? const [])
        .map((item) => HouseMember.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<House> createHouse({required String name}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.houses,
      data: {'name': name},
    );
    return House.fromJson(response.data!);
  }

  Future<void> joinHouse({required String inviteCode}) async {
    await _dio.post<void>(
      ApiEndpoints.joinHouse,
      data: {'inviteCode': inviteCode},
    );
  }

  Future<void> leaveHouse(String houseId) async {
    await _dio.delete<void>(ApiEndpoints.leaveHouse(houseId));
  }

  Future<void> kickMember({
    required String houseId,
    required String memberId,
  }) async {
    await _dio.delete<void>(ApiEndpoints.kickMember(houseId, memberId));
  }

  Future<void> transferOwnership({
    required String houseId,
    required String newOwnerId,
  }) async {
    await _dio.post<void>(
      ApiEndpoints.transferOwnership(houseId, newOwnerId),
    );
  }
}
