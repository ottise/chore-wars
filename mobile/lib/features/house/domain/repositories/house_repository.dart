import '../entities/house_models.dart';

abstract interface class HouseRepository {
  Future<List<House>> getMyHouses();
  Future<House> getHouse(String houseId);
  Future<List<HouseMember>> getMembers(String houseId);
  Future<House> createHouse({required String name});
  Future<void> joinHouse({required String inviteCode});
  Future<void> leaveHouse(String houseId);
  Future<void> kickMember({required String houseId, required String memberId});
  Future<void> transferOwnership({
    required String houseId,
    required String newOwnerId,
  });
}
