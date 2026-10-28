enum PaymentStatus { pending, paid, disputed, cancelled, unknown }

enum PaymentReason {
  bountyPayment,
  forcedReassignment,
  penalty,
  other,
  unknown,
}

class PaymentObligation {
  final String id;
  final String debtorUserId;
  final String debtorDisplayName;
  final String creditorUserId;
  final String creditorDisplayName;
  final double amount;
  final PaymentReason reason;
  final PaymentStatus status;
  final DateTime createdAt;
  final DateTime? paidAt;
  final String? choreName;

  const PaymentObligation({
    required this.id,
    required this.debtorUserId,
    required this.debtorDisplayName,
    required this.creditorUserId,
    required this.creditorDisplayName,
    required this.amount,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.paidAt,
    this.choreName,
  });
}
