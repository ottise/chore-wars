import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chore_wars/core/network/api_client.dart';

import '../data/models/action_proposal_model.dart';

final actionProposalProvider = FutureProvider.autoDispose
    .family<List<ActionProposalModel>, String>((ref, roomId) async {
      final response = await ref
          .watch(dioProvider)
          .get('/rooms/$roomId/proposals/active');
      return (response.data as List)
          .map(
            (item) => ActionProposalModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    });
