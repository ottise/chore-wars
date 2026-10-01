import 'package:dio/dio.dart';
import '../../../../core/network/api_endpoints.dart';

class SeasonRemoteDataSource {
  const SeasonRemoteDataSource(this._dio);
  final Dio _dio;

  Future<void> createSeason(String houseId, Map<String, dynamic> data) async {
    await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.houseSeasons(houseId),
      data: data,
    );
  }
}
