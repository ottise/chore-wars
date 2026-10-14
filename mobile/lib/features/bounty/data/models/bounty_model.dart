import '../../domain/entities/bounty.dart';

class BountyModel extends Bounty {
  const BountyModel({
    required super.id,
    required super.choreOccurrenceId,
    required super.choreName,
    required super.postedByUserId,
    required super.postedByDisplayName,
    super.assignedUserId,
    required super.amount,
    required super.status,
    required super.expiresAt,
    super.newAssigneeDisplayName,
    super.forcedCompensationAmount,
  });

  factory BountyModel.fromJson(Map<String, dynamic> json) {
    return BountyModel(
      id: json['id']?.toString() ?? '',
      choreOccurrenceId: json['choreOccurrenceId']?.toString() ?? '',
      choreName: json['choreName'] as String? ?? 'Chore',
      postedByUserId: json['postedByUserId']?.toString() ?? '',
      postedByDisplayName: json['postedByDisplayName'] as String? ?? '',
      assignedUserId: json['assignedUserId']?.toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: bountyStatusFromJson(json['status']),
      expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      newAssigneeDisplayName: json['newAssigneeDisplayName'] as String?,
      forcedCompensationAmount: (json['forcedCompensationAmount'] as num?)?.toDouble(),
    );
  }

  Bounty toEntity() => this;
}

BountyStatus bountyStatusFromJson(Object? value) {
  final status = value.toString().toLowerCase();
  if (status == 'open' || status == '0') return BountyStatus.open;
  if (status == 'claimed' || status == '1') return BountyStatus.claimed;
  if (status == 'completed' || status == '2') return BountyStatus.completed;
  if (status == 'expired' || status == '3') return BountyStatus.expired;
  if (status == 'cancelled' || status == '4') return BountyStatus.cancelled;
  return BountyStatus.unknown;
}
