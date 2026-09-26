import 'package:dio/dio.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/chore_models.dart';

class ChoreRemoteDataSource {
  const ChoreRemoteDataSource(this._dio);
  final Dio _dio;

  Future<List<ChoreTemplate>> getHouseChores(String houseId) async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.houseChores(houseId),
    );
    return (response.data ?? const [])
        .map((item) => ChoreTemplate.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ChoreOccurrence>> getMyChores(String houseId) async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.myChores(houseId),
    );
    return (response.data ?? const [])
        .map((item) => ChoreOccurrence.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ChoreOccurrence> getOccurrence(String occurrenceId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.choreDetails(occurrenceId),
    );
    return ChoreOccurrence.fromJson(response.data!);
  }

  Future<ChoreTemplate> createChore(String houseId, ChoreTemplate chore) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.houseChores(houseId),
      data: chore.toRequestJson(),
    );
    return ChoreTemplate.fromJson(response.data!);
  }

  Future<ChoreTemplate> updateChore(ChoreTemplate chore) async {
    final response = await _dio.put<Map<String, dynamic>>(
      ApiEndpoints.choreTemplate(chore.id),
      data: chore.toRequestJson(),
    );
    return ChoreTemplate.fromJson(response.data!);
  }

  Future<void> deleteChore(String choreId) =>
      _dio.delete<void>(ApiEndpoints.choreTemplate(choreId));

  Future<void> completeChore(String occurrenceId) =>
      _dio.post<void>(ApiEndpoints.completeChore(occurrenceId));

  Future<void> skipChore(String occurrenceId) =>
      _dio.post<void>(ApiEndpoints.skipChore(occurrenceId));
}
