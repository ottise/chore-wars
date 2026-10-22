def stream_status(history: list[dict], expected_sequence: int | None = None) -> dict:
    sequences = {e["house_sequence"] for e in history}
    maximum = max(sequences, default=0)
    expected = max(
        [maximum, expected_sequence or 0]
        + [e.get("batch_last_sequence") or e["house_sequence"] for e in history]
    )
    return {
        "telemetry_complete": len(sequences) == maximum and maximum >= expected,
        "observed_sequence": maximum,
        "expected_sequence": expected,
        "missing_sequence_count": expected - len(sequences),
    }
