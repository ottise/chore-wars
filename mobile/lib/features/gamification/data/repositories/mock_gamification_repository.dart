import '../../domain/entities/gamification_models.dart';
import '../../domain/repositories/gamification_repository.dart';

class MockGamificationRepository implements GamificationRepository {
  MockGamificationRepository() {
    final now = DateTime.now();
    _rewards.add(
      SeasonReward(
        id: 'preview-reward',
        name: 'Champion chore pass',
        description: 'Skip one pending assignment without losing Karma. The chore will be reassigned.',
        type: 0,
        status: RedemptionStatus.claimed,
        redemptionId: 'preview-chore-pass',
        claimDeadline: now.add(const Duration(days: 3)),
        usageDeadline: now.add(const Duration(days: 10)),
      ),
    );
  }

  final List<SeasonReward> _rewards = [];

  Future<T> _result<T>(T value) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return value;
  }

  @override
  Future<List<SeasonRanking>> getRankings(String houseId, String seasonId) =>
      _result(const [
        SeasonRanking(
          userId: '1',
          displayName: 'Minh',
          totalKarma: 420,
          rank: 1,
          choresCompleted: 18,
        ),
        SeasonRanking(
          userId: '2',
          displayName: 'Lan',
          totalKarma: 365,
          rank: 2,
          choresCompleted: 16,
        ),
        SeasonRanking(
          userId: '3',
          displayName: 'An',
          totalKarma: 290,
          rank: 3,
          choresCompleted: 13,
        ),
        SeasonRanking(
          userId: '4',
          displayName: 'Huy',
          totalKarma: 235,
          rank: 4,
          choresCompleted: 11,
        ),
      ]);

  @override
  Future<KarmaSummary> getKarma(String houseId) => _result(
    const KarmaSummary(
      current: 420,
      normalChores: 330,
      bonus: 120,
      penalties: -30,
    ),
  );

  @override
  Future<List<KarmaTransaction>> getKarmaHistory(String houseId) {
    final now = DateTime.now();
    return _result([
      KarmaTransaction(
        id: 'transaction-1',
        amount: 20,
        type: KarmaTransactionType.choreCompleted,
        createdAt: now.subtract(const Duration(hours: 2)),
        description: 'Completed Wash the dishes',
      ),
      KarmaTransaction(
        id: 'transaction-2',
        amount: 75,
        type: KarmaTransactionType.bonus,
        createdAt: now.subtract(const Duration(days: 1)),
        description: 'Bonus: Deep-clean the fridge',
      ),
      KarmaTransaction(
        id: 'transaction-3',
        amount: -10,
        type: KarmaTransactionType.penalty,
        createdAt: now.subtract(const Duration(days: 2)),
        description: 'Overdue penalty',
      ),
      KarmaTransaction(
        id: 'transaction-4',
        amount: 30,
        type: KarmaTransactionType.choreCompleted,
        createdAt: now.subtract(const Duration(days: 3)),
        description: 'Completed Fold the laundry',
      ),
    ]);
  }

  @override
  Future<List<Achievement>> getAchievements(String houseId) => _result([
    Achievement(
      id: 'achievement-1',
      name: 'First victory',
      description: 'Complete your first chore.',
      conditionType: 0,
      threshold: 1,
      isUnlocked: true,
      unlockedAt: DateTime.now().subtract(const Duration(days: 12)),
    ),
    Achievement(
      id: 'achievement-2',
      name: 'On fire',
      description: 'Complete chores 7 days in a row.',
      conditionType: 1,
      threshold: 7,
      isUnlocked: true,
      unlockedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    const Achievement(
      id: 'achievement-3',
      name: 'Karma legend',
      description: 'Earn 1,000 Karma in one season.',
      conditionType: 2,
      threshold: 1000,
      isUnlocked: false,
    ),
    const Achievement(
      id: 'achievement-4',
      name: 'Helping hand',
      description: 'Complete 10 bonus chores.',
      conditionType: 3,
      threshold: 10,
      isUnlocked: false,
    ),
  ]);

  @override
  Future<List<SeasonReward>> getSeasonRewards(
    String houseId,
    String seasonId,
  ) => _result(List.unmodifiable(_rewards));

  @override
  Future<void> claimReward(String houseId, String redemptionId) async {
    _setRewardStatus(redemptionId, RedemptionStatus.claimed);
    await _result(null);
  }

  @override
  Future<void> useChorePass(
    String houseId,
    String redemptionId,
    String occurrenceId,
  ) async {
    _setRewardStatus(redemptionId, RedemptionStatus.used);
    await _result(null);
  }

  void _setRewardStatus(String redemptionId, RedemptionStatus status) {
    final index = _rewards.indexWhere(
      (item) => item.redemptionId == redemptionId,
    );
    if (index < 0) return;
    final reward = _rewards[index];
    _rewards[index] = SeasonReward(
      id: reward.id,
      name: reward.name,
      description: reward.description,
      type: reward.type,
      status: status,
      redemptionId: reward.redemptionId,
      claimDeadline: reward.claimDeadline,
      usageDeadline: reward.usageDeadline,
    );
  }
}
