import json
import logging
import os
import signal
import time

from confluent_kafka import Consumer
from pydantic import ValidationError

from app.config import Settings
from app.schemas import Event
from app.storage import EvaluationStore

logger = logging.getLogger("chorewars.ai.worker")


def run_worker(settings: Settings | None = None):
    config = settings or Settings()
    store = EvaluationStore(config.database_url)
    consumer = Consumer(
        {
            "bootstrap.servers": config.kafka_servers,
            "group.id": config.kafka_group,
            "session.timeout.ms": config.kafka_session_timeout_ms,
            "enable.auto.commit": False,
            "enable.auto.offset.store": False,
            "auto.offset.reset": "earliest",
        }
    )
    consumer.subscribe([config.topic_prefix + "ai.telemetry.v1"])
    stopped = False

    def stop(*_):
        nonlocal stopped
        stopped = True

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
        while not stopped:
            message = consumer.poll(1)
            if message is None:
                continue
            if message.error():
                logger.error("Kafka poll error: %s", message.error().code())
                continue
            verified_house = None
            try:
                if message.value() is None:
                    raise ValueError("NULL_ENVELOPE")
                raw = json.loads(message.value())
                event = Event.model_validate(raw)
                if message.key() is None or message.key().decode() != str(
                    event.house_id
                ):
                    raise ValueError("UNVERIFIED_PARTITION_SCOPE")
                verified_house = str(event.house_id)
                store.ingest(event)
                if (
                    config.environment == "test"
                    and os.getenv("AI_TEST_CRASH_STAGE") == "after_db"
                ):
                    os._exit(91)
                consumer.commit(message=message, asynchronous=False)
                if (
                    config.environment == "test"
                    and os.getenv("AI_TEST_CRASH_STAGE") == "after_offset"
                ):
                    os._exit(92)
            except (ValidationError, ValueError, UnicodeError) as error:
                # Invalid payload cannot establish house ownership. Only operations can inspect/replay it.
                store.quarantine(
                    {
                        "topic": message.topic(),
                        "partition": message.partition(),
                        "offset": message.offset(),
                        "raw_hex": (message.value() or b"").hex(),
                    },
                    type(error).__name__,
                    verified_house,
                )
                consumer.commit(message=message, asynchronous=False)
            except Exception:
                logger.exception("Event transaction failed; offset retained")
                consumer.seek(
                    __import__("confluent_kafka").TopicPartition(
                        message.topic(), message.partition(), message.offset()
                    )
                )
                time.sleep(1)
    finally:
        consumer.close()


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    run_worker()
