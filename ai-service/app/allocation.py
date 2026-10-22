import time
from collections import Counter
from datetime import datetime, timedelta, timezone
from functools import lru_cache
from itertools import chain, combinations
from zoneinfo import ZoneInfo

from app.schemas import Context, Member, Task
from app.storage import canonical_hash

LOCAL = ZoneInfo("Asia/Ho_Chi_Minh")
POLICY_VERSION = "allocation-v2"
METRIC_VERSION = "metrics-v1"


def local_date(task: Task):
    return local_day(task.due_at)


@lru_cache(maxsize=8192)
def local_day(due_at: datetime):
    return due_at.astimezone(LOCAL).date()


def find_start(
    task: Task, member: Member, tasks: list[Task], not_before: datetime | None = None
) -> datetime | None:
    day = local_date(task)
    assigned = [t for t in tasks if t.assigned_to == member.id and t.id != task.id]
    if (
        sum(local_date(t).isocalendar()[:2] == day.isocalendar()[:2] for t in assigned)
        >= member.max_chores_per_week
    ):
        return None
    if (
        sum(t.minutes for t in assigned if local_date(t) == day) + task.minutes
        > member.max_minutes_per_day
    ):
        return None
    if day.isoformat() in member.date_exceptions:
        windows = [(w.start, w.end) for w in member.date_exceptions[day.isoformat()]]
    else:
        availability = next(
            (a for a in member.availability if a.day == (day.weekday() + 1) % 7), None
        )
        if not availability or not availability.available:
            return None
        windows = [(w.start, w.end) for w in availability.slots] or [(0, 1440)]
    for start_minute, end_minute in sorted(windows):
        midnight = datetime.combine(day, datetime.min.time(), LOCAL)
        start = (midnight + timedelta(minutes=start_minute)).astimezone(timezone.utc)
        if not_before is not None:
            start = max(start, not_before)
        end = min(
            (midnight + timedelta(minutes=end_minute)).astimezone(timezone.utc),
            task.due_at,
        )
        for booked in sorted(
            (
                t
                for t in assigned
                if t.start_at and t.status not in ("COMPLETED", "SKIPPED")
            ),
            key=lambda t: t.start_at,
        ):
            occupied_end = booked.start_at + timedelta(minutes=booked.minutes)
            if occupied_end <= start or booked.start_at >= end:
                continue
            if start + timedelta(minutes=task.minutes) <= booked.start_at:
                break
            start = max(start, occupied_end)
        if start + timedelta(minutes=task.minutes) <= end:
            return start
    return None


def preference(task: Task, member: Member | None) -> int:
    if member is None:
        return 0
    return {"PREFERRED": -1, "DISLIKED": 1}.get(
        member.preferences.get(str(task.template_id)), 0
    )


def baseline(context: Context) -> list[Task]:
    tasks = [t.model_copy(deep=True) for t in context.tasks]
    for task in sorted(
        (t for t in tasks if t.assigned_to is None and not t.locked),
        key=lambda t: (t.due_at, -t.karma, str(t.id)),
    ):
        candidates = []
        for member in context.members:
            start = find_start(
                task,
                member,
                tasks,
                context.as_of if context.status == "ACTIVE" else None,
            )
            if start is None:
                continue
            assigned = [t for t in tasks if t.assigned_to == member.id]
            previous_monday = local_date(task) - timedelta(
                days=local_date(task).weekday() + 7
            )
            rotation = any(
                t.template_id == task.template_id
                and previous_monday
                <= local_date(t)
                < previous_monday + timedelta(days=7)
                for t in assigned
            )
            candidates.append(
                (
                    (
                        sum(t.karma for t in assigned),
                        int(rotation),
                        preference(task, member),
                        len(assigned),
                        str(member.id),
                    ),
                    member,
                    start,
                )
            )
        if candidates:
            _, member, start = min(candidates, key=lambda x: x[0])
            task.assigned_to, task.start_at = member.id, start
    return tasks


def measure(context: Context, tasks: list[Task]) -> dict:
    members = {m.id: m for m in context.members}
    assigned = [t for t in tasks if t.assigned_to is not None]
    days = {t.id: local_date(t) for t in tasks}
    weekly = Counter((t.assigned_to, days[t.id].isocalendar()[:2]) for t in assigned)
    effort_by_day = Counter()
    karma_load = Counter()
    effort_load = Counter()
    bookings = {}
    for task in assigned:
        effort_by_day[(task.assigned_to, days[task.id])] += task.minutes
        karma_load[task.assigned_to] += task.karma
        effort_load[task.assigned_to] += task.minutes
        if task.start_at and task.status not in ("COMPLETED", "SKIPPED"):
            bookings.setdefault(task.assigned_to, []).append(task)
    overlaps = set()
    for booked in bookings.values():
        previous = None
        maximum = None
        for task in sorted(booked, key=lambda t: (t.start_at, str(t.id))):
            if maximum is not None and maximum > task.start_at:
                overlaps.add(task.id)
                overlaps.add(previous.id)
            end = task.start_at + timedelta(minutes=task.minutes)
            if maximum is None or end > maximum:
                maximum = end
                previous = task
    violations = set()
    windows_cache = {}
    for task in assigned:
        if (
            task.status in ("COMPLETED", "SKIPPED")
            or context.status != "DRAFT"
            and task.locked
            and task.id not in context.constraint_task_ids
        ):
            continue
        member = members[task.assigned_to]
        day = days[task.id]
        key = (member.id, day)
        if key not in windows_cache:
            exception = member.date_exceptions.get(day.isoformat())
            if exception is not None:
                windows = [(w.start, w.end) for w in exception]
            else:
                availability = next(
                    (
                        a
                        for a in member.availability
                        if a.day == (day.weekday() + 1) % 7
                    ),
                    None,
                )
                windows = (
                    ([(w.start, w.end) for w in availability.slots] or [(0, 1440)])
                    if availability and availability.available
                    else []
                )
            midnight = datetime.combine(day, datetime.min.time(), LOCAL)
            windows_cache[key] = [
                (midnight + timedelta(minutes=a), midnight + timedelta(minutes=b))
                for a, b in windows
            ]
        if task.start_at is None:
            violations.add(task.id)
            continue
        actual = task.start_at.astimezone(LOCAL)
        end = actual + timedelta(minutes=task.minutes)
        if (
            weekly[(member.id, day.isocalendar()[:2])] > member.max_chores_per_week
            or effort_by_day[key] > member.max_minutes_per_day
            or actual.date() != day
            or end > task.due_at
            or task.id in overlaps
            or not any(a <= actual and end <= b for a, b in windows_cache[key])
        ):
            violations.add(task.id)
    karma = [karma_load[m.id] for m in context.members]
    effort = [effort_load[m.id] for m in context.members]
    fits = [preference(t, members.get(t.assigned_to)) for t in assigned]
    preferred, disliked = fits.count(-1), fits.count(1)
    mean = sum(karma) / len(karma) if karma else 0
    gap = max(karma, default=0) - min(karma, default=0)
    first = min(days.values(), default=None)
    assigned_weeks = {
        (
            t.assigned_to,
            t.template_id,
            days[t.id] - timedelta(days=days[t.id].weekday()),
        )
        for t in assigned
    }
    rotation = []
    for task in assigned:
        previous = days[task.id] - timedelta(days=days[task.id].weekday() + 7)
        if first is not None and first <= previous:
            rotation.append(
                (task.assigned_to, task.template_id, previous) in assigned_weeks
            )
    valid = len(assigned) - len(violations)
    return {
        "coverage_count": valid,
        "assigned_count": len(assigned),
        "task_count": len(tasks),
        "coverage": valid / len(tasks) if tasks else None,
        "karma_gap": gap,
        "karma_range_pct": 100 * gap / mean if mean else 0,
        "preferred_count": preferred,
        "disliked_count": disliked,
        "hard_violations": len(violations),
        "preference_eligible_count": preferred + disliked,
        "declared_preference_alignment": preferred / (preferred + disliked)
        if preferred + disliked
        else None,
        "rotation_repeat_count": sum(rotation),
        "rotation_eligible_count": len(rotation),
        "rotation_repeat_rate": sum(rotation) / len(rotation) if rotation else None,
        "workload_concentration": sum((v / sum(effort)) ** 2 for v in effort)
        if sum(effort)
        else None,
    }


def objective(
    context: Context,
    tasks: list[Task],
    experience: dict,
    known_valid: bool = False,
    prepared: dict | None = None,
) -> tuple:
    prepared = prepared or objective_context(context, experience)
    assigned = [t for t in tasks if t.assigned_to]
    if known_valid:
        loads = Counter()
        for task in assigned:
            loads[task.assigned_to] += task.karma
        values = [loads[m.id] for m in context.members]
        members = prepared["members"]
        fits = [preference(t, members.get(t.assigned_to)) for t in assigned]
        m = {
            "hard_violations": 0,
            "coverage_count": len(assigned),
            "karma_gap": max(values, default=0) - min(values, default=0),
            "disliked_count": fits.count(1),
            "preferred_count": fits.count(-1),
        }
    else:
        m = measure(context, tasks)
    first = prepared["first"]
    weekly = {
        (
            t.assigned_to,
            t.template_id,
            prepared["week"][t.id],
        )
        for t in assigned
    }
    repeat = 0
    for task in assigned:
        previous = prepared["previous"][task.id]
        repeat += int(
            first is not None
            and previous >= first
            and (task.assigned_to, task.template_id, previous) in weekly
        )
    experienced = sum(
        prepared["experience"].get(
            (t.assigned_to, t.history_template_id or t.template_id), 0
        )
        for t in tasks
        if t.assigned_to
    )
    original = prepared["original"]
    churn = sum(
        t.assigned_to != original[t.id].assigned_to
        or t.start_at != original[t.id].start_at
        for t in tasks
    )
    return (
        m["hard_violations"],
        -m["coverage_count"],
        m["karma_gap"],
        m["disliked_count"],
        -m["preferred_count"],
        repeat,
        -experienced,
        churn,
    )


def objective_context(context: Context, experience: dict) -> dict:
    weeks = {
        t.id: local_date(t) - timedelta(days=local_date(t).weekday())
        for t in context.tasks
    }
    templates = {t.history_template_id or t.template_id for t in context.tasks}
    return {
        "first": min((local_date(t) for t in context.tasks), default=None),
        "members": {m.id: m for m in context.members},
        "week": weeks,
        "previous": {key: week - timedelta(days=7) for key, week in weeks.items()},
        "original": {t.id: t for t in context.tasks},
        "experience": {
            (m.id, template): experience.get(f"{m.id}:{template}", 0)
            for m in context.members
            for template in templates
        },
    }


def gate(context: Context, base: list[Task], candidate: list[Task]) -> tuple[bool, str]:
    b, c = measure(context, base), measure(context, candidate)
    fixed = {str(t.id): t for t in context.tasks if t.locked}
    if any(
        t.model_dump() != fixed[str(t.id)].model_dump()
        for t in candidate
        if str(t.id) in fixed
    ):
        return False, "LOCKED_ITEM_CHANGED"
    common = {t.id for t in base if t.assigned_to} & {
        t.id for t in candidate if t.assigned_to
    }
    members = {m.id: m for m in context.members}
    pref_b = sum(
        preference(t, members.get(t.assigned_to)) == -1 for t in base if t.id in common
    )
    pref_c = sum(
        preference(t, members.get(t.assigned_to)) == -1
        for t in candidate
        if t.id in common
    )
    dislike_b = sum(
        preference(t, members.get(t.assigned_to)) == 1 for t in base if t.id in common
    )
    dislike_c = sum(
        preference(t, members.get(t.assigned_to)) == 1
        for t in candidate
        if t.id in common
    )
    if (
        c["hard_violations"]
        or c["coverage_count"] < b["coverage_count"]
        or c["karma_gap"] > b["karma_gap"]
        or dislike_c > dislike_b
    ):
        return False, "GUARDRAIL_REJECTED"
    if context.status == "ACTIVE" and b["hard_violations"] > 0:
        return True, "CONFIRMED_AVAILABILITY_CONSTRAINT_REPAIRED"
    if c["coverage_count"] > b["coverage_count"]:
        return True, "COVERAGE_IMPROVED"
    if (
        b["karma_gap"]
        and b["karma_gap"] - c["karma_gap"] >= 1
        and c["karma_gap"] <= b["karma_gap"] * 0.9
    ):
        return True, "FAIRNESS_IMPROVED"
    if (
        common
        and pref_c - pref_b >= 1
        and (pref_c - pref_b) / len(common) >= 0.1 - 1e-12
    ):
        return True, "DECLARED_PREFERENCE_IMPROVED"
    return False, "NO_MATERIAL_IMPROVEMENT"


def neighbor_objective(
    best: list[Task],
    candidate: list[Task],
    changed: list[int],
    prepared: dict,
    score: tuple,
    loads: Counter,
    weekly: Counter,
) -> tuple:
    new_loads = loads.copy()
    delta = Counter()
    disliked, preferred, experienced, churn = score[3], -score[4], -score[6], score[7]
    for index in changed:
        old, new = best[index], candidate[index]
        week = prepared["week"][old.id]
        delta[(old.assigned_to, old.template_id, week)] -= 1
        delta[(new.assigned_to, new.template_id, week)] += 1
        new_loads[old.assigned_to] -= old.karma
        new_loads[new.assigned_to] += new.karma
        before, after = [
            preference(t, prepared["members"].get(t.assigned_to)) for t in (old, new)
        ]
        disliked += int(after == 1) - int(before == 1)
        preferred += int(after == -1) - int(before == -1)
        experienced += prepared["experience"].get(
            (new.assigned_to, new.history_template_id or new.template_id), 0
        ) - prepared["experience"].get(
            (old.assigned_to, old.history_template_id or old.template_id), 0
        )
        original = prepared["original"][old.id]
        churn += int(
            (new.assigned_to, new.start_at) != (original.assigned_to, original.start_at)
        ) - int(
            (old.assigned_to, old.start_at) != (original.assigned_to, original.start_at)
        )
    affected = set(delta) | {
        (member, template, week + timedelta(days=7)) for member, template, week in delta
    }
    repeat = score[5]
    for key in affected:
        member, template, week = key
        previous = (member, template, week - timedelta(days=7))
        if previous[2] >= prepared["first"]:
            repeat += (weekly[key] + delta[key]) * int(
                weekly[previous] + delta[previous] > 0
            ) - weekly[key] * int(weekly[previous] > 0)
    values = [new_loads[member] for member in prepared["members"]]
    return (
        0,
        score[1],
        max(values, default=0) - min(values, default=0),
        disliked,
        -preferred,
        repeat,
        -experienced,
        churn,
    )


def optimize(
    context: Context,
    experience: dict | None = None,
    move_budget: int = 10000,
    timeout: float | None = 4,
) -> dict:
    started = time.monotonic()
    base = baseline(context)
    known_valid = measure(context, base)["hard_violations"] == 0
    best = [t.model_copy(deep=True) for t in base]
    experience = experience or {}
    prepared = objective_context(context, experience)
    evaluated = 0
    timed_out = False
    while evaluated < move_budget:
        options = (
            ("move", (i, m.id))
            for i, t in enumerate(best)
            if not t.locked
            for m in sorted(context.members, key=lambda m: str(m.id))
            if m.id != t.assigned_to
        )
        moves = (
            ("swap", (i, j))
            for i, j in combinations(range(len(best)), 2)
            if not best[i].locked
            and not best[j].locked
            and best[i].assigned_to
            and best[j].assigned_to
            and best[i].assigned_to != best[j].assigned_to
        )
        time_moves = (
            ("move", (i, t.assigned_to))
            for i, t in enumerate(best)
            if context.status == "ACTIVE" and not t.locked and t.assigned_to
        )
        selected, score = (
            None,
            objective(context, best, experience, known_valid, prepared),
        )
        initial_score = score
        fast_neighbors = known_valid and all(t.assigned_to for t in best)
        loads = Counter()
        for t in best:
            loads[t.assigned_to] += t.karma
        weekly = Counter(
            (t.assigned_to, t.template_id, prepared["week"][t.id])
            for t in best
            if t.assigned_to
        )
        for kind, indices in chain(time_moves, options, moves):
            if evaluated >= move_budget:
                break
            if timeout is not None and time.monotonic() - started >= timeout:
                timed_out = True
                break
            evaluated += 1
            candidate = list(best)
            i, other = indices
            candidate[i] = candidate[i].model_copy()
            if kind == "move":
                candidate[i].assigned_to, candidate[i].start_at = other, None
                start = find_start(
                    candidate[i],
                    next(m for m in context.members if m.id == other),
                    candidate,
                    context.as_of if context.status == "ACTIVE" else None,
                )
                if start is None:
                    continue
                candidate[i].start_at = start
            else:
                j = other
                candidate[j] = candidate[j].model_copy()
                candidate[i].assigned_to, candidate[j].assigned_to = (
                    candidate[j].assigned_to,
                    candidate[i].assigned_to,
                )
                candidate[i].start_at = candidate[j].start_at = None
                possible = True
                for k in (i, j):
                    t = candidate[k]
                    t.start_at = find_start(
                        t,
                        next(m for m in context.members if m.id == t.assigned_to),
                        candidate,
                        context.as_of if context.status == "ACTIVE" else None,
                    )
                    possible &= t.start_at is not None
                if not possible:
                    continue
            # Fill newly available capacity using the same deterministic baseline recipe.
            if any(t.assigned_to is None and not t.locked for t in candidate):
                candidate = baseline(context.model_copy(update={"tasks": candidate}))
            new_score = (
                neighbor_objective(
                    best,
                    candidate,
                    [i] if kind == "move" else [i, other],
                    prepared,
                    initial_score,
                    loads,
                    weekly,
                )
                if fast_neighbors
                else objective(context, candidate, experience, known_valid, prepared)
            )
            if new_score < score:
                selected, score = candidate, new_score
        if timed_out or selected is None:
            break
        best = selected
    accepted, reason = gate(context, base, best)
    served = best if accepted and not timed_out else base
    served_metrics = measure(context, served)
    return {
        "status": "INFEASIBLE"
        if served_metrics["hard_violations"]
        else ("PARTIAL" if served_metrics["coverage_count"] < len(served) else "READY"),
        "constraint_scope": "EDITABLE_FUTURE_WITH_FIXED_HISTORY_AND_BOOKINGS"
        if context.status != "DRAFT"
        else "ENTIRE_DRAFT",
        "tasks": [t.model_dump(mode="json") for t in served],
        "baseline": [t.model_dump(mode="json") for t in base],
        "candidate_metrics": measure(context, best),
        "metrics": served_metrics,
        "baseline_metrics": measure(context, base),
        "accepted": accepted and not timed_out,
        "reason": "OPTIMIZER_BUDGET_EXCEEDED" if timed_out else reason,
        "evaluation_mode": "SERVING_DEADLINE"
        if timeout is not None
        else "BUDGET_COMPLETE",
        "moves": evaluated,
        "duration_ms": round((time.monotonic() - started) * 1000, 2),
        "context_hash": canonical_hash(context.model_dump(mode="json")),
        "policy_version": POLICY_VERSION,
        "data_source": context.data_source,
        "inference_source": "PROFILE" if experience else "RULE",
    }
