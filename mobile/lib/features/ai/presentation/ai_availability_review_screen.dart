import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/session_provider.dart';
import '../../../core/utils/api_error_message.dart';
import '../data/ai_repository.dart';
import 'ai_planning_screen.dart';

class AiAvailabilityReviewScreen extends ConsumerStatefulWidget {
  const AiAvailabilityReviewScreen({
    super.key,
    required this.houseId,
    this.candidate,
    this.insightId,
  });
  final String houseId;
  final Map? candidate;
  final String? insightId;
  @override
  ConsumerState<AiAvailabilityReviewScreen> createState() =>
      _AiAvailabilityReviewScreenState();
}

class _AiAvailabilityReviewScreenState
    extends ConsumerState<AiAvailabilityReviewScreen> {
  String? season, error;
  DateTime? date;
  TimeOfDay? start, end;
  bool busyValue = true, saving = false;
  bool endOfDay = false;
  int? epoch;
  final request = const Uuid().v4();
  @override
  void initState() {
    super.initState();
    final c = widget.candidate;
    date = DateTime.tryParse(c?['local_date']?.toString() ?? '');
    TimeOfDay? time(dynamic n) =>
        n is int ? TimeOfDay(hour: n ~/ 60, minute: n % 60) : null;
    start = time(c?['start_minute']);
    final last = c?['end_minute'];
    endOfDay = last == 1440;
    end = last == 1440 ? const TimeOfDay(hour: 23, minute: 59) : time(last);
    busyValue = c?['kind'] != 'FREE';
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(sessionEpochProvider);
    epoch ??= current;
    if (epoch != current) {
      return const Scaffold(
        body: Center(child: Text('Phiên đã đổi. Hãy mở lại yêu cầu.')),
      );
    }
    final seasons = ref.watch(aiSeasonsProvider(widget.houseId));
    final rows = (seasons.asData?.value ?? [])
        .where(
          (s) =>
              s['status'] == 'DRAFT' ||
              s['status'] == 0 ||
              s['status'] == 'ACTIVE' ||
              s['status'] == 2,
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Xác nhận lịch bận / rảnh')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Chọn đúng ngày và giờ của bạn theo giờ Việt Nam. Mùa nháp cập nhật khai báo; mùa đang chạy sẽ tạo phương án để xem lại và đồng thuận trước khi đổi lịch.',
          ),
          if (seasons.isLoading) const LinearProgressIndicator(),
          if (seasons.hasError)
            TextButton(
              onPressed: () =>
                  ref.invalidate(aiSeasonsProvider(widget.houseId)),
              child: const Text('Tải lại danh sách mùa'),
            ),
          DropdownButtonFormField<String>(
            initialValue: season,
            decoration: const InputDecoration(labelText: 'Mùa áp dụng'),
            items: rows
                .map(
                  (s) => DropdownMenuItem(
                    value: s['id'].toString(),
                    child: Text(s['name']?.toString() ?? s['id'].toString()),
                  ),
                )
                .toList(),
            onChanged: saving ? null : (v) => setState(() => season = v),
          ),
          SwitchListTile(
            title: Text(
              busyValue
                  ? 'Tôi bận trong khung giờ này'
                  : 'Tôi rảnh trong khung giờ này',
            ),
            value: busyValue,
            onChanged: saving ? null : (v) => setState(() => busyValue = v),
          ),
          ListTile(
            title: Text(
              date == null
                  ? 'Chọn ngày'
                  : date!.toIso8601String().substring(0, 10),
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: saving
                ? null
                : () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null && mounted) {
                      setState(() => date = picked);
                    }
                  },
          ),
          ListTile(
            title: Text(
              start == null ? 'Chọn giờ bắt đầu' : start!.format(context),
            ),
            onTap: saving
                ? null
                : () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: start ?? const TimeOfDay(hour: 8, minute: 0),
                    );
                    if (picked != null && mounted) {
                      setState(() => start = picked);
                    }
                  },
          ),
          ListTile(
            title: Text(
              endOfDay
                  ? '24:00 (cuối ngày)'
                  : end == null
                  ? 'Chọn giờ kết thúc'
                  : end!.format(context),
            ),
            onTap: saving
                ? null
                : () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: end ?? const TimeOfDay(hour: 9, minute: 0),
                    );
                    if (picked != null && mounted) {
                      setState(() {
                        end = picked;
                        endOfDay = false;
                      });
                    }
                  },
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton(
            onPressed:
                saving ||
                    season == null ||
                    date == null ||
                    start == null ||
                    end == null
                ? null
                : () async {
                    final first = start!.hour * 60 + start!.minute,
                        last = endOfDay ? 1440 : end!.hour * 60 + end!.minute;
                    if (first >= last) {
                      setState(
                        () => error = 'Giờ kết thúc phải sau giờ bắt đầu trong cùng ngày.',
                      );
                      return;
                    }
                    setState(() {
                      saving = true;
                      error = null;
                    });
                    try {
                      final result = await ref.read(aiRepositoryProvider).post(
                        widget.houseId,
                        'me/availability-confirmations',
                        {
                          'clientRequestId': request,
                          'seasonId': season,
                          'localDate': date!.toIso8601String().substring(0, 10),
                          'busy': busyValue,
                          'startMinute': first,
                          'endMinute': last,
                          'insightId': widget.insightId,
                        },
                      );
                      if (!mounted ||
                          !context.mounted ||
                          ref.read(sessionEpochProvider) != epoch) {
                        return;
                      }
                      if (result['status'] == 'APPLIED_DRAFT') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Đã cập nhật khai báo trong mùa nháp.',
                            ),
                          ),
                        );
                        Navigator.pop(context);
                      } else {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => AiPlanningScreen(
                              houseId: widget.houseId,
                              kind: 'REPLAN',
                              initialRecord: result,
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted && ref.read(sessionEpochProvider) == epoch) {
                        setState(() => error = apiErrorMessage(e));
                      }
                    } finally {
                      if (mounted && ref.read(sessionEpochProvider) == epoch) {
                        setState(() => saving = false);
                      }
                    }
                  },
            child: Text(saving ? 'Đang xử lý…' : 'Xác nhận và xem phương án'),
          ),
        ],
      ),
    );
  }
}
