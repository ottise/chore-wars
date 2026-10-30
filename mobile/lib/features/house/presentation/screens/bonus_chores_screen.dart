import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/utils/vietnam_time.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../bounty/presentation/providers/bounty_providers.dart';
import '../../../chat/presentation/widgets/assistant_requests.dart';
import '../../../chat/providers/action_proposal_providers.dart';
import '../../../chore/presentation/providers/chore_providers.dart';
import '../../../chore/domain/entities/chore_models.dart';
import '../../../chat/data/models/action_proposal_model.dart';

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
  List<Map<String, dynamic>> _chores = [];
  bool _loading = true;
  bool _fetching = false;
  bool _reload = false;
  final _claiming = <String>{};
  Object? _error;

  String? get _userId {
    final auth = ref.read(authStateProvider);
    return ref.read(userProfileProvider).asData?.value.id ??
        (auth is AuthAuthenticated ? auth.user.userId : null);
  }

  @override
  void initState() {
    super.initState();
    _fetchBonusChores();
  }

  @override
  void didUpdateWidget(covariant BonusChoresScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId ||
        oldWidget.seasonId != widget.seasonId) {
      _chores = [];
      _loading = true;
      _fetchBonusChores();
    }
  }

  Future<void> _fetchBonusChores() async {
    if (_fetching) {
      _reload = true;
      return;
    }
    _fetching = true;
    final houseId = widget.houseId;
    final seasonId = widget.seasonId;
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(
        '/houses/$houseId/seasons/$seasonId/occurrences',
      );
      final bounties = await dio.get('/houses/$houseId/bounties');
      final me = _userId;
      final accepted = {
        for (final b in bounties.data as List)
          if (me != null &&
              (b['status'] == 1 || b['status'] == 'CLAIMED') &&
              b['assignedUserId'] == me)
            b['choreOccurrenceId'].toString(): b,
      };
      final chores = (res.data as List)
          .map((c) => Map<String, dynamic>.from(c as Map))
          .where((c) {
            if (accepted.containsKey(c['id'].toString())) return true;
            if (c['type'] != 1 && c['type'] != 'BONUS') return false;
            if (me != null && c['assignedUserId'] == me) return true;
            return c['assignedUserId'] == null &&
                (c['status'] == 0 || c['status'] == 'ASSIGNED') &&
                (DateTime.tryParse(c['dueDate'].toString())
                        ?.isAfter(DateTime.now()) ??
                    false);
          })
          .map(
            (c) => {
              ...c,
              if (accepted.containsKey(c['id'].toString()))
                'bounty': accepted[c['id'].toString()],
            },
          )
          .toList();
      chores.sort((a, b) {
        final due = a['dueDate'].toString().compareTo(b['dueDate'].toString());
        return due != 0
            ? due
            : a['id'].toString().compareTo(b['id'].toString());
      });
      if (mounted && houseId == widget.houseId && seasonId == widget.seasonId) {
        setState(() {
          _chores = chores;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && houseId == widget.houseId && seasonId == widget.seasonId) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    } finally {
      _fetching = false;
      if (mounted && _reload) {
        _reload = false;
        _fetchBonusChores();
      }
    }
  }

  Future<void> _refresh() async {
    final room = ref
        .read(assistantRequestRoomProvider(widget.houseId))
        .asData
        ?.value;
    if (room == null) {
      ref.invalidate(assistantRequestRoomProvider(widget.houseId));
    } else {
      await ref.read(actionProposalProvider(room).notifier).loadProposals();
    }
    await _fetchBonusChores();
  }

  Future<void> _claimChore(String id) async {
    if (!_claiming.add(id)) return;
    setState(() {});
    try {
      await ref.read(dioProvider).post('/occurrences/$id/claim');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bonus chore claimed successfully!')),
        );
        refreshChoreState(ref, widget.houseId);
        await _fetchBonusChores();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _claiming.remove(id));
    }
  }

  Widget _chore(Map<String, dynamic> c) {
    final id = c['id'].toString();
    final owned = c['assignedUserId'] == _userId || c['bounty'] != null;
    final due = DateFormat('dd/MM/yyyy HH:mm')
        .format(vietnamTime(c['dueDate']));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              c['choreName']?.toString() ?? 'Bonus chore',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              c['bounty'] != null
                  ? "Bounty: ${c['bounty']['amount']} VND"
                  : "Reward: ${c['karmaPoints']} Karma",
            ),
            Text('Due $due (UTC+7)'),
            if (owned)
              Text('Status: ${ChoreStatus.fromJson(c['status']).label}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                TextButton(
                  onPressed: () =>
                      context.push('/houses/${widget.houseId}/chores/$id'),
                  child: const Text('View chore'),
                ),
                if (!owned)
                  ElevatedButton(
                    onPressed: _claiming.contains(id)
                        ? null
                        : () => _claimChore(id),
                    child: Text(_claiming.contains(id) ? 'Claiming…' : 'Claim'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(bountyBoardProvider(widget.houseId), (_, next) {
      if (next.hasValue) _fetchBonusChores();
    });
    ref.listen(
      choreRefreshProvider(widget.houseId),
      (_, _) => _fetchBonusChores(),
    );
    ref.listen(userProfileProvider, (_, next) {
      if (next.hasValue) _fetchBonusChores();
    });
    final roomId = ref
        .watch(assistantRequestRoomProvider(widget.houseId))
        .asData
        ?.value;
    if (roomId != null) {
      ref.listen(actionProposalProvider(roomId), (previous, next) {
        final old = previous?.asData?.value ?? <ActionProposalModel>[];
        final approved =
            next.asData?.value.any(
              (proposal) =>
                  proposal.type == ProposalType.urgentEvent &&
                  proposal.status == ProposalStatus.approved &&
                  !old.any(
                    (p) =>
                        p.id == proposal.id &&
                        p.status == ProposalStatus.approved,
                  ),
            ) ??
            false;
        if (approved) _fetchBonusChores();
      });
    }
    final body = RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        itemCount:
            2 +
            (_loading || _error != null || _chores.isEmpty
                ? 1
                : _chores.length),
        itemBuilder: (context, index) {
          if (index == 0) {
            return AssistantRequests(
              houseId: widget.houseId,
              urgentOnly: true,
              inline: true,
            );
          }
          if (index == 1) {
            return Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh bonus'),
              ),
            );
          }
          if (_loading) return const Center(child: CircularProgressIndicator());
          if (_error != null) {
            return Column(
              children: [
                Text(apiErrorMessage(_error!)),
                TextButton(
                  onPressed: _fetchBonusChores,
                  child: const Text('Retry bonus chores'),
                ),
              ],
            );
          }
          if (_chores.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No bonus chores yet. Pending invitations appear above.',
              ),
            );
          }
          return _chore(_chores[index - 2]);
        },
      ),
    );
    return widget.embedded
        ? body
        : Scaffold(
            appBar: AppBar(title: const Text('Bonus Chores')),
            body: body,
          );
  }
}
