import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../chore/domain/entities/chore_models.dart';
import '../../../chore/presentation/providers/chore_providers.dart';
import '../providers/gamification_providers.dart';
import '../../../../core/utils/api_error_message.dart';


class ChorePassScreen extends ConsumerStatefulWidget {
  const ChorePassScreen({
    required this.houseId,
    required this.seasonId,
    required this.redemptionId,
    super.key,
  });
  final String houseId;
  final String seasonId;
  final String redemptionId;

  @override
  ConsumerState<ChorePassScreen> createState() => _ChorePassScreenState();
}

class _ChorePassScreenState extends ConsumerState<ChorePassScreen> {
  String? _selectedId;
  bool _using = false;

  @override
  Widget build(BuildContext context) {
    final chores = ref.watch(myChoresProvider(widget.houseId));
    return Scaffold(
      appBar: AppBar(title: const Text('Your chore pass')),
      body: chores.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(myChoresProvider(widget.houseId)),
        ),
        data: (items) {
          final eligible = items
              .where((item) => item.status == ChoreStatus.assigned)
              .toList();
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    const _PassHeader(),
                    const SizedBox(height: 24),
                    Text(
                      'Select one chore',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (eligible.isEmpty)
                      const SizedBox(
                        height: 260,
                        child: EmptyView(
                          icon: Icons.task_alt_rounded,
                          title: 'No eligible chores',
                          message:
                              'Only pending chores can be covered by a pass.',
                        ),
                      )
                    else
                      for (final chore in eligible) ...[
                        Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => setState(() => _selectedId = chore.id),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(
                                    _selectedId == chore.id
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_off_rounded,
                                    color: _selectedId == chore.id
                                        ? AppTheme.purple
                                        : AppTheme.muted,
                                  ),
                                  const SizedBox(width: 14),
                                  const Icon(Icons.cleaning_services_outlined),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          chore.choreName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Due ${_relativeDue(chore.dueDate)}',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: ElevatedButton.icon(
                    onPressed: _selectedId == null || _using ? null : _usePass,
                    icon: _using
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.confirmation_number_outlined),
                    label: const Text('Use chore pass'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _relativeDue(DateTime date) {
    final local = date.toLocal();
    if (DateUtils.isSameDay(local, DateTime.now())) {
      return 'today at ${TimeOfDay.fromDateTime(local).format(context)}';
    }
    return '${local.month}/${local.day}';
  }

  Future<void> _usePass() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use your chore pass?'),
        content: const Text(
          'You will be excused without a penalty. The server will reassign the chore so the work stays covered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Use pass'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _using = true);
    try {
      await ref
          .read(gamificationRepositoryProvider)
          .useChorePass(widget.houseId, widget.redemptionId, _selectedId!);
      refreshChoreState(ref, widget.houseId, occurrenceId: _selectedId);
      ref.invalidate(
        seasonRewardsProvider((
          houseId: widget.houseId,
          seasonId: widget.seasonId,
        )),
      );
      ref.invalidate(leaderboardProvider);
      if (mounted) {
        showAppMessage(
          context,
          'Chore pass used — the chore has been reassigned',
        );
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) showAppMessage(context, apiErrorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _using = false);
    }
  }
}

class _PassHeader extends StatelessWidget {
  const _PassHeader();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AppTheme.purple,
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Row(
      children: [
        Icon(
          Icons.confirmation_number_rounded,
          size: 46,
          color: AppTheme.yellow,
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chore pass',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 21,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Available · Covers one assignment',
                style: TextStyle(color: Color(0xFFE5E1FF)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
