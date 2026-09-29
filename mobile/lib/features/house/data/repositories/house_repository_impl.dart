import '../../domain/entities/house_models.dart';
import '../../domain/repositories/house_repository.dart';
import '../datasources/house_remote_data_source.dart';

class HouseRepositoryImpl implements HouseRepository {
  const HouseRepositoryImpl(this._remote);
  final HouseRemoteDataSource _remote;

  @override
  Future<List<House>> getMyHouses() => _remote.getMyHouses();
  @override
  Future<House> getHouse(String houseId) => _remote.getHouse(houseId);
  @override
  Future<List<HouseMember>> getMembers(String houseId) =>
      _remote.getMembers(houseId);
  @override
  Future<House> createHouse({required String name}) =>
      _remote.createHouse(name: name);
  @override
  Future<void> joinHouse({required String inviteCode}) =>
      _remote.joinHouse(inviteCode: inviteCode);
  @override
  Future<void> leaveHouse(String houseId) => _remote.leaveHouse(houseId);
  @override
  Future<void> kickMember({
    required String houseId,
    required String memberId,
  }) => _remote.kickMember(houseId: houseId, memberId: memberId);
  @override
  Future<void> transferOwnership({
    required String houseId,
    required String newOwnerId,
  }) => _remote.transferOwnership(houseId: houseId, newOwnerId: newOwnerId);
}
