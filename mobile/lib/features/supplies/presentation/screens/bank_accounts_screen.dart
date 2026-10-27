import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/api_error_message.dart';
import '../providers/supplies_providers.dart';
import '../widgets/supplies_ui.dart';

class BankAccountsScreen extends ConsumerStatefulWidget {
  const BankAccountsScreen({super.key});
  @override
  ConsumerState<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends ConsumerState<BankAccountsScreen> {
  final _bank = TextEditingController();
  final _number = TextEditingController();
  final _name = TextEditingController();
  bool _initialized = false;
  bool _active = true;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _bank.dispose();
    _number.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(suppliesRepositoryProvider).mutate('/user/bank-account', {
        'bankName': _bank.text.trim(),
        'accountNumber': _number.text.trim(),
        'accountName': _name.text.trim(),
        'active': _active,
      }, method: 'PUT');
      if (mounted) {
        ref.invalidate(ownBankProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receiving details saved')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SuppliesPage(
    title: 'My bank details',
    child: ref
        .watch(ownBankProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              SupplyFailure(e, () => ref.invalidate(ownBankProvider)),
          data: (b) {
            if (!_initialized) {
              _initialized = true;
              _bank.text = b['bankName']?.toString() ?? '';
              _number.text = b['accountNumber']?.toString() ?? '';
              _name.text = b['accountName']?.toString() ?? '';
              _active = b['active'] != false;
            }
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Optional receiving details for members who owe you money. These details are self-declared. This does not connect or give access to your bank account.',
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _bank,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Bank name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _number,
                  keyboardType: TextInputType.number,
                  maxLength: 40,
                  decoration: const InputDecoration(
                    labelText: 'Account number',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _name,
                  maxLength: 150,
                  decoration: const InputDecoration(
                    labelText: 'Account holder name',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  onChanged: _busy ? null : (v) => setState(() => _active = v),
                  title: const Text('Share with members repaying me'),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Saving…' : 'Save receiving details'),
                ),
              ],
            );
          },
        ),
  );
}
