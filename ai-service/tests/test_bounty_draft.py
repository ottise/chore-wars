from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest

from app.config import Settings
from app.provider import GeminiClient, ProviderUnavailable
from app.schemas import LanguageInput


def request():
    occurrence = uuid4()
    return LanguageInput(
        house_id=uuid4(), actor_id=uuid4(),
        text="Đăng bounty lau bếp giúp tôi, thưởng 20k",
        now=datetime(2026, 11, 1, 3, tzinfo=timezone.utc), consent_version="ON_DEMAND",
        bounty_chores={str(occurrence): {"name": "Lau bếp", "due_at": "2026-11-02T16:59:00Z"}},
    ), occurrence


async def interpret(monkeypatch, request, candidate):
    client = GeminiClient(Settings(environment="test", service_key="x" * 32))

    async def generate(*args):
        assert "bounty_create" in args[1]
        return {"intent": "bounty_create", "summary": "Review your kitchen bounty before posting.",
                "requires_confirmation": False, "bounty": candidate}

    monkeypatch.setattr(client, "generate", generate)
    return await client.interpret(request)


async def test_explicit_bounty_request_is_grounded_and_needs_no_second_confirmation(monkeypatch):
    r, occurrence = request()
    result = await interpret(monkeypatch, r, {"occurrence_id": str(occurrence), "amount": 20000})
    assert result.requires_confirmation is False
    assert result.bounty.occurrence_id == occurrence
    assert result.bounty.amount == 20000
    assert not result.missing_fields


@pytest.mark.parametrize("candidate,missing", [
    (None, {"bounty_chore", "bounty_amount_vnd"}),
    ({"amount": 20000}, {"bounty_chore"}),
    ({}, {"bounty_chore", "bounty_amount_vnd"}),
])
async def test_missing_information_is_requested(monkeypatch, candidate, missing):
    r, _ = request()
    result = await interpret(monkeypatch, r, candidate)
    assert missing <= set(result.missing_fields)


async def test_missing_reward_is_not_invented(monkeypatch):
    r, occurrence = request()
    result = await interpret(monkeypatch, r, {"occurrence_id": str(occurrence)})
    assert result.bounty.amount is None
    assert "bounty_amount_vnd" in result.missing_fields


@pytest.mark.parametrize("amount", [0, -20000, 1.5])
async def test_invalid_reward_is_rejected(monkeypatch, amount):
    r, occurrence = request()
    with pytest.raises(ProviderUnavailable):
        await interpret(monkeypatch, r, {"occurrence_id": str(occurrence), "amount": amount})


async def test_invented_or_ineligible_occurrence_is_rejected(monkeypatch):
    r, _ = request()
    with pytest.raises(ProviderUnavailable):
        await interpret(monkeypatch, r, {"occurrence_id": str(uuid4()), "amount": 20000})


async def test_ambiguous_recurring_chore_requires_date_then_accepts_clarification(monkeypatch):
    r, occurrence = request()
    r.bounty_chores[str(uuid4())] = r.bounty_chores[str(occurrence)].model_copy(
        update={"due_at": datetime(2026, 11, 3, 16, 59, tzinfo=timezone.utc)})
    result = await interpret(monkeypatch, r, {"occurrence_id": str(occurrence), "amount": 20000})
    assert "bounty_occurrence_date" in result.missing_fields
    result = await interpret(monkeypatch, r, {
        "occurrence_id": str(occurrence), "amount": 20000, "local_date": "2026-11-02"})
    assert not result.missing_fields


async def test_expired_chore_is_rejected(monkeypatch):
    r, occurrence = request()
    r.now += timedelta(days=3)
    with pytest.raises(ProviderUnavailable):
        await interpret(monkeypatch, r, {"occurrence_id": str(occurrence), "amount": 20000})
