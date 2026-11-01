from uuid import UUID

from app.allocation import baseline
from app.schemas import SwapInput
from app.swap import find_swap


def test_swap_can_choose_both_chores_automatically(context):
    actor = UUID(int=1)
    active = context.model_copy(update={"status": "ACTIVE"})
    tasks = baseline(active)
    active = active.model_copy(update={"tasks": tasks})

    result = find_swap(active, None, actor)

    assert result["accepted"] is True
    swap = result["swap_payload"]
    source = next(task for task in tasks if str(task.id) == swap["SourceOccurrenceId"])
    target = next(task for task in tasks if str(task.id) == swap["TargetOccurrenceId"])
    assert source.assigned_to == actor
    assert target.assigned_to != actor
    assert result["target_member_id"] == str(target.assigned_to)


def test_swap_can_limit_automatic_target_to_named_member(context):
    actor = UUID(int=1)
    target_member = UUID(int=2)
    active = context.model_copy(update={"status": "ACTIVE"})
    tasks = baseline(active)
    active = active.model_copy(update={"tasks": tasks})

    result = find_swap(active, None, actor, target_member)

    assert result["accepted"] is True
    swap = result["swap_payload"]
    target = next(task for task in tasks if str(task.id) == swap["TargetOccurrenceId"])
    assert target.assigned_to == target_member
    assert result["target_member_id"] == str(target_member)


def test_swap_honors_exact_source_and_target_occurrences(context):
    actor, target_member = UUID(int=1), UUID(int=2)
    active = context.model_copy(update={"status": "ACTIVE"})
    tasks = baseline(active)
    active = active.model_copy(update={"tasks": tasks})
    source = next(task for task in tasks if task.assigned_to == actor)
    target = next(task for task in tasks if task.assigned_to == target_member)

    result = find_swap(active, source.id, actor, target_member, target.id)

    assert result["accepted"] is True
    assert result["swap_payload"]["SourceOccurrenceId"] == str(source.id)
    assert result["swap_payload"]["TargetOccurrenceId"] == str(target.id)


def test_swap_request_remains_feasible_when_declared_availability_does_not(context):
    actor, target_member = UUID(int=1), UUID(int=2)
    active = context.model_copy(update={"status": "ACTIVE"})
    tasks = baseline(active)
    active = active.model_copy(update={"tasks": tasks})
    source = next(task for task in tasks if task.assigned_to == actor)
    target = next(task for task in tasks if task.assigned_to == target_member)
    for member in active.members:
        if member.id in (actor, target_member):
            member.availability = []
            member.max_chores_per_week = 20
            member.max_minutes_per_day = 600

    result = find_swap(active, source.id, actor, target_member, target.id)

    assert result["accepted"] is True
    assert result["availability_overridden"] is True


def test_swap_does_not_replace_an_ineligible_named_target_with_another_chore(context):
    actor, target_member = UUID(int=1), UUID(int=2)
    active = context.model_copy(update={"status": "ACTIVE"})
    tasks = baseline(active)
    active = active.model_copy(update={"tasks": tasks})
    source = next(task for task in tasks if task.assigned_to == actor)
    other_member_task = next(task for task in tasks if task.assigned_to == UUID(int=3))

    result = find_swap(active, source.id, actor, target_member, other_member_task.id)

    assert result["accepted"] is False
    assert result["reason"] == "TARGET_NOT_ELIGIBLE"
    assert result["candidate_target_count"] == 0


def test_swap_input_does_not_require_manual_occurrence_selection(context):
    active = context.model_copy(update={"status": "ACTIVE"})

    request = SwapInput(context=active)

    assert request.source_occurrence_id is None
