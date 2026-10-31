import '../../../../core/storage/session_provider.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../bounty/presentation/providers/bounty_providers.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/datasources/notification_remote_data_source.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../../data/services/notification_signalr_service.dart';
import '../../domain/entities/notification_models.dart';

final notificationRemoteDataSourceProvider =
    Provider<NotificationRemoteDataSource>((ref) {
      return NotificationRemoteDataSourceImpl(ref.watch(dioProvider));
    });

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl(
    ref.watch(notificationRemoteDataSourceProvider),
  );
});

class NotificationState {
  const NotificationState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
    this.latestArrival,
    this.bountyBoardEpoch = 0,
  });
  final List<AppNotification> notifications;
  final bool isLoading;
  final String? error;
  final AppNotification? latestArrival;
  final int bountyBoardEpoch;
}

class NotificationNotifier extends Notifier<NotificationState> {
  NotificationSignalRService? _realtime;
  int _generation = 0;
  bool _current(int generation) => ref.mounted && generation == _generation;
  @override
  NotificationState build() {
    ref.watch(sessionEpochProvider);
    final generation = ++_generation;
    NotificationSignalRService? service;
    ref.onDispose(() {
      service?.disconnect();
    });
    Future.microtask(() {
      if (!_current(generation)) return;
      service = NotificationSignalRService(
        () => ref.read(secureStorageProvider).getAccessToken(),
        (notification) {
          if (!_current(generation)) return;
          if (notification.houseId != null &&
              notification.houseId!.isNotEmpty) {
            ref.invalidate(bountyBoardProvider(notification.houseId!));
          } else {
            ref.invalidate(bountyBoardProvider);
          }
          if (state.notifications.any((n) => n.id == notification.id)) return;
          state = NotificationState(
            latestArrival: notification,
            bountyBoardEpoch: state.bountyBoardEpoch + 1,
            notifications: [
              notification,
              ...state.notifications.where((n) => n.id != notification.id),
            ],
          );
        },
        onChatUnreadChanged: (house) {
          if (_current(generation)) {
            if (house.isEmpty) {
              ref.invalidate(chatUnreadRequestProvider);
            } else {
              ref.invalidate(chatUnreadRequestProvider(house));
            }
          }
        },
        onBountyBoardChanged: (house) {
          if (_current(generation)) {
            if (house.isEmpty) {
              ref.invalidate(bountyBoardProvider);
            } else {
              ref.invalidate(bountyBoardProvider(house));
            }
            ref.invalidate(bountyDetailProvider);
            state = NotificationState(
              notifications: state.notifications,
              isLoading: state.isLoading,
              error: state.error,
              latestArrival: state.latestArrival,
              bountyBoardEpoch: state.bountyBoardEpoch + 1,
            );
          }
        },
      );
      _realtime = service;
      loadNotifications();
    });
    return const NotificationState();
  }

  Future<void> loadNotifications() async {
    _realtime?.connect();
    final generation = _generation;
    final existingIds = state.notifications.map((n) => n.id).toSet();
    state = NotificationState(
      notifications: state.notifications,
      isLoading: true,
      bountyBoardEpoch: state.bountyBoardEpoch,
    );
    try {
      final data = await ref
          .read(notificationRepositoryProvider)
          .getNotifications();
      if (_current(generation)) {
        final arrivals = state.notifications
            .where((n) => !existingIds.contains(n.id))
            .toList();
        final arrivalIds = arrivals.map((n) => n.id).toSet();
        state = NotificationState(
          bountyBoardEpoch: state.bountyBoardEpoch,
          notifications: [
            ...arrivals,
            ...data.where((n) => !arrivalIds.contains(n.id)),
          ],
        );
      }
    } catch (error) {
      if (_current(generation)) {
        state = NotificationState(
          notifications: state.notifications,
          error: apiErrorMessage(error),
          bountyBoardEpoch: state.bountyBoardEpoch,
        );
      }
    }
  }

  Future<void> markAsRead(String id) async {
    final generation = _generation;
    await ref.read(notificationRepositoryProvider).markAsRead(id);
    if (_current(generation)) {
      state = NotificationState(
        bountyBoardEpoch: state.bountyBoardEpoch,
        notifications: state.notifications
            .map((n) => n.id == id ? n.asRead() : n)
            .toList(),
      );
    }
  }

  Future<void> markAllAsRead() async {
    final generation = _generation;
    await ref.read(notificationRepositoryProvider).markAllAsRead();
    if (_current(generation)) {
      state = NotificationState(
        bountyBoardEpoch: state.bountyBoardEpoch,
        notifications: state.notifications
            .map((n) => (n.isChat || n.isTaskRequest) ? n : n.asRead())
            .toList(),
      );
    }
  }
}

final notificationNotifierProvider =
    NotifierProvider<NotificationNotifier, NotificationState>(
      NotificationNotifier.new,
    );
final unreadNotificationCountProvider = Provider<int>(
  (ref) => ref
      .watch(notificationNotifierProvider)
      .notifications
      .where((n) => !n.isChat && !n.isTaskRequest && !n.isRead)
      .length,
);
final chatUnreadRequestProvider = FutureProvider.autoDispose
    .family<int, String>((ref, houseId) async {
      ref.watch(sessionEpochProvider);
      ref.watch(notificationNotifierProvider.select((s) => s.latestArrival));
      final response = await ref
          .watch(dioProvider)
          .get('/houses/$houseId/chat/unread');
      return (response.data['count'] as num).toInt();
    }, retry: (_, _) => null);
final unreadChatCountProvider = Provider.family<int, String>(
  (ref, houseId) =>
      ref.watch(chatUnreadRequestProvider(houseId)).asData?.value ?? 0,
);
final unreadHouseNotificationCountProvider = Provider.family<int, String>(
  (ref, houseId) => ref
      .watch(notificationNotifierProvider)
      .notifications
      .where(
        (n) =>
            !n.isChat && !n.isTaskRequest && n.houseId == houseId && !n.isRead,
      )
      .length,
);

final unreadAssistantCountProvider = Provider.family<int, String>(
  (ref, houseId) => ref
      .watch(notificationNotifierProvider)
      .notifications
      .where((n) => n.isTaskRequest && n.houseId == houseId && !n.isRead)
      .length,
);
