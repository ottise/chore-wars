import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chore_wars/core/theme/app_theme.dart';
import 'package:chore_wars/features/auth/presentation/providers/auth_providers.dart';
import 'package:chore_wars/features/chat/providers/chat_providers.dart';
import 'package:chore_wars/features/chat/presentation/widgets/message_bubble.dart';
import 'package:chore_wars/features/chat/presentation/widgets/message_input.dart';
import 'package:chore_wars/features/chat/presentation/widgets/chat_date_separator.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String houseId;
  const ChatRoomScreen({required this.houseId, super.key});

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final ScrollController _scrollController = ScrollController();
  String? _roomId;
  bool _isLoadingRoom = true;

  @override
  void initState() {
    super.initState();
    _initChat();
    
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (_roomId != null) {
          ref.read(chatMessagesProvider(_roomId!).notifier).loadMore();
        }
      }
    });
  }

  Future<void> _initChat() async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final room = await repo.getHouseRoom(widget.houseId);
      setState(() {
        _roomId = room.id;
        _isLoadingRoom = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingRoom = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load chat room: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRoom) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_roomId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat Error')),
        body: const Center(child: Text('Could not load chat room')),
      );
    }

    final chatState = ref.watch(chatMessagesProvider(_roomId!));
    final currentUser = ref.watch(userProfileProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('House Chat'),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
      ),
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          Expanded(
            child: chatState.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet. Say hi!'));
                }
                
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUser?.id;
                    
                    bool showDateSeparator = false;
                    if (index == messages.length - 1) {
                      showDateSeparator = true;
                    } else {
                      final prevMessage = messages[index + 1];
                      if (message.createdAt.toLocal().day != prevMessage.createdAt.toLocal().day) {
                        showDateSeparator = true;
                      }
                    }

                    return Column(
                      children: [
                        if (showDateSeparator) 
                          ChatDateSeparator(date: message.createdAt),
                        MessageBubble(message: message, isMe: isMe),
                      ],
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ),
          MessageInput(
            onSendMessage: (content) {
              ref.read(chatMessagesProvider(_roomId!).notifier).sendMessage(content);
            },
          ),
        ],
      ),
    );
  }
}
