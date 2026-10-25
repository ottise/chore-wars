import '../../../../core/widgets/app_page_frame.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chore_wars/core/utils/api_error_message.dart';

import '../screens/capture_photo_screen.dart';
import '../../domain/chat_mentions.dart';
import 'chat_send_error_message.dart';

class MessageInput extends StatefulWidget {
  final Future<void> Function(String) onSendMessage;
  final Future<void> Function(List<int> bytes, String filename)? onSendImage;
  final Widget? voiceRecorder;
  final VoidCallback? onOpenBounty;
  final List<ChatMentionTarget> mentionTargets;
  final Future<void> Function(String)? onAgentRequest;

  const MessageInput({
    super.key,
    required this.onSendMessage,
    this.onSendImage,
    this.voiceRecorder,
    this.onOpenBounty,
    this.mentionTargets = const [],
    this.onAgentRequest,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isComposing = false;
  bool _isUploading = false;
  List<int>? _pendingImage;
  String? _pendingFilename;
  bool _imageFailed = false;
  String? _sendError;
  final Map<String, ChatMentionTarget> _mentions = {};
  bool _mentionPickerOpen = false;

  Future<void> _chooseMention({bool replaceAt = false}) async {
    if (_isUploading || _mentionPickerOpen) return;
    _mentionPickerOpen = true;
    FocusScope.of(context).unfocus();
    final target = await showModalBottomSheet<ChatMentionTarget>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .55,
          child: ListView(
            children: [
              const ListTile(
                title: Text('Mention'),
                subtitle: Text('Choose the assistant, everyone or a member'),
              ),
              for (final item in widget.mentionTargets)
                ListTile(
                  title: Text('@${item.label}'),
                  selected: _mentions.containsKey(item.id),
                  onTap: () => Navigator.pop(context, item),
                ),
            ],
          ),
        ),
      ),
    );
    _mentionPickerOpen = false;
    if (!mounted || target == null) return;
    if (replaceAt && _controller.text.endsWith('@')) {
      final value = _controller.text.substring(0, _controller.text.length - 1);
      _controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
    setState(() => _mentions[target.id] = target);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitted(String text) async {
    if ((text.trim().isEmpty && _mentions.isEmpty) || _isUploading) return;
    setState(() {
      _isUploading = true;
      _sendError = null;
    });
    try {
      final content =
          '${_mentions.values.map((m) => m.token).join(' ')} ${text.trim()}'
              .trim();
      final agent = chatAgentMentionPattern.hasMatch(content);
      if (content.length > 2000) {
        setState(
          () => _sendError =
              'Messages and mentions can contain up to 2,000 characters.',
        );
        return;
      }
      await widget.onSendMessage(content);
      if (!mounted) return;
      _controller.clear();
      setState(() {
        _isComposing = false;
        _mentions.clear();
        _isUploading = false;
      });
      final prompt = chatAgentPrompt(
        content,
        memberNames: {
          for (final member in widget.mentionTargets) member.id: member.label,
        },
      );
      if (agent && prompt.isNotEmpty && widget.onAgentRequest != null) {
        await widget.onAgentRequest!(prompt);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _sendError = chatSendErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    if (widget.onSendImage == null || _isUploading) return;
    setState(() {
      _isUploading = true;
      _sendError = null;
    });
    try {
      final photo = source == ImageSource.camera
          ? await Navigator.of(context, rootNavigator: true).push<XFile>(
              MaterialPageRoute(builder: (_) => const CapturePhotoScreen()),
            )
          : await _picker.pickImage(
              source: source,
              maxWidth: 1280,
              maxHeight: 1280,
              imageQuality: 85,
            );

      if (photo != null) {
        if (!mounted) return;
        final bytes = await photo.readAsBytes();
        if (!mounted) return;
        if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
          throw StateError('Photo size must be between 1 byte and 5 MB.');
        }
        _pendingImage = bytes;
        _pendingFilename = photo.name;
        await _sendPendingImage();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sendError = apiErrorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _sendPendingImage() async {
    final bytes = _pendingImage;
    if (bytes == null) return;
    setState(() {
      _isUploading = true;
      _imageFailed = false;
      _sendError = null;
    });
    try {
      await widget.onSendImage!(bytes, _pendingFilename!);
      _pendingImage = null;
      _pendingFilename = null;
    } catch (error) {
      if (mounted) {
        setState(() {
          _imageFailed = true;
          _sendError = apiErrorMessage(error);
        });
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final canPick =
        !_isUploading && _pendingImage == null && widget.onSendImage != null;
    return Material(
      color: colors.surfaceContainerLowest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_sendError != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 80),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _sendError!,
                          style: TextStyle(color: colors.error, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_mentions.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 4,
                    children: [
                      for (final target in _mentions.values)
                        InputChip(
                          label: Text('@${target.label}'),
                          onDeleted: _isUploading
                              ? null
                              : () =>
                                    setState(() => _mentions.remove(target.id)),
                        ),
                    ],
                  ),
                ),
              if (_imageFailed)
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Unable to send photo.'),
                    TextButton(
                      onPressed: _isUploading ? null : _sendPendingImage,
                      child: const Text('Retry'),
                    ),
                    TextButton(
                      onPressed: _isUploading
                          ? null
                          : () => setState(() {
                              _pendingImage = null;
                              _pendingFilename = null;
                              _imageFailed = false;
                            }),
                      child: const Text('Remove Photo'),
                    ),
                  ],
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 2,
                  children: [
                    if (widget.mentionTargets.any(
                      (target) => target.id == 'all',
                    ))
                      TextButton(
                        key: const ValueKey('chat-mention-all'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          backgroundColor: _mentions.containsKey('all')
                              ? colors.primaryFixed
                              : colors.surfaceContainerLow,
                          foregroundColor: colors.onPrimaryFixedVariant,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: AppPageFrame.fontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: _isUploading
                            ? null
                            : () => setState(() {
                                if (_mentions.containsKey('all')) {
                                  _mentions.remove('all');
                                } else {
                                  final target = widget.mentionTargets
                                      .firstWhere(
                                        (target) => target.id == 'all',
                                      );
                                  _mentions[target.id] = target;
                                }
                              }),
                        child: const Text('@Everyone'),
                      ),
                    Tooltip(
                      message: 'Choose Photo',
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: const TextStyle(
                            fontFamily: AppPageFrame.fontFamily,
                            fontSize: 12,
                          ),
                        ),
                        onPressed: canPick
                            ? () => _pickAndSendImage(ImageSource.gallery)
                            : null,
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          size: 16,
                        ),
                        label: const Text('Photo'),
                      ),
                    ),
                    if (widget.onOpenBounty != null)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: const TextStyle(
                            fontFamily: AppPageFrame.fontFamily,
                            fontSize: 12,
                          ),
                        ),
                        onPressed: _isUploading ? null : widget.onOpenBounty,
                        icon: const Icon(
                          Icons.card_giftcard_outlined,
                          size: 16,
                        ),
                        label: const Text('Bounty'),
                      ),
                    if (widget.mentionTargets.isNotEmpty)
                      IconButton(
                        tooltip: 'Mention',
                        onPressed: _isUploading ? null : _chooseMention,
                        icon: const Text(
                          '@',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (widget.voiceRecorder != null) widget.voiceRecorder!,
                  ],
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Take Photo',
                    onPressed: canPick
                        ? () => _pickAndSendImage(ImageSource.camera)
                        : null,
                    icon: const Icon(Icons.camera_alt_outlined, size: 21),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_isUploading,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 1700,
                      maxLines: 4,
                      minLines: 1,
                      onChanged: (text) {
                        setState(() => _isComposing = text.trim().isNotEmpty);
                        if (text.endsWith('@') &&
                            widget.mentionTargets.isNotEmpty) {
                          _chooseMention(replaceAt: true);
                        }
                      },
                      onSubmitted: _handleSubmitted,
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: _isUploading
                            ? 'Sending…'
                            : 'Message your household…',
                        fillColor: colors.surfaceContainerLow,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (_isUploading)
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    IconButton.filled(
                      tooltip: 'Send Message',
                      onPressed: _isComposing || _mentions.isNotEmpty
                          ? () => _handleSubmitted(_controller.text)
                          : null,
                      icon: Icon(
                        Icons.send_outlined,
                        size: 21,
                        color: _isComposing || _mentions.isNotEmpty
                            ? colors.onPrimary
                            : null,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
