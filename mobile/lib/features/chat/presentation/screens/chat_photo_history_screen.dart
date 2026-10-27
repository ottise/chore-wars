import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/session_provider.dart';
import '../../../../core/widgets/app_page_bar.dart';
import '../../../../core/widgets/app_page_frame.dart';
import '../../data/models/chat_message_model.dart';
import '../widgets/audio_message_bubble.dart';

final chatPhotoPageProvider = FutureProvider.autoDispose
    .family<
      ({List<ChatMessageModel> items, int total}),
      ({String roomId, int page})
    >((ref, key) async {
      ref.watch(sessionEpochProvider);
      final response = await ref
          .watch(dioProvider)
          .get(
            '/chat/rooms/${key.roomId}/photos',
            queryParameters: {'page': key.page, 'pageSize': 24},
          );
      return (
        items: (response.data['items'] as List)
            .map((e) => ChatMessageModel.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        total: response.data['totalCount'] as int,
      );
    });

class ChatPhotoHistoryScreen extends ConsumerStatefulWidget {
  const ChatPhotoHistoryScreen({required this.roomId, super.key});
  final String roomId;
  @override
  ConsumerState<ChatPhotoHistoryScreen> createState() =>
      _ChatPhotoHistoryScreenState();
}

class _ChatPhotoHistoryScreenState
    extends ConsumerState<ChatPhotoHistoryScreen> {
  int page = 1;
  @override
  Widget build(BuildContext context) {
    final key = (roomId: widget.roomId, page: page);
    return AppPageFrame(
      builder: (context) => Scaffold(
        appBar: const AppPageBar(title: 'Photo history'),
        body: ref
            .watch(chatPhotoPageProvider(key))
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(chatPhotoPageProvider(key)),
                  child: const Text('Unable to load photos. Retry'),
                ),
              ),
              data: (result) => result.total == 0
                  ? const Center(
                      child: Text('No photos shared in this chat yet.'),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            '${result.total} shared photos · newest first',
                          ),
                        ),
                        Expanded(
                          child: GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: .75,
                                ),
                            itemCount: result.items.length,
                            itemBuilder: (context, i) {
                              final photo = result.items[i];
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Center(
                                          child: PrivateImageBubble(
                                            attachmentId: photo.attachmentId!,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        photo.senderName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        DateFormat.MMMd().add_jm().format(
                                          photo.createdAt.toLocal(),
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        SafeArea(
                          top: false,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton(
                                onPressed: page > 1
                                    ? () => setState(() => page--)
                                    : null,
                                child: const Text('Previous'),
                              ),
                              Text('Page $page'),
                              TextButton(
                                onPressed: page * 24 < result.total
                                    ? () => setState(() => page++)
                                    : null,
                                child: const Text('Next'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
      ),
    );
  }
}
