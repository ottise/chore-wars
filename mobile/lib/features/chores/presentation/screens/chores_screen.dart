import 'package:flutter/material.dart';
import '../../../../core/widgets/empty_state.dart';

class ChoresScreen extends StatelessWidget {
  const ChoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      message: 'No chores today 🎉',
      icon: Icons.checklist_outlined,
    );
  }
}