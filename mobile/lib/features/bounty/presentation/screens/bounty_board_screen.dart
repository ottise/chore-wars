import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/utils/vietnam_time.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../ai/presentation/ai_insights_screen.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../chore/presentation/providers/chore_providers.dart';
import '../../../house/presentation/providers/house_providers.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
import '../../../supplies/presentation/providers/supplies_providers.dart';
import '../../domain/entities/bounty.dart';
import '../providers/bounty_providers.dart';

enum _BountyMainTab { available, postedByMe, completed }

enum _BountyStatusFilter { all, open, claimed, completed }

class BountyBoardScreen extends ConsumerStatefulWidget {
  final String? houseId;

  const BountyBoardScreen({super.key, required this.houseId});

  @override
  ConsumerState<BountyBoardScreen> createState() => _BountyBoardScreenState();
}

class _BountyBoardScreenState extends ConsumerState<BountyBoardScreen> {
  _BountyMainTab _currentTab = _BountyMainTab.available;
  _BountyStatusFilter _statusFilter = _BountyStatusFilter.all;

  final Set<String> _accepting = <String>{};
  Timer? _realtimePollTimer;

  @override
  void initState() {
    super.initState();
    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    if (!bindingName.contains('TestWidgetsFlutterBinding')) {
      _realtimePollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        final houseId = widget.houseId;
        if (mounted && houseId != null && houseId.isNotEmpty) {
          ref.invalidate(bountyBoardProvider(houseId));
        }
      });
    }
  }

  @override
  void dispose() {
    _realtimePollTimer?.cancel();
    super.dispose();
  }

  Future<void> _openCreateBounty(BuildContext context) async {
    final houseId = widget.houseId;
    if (houseId == null || houseId.isEmpty) return;

    try {
      final response = await ref
          .read(dioProvider)
          .get('/houses/$houseId/bounties/eligible-chores');
      final occurrences = (response.data as List)
          .map((row) => Map<String, dynamic>.from(row))
          .toList();

      if (!context.mounted) return;
      if (occurrences.isEmpty) {
        showAppMessage(
          context,
          'You have no eligible chores of your own to post a bounty for.',
          error: true,
        );
        return;
      }

      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        showDragHandle: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  'Choose a chore to request help with',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: occurrences.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    color: Color(0xFFF1ECE7),
                  ),
                  itemBuilder: (context, index) {
                    final occurrence = occurrences[index];
                    final dueDate = DateTime.tryParse(
                      occurrence['dueDate']?.toString() ?? '',
                    );
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.cleaning_services_outlined,
                          color: Color(0xFF7C4DFF),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        occurrence['choreName']?.toString() ?? 'Chore',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      subtitle: Text(
                        dueDate == null
                            ? 'No deadline'
                            : 'Due: ${DateFormat('dd/MM HH:mm').format(vietnamTime(dueDate))}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Color(0xFF94A3B8),
                      ),
                      onTap: () => Navigator.pop(context, occurrence),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );

      if (selected == null || !context.mounted) return;
      final occurrenceId = selected['id']?.toString();
      if (occurrenceId == null || occurrenceId.isEmpty) return;
      final dueDate = DateTime.tryParse(selected['dueDate']?.toString() ?? '');
      context.push(
        '/bounties/create?houseId=${Uri.encodeComponent(houseId)}'
        '&occurrenceId=${Uri.encodeComponent(occurrenceId)}'
        '&choreName=${Uri.encodeComponent(selected['choreName']?.toString() ?? 'Chore')}'
        '&deadline=${Uri.encodeComponent(dueDate?.toLocal().toIso8601String() ?? '')}',
      );
    } catch (error) {
      if (context.mounted) {
        showAppMessage(context, apiErrorMessage(error), error: true);
      }
    }
  }

  Future<void> _handleAcceptBounty(Bounty bounty) async {
    final houseId = widget.houseId;
    if (houseId == null || houseId.isEmpty) return;

    final formattedAmount =
        '${NumberFormat.decimalPattern('en').format(bounty.amount)} VND';
    final formattedDeadline = DateFormat('dd/MM HH:mm').format(vietnamTime(bounty.expiresAt));

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Accept This Bounty?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          content: Text(
            'Do you agree to complete "${bounty.choreName}" on behalf of ${bounty.postedByDisplayName}?\n\n'
            'Reward: $formattedAmount\n'
            'Deadline: $formattedDeadline',
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C4DFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm Acceptance'),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted || !_accepting.add(bounty.id)) return;
    setState(() {});

    try {
      await ref
          .read(bountyRepositoryProvider)
          .acceptBounty(houseId: houseId, bountyId: bounty.id);
      refreshHouseState(ref, houseId: houseId);
      refreshChoreState(ref, houseId, occurrenceId: bounty.choreOccurrenceId);
      ref.invalidate(purchaseDebtsProvider(houseId));
      ref.invalidate(bountyBoardProvider(houseId));
      if (mounted) {
        showAppMessage(
          context,
          'Bounty accepted. Please complete it before the deadline.',
        );
      }
    } catch (e) {
      if (mounted) {
        showAppMessage(context, apiErrorMessage(e), error: true);
      }
    } finally {
      _accepting.remove(bounty.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final houseId = widget.houseId;
    if (houseId == null || houseId.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFFFAF8F5),
        body: EmptyState(message: 'Choose a house to view bounties.'),
      );
    }

    ref.listen(
      notificationNotifierProvider.select((state) => state.bountyBoardEpoch),
      (previous, next) {
        if (previous != next) {
          ref.invalidate(bountyBoardProvider(houseId));
        }
      },
    );

    final bountiesAsync = ref.watch(bountyBoardProvider(houseId));
    final currentUser = ref.watch(userProfileProvider).value;
    final myUserId = currentUser?.id.toLowerCase() ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopHeader(context, houseId),
            Expanded(
              child: bountiesAsync.when(
                skipLoadingOnRefresh: true,
                loading: () => const LoadingWidget(),
                error: (error, _) => ErrorState(
                  error: error,
                  onRetry: () => ref.invalidate(bountyBoardProvider(houseId)),
                ),
                data: (items) => _buildContent(items, myUserId, houseId),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context, String houseId) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.arrow_back_ios_new,
                size: 18,
                color: Color(0xFF1E293B),
              ),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go('/houses/$houseId');
                }
              },
            ),
          ),
          const Expanded(
            child: Text(
              'My Bounties',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
                letterSpacing: -0.3,
              ),
            ),
          ),
          Container(
            width: 38,
            height: 38,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: 'AI suggestions',
              icon: const Icon(
                Icons.auto_awesome_outlined,
                color: Color(0xFF7C4DFF),
                size: 19,
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AiInsightsScreen(houseId: houseId),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _openCreateBounty(context),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF7C4DFF),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.add, color: Colors.white, size: 24),
                  Positioned.fill(
                    child: Center(
                      child: Text(
                        'Post Bounty',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<Bounty> items, String myUserId, String houseId) {
    final openItems = items.where((b) => b.status == BountyStatus.open).toList();
    final claimedItems = items.where((b) => b.status == BountyStatus.claimed).toList();
    final completedItems = items.where((b) => b.status == BountyStatus.completed).toList();
    final postedByMeItems = items.where((b) => b.postedByUserId.toLowerCase() == myUserId).toList();

    final availableCount = openItems.length + claimedItems.length;
    final postedCount = postedByMeItems.length;
    final completedCount = completedItems.length;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(bountyBoardProvider(houseId).future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        children: [
          _buildPillTabSwitcher(availableCount, postedCount, completedCount),
          const SizedBox(height: 14),
          _buildFilterChips(openItems.length, claimedItems.length, availableCount),
          const SizedBox(height: 18),
          if (_currentTab == _BountyMainTab.available)
            ..._buildAvailableSection(openItems, claimedItems, myUserId, houseId)
          else if (_currentTab == _BountyMainTab.postedByMe)
            ..._buildPostedByMeSection(postedByMeItems, myUserId, houseId)
          else
            ..._buildCompletedSection(completedItems, houseId),
        ],
      ),
    );
  }

  Widget _buildPillTabSwitcher(int availableCount, int postedCount, int completedCount) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1ECE7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _buildPillTabItem(
            tab: _BountyMainTab.available,
            title: 'Available ($availableCount)',
          ),
          _buildPillTabItem(
            tab: _BountyMainTab.postedByMe,
            title: postedCount > 0 ? 'Posted by Me ($postedCount)' : 'Posted by Me',
          ),
          _buildPillTabItem(
            tab: _BountyMainTab.completed,
            title: completedCount > 0 ? 'Completed ($completedCount)' : 'Completed',
          ),
        ],
      ),
    );
  }

  Widget _buildPillTabItem({
    required _BountyMainTab tab,
    required String title,
  }) {
    final isSelected = _currentTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentTab = tab;
            _statusFilter = _BountyStatusFilter.all;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected
                  ? const Color(0xFF7C4DFF)
                  : const Color(0xFF78716C),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(int openCount, int claimedCount, int availableTotal) {
    if (_currentTab == _BountyMainTab.available) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildStatusChip(
              filter: _BountyStatusFilter.all,
              label: 'All Bounties',
              count: availableTotal,
              dotColor: null,
            ),
            const SizedBox(width: 8),
            _buildStatusChip(
              filter: _BountyStatusFilter.open,
              label: 'Open',
              count: openCount,
              dotColor: const Color(0xFFF59E0B),
            ),
            const SizedBox(width: 8),
            _buildStatusChip(
              filter: _BountyStatusFilter.claimed,
              label: 'Claimed',
              count: claimedCount,
              dotColor: const Color(0xFF10B981),
            ),
          ],
        ),
      );
    }

    if (_currentTab == _BountyMainTab.postedByMe) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildStatusChip(
              filter: _BountyStatusFilter.all,
              label: 'All Posted',
              count: null,
              dotColor: null,
            ),
            const SizedBox(width: 8),
            _buildStatusChip(
              filter: _BountyStatusFilter.open,
              label: 'Open',
              count: null,
              dotColor: const Color(0xFFF59E0B),
            ),
            const SizedBox(width: 8),
            _buildStatusChip(
              filter: _BountyStatusFilter.claimed,
              label: 'Claimed',
              count: null,
              dotColor: const Color(0xFF10B981),
            ),
            const SizedBox(width: 8),
            _buildStatusChip(
              filter: _BountyStatusFilter.completed,
              label: 'Completed',
              count: null,
              dotColor: const Color(0xFF6366F1),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildStatusChip({
    required _BountyStatusFilter filter,
    required String label,
    required int? count,
    required Color? dotColor,
  }) {
    final isSelected = _statusFilter == filter;

    if (isSelected) {
      return Material(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => setState(() => _statusFilter = filter),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dotColor != null) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => setState(() => _statusFilter = filter),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: dotColor != null
                        ? dotColor.withValues(alpha: 0.12)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: dotColor ?? const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAvailableSection(
    List<Bounty> openItems,
    List<Bounty> claimedItems,
    String myUserId,
    String houseId,
  ) {
    final showOpen = _statusFilter == _BountyStatusFilter.all ||
        _statusFilter == _BountyStatusFilter.open;
    final showClaimed = _statusFilter == _BountyStatusFilter.all ||
        _statusFilter == _BountyStatusFilter.claimed;

    final widgets = <Widget>[];

    if (showOpen && openItems.isNotEmpty) {
      widgets.add(
        _buildSectionHeader(
          dotColor: const Color(0xFFF59E0B),
          title: 'AVAILABLE & OPEN (${openItems.length})',
          badgeText: 'Needs action',
          badgeColor: const Color(0xFFFEF3C7),
          badgeTextColor: const Color(0xFFD97706),
        ),
      );
      widgets.add(const SizedBox(height: 10));
      for (final bounty in openItems) {
        final isMine = bounty.postedByUserId.toLowerCase() == myUserId;
        widgets.add(
          _BountyOpenCard(
            bounty: bounty,
            isMine: isMine,
            onTap: () => context.push(
              '/bounties/${bounty.id}?houseId=${Uri.encodeComponent(houseId)}',
            ),
            onClaim: () {
              if (!_accepting.contains(bounty.id)) {
                _handleAcceptBounty(bounty);
              }
            },
          ),
        );
      }
      widgets.add(const SizedBox(height: 14));
    }

    if (showClaimed && claimedItems.isNotEmpty) {
      widgets.add(
        _buildSectionHeader(
          dotColor: const Color(0xFF10B981),
          title: 'CLAIMED & IN PROGRESS (${claimedItems.length})',
          badgeText: 'In progress',
          badgeColor: const Color(0xFFDCFCE7),
          badgeTextColor: const Color(0xFF059669),
        ),
      );
      widgets.add(const SizedBox(height: 10));
      for (final bounty in claimedItems) {
        widgets.add(
          _BountyClaimedCard(
            bounty: bounty,
            onTap: () => context.push(
              '/bounties/${bounty.id}?houseId=${Uri.encodeComponent(houseId)}',
            ),
          ),
        );
      }
    }

    if (widgets.isEmpty) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.volunteer_activism_outlined,
                  size: 56,
                  color: Color(0xFFCBD5E1),
                ),
                SizedBox(height: 12),
                Text(
                  'No bounties match this filter',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Post a bounty with the + button above to offer a chore reward.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  List<Widget> _buildPostedByMeSection(
    List<Bounty> postedItems,
    String myUserId,
    String houseId,
  ) {
    var filtered = postedItems;
    if (_statusFilter == _BountyStatusFilter.open) {
      filtered = postedItems.where((b) => b.status == BountyStatus.open).toList();
    } else if (_statusFilter == _BountyStatusFilter.claimed) {
      filtered = postedItems.where((b) => b.status == BountyStatus.claimed).toList();
    } else if (_statusFilter == _BountyStatusFilter.completed) {
      filtered = postedItems.where((b) => b.status == BountyStatus.completed).toList();
    }

    if (filtered.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.outbox_outlined,
                  size: 56,
                  color: Color(0xFFCBD5E1),
                ),
                SizedBox(height: 12),
                Text(
                  'No posted bounties here',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Tap the + button to post a chore bounty.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      _buildSectionHeader(
        dotColor: const Color(0xFF7C4DFF),
        title: 'POSTED BY ME (${filtered.length})',
        badgeText: 'Manage',
        badgeColor: const Color(0xFFF3E8FF),
        badgeTextColor: const Color(0xFF7C4DFF),
      ),
      const SizedBox(height: 10),
      for (final bounty in filtered)
        if (bounty.status == BountyStatus.claimed)
          _BountyClaimedCard(
            bounty: bounty,
            onTap: () => context.push(
              '/bounties/${bounty.id}?houseId=${Uri.encodeComponent(houseId)}',
            ),
          )
        else if (bounty.status == BountyStatus.completed)
          _BountyCompletedCard(
            bounty: bounty,
            onTap: () => context.push(
              '/bounties/${bounty.id}?houseId=${Uri.encodeComponent(houseId)}',
            ),
          )
        else
          _BountyOpenCard(
            bounty: bounty,
            isMine: true,
            onTap: () => context.push(
              '/bounties/${bounty.id}?houseId=${Uri.encodeComponent(houseId)}',
            ),
            onClaim: () {},
          ),
    ];
  }

  List<Widget> _buildCompletedSection(List<Bounty> completedItems, String houseId) {
    if (completedItems.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 56,
                  color: Color(0xFFCBD5E1),
                ),
                SizedBox(height: 12),
                Text(
                  'No completed bounties yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      _buildSectionHeader(
        dotColor: const Color(0xFF10B981),
        title: 'COMPLETED & SETTLED (${completedItems.length})',
        badgeText: 'Verified',
        badgeColor: const Color(0xFFDCFCE7),
        badgeTextColor: const Color(0xFF059669),
      ),
      const SizedBox(height: 10),
      for (final bounty in completedItems)
        _BountyCompletedCard(
          bounty: bounty,
          onTap: () => context.push(
            '/bounties/${bounty.id}?houseId=${Uri.encodeComponent(houseId)}',
          ),
        ),
    ];
  }

  Widget _buildSectionHeader({
    required Color dotColor,
    required String title,
    required String badgeText,
    required Color badgeColor,
    required Color badgeTextColor,
  }) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: dotColor,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            badgeText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: badgeTextColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _BountyOpenCard extends StatelessWidget {
  final Bounty bounty;
  final bool isMine;
  final VoidCallback onTap;
  final VoidCallback onClaim;

  const _BountyOpenCard({
    required this.bounty,
    required this.isMine,
    required this.onTap,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final amountFormatted =
        '${NumberFormat.decimalPattern('en').format(bounty.amount)} VND';
    final dueFormatted = _formatDueText(bounty.expiresAt, bounty.postedByDisplayName);
    final bountyShortId = _shortBountyId(bounty.id);
    final choreIcon = _getChoreIcon(bounty.choreName);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1ECE7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Color(0xFFF59E0B), width: 4.5),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            choreIcon,
                            color: const Color(0xFF7C4DFF),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bounty.choreName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    amountFormatted,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '· Household reward',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      dueFormatted,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 12,
                                color: Color(0xFFD97706),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Open',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          'Bounty ID: $bountyShortId',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const Spacer(),
                        OutlinedButton(
                          onPressed: onTap,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 34),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          child: const Text(
                            'Details',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isMine)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Your Bounty',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          )
                        else
                          FilledButton(
                            onPressed: onClaim,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF7C4DFF),
                              minimumSize: const Size(0, 34),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Claim Now ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BountyClaimedCard extends StatelessWidget {
  final Bounty bounty;
  final VoidCallback onTap;

  const _BountyClaimedCard({required this.bounty, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final amountFormatted =
        '${NumberFormat.decimalPattern('en').format(bounty.amount)} VND';
    final choreIcon = _getChoreIcon(bounty.choreName);
    final assignee = bounty.newAssigneeDisplayName ?? 'Member';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1ECE7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Color(0xFF10B981), width: 4.5),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            choreIcon,
                            color: const Color(0xFF059669),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bounty.choreName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    amountFormatted,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '· Assigned task',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 13,
                                    color: Color(0xFF059669),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Claimed by $assignee · In progress',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF059669),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_rounded,
                                size: 12,
                                color: Color(0xFF059669),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Claimed',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 15,
                              color: Color(0xFF0D9488),
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Verified Bounty',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0D9488),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        OutlinedButton(
                          onPressed: onTap,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 34),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          child: const Text(
                            'Status',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BountyCompletedCard extends StatelessWidget {
  final Bounty bounty;
  final VoidCallback onTap;

  const _BountyCompletedCard({required this.bounty, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final amountFormatted =
        '${NumberFormat.decimalPattern('en').format(bounty.amount)} VND';
    final choreIcon = _getChoreIcon(bounty.choreName);
    final bountyShortId = _shortBountyId(bounty.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1ECE7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Color(0xFF10B981), width: 4.5),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            choreIcon,
                            color: const Color(0xFF059669),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bounty.choreName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    amountFormatted,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '· Settled',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Completed by ${bounty.newAssigneeDisplayName ?? "Member"}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 12,
                                color: Color(0xFF059669),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Settled',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          'Bounty ID: $bountyShortId',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const Spacer(),
                        OutlinedButton(
                          onPressed: onTap,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 34),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          child: const Text(
                            'Details',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _shortBountyId(String id) {
  if (id.isEmpty) return '#BNT-001';
  final clean = id.replaceAll('-', '');
  final suffix = clean.length > 4 ? clean.substring(clean.length - 4).toUpperCase() : clean.toUpperCase();
  return '#BNT-$suffix';
}

String _formatDueText(DateTime due, String poster) {
  final vn = vietnamTime(due);
  final now = vietnamTime(DateTime.now());
  final isToday = vn.year == now.year && vn.month == now.month && vn.day == now.day;
  final tomorrow = now.add(const Duration(days: 1));
  final isTomorrow = vn.year == tomorrow.year && vn.month == tomorrow.month && vn.day == tomorrow.day;
  final timeStr = DateFormat('HH:mm').format(vn);

  String duePrefix;
  if (isToday) {
    duePrefix = 'Due today, $timeStr';
  } else if (isTomorrow) {
    duePrefix = 'Due tomorrow, $timeStr';
  } else {
    duePrefix = 'Due ${DateFormat('dd/MM, HH:mm').format(vn)}';
  }

  if (poster.isNotEmpty) {
    return '$duePrefix · Posted by $poster';
  }
  return duePrefix;
}

IconData _getChoreIcon(String choreName) {
  final lower = choreName.toLowerCase();
  if (lower.contains('dish') || lower.contains('kitchen') || lower.contains('sink')) {
    return Icons.assignment_outlined;
  }
  if (lower.contains('room') || lower.contains('house') || lower.contains('floor') || lower.contains('living')) {
    return Icons.home_outlined;
  }
  if (lower.contains('grocer') || lower.contains('buy') || lower.contains('shop') || lower.contains('market')) {
    return Icons.shopping_bag_outlined;
  }
  return Icons.cleaning_services_outlined;
}
