import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chore_wars/core/theme/app_theme.dart';
import 'package:chore_wars/core/utils/api_error_message.dart';

class MessageInput extends StatefulWidget {
  final Future<void> Function(String) onSendMessage;
  final Future<void> Function(List<int> bytes, String filename)? onSendImage;

  const MessageInput({
    super.key,
    required this.onSendMessage,
    this.onSendImage,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isComposing = false;
  bool _isSending = false;
  bool _isUploading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitted(String text) async {
    final content = text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      await widget.onSendMessage(content);
      if (!mounted) return;
      _controller.clear();
      setState(() => _isComposing = false);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    if (widget.onSendImage == null) return;

    try {
      final photo = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() => _isUploading = true);
        final bytes = await photo.readAsBytes();
        await widget.onSendImage!(bytes, photo.name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBusy = _isSending || _isUploading;

    return Container(
      padding: EdgeInsets.only(
        left: 4.0,
        right: 8.0,
        top: 8.0,
        bottom: 8.0 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -1),
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.camera_alt_rounded),
            color: AppTheme.purple,
            tooltip: 'Chụp ảnh',
            onPressed: _isUploading ? null : () => _pickAndSendImage(ImageSource.camera),
          ),
          IconButton(
            icon: const Icon(Icons.photo_library_rounded),
            color: AppTheme.purple,
            tooltip: 'Chọn ảnh',
            onPressed: _isUploading ? null : () => _pickAndSendImage(ImageSource.gallery),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24.0),
              ),
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (text) {
                  setState(() {
                    _isComposing = text.trim().isNotEmpty;
                  });
                },
                onSubmitted: _handleSubmitted,
                decoration: InputDecoration(
                  hintText: _isUploading ? 'Đang gửi ảnh...' : 'Nhập tin nhắn...',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.muted,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  border: InputBorder.none,
                ),
                maxLines: 4,
                minLines: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
            color: (_isComposing && !_isSending) || _isUploading
                  ? AppTheme.purple
                  : theme.colorScheme.surface,
              shape: BoxShape.circle,
            ),
            child: isBusy
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.send_rounded),
                    color: _isComposing ? Colors.white : AppTheme.muted,
                    onPressed: _isComposing && !_isSending
                        ? () => _handleSubmitted(_controller.text)
                        : null,
                  ),
          ),
        ],
      ),
    );
  }
}
