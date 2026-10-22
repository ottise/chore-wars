from uuid import uuid4

from app.schemas import Event
from sqlalchemy import inspect, text


def test_postgres_migration_and_retry_are_real(postgres_store):
    from datetime import datetime, timezone

    identity, house, entity = uuid4(), uuid4(), uuid4()
    event = Event(
        event_id=identity,
        house_id=house,
        house_sequence=1,
        event_type="occurrence.upsert",
        entity_id=entity,
        occurred_at=datetime.now(timezone.utc),
        recorded_at=datetime.now(timezone.utc),
        payload={"status": "ASSIGNED"},
    )
    assert postgres_store.ingest(event) and not postgres_store.ingest(event)
    assert len(postgres_store.history(str(house))) == 1
    with postgres_store.engine.connect() as db:
        assert (
            db.execute(text("select count(*) from alembic_version")).scalar_one() == 1
        )
    assert inspect(postgres_store.engine).get_foreign_keys("evaluation_metrics")
