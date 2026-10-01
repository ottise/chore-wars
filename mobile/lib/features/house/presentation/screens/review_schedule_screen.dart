import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/house_providers.dart';

class ReviewScheduleScreen extends ConsumerStatefulWidget {
  const ReviewScheduleScreen({
    required this.houseId,
    required this.seasonId,
    super.key,
  });
  final String houseId;
  final String seasonId;

  @override
  ConsumerState<ReviewScheduleScreen> createState() => _ReviewScheduleScreenState();
}

class _ReviewScheduleScreenState extends ConsumerState<ReviewScheduleScreen> {
  bool _loading = false;
  List<dynamic> _occurrences = [];
  bool _occurrencesLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOccurrences();
  }

  Future<void> _fetchOccurrences() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/houses/${widget.houseId}/seasons/${widget.seasonId}/occurrences');
      if (mounted) {
        setState(() {
          _occurrences = res.data;
          _occurrencesLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _occurrencesLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _action(bool confirm) async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final action = confirm ? 'confirm' : 'reject';
      await dio.post('/houses/${widget.houseId}/seasons/${widget.seasonId}/$action');
      if (mounted) {
        refreshHouseState(ref, houseId: widget.houseId);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(confirm ? 'Schedule confirmed!' : 'Schedule rejected!')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _assignOccurrence(String occurrenceId, String memberId) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.put(
        '/houses/${widget.houseId}/seasons/${widget.seasonId}/occurrences/$occurrenceId/assign',
        data: {'assigneeId': memberId},
      );
      await _fetchOccurrences(); // Refresh
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _showAssignDialog(dynamic occurrence, List<dynamic> members) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign Chore'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: members.length,
            itemBuilder: (ctx, i) {
              final m = members[i];
              return ListTile(
                leading: CircleAvatar(child: Text(m.user.displayName[0])),
                title: Text(m.user.displayName),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _assignOccurrence(occurrence['id'], m.userId);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeSeasonAsync = ref.watch(activeSeasonProvider(widget.houseId));
    final membersAsync = ref.watch(houseMembersProvider(widget.houseId));
    
    final isManual = activeSeasonAsync.value?['allocationMethod'] == 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Review Schedule')),
      body: _occurrencesLoading || membersAsync.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  width: double.infinity,
                  child: Column(
                    children: [
                      Text(
                        isManual ? 'Assign Chores' : 'Schedule Generated',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isManual
                            ? 'Please tap on unassigned chores to manually assign them to members.'
                            : 'The AI has allocated chores based on member availability. Please review and confirm.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _occurrences.length,
                    itemBuilder: (context, index) {
                      final occ = _occurrences[index];
                      final isUnassigned = occ['assignedUserId'] == null;
                      final date = DateTime.parse(occ['dueDate']).toLocal();
                      final dateStr = '${date.day}/${date.month}/${date.year}';
                      
                      return ListTile(
                        title: Text(occ['choreName']),
                        subtitle: Text('Due: $dateStr'),
                        trailing: isUnassigned
                            ? (isManual
                                ? ElevatedButton(
                                    onPressed: () => _showAssignDialog(occ, membersAsync.value ?? []),
                                    child: const Text('Assign'),
                                  )
                                : const Text('Unassigned', style: TextStyle(color: AppTheme.red)))
                            : Chip(label: Text(occ['assignedUserDisplayName'] ?? 'Unknown')),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _loading
                      ? const CircularProgressIndicator()
                      : Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _action(false),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.red,
                                  side: const BorderSide(color: AppTheme.red),
                                ),
                                child: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _action(true),
                                child: const Text('Confirm'),
                              ),
                            ),
                          ],
                        ),
                )
              ],
            ),
    );
  }
}
