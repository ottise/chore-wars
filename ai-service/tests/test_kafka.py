import os
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4

import pytest
from app.schemas import Event
from app.storage import failures
from confluent_kafka import Consumer, Producer, TopicPartition
from confluent_kafka.admin import AdminClient, NewTopic
from sqlalchemy import select


def worker(config: dict, stage: str | None, log):
    environment = {
        **os.environ,
        **config,
        "AI_ENVIRONMENT": "test",
        "AI_SERVICE_KEY": "test-key-for-worker-contract-only-32",
    }
    if stage:
        environment["AI_TEST_CRASH_STAGE"] = stage
    else:
        environment.pop("AI_TEST_CRASH_STAGE", None)
    return subprocess.Popen(
        [sys.executable, "-m", "app.worker"],
        env=environment,
        stdout=log,
        stderr=log,
        cwd=Path(__file__).resolve().parents[1],
    )


def test_worker_crash_after_database_and_after_offset_does_not_double_count(
    postgres_store, tmp_path
):
    broker = os.getenv("AI_TEST_KAFKA")
    if not broker:
        pytest.skip(
            "AI_TEST_KAFKA must point to a disposable or namespaced local broker"
        )
    if not broker.startswith(("127.0.0.1:", "localhost:")):
        raise ValueError("Runtime tests require a local broker")
    prefix = "cw-ai-test-" + uuid4().hex + "."
    topic = prefix + "ai.telemetry.v1"
    group = prefix + "group"
    admin = AdminClient({"bootstrap.servers": broker})
    admin.create_topics([NewTopic(topic, num_partitions=1, replication_factor=1)])[
        topic
    ].result(30)
    now = datetime.now(timezone.utc)
    house = uuid4()
    event = Event(
        event_id=uuid4(),
        house_id=house,
        entity_id=uuid4(),
        house_sequence=1,
        event_type="occurrence.upsert",
        recorded_at=now,
        occurred_at=now,
        payload={
            "status": "ASSIGNED",
            "due_at": now.isoformat(),
            "minutes": 15,
            "karma": 10,
            "assigned_to": str(uuid4()),
        },
    )
    producer = Producer({"bootstrap.servers": broker})
    producer.produce(topic, key=str(house), value=event.model_dump_json())
    assert producer.flush(15) == 0
    config = {
        "AI_DATABASE_URL": postgres_store.engine.url.render_as_string(
            hide_password=False
        ),
        "AI_KAFKA_SERVERS": broker,
        "AI_KAFKA_GROUP": group,
        "AI_TOPIC_PREFIX": prefix,
        "AI_KAFKA_SESSION_TIMEOUT_MS": "10000",
    }
    process = None
    try:
        with (tmp_path / "worker.log").open("w") as log:
            process = worker(config, "after_db", log)
            assert process.wait(45) == 91
            assert len(postgres_store.history(str(house))) == 1
            process = worker(config, "after_offset", log)
            assert process.wait(45) == 92
            assert len(postgres_store.history(str(house))) == 1
            observer = Consumer(
                {
                    "bootstrap.servers": broker,
                    "group.id": group,
                    "enable.auto.commit": False,
                }
            )
            try:
                assert (
                    observer.committed([TopicPartition(topic, 0)], timeout=15)[0].offset
                    == 1
                )
            finally:
                observer.close()
            producer.produce(topic, key=str(house), value=b"{broken-json")
            assert producer.flush(15) == 0
            process = worker(config, None, log)
            deadline = time.monotonic() + 45
            while time.monotonic() < deadline:
                with postgres_store.engine.connect() as db:
                    quarantined = list(db.execute(select(failures)).mappings())
                if quarantined:
                    break
                time.sleep(0.2)
            assert len(quarantined) == 1 and quarantined[0]["house_id"] is None
            assert len(postgres_store.history(str(house))) == 1
    finally:
        if process and process.poll() is None:
            process.terminate()
            try:
                process.wait(10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(10)
        admin.delete_topics([topic])[topic].result(30)
