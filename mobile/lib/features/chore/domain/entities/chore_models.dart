enum ChoreType {
  normal(0, 'Normal'),
  bonus(1, 'Bonus');

  const ChoreType(this.apiValue, this.label);
  final int apiValue;
  final String label;

  static ChoreType fromJson(Object? value) =>
      value == 1 || value == 'BONUS' ? bonus : normal;
}

enum ChoreFrequency {
  daily(0, 'Daily'),
  everyXDays(1, 'Every X days'),
  weekly(2, 'Weekly'),
  xTimesPerWeek(3, 'X times / week'),
  specificDays(4, 'Specific days'),
  monthly(5, 'Monthly'),
  everyXMonths(6, 'Every X months'),
  yearly(7, 'Yearly'),
  custom(8, 'Custom');

  const ChoreFrequency(this.apiValue, this.label);
  final int apiValue;
  final String label;

  bool get needsValue => const {
    ChoreFrequency.everyXDays,
    ChoreFrequency.xTimesPerWeek,
    ChoreFrequency.everyXMonths,
  }.contains(this);

  static ChoreFrequency fromJson(Object? value) {
    if (value is int && value >= 0 && value < values.length) {
      return values[value];
    }
    final normalized = value.toString().toUpperCase();
    return values.firstWhere(
      (item) => item.name.toUpperCase() == normalized.replaceAll('_', ''),
      orElse: () => daily,
    );
  }
}

enum ChoreStatus {
  assigned,
  completed,
  overdue,
  criticalOverdue,
  skipped;

  static ChoreStatus fromJson(Object? value) {
    if (value is int && value >= 0 && value < values.length) {
      return values[value];
    }
    final normalized = value.toString().toUpperCase();
    return switch (normalized) {
      'COMPLETED' => completed,
      'OVERDUE' => overdue,
      'CRITICAL_OVERDUE' => criticalOverdue,
      'SKIPPED' => skipped,
      _ => assigned,
    };
  }

  String get label => switch (this) {
    assigned => 'Pending',
    completed => 'Completed',
    overdue => 'Overdue',
    criticalOverdue => 'Critical',
    skipped => 'Skipped',
  };
}

enum ChoreEffort {
  easy(1, 'Easy'),
  medium(2, 'Medium'),
  hard(3, 'Hard');

  const ChoreEffort(this.apiValue, this.label);
  final int apiValue;
  final String label;

  static ChoreEffort fromJson(Object? value) {
    if (value is int && value >= 1 && value <= 3) return values[value - 1];
    final normalized = value.toString().toUpperCase();
    return switch (normalized) {
      'EASY' => easy,
      'HARD' => hard,
      _ => medium,
    };
  }
}

class ChoreTemplate {
  const ChoreTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.karmaPoints,
    required this.type,
    required this.frequency,
    this.seasonId,
    this.asRoutine = false,
    this.deadlineMinutes = 1439,
    this.recurrenceAnchor,
    this.customDates = const [],
    this.frequencyValue,
    this.frequencyDays = const [],
    this.difficulty = ChoreEffort.medium,
    this.estimatedMinutes = 30,
  });

  final String? seasonId;
  final bool asRoutine;
  final int deadlineMinutes;
  final String? recurrenceAnchor;
  final List<String> customDates;
  final String id;
  final String name;
  final String description;
  final int karmaPoints;
  final ChoreType type;
  final ChoreFrequency frequency;
  final int? frequencyValue;
  final List<int> frequencyDays;
  final ChoreEffort difficulty;
  final int estimatedMinutes;

  factory ChoreTemplate.fromJson(Map<String, dynamic> json) => ChoreTemplate(
    seasonId: json['seasonId'] as String?,
    deadlineMinutes: (json['deadlineMinutes'] as num?)?.toInt() ?? 1439,
    recurrenceAnchor: json['recurrenceAnchor'] as String?,
    customDates: List<String>.from(json['customDates'] as List? ?? const []),
    id: json['id'].toString(),
    name: json['name']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    karmaPoints: (json['karmaPoints'] as num?)?.toInt() ?? 0,
    type: ChoreType.fromJson(json['type']),
    frequency: ChoreFrequency.fromJson(json['frequencyType']),
    frequencyValue: (json['frequencyValue'] as num?)?.toInt(),
    frequencyDays: (json['frequencyDays'] as List<dynamic>? ?? const [])
        .map((day) => (day as num).toInt())
        .toList(),
    difficulty: ChoreEffort.fromJson(json['difficulty']),
    estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt() ?? 30,
  );

  Map<String, dynamic> toRequestJson() => {
    'asRoutine': asRoutine,
    'deadlineMinutes': deadlineMinutes,
    'recurrenceAnchor': recurrenceAnchor,
    'customDates': customDates,
    'name': name.trim(),
    'description': description.trim(),
    'karmaPoints': karmaPoints,
    'type': type.apiValue,
    'frequencyType': frequency.apiValue,
    'frequencyValue': frequencyValue,
    'frequencyDays': frequencyDays,
    'difficulty': difficulty.apiValue,
    'estimatedMinutes': estimatedMinutes,
  };
}

class ChoreOccurrence {
  const ChoreOccurrence({
    required this.id,
    required this.choreId,
    required this.choreName,
    required this.assignedUserDisplayName,
    required this.dueDate,
    required this.status,
    this.assignedUserId,
    this.description = '',
    this.karmaPoints = 0,
    this.type = ChoreType.normal,
    this.penaltyCount = 0,
    this.proofImageUrl,
    this.evidenceId,
  });

  final String id;
  final String choreId;
  final String choreName;
  final String? assignedUserId;
  final String assignedUserDisplayName;
  final DateTime dueDate;
  final ChoreStatus status;
  final String description;
  final int karmaPoints;
  final ChoreType type;
  final int penaltyCount;
  final String? proofImageUrl;
  final String? evidenceId;

  factory ChoreOccurrence.fromJson(Map<String, dynamic> json) =>
      ChoreOccurrence(
        id: json['id'].toString(),
        choreId: json['choreId'].toString(),
        choreName: json['choreName']?.toString() ?? '',
        assignedUserId: json['assignedUserId']?.toString(),
        assignedUserDisplayName:
            json['assignedUserDisplayName']?.toString() ?? 'Unassigned',
        dueDate: DateTime.parse(json['dueDate'].toString()).toLocal(),
        status: ChoreStatus.fromJson(json['status']),
        description: json['description']?.toString() ?? '',
        karmaPoints:
            (json['karmaPoints'] as num?)?.toInt() ??
            (json['snapshotKarma'] as num?)?.toInt() ??
            0,
        type: ChoreType.fromJson(json['type']),
        penaltyCount: (json['penaltyCount'] as num?)?.toInt() ?? 0,
        proofImageUrl: json['proofImageUrl']?.toString(),
        evidenceId: json['evidenceId']?.toString(),
      );
}

class ChoreDetail {
  const ChoreDetail({required this.occurrence, required this.template});
  final ChoreOccurrence occurrence;
  final ChoreTemplate? template;

  int get karmaPoints => occurrence.karmaPoints > 0
      ? occurrence.karmaPoints
      : template?.karmaPoints ?? 0;
  String get description => occurrence.description.isNotEmpty
      ? occurrence.description
      : template?.description ?? '';
}
