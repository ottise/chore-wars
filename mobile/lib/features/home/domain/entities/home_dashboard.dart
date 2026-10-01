import '../../../bounty/domain/entities/bounty.dart';

class DashboardChore {
  final String id;
  final String name;
  final DateTime dueDate;
  final String status;

  const DashboardChore({
    required this.id,
    required this.name,
    required this.dueDate,
    required this.status,
  });
}

class HomeDashboard {
  final String userDisplayName;
  final String houseId;
  final String houseName;
  final int karma;
  final int? rank;
  final String? seasonId;
  final int? seasonStatus;
  final List<DashboardChore> chores;
  final List<Bounty> bounties;

  const HomeDashboard({
    required this.userDisplayName,
    required this.houseId,
    required this.houseName,
    required this.karma,
    required this.rank,
    this.seasonId,
    this.seasonStatus,
    required this.chores,
    required this.bounties,
  });
}