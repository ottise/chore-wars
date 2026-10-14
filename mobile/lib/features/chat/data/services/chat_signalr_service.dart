import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:chore_wars/core/network/api_endpoints.dart';
import 'package:chore_wars/features/chat/data/models/chat_message_model.dart';

class ChatSignalRService {
  HubConnection? _connection;
  final String baseUrl;
  final Future<String> Function() getToken;

  ChatSignalRService({
    required this.baseUrl,
    required this.getToken,
  });

  Future<void> connect(String roomId, void Function(ChatMessageModel) onMessage) async {
    final hubUrl = '$baseUrl${ApiEndpoints.chatHubUrl}';

    _connection = HubConnectionBuilder()
        .withUrl(
          hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => getToken(),
          ),
        )
        .withAutomaticReconnect()
        .build();

    _connection!.on('MessageReceived', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final raw = arguments[0];
        if (raw is Map) {
          final messageMap = Map<String, dynamic>.from(raw);
          onMessage(ChatMessageModel.fromJson(messageMap));
        }
      }
    });

    _connection!.onreconnected(({connectionId}) {
      _connection!.invoke('JoinRoom', args: [roomId]);
    });

    await _connection!.start();
    await _connection!.invoke('JoinRoom', args: [roomId]);
  }

  Future<void> sendMessage(String roomId, String content) async {
    if (_connection?.state == HubConnectionState.Connected) {
      await _connection!.invoke('SendMessage', args: [roomId, content]);
    } else {
      debugPrint('ChatSignalRService: Cannot send message, connection state is ${_connection?.state}');
    }
  }

  Future<void> disconnect(String roomId) async {
    if (_connection?.state == HubConnectionState.Connected) {
      await _connection!.invoke('LeaveRoom', args: [roomId]);
      await _connection!.stop();
    }
  }
}
