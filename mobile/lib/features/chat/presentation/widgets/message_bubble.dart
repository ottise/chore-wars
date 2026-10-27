import 'audio_message_bubble.dart';
import '../../../supplies/presentation/widgets/supply_chat_card.dart';
import '../../domain/chat_mentions.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:chore_wars/core/constants/app_constants.dart';
import 'package:chore_wars/features/chat/data/models/chat_message_model.dart';
import 'package:chore_wars/core/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMe;
  final Map<String, String> memberNames;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.memberNames = const {},
  });

  String _resolveImageUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final root = AppConstants.apiBaseUrl.replaceAll('/api', '');
    return '$root$path';
  }

  @override
  Widget build(BuildContext context) {
    if (message.messageType == 'SUPPLY_CARD') {
      return SupplyChatCard(content: message.content);
    }
    final theme = Theme.of(context);
    final timeFormat = DateFormat('HH:mm');
    final isImage = message.content.startsWith('[IMAGE]');
    final rawImageUrl = isImage ? message.content.substring(7).trim() : null;
    final imageUrl = rawImageUrl != null ? _resolveImageUrl(rawImageUrl) : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: message.senderAvatar != null
                  ? CachedNetworkImageProvider(message.senderAvatar!)
                  : null,
              child: message.senderAvatar == null
                  ? Text(
                      message.senderName.isNotEmpty
                          ? message.senderName[0].toUpperCase()
                          : '?',
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMe) ...[
                  Text(
                    message.senderName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                if (message.messageType == 'AUDIO' &&
                    message.attachmentId != null)
                  AudioMessageBubble(
                    attachmentId: message.attachmentId!,
                    isMe: isMe,
                  )
                else if (message.messageType == 'IMAGE' &&
                    message.attachmentId != null)
                  PrivateImageBubble(attachmentId: message.attachmentId!)
                else if (isImage && imageUrl != null)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => Dialog(
                              insetPadding: const EdgeInsets.all(12),
                              backgroundColor: Colors.transparent,
                              child: InteractiveViewer(
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  placeholder: (_, _) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  errorWidget: (_, _, _) => const Center(
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      size: 48,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 240,
                          height: 240,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 240,
                            height: 240,
                            color: Colors.black12,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 240,
                            height: 140,
                            color: Colors.black12,
                            child: const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: AppTheme.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14.0,
                      vertical: 10.0,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                    ),
                    child: Text(
                      displayChatMentions(message.content, memberNames),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isMe
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  timeFormat.format(message.createdAt.toLocal()),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 24),
        ],
      ),
    );
  }
}
