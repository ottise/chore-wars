import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../ai/presentation/ai_insights_screen.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../payment/domain/entities/payment_obligation.dart';
import '../../../payment/presentation/providers/payment_providers.dart';
import '../../domain/entities/bounty.dart';
import '../providers/bounty_providers.dart';

class BountyBoardScreen extends ConsumerStatefulWidget {
  final String? houseId;

  const BountyBoardScreen({super.key, required this.houseId});

  @override
  ConsumerState<BountyBoardScreen> createState() => _BountyBoardScreenState();
}

class _BountyBoardScreenState extends ConsumerState<BountyBoardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openCreateBounty(BuildContext context) async {
    final houseId = widget.houseId;
    if (houseId == null || houseId.isEmpty) return;

    try {
      final profile = await ref.read(userProfileProvider.future);
      final dio = ref.read(dioProvider);
      final seasonResponse = await dio.get('/houses/$houseId/seasons/current');
      final season = seasonResponse.data is Map
          ? Map<String, dynamic>.from(seasonResponse.data as Map)
          : <String, dynamic>{};
      final seasonId = season['id']?.toString();
      if (seasonId == null || seasonId.isEmpty) {
        if (context.mounted) {
          showAppMessage(
            context,
            'Create a season before posting a bounty.',
            error: true,
          );
        }
        return;
      }

      final occurrencesResponse = await dio.get(
        '/houses/$houseId/seasons/$seasonId/occurrences',
      );
      final occurrences = occurrencesResponse.data is List
          ? (occurrencesResponse.data as List)
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .where(
                  (item) =>
                      item['assignedUserId']?.toString().toLowerCase() ==
                          profile.id.toLowerCase() &&
                      [
                        'ASSIGNED',
                        'OVERDUE',
                        'CRITICAL_OVERDUE',
                        '0',
                        '2',
                        '3',
                      ].contains(item['status']?.toString().toUpperCase()),
                )
                .toList()
          : <Map<String, dynamic>>[];

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
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  'Choose a chore to request help with',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: occurrences.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final occurrence = occurrences[index];
                    final dueDate = DateTime.tryParse(
                      occurrence['dueDate']?.toString() ?? '',
                    );
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppTheme.lavender,
                        child: Icon(
                          Icons.cleaning_services_outlined,
                          color: AppTheme.purple,
                        ),
                      ),
                      title: Text(
                        occurrence['choreName']?.toString() ?? 'Chore',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        dueDate == null
                            ? 'No deadline'
                            : 'Due: ${DateFormat('dd/MM HH:mm').format(dueDate.toLocal())}',
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_outlined,
                        size: 16,
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

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final currency = NumberFormat.currency(
          locale: 'en_US',
          symbol: '₫',
          decimalDigits: 0,
        );
        return AlertDialog(
          title: const Text('Accept This Bounty?'),
          content: Text(
            'Do you agree to complete "${bounty.choreName}" on behalf of ${bounty.postedByDisplayName}?\n\n'
            'Reward: ${currency.format(bounty.amount)}\n'
            'Deadline: ${DateFormat('dd/MM HH:mm').format(bounty.expiresAt)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm Acceptance'),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    try {
      await ref
          .read(bountyRepositoryProvider)
          .acceptBounty(houseId: houseId, bountyId: bounty.id);
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
    }
  }

  Future<void> _handleSettlePayment(PaymentObligation payment) async {
    final houseId = widget.houseId;
    if (houseId == null || houseId.isEmpty) return;

    final currency = NumberFormat.currency(
      locale: 'en_US',
      symbol: '₫',
      decimalDigits: 0,
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment Received?'),
        content: Text(
          'Confirm the payment of ${currency.format(payment.amount)} between '
          '${payment.debtorDisplayName} and ${payment.creditorDisplayName} has been settled?\n\n'
          '(Only the recipient should confirm after receiving the money; this is a manual confirmation.)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Paid'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await ref
          .read(paymentRepositoryProvider)
          .settlePayment(houseId: houseId, paymentId: payment.id);
      ref.invalidate(paymentListProvider(houseId));
      ref.invalidate(bountyBoardProvider(houseId));
      if (mounted) {
        showAppMessage(context, 'Payment updated successfully.');
      }
    } catch (e) {
      if (mounted) {
        showAppMessage(context, apiErrorMessage(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final houseId = widget.houseId;
    if (houseId == null || houseId.isEmpty) {
      return const Scaffold(
        body: EmptyState(message: 'Choose a house to view bounties.'),
      );
    }

    final bountiesAsync = ref.watch(bountyBoardProvider(houseId));
    final paymentsAsync = ref.watch(paymentListProvider(houseId));
    final currentUser = ref.watch(userProfileProvider).value;
    final myUserId = currentUser?.id.toLowerCase() ?? '';

    final pendingDebtsCount =
        paymentsAsync.asData?.value
            .where((p) => p.status == PaymentStatus.pending)
            .length ??
        0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bounties & Payments'),
        actions: [
          if (widget.houseId != null)
            IconButton(
              tooltip: 'Optional Bounty Suggestions',
              icon: const Icon(Icons.auto_awesome_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      AiInsightsScreen(houseId: widget.houseId!),
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelPadding: const EdgeInsets.symmetric(horizontal: 14),
          indicatorColor: AppTheme.purple,
          tabs: [
            const Tab(
              text: 'Available',
              icon: Icon(Icons.explore_outlined, size: 20),
            ),
            const Tab(
              text: 'Posted by Me',
              icon: Icon(Icons.outbox_outlined, size: 20),
            ),
            const Tab(
              text: 'Accepted by Me',
              icon: Icon(Icons.handshake_outlined, size: 20),
            ),
            Tab(
              icon: Badge(
                isLabelVisible: pendingDebtsCount > 0,
                label: Text('$pendingDebtsCount'),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 20,
                ),
              ),
              text: 'Payments',
            ),
            const Tab(
              text: 'History',
              icon: Icon(Icons.history_outlined, size: 20),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Available Bounties
          _buildAvailableTab(bountiesAsync, myUserId, houseId),

          // Tab 2: My Posted Bounties
          _buildMyPostedTab(bountiesAsync, myUserId, houseId),

          // Tab 3: My Accepted Bounties
          _buildMyAcceptedTab(
            bountiesAsync,
            myUserId,
            currentUser?.displayName ?? '',
            houseId,
          ),

          // Tab 4: Outstanding Debts
          _buildDebtsTab(paymentsAsync, myUserId, houseId),

          // Tab 5: Payment & Compensation History
          _buildHistoryTab(paymentsAsync, houseId),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'bounty-fab',
        onPressed: () => _openCreateBounty(context),
        icon: const Icon(Icons.add_outlined),
        label: const Text('Post Bounty'),
        backgroundColor: AppTheme.purple,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildAvailableTab(
    AsyncValue<List<Bounty>> bountiesAsync,
    String myUserId,
    String houseId,
  ) {
    return bountiesAsync.when(
      loading: () => const LoadingWidget(),
      error: (error, _) => ErrorState(
        error: error,
        onRetry: () => ref.invalidate(bountyBoardProvider(houseId)),
      ),
      data: (items) {
        final available = items
            .where((b) => b.status == BountyStatus.open)
            .toList();
        if (available.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.volunteer_activism_outlined,
                    size: 64,
                    color: AppTheme.muted,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Available Bounties',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Need help with a chore?\nPost a bounty to offer a cash reward.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.muted, height: 1.4),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(bountyBoardProvider(houseId).future),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 88),
            itemCount: available.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final bounty = available[index];
              final isMine = bounty.postedByUserId.toLowerCase() == myUserId;
              return _AvailableBountyCard(
                bounty: bounty,
                isMine: isMine,
                onAccept: () => _handleAcceptBounty(bounty),
                onTap: () => context.push(
                  '/bounties/${bounty.id}?houseId=${Uri.encodeComponent(houseId)}',
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMyPostedTab(
    AsyncValue<List<Bounty>> bountiesAsync,
    String myUserId,
    String houseId,
  ) {
    return bountiesAsync.when(
      loading: () => const LoadingWidget(),
      error: (error, _) => ErrorState(
        error: error,
        onRetry: () => ref.invalidate(bountyBoardProvider(houseId)),
      ),
      data: (items) {
        final posted = items
            .where((b) => b.postedByUserId.toLowerCase() == myUserId)
            .toList();

        if (posted.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.outbox_outlined,
                    size: 64,
                    color: AppTheme.muted,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'You Have Not Posted Any Bounties',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Post a bounty to offer a cash reward for a housemate to complete your chore.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.muted, height: 1.4),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(bountyBoardProvider(houseId).future),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 88),
            itemCount: posted.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _MyPostedBountyCard(
              bounty: posted[index],
              onTap: () => context.push(
                '/bounties/${posted[index].id}?houseId=${Uri.encodeComponent(houseId)}',
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMyAcceptedTab(
    AsyncValue<List<Bounty>> bountiesAsync,
    String myUserId,
    String myDisplayName,
    String houseId,
  ) {
    return bountiesAsync.when(
      loading: () => const LoadingWidget(),
      error: (error, _) => ErrorState(
        error: error,
        onRetry: () => ref.invalidate(bountyBoardProvider(houseId)),
      ),
      data: (items) {
        final accepted = items.where((b) {
          final isAssignedToMe =
              (b.assignedUserId != null &&
                  b.assignedUserId!.toLowerCase() == myUserId) ||
              (b.newAssigneeDisplayName != null &&
                  b.newAssigneeDisplayName == myDisplayName);
          final isNotMyPost = b.postedByUserId.toLowerCase() != myUserId;
          return isAssignedToMe && isNotMyPost;
        }).toList();

        if (accepted.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.handshake_outlined,
                    size: 64,
                    color: AppTheme.muted,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'You Have Not Accepted Any Bounties',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Open the "Available" tab to accept a chore and earn a cash reward.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.muted, height: 1.4),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(bountyBoardProvider(houseId).future),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 88),
            itemCount: accepted.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _MyAcceptedBountyCard(
              bounty: accepted[index],
              houseId: houseId,
              onTap: () => context.push(
                '/bounties/${accepted[index].id}?houseId=${Uri.encodeComponent(houseId)}',
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDebtsTab(
    AsyncValue<List<PaymentObligation>> paymentsAsync,
    String myUserId,
    String houseId,
  ) {
    return paymentsAsync.when(
      loading: () => const LoadingWidget(),
      error: (error, _) => ErrorState(
        error: error,
        onRetry: () => ref.invalidate(paymentListProvider(houseId)),
      ),
      data: (items) {
        final pending = items
            .where((p) => p.status == PaymentStatus.pending)
            .toList();

        final currency = NumberFormat.currency(
          locale: 'en_US',
          symbol: '₫',
          decimalDigits: 0,
        );

        double totalMustPay = 0;
        double totalToReceive = 0;
        for (final p in pending) {
          if (p.debtorUserId.toLowerCase() == myUserId) {
            totalMustPay += p.amount;
          } else if (p.creditorUserId.toLowerCase() == myUserId) {
            totalToReceive += p.amount;
          }
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(paymentListProvider(houseId).future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 88),
            children: [
              // Summary cards
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.red.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.arrow_upward_outlined,
                                size: 16,
                                color: AppTheme.red,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'You Owe',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            currency.format(totalMustPay),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.green.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.arrow_downward_outlined,
                                size: 16,
                                color: AppTheme.green,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'You Are Owed',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            currency.format(totalToReceive),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.purple.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppTheme.purple,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Settle payments directly in cash or by transfer, then select "Paid" to confirm.',
                        style: TextStyle(fontSize: 12, color: AppTheme.purple),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (pending.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 56,
                          color: AppTheme.green,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No Outstanding Payments',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'All household payments have been settled.',
                          style: TextStyle(color: AppTheme.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...pending.map((p) {
                  final isDebtor = p.debtorUserId.toLowerCase() == myUserId;
                  final isCreditor = p.creditorUserId.toLowerCase() == myUserId;
                  final canSettle = isCreditor;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DebtCard(
                      payment: p,
                      isDebtor: isDebtor,
                      isCreditor: isCreditor,
                      canSettle: canSettle,
                      onSettle: () => _handleSettlePayment(p),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab(
    AsyncValue<List<PaymentObligation>> paymentsAsync,
    String houseId,
  ) {
    return paymentsAsync.when(
      loading: () => const LoadingWidget(),
      error: (error, _) => ErrorState(
        error: error,
        onRetry: () => ref.invalidate(paymentListProvider(houseId)),
      ),
      data: (items) {
        final history = items
            .where((p) => p.status == PaymentStatus.paid)
            .toList();

        if (history.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_outlined, size: 64, color: AppTheme.muted),
                  SizedBox(height: 16),
                  Text(
                    'No Payment History Yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Completed bounty payments and compensation appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.muted, height: 1.4),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(paymentListProvider(houseId).future),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 88),
            itemCount: history.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _PaymentHistoryCard(payment: history[index]),
          ),
        );
      },
    );
  }
}

class _AvailableBountyCard extends StatelessWidget {
  final Bounty bounty;
  final bool isMine;
  final VoidCallback onAccept;
  final VoidCallback onTap;

  const _AvailableBountyCard({
    required this.bounty,
    required this.isMine,
    required this.onAccept,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_US',
      symbol: '₫',
      decimalDigits: 0,
    );
    final date = DateFormat('dd/MM HH:mm').format(bounty.expiresAt);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.outline.withValues(alpha: 0.15)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.volunteer_activism_outlined,
                      color: AppTheme.purple,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bounty.choreName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Posted by: ${bounty.postedByDisplayName}${isMine ? " (You)" : ""}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.amberContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      currency.format(bounty.amount),
                      style: const TextStyle(
                        color: AppTheme.onAmber,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.alarm_outlined,
                    size: 16,
                    color: AppTheme.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Due: $date',
                    style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (isMine)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onTap,
                    child: const Text('Your Bounty (View Details)'),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.handshake_outlined, size: 18),
                    label: const Text('Accept Bounty'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.purple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyPostedBountyCard extends StatelessWidget {
  final Bounty bounty;
  final VoidCallback onTap;

  const _MyPostedBountyCard({required this.bounty, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_US',
      symbol: '₫',
      decimalDigits: 0,
    );
    final date = DateFormat('dd/MM HH:mm').format(bounty.expiresAt);

    Color statusColor;
    String statusText;
    switch (bounty.status) {
      case BountyStatus.open:
        statusColor = AppTheme.orange;
        statusText = 'Awaiting Acceptance';
        break;
      case BountyStatus.claimed:
        statusColor = AppTheme.purple;
        statusText =
            'Accepted by: ${bounty.newAssigneeDisplayName ?? "Member"}';
        break;
      case BountyStatus.completed:
        statusColor = AppTheme.green;
        statusText = 'Completed (Payment Due)';
        break;
      case BountyStatus.expired:
        statusColor = AppTheme.orange;
        statusText = 'Expired (Forced Assignment at 120%)';
        break;
      case BountyStatus.cancelled:
        statusColor = AppTheme.outline;
        statusText = 'Cancelled';
        break;
      default:
        statusColor = AppTheme.outline;
        statusText = 'Unknown';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.outline.withValues(alpha: 0.15)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      bounty.choreName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    currency.format(bounty.amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppTheme.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (bounty.status == BountyStatus.expired &&
                  bounty.forcedCompensationAmount != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Forced Compensation (120%): ${currency.format(bounty.forcedCompensationAmount)}',
                    style: const TextStyle(
                      color: AppTheme.orange,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_outlined,
                    size: 14,
                    color: AppTheme.muted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Deadline: $date',
                    style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyAcceptedBountyCard extends StatelessWidget {
  final Bounty bounty;
  final String houseId;
  final VoidCallback onTap;

  const _MyAcceptedBountyCard({
    required this.bounty,
    required this.houseId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_US',
      symbol: '₫',
      decimalDigits: 0,
    );
    final date = DateFormat('dd/MM HH:mm').format(bounty.expiresAt);

    Color statusColor;
    String statusText;
    switch (bounty.status) {
      case BountyStatus.claimed:
        statusColor = AppTheme.purple;
        statusText = 'In Progress';
        break;
      case BountyStatus.completed:
        statusColor = AppTheme.green;
        statusText = 'Completed! Awaiting Payment';
        break;
      case BountyStatus.expired:
        statusColor = AppTheme.orange;
        statusText = 'Overdue';
        break;
      default:
        statusColor = AppTheme.outline;
        statusText = 'Accepted';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.outline.withValues(alpha: 0.15)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      bounty.choreName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '+${currency.format(bounty.amount)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppTheme.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Posted by: ${bounty.postedByDisplayName}',
                style: const TextStyle(fontSize: 13, color: AppTheme.muted),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_outlined,
                    size: 14,
                    color: AppTheme.muted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Deadline: $date',
                    style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                  ),
                ],
              ),
              if (bounty.status == BountyStatus.claimed) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () => context.push(
                      '/chores/${bounty.choreOccurrenceId}?houseId=${Uri.encodeComponent(houseId)}',
                    ),
                    icon: const Icon(Icons.camera_alt_outlined, size: 16),
                    label: const Text('Open Chore & Add Photo Evidence'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  final PaymentObligation payment;
  final bool isDebtor;
  final bool isCreditor;
  final bool canSettle;
  final VoidCallback onSettle;

  const _DebtCard({
    required this.payment,
    required this.isDebtor,
    required this.isCreditor,
    required this.canSettle,
    required this.onSettle,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_US',
      symbol: '₫',
      decimalDigits: 0,
    );
    final date = DateFormat('dd/MM/yyyy HH:mm').format(payment.createdAt);

    String title;
    String badge;
    Color badgeColor;

    if (isDebtor) {
      title = 'You owe ${payment.creditorDisplayName}';
      badge = 'You Owe';
      badgeColor = AppTheme.red;
    } else if (isCreditor) {
      title = '${payment.debtorDisplayName} owes you';
      badge = 'Awaiting Receipt';
      badgeColor = AppTheme.green;
    } else {
      title = '${payment.debtorDisplayName} → ${payment.creditorDisplayName}';
      badge = 'Member Payment';
      badgeColor = AppTheme.outline;
    }

    String reasonText;
    switch (payment.reason) {
      case PaymentReason.bountyPayment:
        reasonText = 'Bounty Payment';
        break;
      case PaymentReason.forcedReassignment:
        reasonText = 'Forced Compensation (120% for Expiry)';
        break;
      case PaymentReason.penalty:
        reasonText = 'Overdue Penalty';
        break;
      default:
        reasonText = 'Payment Obligation';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.outline.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reasonText,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              payment.reason == PaymentReason.forcedReassignment
                              ? AppTheme.orange
                              : AppTheme.muted,
                        ),
                      ),
                      if (payment.choreName != null &&
                          payment.choreName!.isNotEmpty)
                        Text(
                          'Chore: ${payment.choreName}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.purple,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currency.format(payment.amount),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDebtor
                            ? AppTheme.red
                            : (isCreditor ? AppTheme.green : AppTheme.ink),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 13,
                  color: AppTheme.muted,
                ),
                const SizedBox(width: 4),
                Text(
                  'Created: $date',
                  style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
                const Spacer(),
                if (canSettle)
                  FilledButton.icon(
                    onPressed: onSettle,
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Paid'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      backgroundColor: AppTheme.green,
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentHistoryCard extends StatelessWidget {
  final PaymentObligation payment;

  const _PaymentHistoryCard({required this.payment});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_US',
      symbol: '₫',
      decimalDigits: 0,
    );

    final completedDate = payment.paidAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(payment.paidAt!)
        : DateFormat('dd/MM/yyyy HH:mm').format(payment.createdAt);

    String reasonText;
    switch (payment.reason) {
      case PaymentReason.bountyPayment:
        reasonText = 'Bounty Payment';
        break;
      case PaymentReason.forcedReassignment:
        reasonText = 'Expiry Compensation (120%)';
        break;
      default:
        reasonText = 'Payment';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.outline.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.green.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outlined,
                color: AppTheme.green,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${payment.debtorDisplayName} → ${payment.creditorDisplayName}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reasonText,
                    style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                  ),
                  if (payment.choreName != null &&
                      payment.choreName!.isNotEmpty)
                    Text(
                      'Chore: ${payment.choreName}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.purple,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Completed: $completedDate',
                    style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                  ),
                ],
              ),
            ),
            Text(
              currency.format(payment.amount),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
