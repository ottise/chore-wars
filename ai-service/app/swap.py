from datetime import datetime, time, timezone

from app.allocation import LOCAL, find_start, measure, preference
from app.schemas import Context


def find_swap(
    context: Context,
    source_id,
    actor,
    target_member_id=None,
    target_occurrence_id=None,
):
    if context.status != "ACTIVE":
        raise ValueError("An active schedule is required")
    sources = [
        task
        for task in context.tasks
        if task.assigned_to == actor
        and not task.locked
        and task.status == "ASSIGNED"
        and task.due_at > context.as_of
        and (source_id is None or task.id == source_id)
    ]
    if not sources:
        raise ValueError("Own unlocked active responsibility required")
    members = {m.id: m for m in context.members}
    choices = []
    targets = sorted(
        (
            task
            for task in context.tasks
            if task.assigned_to is not None
            and task.assigned_to != actor
            and not task.locked
            and task.status == "ASSIGNED"
            and task.due_at > context.as_of
            and (target_member_id is None or task.assigned_to == target_member_id)
            and (target_occurrence_id is None or task.id == target_occurrence_id)
        ),
        key=lambda task: str(task.id),
    )
    for source in sources:
        for target in targets:
            tasks = [t.model_copy(deep=True) for t in context.tasks]
            a = next(t for t in tasks if t.id == source.id)
            b = next(t for t in tasks if t.id == target.id)
            a.assigned_to, b.assigned_to = b.assigned_to, a.assigned_to
            a.start_at = b.start_at = None
            possible = True
            availability_overridden = False
            forced_time = False
            for task in (a, b):
                member = members.get(task.assigned_to)
                if member is None:
                    possible = False
                    break
                task.start_at = find_start(task, member, tasks, context.as_of)
                if task.start_at is None:
                    task.start_at = find_start(
                        task, member, tasks, context.as_of, ignore_availability=True
                    )
                    availability_overridden |= task.start_at is not None
                if task.start_at is None:
                    midnight = datetime.combine(
                        task.due_at.astimezone(LOCAL).date(), time.min, LOCAL
                    ).astimezone(timezone.utc)
                    task.start_at = max(context.as_of, midnight)
                    forced_time = True
            if not possible:
                continue
            metrics = measure(context, tasks, ignore_availability_for={a.id, b.id})
            warning_reasons = []
            if availability_overridden:
                warning_reasons.append("OUTSIDE_DECLARED_AVAILABILITY")
            if metrics["hard_violations"] or forced_time:
                warning_reasons.append("SCHEDULE_OVERLAP_CAPACITY_OR_DEADLINE")
            score = preference(a, members[a.assigned_to]) + preference(
                b, members[b.assigned_to]
            )
            choices.append(
                (
                    score,
                    str(source.id),
                    str(target.id),
                    str(target.assigned_to),
                    source,
                    target,
                    tasks,
                    availability_overridden,
                    warning_reasons,
                    metrics,
                )
            )
    if not choices:
        return {
            "tasks": [t.model_dump(mode="json") for t in context.tasks],
            "reason": "NO_FEASIBLE_SWAP" if targets else "TARGET_NOT_ELIGIBLE",
            "diagnostic": (
                "AVAILABILITY_CAPACITY_DEADLINE_OR_OVERLAP"
                if targets
                else "SELECTED_TARGET_IS_NOT_AN_UNLOCKED_FUTURE_TASK_OF_THAT_MEMBER"
            ),
            "candidate_target_count": len(targets),
            "accepted": False,
            "data_source": context.data_source,
            "inference_source": "RULE",
        }
    _, source_key, _, other_member_id, source, target, tasks, availability_overridden, warning_reasons, metrics = min(
        choices, key=lambda c: (c[0], c[1], c[2])
    )
    return {
        "tasks": [t.model_dump(mode="json") for t in tasks],
        "reason": "SWAP_REQUIRES_CONSENT",
        "diagnostic": "READY_FOR_TARGET_MEMBER_CONFIRMATION",
        "accepted": True,
        "swap_payload": {
            "SourceOccurrenceId": source_key,
            "TargetOccurrenceId": str(target.id),
            "AIRequested": True,
            "ScheduleWarning": bool(warning_reasons),
            "ScheduleWarningReasons": warning_reasons,
        },
        "target_member_id": other_member_id,
        "availability_overridden": availability_overridden,
        "schedule_warning": bool(warning_reasons),
        "schedule_warning_reasons": warning_reasons,
        "metrics": metrics,
        "data_source": context.data_source,
        "inference_source": "RULE",
    }
