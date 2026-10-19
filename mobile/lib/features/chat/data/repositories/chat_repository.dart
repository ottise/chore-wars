import 'package:chore_wars/features/chat/data/models/action_proposal_model.dart';
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
    String roomId,
    void Function(ChatMessageModel) onMessageReceived, {
    void Function(ActionProposalModel)? onProposalReceived,
    void Function(ActionProposalModel)? onProposalUpdated,
  }) =>
      _signalRService.connect(
        roomId,
        onMessageReceived,
        onProposalReceived: onProposalReceived,
        onProposalUpdated: onProposalUpdated,
      );

  Future<ChatMessageModel> sendMessage(String roomId, String content) =>
      _signalRService.sendMessage(roomId, content);

  Future<String> uploadImage(List<int> bytes, String filename) =>
      _apiService.uploadImage(bytes, filename);

  Future<void> disconnectHub(String roomId) =>
      _signalRService.disconnect(roomId);
}
