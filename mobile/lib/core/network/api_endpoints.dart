class ApiEndpoints {
  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refreshToken = '/auth/refresh-token';
  static const String logout = '/auth/logout';

  // User
  static const String profile = '/user/profile';

  // House
  static const String houses = '/houses';
  static const String myHouses = '/houses/my-houses';
  static const String joinHouse = '/houses/join';
  static String houseDetails(String id) => '/houses/$id';
  static String leaveHouse(String id) => '/houses/$id/leave';
  static String houseMembers(String houseId) => '/houses/$houseId/members';
  static String kickMember(String houseId, String memberId) =>
      '/houses/$houseId/members/$memberId';
  static String transferOwnership(String houseId, String newOwnerId) =>
      '/houses/$houseId/transfer-ownership/$newOwnerId';

  // Chores
  static String houseChores(String houseId) => '/houses/$houseId/chores';
  static String myChores(String houseId) => '/houses/$houseId/my-chores';
  static String choreDetails(String id) => '/occurrences/$id';
  static String choreTemplate(String id) => '/chores/$id';
  static String completeChore(String id) => '/occurrences/$id/complete';
  static String skipChore(String id) => '/occurrences/$id/skip';

  // Seasons & gamification
  static String seasonRankings(String houseId, String seasonId) =>
      '/houses/$houseId/seasons/$seasonId/rankings';
  static String karma(String houseId) => '/houses/$houseId/gamification/karma';
  static String karmaHistory(String houseId) =>
      '/houses/$houseId/gamification/karma/history';
  static String achievements(String houseId) =>
      '/houses/$houseId/gamification/achievements';
  static String seasonRewards(String houseId, String seasonId) =>
      '/houses/$houseId/gamification/seasons/$seasonId/rewards';
  static String claimReward(String houseId, String redemptionId) =>
      '/houses/$houseId/gamification/rewards/redemptions/$redemptionId/claim';
  static String useChorePass(
    String houseId,
    String redemptionId,
    String occurrenceId,
  ) =>
      '/houses/$houseId/gamification/rewards/redemptions/$redemptionId/use-chore-pass/$occurrenceId';
}
