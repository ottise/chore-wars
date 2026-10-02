import 'package:dio/dio.dart';
import 'package:chore_wars/core/network/api_endpoints.dart';
import 'package:chore_wars/features/chat/data/models/chat_room_model.dart';
import 'package:chore_wars/features/chat/data/models/chat_message_model.dart';

class ChatApiService {
  final Dio _dio;

  ChatApiService(this._dio);

  Future<ChatRoomModel> getHouseRoom(String houseId) async {
    final response = await _dio.get(ApiEndpoints.houseChat(houseId));
    return ChatRoomModel.fromJson(response.data);
  }

  Future<({List<ChatMessageModel> items, int totalCount})> getMessages(String roomId, {int page = 1, int pageSize = 30}) async {
    final response = await _dio.get(
      ApiEndpoints.chatMessages(roomId),
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    
    final items = (response.data['items'] as List)
        .map((e) => ChatMessageModel.fromJson(e))
        .toList();
        
    final totalCount = response.data['totalCount'] as int;
    
    return (items: items, totalCount: totalCount);
  }
}
