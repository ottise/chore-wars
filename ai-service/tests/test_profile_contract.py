import json
from datetime import datetime, timezone
from pathlib import Path
from uuid import UUID, uuid4

from app.behavior import profiles
from app.config import Settings
from app.main import create_app
from app.profile_metrics import METRIC_DEFINITIONS, METRIC_VERSION
from app.schemas import Event
from fastapi.testclient import TestClient

HOUSE = UUID(int=100)
MEMBER = str(UUID(int=1))


def test_published_metric_dictionary_matches_executed_definitions():
    contract = json.loads(
        (
            Path(__file__).resolve().parents[1] / "contracts/profile-metrics.v1.json"
        ).read_text(encoding="utf-8")
    )
    assert contract["definition_version"] == METRIC_VERSION
    assert contract["metrics"] == {
        key: {"lineage_group": source, "denominator_field": denominator, "unit": unit}
        for key, (source, denominator, unit) in METRIC_DEFINITIONS.items()
    }


def fact(seq, kind, payload, entity=None):
    return Event(
        event_id=uuid4(),
        house_id=HOUSE,
        house_sequence=seq,
        event_type=kind + ".upsert",
        entity_id=entity or uuid4(),
        occurred_at=datetime(2026, 1, 1, tzinfo=timezone.utc),
        recorded_at=datetime(2026, 1, 1, tzinfo=timezone.utc),
        payload=payload,
    )


def preference(seq, kind, day, entity=None):
    return fact(
        seq,
        "preference",
        {
            "member_id": MEMBER,
            "template_id": "work-type",
            "chore_name": "Rửa bát",
            "type": kind,
            "effective_at": f"2026-01-{day:02}T00:00:00Z",
            "deleted": False,
        },
        entity,
    )


def test_profile_version_changes_when_earlier_preference_transitions_change():
    initial = preference(1, "PREFERRED", 1)
    middle = preference(2, "DISLIKED", 2, initial.entity_id)
    final = preference(3, "PREFERRED", 3, initial.entity_id)
    cutoff = datetime(2026, 1, 4, tzinfo=timezone.utc)
    short = profiles([e.model_dump(mode="json") for e in (initial, final)], cutoff)
    full = profiles(
        [e.model_dump(mode="json") for e in (initial, middle, final)], cutoff
    )
    assert short["items"][0]["preference_profile"][0]["sample_count"] == 1
    assert full["items"][0]["preference_profile"][0]["sample_count"] == 3
    assert short["profile_version"] != full["profile_version"]


def test_each_metric_has_own_lineage_and_sample_count_is_not_minutes(store):
    completed = []
    for seq in (1, 2):
        value = fact(
            seq,
            "occurrence",
            {
                "completed_by": MEMBER,
                "completed_at": "2026-01-01T01:00:00Z",
                "due_at": "2026-01-01T02:00:00Z",
                "minutes": 30,
                "karma": 20,
                "template_id": "T",
            },
        )
        completed.append(str(value.event_id))
        store.ingest(value)
    store.ingest(
        fact(
            3,
            "ledger",
            {
                "member_id": MEMBER,
                "created_at": "2026-01-01T01:00:00Z",
                "amount": -5,
                "type": "PENALTY",
            },
        )
    )
    data = profiles(
        store.history(str(HOUSE)), datetime(2026, 1, 2, tzinfo=timezone.utc)
    )
    row = data["items"][0]
    metric = row["metrics"]["standard_minutes"]
    assert metric["value"] == 60
    assert metric["sample_count"] == 2
    assert metric["evidence_ids"] == completed
    assert metric["profile_version"] == data["profile_version"]
    assert row["metrics"]["on_time_episode_rate"]["value"] is None
    assert row["metrics"]["on_time_episode_rate"]["denominator"] == 0
    assert row["metrics"]["on_time_episode_rate"]["status"] == "INSUFFICIENT_DATA"


def test_replacing_same_declaration_does_not_inflate_history_and_clear_is_not_dislike(
    store,
):
    initial = preference(1, "PREFERRED", 1)
    deleted = preference(2, "PREFERRED", 2, initial.entity_id)
    deleted.payload["deleted"] = True
    repeat = preference(3, "PREFERRED", 2)
    dislike = preference(4, "DISLIKED", 3, repeat.entity_id)
    cleared = preference(5, "DISLIKED", 4, repeat.entity_id)
    cleared.payload["deleted"] = True
    # A stale delete of a different row cannot erase the newer declaration.
    for value in (cleared, dislike, repeat, deleted, initial):
        store.ingest(value)
    data = profiles(
        store.history(str(HOUSE)), datetime(2026, 1, 4, tzinfo=timezone.utc)
    )
    row = data["items"][0]["preference_profile"][0]
    assert row["current_status"] == "CLEARED" and row["current_declared"] is None
    assert (row["positive_count"], row["negative_count"], row["sample_count"]) == (
        1,
        1,
        2,
    )
    assert row["smoothed_positive_score"] == 0.5
    assert row["uncertainty_status"] == "NOT_COMPUTED"
    assert set(row["evidence_ids"]) == {
        str(e.event_id) for e in (initial, dislike, cleared)
    }


def test_future_effective_and_obsolete_row_delete_do_not_override_current_preference(
    store,
):
    initial = preference(1, "PREFERRED", 1)
    current = preference(2, "DISLIKED", 2)
    obsolete = preference(3, "PREFERRED", 3, initial.entity_id)
    obsolete.payload["deleted"] = True
    future = preference(4, "PREFERRED", 5, current.entity_id)
    for value in (initial, current, obsolete, future):
        store.ingest(value)
    row = profiles(
        store.history(str(HOUSE)), datetime(2026, 1, 4, tzinfo=timezone.utc)
    )["items"][0]
    assert row["preference_profile"][0]["current_declared"] == "DISLIKED"
    assert row["preference_profile"][0]["sample_count"] == 2


def test_window_keeps_old_current_declaration_without_inventing_recent_samples(store):
    store.ingest(preference(1, "PREFERRED", 1))
    history = store.history(str(HOUSE))
    data = profiles(history, datetime(2026, 4, 1, tzinfo=timezone.utc), "30d")
    row = data["items"][0]["preference_profile"][0]
    assert row["current_declared"] == "PREFERRED"
    assert row["sample_count"] == 0 and row["smoothed_positive_score"] is None
    seasonal = profiles(
        history, datetime(2026, 4, 1, tzinfo=timezone.utc), "season", str(uuid4())
    )
    assert (
        seasonal["items"][0]["preference_profile"][0]["history_scope"]
        == "HOUSE_DECLARATIONS_NOT_SEASON_SCOPED"
    )


def test_preference_history_and_evidence_are_only_available_to_its_member(store):
    declaration = preference(1, "PREFERRED", 1)
    store.ingest(declaration)
    app = create_app(
        Settings(
            environment="test", service_key="x" * 32, database_url=str(store.engine.url)
        )
    )
    headers = {"X-AI-Key": "x" * 32, "X-House-Id": str(HOUSE), "X-Actor-Id": MEMBER}
    with TestClient(app) as client:
        path = f"/v1/houses/{HOUSE}"
        own = client.get(path + "/profiles", headers=headers)
        assert own.status_code == 200 and own.json()["items"][0]["preference_profile"]
        assert (
            client.get(
                path + f"/evidence/{declaration.event_id}", headers=headers
            ).status_code
            == 200
        )
        headers["X-Actor-Id"] = str(uuid4())
        other = client.get(path + "/profiles", headers=headers)
        assert "preference_profile" not in other.json()["items"][0]
        assert (
            client.get(
                path + f"/evidence/{declaration.event_id}", headers=headers
            ).status_code
            == 404
        )
        headers["X-Actor-Id"] = MEMBER
        headers["X-Core-Sequence"] = "2"
        provisional = client.get(path + "/profiles", headers=headers).json()["items"][0]
        assert provisional["metrics"]["completed_count"]["status"] == "PROVISIONAL"
