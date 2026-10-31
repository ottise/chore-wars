from app.allocation import find_start, measure, preference
from app.schemas import Context


def find_swap(context: Context, source_id, actor, target_member_id=None):
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
            for task in (a, b):
                member = members.get(task.assigned_to)
                if member is None:
                    possible = False
                    break
                task.start_at = find_start(task, member, tasks, context.as_of)
                possible &= task.start_at is not None
            if not possible or measure(context, tasks)["hard_violations"]:
                continue
            score = preference(a, members[a.assigned_to]) + preference(
                b, members[b.assigned_to]
            )
            choices.append(
                (
                    score,
                    str(source.id),
                    str(target.id),
                    str(target.assigned_to),
                    target,
                    tasks,
                )
            )
    if not choices:
        return {
            "tasks": [t.model_dump(mode="json") for t in context.tasks],
            "reason": "NO_FEASIBLE_SWAP",
            "accepted": False,
            "data_source": context.data_source,
            "inference_source": "RULE",
        }
    _, source_key, _, other_member_id, target, tasks = min(
        choices, key=lambda c: (c[0], c[1], c[2])
    )
    return {
        "tasks": [t.model_dump(mode="json") for t in tasks],
        "reason": "FEASIBLE_SWAP_REQUIRES_CONSENT",
        "accepted": True,
        "swap_payload": {
            "SourceOccurrenceId": source_key,
            "TargetOccurrenceId": str(target.id),
        },
        "target_member_id": other_member_id,
        "metrics": measure(context, tasks),
        "data_source": context.data_source,
        "inference_source": "RULE",
    }
