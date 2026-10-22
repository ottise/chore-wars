from app.allocation import find_start, measure, preference
from app.schemas import Context


def find_swap(context: Context, source_id, actor):
    source = next((t for t in context.tasks if t.id == source_id), None)
    if (
        context.status != "ACTIVE"
        or source is None
        or source.locked
        or source.assigned_to != actor
    ):
        raise ValueError("Own unlocked active responsibility required")
    members = {m.id: m for m in context.members}
    choices = []
    for target in sorted(context.tasks, key=lambda t: str(t.id)):
        if (
            target.id == source.id
            or target.locked
            or target.assigned_to is None
            or target.assigned_to == actor
        ):
            continue
        tasks = [t.model_copy(deep=True) for t in context.tasks]
        a = next(t for t in tasks if t.id == source.id)
        b = next(t for t in tasks if t.id == target.id)
        a.assigned_to, b.assigned_to = b.assigned_to, a.assigned_to
        a.start_at = b.start_at = None
        possible = True
        for t in (a, b):
            t.start_at = find_start(t, members[t.assigned_to], tasks, context.as_of)
            possible &= t.start_at is not None
        if not possible or measure(context, tasks)["hard_violations"]:
            continue
        score = preference(a, members[a.assigned_to]) + preference(
            b, members[b.assigned_to]
        )
        choices.append((score, str(target.id), target, tasks))
    if not choices:
        return {
            "tasks": [t.model_dump(mode="json") for t in context.tasks],
            "reason": "NO_FEASIBLE_SWAP",
            "accepted": False,
            "data_source": context.data_source,
            "inference_source": "RULE",
        }
    _, _, target, tasks = min(choices, key=lambda c: (c[0], c[1]))
    return {
        "tasks": [t.model_dump(mode="json") for t in tasks],
        "reason": "FEASIBLE_SWAP_REQUIRES_CONSENT",
        "accepted": True,
        "swap_payload": {
            "SourceOccurrenceId": str(source.id),
            "TargetOccurrenceId": str(target.id),
        },
        "target_member_id": str(target.assigned_to),
        "metrics": measure(context, tasks),
        "data_source": context.data_source,
        "inference_source": "RULE",
    }
