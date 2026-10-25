import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/primary_button.dart';
import '../providers/house_providers.dart';
import '../../../../core/utils/api_error_message.dart';

class JoinHouseScreen extends ConsumerStatefulWidget {
  const JoinHouseScreen({super.key});

  @override
  ConsumerState<JoinHouseScreen> createState() => _JoinHouseScreenState();
}

class _JoinHouseScreenState extends ConsumerState<JoinHouseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join a house'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter invite code',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Ask your housemate to share the invite code from their house settings.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _codeCtrl,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.characters,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Invite code',
                    prefixIcon: const Icon(Icons.key_outlined),
                    suffixIcon: IconButton(
                      tooltip: 'Scan QR code',
                      icon: const Icon(Icons.qr_code_scanner_outlined),
                      onPressed: () => context.push('/houses/qr-join'),
                    ),
                    hintText: 'e.g. AB12CD',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Enter the invite code';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                PrimaryButton(
                  text: 'Join house',
                  isLoading: _isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 16),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/houses/qr-join'),
                    icon: const Icon(Icons.qr_code_scanner_outlined),
                    label: const Text('Or scan QR code'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(houseRepositoryProvider)
          .joinHouse(inviteCode: _codeCtrl.text.trim().toUpperCase());
      refreshHouseState(ref);
      if (mounted) {
        showAppMessage(context, 'Joined house successfully!');
        context.go('/houses');
      }
    } catch (error) {
      if (mounted) showAppMessage(context, apiErrorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
