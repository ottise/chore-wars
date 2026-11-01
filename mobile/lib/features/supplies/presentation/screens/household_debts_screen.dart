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

  Future<void> _actions(Map debt, String? me) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DebtActionSheet(
        houseId: widget.houseId,
        debt: Map<String, dynamic>.from(debt),
        debtor: debt['debtorUserId'] == me,
      ),
    );
    ref.invalidate(
      purchaseDebtProvider((
        house: widget.houseId,
        id: debt['id'].toString(),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      onActions: (d) => _actions(d, me),
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
                      onActions: (d) => _actions(d, me),
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

class _PersonDebtCard extends StatelessWidget {
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
  final void Function(Map debt) onActions;

  @override
  Widget build(BuildContext context) {
    final total = debts.fold<num>(
      0,
      (sum, d) => sum + (d['remainingAmount'] as num? ?? 0),
    );
    final initial = otherName.isNotEmpty ? otherName[0].toUpperCase() : 'M';
    final primaryDebt = debts.first;
    final confirmedRepayments = debts
        .expand((d) => (d['repayments'] as List? ?? []).cast<Map>())
        .where((r) => r['status'] == 'CONFIRMED')
        .toList();

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
                color: isOwe
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
                          isOwe ? 'DUE TO PAY' : 'RECEIVABLE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: isOwe
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
                            color: isOwe
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
                        color: isOwe
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        isOwe
                            ? 'Unpaid Debts (Chưa trả)'
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
                        color: isOwe
                            ? const Color(0xFFFEE2E2)
                            : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${debts.length} pending',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: isOwe
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
                  for (final _ in confirmedRepayments.take(1))
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
                                  'Settlement transfer',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const Text(
                                  'Paid via VietQR',
                                  style: TextStyle(
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
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push(
                          '/houses/$houseId/account/debts/${primaryDebt['id']}',
                        ),
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
                        onPressed: () => onActions(primaryDebt),
                        icon: Icon(
                          isOwe
                              ? Icons.payments_outlined
                              : Icons.check_circle_outline_rounded,
                          size: 14,
                        ),
                        label: Text(
                          isOwe ? 'Mark as paid' : 'Confirm received',
                        ),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: const Color(0xFF7C4DFF),
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

class _DebtItemRow extends StatelessWidget {
  const _DebtItemRow({
    required this.houseId,
    required this.isOwe,
    required this.debt,
  });

  final String houseId;
  final bool isOwe;
  final Map debt;

  @override
  Widget build(BuildContext context) {
    final awaiting = debt['status'] == 'AWAITING_COMPLETION';
    final remaining = debt['remainingAmount'] as num? ?? 0;
    final otherName = isOwe
        ? (debt['creditorName']?.toString() ?? '')
        : (debt['debtorName']?.toString() ?? '');

    final title = isOwe ? 'Pay $otherName' : '$otherName owes you';
    final subtitle =
        '${supplyMoney(remaining)} remaining · ${financeSourceLabel(debt['reason'])} · ${awaiting ? 'Awaiting chore completion' : debt['status'] == 'DISPUTED' ? 'Disputed' : 'Pending'}';

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
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECDD3)),
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
                        color: const Color(0xFFFFE4E6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isOwe ? 'Awaiting Pay' : 'Due Receivable',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: isOwe
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
                  color: isOwe
                      ? const Color(0xFFE11D48)
                      : const Color(0xFF059669),
                ),
              ),
              const SizedBox(height: 1),
              InkWell(
                onTap: () => context.push(
                  '/houses/$houseId/account/debts/${debt['id']}',
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isOwe ? 'Pay single' : 'Details',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: isOwe
                            ? const Color(0xFFE11D48)
                            : const Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 11,
                      color: isOwe
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
              final availableToReport = debtor
                  ? (remaining - pendingAmount).clamp(0, remaining).toDouble()
                  : remaining;
              final isPayable = d['status'] != 'AWAITING_COMPLETION';
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  SupplySurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${d['debtorName']} → ${d['creditorName']}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Text('Original: ${supplyMoney(d['amount'])}'),
                        Text(
                          'Adjustments: ${supplyMoney(d['adjustments'])}',
                        ),
                        Text(
                          'Confirmed transfers: ${supplyMoney(d['confirmedAmount'])}',
                        ),
                        const Divider(height: 24),
                        Text(
                          'Remaining: ${supplyMoney(remaining)}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  if (!isPayable) ...[
                    const SizedBox(height: 16),
                    const SupplySurface(
                      child: Text(
                        'This obligation is awaiting chore completion before payment can be confirmed.',
                      ),
                    ),
                  ],
                  if (debtor && isPayable)
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
                              padding: const EdgeInsets.only(top: 16),
                              child: SupplySurface(
                                child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pay ${d['creditorName']} directly',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  if (bank == null)
                                    const Text(
                                      'Bank details not added yet. Contact the recipient to arrange a transfer.',
                                    )
                                  else ...[
                                    Text(
                                      '${bank['bankName']} · ${bank['accountHolderName']}',
                                    ),
                                    Text(bank['accountNumber'].toString()),
                                    TextButton(
                                      onPressed: () => supplyCopy(
                                        context,
                                        'Account number',
                                        bank['accountNumber'].toString(),
                                      ),
                                      child: const Text(
                                        'Copy account number',
                                      ),
                                    ),
                                  ],
                                  TextButton(
                                    onPressed: () => supplyCopy(
                                      context,
                                      'Reference',
                                      instructions['reference'].toString(),
                                    ),
                                    child: Text(
                                      'Copy reference: ${instructions['reference']}',
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => supplyCopy(
                                      context,
                                      'Amount',
                                      remaining.toStringAsFixed(0),
                                    ),
                                    child: const Text(
                                      'Copy remaining amount',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                          },
                        ),
                  if (isPayable && (!debtor || availableToReport > 0)) ...[
                    const SizedBox(height: 20),
                    FilledButton(
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
                      child: const Text('Confirm'),
                    ),
                  ] else if (debtor &&
                      pendingAmount > 0 &&
                      !_localConfirmed) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Waiting for ${d['creditorName']} to confirm receipt.',
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
                  const SizedBox(height: 24),
                  Text(
                    'Transfer history',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (repayments.isEmpty && !_localConfirmed)
                    const Text('No transfers reported yet.')
                  else if (repayments.isEmpty && _localConfirmed)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SupplySurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(supplyMoney(rawRemaining)),
                            const Text('Debt · CONFIRMED'),
                          ],
                        ),
                      ),
                    ),
                  for (final r in repayments)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SupplySurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(supplyMoney(r['amount'])),
                            Text('Debt · ${r['status']}'),
                            if (r['responseReason'] != null)
                              Text(r['responseReason'].toString()),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
    );
  }
}
