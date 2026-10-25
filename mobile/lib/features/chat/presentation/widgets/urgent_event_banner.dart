import 'package:chore_wars/core/theme/app_theme.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/action_proposal_model.dart';

class UrgentEventBanner extends StatefulWidget {
  const UrgentEventBanner({required this.proposal, super.key});

  final ActionProposalModel proposal;

  @override
  State<UrgentEventBanner> createState() => _UrgentEventBannerState();
}

class _UrgentEventBannerState extends State<UrgentEventBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deadline = widget.proposal.expiresAt;
    if (deadline == null) return const SizedBox.shrink();
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) return const SizedBox.shrink();
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    final seconds = remaining.inSeconds.remainder(60);
    final countdown = hours > 0
        ? '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
        : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Card(
      color: AppTheme.amberContainer,
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppTheme.orange,
          child: Icon(Icons.bolt_outlined, color: Colors.white),
        ),
        title: Text(
          'CAMPAIGN ACTIVATED: ${widget.proposal.title}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text('Urgent tasks have been added to the schedule.'),
        trailing: Text(
          countdown,
          style: const TextStyle(
            color: AppTheme.orange,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}
