enum BountyStatus { open, claimed, completed, expired, cancelled, unknown }

class Bounty {
  final String? claimedByUserId, cancellationRequestedByUserId;
  final String id;
  final String choreOccurrenceId;
  final String choreName;
  final String postedByUserId;
  final String postedByDisplayName;
  final String? assignedUserId;
  final double amount;
  final BountyStatus status;
  final DateTime expiresAt;
  final String? newAssigneeDisplayName;
  final double? forcedCompensationAmount;

  const Bounty({
    this.claimedByUserId,
    this.cancellationRequestedByUserId,
    required this.id,
    required this.choreOccurrenceId,
    required this.choreName,
    required this.postedByUserId,
    required this.postedByDisplayName,
    this.assignedUserId,
    required this.amount,
    required this.status,
    required this.expiresAt,
    this.newAssigneeDisplayName,
    this.forcedCompensationAmount,
  });
}
