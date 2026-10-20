import 'package:signalr_netcore/signalr_client.dart';
import 'package:chore_wars/core/network/api_endpoints.dart';
import 'package:chore_wars/features/chat/data/models/chat_message_model.dart';
import 'package:chore_wars/features/chat/data/models/action_proposal_model.dart';

class ChatSignalRService {
  HubConnection? _connection;
  String? _connectedRoomId;
  final String baseUrl;
  final Future<String> Function() getToken;

  ChatSignalRService({required this.baseUrl, required this.getToken});

  ChatSignalRService fork() =>
      ChatSignalRService(baseUrl: baseUrl, getToken: getToken);

  Future<void> connect(
    String roomId,
    void Function(ChatMessageModel) onMessage, {
    void Function(ActionProposalModel)? onProposalReceived,
    void Function(ActionProposalModel)? onProposalUpdated,
    void Function()? onProposalsChanged,
  }) async {
    // There must only be one live connection per service. Previously each
    // visit to Chat replaced this field without stopping the old connection,
    // leaving orphan connections that all delivered the same message.
    await _stopCurrentConnection();

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

    for (final event in ['ReceiveProposal', 'ProposalUpdated']) {
      connection.on(event, (_) => onProposalsChanged?.call());
    }

    connection.on('MessageReceived', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final raw = arguments[0];
        if (raw is Map) {
          final messageMap = Map<String, dynamic>.from(raw);
          onMessage(ChatMessageModel.fromJson(messageMap));
        }
      }
    });

    connection.on('ReceiveProposal', (arguments) {
      if (arguments != null &&
          arguments.isNotEmpty &&
          onProposalReceived != null) {
        final raw = arguments[0];
        if (raw is Map) {
          final map = Map<String, dynamic>.from(raw);
          onProposalReceived(ActionProposalModel.fromJson(map));
        }
      }
    });

    connection.on('ProposalUpdated', (arguments) {
      if (arguments != null &&
          arguments.isNotEmpty &&
          onProposalUpdated != null) {
        final raw = arguments[0];
        if (raw is Map) {
          final map = Map<String, dynamic>.from(raw);
          onProposalUpdated(ActionProposalModel.fromJson(map));
        }
      }
    });

    connection.onreconnected(({connectionId}) {
      connection.invoke('JoinRoom', args: [roomId]);
    });

    await connection.start();
    await connection.invoke('JoinRoom', args: [roomId]);
    _connectedRoomId = roomId;
  }

  Future<ChatMessageModel> sendMessage(String roomId, String content) async {
    if (_connection?.state == HubConnectionState.Connected) {
      final raw = await _connection!.invoke(
        'SendMessage',
        args: [roomId, content],
      );
      if (raw is Map) {
        return ChatMessageModel.fromJson(Map<String, dynamic>.from(raw));
      }
      throw StateError('The chat server did not return the sent message.');
    }
    throw StateError(
      'Chat is not connected. Please wait a moment and try again.',
    );
  }

  Future<void> disconnect(String roomId) async {
    if (_connectedRoomId == roomId || _connectedRoomId == null) {
      await _stopCurrentConnection();
    }
  }

  Future<void> _stopCurrentConnection() async {
    final connection = _connection;
    final roomId = _connectedRoomId;
    _connection = null;
    _connectedRoomId = null;
    if (connection == null) return;

    if (connection.state == HubConnectionState.Connected) {
      if (roomId != null) {
        try {
          await connection.invoke('LeaveRoom', args: [roomId]);
        } catch (_) {
          // The socket may already be closing; stopping it is still required.
        }
      }
    }
    // Also stop sockets that are connecting or reconnecting. Restricting this
    // to Connected was another way an old listener could survive navigation.
    await connection.stop();
  }
}
