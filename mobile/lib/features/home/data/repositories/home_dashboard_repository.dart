import '../../../../core/utils/vietnam_time.dart';

import 'package:dio/dio.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../bounty/data/models/bounty_model.dart';
import '../../domain/entities/home_dashboard.dart';

class HomeDashboardRepository {
  final Dio dio;

  const HomeDashboardRepository(this.dio);

  Future<HomeDashboard> getDashboard(String houseId) async {
    final responses = await Future.wait([
      dio.get(ApiEndpoints.profile),
      dio.get(ApiEndpoints.houseDetails(houseId)),
      dio.get(ApiEndpoints.karma(houseId)),
      dio.get(ApiEndpoints.myChores(houseId)),
      dio.get(ApiEndpoints.bounties(houseId)),
      dio.get('/houses/$houseId/seasons/current'),
    ]);

    final profile = _asMap(responses[0].data);
    final house = _asMap(responses[1].data);
    final karma = _asMap(responses[2].data);
    final chores = responses[3].data is List
        ? responses[3].data as List
        : const [];
    final bounties = responses[4].data is List
        ? responses[4].data as List
        : const [];
    final season = _asMapNullable(responses[5].data);

    return HomeDashboard(
      userDisplayName: profile['displayName'] as String? ?? '',
      houseId: house['id']?.toString() ?? houseId,
      houseName: house['name'] as String? ?? '',
      isOwner:
          house['currentUserRole'] == 1 || house['currentUserRole'] == 'OWNER',
      karma: (karma['current'] as num?)?.toInt() ?? 0,
      rank: (karma['rank'] as num?)?.toInt(),
      seasonId: season?['id']?.toString(),
      seasonStatus: (season?['status'] as num?)?.toInt(),
      currentUserConfirmationStatus:
          (season?['currentUserConfirmationStatus'] as num?)?.toInt(),
      confirmedCount: (season?['confirmedCount'] as num?)?.toInt() ?? 0,
      requiredConfirmationCount:
          (season?['requiredConfirmationCount'] as num?)?.toInt() ?? 0,
      chores: chores
          .whereType<Map<String, dynamic>>()
          .map(_choreFromJson)
          .toList(),
      bounties: bounties
          .whereType<Map<String, dynamic>>()
          .map(BountyModel.fromJson)
          .map((model) => model.toEntity())
          .toList(),
    );
  }

  static DashboardChore _choreFromJson(Map<String, dynamic> json) {
    return DashboardChore(
      id: json['id'].toString(),
      name: json['choreName'] as String? ?? '',
      dueDate: vietnamTime(json['dueDate']),
      status: json['status']?.toString() ?? '',
    );
  }

  static Map<String, dynamic>? _asMapNullable(Object? value) {
    return value is Map<String, dynamic> ? value : null;
  }

  static Map<String, dynamic> _asMap(Object? value) {
    return value is Map<String, dynamic> ? value : <String, dynamic>{};
  }
}
