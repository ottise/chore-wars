from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field


class SupplyCatalogItem(BaseModel):
    model_config = ConfigDict(extra="forbid")
    supplier_id: UUID
    name: str = Field(max_length=150)
    unit: str = Field(max_length=40)
    price: int = Field(gt=0)
    available_quantity: int = Field(ge=0)


class SupplyLineCandidate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    product_id: UUID
    quantity: int = Field(ge=1, le=1000)


class SupplyReminderCandidate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    items: str = Field(min_length=1, max_length=500)
    day_of_month: int | None = Field(default=None, ge=1, le=31)
    hour: int | None = Field(default=None, ge=0, le=23)
    minute: int | None = Field(default=None, ge=0, le=59)


class SupplyCandidate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    supplier_id: UUID | None = None
    lines: list[SupplyLineCandidate] = Field(default_factory=list, max_length=30)
    payer_id: UUID | None = None
    participant_ids: list[UUID] = Field(default_factory=list, max_length=100)
    reminder: SupplyReminderCandidate | None = None


def validate_supplies(request, result):
    """Ground suggestions in the supplied catalog; Core still authorizes every mutation."""
    if result.intent not in ("supply_purchase", "supply_reminder"):
        return result
    candidate = result.supply
    if candidate is None:
        result.missing_fields.append("purchase_or_reminder_details")
        return result
    ids = [str(user) for user in candidate.participant_ids]
    if len(ids) != len(set(ids)) or any(user not in request.member_names for user in ids):
        raise ValueError("Unsupported purchase participant")
    if candidate.payer_id is not None and str(candidate.payer_id) not in request.member_names:
        raise ValueError("Unsupported purchase payer")
    selected = set(ids) | ({str(candidate.payer_id)} if candidate.payer_id else set())
    for user in selected - {str(request.actor_id)}:
        name = request.member_names[user].strip().casefold()
        if sum(value.strip().casefold() == name for value in request.member_names.values()) > 1 and user not in request.text:
            result.missing_fields.append("ambiguous_participant_name")
            result.summary = "Please choose which household member you mean; more than one member has that name."
    if result.intent == "supply_purchase":
        if not candidate.lines:
            result.missing_fields.append("available_catalog_products_and_quantities")
        if candidate.payer_id is None:
            result.missing_fields.append("payer")
        if not candidate.participant_ids:
            result.missing_fields.append("cost_sharing_participants")
        if candidate.payer_id is not None and candidate.payer_id not in candidate.participant_ids:
            result.missing_fields.append("payer_approval_and_participation")
        if len({line.product_id for line in candidate.lines}) != len(candidate.lines):
            raise ValueError("Duplicate catalog product")
        for line in candidate.lines:
            item = request.supply_catalog.get(str(line.product_id))
            if item is None:
                raise ValueError("Unsupported catalog product")
            if candidate.supplier_id != item.supplier_id:
                raise ValueError("Supplier mismatch")
            if line.quantity > item.available_quantity:
                result.missing_fields.append("available_stock")
    if result.intent == "supply_reminder" or candidate.reminder is not None:
        r = candidate.reminder
        if r is None or r.day_of_month is None or r.hour is None or r.minute is None:
            result.missing_fields.append("monthly_reminder_day_and_time")
    result.missing_fields = list(dict.fromkeys(result.missing_fields))
    return result
