import '../../domain/entities/chore_models.dart';
import '../../domain/repositories/chore_repository.dart';
import '../datasources/chore_remote_data_source.dart';

class ChoreRepositoryImpl implements ChoreRepository {
  const ChoreRepositoryImpl(this._remote);
  final ChoreRemoteDataSource _remote;

  @override
  Future<ChoreTemplate> createChore(String houseId, ChoreTemplate chore) =>
      _remote.createChore(houseId, chore);
  @override
  Future<void> completeChore(String occurrenceId) =>
      _remote.completeChore(occurrenceId);
  @override
  Future<void> deleteChore(String choreId) => _remote.deleteChore(choreId);
  @override
  Future<List<ChoreTemplate>> getHouseChores(String houseId) =>
      _remote.getHouseChores(houseId);
  @override
  Future<List<ChoreOccurrence>> getMyChores(String houseId) =>
      _remote.getMyChores(houseId);
  @override
  Future<ChoreOccurrence> getOccurrence(String occurrenceId) =>
      _remote.getOccurrence(occurrenceId);
  @override
  Future<void> skipChore(String occurrenceId) =>
      _remote.skipChore(occurrenceId);
  @override
  Future<ChoreTemplate> updateChore(ChoreTemplate chore) =>
      _remote.updateChore(chore);
}
