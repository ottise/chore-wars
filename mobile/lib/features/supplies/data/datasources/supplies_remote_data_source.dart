import 'package:dio/dio.dart';

import '../../domain/repositories/supplies_repository.dart';

class SuppliesRemoteDataSource {
  SuppliesRemoteDataSource(this.dio);
  final Dio dio;
  Future<SupplyData> get(String path) async {
    final data = (await dio.get<dynamic>(path)).data;
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<List<SupplyData>> list(String path) async =>
      ((await dio.get<List<dynamic>>(path)).data ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  Future<SupplyData> mutate(
    String path,
    SupplyData body, {
    String method = 'POST',
  }) async {
    final data = (await dio.request<dynamic>(
      path,
      data: body,
      options: Options(method: method),
    )).data;
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }
}
