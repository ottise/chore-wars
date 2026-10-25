from datetime import datetime, timedelta, timezone
from uuid import UUID, uuid4

import pytest
from app.bounty import BountyInput, Offer, suggestions
from app.labels import label_episode
from app.ml import (
    candidates,
    classification_metrics,
    make_estimator,
    temporal_shortlist,
)
from app.registry import predict_observed, promote, trusted_artifact
from app.urgent import Decomposition, MicroTask, UrgentInput, plan_urgent


def urgent(context, minutes=60):
    return UrgentInput(
        context=context.model_copy(
            update={
                "status": "ACTIVE",
                "as_of": datetime(2026, 1, 2, 1, tzinfo=timezone.utc),
            }
        ),
        text="Dọn nhà",
        deadline_minutes=minutes,
        participant_ids=[m.id for m in context.members],
        resources=["sink"],
    )


def micro(key, depends=None, resources=None):
    return MicroTask(
        key=key,
        name=key,
        description="",
        difficulty="EASY",
        dependencies=depends or [],
        resources=resources or [],
    )


def test_urgent_dependency_and_resource_timeline(context):
    request = urgent(context)
    result = plan_urgent(
        request,
        Decomposition(
            chores=[
                micro("a", resources=["sink"]),
                micro("b", resources=["sink"]),
                micro("c", ["a", "b"]),
            ]
        ),
    )
    assert result["status"] == "READY"
    a, b, c = result["tasks"]
    assert a["end_at"] <= b["start_at"] and b["end_at"] <= c["start_at"]
    assert result["urgent_payload"]["PlanVersion"] == "blitz-v1"
    assert all(t["KarmaPoints"] == 0 for t in result["urgent_payload"]["Chores"])
    assert all(t.assigned_to is None for t in context.tasks)


def test_urgent_preserves_explicit_assignee_and_rejects_outsider(context):
    request = urgent(context)
    member = request.participant_ids[-1]
    chore = micro("named-task").model_copy(update={"assigned_to": member})
    result = plan_urgent(request, Decomposition(chores=[chore]))
    assert result["status"] == "READY"
    assert result["tasks"][0]["assigned_to"] == str(member)
    chore.assigned_to = uuid4()
    with pytest.raises(ValueError, match="Explicit assignees"):
        plan_urgent(request, Decomposition(chores=[chore]))


def test_party_ready_by_stays_absolute_and_guests_are_not_assignees(context):
    request=urgent(context)
    ready_by=request.context.as_of.replace(hour=3).astimezone(timezone(timedelta(hours=7)))
    request=request.model_copy(update={"ready_by":ready_by,"guest_count":10,"deadline_minutes":120})
    result=plan_urgent(request,Decomposition(title="Party preparation",chores=[micro("table")]))
    assert result["status"]=="READY"
    assert result["deadline_at"]==ready_by
    assert result["urgent_payload"]["ReadyByUtc"].endswith("Z")
    assert datetime.fromisoformat(result["urgent_payload"]["ReadyByUtc"])==ready_by
    assert result["guest_count"]==10
    assert all(t["end_at"]<=ready_by for t in result["tasks"])
    assert len(request.participant_ids)==3


def test_urgent_does_not_reassign_unavailable_named_member(context):
    request = urgent(context)
    member = request.context.members[-1]
    member.availability = []
    chore = micro("named-task").model_copy(update={"assigned_to": member.id})
    result = plan_urgent(request, Decomposition(chores=[chore]))
    assert result["status"] == "INFEASIBLE"


def test_urgent_cycle_and_budget_are_explained(context):
    request = urgent(context, 10)
    cycle = plan_urgent(
        request, Decomposition(chores=[micro("a", ["b"]), micro("b", ["a"])])
    )
    assert cycle["status"] == "INFEASIBLE" and "CYCLE" in cycle["reason"]
    short = plan_urgent(request, Decomposition(chores=[micro("a")]))
    assert short["status"] == "INFEASIBLE" and short["unplaced"] == ["a"]
    with pytest.raises(ValueError):
        plan_urgent(
            request, Decomposition(chores=[micro("a", resources=["invented machine"])])
        )


def test_bounty_suggestions_are_voluntary_not_acceptance_prediction(context):
    context = context.model_copy(
        update={
            "status": "ACTIVE",
            "as_of": datetime(2026, 1, 2, 1, tzinfo=timezone.utc),
        }
    )
    context.tasks[0].assigned_to = context.members[1].id
    offer = Offer(
        id=uuid4(),
        occurrence_id=context.tasks[0].id,
        amount=20000,
        expires_at=context.tasks[0].due_at,
    )
    result = suggestions(
        BountyInput(context=context, offers=[offer]), context.members[0].id, []
    )
    assert (
        len(result["items"]) == 1
        and result["acceptance_probability"] is None
        and not result["push_notifications"]
    )
    assert context.tasks[0].assigned_to == context.members[1].id


def test_future_outcomes_cannot_be_labels():
    e = {
        "snapshot_id": "s",
        "member_id": "A",
        "reason": "INITIAL",
        "started_at": "2026-01-01T00:00:00Z",
        "deadline": "2026-01-03T00:00:00Z",
        "ended_at": "2026-01-02T00:00:00Z",
        "completed_by": "A",
    }
    o = {"due_at": e["deadline"], "completed_by": "A", "completed_at": e["ended_at"]}
    result = label_episode(
        e,
        o,
        [{"actor_id": "A", "requested_at": "2026-01-02T00:00:00Z"}],
        datetime(2026, 1, 1, 12, tzinfo=timezone.utc),
        True,
    )
    assert result["T1"] is None and result["T2"] is None


def test_all_fourteen_candidates_fit_without_fake_accuracy():
    assert len(candidates()) == 14
    x = [
        {"minutes": 15 + i % 3, "difficulty": "EASY" if i % 2 else "HARD"}
        for i in range(60)
    ]
    y = [i % 2 for i in range(60)]
    for family, config in candidates():
        prediction = make_estimator(family, config).fit(x, y).predict_proba(x)[:, 1]
        m = classification_metrics(y, prediction, 0.5)
        assert 0 <= m["brier"] <= 1 and m["sample_count"] == 60
    misleading = classification_metrics([0] * 95 + [1] * 5, [0.01] * 100, 0.5)
    assert misleading["recall"] == 0 and misleading["precision"] is None


def test_temporal_shortlist_has_two_forward_folds_per_configuration():
    rows = [
        {"month": m, "features": {"minutes": 15 + (i % 2) * 30}, "T1": i % 2}
        for m in (1, 2, 3)
        for i in range(30)
    ]
    selected, reports = temporal_shortlist(rows, "T1", lambda r: r["month"])
    assert len(selected) == 5 and len(reports) == 14
    assert all(
        [(f["fit_through_month"], f["validation_month"]) for f in r["forward_folds"]]
        == [(1, 2), (2, 3)]
        for r in reports
    )


def test_registry_does_not_promote_or_invent_probability(store, tmp_path):
    result = predict_observed(
        store, str(UUID(int=100)), {"minutes": 15}, "REAL", tmp_path
    )
    assert result["status"] == "NO_APPROVED_MODEL" and result["p_late"] is None
    with pytest.raises(LookupError):
        promote(store, "house", "missing", "missing", tmp_path)
    with pytest.raises((ValueError, OSError)):
        trusted_artifact(tmp_path, "../escape.joblib", "not-a-hash")
