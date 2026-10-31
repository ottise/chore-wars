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


def test_swap_input_does_not_require_manual_occurrence_selection(context):
    active = context.model_copy(update={"status": "ACTIVE"})

    request = SwapInput(context=active)

    assert request.source_occurrence_id is None
