import 'package:signalr_netcore/signalr_client.dart';
import 'package:chore_wars/core/network/api_client.dart';
import 'package:chore_wars/core/network/api_endpoints.dart';
import 'package:chore_wars/features/chat/data/models/chat_message_model.dart';

class ChatSignalRService {
  HubConnection? _connection;
  final String _baseUrl;
  final Future<String> Function() _getToken;

  ChatSignalRService({
    required String baseUrl,
    required Future<String> Function() getToken,
  })  : _baseUrl = baseUrl,
        _getToken = getToken;

  Future<void> connect(String roomId, void Function(ChatMessageModel) onMessage) async {
    final hubUrl = '$_baseUrl${ApiEndpoints.chatHubUrl}';

    _connection = HubConnectionBuilder()
        .withUrl(
          hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => _getToken(),
          ),
        )
        .withAutomaticReconnect()
        .build();

    _connection!.on("MessageReceived", (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final messageMap = arguments[0] as Map<String, dynamic>;
        onMessage(ChatMessageModel.fromJson(messageMap));
      }
    });

    _connection!.onreconnected(({connectionId}) {
      _connection!.invoke("JoinRoom", args: [roomId]);
    });

    await _connection!.start();
    await _connection!.invoke("JoinRoom", args: [roomId]);
  }

  Future<void> sendMessage(String roomId, String content) async {
    if (_connection?.state == HubConnectionState.Connected) {
      await _connection!.invoke("SendMessage", args: [roomId, content]);
    }
  }

  Future<void> disconnect(String roomId) async {
    if (_connection?.state == HubConnectionState.Connected) {
      await _connection!.invoke("LeaveRoom", args: [roomId]);
      await _connection!.stop();
    }
  }
}
