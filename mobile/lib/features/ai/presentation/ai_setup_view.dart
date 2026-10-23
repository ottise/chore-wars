import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/api_error_message.dart';
import '../data/ai_repository.dart';

class AiSetupView extends ConsumerStatefulWidget {
  const AiSetupView({
    required this.houseId,
    required this.owner,
    required this.settings,
    super.key,
  });
  final String houseId;
  final bool owner;
  final Map<String, dynamic> settings;
  @override
  ConsumerState<AiSetupView> createState() => _AiSetupViewState();
}

class _AiSetupViewState extends ConsumerState<AiSetupView> {
  bool busy = false;
  String? error;
  @override
  Widget build(BuildContext context) {
    final offline = widget.settings['configured'] == false;
    final key = (house: widget.houseId, path: 'settings');
    return Scaffold(
      appBar: AppBar(title: const Text('Assistant')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                offline
                    ? 'Assistant Setup Required'
                    : 'Assistant Is Not Enabled',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                offline
                    ? 'The assistant service is not configured on the server. Ask the server administrator to configure and start the AI service, then retry. You can continue using Chores, Chat, Bonus and Bounty.'
                    : widget.owner
                    ? 'Enable the assistant to view contributions and suggestions. Automatic chat analysis requires separate household and individual consent.'
                    : 'The owner can enable the assistant for this household.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (!offline && widget.owner)
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() {
                            busy = true;
                            error = null;
                          });
                          try {
                            await ref.read(aiRepositoryProvider).put(
                              widget.houseId,
                              'settings',
                              {
                                'enabled': true,
                                'chatAutoInsightsEnabled':
                                    widget
                                        .settings['chat_auto_insights_enabled'] ==
                                    true,
                              },
                            );
                            if (mounted) ref.invalidate(aiDataProvider(key));
                          } catch (e) {
                            if (mounted) {
                              setState(() => error = apiErrorMessage(e));
                            }
                          } finally {
                            if (mounted) setState(() => busy = false);
                          }
                        },
                  child: Text(busy ? 'Enabling…' : 'Enable Assistant'),
                ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => ref.invalidate(aiDataProvider(key)),
                child: const Text('Retry'),
              ),
              if (error != null) Text(error!),
            ],
          ),
        ),
      ),
    );
  }
}
