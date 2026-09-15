class ApiEndpoints {
  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';
  
  // User
  static const String profile = '/user/profile';
  
  // House
  static const String houses = '/houses';
  static String houseDetails(String id) => '/houses/$id';
  static String joinHouse = '/houses/join';
  static String leaveHouse(String id) => '/houses/$id/leave';
  
  // Chores
  static const String chores = '/chores';
  static String choreDetails(String id) => '/chores/$id';
  
  // Seasons
  static const String seasons = '/seasons';
}
