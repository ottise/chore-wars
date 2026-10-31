import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../house/presentation/providers/house_providers.dart';
import '../../providers/action_proposal_providers.dart';
import 'urgent_event_banner.dart';

class UrgentCampaignDialog extends ConsumerWidget {
  const UrgentCampaignDialog({required this.houseId, super.key});

  final String houseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaign = ref.watch(activeUrgentEventForHouseProvider(houseId));
    final members = ref.watch(houseMembersProvider(houseId));
    final names = {
      for (final member in members.asData?.value ?? [])
        member.userId.toLowerCase(): member.displayName,
    };

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Urgent tasks',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close urgent tasks',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: campaign.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => TextButton(
                    onPressed: () => ref.invalidate(
                      activeUrgentEventForHouseProvider(houseId),
                    ),
                    child: const Text('Unable to load urgent tasks. Retry'),
                  ),
                  data: (proposal) {
                    if (proposal == null) {
                      return const Text('No active urgent campaign.');
                    }
                    final Map<String, List<Map>> grouped = {};
                    try {
                      final payload = jsonDecode(proposal.payloadJson) as Map;
                      final chores =
                          (payload['Chores'] ?? payload['chores']) as List? ??
                          [];
                      for (final task in chores.cast<Map>()) {
                        final userId =
                            (task['AssignedUserId'] ?? task['assignedUserId'])
                                ?.toString()
                                .toLowerCase() ??
                            '';
                        grouped.putIfAbsent(userId, () => []).add(task);
                      }
                    } on FormatException {
                      return const Text('Unable to read campaign tasks.');
                    } on TypeError {
                      return const Text('Unable to read campaign tasks.');
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        UrgentEventBanner(proposal: proposal),
                        const SizedBox(height: 16),
                        if (members.isLoading) const LinearProgressIndicator(),
                        if (members.hasError)
                          TextButton(
                            onPressed: () =>
                                ref.invalidate(houseMembersProvider(houseId)),
                            child: const Text(
                              'Unable to load member names. Retry',
                            ),
                          ),
                        if (grouped.isEmpty)
                          const Text('No tasks in this campaign.'),
                        for (final entry in grouped.entries) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  color: AppTheme.purple,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    names[entry.key] ??
                                        (entry.key.isEmpty
                                            ? 'Unassigned'
                                            : 'Household member'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text('${entry.value.length} tasks'),
                              ],
                            ),
                          ),
                          for (final task in entry.value)
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              leading: const Icon(
                                Icons.bolt_outlined,
                                color: AppTheme.orange,
                              ),
                              title: Text(
                                (task['Name'] ?? task['name'] ?? 'Urgent task')
                                    .toString(),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if ((task['Description'] ??
                                          task['description'] ??
                                          '')
                                      .toString()
                                      .isNotEmpty)
                                    Text(
                                      (task['Description'] ??
                                              task['description'])
                                          .toString(),
                                    ),
                                  Text(
                                    '${task['KarmaPoints'] ?? task['karmaPoints'] ?? 0} Karma',
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
