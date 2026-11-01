from datetime import date, timedelta, timezone
from uuid import UUID

from pydantic import AwareDatetime, BaseModel, ConfigDict, Field


class BountyChore(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: str
    due_at: AwareDatetime


class BountyCandidate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    occurrence_id: UUID | None = None
    amount: int | None = Field(default=None, gt=0)
    local_date: date | None = None


def validate_bounty(request, result):
    if result.intent != "bounty_create":
        return result
    candidate = result.bounty
    if candidate is None or candidate.occurrence_id is None:
        result.missing_fields.append("bounty_chore")
    elif str(candidate.occurrence_id) not in request.bounty_chores:
        raise ValueError("Unsupported bounty chore")
    else:
        selected = request.bounty_chores[str(candidate.occurrence_id)]
        if selected.due_at <= request.now:
            raise ValueError("Bounty chore has expired")
        # Recurring chores can have identical names. Require the date/occurrence
        # to be clarified rather than silently choosing one occurrence.
        vietnam = timezone(timedelta(hours=7))
        if (
            candidate.local_date is not None
            and selected.due_at.astimezone(vietnam).date() != candidate.local_date
        ):
            raise ValueError("Bounty chore date does not match")
        matches = [
            item for item in request.bounty_chores.values()
            if item.name.strip().casefold() == selected.name.strip().casefold()
        ]
        if len(matches) > 1 and (
            candidate.local_date is None
            or sum(item.due_at.astimezone(vietnam).date() == candidate.local_date
                   for item in matches) != 1
        ):
            result.missing_fields.append("bounty_occurrence_date")
    if candidate is None or candidate.amount is None:
        result.missing_fields.append("bounty_amount_vnd")
    result.missing_fields = list(dict.fromkeys(result.missing_fields))
    return result
