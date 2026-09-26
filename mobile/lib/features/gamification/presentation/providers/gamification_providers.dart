import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/gamification_remote_data_source.dart';
import '../../data/repositories/gamification_repository_impl.dart';
import '../../data/repositories/mock_gamification_repository.dart';
import '../../domain/entities/gamification_models.dart';
import '../../domain/repositories/gamification_repository.dart';

final gamificationRepositoryProvider = Provider<GamificationRepository>((ref) {
  if (AppConstants.uiPreview) return MockGamificationRepository();
  return GamificationRepositoryImpl(
    GamificationRemoteDataSource(ref.watch(dioProvider)),
  );
});

typedef SeasonKey = ({String houseId, String seasonId});

final leaderboardProvider =
    FutureProvider.family<List<SeasonRanking>, SeasonKey>(
      (ref, key) => ref
          .watch(gamificationRepositoryProvider)
          .getRankings(key.houseId, key.seasonId),
    );

final karmaSummaryProvider = FutureProvider.family<KarmaSummary, String>(
  (ref, houseId) => ref.watch(gamificationRepositoryProvider).getKarma(houseId),
);

final karmaHistoryProvider =
    FutureProvider.family<List<KarmaTransaction>, String>(
      (ref, houseId) =>
          ref.watch(gamificationRepositoryProvider).getKarmaHistory(houseId),
    );

final achievementsProvider = FutureProvider.family<List<Achievement>, String>(
  (ref, houseId) =>
      ref.watch(gamificationRepositoryProvider).getAchievements(houseId),
);

final seasonRewardsProvider =
    FutureProvider.family<List<SeasonReward>, SeasonKey>(
      (ref, key) => ref
          .watch(gamificationRepositoryProvider)
          .getSeasonRewards(key.houseId, key.seasonId),
    );
