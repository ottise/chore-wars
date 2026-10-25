import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../gamification/domain/entities/gamification_models.dart';

class ProfileKarmaCard extends StatelessWidget {
  const ProfileKarmaCard({
    required this.karma,
    required this.houseId,
    super.key,
  });
  final KarmaSummary karma;
  final String houseId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final negative = karma.current < 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.star_outlined,
                    color: colors.tertiary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Household Standing',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'My Karma Score',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (negative)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.error.withValues(alpha: .06),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Needs Balance',
                      style: TextStyle(
                        color: colors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: .6),
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Wrap(
                spacing: 7,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${karma.current}',
                    style: TextStyle(
                      fontSize: 34,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                      color: negative ? colors.error : colors.onSurface,
                    ),
                  ),
                  Text(
                    'karma pts',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final entry in [
                  ('Chores', karma.normalChores, 'points'),
                  ('Bonus', karma.bonus, 'rewards'),
                  ('Penalties', karma.penalties, 'deductions'),
                ])
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: entry.$2 < 0
                            ? colors.error.withValues(alpha: .04)
                            : colors.surface,
                        border: Border.all(
                          color: entry.$2 < 0
                              ? colors.error.withValues(alpha: .1)
                              : colors.outlineVariant.withValues(alpha: .5),
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Text(
                            entry.$1,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${entry.$2 > 0 ? '+' : ''}${entry.$2}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: entry.$2 < 0
                                  ? colors.error
                                  : colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            entry.$3,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: colors.surface,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onPressed: () => context.push('/houses/$houseId/karma/history'),
              child: const Row(
                children: [
                  Expanded(
                    child: Text(
                      'View Detailed Karma History',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.chevron_right_outlined, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
