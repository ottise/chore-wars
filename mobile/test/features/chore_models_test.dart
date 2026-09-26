import 'package:chore_wars/features/chore/domain/entities/chore_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a chore occurrence returned by the API', () {
    final occurrence = ChoreOccurrence.fromJson({
      'id': 'occurrence-1',
      'choreId': 'chore-1',
      'choreName': 'Clean kitchen',
      'assignedUserId': 'user-1',
      'assignedUserDisplayName': 'Minh',
      'dueDate': '2026-09-23T20:00:00Z',
      'status': 2,
      'description': 'Wipe every counter',
      'karmaPoints': 10,
      'type': 0,
    });

    expect(occurrence.status, ChoreStatus.overdue);
    expect(occurrence.karmaPoints, 10);
    expect(occurrence.type, ChoreType.normal);
  });

  test('serializes the frequency fields required by create and edit', () {
    const chore = ChoreTemplate(
      id: '',
      name: 'Take out trash',
      description: 'Before collection time',
      karmaPoints: 5,
      type: ChoreType.normal,
      frequency: ChoreFrequency.specificDays,
      frequencyDays: [1, 4],
    );

    final json = chore.toRequestJson();

    expect(json['frequencyType'], 4);
    expect(json['frequencyDays'], [1, 4]);
    expect(json['karmaPoints'], 5);
  });
}
