import '../../domain/entities/gamification_models.dart';
import '../../domain/repositories/gamification_repository.dart';
import '../datasources/gamification_remote_data_source.dart';

class GamificationRepositoryImpl implements GamificationRepository {
  const GamificationRepositoryImpl(this._remote);
  final GamificationRemoteDataSource _remote;

  @override
  Future<void> claimReward(String houseId, String redemptionId) =>
      _remote.claimReward(houseId, redemptionId);
  @override
  Future<List<Achievement>> getAchievements(String houseId) =>
      _remote.getAchievements(houseId);
  @override
  Future<KarmaSummary> getKarma(String houseId) => _remote.getKarma(houseId);
  @override
  Future<List<KarmaTransaction>> getKarmaHistory(String houseId) =>
      _remote.getKarmaHistory(houseId);
  @override
  Future<List<SeasonRanking>> getRankings(String houseId, String seasonId) =>
      _remote.getRankings(houseId, seasonId);
  @override
  Future<List<SeasonReward>> getSeasonRewards(
    String houseId,
    String seasonId,
  ) => _remote.getSeasonRewards(houseId, seasonId);
  @override
  Future<void> useChorePass(
    String houseId,
    String redemptionId,
    String occurrenceId,
  ) => _remote.useChorePass(houseId, redemptionId, occurrenceId);
}
