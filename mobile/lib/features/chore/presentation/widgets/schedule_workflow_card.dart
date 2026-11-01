import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../house/presentation/providers/house_providers.dart';
import '../providers/chore_providers.dart';

class ScheduleWorkflowCard extends ConsumerStatefulWidget {
  const ScheduleWorkflowCard({
    required this.houseId,
    required this.seasonId,
    required this.isOwner,
    required this.hasOccurrences,
    required this.mandatoryCount,
    required this.unassignedCount,
    required this.allAssigned,
    required this.isDraft,
    required this.isReviewing,
    this.onStateChanged,
    super.key,
  });

  final String houseId;
  final String seasonId;
  final bool isOwner;
  final bool hasOccurrences;
  final int mandatoryCount;
  final int unassignedCount;
  final bool allAssigned;
  final bool isDraft;
  final bool isReviewing;
  final VoidCallback? onStateChanged;

  @override
  ConsumerState<ScheduleWorkflowCard> createState() =>
      _ScheduleWorkflowCardState();
}

class _ScheduleWorkflowCardState extends ConsumerState<ScheduleWorkflowCard> {
  String? _busyAction;

  bool get _busy => _busyAction != null;

  Future<void> _act(String action, String successMessage) async {
    if (_busy) return;
    setState(() => _busyAction = action);
    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        '/houses/${widget.houseId}/seasons/${widget.seasonId}/$action',
      );
      if (!mounted) return;
      refreshHouseState(ref, houseId: widget.houseId);
      refreshChoreState(ref, widget.houseId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
      widget.onStateChanged?.call();
      if (action == 'submit-review' && mounted) {
        context.push(
          '/houses/${widget.houseId}/seasons/${widget.seasonId}/review',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F4FE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0D7FA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0x1F7C4DFF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.checklist_rounded,
                  color: Color(0xFF7C4DFF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quy trình chuẩn bị lịch mùa',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '3 bước trước khi chốt lịch',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStepRow(
            stepNumber: '1',
            title: 'Sinh lịch việc cho từng ngày',
            status: widget.hasOccurrences
                ? 'Đã sinh ${widget.mandatoryCount} việc nhà'
                : 'Chưa sinh lịch các ngày',
            isDone: widget.hasOccurrences,
            action: OutlinedButton.icon(
              onPressed: _busy || !widget.isOwner
                  ? null
                  : () => _act(
                      'generate-schedule?autoAllocate=false',
                      'Đã sinh lịch các ngày thành công!',
                    ),
              icon: _busyAction == 'generate-schedule?autoAllocate=false'
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.calendar_month, size: 16),
              label: Text(
                widget.hasOccurrences
                    ? 'Sinh lại lịch việc'
                    : '1. Sinh lịch việc',
              ),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),
          const Divider(height: 24, color: Color(0xFFEDEAF6)),
          _buildStepRow(
            stepNumber: '2',
            title: 'AI tự động phân công việc',
            status: !widget.hasOccurrences
                ? 'Cần hoàn thành Bước 1 trước'
                : widget.allAssigned
                ? '100% đã được gán (${widget.mandatoryCount} việc)'
                : 'Còn ${widget.unassignedCount} việc chưa phân công',
            isDone: widget.allAssigned,
            action: FilledButton.tonalIcon(
              onPressed: _busy || !widget.hasOccurrences || !widget.isOwner
                  ? null
                  : () => _act(
                      'auto-assign',
                      'AI đã tự động phân công xong toàn bộ công việc!',
                    ),
              icon: _busyAction == 'auto-assign'
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome, size: 16),
              label: Text(
                widget.allAssigned
                    ? 'AI phân công lại'
                    : '2. AI phân công việc',
              ),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),
          const Divider(height: 24, color: Color(0xFFEDEAF6)),
          _buildStepRow(
            stepNumber: '3',
            title: 'Chốt lịch & Gửi mọi người duyệt',
            status: !widget.hasOccurrences
                ? 'Chưa có lịch để gửi'
                : !widget.allAssigned
                ? 'Cần phân công hết việc trước khi chốt'
                : widget.isReviewing
                ? 'Đang trong quá trình mọi người duyệt lịch'
                : 'Sẵn sàng gửi để mọi người cùng duyệt',
            isDone: widget.isReviewing,
            action: widget.isReviewing
                ? OutlinedButton.icon(
                    onPressed: () => context.push(
                      '/houses/${widget.houseId}/seasons/${widget.seasonId}/review',
                    ),
                    icon: const Icon(Icons.checklist_rounded, size: 16),
                    label: const Text('Xem tiến độ duyệt lịch'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: _busy || !widget.allAssigned || !widget.isOwner
                        ? null
                        : () => _act(
                            'submit-review',
                            'Đã gửi lịch cho mọi người cùng duyệt!',
                          ),
                    icon: _busyAction == 'submit-review'
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 16),
                    label: const Text('3. Chốt lịch & Gửi duyệt'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: const Color(0xFF7C4DFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow({
    required String stepNumber,
    required String title,
    required String status,
    required bool isDone,
    required Widget action,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isDone
                    ? const Color(0xFF10B981)
                    : const Color(0xFF7C4DFF),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text(
                        stepNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 30, top: 4, bottom: 8),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 12,
              color: isDone
                  ? const Color(0xFF059669)
                  : const Color(0xFF64748B),
              fontWeight: isDone ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 30),
          child: action,
        ),
      ],
    );
  }
}
