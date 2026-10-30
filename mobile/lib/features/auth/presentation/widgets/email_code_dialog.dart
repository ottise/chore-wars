import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/request_cooldown.dart';
import '../../../../core/utils/api_error_message.dart';

Future<bool?> showEmailCodeDialog(
  BuildContext context, {
  String email = '',
  bool resetPassword = false,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => EmailCodeDialog(email: email, resetPassword: resetPassword),
);

class EmailCodeDialog extends ConsumerStatefulWidget {
  const EmailCodeDialog({
    required this.email,
    required this.resetPassword,
    super.key,
  });
  final String email;
  final bool resetPassword;
  @override
  ConsumerState<EmailCodeDialog> createState() => _EmailCodeDialogState();
}

class _EmailCodeDialogState extends ConsumerState<EmailCodeDialog> {
  late final _email = TextEditingController(text: widget.email);
  final _code = TextEditingController(), _password = TextEditingController();
  bool _busy = false, _requested = false;
  late final _sendCooldown = RequestCooldown(_tick);
  late final _verifyCooldown = RequestCooldown(_tick);
  String? _message;
  bool _editingEmail = false;
  final _codeFocus = FocusNode();
  void _tick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sendCooldown.dispose();
    _verifyCooldown.dispose();
    _codeFocus.dispose();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(bool request) async {
    if (_busy) return;
    final email = _email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _message = 'Enter a valid email address.');
      return;
    }
    if (request && _sendCooldown.seconds > 0) {
      setState(
        () => _message = 'Wait one minute before requesting another code.',
      );
      return;
    }
    if (!request && _verifyCooldown.seconds > 0) return;
    if (!request &&
        (_code.text.length != 6 ||
            widget.resetPassword && _password.text.length < 6)) {
      setState(
        () => _message =
            'Enter the six-digit code${widget.resetPassword ? ' and a password of at least 6 characters' : ''}.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
      if (request) _sendCooldown.start(60);
    });
    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        request
            ? '/auth/email-otp/request'
            : widget.resetPassword
            ? '/auth/password/reset'
            : '/auth/email-otp/verify',
        data: {
          'email': email,
          if (request)
            'purpose': widget.resetPassword ? 'RESET_PASSWORD' : 'VERIFY_EMAIL',
          if (!request) 'code': _code.text,
          if (!request && widget.resetPassword) 'newPassword': _password.text,
        },
      );
      if (!mounted) return;
      if (request) {
        setState(() {
          _requested = true;
          _editingEmail = false;
          _code.clear();
          _message = 'If this account is eligible, a 6-digit code has been sent. Check your inbox and spam folder.';
        });
      } else {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = apiErrorMessage(error);
          if (request) {
            _sendCooldown.afterError(error);
          } else {
            _verifyCooldown.afterError(error, fallback: 10);
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = colors.primary;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        backgroundColor: colors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: .07),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.mail_outline_rounded, color: accent),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: _busy
                          ? null
                          : () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  widget.resetPassword ? 'Reset password' : 'Verify email',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.resetPassword
                      ? 'Enter the code from your email and choose a new password.'
                      : 'Confirm your email to access your Chore Wars household.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _email,
                        readOnly: _requested && !_editingEmail,
                        enabled: !_busy,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          prefixIcon: Icon(Icons.alternate_email, size: 20),
                        ),
                      ),
                    ),
                    if (_requested)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () {
                                FocusScope.of(context).unfocus();
                                setState(() {
                                  _editingEmail = true;
                                  _requested = false;
                                  _code.clear();
                                  _message = null;
                                });
                              },
                        child: const Text('Change'),
                      ),
                  ],
                ),
                if (_requested) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(child: Text('Verification code')),
                      Text(
                        '${_code.text.length} / 6',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) => Stack(
                      alignment: Alignment.center,
                      children: [
                        ExcludeSemantics(
                          child: IgnorePointer(
                            child: Row(
                              children: List.generate(
                                6,
                                (i) => Expanded(
                                  child: Container(
                                    margin: EdgeInsets.only(
                                      right: i == 5 ? 0 : 6,
                                    ),
                                    height: 48,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color:
                                            _codeFocus.hasFocus &&
                                                i ==
                                                    _code.text.length.clamp(
                                                      0,
                                                      5,
                                                    )
                                            ? accent
                                            : colors.outlineVariant,
                                      ),
                                    ),
                                    child: Text(
                                      i < _code.text.length
                                          ? _code.text[i]
                                          : '',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        TextField(
                          controller: _code,
                          focusNode: _codeFocus,
                          enabled: !_busy,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: const TextStyle(color: Colors.transparent),
                          cursorColor: Colors.transparent,
                          onChanged: (_) => setState(() {}),
                          onTap: () => setState(() {}),
                          onSubmitted: (_) => _run(false),
                          decoration: const InputDecoration(
                            labelText: 'Verification code',
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                            labelStyle: TextStyle(color: Colors.transparent),
                            counterText: '',
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.resetPassword) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _password,
                      enabled: !_busy,
                      obscureText: true,
                      maxLength: 128,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(
                        labelText: 'New password',
                      ),
                    ),
                  ],
                ],
                if (_message != null ||
                    _sendCooldown.seconds > 0 ||
                    _verifyCooldown.seconds > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: accent.withValues(alpha: .1)),
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_message != null)
                            Text(
                              _message!,
                              style: const TextStyle(fontSize: 12, height: 1.5),
                            ),
                          if (_requested)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Code expires in 10 minutes.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          if (_sendCooldown.seconds > 0)
                            Text(
                              'Wait one minute before requesting another code. ${_sendCooldown.seconds}s remaining.',
                              style: const TextStyle(fontSize: 12),
                            ),
                          if (_verifyCooldown.seconds > 0)
                            Text(
                              'You can try the code again in ${_verifyCooldown.seconds}s.',
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _busy || _sendCooldown.seconds > 0
                ? null
                : () => _run(true),
            child: Text(_requested ? 'Resend code' : 'Send code'),
          ),
          if (_requested)
            FilledButton(
              onPressed: _busy || _verifyCooldown.seconds > 0
                  ? null
                  : () => _run(false),
              child: Text(_busy ? 'Please wait…' : 'Confirm'),
            ),
        ],
      ),
    );
  }
}
