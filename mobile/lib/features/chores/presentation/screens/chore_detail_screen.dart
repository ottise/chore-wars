import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_error_message.dart';

class ChoreDetailScreen extends ConsumerStatefulWidget {
  const ChoreDetailScreen({required this.occurrenceId, super.key});
  final String occurrenceId;
  @override
  ConsumerState<ChoreDetailScreen> createState() => _State();
}

class _State extends ConsumerState<ChoreDetailScreen> {
  String? error;
  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      final response = await ref
          .read(dioProvider)
          .get('/occurrences/${widget.occurrenceId}');
      final house = response.data['houseId']?.toString();
      if (house == null || house.isEmpty) {
        throw StateError(
          'This chore link has no household. Open the chore from your household schedule.',
        );
      }
      if (mounted) context.go('/houses/$house/chores/${widget.occurrenceId}');
    } catch (e) {
      if (mounted) setState(() => error = apiErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Chore detail'),
      leading: BackButton(onPressed: () => context.go('/houses')),
    ),
    body: Center(
      child: error == null
          ? const CircularProgressIndicator()
          : Padding(padding: const EdgeInsets.all(24), child: Text(error!)),
    ),
  );
}
