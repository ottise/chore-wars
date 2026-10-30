import '../../../bounty/presentation/providers/bounty_providers.dart';

import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_providers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_error_message.dart';

class BonusChoresScreen extends ConsumerStatefulWidget {
  const BonusChoresScreen({
    required this.houseId,
    required this.seasonId,
    this.embedded = false,
    super.key,
  });
  final String houseId;
  final String seasonId;
  final bool embedded;

  @override
  ConsumerState<BonusChoresScreen> createState() => _BonusChoresScreenState();
}

class _BonusChoresScreenState extends ConsumerState<BonusChoresScreen> {
  List<dynamic> _chores = [];
  bool _loading = true;
  bool _fetching = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _fetchBonusChores();
  }

  Future<void> _fetchBonusChores() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(
        '/houses/${widget.houseId}/seasons/${widget.seasonId}/occurrences',
      );
      final bounties = await dio.get('/houses/${widget.houseId}/bounties');
      final me = ref.read(userProfileProvider).asData?.value.id;
      final accepted = {
        for (final b in bounties.data as List)
          if ((b['status'] == 1 || b['status'] == 'CLAIMED') &&
              b['assignedUserId'] == me)
            b['choreOccurrenceId'].toString(): b,
      };
      if (mounted) {
        setState(() {
          // Filter for unassigned BONUS chores (Type == 1 means BONUS in our enum)
          _chores = (res.data as List<dynamic>)
              .where(
                (c) =>
                    accepted.containsKey(c['id'].toString()) ||
                    ((c['type'] == 1 || c['type'] == 'BONUS') &&
                        c['assignedUserId'] == null &&
                        DateTime.parse(c['dueDate'].toString())
                            .isAfter(DateTime.now())),
              )
              .map(
                (c) => {
                  ...c as Map,
                  if (accepted.containsKey(c['id'].toString()))
                    'bounty': accepted[c['id'].toString()],
                },
              )
              .toList();
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    } finally {
      _fetching = false;
    }
  }

  Future<void> _claimChore(String occurrenceId) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/occurrences/$occurrenceId/claim');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bonus chore claimed successfully!')),
        );
        _fetchBonusChores();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(bountyBoardProvider(widget.houseId), (previous, next) {
      if (next.hasValue) _fetchBonusChores();
    });
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(apiErrorMessage(_error!)),
                TextButton(
                  onPressed: _fetchBonusChores,
                  child: const Text('Try again'),
                ),
              ],
            ),
          )
        : _chores.isEmpty
        ? const Center(child: Text('No available bonus chores right now.'))
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 88),
            itemCount: _chores.length,
            itemBuilder: (ctx, i) {
              final c = _chores[i];
              return Card(
                child: ListTile(
                  title: Text(c['choreName']),
                  subtitle: Text(
                    c['bounty'] != null
                        ? "Bounty: ${c['bounty']['amount']} VND · Due ${c['dueDate']}"
                        : "Reward: ${c['karmaPoints']} Karma",
                  ),
                  onTap: () => context.push(
                    '/houses/${widget.houseId}/chores/${c['id']}',
                  ),
                  trailing: c['bounty'] != null
                      ? const Chip(label: Text('Bounty'))
                      : ElevatedButton(
                          onPressed: () => _claimChore(c['id']),
                          child: const Text('Claim'),
                        ),
                ),
              );
            },
          );
    return widget.embedded
        ? body
        : Scaffold(
            appBar: AppBar(title: const Text('Bonus Chores')),
            body: body,
          );
  }
}
