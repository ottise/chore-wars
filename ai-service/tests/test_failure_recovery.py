from uuid import uuid4

import pytest
from app.config import Settings
from app.storage import failures
from app.worker import run_worker
from sqlalchemy import select


def test_quarantine_is_idempotent_for_same_broker_position(store):
    envelope = {"topic": "private", "partition": 0, "offset": 7, "raw_hex": "7b"}
    first = store.quarantine(envelope, "INVALID", None)
    assert store.quarantine(envelope, "INVALID", None) == first
    with store.engine.connect() as db:
        rows = list(db.execute(select(failures)).mappings())
    assert len(rows) == 1 and rows[0]["house_id"] is None
    with pytest.raises(LookupError):
        store.replay_failure(first, str(uuid4()))


def test_kafka_tombstone_is_quarantined_and_offset_can_advance(store, monkeypatch):
    class Message:
        def value(self):
            return None

        def error(self):
            return None

        def topic(self):
            return "test-only"

        def partition(self):
            return 0

        def offset(self):
            return 9

    class Consumer:
        def __init__(self):
            self.polled = False
            self.committed = 0
            self.closed = False

        def subscribe(self, topics):
            pass

        def poll(self, timeout):
            if self.polled:
                raise KeyboardInterrupt
            self.polled = True
            return Message()

        def commit(self, **kwargs):
            self.committed += 1

        def close(self):
            self.closed = True

    consumer = Consumer()
    monkeypatch.setattr("app.worker.Consumer", lambda config: consumer)
    monkeypatch.setattr("app.worker.EvaluationStore", lambda url: store)
    monkeypatch.setattr("app.worker.signal.signal", lambda *args: None)
    settings = Settings(
        environment="test",
        database_url=str(store.engine.url),
        service_key="test-only-key-at-least-32-characters",
    )
    with pytest.raises(KeyboardInterrupt):
        run_worker(settings)
    assert consumer.committed == 1 and consumer.closed
    with store.engine.connect() as db:
        row = db.execute(select(failures)).mappings().one()
    assert row["house_id"] is None and row["payload"]["raw_hex"] == ""
