import '../../domain/entities/notification_models.dart';
import '../datasources/notification_remote_data_source.dart';

abstract interface class NotificationRepository {
  Future<List<AppNotification>> getNotifications();
  Future<void> markAsRead(String id);
  Future<void> markAllAsRead();
}

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource _remoteDataSource;

  NotificationRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<AppNotification>> getNotifications() async {
    return await _remoteDataSource.getNotifications();
  }

  @override
  Future<void> markAsRead(String id) async {
    await _remoteDataSource.markAsRead(id);
  }

  @override
  Future<void> markAllAsRead() async {
    await _remoteDataSource.markAllAsRead();
  }
}
