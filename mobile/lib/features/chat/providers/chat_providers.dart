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
  bool _disposed = false;

  ChatMessagesNotifier(this._repo, this._roomId) {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    _hasError = false;
    _notifySafely();

    try {
      final response = await _repo.getMessages(_roomId, page: 1);
      if (_disposed) return;
      _hasMore = response.items.length == 30;
      _messages = response.items;
      _isLoading = false;
      _notifySafely();
    } catch (e) {
      if (_disposed) return;
      _isLoading = false;
      _hasError = true;
      _notifySafely();
    }
  }

  void receiveMessage(ChatMessageModel message) {
    if (_disposed) return;
    // A reconnect or an accidentally duplicated SignalR subscription can
    // deliver the same persisted message more than once. The server-generated
    // message id is the source of truth, so never add an id twice.
    if (_messages.any((item) => item.id == message.id)) return;
    _messages = [message, ..._messages];
    _notifySafely();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_repo.disconnectHub(_roomId));
    super.dispose();
  }

  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;
    
    _page++;
    
    try {
      final response = await _repo.getMessages(_roomId, page: _page);
      if (_disposed) return;
      _hasMore = response.items.length == 30;
      final existingIds = _messages.map((item) => item.id).toSet();
      _messages = [
        ..._messages,
        ...response.items.where((item) => existingIds.add(item.id)),
      ];
      _notifySafely();
    } catch (e) {
      _page--;
      debugPrint('Error loading more messages: $e');
    }
  }

  Future<void> sendMessage(String content) async {
    final message = await _repo.sendMessage(_roomId, content);
    receiveMessage(message);
  }

  Future<void> sendImage(List<int> bytes, String filename) async {
    final imageUrl = await _repo.uploadImage(bytes, filename);
    final message = await _repo.sendMessage(_roomId, '[IMAGE]$imageUrl');
    receiveMessage(message);
  }

  void _notifySafely() {
    if (!_disposed) notifyListeners();
  }
}

final chatMessagesProvider =
    Provider.autoDispose.family<ChatMessagesNotifier, String>(
  (ref, roomId) {
    final repo = ref.watch(chatRepositoryProvider);
    final notifier = ChatMessagesNotifier(repo, roomId);
    ref.onDispose(() {
      notifier.dispose();
    });
    return notifier;
  },
);
