import '../../../../core/network/api_client.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../chat/data/models/action_proposal_model.dart';
import '../../../chat/providers/action_proposal_providers.dart';
import '../../../chat/presentation/screens/capture_photo_screen.dart';
import '../../../gamification/presentation/providers/gamification_providers.dart';
import '../../../house/presentation/providers/house_providers.dart';
import '../../domain/entities/chore_models.dart';
import '../providers/chore_providers.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../ai/presentation/ai_evidence_screen.dart';
import '../../../ai/presentation/ai_planning_screen.dart';
import '../../../ai/presentation/ai_observed_view.dart';

class ChoreDetailScreen extends ConsumerStatefulWidget {
  const ChoreDetailScreen({
    required this.houseId,
    required this.occurrenceId,
    super.key,
  });

  final String houseId;
  final String occurrenceId;

  @override
  ConsumerState<ChoreDetailScreen> createState() => _ChoreDetailScreenState();
}

class _ChoreDetailScreenState extends ConsumerState<ChoreDetailScreen> {
  bool _mutating = false;

  @override
  Widget build(BuildContext context) {
    final key = (houseId: widget.houseId, occurrenceId: widget.occurrenceId);
    final detail = ref.watch(choreDetailProvider(key));
    final authState = ref.watch(authStateProvider);
    final profile = ref.watch(userProfileProvider).asData?.value;
    final currentUserId =
        profile?.id ??
        (authState is AuthAuthenticated ? authState.user.userId : null);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chore detail'),
        actions: [
          if (detail.asData?.value.occurrence.assignedUserId == currentUserId &&
              detail.asData?.value.occurrence.status == ChoreStatus.assigned)
            IconButton(
              tooltip: 'AI swap suggestions',
              icon: const Icon(Icons.auto_awesome_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AiPlanningScreen(
                    houseId: widget.houseId,
                    kind: 'SWAP',
                    sourceOccurrenceId: widget.occurrenceId,
                  ),
                ),
              ),
            ),
          if (detail.asData?.value.occurrence.evidenceId != null ||
              detail.asData?.value.occurrence.assignedUserId == currentUserId)
            IconButton(
              tooltip: 'Photo evidence & AI feedback',
              icon: const Icon(Icons.add_a_photo_outlined),
              onPressed: () => Navigator.of(context)
                  .push<bool>(
                    MaterialPageRoute(
                      builder: (context) => AiEvidenceScreen(
                        occurrenceId: widget.occurrenceId,
                        evidenceId: detail.asData?.value.occurrence.evidenceId,
                      ),
                    ),
                  )
                  .then((changed) {
                    if (changed == true && mounted) _refreshAffectedState();
                  }),
            ),
          if (detail.asData?.value.occurrence.status ==
              ChoreStatus.criticalOverdue)
            IconButton(
              tooltip: 'Take responsibility without new compensation',
              icon: const Icon(Icons.volunteer_activism),
              onPressed: _mutating
                  ? null
                  : () async {
                      setState(() => _mutating = true);
                      try {
                        await ref
                            .read(dioProvider)
                            .post(
                              '/occurrences/${widget.occurrenceId}/take-responsibility',
                            );
                        _refreshAffectedState();
                      } catch (error) {
                        if (context.mounted) {
                          showAppMessage(
                            context,
                            apiErrorMessage(error),
                            error: true,
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _mutating = false);
                      }
                    },
            ),
        ],
      ),
      body: detail.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(choreDetailProvider(key)),
        ),
        data: (item) => AiObservedView(
          house: widget.houseId,
          entity: widget.occurrenceId,
          kind: AiObservedView.taskOpened,
          child: _DetailBody(
            detail: item,
            busy: _mutating,
            onComplete:
                item.occurrence.assignedUserId ==
                    ref.watch(userProfileProvider).asData?.value.id
                ? () => _showCompleteDialog(item)
                : null,
            onSkip: () => _skip(item),
            onSwap: _canSwap(item.occurrence, currentUserId)
                ? () => _showSwapDialog(item)
                : null,
            onCreateBounty: _canCreateBounty(item.occurrence)
                ? () => context.push(
                    '/bounties/create?houseId=${Uri.encodeComponent(widget.houseId)}'
                    '&occurrenceId=${Uri.encodeComponent(item.occurrence.id)}'
                    '&choreName=${Uri.encodeComponent(item.occurrence.choreName)}'
                    '&deadline=${Uri.encodeComponent(DateFormat('dd/MM HH:mm').format(item.occurrence.dueDate))}',
                  )
                : null,
            onEdit: item.template == null
                ? null
                : () => context.push(
                    '/houses/${widget.houseId}/chores/templates/${item.template!.id}/edit',
                    extra: item.template,
                  ),
          ),
        ),
      ),
    );
  }

  bool _canSwap(ChoreOccurrence occurrence, String? currentUserId) {
    return occurrence.status == ChoreStatus.assigned &&
        currentUserId != null &&
        occurrence.assignedUserId?.toLowerCase() == currentUserId.toLowerCase();
  }

  Future<void> _showSwapDialog(ChoreDetail detail) async {
    setState(() => _mutating = true);
    try {
      final authState = ref.read(authStateProvider);
      final profile = ref.read(userProfileProvider).asData?.value;
      final currentUserId =
          profile?.id ??
          (authState is AuthAuthenticated ? authState.user.userId : null);
      if (currentUserId == null) {
        throw StateError('Unable to identify the current account.');
      }

      final season = await ref.read(
        activeSeasonProvider(widget.houseId).future,
      );
      final seasonId = season?['id']?.toString();
      if (seasonId == null || seasonId.isEmpty) {
        throw StateError('This household has no active season.');
      }

      final response = await ref
          .read(dioProvider)
          .get('/houses/${widget.houseId}/seasons/$seasonId/occurrences');
      final rawItems = response.data is List ? response.data as List : const [];
      final candidates =
          rawItems
              .whereType<Map>()
              .map(
                (item) =>
                    ChoreOccurrence.fromJson(Map<String, dynamic>.from(item)),
              )
              .where(
                (item) =>
                    item.id != detail.occurrence.id &&
                    item.status == ChoreStatus.assigned &&
                    item.assignedUserId != null &&
                    item.assignedUserId!.toLowerCase() !=
                        currentUserId.toLowerCase(),
              )
              .toList()
            ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

      if (!mounted) return;
      if (candidates.isEmpty) {
        showAppMessage(
          context,
          'No eligible chores from other members are available to swap.',
          error: true,
        );
        return;
      }

      final selection = await _showSwapSelectionDialog(
        source: detail.occurrence,
        candidates: candidates,
      );
      if (selection == null || !mounted) return;

      await ref
          .read(actionProposalServiceProvider)
          .createProposal(
            houseId: widget.houseId,
            type: ProposalType.choreSwap,
            title:
                'Swap ${detail.occurrence.choreName} with ${selection.occurrence.choreName}',
            description: selection.note.trim().isEmpty
                ? '${detail.occurrence.assignedUserDisplayName} proposes a swap with ${selection.occurrence.assignedUserDisplayName}.'
                : selection.note.trim(),
            targetUserIds: [selection.targetUserId],
            payloadJson: jsonEncode({
              'sourceOccurrenceId': detail.occurrence.id,
              'targetOccurrenceId': selection.occurrence.id,
            }),
          );

      if (mounted) {
        showAppMessage(
          context,
          'Swap proposal sent. The other member can respond in Chat.',
        );
      }
    } catch (error) {
      if (mounted) {
        showAppMessage(context, apiErrorMessage(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<_SwapSelection?> _showSwapSelectionDialog({
    required ChoreOccurrence source,
    required List<ChoreOccurrence> candidates,
  }) async {
    final noteController = TextEditingController();
    final memberNames = <String, String>{};
    for (final item in candidates) {
      memberNames[item.assignedUserId!] = item.assignedUserDisplayName;
    }

    var targetUserId = memberNames.keys.first;
    var targetOccurrence = candidates.firstWhere(
      (item) => item.assignedUserId == targetUserId,
    );

    final result = await showDialog<_SwapSelection>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final memberChores = candidates
              .where((item) => item.assignedUserId == targetUserId)
              .toList();
          return AlertDialog(
            title: const Text('Propose a Swap'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Your chore: ${source.choreName}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<String>(
                      initialValue: targetUserId,
                      decoration: const InputDecoration(
                        labelText: 'Member to swap with',
                        border: OutlineInputBorder(),
                      ),
                      items: memberNames.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          targetUserId = value;
                          targetOccurrence = candidates.firstWhere(
                            (item) => item.assignedUserId == value,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      key: ValueKey(targetUserId),
                      initialValue: targetOccurrence.id,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Chore to take',
                        border: OutlineInputBorder(),
                      ),
                      items: memberChores
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(
                                '${item.choreName} · ${DateFormat('dd/MM HH:mm').format(item.dueDate)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          targetOccurrence = memberChores.firstWhere(
                            (item) => item.id == value,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        hintText: 'Example: I am busy tonight. Could you swap with me?',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  _SwapSelection(
                    targetUserId: targetUserId,
                    occurrence: targetOccurrence,
                    note: noteController.text,
                  ),
                ),
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Send Proposal'),
              ),
            ],
          );
        },
      ),
    );
    noteController.dispose();
    return result;
  }

  Future<void> _showCompleteDialog(ChoreDetail detail) async {
    Uint8List? selectedImageBytes;
    final picker = ImagePicker();

    final result = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pick(ImageSource source) async {
              try {
                final photo = source == ImageSource.camera
                    ? await Navigator.of(
                        context,
                        rootNavigator: true,
                      ).push<XFile>(
                        MaterialPageRoute(
                          builder: (_) => const CapturePhotoScreen(
                            title: 'Capture Photo Evidence',
                            captureLabel: 'Use This Photo',
                          ),
                        ),
                      )
                    : await picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1024,
                        maxHeight: 1024,
                        imageQuality: 85,
                      );
                if (photo != null) {
                  final bytes = await photo.readAsBytes();
                  if (!context.mounted) return;
                  setModalState(() {
                    selectedImageBytes = bytes;
                  });
                }
              } catch (e) {
                if (context.mounted) {
                  showAppMessage(
                    context,
                    'Unable to select photo: $e',
                    error: true,
                  );
                }
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.green.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.task_alt_rounded,
                          color: AppTheme.green,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Complete Chore',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '+${detail.karmaPoints} Karma Points',
                              style: const TextStyle(
                                color: AppTheme.onAmber,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Photo evidence (optional)',
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  if (selectedImageBytes != null) ...[
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            selectedImageBytes!,
                            height: 190,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            radius: 18,
                            child: IconButton(
                              icon: const Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.white,
                              ),
                              onPressed: () => setModalState(
                                () => selectedImageBytes = null,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () => pick(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_rounded, size: 18),
                          label: const Text('Retake'),
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          onPressed: () => pick(ImageSource.gallery),
                          icon: const Icon(
                            Icons.photo_library_rounded,
                            size: 18,
                          ),
                          label: const Text('Choose Another Photo'),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).dividerColor
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 38,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Take a photo of the result to share with your household',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.muted,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => pick(ImageSource.camera),
                                  icon: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Take Photo'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => pick(ImageSource.gallery),
                                  icon: const Icon(
                                    Icons.photo_library_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Gallery'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      String? proofUrl;
                      if (selectedImageBytes != null) {
                        proofUrl =
                            'data:image/jpeg;base64,${base64Encode(selectedImageBytes!)}';
                      }
                      Navigator.pop(context, proofUrl ?? '');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text(
                      'Confirm Completion',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      final proof = result.isEmpty ? null : result;
      await _complete(detail, proofImageUrl: proof);
    }
  }

  Future<void> _complete(ChoreDetail detail, {String? proofImageUrl}) async {
    setState(() => _mutating = true);
    try {
      await ref
          .read(choreRepositoryProvider)
          .completeChore(widget.occurrenceId, proofImageUrl: proofImageUrl);
      _refreshAffectedState();
      if (mounted) {
        showAppMessage(
          context,
          'Chore completed. Karma is awarded only when eligible in an open season.',
        );
      }
    } catch (error) {
      if (mounted) showAppMessage(context, apiErrorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  bool _canCreateBounty(ChoreOccurrence occurrence) {
    if (occurrence.status == ChoreStatus.completed ||
        occurrence.status == ChoreStatus.skipped) {
      return false;
    }
    final authState = ref.read(authStateProvider);
    final userId = authState is AuthAuthenticated
        ? authState.user.userId
        : null;
    if (occurrence.assignedUserId == null) return false;
    if (userId == null) {
      return occurrence.assignedUserId ==
          ref.read(userProfileProvider).asData?.value.id;
    }
    return occurrence.assignedUserId!.toLowerCase() == userId.toLowerCase();
  }

  Future<void> _skip(ChoreDetail detail) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip this occurrence?'),
        content: const Text(
          'The server will check your permission and the household rules before skipping it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep chore'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Skip'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _mutating = true);
    try {
      await ref.read(choreRepositoryProvider).skipChore(widget.occurrenceId);
      _refreshAffectedState();
      if (mounted) showAppMessage(context, 'Chore skipped');
    } catch (error) {
      if (mounted) showAppMessage(context, apiErrorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  void _refreshAffectedState() {
    refreshChoreState(ref, widget.houseId, occurrenceId: widget.occurrenceId);
    ref.invalidate(karmaSummaryProvider(widget.houseId));
    ref.invalidate(karmaHistoryProvider(widget.houseId));
    ref.invalidate(leaderboardProvider);
    ref.invalidate(achievementsProvider(widget.houseId));
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.detail,
    required this.busy,
    required this.onComplete,
    required this.onSkip,
    required this.onSwap,
    required this.onCreateBounty,
    required this.onEdit,
  });

  final ChoreDetail detail;
  final bool busy;
  final VoidCallback? onComplete;
  final VoidCallback onSkip;
  final VoidCallback? onSwap;
  final VoidCallback? onCreateBounty;
  final VoidCallback? onEdit;

  Widget _buildProofWidget(BuildContext context, String proof) {
    Widget imageWidget;
    if (proof.startsWith('data:image')) {
      final raw = proof.contains(',') ? proof.split(',')[1] : proof;
      imageWidget = Image.memory(
        base64Decode(raw),
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    } else {
      imageWidget = Image.network(
        proof,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          height: 120,
          color: AppTheme.surfaceHigh,
          child: const Center(
            child: Icon(Icons.broken_image_outlined, size: 36),
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_rounded,
                  color: AppTheme.green,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Completion Evidence',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => Dialog(
                  insetPadding: const EdgeInsets.all(12),
                  child: InteractiveViewer(
                    child: proof.startsWith('data:image')
                        ? Image.memory(
                            base64Decode(
                              proof.contains(',') ? proof.split(',')[1] : proof,
                            ),
                          )
                        : Image.network(proof),
                  ),
                ),
              );
            },
            child: imageWidget,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chore = detail.occurrence;
    final actionable =
        onComplete != null &&
        (chore.status == ChoreStatus.assigned ||
            chore.status == ChoreStatus.overdue ||
            chore.status == ChoreStatus.criticalOverdue);
    final statusColor = switch (chore.status) {
      ChoreStatus.completed => AppTheme.green,
      ChoreStatus.overdue || ChoreStatus.criticalOverdue => AppTheme.red,
      ChoreStatus.skipped => AppTheme.muted,
      ChoreStatus.assigned => AppTheme.purple,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Card(
          color: AppTheme.purple,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  detail.template?.type == ChoreType.bonus
                      ? Icons.auto_awesome_rounded
                      : Icons.cleaning_services_rounded,
                  size: 34,
                  color: AppTheme.yellow,
                ),
                const SizedBox(height: 20),
                Text(
                  chore.choreName,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(color: Colors.white),
                ),
                if (detail.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    detail.description,
                    style: const TextStyle(
                      color: AppTheme.lavender,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Assigned to',
                  value: chore.assignedUserDisplayName,
                ),
                const Divider(height: 28),
                _InfoRow(
                  icon: Icons.schedule_rounded,
                  label: 'Due',
                  value: DateFormat('EEE, MMM d · h:mm a')
                      .format(chore.dueDate),
                ),
                const Divider(height: 28),
                _InfoRow(
                  icon: Icons.bolt_rounded,
                  label: 'Karma',
                  value: '+${detail.karmaPoints}',
                  valueColor: AppTheme.onAmber,
                ),
                if (chore.penaltyCount > 0) ...[
                  const Divider(height: 28),
                  _InfoRow(
                    icon: Icons.trending_down_rounded,
                    label: 'Overdue Penalty',
                    value: '-${chore.penaltyCount * 5}',
                    valueColor: AppTheme.red,
                  ),
                ],
                const Divider(height: 28),
                _InfoRow(
                  icon: Icons.flag_outlined,
                  label: 'Status',
                  value: chore.status.label,
                  valueColor: statusColor,
                ),
              ],
            ),
          ),
        ),
        if (chore.proofImageUrl != null && chore.proofImageUrl!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildProofWidget(context, chore.proofImageUrl!),
        ],
        if (actionable) ...[
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: busy ? null : onComplete,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.green,
              foregroundColor: Colors.white,
            ),
            icon: busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text('Complete chore'),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'To transfer this chore, use a claimed Chore Pass from Rewards or post a bounty.',
            ),
          ),
        ],
        if (onSwap != null) ...[
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: busy ? null : onSwap,
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Swap with Another Member'),
          ),
        ],
        if (onCreateBounty != null) ...[
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: busy ? null : onCreateBounty,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.orange,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.volunteer_activism_rounded),
            label: const Text(
              'Post Bounty (Pay for Help)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        if (onEdit != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit chore template'),
          ),
        ],
      ],
    );
  }
}

class _SwapSelection {
  const _SwapSelection({
    required this.targetUserId,
    required this.occurrence,
    required this.note,
  });

  final String targetUserId;
  final ChoreOccurrence occurrence;
  final String note;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 22, color: AppTheme.muted),
      const SizedBox(width: 12),
      Expanded(child: Text(label)),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: TextStyle(fontWeight: FontWeight.w800, color: valueColor),
        ),
      ),
    ],
  );
}
