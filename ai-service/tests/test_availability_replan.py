from datetime import datetime, timezone
from uuid import UUID

from app.allocation import baseline, measure, optimize
from app.schemas import Window


def test_active_busy_replan_repairs_time_without_claiming_learning(context):
    tasks = baseline(context)
    for task in tasks:
        task.locked = task.assigned_to != UUID(int=1)
    active = context.model_copy(
        update={
            "status": "ACTIVE",
            "tasks": tasks,
            "as_of": datetime(2026, 1, 2, 0, tzinfo=timezone.utc),
        }
    )
    active.members[0].date_exceptions["2026-01-02"] = [Window(start=600, end=1200)]
    result = optimize(active, timeout=None)
    assert result["status"] == "READY"
    assert result["reason"] == "CONFIRMED_AVAILABILITY_CONSTRAINT_REPAIRED"
    assert result["metrics"]["hard_violations"] == 0
    assert result["inference_source"] == "RULE"
    assert all(
        t["assigned_to"] == str(before.assigned_to)
        for t, before in zip(result["tasks"], tasks)
    )


def test_busy_exception_cannot_ignore_affected_locked_booking(context):
    tasks = baseline(context)
    for task in tasks:
        task.locked = True
    affected = tasks[0]
    active = context.model_copy(
        update={
            "status": "ACTIVE",
            "tasks": tasks,
            "constraint_task_ids": [affected.id],
        }
    )
    next(m for m in active.members if m.id == affected.assigned_to).date_exceptions[
        "2026-01-02"
    ] = []
    assert measure(active, tasks)["hard_violations"] == 1
    assert optimize(active, timeout=None)["status"] == "INFEASIBLE"
