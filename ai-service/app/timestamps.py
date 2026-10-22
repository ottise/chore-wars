from datetime import datetime, timezone


def parse_time(value):
    if value is None:
        return None
    value = datetime.fromisoformat(value) if isinstance(value, str) else value
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value
