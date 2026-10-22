import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/session_provider.dart';
import '../data/ai_repository.dart';

class AiObservedView extends ConsumerStatefulWidget {
  const AiObservedView({
    super.key,
    required this.house,
    required this.entity,
    required this.kind,
    required this.child,
  });
  static const taskOpened = 'TASK_OPENED', bountyOpened = 'BOUNTY_OPENED';
  final String house, entity, kind;
  final Widget child;
  @override
  ConsumerState<AiObservedView> createState() => _AiObservedViewState();
}

class _AiObservedViewState extends ConsumerState<AiObservedView> {
  String? identity;
  String request = const Uuid().v4();
  bool pending = false, recorded = false;
  int? originalEpoch;
  @override
  Widget build(BuildContext context) {
    final epoch = ref.watch(sessionEpochProvider);
    originalEpoch ??= epoch;
    if (epoch != originalEpoch) return widget.child;
    final next = '${widget.house}/${widget.entity}/${widget.kind}/$epoch';
    if (identity != next) {
      identity = next;
      request = const Uuid().v4();
      pending = false;
      recorded = false;
    }
    final current = ModalRoute.of(context)?.isCurrent ?? true;
    if (!pending && !recorded && current) {
      pending = true;
      final captured = request;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted ||
            request != captured ||
            ref.read(sessionEpochProvider) != epoch) {
          return;
        }
        final lifecycle = WidgetsBinding.instance.lifecycleState;
        if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
          pending = false;
          return;
        }
        if (ModalRoute.of(this.context)?.isCurrent == false) {
          pending = false;
          return;
        }
        final result = await ref
            .read(aiRepositoryProvider)
            .observe(widget.house, captured, widget.entity, widget.kind);
        if (mounted && request == captured) {
          pending = false;
          recorded = result;
        }
      });
    }
    return widget.child;
  }
}
