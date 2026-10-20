import 'package:signalr_netcore/signalr_client.dart';
import 'package:chore_wars/core/network/api_endpoints.dart';
import 'package:chore_wars/features/chat/data/models/chat_message_model.dart';

class ChatSignalRService {
  HubConnection? _connection;
  final String baseUrl;
  final Future<String> Function() getToken;

  ChatSignalRService({required this.baseUrl, required this.getToken});

  ChatSignalRService fork() =>
      ChatSignalRService(baseUrl: baseUrl, getToken: getToken);

  Future<void> connect(
    String roomId,
    void Function(ChatMessageModel) onMessage, {
    void Function()? onProposalsChanged,
  }) async {
    await disconnect(roomId);
    final hubUrl = '$baseUrl${ApiEndpoints.chatHubUrl}';

    final connection = HubConnectionBuilder()
        .withUrl(
          hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => getToken(),
          ),
        )
        .withAutomaticReconnect()
        .build();

    _connection = connection;
    connection.on('MessageReceived', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final raw = arguments[0];
        if (raw is Map) {
          final messageMap = Map<String, dynamic>.from(raw);
          onMessage(ChatMessageModel.fromJson(messageMap));
        }
      }
    });

    for (final event in ['ReceiveProposal', 'ProposalUpdated']) {
      connection.on(event, (_) => onProposalsChanged?.call());
    }
    connection.onreconnected(({connectionId}) {
      connection.invoke('JoinRoom', args: [roomId]);
    });

    await connection.start();
    await connection.invoke('JoinRoom', args: [roomId]);
  }

  Future<void> sendMessage(String roomId, String content) async {
    if (_connection?.state == HubConnectionState.Connected) {
      await _connection!.invoke('SendMessage', args: [roomId, content]);
    } else {
      throw StateError('Chat is disconnected. Please reconnect and retry.');
    }
  }

  Future<void> disconnect(String roomId) async {
    final connection = _connection;
    _connection = null;
    await connection?.stop();
  }
}
