from datetime import datetime
from zoneinfo import ZoneInfo

from app.behavior import parse_time
from app.labels import label_episode
from app.storage import canonical_hash
from app.stream import stream_status


def build_dataset(history: list[dict], cutoff: datetime) -> dict:
    history = [e for e in history if parse_time(e["recorded_at"]) <= cutoff]
    complete = stream_status(history)["telemetry_complete"]
    latest = {}
    for event in sorted(history, key=lambda e: e["house_sequence"]):
        latest[(event["event_type"].removesuffix(".upsert"), event["entity_id"])] = (
            event
        )
    occurrences = {
        key[1]: e["payload"] for key, e in latest.items() if key[0] == "occurrence"
    }
    requests = []
    for (kind, _), event in latest.items():
        p = event["payload"]
        if kind != "proposal" or p.get("type") not in ("CHORE_SWAP", "SCHEDULE_REPLAN"):
            continue
        data = {k.lower(): v for k, v in p.get("payload", {}).items()}
        occurrence = data.get("sourceoccurrenceid")
        if occurrence:
            requests.append(
                {
                    "occurrence_id": occurrence,
                    "actor_id": p["actor_id"],
                    "requested_at": p["requested_at"],
                }
            )
        if p.get("type") == "SCHEDULE_REPLAN":
            for change in data.get("changes", []):
                fields = {k.lower(): v for k, v in change.items()}
                if fields.get("previoususerid") == p["actor_id"]:
                    requests.append(
                        {
                            "occurrence_id": fields["occurrenceid"],
                            "actor_id": p["actor_id"],
                            "requested_at": p["requested_at"],
                        }
                    )
    rows = []
    for (kind, entity_id), event in latest.items():
        if kind != "episode":
            continue
        episode = event["payload"]
        occurrence = occurrences.get(episode.get("occurrence_id"))
        snapshot = episode.get("source_snapshot")
        if not occurrence:
            continue
        labels = label_episode(
            episode,
            occurrence,
            [r for r in requests if r["occurrence_id"] == episode["occurrence_id"]],
            cutoff,
            complete,
        )
        features = None
        if snapshot:
            started = parse_time(snapshot["prediction_time"])
            workload = snapshot.get("workload", [])
            features = {
                "minutes": snapshot["minutes"],
                "karma": snapshot["karma"],
                "difficulty": snapshot["difficulty"],
                "reason": snapshot["reason"],
                "hours_remaining": (
                    parse_time(snapshot["deadline"]) - started
                ).total_seconds()
                / 3600,
                "assigned_count": len(workload),
                "assigned_minutes": sum(t.get("SnapshotMinutes", 0) for t in workload),
                "weekday": started.astimezone(ZoneInfo("Asia/Ho_Chi_Minh")).weekday(),
                "hour": started.astimezone(ZoneInfo("Asia/Ho_Chi_Minh")).hour,
            }
            for key in (
                "completed_count",
                "completed_standard_minutes",
                "same_template_completed",
            ):
                if key in snapshot.get("history", {}):
                    features["history_" + key] = snapshot["history"][key]
            if snapshot.get("template_id"):
                features["template_id"] = snapshot["template_id"]
            features["declared_preference"] = next(
                (
                    p["type"]
                    for p in snapshot.get("preferences", [])
                    if p.get("template_id") == snapshot.get("chore_id")
                ),
                "UNSPECIFIED",
            )
            due = parse_time(snapshot["deadline"]).astimezone(
                ZoneInfo("Asia/Ho_Chi_Minh")
            )
            same_day = [
                t
                for t in workload
                if t.get("DueDate")
                and parse_time(t["DueDate"])
                .astimezone(ZoneInfo("Asia/Ho_Chi_Minh"))
                .date()
                == due.date()
            ]
            same_week = [
                t
                for t in workload
                if t.get("DueDate")
                and parse_time(t["DueDate"])
                .astimezone(ZoneInfo("Asia/Ho_Chi_Minh"))
                .isocalendar()[:2]
                == due.isocalendar()[:2]
            ]
            features["deadline_day_assigned_minutes"] = sum(
                t.get("SnapshotMinutes", 0) for t in same_day
            )
            features["deadline_week_assigned_count"] = len(same_week)
            exceptions = snapshot.get("date_exceptions", {})
            if due.date().isoformat() in exceptions:
                windows = exceptions[due.date().isoformat()]
                features["declared_free_minutes"] = sum(
                    w["end"] - w["start"] for w in windows
                )
                features["availability_declared"] = 1
            else:
                availability = next(
                    (
                        a
                        for a in snapshot.get("availability", [])
                        if a["day"] == (due.weekday() + 1) % 7
                    ),
                    None,
                )
                features["availability_declared"] = int(availability is not None)
                if availability:
                    features["declared_free_minutes"] = (
                        (
                            sum(
                                w["end"] - w["start"]
                                for w in availability.get("slots", [])
                            )
                            or 1440
                        )
                        if availability["available"]
                        else 0
                    )
        rows.append(
            {
                "episode_id": entity_id,
                "occurrence_id": episode["occurrence_id"],
                "member_id": episode["member_id"],
                "reason": episode["reason"],
                "prediction_time": episode["started_at"],
                "snapshot_id": episode.get("snapshot_id"),
                "snapshot_hash": canonical_hash(snapshot) if snapshot else None,
                "features": features,
                **labels,
            }
        )
    rows.sort(
        key=lambda r: (
            parse_time(r["prediction_time"]),
            r["occurrence_id"],
            r["member_id"],
            r["reason"],
            r["episode_id"],
        )
    )
    return {
        "rows": rows,
        "manifest": {
            "hash": canonical_hash(rows),
            "cutoff": cutoff.isoformat(),
            "telemetry_complete": complete,
            "feature_version": "episode-at-start-v1",
            "label_version": "episode-labels-v1",
            "sample_count": len(rows),
            "data_sources": sorted({e["data_source"] for e in history}),
        },
    }
