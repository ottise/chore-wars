import '../entities/gamification_models.dart';

abstract interface class GamificationRepository {
  Future<List<SeasonRanking>> getRankings(String houseId, String seasonId);
  Future<KarmaSummary> getKarma(String houseId);
  Future<List<KarmaTransaction>> getKarmaHistory(String houseId);
  Future<List<Achievement>> getAchievements(String houseId);
  Future<List<SeasonReward>> getSeasonRewards(String houseId, String seasonId);
  Future<void> claimReward(String houseId, String redemptionId);
  Future<void> useChorePass(
    String houseId,
    String redemptionId,
    String occurrenceId,
  );
}
