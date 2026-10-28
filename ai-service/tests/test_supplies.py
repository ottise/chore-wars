from datetime import datetime, timezone
from uuid import uuid4

import pytest

from app.config import Settings
from app.provider import GeminiClient, ProviderUnavailable
from app.schemas import LanguageInput


def request():
    actor, other, supplier, product = uuid4(), uuid4(), uuid4(), uuid4()
    return LanguageInput(
        house_id=uuid4(), actor_id=actor, text="Tôi trả trước, mua gạo cho tôi và Trinh",
        now=datetime.now(timezone.utc), consent_version="ON_DEMAND",
        member_names={str(actor): "A", str(other): "Trinh"},
        supply_catalog={str(product): {"supplier_id": supplier, "name": "Rice", "unit": "10 kg bag", "price": 240000, "available_quantity": 2}},
    ), other, supplier, product


async def test_purchase_is_grounded_and_still_requires_confirmation(monkeypatch):
    r, other, supplier, product = request()
    client = GeminiClient(Settings(environment="test", service_key="x" * 32))

    async def generate(*args):
        return {"intent": "supply_purchase", "summary": "Review one bag of rice and your cost shares.",
                "supply": {"supplier_id": str(supplier), "payer_id": str(r.actor_id), "participant_ids": [str(r.actor_id), str(other)], "lines": [{"product_id": str(product), "quantity": 1}]}}

    monkeypatch.setattr(client, "generate", generate)
    result = await client.interpret(r)
    assert result.intent == "supply_purchase"
    assert result.requires_confirmation is True
    assert result.missing_fields == []
    assert result.supply.lines[0].product_id == product


@pytest.mark.parametrize("invalid", ["product", "payer", "participant", "supplier"])
async def test_invented_purchase_references_are_rejected(monkeypatch, invalid):
    r, other, supplier, product = request()
    client = GeminiClient(Settings(environment="test", service_key="x" * 32))

    async def generate(*args):
        return {"intent": "supply_purchase", "summary": "Review purchase", "supply": {
            "supplier_id": str(uuid4() if invalid == "supplier" else supplier),
            "payer_id": str(uuid4() if invalid == "payer" else r.actor_id),
            "participant_ids": [str(r.actor_id), str(uuid4() if invalid == "participant" else other)],
            "lines": [{"product_id": str(uuid4() if invalid == "product" else product), "quantity": 1}],
        }}

    monkeypatch.setattr(client, "generate", generate)
    with pytest.raises(ProviderUnavailable):
        await client.interpret(r)


async def test_monthly_check_does_not_require_a_payer_or_catalog(monkeypatch):
    r, _, _, _ = request()
    r.supply_catalog = {}
    client = GeminiClient(Settings(environment="test", service_key="x" * 32))

    async def generate(*args):
        return {"intent": "supply_reminder", "summary": "Review a monthly rice and water check.", "supply": {
            "reminder": {"items": "Rice and water", "day_of_month": 5, "hour": 19, "minute": 0}}}

    monkeypatch.setattr(client, "generate", generate)
    result = await client.interpret(r)
    assert not result.missing_fields
    assert result.supply.payer_id is None


async def test_missing_payment_and_sharing_details_are_not_guessed(monkeypatch):
    r, _, supplier, product = request()
    client = GeminiClient(Settings(environment="test", service_key="x" * 32))

    async def generate(*args):
        return {"intent": "supply_purchase", "summary": "Choose the quantities and send the order.", "supply": {
            "supplier_id": str(supplier), "lines": [{"product_id": str(product), "quantity": 1}]}}

    monkeypatch.setattr(client, "generate", generate)
    result = await client.interpret(r)
    assert result.missing_fields == []
    assert result.requires_confirmation is True
