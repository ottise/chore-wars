import '../entities/chore_models.dart';

abstract interface class ChoreRepository {
  Future<List<ChoreTemplate>> getHouseChores(String houseId);
  Future<List<ChoreOccurrence>> getMyChores(String houseId);
  Future<ChoreOccurrence> getOccurrence(String occurrenceId);
  Future<ChoreTemplate> createChore(String houseId, ChoreTemplate chore);
  Future<ChoreTemplate> updateChore(ChoreTemplate chore);
  Future<void> deleteChore(String choreId);
  Future<void> completeChore(String occurrenceId);
  Future<void> skipChore(String occurrenceId);
}
