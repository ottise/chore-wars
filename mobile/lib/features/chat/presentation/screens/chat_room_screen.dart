import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chore_wars/core/utils/api_error_message.dart';
import 'package:chore_wars/features/auth/presentation/providers/auth_providers.dart';
import 'package:chore_wars/features/chat/data/models/action_proposal_model.dart';
import 'package:chore_wars/features/chat/providers/action_proposal_providers.dart';
import 'package:chore_wars/features/chat/providers/chat_providers.dart';
import 'package:chore_wars/features/chat/presentation/widgets/chat_date_separator.dart';
import 'package:chore_wars/features/chat/presentation/widgets/interactive_action_card.dart';
import 'package:chore_wars/features/chat/presentation/widgets/message_bubble.dart';
import 'package:chore_wars/features/chat/presentation/widgets/message_input.dart';
import 'package:chore_wars/features/chat/presentation/widgets/urgent_event_banner.dart';

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
          ref.read(chatMessagesProvider(_roomId!)).loadMore();
        }
      }
    });
  }

  Future<void> _initChat() async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final room = await repo.getHouseRoom(widget.houseId);
      if (mounted) {
        setState(() {
          _roomId = room.id;
          _isLoadingRoom = false;
        });
        await _connectWithProposalCallbacks(room.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRoom = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _connectWithProposalCallbacks(String roomId) async {
    final repo = ref.read(chatRepositoryProvider);

    await repo.connectToHub(
      roomId,
      (message) {
        if (mounted && _roomId == roomId) {
          ref.read(chatMessagesProvider(roomId)).receiveMessage(message);
        }
      },
      onProposalReceived: (proposal) {
        if (mounted) {
          ref.read(actionProposalProvider(roomId).notifier).addProposal(proposal);
        }
      },
      onProposalUpdated: (proposal) {
        if (mounted) {
          ref.read(actionProposalProvider(roomId).notifier).updateProposal(proposal);
        }
      },
    );
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

    final chatNotifier = ref.watch(chatMessagesProvider(_roomId!));
    final currentUser = ref.watch(userProfileProvider).asData?.value;
    final proposalsAsync = ref.watch(actionProposalProvider(_roomId!));

    return Scaffold(
      appBar: AppBar(
        title: const Text('House Chat'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Phát động nhiệm vụ khẩn cấp',
            onPressed: () =>
                context.push('/houses/${widget.houseId}/urgent-event'),
            icon: const Icon(Icons.bolt_rounded),
          ),
        ],
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
          children: [
            if (_activeUrgentEvent(proposalsAsync) case final urgent?)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: UrgentEventBanner(proposal: urgent),
              ),
            _buildActiveProposalsBanner(context, proposalsAsync, currentUser?.id ?? ''),
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

                  if (chatNotifier.messages.isEmpty) {
                    return const Center(child: Text('No messages yet. Say hi!'));
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    itemCount: chatNotifier.messages.length,
                    itemBuilder: (context, index) {
                      final msgIndex = index;
                      final message = chatNotifier.messages[msgIndex];
                      final isMe = message.senderId == currentUser?.id;

                      bool showDateSeparator = false;
                      if (msgIndex == chatNotifier.messages.length - 1) {
                        showDateSeparator = true;
                      } else {
                        final prevMessage = chatNotifier.messages[msgIndex + 1];
                        if (message.createdAt.toLocal().day != prevMessage.createdAt.toLocal().day) {
                          showDateSeparator = true;
                        }
                      }

                      return Column(
                        children: [
                          if (showDateSeparator) ChatDateSeparator(date: message.createdAt),
                          MessageBubble(message: message, isMe: isMe),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            MessageInput(
              onSendMessage: (content) async {
                await ref
                    .read(chatMessagesProvider(_roomId!))
                    .sendMessage(content);
              },
              onSendImage: (bytes, filename) async {
                await ref.read(chatMessagesProvider(_roomId!)).sendImage(bytes, filename);
              },
            ),
          ],
        ),
    );
  }

  Widget _buildActiveProposalsBanner(
    BuildContext context,
    AsyncValue<List<ActionProposalModel>> proposalsAsync,
    String currentUserId,
  ) {
    return proposalsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, e) => const SizedBox.shrink(),
      data: (proposals) {
        final now = DateTime.now();
        final active = proposals
            .where(
              (proposal) =>
                  !proposal.isCompleted ||
                  (proposal.type == ProposalType.urgentEvent &&
                      proposal.status == ProposalStatus.approved &&
                      proposal.expiresAt?.isAfter(now) == true),
            )
            .toList();
        if (active.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  Icon(Icons.pending_actions_rounded,
                      size: 16, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Thẻ tương tác đang chờ (${active.length})',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            ...active.map(
              (p) => InteractiveActionCard(
                proposal: p,
                currentUserId: currentUserId,
              ),
            ),
            const Divider(height: 1),
          ],
        );
      },
    );
  }

  ActionProposalModel? _activeUrgentEvent(
    AsyncValue<List<ActionProposalModel>> proposals,
  ) {
    final now = DateTime.now();
    for (final proposal in proposals.asData?.value ?? const []) {
      if (proposal.type == ProposalType.urgentEvent &&
          proposal.status == ProposalStatus.approved &&
          proposal.expiresAt?.isAfter(now) == true) {
        return proposal;
      }
    }
    return null;
  }
}
