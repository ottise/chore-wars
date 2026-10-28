import '../../../../core/widgets/app_page_frame.dart';
import '../widgets/voice_note_recorder.dart';
import 'assistant_chat_screen.dart';
import 'chat_photo_history_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chore_wars/core/utils/api_error_message.dart';

import '../../domain/chat_mentions.dart';
import '../../../house/presentation/providers/house_providers.dart';
import '../widgets/chat_notification_button.dart';

import 'package:chore_wars/features/auth/presentation/providers/auth_providers.dart';
import 'package:chore_wars/features/chat/data/models/action_proposal_model.dart';
import 'package:chore_wars/features/chat/providers/action_proposal_providers.dart';
import 'package:chore_wars/features/chat/providers/chat_providers.dart';
import 'package:chore_wars/features/chat/presentation/widgets/chat_date_separator.dart';
import 'package:chore_wars/features/chat/presentation/widgets/interactive_action_card.dart';
import 'package:chore_wars/features/chat/presentation/widgets/message_bubble.dart';
import 'package:chore_wars/features/chat/presentation/widgets/message_input.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String houseId;
  const ChatRoomScreen({required this.houseId, super.key});

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  Future<void> _openAssistant([String? prompt]) async {
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: .95,
        child: AssistantChatScreen(
          houseId: widget.houseId,
          initialPrompt: prompt,
          embedded: true,
        ),
      ),
    );
  }

  final ScrollController _scrollController = ScrollController();
  String? _roomId;
  String? _roomError;
  bool _isLoadingRoom = true;
  int _roomLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _initChat();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (_roomId != null) {
          ref.read(chatMessagesProvider(_roomId!)).loadMore();
        }
      }
    });
  }

  Future<void> _initChat() async {
    final generation = ++_roomLoadGeneration;
    try {
      final repo = ref.read(chatRepositoryProvider);
      final room = await repo.getHouseRoom(widget.houseId);
      if (mounted && generation == _roomLoadGeneration) {
        setState(() {
          _roomId = room.id;
          _isLoadingRoom = false;
        });
      }
    } catch (e) {
      if (mounted && generation == _roomLoadGeneration) {
        setState(() {
          _isLoadingRoom = false;
          _roomError = apiErrorMessage(e);
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant ChatRoomScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId) {
      _roomId = null;
      _isLoadingRoom = true;
      _initChat();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPageFrame(builder: _buildScreen);

  Widget _buildScreen(BuildContext context) {
    if (_isLoadingRoom) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_roomId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Household Chat')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_roomError ?? 'Could not load the household conversation.'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  setState(() => _isLoadingRoom = true);
                  _initChat();
                },
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final chatNotifier = ref.watch(chatMessagesProvider(_roomId!));
    final currentUser = ref.watch(userProfileProvider).asData?.value;
    final members =
        ref.watch(houseMembersProvider(widget.houseId)).asData?.value ?? [];
    final house = ref.watch(houseDetailProvider(widget.houseId)).asData?.value;
    final colors = Theme.of(context).colorScheme;
    final background = colors.surface;
    final names = {
      for (final member in members) member.userId: member.displayName,
    };
    final proposalsAsync = ref.watch(actionProposalProvider(_roomId!));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to Overview',
          onPressed: () => context.go('/houses/${widget.houseId}'),
          icon: const Icon(Icons.arrow_back_outlined, size: 21),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Household Chat',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${house?.name ?? 'My House'}${members.isEmpty ? '' : ' · ${members.where((m) => m.isActive).length} members'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ],
        ),
        backgroundColor: background,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Photo history',
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatPhotoHistoryScreen(roomId: _roomId!),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Ask Assistant',
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: () => _openAssistant(),
          ),
          ChatNotificationButton(houseId: widget.houseId),
        ],
      ),
      backgroundColor: background,
      body: Column(
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: chatNotifier,
              builder: (context, _) {
                if (chatNotifier.isLoading && chatNotifier.messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (chatNotifier.hasError && chatNotifier.messages.isEmpty) {
                  return const Center(child: Text('Error loading messages'));
                }

                // Combine active proposals and messages
                final activeProposals = proposalsAsync.when(
                  loading: () => const <ActionProposalModel>[],
                  error: (_, _) => const <ActionProposalModel>[],
                  data: (proposals) =>
                      proposals.where((p) => !p.isCompleted).toList(),
                );

                final totalItems =
                    activeProposals.length + chatNotifier.messages.length;

                if (totalItems == 0) {
                  return const Center(
                    child: Text('Say hello to your household.'),
                  );
                }
                return Align(
                  alignment: Alignment.topCenter,
                  child: ListView.builder(
                    shrinkWrap: true,
                    controller: _scrollController,
                    reverse: true,
                    itemCount: totalItems,
                    itemBuilder: (context, index) {
                      // Render proposals first
                      if (index < activeProposals.length) {
                        final proposal = activeProposals[index];
                        return InteractiveActionCard(
                          proposal: proposal,
                          currentUserId: currentUser?.id ?? '',
                        );
                      }

                      // Render messages
                      final msgIndex = index - activeProposals.length;
                      final message = chatNotifier.messages[msgIndex];
                      final isMe = message.senderId == currentUser?.id;

                      bool showDateSeparator = false;
                      if (msgIndex == chatNotifier.messages.length - 1) {
                        showDateSeparator = true;
                      } else {
                        final prevMessage = chatNotifier.messages[msgIndex + 1];
                        if (!DateUtils.isSameDay(
                          message.createdAt.toLocal(),
                          prevMessage.createdAt.toLocal(),
                        )) {
                          showDateSeparator = true;
                        }
                      }

                      return Column(
                        children: [
                          if (showDateSeparator)
                            ChatDateSeparator(date: message.createdAt),
                          MessageBubble(
                            message: message,
                            isMe: isMe,
                            memberNames: names,
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
          MessageInput(
            onOpenBounty: () =>
                context.push('/houses/${widget.houseId}/bounties'),
            voiceRecorder: VoiceNoteRecorder(
              onSend: (bytes, filename) => ref
                  .read(chatMessagesProvider(_roomId!))
                  .sendImage(bytes, filename),
            ),
            mentionTargets: [
              const ChatMentionTarget(id: 'agent', label: 'Assistant'),
              const ChatMentionTarget(id: 'all', label: 'Everyone'),
              for (final member in members.where(
                (m) => m.isActive && m.userId != currentUser?.id,
              ))
                ChatMentionTarget(id: member.userId, label: member.displayName),
            ],
            onAgentRequest: (prompt) => _openAssistant(prompt),
            onSendMessage: (content) =>
                ref.read(chatMessagesProvider(_roomId!)).sendMessage(content),
            onSendImage: (bytes, filename) async {
              await ref
                  .read(chatMessagesProvider(_roomId!))
                  .sendImage(bytes, filename);
            },
          ),
        ],
      ),
    );
  }
}
