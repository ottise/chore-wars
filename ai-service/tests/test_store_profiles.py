from datetime import datetime, timezone
from uuid import UUID, uuid4

import pytest
from app.behavior import profiles
from app.dataset import build_dataset
from app.evaluation import comparison, persist_comparison
from app.learning import snapshot_learning
from app.schemas import Event


def event(seq, entity, kind, payload):
    return Event(
        event_id=uuid4(),
        house_id=UUID(int=100),
        house_sequence=seq,
        event_type=kind + ".upsert",
        entity_id=entity,
        occurred_at=datetime(2026, 1, 1, tzinfo=timezone.utc),
        recorded_at=datetime(2026, 1, 1, tzinfo=timezone.utc),
        payload=payload,
    )


def test_ui_open_is_only_an_observation_not_a_training_label_or_completion(store):
    observed = event(
        1,
        uuid4(),
        "interaction",
        {
            "member_id": str(uuid4()),
            "action": "BOUNTY_OPENED",
            "occurrence_id": str(uuid4()),
        },
    )
    store.ingest(observed)
    history = store.history(str(observed.house_id))
    cutoff = datetime(2026, 1, 2, tzinfo=timezone.utc)
    assert build_dataset(history, cutoff)["rows"] == []
    assert profiles(history, cutoff)["items"] == []
    snapshot = snapshot_learning(store, str(observed.house_id), cutoff)
    assert snapshot["observed_interaction_count"] == 1
    assert snapshot["profile_evidence_count"] == 0


def test_duplicate_and_out_of_order_preserve_history(store):
    entity = uuid4()
    new = event(2, entity, "occurrence", {"status": "COMPLETED"})
    old = event(1, entity, "occurrence", {"status": "ASSIGNED"})
    assert store.ingest(new)
    assert not store.ingest(new)
    store.ingest(old)
    assert len(store.history(str(UUID(int=100)))) == 2
    assert store.house_facts(str(UUID(int=100)))[0]["payload"]["status"] == "COMPLETED"
    changed = new.model_copy(update={"payload": {"status": "SKIPPED"}})
    with pytest.raises(ValueError):
        store.ingest(changed)


def test_bounty_receiver_not_completer_no_double_count(store):
    occurrence = uuid4()
    for seq in (1, 2):
        store.ingest(
            event(
                seq,
                uuid4(),
                "episode",
                {
                    "member_id": "A",
                    "reason": "BOUNTY",
                    "occurrence_id": str(occurrence),
                    "started_at": "2026-01-01T00:00:00Z",
                },
            )
        )
    store.ingest(
        event(
            3,
            occurrence,
            "occurrence",
            {
                "completed_by": "B",
                "completed_at": "2026-01-02T00:00:00Z",
                "due_at": "2026-01-02T01:00:00Z",
                "minutes": 30,
                "karma": 20,
                "template_id": "T",
            },
        )
    )
    result = profiles(
        store.history(str(UUID(int=100))), datetime(2026, 1, 3, tzinfo=timezone.utc)
    )
    a, b = result["items"]
    assert a["bounty_claim_count"] == 2 and a["bounty_occurrence_count"] == 1
    assert a["bounty_other_completed"] == 1 and a["completed_count"] == 0
    assert b["completed_count"] == 1 and b["standard_minutes"] == 30


def test_evaluations_persist_replay_scope_and_attribution(store, context):
    result = persist_comparison(store, context, {}, "job-1", 42, "scenario", None, 10)
    replay = persist_comparison(store, context, {}, "job-1", 42, "scenario", None, 10)
    assert replay == result
    data = comparison(store, str(context.house_id), result["comparison_group_id"])
    assert data["status"] == "COMPARABLE"
    assert all(v["history"] == 0 for v in data["deltas"].values())
    assert store.get_run(str(uuid4()), result["runs"]["B0"]) is None
    assert len(store.list_runs(str(context.house_id))["items"]) == 3
