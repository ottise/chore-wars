import 'package:chore_wars/features/chat/data/models/chat_message_model.dart';
import 'package:chore_wars/features/chat/data/models/chat_room_model.dart';
import 'package:chore_wars/features/chat/data/services/chat_api_service.dart';
import 'package:chore_wars/features/chat/data/services/chat_signalr_service.dart';

class ChatRepository {
  final ChatApiService _apiService;
  final ChatSignalRService _signalRService;
  final Map<String, ChatSignalRService> _rooms = {};

  ChatRepository(this._apiService, this._signalRService);

  Future<ChatRoomModel> getHouseRoom(String houseId) =>
      _apiService.getHouseRoom(houseId);

  Future<({List<ChatMessageModel> items, int totalCount})> getMessages(
    String roomId, {
    int page = 1,
    int pageSize = 30,
  }) => _apiService.getMessages(roomId, page: page, pageSize: pageSize);

  Future<void> connectToHub(
    String roomId,
    void Function(ChatMessageModel) onMessageReceived, {
    void Function()? onProposalsChanged,
  }) => (_rooms.putIfAbsent(
    roomId,
    _signalRService.fork,
  )).connect(roomId, onMessageReceived, onProposalsChanged: onProposalsChanged);

  Future<void> sendMessage(String roomId, String content) =>
      _rooms[roomId]?.sendMessage(roomId, content) ??
      Future.error(StateError('Chat is disconnected'));

  Future<ChatMessageModel> sendMedia(
    String roomId,
    List<int> bytes,
    String filename,
    String clientMessageId,
  ) => _apiService.sendMedia(roomId, bytes, filename, clientMessageId);

  Future<void> disconnectHub(String roomId) =>
      _rooms.remove(roomId)?.disconnect(roomId) ?? Future.value();
}
