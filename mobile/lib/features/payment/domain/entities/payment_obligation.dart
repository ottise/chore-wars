enum PaymentStatus { pending, paid, disputed, cancelled, unknown }
enum PaymentReason { bountyPayment, forcedReassignment, penalty, other, unknown }

class PaymentObligation {
  final String id;
  final String debtorDisplayName;
  final String creditorDisplayName;
  final double amount;
  final PaymentReason reason;
  final PaymentStatus status;
  final DateTime createdAt;
  final DateTime? paidAt;

  const PaymentObligation({
    required this.id,
    required this.debtorDisplayName,
    required this.creditorDisplayName,
    required this.amount,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.paidAt,
  });
}