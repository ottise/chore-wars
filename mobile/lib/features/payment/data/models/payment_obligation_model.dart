import '../../domain/entities/payment_obligation.dart';

class PaymentObligationModel extends PaymentObligation {
  const PaymentObligationModel({
    required super.id,
    required super.debtorUserId,
    required super.debtorDisplayName,
    required super.creditorUserId,
    required super.creditorDisplayName,
    required super.amount,
    required super.reason,
    required super.status,
    required super.createdAt,
    super.paidAt,
    super.choreName,
  });

  factory PaymentObligationModel.fromJson(Map<String, dynamic> json) {
    return PaymentObligationModel(
      id: json['id'].toString(),
      debtorUserId: json['debtorUserId']?.toString() ?? '',
      debtorDisplayName: json['debtorDisplayName'] as String? ?? '',
      creditorUserId: json['creditorUserId']?.toString() ?? '',
      creditorDisplayName: json['creditorDisplayName'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      reason: _reason(json['reason']),
      status: _status(json['status']),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      paidAt: json['paidAt'] == null ? null : DateTime.tryParse(json['paidAt'].toString())?.toLocal(),
      choreName: json['choreName'] as String?,
    );
  }

  static PaymentStatus _status(Object? value) {
    switch (value.toString().toLowerCase()) {
      case 'pending':
      case '0':
        return PaymentStatus.pending;
      case 'paid':
      case '1':
        return PaymentStatus.paid;
      case 'disputed':
      case '2':
        return PaymentStatus.disputed;
      case 'cancelled':
      case '3':
        return PaymentStatus.cancelled;
      default:
        return PaymentStatus.unknown;
    }
  }

  static PaymentReason _reason(Object? value) {
    switch (value.toString().toLowerCase()) {
      case 'bounty_payment':
      case 'bountypayment':
      case '0':
        return PaymentReason.bountyPayment;
      case 'forced_reassignment':
      case 'forcedreassignment':
      case '1':
        return PaymentReason.forcedReassignment;
      case 'penalty':
      case '2':
        return PaymentReason.penalty;
      case 'other':
      case '3':
        return PaymentReason.other;
      default:
        return PaymentReason.unknown;
    }
  }
}