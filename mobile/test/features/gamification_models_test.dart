import 'package:chore_wars/features/gamification/domain/entities/gamification_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('karma balance can be negative', () {
    final summary = KarmaSummary.fromJson({
      'current': -5,
      'normalChores': 10,
      'bonus': 0,
      'penalties': -15,
    });

    expect(summary.current, -5);
    expect(summary.penalties, -15);
  });

  test('parses a claimed chore pass and its usage window', () {
    final reward = SeasonReward.fromJson({
      'id': 'reward-1',
      'name': 'Chore Pass',
      'description': 'Skip one chore',
      'type': 0,
      'redemptionId': 'redemption-1',
      'status': 1,
      'claimDeadline': '2026-09-30T00:00:00Z',
      'usageDeadline': '2026-10-10T00:00:00Z',
    });

    expect(reward.status, RedemptionStatus.claimed);
    expect(reward.isChorePass, isTrue);
    expect(reward.usageDeadline, isNotNull);
  });
}
