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
    # A task that cannot be matched is a clarification, not a provider outage.
    # Clearing its ID prevents the app from posting an unintended bounty.
    def clarify(field, message):
        if candidate is not None:
            candidate.occurrence_id = None
        result.missing_fields.append(field)
        result.summary = message

    if candidate is None or candidate.occurrence_id is None:
        result.missing_fields.append("bounty_chore")
    elif str(candidate.occurrence_id) not in request.bounty_chores:
        clarify("bounty_chore", "I couldn't match that request to one of your eligible chores. Please specify your chore and its date.")
    else:
        selected = request.bounty_chores[str(candidate.occurrence_id)]
        if selected.due_at <= request.now:
            clarify("bounty_chore", "This chore's deadline has passed. Please choose an unfinished chore whose deadline is still in the future.")
        # Recurring chores can have identical names. Require the date/occurrence
        # to be clarified rather than silently choosing one occurrence.
        vietnam = timezone(timedelta(hours=7))
        if (
            candidate.local_date is not None
            and selected.due_at.astimezone(vietnam).date() != candidate.local_date
        ):
            clarify("bounty_occurrence_date", "I couldn't match the selected chore to your requested date. Please specify the chore and its date again.")
        matches = [
            item for item in request.bounty_chores.values()
            if item.name.strip().casefold() == selected.name.strip().casefold()
        ]
        if len(matches) > 1 and (
            candidate.local_date is None
            or sum(item.due_at.astimezone(vietnam).date() == candidate.local_date
                   for item in matches) != 1
        ):
            clarify("bounty_occurrence_date", "You have more than one eligible chore with that name. Which date is the bounty for?")
    if candidate is None or candidate.amount is None:
        result.missing_fields.append("bounty_amount_vnd")
    result.missing_fields = list(dict.fromkeys(result.missing_fields))
    return result
