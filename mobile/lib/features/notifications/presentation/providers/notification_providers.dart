import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/datasources/notification_remote_data_source.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../../data/services/notification_signalr_service.dart';
import '../../domain/entities/notification_models.dart';

final notificationRemoteDataSourceProvider = Provider<NotificationRemoteDataSource>((ref) {
  return NotificationRemoteDataSourceImpl(ref.watch(dioProvider));
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl(ref.watch(notificationRemoteDataSourceProvider));
});

class NotificationState {
  final List<AppNotification> notifications;
  final bool isLoading;

  NotificationState({
    this.notifications = const [],
    this.isLoading = false,
  });

  NotificationState copyWith({
    List<AppNotification>? notifications,
    bool? isLoading,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotificationNotifier extends Notifier<NotificationState> {
  NotificationSignalRService? _signalRService;

  @override
  NotificationState build() {
    ref.onDispose(() {
      _signalRService?.disconnect();
    });

    // Start fetching & signalR asynchronously without blocking build
    Future.microtask(() {
      _initSignalR();
      loadNotifications();
    });

    return NotificationState();
  }

  void _initSignalR() {
    final secureStorage = ref.read(secureStorageProvider);
    _signalRService = NotificationSignalRService(
      () => secureStorage.getAccessToken(),
      _handleNewNotification,
    );
    _signalRService?.connect();
  }

  void _handleNewNotification(AppNotification notification) {
    state = state.copyWith(
      notifications: [notification, ...state.notifications],
    );
  }

  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true);
    try {
      final repository = ref.read(notificationRepositoryProvider);
      final data = await repository.getNotifications();
      state = state.copyWith(notifications: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      final repository = ref.read(notificationRepositoryProvider);
      await repository.markAsRead(id);
      final updated = state.notifications.map((n) {
        if (n.id == id) {
          return AppNotification(
            id: n.id,
            userId: n.userId,
            title: n.title,
            message: n.message,
            type: n.type,
            isRead: true,
            createdAt: n.createdAt,
            metadata: n.metadata,
          );
        }
        return n;
      }).toList();
      state = state.copyWith(notifications: updated);
    } catch (e) {
      // Ignore
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final repository = ref.read(notificationRepositoryProvider);
      await repository.markAllAsRead();
      final updated = state.notifications.map((n) {
        return AppNotification(
          id: n.id,
          userId: n.userId,
          title: n.title,
          message: n.message,
          type: n.type,
          isRead: true,
          createdAt: n.createdAt,
          metadata: n.metadata,
        );
      }).toList();
      state = state.copyWith(notifications: updated);
    } catch (e) {
      // Ignore
    }
  }
}

final notificationNotifierProvider =
    NotifierProvider<NotificationNotifier, NotificationState>(() {
  return NotificationNotifier();
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationNotifierProvider).notifications;
  return notifications.where((n) => !n.isRead).length;
});
