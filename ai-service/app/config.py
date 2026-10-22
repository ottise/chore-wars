from pathlib import Path

from pydantic import SecretStr, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="AI_", extra="ignore")
    environment: str = "production"
    database_url: str = (
        "postgresql+psycopg://postgres:postgres@ai-postgres/chorewars_ai"
    )
    service_key: SecretStr = SecretStr("")
    kafka_servers: str = "kafka:9092"
    kafka_group: str = "chorewars-ai-v1"
    kafka_session_timeout_ms: int = 45000
    topic_prefix: str = ""
    artifacts: Path = Path("artifacts")
    gemini_api_key: SecretStr = SecretStr("")
    gemini_text_model: str = "gemini-3.5-flash-lite"
    gemini_vision_model: str = "gemini-3.8-flash"
    optimizer_move_budget: int = 10000
    optimizer_timeout_seconds: float = 4.0

    @model_validator(mode="after")
    def validate_security(self):
        if len(self.service_key.get_secret_value()) < 32:
            raise ValueError("AI_SERVICE_KEY must contain at least 32 characters")
        if self.environment != "test" and not self.database_url.startswith(
            "postgresql+psycopg://"
        ):
            raise ValueError("Production requires a dedicated PostgreSQL database")
        return self
