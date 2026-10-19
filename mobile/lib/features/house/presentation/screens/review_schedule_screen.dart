import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../chore/presentation/providers/chore_providers.dart';
import '../../domain/entities/house_models.dart';
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
  Object? _occurrencesError;
  
  List<dynamic> _workloadMembers = [];
  List<String> _warnings = [];
  bool _workloadLoading = true;
  Object? _workloadError;

  @override
  void initState() {
    super.initState();
    _fetchOccurrences();
    _fetchWorkloadSummary();
  }

  Future<void> _fetchOccurrences() async {
    setState(() {
      _occurrencesLoading = true;
      _occurrencesError = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/houses/${widget.houseId}/seasons/${widget.seasonId}/occurrences');
      if (mounted) {
        setState(() {
          _occurrences = res.data;
          _occurrencesLoading = false;
          _occurrencesError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _occurrencesLoading = false;
          _occurrencesError = e;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _fetchWorkloadSummary() async {
    setState(() {
      _workloadLoading = true;
      _workloadError = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(ApiEndpoints.seasonWorkloadSummary(widget.houseId, widget.seasonId));
      if (mounted) {
        setState(() {
          _workloadMembers = res.data['members'] ?? [];
          _warnings = List<String>.from(res.data['warnings'] ?? []);
          _workloadLoading = false;
          _workloadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _workloadLoading = false;
          _workloadError = e;
        });
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
        refreshChoreState(ref, widget.houseId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              confirm
                  ? 'Schedule confirmed!'
                  : 'Schedule rejected. You can now generate a new schedule.',
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
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
      await _fetchWorkloadSummary();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
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
              return Material(
                type: MaterialType.transparency,
                child: ListTile(
                  leading: CircleAvatar(child: Text(m.displayName.isNotEmpty ? m.displayName[0].toUpperCase() : '?')),
                  title: Text(m.displayName),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _assignOccurrence(occurrence['id'], m.userId);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _difficultyLabel(int? difficulty) {
    switch (difficulty) {
      case 1: return 'Easy';
      case 2: return 'Medium';
      case 3: return 'Hard';
      default: return 'Medium';
    }
  }

  Widget _buildWorkloadSummary() {
    if (_workloadLoading) return const SizedBox.shrink();
    if (_workloadError != null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.error_outline_rounded),
          title: Text(apiErrorMessage(_workloadError!)),
          trailing: TextButton(
            onPressed: _fetchWorkloadSummary,
            child: const Text('Retry'),
          ),
        ),
      );
    }
    if (_workloadMembers.isEmpty) return const SizedBox.shrink();

    int maxKarma = 1;
    for (var m in _workloadMembers) {
      final karma = (m['totalKarma'] as num?)?.toInt() ?? 0;
      if (karma > maxKarma) {
        maxKarma = karma;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, size: 20),
              const SizedBox(width: 8),
              Text(
                'Workload Summary',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._workloadMembers.map((m) {
            final int karma = (m['totalKarma'] as num?)?.toInt() ?? 0;
            final double progress = maxKarma > 0 ? (karma / maxKarma).clamp(0.0, 1.0) : 0.0;
            final int chores = (m['totalChores'] as num?)?.toInt() ?? 0;
            final int mins = (m['totalEstimatedMinutes'] as num?)?.toInt() ?? 0;
            final int h = m['hardCount'] ?? 0;
            final int med = m['mediumCount'] ?? 0;
            final int e = m['easyCount'] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(m['displayName'] ?? 'Member', style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text('$chores chores • $mins min • $karma Karma', 
                           style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Total Karma: $karma (${h}H ${med}M ${e}E)', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            );
          }),
          if (_warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._warnings.map((w) => Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(w, style: const TextStyle(color: AppTheme.orange, fontSize: 13))),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeSeasonAsync = ref.watch(activeSeasonProvider(widget.houseId));
    final membersAsync = ref.watch(houseMembersProvider(widget.houseId));
    final houseAsync = ref.watch(houseDetailProvider(widget.houseId));
    
    final isManual = activeSeasonAsync.value?['allocationMethod'] == 0;
    final isOwner = houseAsync.value?.myRole == HouseRole.owner;
    final hasConfirmed =
        activeSeasonAsync.value?['currentUserConfirmationStatus'] == 1;
    final confirmedCount = activeSeasonAsync.value?['confirmedCount'] ?? 0;
    final requiredCount =
        activeSeasonAsync.value?['requiredConfirmationCount'] ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Review Schedule')),
      body: _occurrencesLoading || membersAsync.isLoading || houseAsync.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _occurrencesError != null
              ? ErrorView(error: _occurrencesError!, onRetry: _fetchOccurrences)
          : Column(
              children: [
                _buildWorkloadSummary(),
                if (isManual && isOwner)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    width: double.infinity,
                    child: Column(
                      children: [
                        Text(
                          'Assign Chores',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Please tap on unassigned chores to manually assign them to members.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final startDateStr = activeSeasonAsync.value?['startDate'];
                      final startDate = startDateStr != null ? DateTime.parse(startDateStr).toLocal() : null;

                      final List<dynamic> listItems = [];
                      if (startDate != null && _occurrences.isNotEmpty) {
                        final sorted = List<Map<String, dynamic>>.from(_occurrences)
                          ..sort((a, b) => DateTime.parse(a['dueDate']).compareTo(DateTime.parse(b['dueDate'])));
                        
                        final firstDay = startDate.subtract(Duration(days: startDate.weekday - 1));
                        int currentWeek = -1;
                        
                        for (var occ in sorted) {
                          final date = DateTime.parse(occ['dueDate']).toLocal();
                          final diff = date.difference(firstDay).inDays;
                          final week = (diff / 7).floor() + 1;
                          
                          if (week != currentWeek) {
                            currentWeek = week;
                            listItems.add('Week $week');
                          }
                          listItems.add(occ);
                        }
                      }

                      return ListView.builder(
                        itemCount: listItems.length,
                        itemBuilder: (context, index) {
                          final item = listItems[index];
                          
                          if (item is String) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                              child: Text(
                                item,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }

                          final occ = item as Map<String, dynamic>;
                          final isUnassigned = occ['assignedUserId'] == null;
                          final date = DateTime.parse(occ['dueDate']).toLocal();
                          final dateStr = '${date.day}/${date.month}/${date.year}';
                          
                          final difficulty = occ['difficulty'];
                          final estMinutes = occ['estimatedMinutes'] ?? 0;
                          
                          return Material(
                            type: MaterialType.transparency,
                            child: ListTile(
                              title: Text(occ['choreName']),
                              subtitle: Text('Due: $dateStr • ${_difficultyLabel(difficulty)} • $estMinutes min'),
                              trailing: isUnassigned
                                  ? (isManual && isOwner
                                      ? ElevatedButton(
                                          onPressed: () => _showAssignDialog(occ, membersAsync.value ?? []),
                                          child: const Text('Assign'),
                                        )
                                      : const Text('Unassigned', style: TextStyle(color: AppTheme.red)))
                                  : Chip(label: Text(occ['assignedUserDisplayName'] ?? 'Unknown')),
                            ),
                          );
                        },
                      );
                    }
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _loading
                      ? const CircularProgressIndicator()
                      : hasConfirmed
                          ? Card(
                              color: Theme.of(
                                context,
                              ).colorScheme.secondaryContainer,
                              child: ListTile(
                                leading: const Icon(Icons.check_circle_rounded),
                                title: const Text('You confirmed this schedule'),
                                subtitle: Text(
                                  'Waiting for the other members '
                                  '($confirmedCount/$requiredCount confirmed)',
                                ),
                              ),
                            )
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
