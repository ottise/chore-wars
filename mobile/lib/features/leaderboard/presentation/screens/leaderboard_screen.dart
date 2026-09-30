import 'package:flutter/material.dart';
import '../../../../core/widgets/empty_state.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      message: 'Leaderboard data will appear after you join a house.',
      icon: Icons.emoji_events_outlined,
    );
  }
}