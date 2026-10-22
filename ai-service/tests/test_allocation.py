from collections import Counter
from datetime import timedelta
from uuid import UUID

from app.allocation import (
    baseline,
    gate,
    measure,
    neighbor_objective,
    objective,
    objective_context,
    optimize,
)


def test_baseline_deterministic_and_balanced(context):
    tasks = baseline(context)
    assert [t.model_dump() for t in tasks] == [
        t.model_dump() for t in baseline(context)
    ]
    result = measure(context, tasks)
    assert result["coverage_count"] == 6
    assert result["karma_gap"] == 0
    assert result["hard_violations"] == 0
    assert tasks[0].assigned_to == UUID(int=1)


def test_capacity_no_forced_fallback(context):
    for member in context.members:
        member.max_chores_per_week = 1
    assert measure(context, baseline(context))["coverage_count"] == 3


def test_exception_busy_overrides_weekly(context):
    for member in context.members:
        member.date_exceptions["2026-01-02"] = []
    assert not any(t.assigned_to for t in baseline(context))


def test_disliked_can_not_bypass_fairness(context):
    base = baseline(context)
    candidate = [t.model_copy(deep=True) for t in base]
    candidate[0].assigned_to = UUID(int=2)
    accepted, reason = gate(context, base, candidate)
    assert not accepted
    assert reason == "GUARDRAIL_REJECTED"


def test_timeout_serves_baseline(context):
    result = optimize(context, move_budget=1000, timeout=0)
    assert result["tasks"] == result["baseline"]
    assert result["reason"] == "OPTIMIZER_BUDGET_EXCEEDED"


def test_rotation_only_is_not_material(context):
    base = baseline(context)
    assert gate(context, base, base) == (False, "NO_MATERIAL_IMPROVEMENT")


def test_actual_overlap_is_violation(context):
    base = baseline(context)
    first = [t for t in base if t.assigned_to == UUID(int=1)]
    first[1].start_at = first[0].start_at
    assert measure(context, base)["hard_violations"] >= 1


def test_fast_objective_has_same_result_for_valid_schedules(context):
    tasks = baseline(context)
    experience = {f"{tasks[0].assigned_to}:{tasks[0].template_id}": 4}
    assert objective(context, tasks, experience, True) == objective(
        context, tasks, experience, False
    )


def test_incremental_neighbor_score_matches_full_score_across_weeks(context):
    initial = baseline(context)
    tasks = [
        task.model_copy(
            update={
                "id": UUID(int=1000 + week * len(initial) + i),
                "due_at": task.due_at + timedelta(days=week * 7),
                "start_at": task.start_at + timedelta(days=week * 7),
            }
        )
        for week in range(4)
        for i, task in enumerate(initial)
    ]
    context = context.model_copy(update={"tasks": tasks})
    for i, member in enumerate(context.members):
        member.preferences = {
            str(task.template_id): "PREFERRED" if i % 2 else "DISLIKED"
            for task in tasks[:2]
        }
    experience = {
        f"{member.id}:{task.template_id}": i + 2
        for i, member in enumerate(context.members)
        for task in tasks[:2]
    }
    prepared = objective_context(context, experience)
    score = objective(context, tasks, experience, True)
    loads = Counter()
    for task in tasks:
        loads[task.assigned_to] += task.karma
    weekly = Counter(
        (t.assigned_to, t.template_id, prepared["week"][t.id]) for t in tasks
    )
    for i in range(len(tasks)):
        for j in range(i + 1, len(tasks)):
            candidate = list(tasks)
            candidate[i] = tasks[i].model_copy(
                update={"assigned_to": tasks[j].assigned_to}
            )
            candidate[j] = tasks[j].model_copy(
                update={
                    "assigned_to": tasks[i].assigned_to,
                    "start_at": tasks[j].start_at + timedelta(minutes=15),
                }
            )
            assert neighbor_objective(
                tasks, candidate, [i, j], prepared, score, loads, weekly
            ) == objective(context, candidate, experience, True)
