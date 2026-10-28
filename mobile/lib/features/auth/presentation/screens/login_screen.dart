import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/api_error_message.dart';
import '../providers/auth_providers.dart';
import '../widgets/google_sign_in_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    InputDecoration input(String label, String hint, IconData icon) =>
        InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 20),
          fillColor: colors.surfaceContainerLowest,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: colors.outlineVariant.withValues(alpha: .5),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.primary, width: 1.5),
          ),
        );
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                      child: AutofillGroup(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: colors.primary,
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Icon(
                                      Icons.home_outlined,
                                      color: colors.onPrimary,
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Chore Wars',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              color: colors.onSurface,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Chores, together.',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: colors.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 44),
                              Text(
                                'Welcome\nback.',
                                style: theme.textTheme.headlineLarge?.copyWith(
                                  fontSize: 34,
                                  height: 1.12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -1,
                                  color: colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Sign in to care for your shared home.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 32),
                              TextFormField(
                                controller: _emailCtrl,
                                enabled: !_isLoading,
                                autofillHints: const [
                                  AutofillHints.username,
                                  AutofillHints.email,
                                ],
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: input(
                                  'Email',
                                  'ban@example.com',
                                  Icons.mail_outline_rounded,
                                ),
                                validator: (value) {
                                  final email = value?.trim() ?? '';
                                  if (email.isEmpty) {
                                    return 'Enter your email address.';
                                  }
                                  if (!email.contains('@')) {
                                    return 'Enter a valid email address.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordCtrl,
                                enabled: !_isLoading,
                                autofillHints: const [AutofillHints.password],
                                obscureText: _obscurePassword,
                                enableIMEPersonalizedLearning: false,
                                autocorrect: false,
                                enableSuggestions: false,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                decoration:
                                    input(
                                      'Password',
                                      'Enter your password',
                                      Icons.lock_outline_rounded,
                                    ).copyWith(
                                      suffixIcon: IconButton(
                                        tooltip: _obscurePassword
                                            ? 'Show Password'
                                            : 'Hide Password',
                                        onPressed: _isLoading
                                            ? null
                                            : () {
                                                FocusScope.of(context)
                                                    .unfocus();
                                                setState(
                                                  () => _obscurePassword =
                                                      !_obscurePassword,
                                                );
                                              },
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Enter your password.'
                                    : null,
                              ),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 16),
                                Semantics(
                                  liveRegion: true,
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: colors.errorContainer,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: colors.onErrorContainer,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              FilledButton(
                                onPressed: _isLoading ? null : _submit,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(54),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text('Sign In'),
                                          SizedBox(width: 10),
                                          Icon(
                                            Icons.arrow_forward_outlined,
                                            size: 18,
                                          ),
                                        ],
                                      ),
                              ),
                              const SizedBox(height: 24),
                              GoogleSignInButton(
                                enabled: !_isLoading,
                                onToken: _googleLogin,
                                onError: (message) {
                                  if (mounted) {
                                    setState(() => _errorMessage = message);
                                  }
                                },
                              ),
                              const Spacer(),
                              Padding(
                                padding: const EdgeInsets.only(top: 24),
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'New here?',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                    TextButton(
                                      onPressed: _isLoading
                                          ? null
                                          : () => context.go('/register'),
                                      child: const Text('Create an Account'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    setState(() => _errorMessage = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authStateProvider.notifier)
          .login(email: _emailCtrl.text.trim(), password: _passwordCtrl.text);
      if (mounted) {
        TextInput.finishAutofillContext();
        context.go('/houses');
      }
    } catch (error) {
      if (mounted) setState(() => _errorMessage = apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleLogin(String idToken) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authStateProvider.notifier).googleLogin(idToken);
      if (mounted) context.go('/houses');
    } catch (error) {
      if (mounted) setState(() => _errorMessage = apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
