import 'package:signalr_netcore/signalr_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/notification_models.dart';

class NotificationSignalRService {
  HubConnection? _hubConnection;
  final Future<String?> Function() _getToken;
  final void Function(AppNotification) _onNotificationReceived;

  NotificationSignalRService(
    this._getToken,
    this._onNotificationReceived,
  );

  Future<void> connect() async {
    if (_hubConnection != null &&
        _hubConnection!.state == HubConnectionState.Connected) {
      return;
    }

    final token = await _getToken();
    if (token == null) return;

    final hubUrl = '${AppConstants.signalRBaseUrl}${ApiEndpoints.notificationsHubUrl}?access_token=$token';

    _hubConnection = HubConnectionBuilder()
        .withUrl(hubUrl)
        .withAutomaticReconnect(retryDelays: [2000, 5000, 10000, 20000])
        .build();

    _hubConnection!.on('NotificationReceived', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        try {
          final data = Map<String, dynamic>.from(arguments[0] as Map);
          final notification = AppNotification.fromJson(data);
          _onNotificationReceived(notification);
        } catch (e) {
          // Ignore parsing error
        }
      }
    });

    try {
      await _hubConnection!.start();
    } catch (e) {
      // Ignore start error
    }
  }

  Future<void> disconnect() async {
    if (_hubConnection != null) {
      await _hubConnection!.stop();
      _hubConnection = null;
    }
  }
}
