from datetime import datetime, timezone
from uuid import uuid4

from app.config import Settings
from app.ml import select_threshold
from app.schemas import Event
from app.storage import training, training_jobs
from app.stream import stream_status
from app.trainer import process_one
from sqlalchemy import select


def test_incomplete_capture_cannot_be_treated_as_complete_or_start_training(
    store, tmp_path
):
    house = uuid4()
    batch = uuid4()
    now = datetime.now(timezone.utc)
    event = Event(
        event_id=uuid4(),
        house_id=house,
        entity_id=uuid4(),
        house_sequence=1,
        capture_batch_id=batch,
        batch_last_sequence=2,
        occurred_at=now,
        recorded_at=now,
        event_type="season.upsert",
        payload={"status": "COMPLETED"},
    )
    store.ingest(event)
    config = Settings(
        environment="test",
        database_url=str(store.engine.url),
        service_key="x" * 32,
        artifacts=tmp_path,
    )
    assert not stream_status(store.history(str(house)))["telemetry_complete"]
    assert not process_one(store, config)
    with store.engine.connect() as db:
        assert list(db.execute(select(training_jobs.c.attempts)).scalars()) == [0, 0]
    tail = event.model_copy(
        update={
            "event_id": uuid4(),
            "entity_id": uuid4(),
            "house_sequence": 2,
            "event_type": "ranking.upsert",
            "payload": {},
        }
    )
    store.ingest(tail)
    assert stream_status(store.history(str(house)))["telemetry_complete"]
    assert process_one(store, config)
    with store.engine.connect() as db:
        row = db.execute(select(training)).mappings().one()
        assert row["status"] == "INSUFFICIENT_DATA"
        assert not row["payload"].get("quality_passed")


def test_threshold_cannot_be_selected_from_a_single_class():
    assert select_threshold([1, 1], [0.8, 0.9]) is None
    assert select_threshold([0, 0], [0.1, 0.2]) is None


def test_core_high_watermark_detects_unreceived_tail():
    assert not stream_status([], 5)["telemetry_complete"]
    assert stream_status([], 0)["telemetry_complete"]
