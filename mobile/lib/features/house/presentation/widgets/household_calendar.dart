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

  @override
  Widget build(BuildContext context) {
    final first = _month.subtract(Duration(days: _month.weekday - 1));
    final range = (
      houseId: widget.houseId,
      from: first,
      to: first.add(const Duration(days: 41)),
    );
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              onPressed: () => _move(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                DateFormat('MMMM yyyy').format(_month),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: () => _move(1),
              icon: const Icon(Icons.chevron_right),
            ),
            TextButton(
              onPressed: () => setState(() {
                _selected = vietnamDay(DateTime.now());
                _month = DateTime(_selected.year, _selected.month);
              }),
              child: const Text('Today'),
            ),
          ],
        ),
        ref
            .watch(houseCalendarProvider(range))
            .when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(apiErrorMessage(e)),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(houseCalendarProvider(range)),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
              data: (days) {
                final selected = days
                    .where((d) => d.date == _selected)
                    .firstOrNull;
                Widget cell(HouseCalendarDay day) => Material(
                  color: day.date == _selected
                      ? colors.primaryFixed
                      : colors.surfaceContainerLowest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: day.date == _selected
                          ? colors.primary
                          : colors.outlineVariant,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _selected = day.date),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Column(
                        children: [
                          Text(
                            '${day.date.day}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: day.date.month == _month.month
                                  ? colors.onSurface
                                  : colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 3),
                          if (day.previews.isNotEmpty)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (final id in day.previews.take(2))
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 1,
                                      ),
                                      child: CalendarEvidencePhoto(
                                        houseId: widget.houseId,
                                        evidenceId: id,
                                        height: 20,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          if (day.photoCount > 2)
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(36, 22),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                setState(() => _selected = day.date);
                                _gallery(context, day);
                              },
                              child: Text(
                                '+${day.photoCount - 2}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: colors.primary,
                                ),
                              ),
                            ),
                          if (day.previews.isEmpty &&
                              (day.scheduled > 0 || day.completed > 0))
                            Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.event_note_outlined,
                                      size: 10,
                                    ),
                                    const SizedBox(width: 2),
                                    Flexible(
                                      child: Text(
                                        '${day.scheduled}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_outlined, size: 10),
                                    const SizedBox(width: 2),
                                    Flexible(
                                      child: Text(
                                        '${day.completed}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          if (day.overdue > 0)
                            Icon(
                              Icons.priority_high,
                              size: 12,
                              color: colors.error,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) =>
                          constraints.maxWidth < 308
                          ? SizedBox(
                              height: 98,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: days.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 4),
                                itemBuilder: (_, i) =>
                                    SizedBox(width: 48, child: cell(days[i])),
                              ),
                            )
                          : Column(
                              children: [
                                Row(
                                  children: [
                                    for (final name in [
                                      'Mon',
                                      'Tue',
                                      'Wed',
                                      'Thu',
                                      'Fri',
                                      'Sat',
                                      'Sun',
                                    ])
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          child: Text(
                                            name,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 11,
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
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 7,
                                        mainAxisExtent: 91,
                                        crossAxisSpacing: 1,
                                        mainAxisSpacing: 4,
                                      ),
                                  itemBuilder: (_, i) => cell(days[i]),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      DateFormat('EEEE, MMM d').format(_selected),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (selected == null || selected.items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('No chores for this day.'),
                      ),
                    if (selected != null && selected.completedPhotos.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => _gallery(context, selected),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(
                          'View ${selected.photoCount} completion photos',
                        ),
                      ),
                    for (final item in selected?.items ?? <CalendarChore>[])
                      Card(
                        child: InkWell(
                          onTap: () => context.push(
                            '/houses/${widget.houseId}/chores/${item.id}',
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Assigned to ${item.assignedName ?? 'Unassigned'}',
                                      ),
                                      Text(
                                        item.status == 'COMPLETED'
                                            ? 'Completed by ${item.completedByName ?? 'Not recorded'}'
                                            : item.status.replaceAll('_', ' '),
                                      ),
                                      if (item.completedAt != null)
                                        Text(
                                          'Completed ${DateFormat('MMM d').format(vietnamDay(item.completedAt!))}',
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
      ],
    );
  }

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
      borderRadius: BorderRadius.circular(4),
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
