import 'chore_models.dart';

enum RoutinePreset {
  deepClean(
    'deep-clean',
    'Weekly Deep Clean',
    'Every Sat · 9:00 AM',
    30,
    ChoreFrequency.specificDays,
    [6],
    540,
    60,
  ),
  dishes(
    'dishes',
    'Daily Dish Duty',
    'Every evening · 8:00 PM',
    15,
    ChoreFrequency.daily,
    [],
    1200,
    20,
  ),
  recycling(
    'recycling',
    'Trash & Recycling',
    'Tue & Fri · 7:30 AM',
    10,
    ChoreFrequency.specificDays,
    [2, 5],
    450,
    15,
  );

  const RoutinePreset(
    this.key,
    this.title,
    this.schedule,
    this.karma,
    this.frequency,
    this.days,
    this.deadlineMinutes,
    this.minutes,
  );

  final String key, title, schedule;
  final int karma, deadlineMinutes, minutes;
  final ChoreFrequency frequency;
  final List<int> days;

  static RoutinePreset? fromKey(String? key) {
    for (final preset in values) {
      if (preset.key == key) return preset;
    }
    return null;
  }
}
