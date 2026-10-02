import 'package:chore_wars/features/chat/data/models/chat_message_model.dart';
import 'package:chore_wars/features/chat/data/models/chat_room_model.dart';
import 'package:chore_wars/features/chat/data/services/chat_api_service.dart';
import 'package:chore_wars/features/chat/data/services/chat_signalr_service.dart';

class ChatRepository {
  final ChatApiService _apiService;
  final ChatSignalRService _signalRService;

  ChatRepository(this._apiService, this._signalRService);

  Future<ChatRoomModel> getHouseRoom(String houseId) =>
      _apiService.getHouseRoom(houseId);

  Future<({List<ChatMessageModel> items, int totalCount})> getMessages(
          String roomId,
          {int page = 1,
          int pageSize = 30}) =>
      _apiService.getMessages(roomId, page: page, pageSize: pageSize);

  Future<void> connectToHub(
          String roomId, void Function(ChatMessageModel) onMessageReceived) =>
      _signalRService.connect(roomId, onMessageReceived);

  Future<void> sendMessage(String roomId, String content) =>
      _signalRService.sendMessage(roomId, content);

  Future<void> disconnectHub(String roomId) =>
      _signalRService.disconnect(roomId);
}
