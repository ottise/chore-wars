import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/repositories/custom_reward_repository.dart';

final customRewardRepositoryProvider = Provider(
  (ref) => CustomRewardRepository(ref.watch(dioProvider)),
);
final customRewardsProvider = FutureProvider.autoDispose
    .family<List<CustomReward>, String>(
      (ref, houseId) => ref.watch(customRewardRepositoryProvider).list(houseId),
    );
