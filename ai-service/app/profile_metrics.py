METRIC_VERSION = "contribution-metrics-v1"
METRIC_DEFINITIONS = {
    "completed_count": ("completion", None, "count"),
    "standard_minutes": ("completion", None, "standard_minutes"),
    "snapshot_karma": ("completion", None, "karma"),
    "responsibility_count": ("responsibility", None, "count"),
    "on_time_episode_rate": (
        "episode_outcome",
        "on_time_episode_denominator",
        "ratio",
    ),
    "bounty_claim_count": ("bounty_claim", None, "count"),
    "bounty_occurrence_count": ("bounty_outcome", None, "count"),
    "bounty_self_completion_rate": (
        "bounty_outcome",
        "bounty_outcome_denominator",
        "ratio",
    ),
    "bounty_posted_count": ("bounty_posted", None, "count"),
    "mean_normalized_rank": ("ranking", "normalized_rank_count", "ratio"),
}


def metric_records(values: dict, evidence: dict, context: dict) -> dict:
    numerators = {
        "on_time_episode_rate": values["on_time_episode_count"],
        "bounty_self_completion_rate": values["bounty_self_completed"],
        "mean_normalized_rank": values["normalized_rank_sum"],
    }
    sample_counts = {
        "standard_minutes": values["completed_count"],
        "snapshot_karma": values["completed_count"],
        "bounty_occurrence_count": values["bounty_occurrence_count"],
    }
    result = {}
    for key, (source, denominator, unit) in METRIC_DEFINITIONS.items():
        ids = list(dict.fromkeys(evidence.get(source, [])))
        count = len(ids)
        result[key] = {
            **context,
            "value": values[key],
            "numerator": numerators.get(key, values[key]),
            "denominator": values[denominator] if denominator else None,
            "sample_count": values[denominator]
            if denominator
            else sample_counts.get(key, count),
            "evidence_count": count,
            "unit": unit,
            "quality": "BUSINESS_FACTS" if ids else "NO_OBSERVATIONS",
            "status": "VALID" if values[key] is not None else "INSUFFICIENT_DATA",
            "evidence_ids": ids,
            "definition_version": METRIC_VERSION,
            "coverage_scope": "OBSERVED_TELEMETRY_ONLY",
        }
    result["on_time_episode_rate"].update(
        excluded_count=values["censored_episode_count"],
        pending_count=values["pending_episode_count"],
    )
    result["bounty_self_completion_rate"].update(
        excluded_count=values["bounty_cancelled"] + values["bounty_unknown"],
        pending_count=values["bounty_pending"] + values["bounty_overdue_open"],
    )
    return result
