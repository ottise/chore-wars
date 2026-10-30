/// For display/grouping only. Keep API timestamps in UTC in domain models.
DateTime vietnamTime(DateTime instant) =>
    instant.toUtc().add(const Duration(hours: 7));
