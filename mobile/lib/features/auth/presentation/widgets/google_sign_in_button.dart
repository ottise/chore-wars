import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../data/google/google_identity_client.dart';
import 'google_button_surface.dart';

class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({
    required this.onToken,
    required this.onError,
    this.enabled = true,
    this.title,
    super.key,
  });
  final Future<void> Function(String) onToken;
  final ValueChanged<String> onError;
  final bool enabled;
  final String? title;
  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _events;
  bool _ready = false, _busy = false;
  @override
  void initState() {
    super.initState();
    if (GoogleIdentityClient.enabled) unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await GoogleIdentityClient.initialize();
      if (!mounted) return;
      if (kIsWeb) {
        _events = GoogleSignIn.instance.authenticationEvents.listen((event) {
          if (event is GoogleSignInAuthenticationEventSignIn) {
            unawaited(_accept(event.user));
          }
        }, onError: _error);
      }
      setState(() => _ready = true);
    } catch (error) {
      _error(error);
    }
  }

  void _error(Object error) {
    if (!mounted ||
        error is GoogleSignInException &&
            error.code == GoogleSignInExceptionCode.canceled) {
      return;
    }
    widget.onError(
      'Google sign-in is unavailable right now. Please try again or use email and password.',
    );
  }

  Future<void> _accept(GoogleSignInAccount account) async {
    if (_busy || !widget.enabled || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.onToken(GoogleIdentityClient.token(account));
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _authenticate() async {
    if (_busy || !widget.enabled) return;
    setState(() => _busy = true);
    try {
      final account = await GoogleSignIn.instance.authenticate();
      if (mounted) await widget.onToken(GoogleIdentityClient.token(account));
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!GoogleIdentityClient.enabled || !_ready) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          if (widget.title != null) ...[
            Text(widget.title!, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Choose Google with the same email as your account.'),
            const SizedBox(height: 12),
          ],
          AbsorbPointer(
            absorbing: _busy || !widget.enabled,
            child: Center(
              child: _busy
                  ? const CircularProgressIndicator()
                  : googleButtonSurface(_authenticate),
            ),
          ),
        ],
      ),
    );
  }
}
