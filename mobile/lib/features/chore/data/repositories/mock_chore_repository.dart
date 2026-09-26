import '../../domain/entities/chore_models.dart';
import '../../domain/repositories/chore_repository.dart';

class MockChoreRepository implements ChoreRepository {
  MockChoreRepository() {
    final now = DateTime.now();
    _templates.addAll(const [
      ChoreTemplate(
        id: 'preview-dishes-template',
        name: 'Wash the dishes',
        description: 'Clear the sink, wash every dish, and wipe the counter.',
        karmaPoints: 20,
        type: ChoreType.normal,
        frequency: ChoreFrequency.daily,
      ),
      ChoreTemplate(
        id: 'preview-laundry-template',
        name: 'Fold the laundry',
        description: 'Fold the clean load and put everything away.',
        karmaPoints: 30,
        type: ChoreType.normal,
        frequency: ChoreFrequency.weekly,
      ),
      ChoreTemplate(
        id: 'preview-fridge-template',
        name: 'Deep-clean the fridge',
        description: 'A bonus mission: shelves, drawers, and expired food.',
        karmaPoints: 75,
        type: ChoreType.bonus,
        frequency: ChoreFrequency.monthly,
      ),
    ]);
    _occurrences.addAll([
      ChoreOccurrence(
        id: 'preview-dishes',
        choreId: 'preview-dishes-template',
        choreName: 'Wash the dishes',
        assignedUserId: 'preview-user',
        assignedUserDisplayName: 'Minh',
        dueDate: DateTime(now.year, now.month, now.day, 20),
        status: ChoreStatus.assigned,
        description: 'Clear the sink, wash every dish, and wipe the counter.',
        karmaPoints: 20,
      ),
      ChoreOccurrence(
        id: 'preview-laundry',
        choreId: 'preview-laundry-template',
        choreName: 'Fold the laundry',
        assignedUserId: 'preview-user',
        assignedUserDisplayName: 'Minh',
        dueDate: now.add(const Duration(days: 2)),
        status: ChoreStatus.assigned,
        description: 'Fold the clean load and put everything away.',
        karmaPoints: 30,
      ),
      ChoreOccurrence(
        id: 'preview-fridge',
        choreId: 'preview-fridge-template',
        choreName: 'Deep-clean the fridge',
        assignedUserId: 'preview-user',
        assignedUserDisplayName: 'Minh',
        dueDate: now.subtract(const Duration(hours: 5)),
        status: ChoreStatus.overdue,
        description: 'A bonus mission: shelves, drawers, and expired food.',
        karmaPoints: 75,
        type: ChoreType.bonus,
      ),
    ]);
  }

  final List<ChoreTemplate> _templates = [];
  final List<ChoreOccurrence> _occurrences = [];

  Future<T> _result<T>(T value) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return value;
  }

  @override
  Future<List<ChoreTemplate>> getHouseChores(String houseId) =>
      _result(List.unmodifiable(_templates));

  @override
  Future<List<ChoreOccurrence>> getMyChores(String houseId) =>
      _result(List.unmodifiable(_occurrences));

  @override
  Future<ChoreOccurrence> getOccurrence(String occurrenceId) {
    final match = _occurrences.where((item) => item.id == occurrenceId);
    return _result(match.isEmpty ? _occurrences.first : match.first);
  }

  @override
  Future<ChoreTemplate> createChore(String houseId, ChoreTemplate chore) async {
    final created = ChoreTemplate(
      id: 'preview-template-${DateTime.now().microsecondsSinceEpoch}',
      name: chore.name,
      description: chore.description,
      karmaPoints: chore.karmaPoints,
      type: chore.type,
      frequency: chore.frequency,
      frequencyValue: chore.frequencyValue,
      frequencyDays: chore.frequencyDays,
    );
    _templates.add(created);
    return _result(created);
  }

  @override
  Future<ChoreTemplate> updateChore(ChoreTemplate chore) async {
    final index = _templates.indexWhere((item) => item.id == chore.id);
    if (index >= 0) _templates[index] = chore;
    return _result(chore);
  }

  @override
  Future<void> deleteChore(String choreId) async {
    _templates.removeWhere((item) => item.id == choreId);
    _occurrences.removeWhere((item) => item.choreId == choreId);
    await _result(null);
  }

  @override
  Future<void> completeChore(String occurrenceId) =>
      _setStatus(occurrenceId, ChoreStatus.completed);

  @override
  Future<void> skipChore(String occurrenceId) =>
      _setStatus(occurrenceId, ChoreStatus.skipped);

  Future<void> _setStatus(String occurrenceId, ChoreStatus status) async {
    final index = _occurrences.indexWhere((item) => item.id == occurrenceId);
    if (index >= 0) {
      final item = _occurrences[index];
      _occurrences[index] = ChoreOccurrence(
        id: item.id,
        choreId: item.choreId,
        choreName: item.choreName,
        assignedUserId: item.assignedUserId,
        assignedUserDisplayName: item.assignedUserDisplayName,
        dueDate: item.dueDate,
        status: status,
        description: item.description,
        karmaPoints: item.karmaPoints,
        type: item.type,
      );
    }
    await _result(null);
  }
}
