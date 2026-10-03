import 'package:flutter/foundation.dart';
import 'dart:async';
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

class ChatMessagesNotifier extends ChangeNotifier {
  final ChatRepository _repo;
  final String _roomId;
  
  List<ChatMessageModel> _messages = [];
  List<ChatMessageModel> get messages => _messages;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _hasError = false;
  bool get hasError => _hasError;

  int _page = 1;
  bool _hasMore = true;

  ChatMessagesNotifier(this._repo, this._roomId) {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      final response = await _repo.getMessages(_roomId, page: 1);
      _hasMore = response.items.length == 30;
      _messages = response.items;
      _isLoading = false;
      notifyListeners();

      await _repo.connectToHub(_roomId, (message) {
        _messages = [message, ..._messages];
        notifyListeners();
      });
    } catch (e) {
      _isLoading = false;
      _hasError = true;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _repo.disconnectHub(_roomId);
    super.dispose();
  }

  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;
    
    _page++;
    
    try {
      final response = await _repo.getMessages(_roomId, page: _page);
      _hasMore = response.items.length == 30;
      _messages = [..._messages, ...response.items];
      notifyListeners();
    } catch (e) {
      _page--;
      print('Error loading more messages: $e');
    }
  }

  Future<void> sendMessage(String content) async {
    await _repo.sendMessage(_roomId, content);
  }
}

final chatMessagesProvider = Provider.family<ChatMessagesNotifier, String>(
  (ref, roomId) {
    final repo = ref.watch(chatRepositoryProvider);
    final notifier = ChatMessagesNotifier(repo, roomId);
    ref.onDispose(() {
      notifier.dispose();
    });
    return notifier;
  },
);
