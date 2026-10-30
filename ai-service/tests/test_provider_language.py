from datetime import datetime, timezone
from uuid import uuid4

import pytest

from app.config import Settings
from app.provider import GeminiClient, ProviderUnavailable, _generation_shape
from app.urgent import Decomposition
from app.schemas import LanguageInput


@pytest.mark.parametrize("intent", ["help", "create_chore"])
async def test_model_cannot_disable_required_application_confirmation(monkeypatch, intent):
    client = GeminiClient(Settings(environment="test", service_key="x" * 32))

    async def generate(*args, **kwargs):
        return {"intent": intent, "summary": "Review this response.", "requires_confirmation": False}

    monkeypatch.setattr(client, "generate", generate)
    result = await client.interpret(LanguageInput(house_id=uuid4(), actor_id=uuid4(),
        text="Help me plan chores", now=datetime.now(timezone.utc), consent_version="test-v1"))
    assert result.intent == intent
    assert result.requires_confirmation is True


async def test_enforcing_confirmation_does_not_accept_other_invalid_model_fields(monkeypatch):
    client = GeminiClient(Settings(environment="test", service_key="x" * 32))

    async def generate(*args, **kwargs):
        return {"intent": "unsupported-dangerous-action", "summary": "Invalid", "requires_confirmation": False}

    monkeypatch.setattr(client, "generate", generate)
    with pytest.raises(ProviderUnavailable, match="PROVIDER_SCHEMA_INVALID"):
        await client.interpret(LanguageInput(house_id=uuid4(), actor_id=uuid4(),
            text="Help", now=datetime.now(timezone.utc), consent_version="test-v1"))


def test_generation_shape_keeps_fields_and_enums_but_limits_are_still_validated():
    schema=_generation_shape(Decomposition.model_json_schema())
    assert "title" in schema["properties"]
    assert "maxItems" not in schema["properties"]["chores"]
    assert schema["$defs"]["MicroTask"]["properties"]["difficulty"]["enum"]==["EASY","MEDIUM","HARD"]
    with pytest.raises(ValueError):
        Decomposition(chores=[])


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


@pytest.mark.parametrize("unknown", [False, True])
async def test_urgent_uses_known_participants_and_asks_for_missing_budget(monkeypatch, unknown):
    actor, participant = uuid4(), uuid4()
    client = GeminiClient(Settings(environment="test", service_key="x" * 32))

    async def generate(*args):
        return {
            "intent": "urgent", "summary": "What is the time budget?",
            "urgent": {"participant_ids": [str(participant)], "deadline_minutes": None},
        }

    monkeypatch.setattr(client, "generate", generate)
    request = LanguageInput(house_id=uuid4(), actor_id=actor, text="B should clean the table",
        member_names={str(actor): "A", **({} if unknown else {str(participant): "B"})},
        now=datetime(2026, 10, 23, tzinfo=timezone.utc), consent_version="ON_DEMAND")
    if unknown:
        with pytest.raises(ProviderUnavailable, match="UNSUPPORTED_MEMBER_REFERENCE"):
            await client.interpret(request)
    else:
        result = await client.interpret(request)
        assert set(result.urgent.participant_ids) == {actor, participant}
        assert "deadline_minutes" in result.missing_fields


async def test_party_time_and_guests_are_separate_from_named_workers(monkeypatch):
    actor, trinh=uuid4(), uuid4()
    client=GeminiClient(Settings(environment="test", service_key="x"*32))
    async def generate(*args):
        return {"intent":"urgent", "summary":"Prepare a party for 10 guests by 10 PM with Trinh.",
                "urgent":{"ready_by":"2026-10-25T22:00:00+07:00","guest_count":10,"participant_ids":[str(actor),str(trinh)]}}
    monkeypatch.setattr(client,"generate",generate)
    result=await client.interpret(LanguageInput(house_id=uuid4(),actor_id=actor,
        text="10 giờ tối nay tiệc cho 10 người bạn, tôi và Trinh chuẩn bị",now=datetime(2026,10,25,9,tzinfo=timezone.utc),
        member_names={str(actor):"Me",str(trinh):"Trinh"},consent_version="ON_DEMAND"))
    assert result.urgent.guest_count==10
    assert set(result.urgent.participant_ids)=={actor,trinh}
    assert result.urgent.ready_by.hour==22
    assert "deadline_minutes" not in result.missing_fields


async def test_elapsed_tonight_does_not_silently_move_to_tomorrow(monkeypatch):
    actor, trinh=uuid4(),uuid4()
    client=GeminiClient(Settings(environment="test",service_key="x"*32))
    async def generate(*args):
        return {"intent":"urgent","summary":"Party plan","urgent":{"ready_by":"2026-10-25T22:00:00+07:00","participant_ids":[str(actor),str(trinh)]}}
    monkeypatch.setattr(client,"generate",generate)
    result=await client.interpret(LanguageInput(house_id=uuid4(),actor_id=actor,text="Tonight at 10 PM",
        now=datetime(2026,10,25,16,tzinfo=timezone.utc),member_names={str(actor):"Me",str(trinh):"Trinh"},consent_version="ON_DEMAND"))
    assert "future_ready_by_within_24_hours" in result.missing_fields
