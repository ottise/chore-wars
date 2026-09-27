import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/repositories/bounty_repository_impl.dart';
import '../../domain/entities/bounty.dart';
import '../../domain/repositories/bounty_repository.dart';

final bountyRepositoryProvider = Provider<BountyRepository>((ref) {
  return BountyRepositoryImpl(ref.watch(dioProvider));
});

final bountyBoardProvider = FutureProvider.autoDispose.family<List<Bounty>, String>((ref, houseId) {
  return ref.watch(bountyRepositoryProvider).getBounties(houseId);
});

final bountyDetailProvider = FutureProvider.autoDispose.family<Bounty, ({String houseId, String bountyId})>((ref, key) {
  return ref.watch(bountyRepositoryProvider).getBounty(
        houseId: key.houseId,
        bountyId: key.bountyId,
      );
});