import 'package:signalr_netcore/signalr_client.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/notification_models.dart';

class NotificationSignalRService {
  NotificationSignalRService(this._getToken, this._onNotificationReceived);
  final Future<String?> Function() _getToken;
  final void Function(AppNotification) _onNotificationReceived;
  HubConnection? _connection;
  bool _disposed = false;
  bool _starting = false;
  Future<void> connect() async {
    if (_disposed || _connection != null || _starting) return;
    _starting = true;
    try {
      final token = await _getToken();
      if (_disposed || token == null) return;
      final connection = HubConnectionBuilder()
          .withUrl(
            '${AppConstants.signalRBaseUrl}${ApiEndpoints.notificationsHubUrl}',
            options: HttpConnectionOptions(
              accessTokenFactory: () async => await _getToken() ?? '',
            ),
          )
          .withAutomaticReconnect(retryDelays: [2000, 5000, 10000, 20000])
          .build();
      _connection = connection;
      connection.on('NotificationReceived', (arguments) {
        if (_disposed || arguments == null || arguments.isEmpty) return;
        final raw = arguments.first;
        if (raw is Map) {
          _onNotificationReceived(
            AppNotification.fromJson(Map<String, dynamic>.from(raw)),
          );
        }
      });
      await connection.start();
      if (_disposed || _connection != connection) await connection.stop();
    } catch (_) {
      final failed = _connection;
      _connection = null;
      try {
        await failed?.stop();
      } catch (_) {}
      // HTTP inbox refresh remains available if the realtime transport is offline.
    } finally {
      _starting = false;
    }
  }

  Future<void> disconnect() async {
    _disposed = true;
    final connection = _connection;
    _connection = null;
    try {
      await connection?.stop();
    } catch (_) {
      // A transport may already be closed when a session is revoked.
    }
  }
}
