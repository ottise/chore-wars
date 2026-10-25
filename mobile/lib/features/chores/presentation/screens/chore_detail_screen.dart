import 'package:flutter/material.dart';

class ChoreDetailScreen extends StatelessWidget {
  final String choreName;
  final String dueDate;
  final String status;

  const ChoreDetailScreen({
    super.key,
    required this.choreName,
    required this.dueDate,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chore Detail')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(choreName, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_outlined),
            title: const Text('Due'),
            subtitle: Text(dueDate),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Status'),
            subtitle: Text(status),
          ),
        ],
      ),
    );
  }
}
