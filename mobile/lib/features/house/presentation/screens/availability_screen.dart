import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_error_message.dart';

class AvailabilityScreen extends ConsumerStatefulWidget {
  const AvailabilityScreen({
    required this.houseId,
    required this.seasonId,
    super.key,
  });

  final String houseId;
  final String seasonId;

  @override
  ConsumerState<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends ConsumerState<AvailabilityScreen> {
  bool _isLoading = false;
  
  // 0 = Sunday, 1 = Monday ... 6 = Saturday
  final Map<int, bool> _availability = {
    0: true,
    1: true,
    2: true,
    3: true,
    4: true,
    5: true,
    6: true,
  };

  final _days = [
    (1, 'Monday'),
    (2, 'Tuesday'),
    (3, 'Wednesday'),
    (4, 'Thursday'),
    (5, 'Friday'),
    (6, 'Saturday'),
    (0, 'Sunday'),
  ];

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      
      final Map<String, bool> payload = {};
      _availability.forEach((key, value) {
        payload[key.toString()] = value;
      });

      await dio.post(
        '/api/houses/${widget.houseId}/seasons/${widget.seasonId}/availability',
        data: {'availabilities': payload},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Availability saved!')),
        );
        context.pop();
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Availability'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Which days are you available to do chores?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'The AI allocation system will try to assign you chores on these days.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            elevation: 0,
            child: Column(
              children: [
                for (var i = 0; i < _days.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  SwitchListTile(
                    title: Text(_days[i].$2, style: const TextStyle(fontWeight: FontWeight.w500)),
                    value: _availability[_days[i].$1]!,
                    onChanged: (val) {
                      setState(() {
                        _availability[_days[i].$1] = val;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 48),
          FilledButton(
            onPressed: _isLoading ? null : _save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save Availability'),
          ),
        ],
      ),
    );
  }
}
