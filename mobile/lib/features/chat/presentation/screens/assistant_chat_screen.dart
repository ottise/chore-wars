import '../../../../core/widgets/app_page_frame.dart';
import '../../../supplies/presentation/widgets/ai_supply_draft_card.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ai/data/ai_repository.dart';
import '../../../ai/presentation/ai_availability_review_screen.dart';
import '../../../ai/presentation/ai_voice_controls.dart';
import '../../../house/presentation/providers/house_providers.dart';
import '../widgets/ai_urgent_plan_card.dart';
import '../widgets/assistant_requests.dart';

class AssistantChatScreen extends ConsumerStatefulWidget {
  const AssistantChatScreen({
    required this.houseId,
    this.initialPrompt,
    this.urgentMode = false,
    this.embedded = false,
    super.key,
  });
  final String houseId;
  final String? initialPrompt;
  final bool urgentMode;
  final bool embedded;

  @override
  ConsumerState<AssistantChatScreen> createState() =>
      _AssistantChatScreenState();
}

class _AssistantChatScreenState extends ConsumerState<AssistantChatScreen> {
  final _input = TextEditingController();
  final _messages =
      <
        ({
          bool mine,
          String text,
          Map<String, dynamic>? availability,
          Map<String, dynamic>? urgent,
          Map<String, dynamic>? supply,
          DateTime at,
        })
      >[];
  bool _busy = false;
  String? _error;
  String? _pendingRequestPrompt;

  @override
  void initState() {
    super.initState();
    if (widget.urgentMode) {
      _input.text = 'Plan an urgent household task. ';
    }
    if (widget.initialPrompt?.trim().isNotEmpty == true) {
      _input.text = widget.initialPrompt!;
      Future.microtask(_send);
    }
  }

  Future<void> _send() async {
    final prompt = _input.text.trim();
    if (!mounted || _busy || prompt.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = ref.read(aiRepositoryProvider);
      final requestText = _pendingRequestPrompt == null
          ? prompt
          : 'Original household request: $_pendingRequestPrompt\nAdditional details: $prompt';
      final response = await repository.post(widget.houseId, 'interpret', {
        'text': requestText,
      });
      if (!mounted) return;
      final missing = response['missing_fields'] as List? ?? [];
      final summary = response['summary']?.toString().trim() ?? '';
      if (summary.isEmpty) {
        throw const FormatException('Missing assistant reply');
      }
      _pendingRequestPrompt =
          [
                'urgent',
                'supply_purchase',
                'supply_reminder',
              ].contains(response['intent']) &&
              missing.isNotEmpty
          ? requestText
          : null;
      setState(() {
        _messages.insertAll(0, [
          (
            mine: false,
            at: DateTime.now(),
            text:
                '$summary${missing.isEmpty ? '' : '\nPlease add the missing details and send again.'}',
            availability: response['availability'] is Map
                ? Map<String, dynamic>.from(response['availability'] as Map)
                : null,
            supply: missing.isEmpty && response['supply'] is Map
                ? Map<String, dynamic>.from(response['supply'] as Map)
                : null,
            urgent:
                response['intent'] == 'urgent' &&
                    missing.isEmpty &&
                    response['urgent'] is Map
                ? {
                    ...Map<String, dynamic>.from(response['urgent'] as Map),
                    'prompt': requestText,
                  }
                : null,
          ),
          (
            mine: true,
            text: prompt,
            availability: null,
            urgent: null,
            supply: null,
            at: DateTime.now(),
          ),
        ]);
        _input.clear();
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = 'Your message could not be sent. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPageFrame(builder: _buildScreen);

  Widget _buildScreen(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final house = ref.watch(houseDetailProvider(widget.houseId)).asData?.value;
    final intro =
        _messages.isEmpty && MediaQuery.viewInsetsOf(context).bottom == 0;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to Chat',
          onPressed: () => widget.embedded
              ? Navigator.of(context).pop()
              : context.go('/houses/${widget.houseId}/chat'),
          icon: const Icon(Icons.arrow_back_outlined, size: 21),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Assistant',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              house?.name ?? 'Private Conversation',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              reverse: !intro,
              child: Column(
                children: [
                  AssistantRequests(houseId: widget.houseId),
                  if (intro)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colors.outlineVariant.withValues(alpha: .3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 17,
                              backgroundColor: colors.primaryFixed,
                              foregroundColor: colors.onPrimaryFixedVariant,
                              child: const Icon(
                                Icons.auto_awesome_outlined,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your Private Assistant',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Type or speak a task request. For a party, include its time, guest count and household participants. AI prepares the plan and sends requests for participants to approve. Photo attachments are not available in Assistant yet.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.5,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (intro)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          children: [
                            for (final suggestion in [
                              (
                                label: 'Plan Urgent Tasks',
                                text: 'Plan an urgent cleanup within 60 minutes with ',
                              ),
                              (
                                label: 'Report Unavailability',
                                text: 'I am busy tomorrow from 7 PM to 9 PM.',
                              ),
                              (
                                label: 'Update Availability',
                                text: 'I am available on Sunday from 8 AM to 11 AM.',
                              ),
                            ])
                              ActionChip(
                                label: Text(suggestion.label),
                                onPressed: _busy
                                    ? null
                                    : () {
                                        _input.text = suggestion.text;
                                        _input.selection =
                                            TextSelection.collapsed(
                                              offset: _input.text.length,
                                            );
                                      },
                              ),
                          ],
                        ),
                      ),
                    ),
                  _messages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'How can your assistant help today?',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          ),
                        )
                      : ListView.builder(
                          reverse: true,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          findChildIndexCallback: (key) {
                            final index = _messages.indexWhere(
                              (message) =>
                                  ValueKey((message.at, message.mine)) == key,
                            );
                            return index < 0 ? null : index;
                          },
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            return Padding(
                              key: ValueKey((message.at, message.mine)),
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                mainAxisAlignment: message.mine
                                    ? MainAxisAlignment.end
                                    : MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!message.mine) ...[
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: colors.primary,
                                      foregroundColor: colors.onPrimary,
                                      child: const Icon(
                                        Icons.auto_awesome_outlined,
                                        size: 15,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Flexible(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 460,
                                      ),
                                      child: Column(
                                        crossAxisAlignment: message.mine
                                            ? CrossAxisAlignment.end
                                            : CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: message.mine
                                                  ? colors.primaryContainer
                                                  : colors
                                                        .surfaceContainerLowest,
                                              borderRadius: BorderRadius.only(
                                                topLeft: Radius.circular(
                                                  message.mine ? 20 : 4,
                                                ),
                                                topRight: const Radius.circular(
                                                  20,
                                                ),
                                                bottomLeft:
                                                    const Radius.circular(20),
                                                bottomRight: Radius.circular(
                                                  message.mine ? 4 : 20,
                                                ),
                                              ),
                                              border: message.mine
                                                  ? null
                                                  : Border.all(
                                                      color: colors
                                                          .outlineVariant
                                                          .withValues(
                                                            alpha: .3,
                                                          ),
                                                    ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  message.text,
                                                  style: TextStyle(
                                                    color: message.mine
                                                        ? colors
                                                              .onPrimaryContainer
                                                        : colors.onSurface,
                                                    height: 1.5,
                                                  ),
                                                ),
                                                if (message.urgent != null)
                                                  AiUrgentPlanCard(
                                                    houseId: widget.houseId,
                                                    prompt:
                                                        message.urgent!['prompt']
                                                            as String,
                                                    candidate: message.urgent!,
                                                  ),
                                                if (message.supply != null)
                                                  AiSupplyDraftCard(
                                                    houseId: widget.houseId,
                                                    candidate: message.supply!,
                                                  ),
                                                if (message.availability !=
                                                    null)
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          context,
                                                        ).push(
                                                          MaterialPageRoute(
                                                            builder: (_) =>
                                                                AiAvailabilityReviewScreen(
                                                                  houseId: widget
                                                                      .houseId,
                                                                  candidate: message
                                                                      .availability!,
                                                                ),
                                                          ),
                                                        ),
                                                    child: const Text(
                                                      'Review Availability',
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            '${message.mine ? 'You' : 'Assistant'} · ${TimeOfDay.fromDateTime(message.at).format(context)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: colors.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 90),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(_error!, style: TextStyle(color: colors.error)),
                  ),
                ),
              ),
            ),
          if (_error != null)
            TextButton(
              onPressed: _busy ? null : _send,
              child: const Text('Retry'),
            ),
          Material(
            color: colors.surfaceContainerLowest,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AiVoiceControls(
                        controller: _input,
                        summary:
                            _messages.where((m) => !m.mine).firstOrNull?.text ??
                            '',
                        disabled: _busy,
                        compact: true,
                        speechLocale: 'vi-VN',
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _input,
                            enabled: !_busy,
                            maxLength: 1700,
                            minLines: 1,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: 'Message your assistant…',
                              counterText: '',
                              fillColor: colors.surfaceContainerLow,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: 'Send to Assistant',
                          onPressed: _busy ? null : _send,
                          icon: Icon(
                            Icons.send_outlined,
                            size: 21,
                            color: _busy ? null : colors.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
