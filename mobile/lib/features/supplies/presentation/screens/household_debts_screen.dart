import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/api_error_message.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/repositories/supplies_repository.dart';
import '../providers/supplies_providers.dart';
import '../widgets/supplies_ui.dart';
import '../widgets/debt_action_sheet.dart';
import '../../../payment/presentation/providers/payment_history_provider.dart';
import '../../../house/presentation/providers/household_summary_provider.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';

final purchaseDebtProvider = FutureProvider.autoDispose
    .family<SupplyData, ({String house, String id})>(
      (ref, key) => ref
          .watch(suppliesRepositoryProvider)
          .get('/houses/${key.house}/me/debts/${key.id}'),
    );
final repaymentInstructionsProvider = FutureProvider.autoDispose
    .family<SupplyData, String>(
      (ref, id) => ref
          .watch(suppliesRepositoryProvider)
          .get('/payment-obligations/$id/instructions'),
    );

enum DebtFilter { all, owe, owedToMe }

class HouseholdDebtsScreen extends ConsumerStatefulWidget {
  const HouseholdDebtsScreen({required this.houseId, super.key});
  final String houseId;

  @override
  ConsumerState<HouseholdDebtsScreen> createState() =>
      _HouseholdDebtsScreenState();
}

class _HouseholdDebtsScreenState extends ConsumerState<HouseholdDebtsScreen> {
  DebtFilter _filter = DebtFilter.all;

  Future<void> _actions(List<Map> debts, String? me) async {
    if (debts.isEmpty) return;
    final debt = debts.first;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DebtActionSheet(
        houseId: widget.houseId,
        debt: Map<String, dynamic>.from(debt),
        debts: debts.map((d) => Map<String, dynamic>.from(d)).toList(),
        debtor: debt['debtorUserId'] == me,
      ),
    );
    ref.invalidate(
      purchaseDebtProvider((
        house: widget.houseId,
        id: debt['id'].toString(),
      )),
    );
    ref.invalidate(purchaseDebtsProvider(widget.houseId));
    ref.invalidate(householdSummaryProvider);
    ref.invalidate(paymentHistoryProvider);
    if (mounted) {
      if (changed == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              debt['debtorUserId'] == me
                  ? 'Đã gửi thông báo thanh toán. Chờ người nhận xác nhận!'
                  : 'Đã xác nhận thanh toán thành công!',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      await ref.read(purchaseDebtsProvider(widget.houseId).future);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      notificationNotifierProvider.select((state) => state.latestArrival),
      (previous, next) {
        if (next != null && next.houseId == widget.houseId) {
          ref.invalidate(purchaseDebtsProvider(widget.houseId));
          ref.invalidate(householdSummaryProvider);
          ref.invalidate(paymentHistoryProvider);
        }
      },
    );
    final me = ref.watch(userProfileProvider).asData?.value.id;
    if (me == null) {
      return SuppliesPage(
        title: 'My Debts',
        child: ref
            .watch(userProfileProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  SupplyFailure(e, () => ref.invalidate(userProfileProvider)),
              data: (_) =>
                  const Center(child: Text('Sign in to view your finances.')),
            ),
      );
    }

    return SuppliesPage(
      title: 'My Debts',
      actions: [
        IconButton(
          tooltip: 'Receiving bank account',
          onPressed: () => context.push('/bank-accounts'),
          icon: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(
              Icons.account_balance_outlined,
              size: 17,
              color: Color(0xFF475569),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
      child: ref.watch(purchaseDebtsProvider(widget.houseId)).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => SupplyFailure(
          e,
          () => ref.invalidate(purchaseDebtsProvider(widget.houseId)),
        ),
        data: (summary) {
          final oweTotal = summary['owe'] as num? ?? 0;
          final owedToMeTotal = summary['owedToMe'] as num? ?? 0;
          final net = owedToMeTotal - oweTotal;

          final allDebts =
              (summary['debts'] as List? ?? []).cast<Map>().toList();
          final activeDebts = allDebts
              .where((d) => (d['remainingAmount'] as num? ?? 0) > 0)
              .toList();
          final oweDebts =
              activeDebts.where((d) => d['debtorUserId'] == me).toList();
          final owedToMeDebts =
              activeDebts.where((d) => d['debtorUserId'] != me).toList();

          final Map<String, List<Map>> oweByCreditor = {};
          for (final d in oweDebts) {
            final key = d['creditorUserId']?.toString() ??
                d['creditorName']?.toString() ??
                '';
            oweByCreditor.putIfAbsent(key, () => []).add(d);
          }

          final Map<String, List<Map>> owedByDebtor = {};
          for (final d in owedToMeDebts) {
            final key = d['debtorUserId']?.toString() ??
                d['debtorName']?.toString() ??
                '';
            owedByDebtor.putIfAbsent(key, () => []).add(d);
          }

          final showOwe = _filter == DebtFilter.all || _filter == DebtFilter.owe;
          final showOwedToMe =
              _filter == DebtFilter.all || _filter == DebtFilter.owedToMe;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(purchaseDebtsProvider(widget.houseId));
              await ref.read(purchaseDebtsProvider(widget.houseId).future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const Text(
                  'Instant Household Ledger',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                _buildOverallStandingCard(
                  oweTotal: oweTotal,
                  owedToMeTotal: owedToMeTotal,
                  net: net,
                  uniqueCreditorsCount: oweByCreditor.length,
                  uniqueDebtorsCount: owedByDebtor.length,
                  firstCreditorName: oweDebts.isNotEmpty
                      ? (oweDebts.first['creditorName']?.toString() ?? '')
                      : '',
                  firstDebtorName: owedToMeDebts.isNotEmpty
                      ? (owedToMeDebts.first['debtorName']?.toString() ?? '')
                      : '',
                ),
                const SizedBox(height: 8),
                _buildSegmentedFilter(
                  oweTotal: oweTotal,
                  owedToMeTotal: owedToMeTotal,
                ),
                const SizedBox(height: 8),
                if (showOwe) ...[
                  for (final entry in oweByCreditor.entries)
                    _PersonDebtCard(
                      houseId: widget.houseId,
                      isOwe: true,
                      otherName:
                          entry.value.first['creditorName']?.toString() ??
                              'Member',
                      debts: entry.value,
                      onActions: (ds) => _actions(ds, me),
                    ),
                  if (oweByCreditor.isEmpty && _filter == DebtFilter.owe)
                    const _SettledNoticeCard(
                      title: 'All Debts Settled',
                      subtitle: 'You don\'t owe anyone in this household',
                      badge: '0 VND',
                      isOwe: true,
                    ),
                ],
                if (showOwedToMe) ...[
                  for (final entry in owedByDebtor.entries)
                    _PersonDebtCard(
                      houseId: widget.houseId,
                      isOwe: false,
                      otherName:
                          entry.value.first['debtorName']?.toString() ??
                              'Member',
                      debts: entry.value,
                      onActions: (ds) => _actions(ds, me),
                    ),
                  if (owedByDebtor.isEmpty || _filter == DebtFilter.owe)
                    const _SettledNoticeCard(
                      title: 'Receivables Settled',
                      subtitle: 'No pending debts owed to you',
                      badge: '0 VND',
                      isOwe: false,
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverallStandingCard({
    required num oweTotal,
    required num owedToMeTotal,
    required num net,
    required int uniqueCreditorsCount,
    required int uniqueDebtorsCount,
    required String firstCreditorName,
    required String firstDebtorName,
  }) {
    final netText = net < 0
        ? '-${supplyMoney(net.abs())}'
        : '+${supplyMoney(net)}';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEAF6)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              const Expanded(
                child: Text(
                  'OVERALL STANDING',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: net < 0
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: net < 0
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Net: $netText',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: net < 0
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECDD3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Text(
                              'I Owe',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFBE123C),
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE4E6),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              uniqueCreditorsCount > 0
                                  ? '$uniqueCreditorsCount person'
                                  : 'All Settled',
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFBE123C),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        supplyMoney(oweTotal),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFE11D48),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        uniqueCreditorsCount > 0
                            ? 'To $firstCreditorName (Household)'
                            : 'All settled ✓',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: uniqueCreditorsCount > 0
                              ? const Color(0xFFE11D48).withValues(alpha: 0.8)
                              : const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDCFCE7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Text(
                              'Owed to Me',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF047857),
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              uniqueDebtorsCount == 0
                                  ? 'All Settled'
                                  : '$uniqueDebtorsCount pending',
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF047857),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        supplyMoney(owedToMeTotal),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF059669),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        uniqueDebtorsCount == 0
                            ? 'All clear ✓'
                            : 'From $firstDebtorName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedFilter({
    required num oweTotal,
    required num owedToMeTotal,
  }) {
    final oweActive = _filter == DebtFilter.owe;
    final owedActive = _filter == DebtFilter.owedToMe;

    return Container(
      height: 36,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: oweActive ? const Color(0xFF7C4DFF) : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => setState(() {
                  _filter = _filter == DebtFilter.owe
                      ? DebtFilter.all
                      : DebtFilter.owe;
                }),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          'I Owe',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: oweActive
                                ? Colors.white
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: oweActive
                              ? Colors.white
                              : const Color(0xFFFFE4E6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          supplyMoney(oweTotal),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: oweActive
                                ? const Color(0xFF7C4DFF)
                                : const Color(0xFFBE123C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Material(
              color: owedActive ? const Color(0xFF7C4DFF) : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => setState(() {
                  _filter = _filter == DebtFilter.owedToMe
                      ? DebtFilter.all
                      : DebtFilter.owedToMe;
                }),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          'Owed to Me',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: owedActive
                                ? Colors.white
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: owedActive
                              ? Colors.white
                              : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          supplyMoney(owedToMeTotal),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: owedActive
                                ? const Color(0xFF7C4DFF)
                                : const Color(0xFF047857),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonDebtCard extends ConsumerWidget {
  const _PersonDebtCard({
    required this.houseId,
    required this.isOwe,
    required this.otherName,
    required this.debts,
    required this.onActions,
  });

  final String houseId;
  final bool isOwe;
  final String otherName;
  final List<Map> debts;
  final void Function(List<Map> debts) onActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = debts.fold<num>(
      0,
      (sum, d) => sum + (d['remainingAmount'] as num? ?? 0),
    );
    final initial = otherName.isNotEmpty ? otherName[0].toUpperCase() : 'M';
    final primaryDebt = debts.first;
    final orderDebts = debts
        .where(
          (d) =>
              d['reason'] == 'HOUSEHOLD_PURCHASE' &&
              d['sourceOrderId'] != null &&
              (d['remainingAmount'] as num? ?? 0) > 0,
        )
        .toList();
    final confirmedRepayments = debts
        .expand((d) => (d['repayments'] as List? ?? []).cast<Map>())
        .where((r) => r['status'] == 'CONFIRMED')
        .toList();
    final reportedRepayments = debts
        .expand((d) => (d['repayments'] as List? ?? []).cast<Map>())
        .where((r) => r['status'] == 'REPORTED')
        .toList();
    final reportedTotal = reportedRepayments.fold<num>(
      0,
      (sum, r) => sum + (r['amount'] as num? ?? 0),
    );
    final isFullyReported = isOwe && reportedTotal >= total && total > 0;
    final hasAnyReported = reportedTotal > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEAF6)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isFullyReported
                    ? const Color(0xFFF59E0B)
                    : isOwe
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                width: 4,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isOwe
                            ? const Color(0xFF7C4DFF)
                            : const Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  otherName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEDE9FE),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Roommate',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF6D28D9),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          const Text(
                            'Direct VietQR settlement',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          isFullyReported
                              ? 'CHỜ XÁC NHẬN'
                              : isOwe
                                  ? 'DUE TO PAY'
                                  : 'RECEIVABLE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: isFullyReported
                                ? const Color(0xFFD97706)
                                : isOwe
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF059669),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          supplyMoney(total),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: isFullyReported
                                ? const Color(0xFFD97706)
                                : isOwe
                                    ? const Color(0xFFE11D48)
                                    : const Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isFullyReported
                            ? const Color(0xFFF59E0B)
                            : isOwe
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        isFullyReported
                            ? 'Đã báo chuyển (Chờ xác nhận)'
                            : isOwe
                                ? 'Unpaid Debts (Chưa trả)'
                                : hasAnyReported
                                    ? 'Cần xác nhận đã nhận tiền'
                                    : 'Pending Debts (Chưa trả)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: isFullyReported
                            ? const Color(0xFFFEF3C7)
                            : isOwe
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isFullyReported
                            ? '${debts.length} chờ duyệt'
                            : hasAnyReported && !isOwe
                                ? '${debts.length} cần xác nhận'
                                : '${debts.length} pending',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: isFullyReported
                              ? const Color(0xFFB45309)
                              : isOwe
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (final d in debts) ...[
                  _DebtItemRow(
                    houseId: houseId,
                    isOwe: isOwe,
                    debt: d,
                  ),
                  const SizedBox(height: 6),
                ],
                if (confirmedRepayments.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Expanded(
                        child: Text(
                          'Settled History (Đã trả)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Recent',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (final r in confirmedRepayments.take(1))
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFDCFCE7)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: Color(0xFFDCFCE7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 12,
                              color: Color(0xFF15803D),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Xác nhận bởi: ${primaryDebt['creditorName'] ?? (isOwe ? otherName : 'Bạn')}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                Text(
                                  'Người chuyển: ${primaryDebt['debtorName'] ?? (isOwe ? 'Bạn' : otherName)} · ${supplyMoney(r['amount'] as num? ?? 0)}',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Text(
                            'Settled ✓',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 4),
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: (isOwe ? isFullyReported : hasAnyReported)
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (isOwe ? isFullyReported : hasAnyReported)
                          ? const Color(0xFFFDE68A)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        (isOwe ? isFullyReported : hasAnyReported)
                            ? Icons.hourglass_top_rounded
                            : Icons.account_circle_outlined,
                        size: 13,
                        color: (isOwe ? isFullyReported : hasAnyReported)
                            ? const Color(0xFFB45309)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isOwe
                              ? isFullyReported
                                  ? 'Đã báo chuyển · Đang chờ $otherName duyệt'
                                  : 'Người chuyển: ${primaryDebt['debtorName'] ?? 'Bạn'} → Người nhận: $otherName'
                              : hasAnyReported
                                  ? '$otherName đã báo chuyển · Xác nhận bởi: ${primaryDebt['creditorName'] ?? 'Bạn'}'
                                  : 'Chờ $otherName chuyển · Bấm Confirm received nếu đã nhận',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: (isOwe ? isFullyReported : hasAnyReported)
                                ? const Color(0xFFB45309)
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await context.push(
                            '/houses/$houseId/account/debts/${primaryDebt['id']}',
                          );
                          ref.invalidate(purchaseDebtsProvider(houseId));
                          ref.invalidate(householdSummaryProvider);
                          ref.invalidate(paymentHistoryProvider);
                        },
                        icon: const Icon(
                          Icons.receipt_long_outlined,
                          size: 14,
                        ),
                        label: const Text('View Breakdown'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          foregroundColor: const Color(0xFF334155),
                          textStyle: const TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => onActions(
                          orderDebts.isNotEmpty ? orderDebts : [primaryDebt],
                        ),
                        icon: Icon(
                          isOwe
                              ? (isFullyReported
                                  ? Icons.hourglass_top_rounded
                                  : Icons.payments_outlined)
                              : Icons.check_circle_outline_rounded,
                          size: 14,
                        ),
                        label: Text(
                          isOwe
                              ? (isFullyReported ? 'Chờ duyệt' : 'Mark as paid')
                              : 'Confirm received',
                        ),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: isOwe
                              ? (isFullyReported
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF7C4DFF))
                              : const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(fontSize: 11.5),
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
    );
  }
}

class _DebtItemRow extends ConsumerWidget {
  const _DebtItemRow({
    required this.houseId,
    required this.isOwe,
    required this.debt,
  });

  final String houseId;
  final bool isOwe;
  final Map debt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final awaiting = debt['status'] == 'AWAITING_COMPLETION';
    final remaining = debt['remainingAmount'] as num? ?? 0;
    final repayments = (debt['repayments'] as List? ?? []).cast<Map>();
    final pendingTransfers =
        repayments.where((r) => r['status'] == 'REPORTED').toList();
    final pendingReported =
        pendingTransfers.fold<num>(0, (s, r) => s + (r['amount'] as num? ?? 0));
    final isReported = pendingReported > 0;
    final otherName = isOwe
        ? (debt['creditorName']?.toString() ?? '')
        : (debt['debtorName']?.toString() ?? '');

    final debtorName =
        debt['debtorName']?.toString() ?? (isOwe ? 'Bạn' : otherName);
    final creditorName =
        debt['creditorName']?.toString() ?? (isOwe ? otherName : 'Bạn');

    final title = isOwe ? 'Pay $creditorName' : '$debtorName owes you';
    final subtitle = isReported
        ? '$debtorName đã báo chuyển ${supplyMoney(pendingReported)} · Chờ $creditorName xác nhận'
        : '${supplyMoney(remaining)} remaining · ${financeSourceLabel(debt['reason'])} · Người nhận: $creditorName';

    if (awaiting) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          '🟡 In Progress',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  supplyMoney(remaining),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFB45309),
                  ),
                ),
                const SizedBox(height: 1),
                const Text(
                  'Pending review',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isReported
            ? const Color(0xFFFFFBEB)
            : const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isReported
              ? const Color(0xFFFDE68A)
              : const Color(0xFFFECDD3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: isReported
                            ? const Color(0xFFFEF3C7)
                            : const Color(0xFFFFE4E6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isReported
                            ? isOwe
                                ? '🟡 Chờ xác nhận'
                                : '🟢 Cần duyệt'
                            : isOwe
                                ? 'Awaiting Pay'
                                : 'Due Receivable',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: isReported
                              ? isOwe
                                  ? const Color(0xFFB45309)
                                  : const Color(0xFF047857)
                              : isOwe
                                  ? const Color(0xFFBE123C)
                                  : const Color(0xFF047857),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                supplyMoney(remaining),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isReported
                      ? const Color(0xFFB45309)
                      : isOwe
                          ? const Color(0xFFE11D48)
                          : const Color(0xFF059669),
                ),
              ),
              const SizedBox(height: 1),
              InkWell(
                onTap: () async {
                  await context.push(
                    '/houses/$houseId/account/debts/${debt['id']}',
                  );
                  ref.invalidate(purchaseDebtsProvider(houseId));
                  ref.invalidate(householdSummaryProvider);
                  ref.invalidate(paymentHistoryProvider);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isReported
                          ? isOwe
                              ? 'Đã chuyển ✓'
                              : 'Xác nhận >'
                          : isOwe
                              ? 'Pay single'
                              : 'Details',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: isReported
                            ? isOwe
                                ? const Color(0xFFB45309)
                                : const Color(0xFF047857)
                            : isOwe
                                ? const Color(0xFFE11D48)
                                : const Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 11,
                      color: isReported
                          ? isOwe
                              ? const Color(0xFFB45309)
                              : const Color(0xFF047857)
                          : isOwe
                              ? const Color(0xFFE11D48)
                              : const Color(0xFF059669),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettledNoticeCard extends StatelessWidget {
  const _SettledNoticeCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.isOwe,
  });

  final String title;
  final String subtitle;
  final String badge;
  final bool isOwe;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF065F46),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF047857),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 2.5,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF047857),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class InternalRepaymentScreen extends ConsumerStatefulWidget {
  const InternalRepaymentScreen({
    required this.houseId,
    required this.debtId,
    super.key,
  });
  final String houseId;
  final String debtId;
  @override
  ConsumerState<InternalRepaymentScreen> createState() =>
      _InternalRepaymentScreenState();
}

class _InternalRepaymentScreenState
    extends ConsumerState<InternalRepaymentScreen> {
  String _requestId = const Uuid().v4();
  bool _busy = false;
  bool _localConfirmed = false;
  String? _error;

  Future<void> _run(String path, SupplyData request) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(suppliesRepositoryProvider).mutate(path, request);
      if (mounted) {
        _requestId = const Uuid().v4();
        setState(() => _localConfirmed = true);
        ref.invalidate(
          purchaseDebtProvider((
            house: widget.houseId,
            id: widget.debtId,
          )),
        );
        ref.invalidate(purchaseDebtsProvider(widget.houseId));
        ref.invalidate(paymentHistoryProvider);
        ref.invalidate(householdSummaryProvider);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(userProfileProvider).asData?.value.id;
    return SuppliesPage(
      title: 'Direct repayment',
      child: ref
          .watch(
            purchaseDebtProvider((
              house: widget.houseId,
              id: widget.debtId,
            )),
          )
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => SupplyFailure(
              e,
              () => ref.invalidate(
                purchaseDebtProvider((
                  house: widget.houseId,
                  id: widget.debtId,
                )),
              ),
            ),
            data: (d) {
              final debtor = d['debtorUserId'] == me;
              final rawRemaining = d['remainingAmount'] as num? ?? 0;
              final repayments = (d['repayments'] as List? ?? []).cast<Map>();
              final pending = repayments
                  .where((r) => r['status'] == 'REPORTED')
                  .toList();
              final pendingAmount = pending.fold<num>(
                0,
                (sum, r) => sum + (r['amount'] as num),
              );
              final remaining =
                  _localConfirmed ? 0 : rawRemaining.toDouble();
              final num originalAmount =
                  d['originalAmount'] as num? ?? d['amount'] as num? ?? 0;
              final num confirmedAmount = d['confirmedAmount'] as num? ?? 0;
              final num adjustments = d['adjustments'] as num? ?? 0;
              final num totalAmount = originalAmount > 0
                  ? originalAmount + adjustments
                  : (confirmedAmount + (d['remainingAmount'] as num? ?? 0));
              final isSettled = remaining <= 0 || d['status'] == 'PAID';
              final availableToReport = debtor
                  ? (remaining - pendingAmount).clamp(0, remaining).toDouble()
                  : remaining;
              final isPayable = d['status'] != 'AWAITING_COMPLETION';

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEDEAF6)),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF0F172A).withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${d['debtorName']} → ${d['creditorName']}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isSettled
                                    ? const Color(0xFFDCFCE7)
                                    : pendingAmount > 0
                                        ? const Color(0xFFFEF3C7)
                                        : const Color(0xFFFFE4E6),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                isSettled
                                    ? 'Đã thanh toán ✓'
                                    : pendingAmount > 0
                                        ? 'Chờ xác nhận'
                                        : 'Chưa thanh toán',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: isSettled
                                      ? const Color(0xFF15803D)
                                      : pendingAmount > 0
                                          ? const Color(0xFFB45309)
                                          : const Color(0xFFBE123C),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          supplyMoney(totalAmount),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        if (d['reason'] != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            financeSourceLabel(d['reason']),
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                        if (isSettled) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFFDCFCE7)),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  size: 14,
                                  color: Color(0xFF15803D),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Xác nhận bởi: ${d['creditorName']} (Người nhận) · Người chuyển: ${d['debtorName']}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF15803D),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (!isSettled &&
                            remaining > 0 &&
                            remaining != totalAmount) ...[
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Còn lại cần thanh toán:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                supplyMoney(remaining),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFE11D48),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (adjustments != 0) ...[
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Điều chỉnh:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                supplyMoney(adjustments),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!isPayable) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Text(
                        'Khoản nợ này đang chờ hoàn thành công việc trước khi thanh toán.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                  if (debtor && isPayable && !isSettled)
                    ref
                        .watch(
                          repaymentInstructionsProvider(widget.debtId),
                        )
                        .when(
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          error: (_, _) => const SizedBox.shrink(),
                          data: (instructions) {
                            final bank =
                                instructions['bankAccount'] as Map?;
                            return Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFEDEAF6),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Chuyển khoản trực tiếp cho ${d['creditorName']}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (bank == null)
                                      const Text(
                                        'Người nhận chưa thêm tài khoản ngân hàng. Hãy liên hệ người nhận để chuyển khoản.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      )
                                    else ...[
                                      Text(
                                        '${bank['bankName']} · ${bank['accountHolderName']}',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              bank['accountNumber'].toString(),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1E293B),
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ),
                                          TextButton.icon(
                                            onPressed: () => supplyCopy(
                                              context,
                                              'Account number',
                                              bank['accountNumber'].toString(),
                                            ),
                                            icon: const Icon(
                                              Icons.copy_rounded,
                                              size: 13,
                                            ),
                                            label: const Text(
                                              'Sao chép',
                                              style: TextStyle(fontSize: 11),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (instructions['reference'] != null &&
                                          instructions['reference']
                                              .toString()
                                              .isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Nội dung: ${instructions['reference']}',
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                            TextButton.icon(
                                              onPressed: () => supplyCopy(
                                                context,
                                                'Reference',
                                                instructions['reference']
                                                    .toString(),
                                              ),
                                              icon: const Icon(
                                                Icons.copy_rounded,
                                                size: 13,
                                              ),
                                              label: const Text(
                                                'Sao chép',
                                                style: TextStyle(fontSize: 11),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  if (isPayable &&
                      !isSettled &&
                      (!debtor || availableToReport > 0)) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => debtor
                              ? _run(
                                  '/payment-obligations/${widget.debtId}/repayments',
                                  {
                                    'clientRequestId': _requestId,
                                    'amount': availableToReport,
                                    'reference': '',
                                  },
                                )
                              : pending.isNotEmpty
                              ? _run(
                                  '/payment-obligations/${widget.debtId}/repayments/${pending.first['id']}/respond',
                                  {'confirm': true},
                                )
                              : _run(
                                  '/payment-obligations/${widget.debtId}/record-receipt',
                                  {
                                    'clientRequestId': _requestId,
                                    'amount': remaining,
                                    'reference': '',
                                  },
                                ),
                      icon: Icon(
                        debtor
                            ? Icons.payments_outlined
                            : Icons.check_circle_outline_rounded,
                        size: 16,
                      ),
                      label: Text(
                        _busy
                            ? 'Đang lưu…'
                            : debtor
                                ? 'Xác nhận đã chuyển khoản'
                                : 'Xác nhận đã nhận tiền',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: debtor
                            ? const Color(0xFF7C4DFF)
                            : const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ] else if (debtor &&
                      pendingAmount > 0 &&
                      !isSettled &&
                      !_localConfirmed) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.hourglass_top_rounded,
                            size: 16,
                            color: Color(0xFFB45309),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Đã báo chuyển ${supplyMoney(pendingAmount)}. Đang chờ ${d['creditorName']} xác nhận.',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (_busy) const LinearProgressIndicator(),
                  const SizedBox(height: 20),
                  const Text(
                    'Lịch sử thanh toán',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (repayments.isEmpty && !isSettled)
                    Container(
                      padding: const EdgeInsets.all(16),
                      alignment: Alignment.center,
                      child: const Text(
                        'Chưa có giao dịch chuyển khoản nào.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    )
                  else if (repayments.isEmpty && isSettled)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDCFCE7)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: Color(0xFFDCFCE7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: Color(0xFF15803D),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Thanh toán hoàn tất',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                                Text(
                                  'Xác nhận bởi: ${d['creditorName']} · Người chuyển: ${d['debtorName']}',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            supplyMoney(totalAmount),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  for (final r in repayments)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: r['status'] == 'CONFIRMED'
                                  ? const Color(0xFFDCFCE7)
                                  : r['status'] == 'REPORTED'
                                      ? const Color(0xFFFEF3C7)
                                      : const Color(0xFFFEE2E2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              r['status'] == 'CONFIRMED'
                                  ? Icons.check_rounded
                                  : r['status'] == 'REPORTED'
                                      ? Icons.hourglass_top_rounded
                                      : Icons.close_rounded,
                              size: 15,
                              color: r['status'] == 'CONFIRMED'
                                  ? const Color(0xFF15803D)
                                  : r['status'] == 'REPORTED'
                                      ? const Color(0xFFB45309)
                                      : const Color(0xFFDC2626),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r['status'] == 'CONFIRMED'
                                      ? 'Xác nhận bởi: ${d['creditorName']}'
                                      : r['status'] == 'REPORTED'
                                          ? 'Báo chuyển bởi: ${d['debtorName']}'
                                          : 'Bị từ chối bởi: ${d['creditorName']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  r['status'] == 'CONFIRMED'
                                      ? 'Người chuyển: ${d['debtorName']} · ${r['source'] == 'CREDITOR_RECORDED' ? 'Người nhận ghi nhận' : 'Đã duyệt'}'
                                      : r['status'] == 'REPORTED'
                                          ? 'Đang chờ ${d['creditorName']} xác nhận'
                                          : 'Giao dịch không hợp lệ',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '+${supplyMoney(r['amount'])}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: r['status'] == 'CONFIRMED'
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
    );
  }
}
