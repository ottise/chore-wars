class CalendarChore {
  const CalendarChore({
    required this.id,
    required this.name,
    required this.status,
    required this.dueDate,
    required this.evidenceIds,
    this.completedAt,
    this.assignedName,
    this.completedByName,
  });
  final String id, name, status;
  final DateTime dueDate;
  final DateTime? completedAt;
  final String? assignedName, completedByName;
  final List<String> evidenceIds;
  factory CalendarChore.fromJson(Map<String, dynamic> data) => CalendarChore(
    id: data['id'] as String,
    name: data['choreName'] as String,
    status: data['status'] as String,
    dueDate: DateTime.parse(data['dueDate'] as String),
    completedAt: data['completedAt'] == null
        ? null
        : DateTime.parse(data['completedAt'] as String),
    assignedName: data['assignedName'] as String?,
    completedByName: data['completedByName'] as String?,
    evidenceIds: (data['evidenceIds'] as List).cast<String>(),
  );
}

class HouseCalendarDay {
  const HouseCalendarDay({
    required this.date,
    required this.scheduled,
    required this.completed,
    required this.overdue,
    required this.photoCount,
    required this.previews,
    required this.items,
  });
  final DateTime date;
  final int scheduled, completed, overdue, photoCount;
  final List<String> previews;
  final List<CalendarChore> items;
  factory HouseCalendarDay.fromJson(Map<String, dynamic> data) =>
      HouseCalendarDay(
        date: DateTime.parse(data['date'] as String),
        scheduled: data['scheduledCount'] as int,
        completed: data['completedCount'] as int,
        overdue: data['overdueCount'] as int,
        photoCount: data['totalEvidenceCount'] as int,
        previews: (data['previewEvidenceIds'] as List).cast<String>(),
        items: (data['items'] as List)
            .map(
              (v) =>
                  CalendarChore.fromJson(Map<String, dynamic>.from(v as Map)),
            )
            .toList(),
      );
  List<String> get completedPhotos => items
      .where(
        (c) =>
            c.status == 'COMPLETED' &&
            c.completedAt != null &&
            vietnamDay(c.completedAt!) == date,
      )
      .expand((c) => c.evidenceIds)
      .toSet()
      .toList();
}

DateTime vietnamDay(DateTime value) {
  final local = value.toUtc().add(const Duration(hours: 7));
  return DateTime(local.year, local.month, local.day);
}
