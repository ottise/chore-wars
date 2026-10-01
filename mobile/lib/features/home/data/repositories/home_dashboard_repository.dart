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
    ]);

    final profile = _asMap(responses[0].data);
    final house = _asMap(responses[1].data);
    final karma = _asMap(responses[2].data);
    final chores = responses[3].data is List ? responses[3].data as List : const [];
    final bounties = responses[4].data is List ? responses[4].data as List : const [];

    Map<String, dynamic>? season;
    try {
      final seasonRes = await dio.get('/houses/$houseId/seasons/current');
      season = _asMapNullable(seasonRes.data);
    } catch (_) {
      season = null;
    }

    return HomeDashboard(
      userDisplayName: profile['displayName'] as String? ?? '',
      houseId: house['id']?.toString() ?? houseId,
      houseName: house['name'] as String? ?? '',
      karma: (karma['karma'] as num?)?.toInt() ?? 0,
      rank: (karma['rank'] as num?)?.toInt(),
      seasonId: season?['id']?.toString(),
      seasonStatus: (season?['status'] as num?)?.toInt(),
      chores: chores.whereType<Map<String, dynamic>>().map(_choreFromJson).toList(),
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
      dueDate: DateTime.parse(json['dueDate'] as String).toLocal(),
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