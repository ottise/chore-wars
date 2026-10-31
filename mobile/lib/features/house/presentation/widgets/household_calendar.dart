import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/api_error_message.dart';
import '../../domain/entities/house_calendar_models.dart';
import '../providers/house_calendar_providers.dart';

class HouseholdCalendar extends ConsumerStatefulWidget {
  const HouseholdCalendar({required this.houseId, super.key});
  final String houseId;

  @override
  ConsumerState<HouseholdCalendar> createState() => _HouseholdCalendarState();
}

class _HouseholdCalendarState extends ConsumerState<HouseholdCalendar> {
  late DateTime _selected = vietnamDay(DateTime.now());
  late DateTime _month = DateTime(_selected.year, _selected.month);

  void _move(int offset) => setState(() {
    _month = DateTime(_month.year, _month.month + offset);
    _selected = _month;
  });

  void _goToday() => setState(() {
    _selected = vietnamDay(DateTime.now());
    _month = DateTime(_selected.year, _selected.month);
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final first = _month.subtract(Duration(days: _month.weekday - 1));
    final range = (
      houseId: widget.houseId,
      from: first,
      to: first.add(const Duration(days: 41)),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Schedule',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Household calendar',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: _goToday, child: const Text('Today')),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: .4),
              ),
            ),
            child: Row(
              children: [
                _MonthArrow(
                  label: 'Previous month',
                  text: '‹',
                  onTap: () => _move(-1),
                ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy').format(_month),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                _MonthArrow(
                  label: 'Next month',
                  text: '›',
                  onTap: () => _move(1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          ref
              .watch(houseCalendarProvider(range))
              .when(
                loading: () => Column(
                  children: [
                    const LinearProgressIndicator(minHeight: 2),
                    _monthGrid(const [], hasData: false),
                  ],
                ),
                error: (error, _) => Column(
                  children: [
                    _monthGrid(const [], hasData: false),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            error is DioException &&
                                    error.response?.statusCode == 404
                                ? 'Calendar is not available on this server yet.'
                                : apiErrorMessage(error),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(houseCalendarProvider(range)),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ],
                ),
                data: (days) => _monthGrid(days, hasData: true),
              ),
        ],
      ),
    );
  }

  Widget _monthGrid(
    List<HouseCalendarDay> loadedDays, {
    required bool hasData,
  }) {
    final colors = Theme.of(context).colorScheme;
    final first = _month.subtract(Duration(days: _month.weekday - 1));
    final byDate = {for (final day in loadedDays) day.date: day};
    final days = List.generate(42, (index) {
      final date = first.add(Duration(days: index));
      return byDate[date] ??
          HouseCalendarDay(
            date: date,
            scheduled: 0,
            completed: 0,
            overdue: 0,
            photoCount: 0,
            previews: const [],
            items: const [],
          );
    });

    return Column(
      children: [
        Row(
          children: [
            for (final weekday in [
              'Mon',
              'Tue',
              'Wed',
              'Thu',
              'Fri',
              'Sat',
              'Sun',
            ])
              Expanded(
                child: SizedBox(
                  height: 27,
                  child: Center(
                    child: Text(
                      weekday,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: days.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 35,
          ),
          itemBuilder: (context, index) {
            final day = days[index];
            final isSelected = day.date == _selected;
            final isToday = day.date == vietnamDay(DateTime.now());
            final inMonth = day.date.month == _month.month;
            return Semantics(
              button: true,
              label:
                  '${DateFormat('EEEE, MMMM d').format(day.date)}'
                  '${day.scheduled > 0 ? ', ${day.scheduled} chores' : ''}',
              child: InkWell(
                key: ValueKey(
                  'calendar-day-${DateFormat('yyyy-MM-dd').format(day.date)}',
                ),
                customBorder: const CircleBorder(),
                onTap: () {
                  setState(() {
                    _selected = day.date;
                    if (day.date.month != _month.month ||
                        day.date.year != _month.year) {
                      _month = DateTime(day.date.year, day.date.month);
                    }
                  });
                  _showDay(context, day, hasData: hasData);
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 27,
                      height: 27,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? colors.primary : Colors.transparent,
                        shape: BoxShape.circle,
                        border: isToday && !isSelected
                            ? Border.all(color: colors.primary, width: 1)
                            : null,
                      ),
                      child: Text(
                        '${day.date.day}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isToday || isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? colors.onPrimary
                              : inMonth
                              ? colors.onSurface
                              : colors.onSurfaceVariant.withValues(alpha: .45),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    _ActivityDots(day: day),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _showDay(
    BuildContext context,
    HouseCalendarDay day, {
    required bool hasData,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (sheetContext) {
      final colors = Theme.of(sheetContext).colorScheme;
      final done = day.items.where((item) => item.status == 'COMPLETED').length;
      final visibleHeight = (MediaQuery.sizeOf(sheetContext).height - 36)
          .clamp(260, 620)
          .toDouble();
      return SafeArea(
        child: SizedBox(
          height: visibleHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat('EEEE, MMM d').format(day.date),
                        style: Theme.of(sheetContext).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Done'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  children: [
                    if (day.date == vietnamDay(DateTime.now()))
                      const _DateTag(text: 'Today'),
                    _DateTag(
                      text:
                          '${day.items.length} ${day.items.length == 1 ? 'chore' : 'chores'}',
                    ),
                    if (done > 0) _DateTag(text: '$done done'),
                    if (day.overdue > 0)
                      _DateTag(
                        text: '${day.overdue} overdue',
                        color: colors.errorContainer,
                        foreground: colors.onErrorContainer,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (day.photoCount > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _gallery(context, day);
                      },
                      child: Text('View ${day.photoCount} completion photos'),
                    ),
                  ),
                Expanded(
                  child: !hasData
                      ? const Center(
                          child: Text('Calendar details are unavailable.'),
                        )
                      : day.items.isEmpty
                      ? const Center(child: Text('Nothing scheduled yet.'))
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: day.items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = day.items[index];
                            final person = item.assignedName ?? 'Unassigned';
                            final initial = person.trim().isEmpty
                                ? '·'
                                : person.trim()[0].toUpperCase();
                            final isDone = item.status == 'COMPLETED';
                            final overdue =
                                item.status == 'OVERDUE' ||
                                item.status == 'CRITICAL_OVERDUE';
                            final tint = isDone
                                ? const Color(0xFFE8F2E9)
                                : overdue
                                ? colors.errorContainer
                                : colors.primaryContainer;
                            return Material(
                              color: colors.surfaceContainerLowest,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                                side: BorderSide(
                                  color: colors.outlineVariant.withValues(
                                    alpha: .45,
                                  ),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  context.push(
                                    '/houses/${widget.houseId}/chores/${item.id}',
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 15,
                                        backgroundColor: tint,
                                        child: Text(
                                          initial,
                                          style: TextStyle(
                                            color: colors.onPrimaryContainer,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(sheetContext)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              isDone
                                                  ? 'Done by ${item.completedByName ?? person}'
                                                  : 'Assigned to $person',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(sheetContext)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color:
                                                        colors.onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _StatusTag(
                                        text: _statusLabel(item.status),
                                        color: tint,
                                        foreground: overdue
                                            ? colors.onErrorContainer
                                            : colors.onSurfaceVariant,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          context.push('/houses/${widget.houseId}/chores/new');
                        },
                        child: const Text('+  Add chore'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        context.push(
                          '/houses/${widget.houseId}/chores?tab=team',
                        );
                      },
                      child: const Text('View details'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  String _statusLabel(String status) => switch (status) {
    'COMPLETED' => 'Done',
    'OVERDUE' => 'Overdue',
    'CRITICAL_OVERDUE' => 'Very overdue',
    'IN_PROGRESS' => 'In progress',
    'ASSIGNED' => 'Assigned',
    _ => status.replaceAll('_', ' '),
  };

  void _gallery(BuildContext context, HouseCalendarDay day) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * .75,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Completed ${DateFormat('MMM d').format(day.date)}',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                for (final item in day.items.where(
                  (i) =>
                      i.completedAt != null &&
                      vietnamDay(i.completedAt!) == day.date &&
                      i.status == 'COMPLETED',
                )) ...[
                  const SizedBox(height: 16),
                  Text(
                    '${item.name} · ${item.completedByName ?? 'Not recorded'}',
                  ),
                  for (final id in item.evidenceIds)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: CalendarEvidencePhoto(
                        houseId: widget.houseId,
                        evidenceId: id,
                        height: 250,
                        thumbnail: false,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      );
}

class _MonthArrow extends StatelessWidget {
  const _MonthArrow({
    required this.label,
    required this.text,
    required this.onTap,
  });
  final String label, text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 40,
    child: Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 23,
                height: 1,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ActivityDots extends StatelessWidget {
  const _ActivityDots({required this.day});
  final HouseCalendarDay day;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dots = <Color>[
      if (day.overdue > 0) colors.error,
      if (day.scheduled > day.completed) colors.primary,
      if (day.completed > 0) const Color(0xFF77A982),
    ];
    if (dots.isEmpty) return const SizedBox(height: 4);
    return SizedBox(
      height: 4,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < dots.length; index++) ...[
            if (index > 0) const SizedBox(width: 3),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: dots[index],
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DateTag extends StatelessWidget {
  const _DateTag({required this.text, this.color, this.foreground});
  final String text;
  final Color? color, foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color ?? Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: foreground ?? Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({
    required this.text,
    required this.color,
    required this.foreground,
  });
  final String text;
  final Color color, foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
    ),
  );
}

class CalendarEvidencePhoto extends ConsumerWidget {
  const CalendarEvidencePhoto({
    required this.houseId,
    required this.evidenceId,
    required this.height,
    this.thumbnail = true,
    super.key,
  });
  final String houseId, evidenceId;
  final double height;
  final bool thumbnail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (
      houseId: houseId,
      evidenceId: evidenceId,
      thumbnail: thumbnail,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ref
          .watch(calendarPhotoProvider(key))
          .when(
            data: (bytes) => Image.memory(
              bytes,
              height: height,
              semanticLabel: thumbnail ? null : 'Chore completion photo',
              excludeFromSemantics: thumbnail,
              fit: thumbnail ? BoxFit.cover : BoxFit.contain,
              errorBuilder: (_, _, _) => SizedBox(
                height: height,
                child: const Icon(Icons.broken_image_outlined, size: 16),
              ),
            ),
            loading: () => SizedBox(
              height: height,
              child: const Center(child: Icon(Icons.photo_outlined, size: 14)),
            ),
            error: (_, _) => SizedBox(
              height: height,
              child: InkWell(
                onTap: () => ref.invalidate(calendarPhotoProvider(key)),
                child: const Icon(Icons.refresh, size: 16),
              ),
            ),
          ),
    );
  }
}
