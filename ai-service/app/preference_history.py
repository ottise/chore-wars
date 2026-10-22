from collections import defaultdict

from app.timestamps import parse_time

PREFERENCE_HISTORY_VERSION = "declared-preference-history-v1"


def preference_history(history: list[dict], cutoff, since, period: str) -> dict:
    states = {}
    transitions = defaultdict(list)
    last_signal = {}
    for event in sorted(history, key=lambda e: e["house_sequence"]):
        if event["event_type"] != "preference.upsert":
            continue
        payload = event["payload"]
        stamp = parse_time(payload.get("effective_at"))
        if parse_time(event["recorded_at"]) > cutoff or stamp is None or stamp > cutoff:
            continue
        key = (payload["member_id"], payload["template_id"])
        if payload.get("deleted"):
            # Replacing a declaration deletes then reinserts it; deletion is not dislike.
            current = states.get(key)
            if current is None or current["entity_id"] == event["entity_id"]:
                states[key] = event
            continue
        if payload.get("type") not in ("PREFERRED", "DISLIKED"):
            continue
        states[key] = event
        if last_signal.get(key) != payload["type"]:
            transitions[key].append(event)
            last_signal[key] = payload["type"]
    members = defaultdict(list)
    for (member, template), current in sorted(states.items()):
        samples = (
            [
                event
                for event in transitions[(member, template)]
                if since <= parse_time(event["payload"]["effective_at"]) <= cutoff
            ]
            if period != "season"
            else []
        )
        positive = sum(e["payload"]["type"] == "PREFERRED" for e in samples)
        negative = len(samples) - positive
        deleted = current["payload"].get("deleted", False)
        members[member].append(
            {
                "template_id": template,
                "chore_name": current["payload"].get("chore_name"),
                "current_declared": None if deleted else current["payload"]["type"],
                "current_status": "CLEARED" if deleted else "CONFIRMED",
                "positive_count": positive,
                "negative_count": negative,
                "sample_count": len(samples),
                "smoothed_positive_score": (positive + 1) / (len(samples) + 2)
                if samples
                else None,
                "numerator": positive + 1 if samples else None,
                "denominator": len(samples) + 2 if samples else None,
                "uncertainty_status": "NOT_COMPUTED",
                "quality": "CONFIRMED_DECLARATIONS"
                if samples
                else "NO_WINDOW_OBSERVATIONS",
                "history_scope": "HOUSE_DECLARATIONS_NOT_SEASON_SCOPED"
                if period == "season"
                else period,
                "current_scope": "LATEST_KNOWN_AT_CUTOFF",
                "evidence_ids": list(
                    dict.fromkeys(
                        [e["event_id"] for e in samples] + [current["event_id"]]
                    )
                ),
                "version": PREFERENCE_HISTORY_VERSION,
                "interpretation": "Explicit declarations only. Score is not confidence, acceptance probability, or an inferred preference from completion/open signals.",
            }
        )
    return members
