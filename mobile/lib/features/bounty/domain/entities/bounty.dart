enum BountyStatus { open, claimed, completed, expired, cancelled, unknown }

class Bounty {
  final String id;
  final String choreOccurrenceId;
  final String choreName;
  final String postedByUserId;
  final String postedByDisplayName;
  final double amount;
  final BountyStatus status;
  final DateTime expiresAt;
  final String? newAssigneeDisplayName;
  final double? forcedCompensationAmount;

  const Bounty({
    required this.id,
    required this.choreOccurrenceId,
    required this.choreName,
    required this.postedByUserId,
    required this.postedByDisplayName,
    required this.amount,
    required this.status,
    required this.expiresAt,
    this.newAssigneeDisplayName,
    this.forcedCompensationAmount,
  });
}