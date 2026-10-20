import '../../../core/storage/session_provider.dart';

import 'package:uuid/uuid.dart';

import 'action_proposal_providers.dart';

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
  ref.watch(sessionEpochProvider);
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
  final void Function() _onProposalsChanged;
  bool _disposed = false;
  bool _loadingMore = false;
  final Map<String, String> _pendingMediaRequests = {};

  List<ChatMessageModel> _messages = [];
  List<ChatMessageModel> get messages => _messages;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _hasError = false;
  bool get hasError => _hasError;

  int _page = 1;
  bool _hasMore = true;

  ChatMessagesNotifier(this._repo, this._roomId, this._onProposalsChanged) {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      final response = await _repo.getMessages(_roomId, page: 1);
      if (_disposed) return;
      _hasMore = response.items.length == 30;
      _messages = response.items;
      _isLoading = false;
      notifyListeners();

      await _repo.connectToHub(_roomId, (message) {
        if (_disposed) return;
        _messages = [message, ..._messages.where((m) => m.id != message.id)];
        notifyListeners();
      }, onProposalsChanged: _onProposalsChanged);
      if (_disposed) await _repo.disconnectHub(_roomId);
    } catch (e) {
      if (_disposed) return;
      _isLoading = false;
      _hasError = true;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_repo.disconnectHub(_roomId));
    super.dispose();
  }

  Future<void> loadMore() async {
    if (_disposed || _isLoading || _loadingMore || !_hasMore) return;
    _loadingMore = true;

    _page++;

    try {
      final response = await _repo.getMessages(_roomId, page: _page);
      if (_disposed) return;
      _hasMore = response.items.length == 30;
      _messages = [
        ..._messages,
        ...response.items.where(
          (message) => !_messages.any((m) => m.id == message.id),
        ),
      ];
      notifyListeners();
    } catch (e) {
      _page--;
      debugPrint('Error loading more messages: $e');
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> sendMessage(String content) async {
    await _repo.sendMessage(_roomId, content);
  }

  Future<void> sendImage(List<int> bytes, String filename) async {
    final fingerprint = '$filename:${bytes.length}:${Object.hashAll(bytes)}';
    final clientId = _pendingMediaRequests.putIfAbsent(
      fingerprint,
      () => const Uuid().v4(),
    );
    final message = await _repo.sendMedia(_roomId, bytes, filename, clientId);
    _pendingMediaRequests.remove(fingerprint);
    if (_disposed) return;
    _messages = [message, ..._messages.where((m) => m.id != message.id)];
    notifyListeners();
  }
}

final chatMessagesProvider = Provider.autoDispose
    .family<ChatMessagesNotifier, String>((ref, roomId) {
      final repo = ref.watch(chatRepositoryProvider);
      final notifier = ChatMessagesNotifier(
        repo,
        roomId,
        () => ref.invalidate(actionProposalProvider(roomId)),
      );
      ref.onDispose(() {
        notifier.dispose();
      });
      return notifier;
    });
