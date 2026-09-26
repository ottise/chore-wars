import 'package:dio/dio.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/gamification_models.dart';

class GamificationRemoteDataSource {
  const GamificationRemoteDataSource(this._dio);
  final Dio _dio;

  Future<List<SeasonRanking>> getRankings(
    String houseId,
    String seasonId,
  ) async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.seasonRankings(houseId, seasonId),
    );
    return (response.data ?? const [])
        .map((item) => SeasonRanking.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<KarmaSummary> getKarma(String houseId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.karma(houseId),
    );
    return KarmaSummary.fromJson(response.data!);
  }

  Future<List<KarmaTransaction>> getKarmaHistory(String houseId) async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.karmaHistory(houseId),
    );
    return (response.data ?? const [])
        .map((item) => KarmaTransaction.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Achievement>> getAchievements(String houseId) async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.achievements(houseId),
    );
    return (response.data ?? const [])
        .map((item) => Achievement.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<SeasonReward>> getSeasonRewards(
    String houseId,
    String seasonId,
  ) async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.seasonRewards(houseId, seasonId),
    );
    return (response.data ?? const [])
        .map((item) => SeasonReward.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> claimReward(String houseId, String redemptionId) =>
      _dio.post<void>(ApiEndpoints.claimReward(houseId, redemptionId));

  Future<void> useChorePass(
    String houseId,
    String redemptionId,
    String occurrenceId,
  ) => _dio.post<void>(
    ApiEndpoints.useChorePass(houseId, redemptionId, occurrenceId),
  );
}
