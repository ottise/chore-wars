from collections import Counter
from datetime import datetime

from app.behavior import parse_time


def label_episode(
    episode: dict,
    occurrence: dict,
    requests: list[dict],
    cutoff: datetime,
    complete: bool,
) -> dict:
    if not complete:
        return {"T1": None, "T2": None, "status": "INCOMPLETE_TELEMETRY"}
    if not episode.get("snapshot_id") or episode.get("reason") == "LEGACY":
        return {"T1": None, "T2": None, "status": "MISSING_SOURCE_SNAPSHOT"}
    if occurrence.get("status") in ("SKIPPED", "CANCELLED"):
        return {"T1": None, "T2": None, "status": "EXCLUDED_CANCELLED_OR_SKIPPED"}
    start, due, end = map(
        parse_time,
        (episode["started_at"], episode["deadline"], episode.get("ended_at")),
    )
    if start > cutoff:
        return {"T1": None, "T2": None, "status": "PREDICTION_TIME_IN_FUTURE"}
    if end and end > cutoff:
        end = None
    if parse_time(occurrence["due_at"]) != due:
        return {"T1": None, "T2": None, "status": "EXCLUDED_DEADLINE_CHANGED"}
    window_end = min(end or due, due)
    positive = any(
        r.get("actor_id") == episode["member_id"]
        and start <= parse_time(r["requested_at"]) <= min(window_end, cutoff)
        for r in requests
    )
    t2 = (
        1
        if positive
        else (0 if cutoff >= window_end and (end is not None or cutoff > due) else None)
    )
    if end and end <= due and episode.get("completed_by") != episode["member_id"]:
        return {"T1": None, "T2": t2, "status": "CENSORED_TRANSFER"}
    completed = parse_time(occurrence.get("completed_at"))
    if completed and completed > cutoff:
        completed = None
    if completed and occurrence.get("completed_by") == episode["member_id"]:
        return {"T1": int(completed > due), "T2": t2, "status": "LABELED"}
    if cutoff > due and (end is None or end > due):
        return {"T1": 1, "T2": t2, "status": "LABELED"}
    return {"T1": None, "T2": t2, "status": "PENDING"}


def readiness(rows: list[dict], target: str) -> dict:
    valid = [r for r in rows if r.get(target) in (0, 1)]
    counts = Counter(r[target] for r in valid)
    product = len(valid) >= 500 and min(counts.get(0, 0), counts.get(1, 0)) >= 50
    return {
        "target": target,
        "eligible_count": len(valid),
        "class_counts": {"0": counts[0], "1": counts[1]},
        "offline_eligible": counts[0] > 0 and counts[1] > 0,
        "product_data_eligible": product,
        "reasons": []
        if product
        else ["INSUFFICIENT_LABELED_SAMPLES_OR_CLASS_COVERAGE"],
        "excluded_reasons": dict(
            Counter(r.get("status", "UNKNOWN") for r in rows if r.get(target) is None)
        ),
        "threshold_status": "PROPOSED_EXPERIMENT_V1",
    }
