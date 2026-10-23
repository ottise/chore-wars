from datetime import datetime, timezone
from uuid import uuid4

import pytest

from app.config import Settings
from app.provider import GeminiClient
from app.schemas import LanguageInput


@pytest.mark.parametrize("text", ["I am busy tomorrow", "Tối mai tôi bận"])
async def test_english_response_keeps_original_evidence(text, monkeypatch):
    client = GeminiClient(Settings(environment="test", service_key="x" * 32))

    async def generate(model, instruction, parts, schema):
        assert "English or Vietnamese" in instruction
        assert "Respond with English" in instruction
        assert "evidence_quotes verbatim" in instruction
        return {
            "intent": "availability",
            "summary": "You are unavailable tomorrow. Confirm the time interval.",
            "evidence_quotes": [text],
            "missing_fields": ["start_minute", "end_minute"],
        }

    monkeypatch.setattr(client, "generate", generate)
    result = await client.interpret(
        LanguageInput(
            house_id=uuid4(), actor_id=uuid4(), text=text,
            now=datetime(2026, 10, 23, tzinfo=timezone.utc),
            consent_version="test-v1",
        )
    )
    assert result.evidence_quotes == [text]
    assert result.requires_confirmation is True
