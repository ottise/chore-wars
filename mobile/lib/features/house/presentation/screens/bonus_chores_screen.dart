import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';

class BonusChoresScreen extends ConsumerStatefulWidget {
  const BonusChoresScreen({
    required this.houseId,
    required this.seasonId,
    super.key,
  });
  final String houseId;
  final String seasonId;

  @override
  ConsumerState<BonusChoresScreen> createState() => _BonusChoresScreenState();
}

class _BonusChoresScreenState extends ConsumerState<BonusChoresScreen> {
  List<dynamic> _chores = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchBonusChores();
  }

  Future<void> _fetchBonusChores() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/houses/${widget.houseId}/seasons/${widget.seasonId}/occurrences');
      if (mounted) {
        setState(() {
          // Filter for unassigned BONUS chores (Type == 1 means BONUS in our enum)
          _chores = (res.data as List<dynamic>)
              .where((c) => c['type'] == 1 && c['assignedUserId'] == null)
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _claimChore(String occurrenceId) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/occurrences/$occurrenceId/claim');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bonus chore claimed successfully!')));
        _fetchBonusChores();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bonus Chores')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _chores.isEmpty
              ? const Center(child: Text('No available bonus chores right now.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _chores.length,
                  itemBuilder: (ctx, i) {
                    final c = _chores[i];
                    return Card(
                      child: ListTile(
                        title: Text(c['choreName']),
                        subtitle: Text("Reward: ${c['karmaPoints']} Karma"),
                        trailing: ElevatedButton(
                          onPressed: () => _claimChore(c['id']),
                          child: const Text('Claim'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
