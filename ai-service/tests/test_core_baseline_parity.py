import json
import os
from pathlib import Path

import pytest
from app.allocation import baseline
from app.schemas import Context


def test_exported_core_baseline_matches_python():
    manifest_path = os.getenv("AI_CORE_DEMO_MANIFEST")
    if not manifest_path:
        pytest.skip(
            "Set AI_CORE_DEMO_MANIFEST to an actual AIDemo business-service export"
        )
    path = Path(manifest_path)
    manifest = json.loads(path.read_text(encoding="utf-8-sig"))
    assert manifest["data_source"] == "DEMO_SYNTHETIC"
    for index, name in enumerate(manifest["contexts"], 1):
        context = Context.model_validate_json(
            (path.parent / name).read_text(encoding="utf-8-sig")
        )
        expected = Context.model_validate_json(
            (path.parent / f"baseline-{index:02}.json").read_text(encoding="utf-8-sig")
        )
        actual = baseline(context)
        assert {str(t.id): (t.assigned_to, t.start_at) for t in actual} == {
            str(t.id): (t.assigned_to, t.start_at) for t in expected.tasks
        }
