import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../providers/action_proposal_providers.dart';
import 'urgent_campaign_dialog.dart';

class UrgentCampaignNotification extends ConsumerWidget {
  const UrgentCampaignNotification({required this.houseId, super.key});

  final String houseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proposal = ref.watch(activeUrgentEventForHouseProvider(houseId));
    if (proposal.asData?.value == null) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: IconButton.filledTonal(
          tooltip: 'Urgent tasks',
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            backgroundColor: AppTheme.amberContainer,
            foregroundColor: AppTheme.onAmber,
          ),
          icon: const Text('💣', style: TextStyle(fontSize: 26)),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => UrgentCampaignDialog(houseId: houseId),
          ),
        ),
      ),
    );
  }
}
