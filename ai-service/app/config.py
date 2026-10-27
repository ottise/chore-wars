from pathlib import Path
from typing import Literal

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
    kafka_security_protocol: Literal["PLAINTEXT", "SSL", "SASL_SSL"] = "PLAINTEXT"
    kafka_sasl_mechanism: Literal["PLAIN", "SCRAM-SHA-256", "SCRAM-SHA-512"] = "PLAIN"
    kafka_sasl_username: str = ""
    kafka_sasl_password: SecretStr = SecretStr("")
    kafka_ssl_ca_location: str = ""
    kafka_ssl_ca_pem: str = ""
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
        if self.kafka_security_protocol == "SASL_SSL" and (
            not self.kafka_sasl_username.strip()
            or not self.kafka_sasl_password.get_secret_value().strip()
        ):
            raise ValueError("Kafka SASL requires AI_KAFKA_SASL_USERNAME and AI_KAFKA_SASL_PASSWORD")
        if self.environment != "test" and not self.database_url.startswith(
            "postgresql+psycopg://"
        ):
            raise ValueError("Production requires a dedicated PostgreSQL database")
        return self

    def kafka_client_config(self) -> dict[str, object]:
        result: dict[str, object] = {
            "bootstrap.servers": self.kafka_servers,
            "security.protocol": self.kafka_security_protocol,
        }
        if self.kafka_security_protocol == "SASL_SSL":
            result.update({
                "sasl.mechanism": self.kafka_sasl_mechanism,
                "sasl.username": self.kafka_sasl_username,
                "sasl.password": self.kafka_sasl_password.get_secret_value(),
            })
        if self.kafka_security_protocol in {"SSL", "SASL_SSL"}:
            result["enable.ssl.certificate.verification"] = True
            result["ssl.endpoint.identification.algorithm"] = "https"
            if self.kafka_ssl_ca_location:
                result["ssl.ca.location"] = self.kafka_ssl_ca_location
            if self.kafka_ssl_ca_pem:
                result["ssl.ca.pem"] = self.kafka_ssl_ca_pem
        return result
