from collections import defaultdict
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from app.preference_history import preference_history
from app.profile_metrics import metric_records
from app.storage import canonical_hash
from app.timestamps import parse_time

LOCAL = ZoneInfo("Asia/Ho_Chi_Minh")
PROFILE_VERSION = "contribution-v3"


def profiles(
    history: list[dict],
    as_of: datetime | None = None,
    period: str = "all-time",
    season_id: str | None = None,
) -> dict:
    cutoff = as_of or datetime.now(timezone.utc)
    if (
        period not in ("all-time", "30d", "90d", "season")
        or period == "season"
        and not season_id
    ):
        raise ValueError("Select all-time, 30d, 90d, or a specified season")
    since = cutoff - timedelta(days={"30d": 30, "90d": 90}.get(period, 365000))

    def included(payload, field):
        stamp = parse_time(payload.get(field))
        return (
            stamp is not None
            and since <= stamp <= cutoff
            and (period != "season" or str(payload.get("season_id")) == season_id)
        )

    latest = {}
    lineage = defaultdict(lambda: defaultdict(list))

    def record(member, source, event_id):
        lineage[member][source].append(event_id)

    for event in sorted(history, key=lambda e: e["house_sequence"]):
        if parse_time(event["recorded_at"]) > cutoff:
            continue
        latest[(event["event_type"].removesuffix(".upsert"), event["entity_id"])] = (
            event
        )
    people = defaultdict(
        lambda: {
            "completed_count": 0,
            "standard_minutes": 0,
            "snapshot_karma": 0,
            "bounty_claim_count": 0,
            "bounty_occurrence_count": 0,
            "bounty_self_completed": 0,
            "bounty_other_completed": 0,
            "bounty_pending": 0,
            "bounty_overdue_open": 0,
            "bounty_cancelled": 0,
            "bounty_unknown": 0,
            "transfer_count": 0,
            "evidence_ids": [],
            "by_template": {},
            "ledger_breakdown": {},
            "season_wins": 0,
            "season_bottoms": 0,
            "ranked_seasons": 0,
            "responsibility_count": 0,
            "on_time_episode_count": 0,
            "late_episode_count": 0,
            "pending_episode_count": 0,
            "censored_episode_count": 0,
            "responsibility_source_counts": {},
            "completion_source_counts": {},
            "completion_weekday_counts": {},
            "adjustment_request_status_counts": {},
            "bounty_posted_count": 0,
            "bounty_posted_amounts": [],
            "normalized_rank_sum": 0,
            "normalized_rank_count": 0,
        }
    )
    occurrences = {key[1]: e for key, e in latest.items() if key[0] == "occurrence"}
    episodes = [e for (kind, _), e in latest.items() if kind == "episode"]
    completed_sources = {}
    for event in episodes:
        p = event["payload"]
        if (
            p.get("completed_by")
            and p.get("ended_at")
            and parse_time(p["ended_at"]) <= cutoff
        ):
            completed_sources[p["occurrence_id"]] = p.get("reason", "UNKNOWN")
    claimed = defaultdict(set)
    for (kind, _), event in latest.items():
        p = event["payload"]
        if kind == "member" and p.get("status") == "ACTIVE":
            people[p["member_id"]]
        if (
            kind == "occurrence"
            and p.get("completed_by")
            and included(p, "completed_at")
        ):
            person = people[p["completed_by"]]
            person["completed_count"] += 1
            person["standard_minutes"] += p.get("minutes", 0)
            person["snapshot_karma"] += p.get("karma", 0)
            source = completed_sources.get(event["entity_id"], "UNKNOWN_LEGACY")
            person["completion_source_counts"][source] = (
                person["completion_source_counts"].get(source, 0) + 1
            )
            weekday = str(parse_time(p["completed_at"]).astimezone(LOCAL).weekday())
            person["completion_weekday_counts"][weekday] = (
                person["completion_weekday_counts"].get(weekday, 0) + 1
            )
            person["evidence_ids"].append(event["event_id"])
            record(p["completed_by"], "completion", event["event_id"])
            template = p.get("template_id", "unknown")
            person["by_template"][template] = person["by_template"].get(template, 0) + 1
        if kind == "episode" and included(p, "started_at"):
            person = people[p["member_id"]]
            record(p["member_id"], "responsibility", event["event_id"])
            person["responsibility_count"] += 1
            source = p.get("reason", "UNKNOWN")
            person["responsibility_source_counts"][source] = (
                person["responsibility_source_counts"].get(source, 0) + 1
            )
            ended = parse_time(p.get("ended_at"))
            due = parse_time(p.get("deadline"))
            occurrence = occurrences.get(p.get("occurrence_id"), {}).get("payload", {})
            if (
                due is None
                or occurrence.get("status") in ("SKIPPED", "CANCELLED")
                or occurrence.get("due_at")
                and parse_time(occurrence["due_at"]) != due
            ):
                person["censored_episode_count"] += 1
            elif ended and ended <= cutoff and p.get("completed_by") == p["member_id"]:
                person[
                    "on_time_episode_count"
                    if due and ended <= due
                    else "late_episode_count"
                ] += 1
            elif ended and ended <= cutoff and (not due or ended <= due):
                person["censored_episode_count"] += 1
            elif due and cutoff > due:
                person["late_episode_count"] += 1
            else:
                person["pending_episode_count"] += 1
            person["evidence_ids"].append(event["event_id"])
            record(p["member_id"], "episode_outcome", event["event_id"])
            occurrence_event = occurrences.get(p.get("occurrence_id"))
            if occurrence_event:
                record(p["member_id"], "episode_outcome", occurrence_event["event_id"])
        if kind == "bounty":
            business = {
                **p,
                "season_id": occurrences.get(p.get("occurrence_id"), {})
                .get("payload", {})
                .get("season_id"),
            }
            if included(business, "created_at"):
                person = people[p["poster_id"]]
                person["bounty_posted_count"] += 1
                person["bounty_posted_amounts"].append(p["amount"])
                person["evidence_ids"].append(event["event_id"])
                record(p["poster_id"], "bounty_posted", event["event_id"])
        if kind == "proposal" and p.get("type") in ("CHORE_SWAP", "SCHEDULE_REPLAN"):
            payload = {k.lower(): v for k, v in p.get("payload", {}).items()}
            own = []
            source_id = payload.get("sourceoccurrenceid")
            if source_id and any(
                e["payload"].get("occurrence_id") == source_id
                and e["payload"].get("member_id") == p["actor_id"]
                and parse_time(e["payload"]["started_at"])
                <= parse_time(p["requested_at"])
                and (
                    not e["payload"].get("ended_at")
                    or parse_time(p["requested_at"])
                    <= parse_time(e["payload"]["ended_at"])
                )
                for e in episodes
            ):
                own.append(source_id)
            for change in payload.get("changes", []):
                fields = {k.lower(): v for k, v in change.items()}
                if fields.get("previoususerid") == p["actor_id"]:
                    own.append(fields["occurrenceid"])
            for occurrence_id in set(own):
                business = {
                    **p,
                    "season_id": occurrences.get(occurrence_id, {})
                    .get("payload", {})
                    .get("season_id"),
                }
                if included(business, "requested_at"):
                    person = people[p["actor_id"]]
                    status = p.get("status", "UNKNOWN")
                    person["adjustment_request_status_counts"][status] = (
                        person["adjustment_request_status_counts"].get(status, 0) + 1
                    )
                    person["evidence_ids"].append(event["event_id"])
        if kind == "ledger" and included(p, "created_at"):
            person = people[p["member_id"]]
            kind_name = p["type"]
            person["ledger_breakdown"][kind_name] = (
                person["ledger_breakdown"].get(kind_name, 0) + p["amount"]
            )
            person["evidence_ids"].append(event["event_id"])
        if kind == "ranking" and included(p, "finalized_at"):
            person = people[p["member_id"]]
            record(p["member_id"], "ranking", event["event_id"])
            if p.get("member_count", 0) > 1:
                person["normalized_rank_sum"] += 1 - (p["rank"] - 1) / (
                    p["member_count"] - 1
                )
                person["normalized_rank_count"] += 1
            person["ranked_seasons"] += 1
            person["season_wins"] += int(p["rank"] == 1)
            person["season_bottoms"] += int(
                p.get("member_count", 0) > 1 and p["rank"] == p["member_count"]
            )
            person["evidence_ids"].append(event["event_id"])
        if (
            kind == "episode"
            and p.get("reason") == "BOUNTY"
            and included(p, "started_at")
        ):
            actor = p["member_id"]
            person = people[actor]
            person["bounty_claim_count"] += 1
            record(actor, "bounty_claim", event["event_id"])
            record(actor, "bounty_outcome", event["event_id"])
            claimed[actor].add(p["occurrence_id"])
            person["evidence_ids"].append(event["event_id"])
            if p.get("ended_at") and not p.get("completed_by"):
                person["transfer_count"] += 1
    for actor, ids in claimed.items():
        person = people[actor]
        person["bounty_occurrence_count"] = len(ids)
        for occurrence_id in ids:
            if occurrence_id in occurrences:
                record(actor, "bounty_outcome", occurrences[occurrence_id]["event_id"])
            occurrence = occurrences.get(occurrence_id, {}).get("payload", {})
            completed = parse_time(occurrence.get("completed_at"))
            if completed and completed <= cutoff and occurrence.get("completed_by"):
                person[
                    "bounty_self_completed"
                    if occurrence.get("completed_by") == actor
                    else "bounty_other_completed"
                ] += 1
            elif occurrence.get("status") in ("CANCELLED", "SKIPPED"):
                person["bounty_cancelled"] += 1
            elif not occurrence:
                person["bounty_unknown"] += 1
            elif occurrence and parse_time(occurrence["due_at"]) < cutoff:
                person["bounty_overdue_open"] += 1
            else:
                person["bounty_pending"] += 1
    declarations = preference_history(history, cutoff, since, period)
    profile_version = canonical_hash(
        {
            "events": [latest[k] for k in sorted(latest)],
            "as_of": cutoff.isoformat(),
            "period": period,
            "season_id": season_id,
            "definition_version": PROFILE_VERSION,
            "declared_preference_history": declarations,
        }
    )
    for member in declarations:
        people[member]
    items = []
    for member_id, values in sorted(people.items()):
        values["evidence_ids"] = list(dict.fromkeys(values["evidence_ids"]))
        known = values["bounty_self_completed"] + values["bounty_other_completed"]
        items.append(
            {
                "member_id": member_id,
                **values,
                "bounty_self_completion_rate": values["bounty_self_completed"] / known
                if known
                else None,
                "bounty_outcome_denominator": known,
                "on_time_episode_rate": values["on_time_episode_count"]
                / (values["on_time_episode_count"] + values["late_episode_count"])
                if values["on_time_episode_count"] + values["late_episode_count"]
                else None,
                "on_time_episode_denominator": values["on_time_episode_count"]
                + values["late_episode_count"],
                "mean_normalized_rank": values["normalized_rank_sum"]
                / values["normalized_rank_count"]
                if values["normalized_rank_count"]
                else None,
                "quality": "BUSINESS_FACTS",
                "actual_duration_minutes": None,
                "metric_context": {
                    "period": period,
                    "season_id": season_id,
                    "as_of": cutoff.isoformat(),
                    "sample_count": values["completed_count"],
                    "source": "CORE_TELEMETRY",
                    "version": PROFILE_VERSION,
                },
            }
        )
        item = items[-1]
        item["metrics"] = metric_records(
            item, lineage[member_id], item["metric_context"]
        )
        for metric in item["metrics"].values():
            metric["profile_version"] = profile_version
        item["preference_profile"] = declarations.get(member_id, [])
    return {
        "items": items,
        "as_of": cutoff.isoformat(),
        "profile_version": profile_version,
        "event_count": len(history),
        "period": period,
        "season_id": season_id,
        "evidence_count": len({i for p in items for i in p["evidence_ids"]}),
        "interpretation": "Effort is standardized, not measured working time. Participation does not imply personality or obligation.",
    }


def experience_from_profiles(data: dict) -> dict:
    return {
        f"{p['member_id']}:{template}": min(count, 20)
        for p in data["items"]
        for template, count in p["by_template"].items()
    }
