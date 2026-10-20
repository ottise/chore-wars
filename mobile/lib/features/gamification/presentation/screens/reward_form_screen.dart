import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/api_error_message.dart';
import '../providers/custom_reward_providers.dart';
import '../../data/repositories/custom_reward_repository.dart';

class RewardFormScreen extends ConsumerStatefulWidget {
  final String houseId;
  final CustomReward? reward;
  const RewardFormScreen({super.key, required this.houseId, this.reward});
  @override
  ConsumerState<RewardFormScreen> createState() => _RewardFormScreenState();
}

class _RewardFormScreenState extends ConsumerState<RewardFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _description = TextEditingController(),
      _cost = TextEditingController();
  bool _busy = false;
  bool _enabled = true;
  @override
  void initState() {
    super.initState();
    final reward = widget.reward;
    if (reward != null) {
      _name.text = reward.name;
      _description.text = reward.description;
      _cost.text = reward.cost.toString();
      _enabled = reward.enabled;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _cost.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final repository = ref.read(customRewardRepositoryProvider);
      final reward = widget.reward;
      if (reward == null) {
        await repository.create(
          widget.houseId,
          _name.text,
          _description.text,
          int.parse(_cost.text),
        );
      } else {
        await repository.update(
          widget.houseId,
          reward.id,
          _name.text,
          _description.text,
          int.parse(_cost.text),
          _enabled,
        );
      }
      ref.invalidate(customRewardsProvider(widget.houseId));
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.reward == null ? 'Create reward' : 'Edit reward'),
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Reward name'),
            maxLength: 100,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Enter a name' : null,
          ),
          TextFormField(
            controller: _description,
            decoration: const InputDecoration(
              labelText: 'What the member receives',
            ),
            maxLength: 1000,
            maxLines: 3,
          ),
          TextFormField(
            controller: _cost,
            decoration: const InputDecoration(labelText: 'Cost in Karma'),
            keyboardType: TextInputType.number,
            validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0
                ? 'Enter a positive cost'
                : null,
          ),
          if (widget.reward != null)
            SwitchListTile(
              title: const Text('Available for redemption'),
              value: _enabled,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _enabled = value),
            ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(
              widget.reward == null ? 'Create reward' : 'Save reward',
            ),
          ),
        ],
      ),
    ),
  );
}
