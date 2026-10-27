import 'package:dio/dio.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/notification_models.dart';

abstract class NotificationRemoteDataSource {
  Future<List<AppNotification>> getNotifications();
  Future<void> markAsRead(String id);
  Future<void> markAllAsRead();
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final Dio _dio;

  NotificationRemoteDataSourceImpl(this._dio);

  @override
  Future<List<AppNotification>> getNotifications() async {
    final response = await _dio.get(ApiEndpoints.notifications);
    return (response.data as List)
        .map((json) => AppNotification.fromJson(json))
        .toList();
  }

  @override
  Future<void> markAsRead(String id) async {
    await _dio.post(ApiEndpoints.readNotification(id));
  }

  @override
  Future<void> markAllAsRead() async {
    await _dio.post(ApiEndpoints.readAllNotifications);
  }
}
