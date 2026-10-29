import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
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
  DateTime? _retryAfter;
  String? _message;
  @override
  void dispose() {
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
    if (request &&
        _retryAfter != null &&
        DateTime.now().isBefore(_retryAfter!)) {
      setState(
        () => _message = 'Wait one minute before requesting another code.',
      );
      return;
    }
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
          _retryAfter = DateTime.now().add(const Duration(seconds: 60));
          _message = 'If this account is eligible, a code has been sent. Check your email and spam folder. The code expires in 10 minutes.';
        });
      } else {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) setState(() => _message = apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(widget.resetPassword ? 'Reset password' : 'Verify email'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _email,
                enabled: !_busy && !_requested,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              if (_requested) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _code,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Verification code',
                  ),
                ),
                if (widget.resetPassword)
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
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(liveRegion: true, child: Text(_message!)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _busy ? null : () => _run(true),
          child: Text(_requested ? 'Resend code' : 'Send code'),
        ),
        if (_requested)
          FilledButton(
            onPressed: _busy ? null : () => _run(false),
            child: Text(_busy ? 'Please wait…' : 'Confirm'),
          ),
      ],
    ),
  );
}
