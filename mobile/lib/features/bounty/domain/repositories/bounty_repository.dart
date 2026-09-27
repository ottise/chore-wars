import '../entities/bounty.dart';

abstract interface class BountyRepository {
  Future<List<Bounty>> getBounties(String houseId);

  Future<Bounty> getBounty({required String houseId, required String bountyId});

  Future<Bounty> createBounty({
    required String houseId,
    required String choreOccurrenceId,
    required double amount,
  });

  Future<void> acceptBounty({
    required String houseId,
    required String bountyId,
  });
}