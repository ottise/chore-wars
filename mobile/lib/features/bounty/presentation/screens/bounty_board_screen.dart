import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
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
            'Hãy tạo mùa giải (Season) trước khi đăng Bounty.',
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
                .where((item) => item['status']?.toString() != 'COMPLETED')
                .toList()
          : <Map<String, dynamic>>[];

      if (!context.mounted) return;
      if (occurrences.isEmpty) {
        showAppMessage(
          context,
          'Không có công việc nào khả dụng để tạo Bounty.',
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
                  'Chọn việc nhà bạn muốn nhờ làm thay',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: occurrences.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final occurrence = occurrences[index];
                    final dueDate = DateTime.tryParse(
                      occurrence['dueDate']?.toString() ?? '',
                    );
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFF3E8FF),
                        child: Icon(Icons.cleaning_services_rounded, color: AppTheme.purple),
                      ),
                      title: Text(
                        occurrence['choreName']?.toString() ?? 'Chore',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        dueDate == null
                            ? 'Chưa có hạn'
                            : 'Hạn: ${DateFormat('dd/MM HH:mm').format(dueDate.toLocal())}',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
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
          locale: 'vi_VN',
          symbol: 'đ',
          decimalDigits: 0,
        );
        return AlertDialog(
          title: const Text('Nhận Bounty này?'),
          content: Text(
            'Bạn đồng ý nhận làm "${bounty.choreName}" thay cho ${bounty.postedByDisplayName}?\n\n'
            'Phần thưởng: ${currency.format(bounty.amount)}\n'
            'Hạn chót: ${DateFormat('dd/MM HH:mm').format(bounty.expiresAt)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xác nhận nhận việc'),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    try {
      await ref.read(bountyRepositoryProvider).acceptBounty(
            houseId: houseId,
            bountyId: bounty.id,
          );
      ref.invalidate(bountyBoardProvider(houseId));
      if (mounted) {
        showAppMessage(context, 'Đã nhận Bounty thành công! Hãy hoàn thành đúng hạn nhé.');
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
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận thanh toán?'),
        content: Text(
          'Xác nhận khoản tiền ${currency.format(payment.amount)} giữa '
          '${payment.debtorDisplayName} và ${payment.creditorDisplayName} đã được thanh toán xong?\n\n'
          '(Hệ thống sẽ cập nhật trạng thái khoản nợ này thành Đã thanh toán).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đã thanh toán'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await ref.read(paymentRepositoryProvider).settlePayment(
            houseId: houseId,
            paymentId: payment.id,
          );
      ref.invalidate(paymentListProvider(houseId));
      ref.invalidate(bountyBoardProvider(houseId));
      if (mounted) {
        showAppMessage(context, 'Đã cập nhật thanh toán thành công!');
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
        body: EmptyState(message: 'Vui lòng chọn một ngôi nhà để xem Bounty.'),
      );
    }

    final bountiesAsync = ref.watch(bountyBoardProvider(houseId));
    final paymentsAsync = ref.watch(paymentListProvider(houseId));
    final currentUser = ref.watch(userProfileProvider).value;
    final myUserId = currentUser?.id.toLowerCase() ?? '';

    final pendingDebtsCount = paymentsAsync.asData?.value
            .where((p) => p.status == PaymentStatus.pending)
            .length ??
        0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bounties & Công nợ'),
        actions: [
          IconButton(
            tooltip: 'Tạo Bounty mới',
            onPressed: () => _openCreateBounty(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelPadding: const EdgeInsets.symmetric(horizontal: 14),
          indicatorColor: AppTheme.purple,
          tabs: [
            const Tab(text: 'Chờ nhận', icon: Icon(Icons.explore_outlined, size: 20)),
            const Tab(text: 'Tôi đăng', icon: Icon(Icons.outbox_rounded, size: 20)),
            const Tab(text: 'Tôi nhận', icon: Icon(Icons.handshake_outlined, size: 20)),
            Tab(
              icon: Badge(
                isLabelVisible: pendingDebtsCount > 0,
                label: Text('$pendingDebtsCount'),
                child: const Icon(Icons.account_balance_wallet_outlined, size: 20),
              ),
              text: 'Công nợ',
            ),
            const Tab(text: 'Lịch sử', icon: Icon(Icons.history_rounded, size: 20)),
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
          _buildMyAcceptedTab(bountiesAsync, myUserId, currentUser?.displayName ?? '', houseId),

          // Tab 4: Outstanding Debts
          _buildDebtsTab(paymentsAsync, myUserId, houseId),

          // Tab 5: Payment & Compensation History
          _buildHistoryTab(paymentsAsync, houseId),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'bounty-fab',
        onPressed: () => _openCreateBounty(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tạo Bounty'),
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
        final available = items.where((b) => b.status == BountyStatus.open).toList();
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
                    'Chưa có Bounty nào đang chờ nhận',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bạn bận rộn hoặc muốn nhờ người làm thay?\nHãy bấm nút Tạo Bounty để đăng việc có thưởng!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.muted, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _openCreateBounty(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Tạo Bounty mới'),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(bountyBoardProvider(houseId).future),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
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
                    Icons.outbox_rounded,
                    size: 64,
                    color: AppTheme.muted,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Bạn chưa đăng Bounty nào',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Đăng Bounty khi bạn muốn nhờ bạn cùng nhà làm việc thay mình với mức thưởng tiền mặt.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.muted, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _openCreateBounty(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Tạo Bounty ngay'),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(bountyBoardProvider(houseId).future),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
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
          final isAssignedToMe = (b.assignedUserId != null &&
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
                    'Bạn chưa nhận làm Bounty nào',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Hãy chuyển sang tab "Chờ nhận" để nhận việc nhà từ bạn cùng phòng và nhận tiền thưởng!',
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
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
        final pending = items.where((p) => p.status == PaymentStatus.pending).toList();

        final currency = NumberFormat.currency(
          locale: 'vi_VN',
          symbol: 'đ',
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            children: [
              // Summary cards
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.arrow_upward_rounded, size: 16, color: Colors.red),
                              SizedBox(width: 4),
                              Text(
                                'Bạn cần trả',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            currency.format(totalMustPay),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
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
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.arrow_downward_rounded, size: 16, color: Colors.green),
                              SizedBox(width: 4),
                              Text(
                                'Bạn chờ nhận',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            currency.format(totalToReceive),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.purple.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.purple),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Các bên tự thanh toán tiền mặt/chuyển khoản, sau đó bấm "Đã thanh toán" để xác nhận.',
                        style: TextStyle(fontSize: 11, color: AppTheme.purple),
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
                        Icon(Icons.check_circle_outline_rounded, size: 56, color: Colors.green),
                        SizedBox(height: 12),
                        Text(
                          'Không có công nợ nào còn thiếu!',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Mọi khoản thanh toán trong nhà đã được xử lý xong.',
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
                  final canSettle = isDebtor || isCreditor;

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
        final history = items.where((p) => p.status == PaymentStatus.paid).toList();

        if (history.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 64,
                    color: AppTheme.muted,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Chưa có lịch sử thanh toán nào',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Các khoản thù lao bounty và tiền bồi thường đã hoàn tất sẽ hiển thị ở đây.',
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: history.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _PaymentHistoryCard(payment: history[index]),
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
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );
    final date = DateFormat('dd/MM HH:mm').format(bounty.expiresAt);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
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
                      Icons.volunteer_activism_rounded,
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
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Đăng bởi: ${bounty.postedByDisplayName}${isMine ? " (Bạn)" : ""}',
                          style: const TextStyle(fontSize: 13, color: AppTheme.muted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      currency.format(bounty.amount),
                      style: const TextStyle(
                        color: Color(0xFFB45309),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.alarm_rounded, size: 16, color: AppTheme.muted),
                  const SizedBox(width: 6),
                  Text(
                    'Hạn hoàn thành: $date',
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
                    child: const Text('Bounty do bạn đăng (Xem chi tiết)'),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.handshake_rounded, size: 18),
                    label: const Text('Nhận làm Bounty này'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.purple,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );
    final date = DateFormat('dd/MM HH:mm').format(bounty.expiresAt);

    Color statusColor;
    String statusText;
    switch (bounty.status) {
      case BountyStatus.open:
        statusColor = Colors.amber;
        statusText = 'Đang chờ người nhận';
        break;
      case BountyStatus.claimed:
        statusColor = Colors.blue;
        statusText = 'Đã có người nhận: ${bounty.newAssigneeDisplayName ?? "Thành viên"}';
        break;
      case BountyStatus.completed:
        statusColor = Colors.green;
        statusText = 'Đã làm xong (Cần thanh toán)';
        break;
      case BountyStatus.expired:
        statusColor = Colors.deepOrange;
        statusText = 'Hết hạn (Gán cưỡng chế đền 120%)';
        break;
      case BountyStatus.cancelled:
        statusColor = Colors.grey;
        statusText = 'Đã hủy';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Không xác định';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
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
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    currency.format(bounty.amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    'Đền bù cưỡng chế (120%): ${currency.format(bounty.forcedCompensationAmount)}',
                    style: const TextStyle(
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 14, color: AppTheme.muted),
                  const SizedBox(width: 4),
                  Text(
                    'Hạn chót: $date',
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
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );
    final date = DateFormat('dd/MM HH:mm').format(bounty.expiresAt);

    Color statusColor;
    String statusText;
    switch (bounty.status) {
      case BountyStatus.claimed:
        statusColor = Colors.blue;
        statusText = 'Đang làm (Chưa hoàn thành)';
        break;
      case BountyStatus.completed:
        statusColor = Colors.green;
        statusText = 'Đã hoàn thành! Đang chờ thanh toán';
        break;
      case BountyStatus.expired:
        statusColor = Colors.deepOrange;
        statusText = 'Quá hạn';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Đã nhận';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
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
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    '+${currency.format(bounty.amount)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Người giao việc: ${bounty.postedByDisplayName}',
                style: const TextStyle(fontSize: 13, color: AppTheme.muted),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  const Icon(Icons.schedule_rounded, size: 14, color: AppTheme.muted),
                  const SizedBox(width: 4),
                  Text(
                    'Hạn chót: $date',
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
                    label: const Text('Làm việc & Chụp ảnh hoàn thành'),
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
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );
    final date = DateFormat('dd/MM/yyyy HH:mm').format(payment.createdAt);

    String title;
    String badge;
    Color badgeColor;

    if (isDebtor) {
      title = 'Bạn phải trả cho ${payment.creditorDisplayName}';
      badge = 'Nợ của bạn';
      badgeColor = Colors.red;
    } else if (isCreditor) {
      title = '${payment.debtorDisplayName} nợ bạn';
      badge = 'Chờ bạn nhận';
      badgeColor = Colors.green;
    } else {
      title = '${payment.debtorDisplayName} → ${payment.creditorDisplayName}';
      badge = 'Công nợ thành viên';
      badgeColor = Colors.grey;
    }

    String reasonText;
    switch (payment.reason) {
      case PaymentReason.bountyPayment:
        reasonText = 'Thù lao làm thay Bounty';
        break;
      case PaymentReason.forcedReassignment:
        reasonText = 'Bồi thường cưỡng chế (120% do quá hạn)';
        break;
      case PaymentReason.penalty:
        reasonText = 'Khoản phạt quá hạn';
        break;
      default:
        reasonText = 'Khoản nghĩa vụ thanh toán';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
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
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reasonText,
                        style: TextStyle(fontSize: 12, color: payment.reason == PaymentReason.forcedReassignment ? Colors.deepOrange : AppTheme.muted),
                      ),
                      if (payment.choreName != null && payment.choreName!.isNotEmpty)
                        Text(
                          'Việc: ${payment.choreName}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.purple),
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
                        fontWeight: FontWeight.bold,
                        color: isDebtor ? Colors.red : (isCreditor ? Colors.green : Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 11,
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
                const Icon(Icons.calendar_today_rounded, size: 13, color: AppTheme.muted),
                const SizedBox(width: 4),
                Text(
                  'Tạo lúc: $date',
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                ),
                const Spacer(),
                if (canSettle)
                  FilledButton.icon(
                    onPressed: onSettle,
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Đã thanh toán'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      backgroundColor: Colors.teal,
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
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );

    final completedDate = payment.paidAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(payment.paidAt!)
        : DateFormat('dd/MM/yyyy HH:mm').format(payment.createdAt);

    String reasonText;
    switch (payment.reason) {
      case PaymentReason.bountyPayment:
        reasonText = 'Thù lao Bounty';
        break;
      case PaymentReason.forcedReassignment:
        reasonText = 'Bồi thường quá hạn (120%)';
        break;
      default:
        reasonText = 'Thanh toán';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${payment.debtorDisplayName} → ${payment.creditorDisplayName}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reasonText,
                    style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                  ),
                  if (payment.choreName != null && payment.choreName!.isNotEmpty)
                    Text(
                      'Việc: ${payment.choreName}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.purple),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Hoàn tất: $completedDate',
                    style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                  ),
                ],
              ),
            ),
            Text(
              currency.format(payment.amount),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
