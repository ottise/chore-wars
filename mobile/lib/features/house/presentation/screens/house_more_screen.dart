import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_states.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/house_models.dart';
import '../providers/house_providers.dart';

class HouseMoreScreen extends ConsumerWidget {
  const HouseMoreScreen({required this.houseId, super.key});
  final String houseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final house = ref.watch(houseDetailProvider(houseId));
    final season = ref.watch(activeSeasonProvider(houseId));
    final base = '/houses/$houseId';
    final colors = Theme.of(context).colorScheme;
    Widget link(
      String title,
      String subtitle,
      IconData icon,
      String path, {
      Color? accent,
      bool highlighted = false,
    }) {
      final tint = accent ?? colors.primary;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Material(
          color: highlighted
              ? colors.primaryFixed.withValues(alpha: .25)
              : colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            dense: true,
            minTileHeight: 60,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: .08),
                border: Border.all(color: tint.withValues(alpha: .12)),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: tint, size: 21),
            ),
            title: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: colors.onSurfaceVariant,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right_outlined,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
            onTap: () => context.push(path),
          ),
        ),
      );
    }

    Widget section(String title, Color dot, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Row(
              children: [
                Icon(Icons.circle_outlined, size: 7, color: dot),
                const SizedBox(width: 7),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .6,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Card(child: Column(children: children)),
        ],
      ),
    );
    final current = season.asData?.value;
    final status = current?['status'];
    final active = status == 2 || status == 'ACTIVE';
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'House Management',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            Text(
              'Season governance & settings',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          if (current != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                backgroundColor: active
                    ? AppTheme.successContainer
                    : colors.primaryFixed,
                side: BorderSide(
                  color: active
                      ? AppTheme.green.withValues(alpha: .2)
                      : colors.outlineVariant.withValues(alpha: .35),
                ),
                label: Text(
                  active
                      ? 'Season Active'
                      : 'Season ${status == 0 || status == 'DRAFT'
                            ? 'Draft'
                            : status == 1 || status == 'REVIEWING'
                            ? 'In Review'
                            : 'Ended'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: active
                        ? AppTheme.green
                        : colors.onPrimaryFixedVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: house.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(houseDetailProvider(houseId)),
        ),
        data: (h) => ListView(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
          children: [
            section('SEASON MANAGEMENT', colors.primary, [
              season.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                ),
                error: (error, _) => ErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(activeSeasonProvider(houseId)),
                ),
                data: (s) => s == null
                    ? const ListTile(
                        title: Text('No season yet'),
                        subtitle: Text(
                          'Start a season to organize household chores.',
                        ),
                      )
                    : Column(
                        children: [
                          link(
                            'Household Summary',
                            'Schedule, spending & chore contributions',
                            Icons.calendar_month_outlined,
                            '$base/seasons/${s['id']}/review',
                            highlighted: true,
                          ),
                          const Divider(indent: 18, endIndent: 18),
                          link(
                            'Leaderboard',
                            'Karma standings & member rankings',
                            Icons.leaderboard_outlined,
                            '$base/seasons/${s['id']}/leaderboard',
                            accent: colors.tertiary,
                          ),
                          const Divider(indent: 18, endIndent: 18),
                          link(
                            'End-of-Season Rewards',
                            'Review the season prize & results',
                            Icons.auto_awesome_outlined,
                            '$base/seasons/${s['id']}/rewards',
                          ),
                        ],
                      ),
              ),
              if (h.myRole == HouseRole.owner) ...[
                const Divider(indent: 18, endIndent: 18),
                link(
                  'Create New Season',
                  'Set dates, rules & assignment preferences',
                  Icons.add_outlined,
                  '$base/seasons/new',
                  accent: const Color(0xFF386A43),
                ),
              ],
            ]),
            section('REWARDS & RECOGNITION', colors.tertiary, [
              link(
                'House Rewards',
                'Season rewards & Chore Passes',
                Icons.card_giftcard_outlined,
                '$base/rewards',
                accent: colors.error,
              ),
              const Divider(indent: 18, endIndent: 18),
              link(
                'House Achievements',
                'Household milestones & achievements',
                Icons.star_outline_rounded,
                '$base/achievements',
                accent: colors.tertiary,
              ),
            ]),
            section('SYSTEM & PREFERENCES', colors.onSurfaceVariant, [
              link(
                'System Notifications',
                'Chore updates & household alerts',
                Icons.notifications_none_outlined,
                '/notifications?houseId=${Uri.encodeComponent(houseId)}',
              ),
              const Divider(indent: 18, endIndent: 18),
              link(
                'Karma History',
                'Your recorded points & penalties',
                Icons.history_outlined,
                '$base/karma/history',
              ),
              const Divider(indent: 18, endIndent: 18),
              link(
                'House Settings',
                'Manage members & household preferences',
                Icons.settings_outlined,
                '$base/settings',
              ),
              const Divider(indent: 18, endIndent: 18),
              link(
                'Payment History',
                'Your money in and money out',
                Icons.payments_outlined,
                '/houses/$houseId/account/payments',
              ),
            ]),
            Center(
              child: TextButton.icon(
                onPressed: () => context.go('/houses'),
                icon: const Icon(Icons.swap_horiz_outlined, size: 18),
                label: const Text('Switch House'),
              ),
            ),
            Center(
              child: Text(
                h.name,
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
