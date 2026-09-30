import 'package:flutter/material.dart';
import '../../../../core/widgets/empty_state.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      message: 'Your profile will appear here after you sign in.',
      icon: Icons.person_outline,
    );
  }
}