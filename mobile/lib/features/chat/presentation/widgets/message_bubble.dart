import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:chore_wars/features/chat/data/models/chat_message_model.dart';
import 'package:chore_wars/core/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMe;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('HH:mm');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: message.senderAvatar != null
                  ? CachedNetworkImageProvider(message.senderAvatar!)
                  : null,
              child: message.senderAvatar == null
                  ? Text(message.senderName[0].toUpperCase())
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe) ...[
                  Text(
                    message.senderName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 12.0),
                  decoration: BoxDecoration(
                    color: isMe ? AppTheme.purple : theme.colorScheme.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 0),
                      bottomRight: Radius.circular(isMe ? 0 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isMe ? Colors.white : AppTheme.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeFormat.format(message.createdAt.toLocal()),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 24), // Spacer for my messages
        ],
      ),
    );
  }
}
