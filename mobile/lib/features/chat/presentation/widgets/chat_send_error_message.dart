import 'package:signalr_netcore/errors.dart';

import '../../../../core/utils/api_error_message.dart';

String chatSendErrorMessage(Object error) {
  if (error is StateError) {
    return 'Chat is disconnected. Reopen the conversation and retry; your draft is saved.';
  }
  if (error is GeneralError) {
    final message = (error.message ?? '').toLowerCase();
    if (message.contains('unknown hub method') ||
        message.contains('method does not exist')) {
      return 'Chat requires a backend update. Restart the backend and reopen the conversation.';
    }
    if (message.contains('only active members')) {
      return 'The mentioned member has left the house. Remove the mention and retry.';
    }
    if (message.contains('not a member')) {
      return 'You no longer have permission to send messages here. Return to the house list.';
    }
    if (message.contains('archived households')) {
      return 'This house is archived and cannot receive new messages.';
    }
    return 'Unable to send the message. Reopen the conversation and retry; your draft is saved.';
  }
  return apiErrorMessage(error);
}
