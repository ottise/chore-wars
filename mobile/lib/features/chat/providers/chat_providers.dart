import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chore_wars/core/network/api_client.dart';
import 'package:chore_wars/core/constants/app_constants.dart';
import 'package:chore_wars/core/storage/secure_storage.dart';
import 'package:chore_wars/features/chat/data/models/chat_message_model.dart';
import 'package:chore_wars/features/chat/data/repositories/chat_repository.dart';
import 'package:chore_wars/features/chat/data/services/chat_api_service.dart';
import 'package:chore_wars/features/chat/data/services/chat_signalr_service.dart';

final chatApiServiceProvider = Provider<ChatApiService>((ref) {
  return ChatApiService(ref.watch(dioProvider));
});

final chatSignalRServiceProvider = Provider<ChatSignalRService>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ChatSignalRService(
    baseUrl: AppConstants.apiBaseUrl,
    getToken: () async => await storage.getAccessToken() ?? '',
  );
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    ref.watch(chatApiServiceProvider),
    ref.watch(chatSignalRServiceProvider),
  );
});

class ChatMessagesNotifier extends StateNotifier<AsyncValue<List<ChatMessageModel>>> {
  final ChatRepository _repo;
  final String _roomId;
  int _page = 1;
  bool _hasMore = true;

  ChatMessagesNotifier(this._repo, this._roomId) : super(const AsyncLoading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final response = await _repo.getMessages(_roomId, page: 1);
      _hasMore = response.items.length == 30;
      state = AsyncData(response.items);

      await _repo.connectToHub(_roomId, (message) {
        final currentList = state.valueOrNull ?? [];
        state = AsyncData([message, ...currentList]);
      });
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  @override
  void dispose() {
    _repo.disconnectHub(_roomId);
    super.dispose();
  }

  Future<void> loadMore() async {
    if (state.isLoading || !_hasMore) return;

    final currentList = state.valueOrNull ?? [];
    _page++;

    try {
      final response = await _repo.getMessages(_roomId, page: _page);
      _hasMore = response.items.length == 30;
      state = AsyncData([...currentList, ...response.items]);
    } catch (e) {
      _page--;
      print('Error loading more messages: $e');
    }
  }

  Future<void> sendMessage(String content) async {
    await _repo.sendMessage(_roomId, content);
  }
}

final chatMessagesProvider = StateNotifierProvider.family<ChatMessagesNotifier, AsyncValue<List<ChatMessageModel>>, String>(
  (ref, roomId) {
    final repo = ref.watch(chatRepositoryProvider);
    return ChatMessagesNotifier(repo, roomId);
  },
);
