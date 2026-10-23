import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/api_error_message.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../house/domain/entities/house_models.dart';
import '../../../house/presentation/providers/house_providers.dart';
import '../../data/models/action_proposal_model.dart';
import '../../providers/action_proposal_providers.dart';

class CreateUrgentEventScreen extends ConsumerStatefulWidget {
  const CreateUrgentEventScreen({required this.houseId, super.key});

  final String houseId;

  @override
  ConsumerState<CreateUrgentEventScreen> createState() =>
      _CreateUrgentEventScreenState();
}

class _CreateUrgentEventScreenState
    extends ConsumerState<CreateUrgentEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _deadlineController = TextEditingController(text: '30');
  final Set<String> _targetIds = {};
  final List<_UrgentChoreDraft> _chores = [_UrgentChoreDraft()];
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _deadlineController.dispose();
    for (final chore in _chores) {
      chore.dispose();
    }
    super.dispose();
  }

  Future<void> _submit({
    required String currentUserId,
    required String seasonId,
  }) async {
    if (!_formKey.currentState!.validate()) return;
    if (_targetIds.isEmpty) {
      _showError('Choose at least one participant.');
      return;
    }

    final participants = {..._targetIds, currentUserId};
    if (_chores.any(
      (chore) =>
          chore.assignedUserId == null ||
          !participants.contains(chore.assignedUserId),
    )) {
      _showError('Assign every task to a participant.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final deadlineMinutes = int.parse(_deadlineController.text.trim());
      await ref
          .read(actionProposalServiceProvider)
          .createProposal(
            houseId: widget.houseId,
            type: ProposalType.urgentEvent,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            targetUserIds: _targetIds.toList(),
            payloadJson: jsonEncode({
              'seasonId': seasonId,
              'deadlineMinutes': deadlineMinutes,
              'chores': _chores
                  .map(
                    (chore) => {
                      'name': chore.name.text.trim(),
                      'description': chore.description.text.trim(),
                      'karmaPoints': int.parse(chore.karma.text.trim()),
                      'difficulty': chore.difficulty,
                      'assignedUserId': chore.assignedUserId,
                    },
                  )
                  .toList(),
            }),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Campaign proposed. Waiting for members to approve.'),
        ),
      );
      context.go('/houses/${widget.houseId}/chat/everyone');
    } catch (error) {
      _showError(apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(houseMembersProvider(widget.houseId));
    final seasonAsync = ref.watch(activeSeasonProvider(widget.houseId));
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Urgent Campaign')),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(apiErrorMessage(error))),
        data: (allMembers) => seasonAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(apiErrorMessage(error))),
          data: (season) => profileAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text(apiErrorMessage(error))),
            data: (profile) {
              if (season == null || !_isActiveSeason(season['status'])) {
                return const Center(
                  child: Text(
                    'An active season is required to launch a campaign.',
                  ),
                );
              }

              final members = allMembers.where((m) => m.isActive).toList();
              final targets = members
                  .where(
                    (member) =>
                        member.userId.toLowerCase() != profile.id.toLowerCase(),
                  )
                  .toList();
              final participants = members
                  .where(
                    (member) =>
                        member.userId == profile.id ||
                        _targetIds.contains(member.userId),
                  )
                  .toList();

              return Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextFormField(
                      controller: _titleController,
                      maxLength: 150,
                      decoration: const InputDecoration(
                        labelText: 'Campaign Title',
                        hintText: 'Clean up for a birthday party',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter a title.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 2,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _deadlineController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Deadline After Activation (minutes)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final minutes = int.tryParse(value?.trim() ?? '');
                        if (minutes == null || minutes < 1 || minutes > 1440) {
                          return 'The deadline must be between 1 and 1,440 minutes.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Members Required to Approve',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (targets.isEmpty)
                      const Text('The house needs at least two members.')
                    else
                      Wrap(
                        spacing: 8,
                        children: targets
                            .map(
                              (member) => FilterChip(
                                label: Text(member.displayName),
                                selected: _targetIds.contains(member.userId),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _targetIds.add(member.userId);
                                    } else {
                                      _targetIds.remove(member.userId);
                                      for (final chore in _chores) {
                                        if (chore.assignedUserId ==
                                            member.userId) {
                                          chore.assignedUserId = profile.id;
                                        }
                                      }
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Task List',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(
                            () => _chores.add(
                              _UrgentChoreDraft(assignedUserId: profile.id),
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Task'),
                        ),
                      ],
                    ),
                    ..._chores.asMap().entries.map(
                      (entry) => _UrgentChoreEditor(
                        index: entry.key,
                        draft: entry.value,
                        participants: participants,
                        currentUserId: profile.id,
                        canRemove: _chores.length > 1,
                        onChanged: () => setState(() {}),
                        onRemove: () {
                          setState(() {
                            final removed = _chores.removeAt(entry.key);
                            removed.dispose();
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _submitting
                          ? null
                          : () => _submit(
                              currentUserId: profile.id,
                              seasonId: season['id'].toString(),
                            ),
                      icon: _submitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.bolt_rounded),
                      label: const Text('Launch Campaign'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  bool _isActiveSeason(Object? status) =>
      status == 2 || status?.toString().toUpperCase() == 'ACTIVE';
}

class _UrgentChoreEditor extends StatelessWidget {
  const _UrgentChoreEditor({
    required this.index,
    required this.draft,
    required this.participants,
    required this.currentUserId,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _UrgentChoreDraft draft;
  final List<HouseMember> participants;
  final String currentUserId;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    draft.assignedUserId ??= currentUserId;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Task${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (canRemove)
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
              ],
            ),
            TextFormField(
              controller: draft.name,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Task Name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a task name.'
                  : null,
            ),
            TextFormField(
              controller: draft.description,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: draft.karma,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Karma'),
                    validator: (value) {
                      final karma = int.tryParse(value?.trim() ?? '');
                      return karma == null || karma < 0
                          ? 'Enter a valid Karma value.'
                          : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: draft.difficulty,
                    decoration: const InputDecoration(labelText: 'Difficulty'),
                    items: const [
                      DropdownMenuItem(value: 'EASY', child: Text('Easy')),
                      DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
                      DropdownMenuItem(value: 'HARD', child: Text('Hard')),
                    ],
                    onChanged: (value) {
                      if (value != null) draft.difficulty = value;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey('${draft.assignedUserId}-${participants.length}'),
              initialValue:
                  participants.any(
                    (member) => member.userId == draft.assignedUserId,
                  )
                  ? draft.assignedUserId
                  : currentUserId,
              decoration: const InputDecoration(labelText: 'Giao cho'),
              items: participants
                  .map(
                    (member) => DropdownMenuItem(
                      value: member.userId,
                      child: Text(member.displayName),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                draft.assignedUserId = value;
                onChanged();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _UrgentChoreDraft {
  _UrgentChoreDraft({this.assignedUserId});

  final name = TextEditingController();
  final description = TextEditingController();
  final karma = TextEditingController(text: '10');
  String difficulty = 'MEDIUM';
  String? assignedUserId;

  void dispose() {
    name.dispose();
    description.dispose();
    karma.dispose();
  }
}
