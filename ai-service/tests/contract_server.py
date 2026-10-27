"""Local-only contract fixture. Replaces the paid provider boundary, not core planning/storage."""
import json
import os
from datetime import timedelta

from app.config import Settings
from app.main import create_app
from app.provider import GeminiClient
from app.schemas import LanguageInput
from app.storage import metadata
from app.urgent import UrgentInput


async def recorded_generation(self, model, instruction, parts, schema):
    request = json.loads(parts[0]["text"])
    if "context" in request:
        urgent = UrgentInput.model_validate(request)
        return {"title": "Party preparation", "chores": [
            {"key": f"task-{i}", "name": f"Prepare party area {i + 1}", "description": "Prepare the shared space", "difficulty": "EASY", "assigned_to": str(member)}
            for i, member in enumerate(urgent.participant_ids)]}
    language = LanguageInput.model_validate(request)
    if "Trinh" in language.text:
        trinh = next(identity for identity, name in language.member_names.items() if name == "Trinh")
        ready = language.now.replace(hour=15, minute=0, second=0, microsecond=0)
        return {"intent": "urgent", "summary": "Prepare the party before 22:00 with Trinh.",
                "urgent": {"ready_by": ready.isoformat(), "guest_count": 10, "participant_ids": [str(language.actor_id), trinh]},
                "evidence_quotes": ["Trinh"]}
    return {"intent": "availability", "summary": "Review your busy time tomorrow.",
            "availability": {"kind": "BUSY", "local_date": (language.now + timedelta(days=1)).date().isoformat(), "start_minute": 1080, "end_minute": 1200}}


def app():
    if os.getenv("AI_ENVIRONMENT") != "test":
        raise RuntimeError("Contract fixture requires explicit test environment")
    config = Settings()
    if not config.database_url.startswith("sqlite:///"):
        raise RuntimeError("Contract fixture only supports a disposable SQLite file")
    GeminiClient.generate = recorded_generation
    api = create_app(config)
    metadata.create_all(api.state.store.engine)
    return api
