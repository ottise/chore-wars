import pytest

from app.config import Settings


@pytest.fixture(autouse=True)
def clean_provider_environment(monkeypatch):
    for suffix in ("API_KEY", "TEXT_MODEL", "VISION_MODEL"):
        monkeypatch.delenv(f"GEMINI_{suffix}", raising=False)
        monkeypatch.delenv(f"AI_GEMINI_{suffix}", raising=False)


@pytest.mark.parametrize("prefix", ["", "AI_"])
def test_render_and_compose_names_configure_the_same_provider(monkeypatch, prefix):
    monkeypatch.setenv(f"{prefix}GEMINI_API_KEY", "synthetic-provider-key")
    monkeypatch.setenv(f"{prefix}GEMINI_TEXT_MODEL", "selected-text-model")
    monkeypatch.setenv(f"{prefix}GEMINI_VISION_MODEL", "selected-vision-model")
    settings = Settings(environment="test", service_key="x" * 32)
    assert settings.gemini_api_key.get_secret_value() == "synthetic-provider-key"
    assert settings.gemini_text_model == "selected-text-model"
    assert settings.gemini_vision_model == "selected-vision-model"
    assert "synthetic-provider-key" not in repr(settings)


def test_explicit_render_names_override_old_prefixed_values(monkeypatch):
    for prefix, value in (("AI_", "older"), ("", "selected")):
        monkeypatch.setenv(f"{prefix}GEMINI_API_KEY", value)
        monkeypatch.setenv(f"{prefix}GEMINI_TEXT_MODEL", value + "-text")
        monkeypatch.setenv(f"{prefix}GEMINI_VISION_MODEL", value + "-vision")
    settings = Settings(environment="test", service_key="x" * 32)
    assert settings.gemini_api_key.get_secret_value() == "selected"
    assert settings.gemini_text_model == "selected-text"
    assert settings.gemini_vision_model == "selected-vision"


def test_explicit_constructor_values_still_override_environment(monkeypatch):
    monkeypatch.setenv("GEMINI_API_KEY", "environment-key")
    monkeypatch.setenv("GEMINI_TEXT_MODEL", "environment-model")
    settings = Settings(environment="test", service_key="x" * 32,
                        gemini_api_key="constructor-key", gemini_text_model="constructor-model")
    assert settings.gemini_api_key.get_secret_value() == "constructor-key"
    assert settings.gemini_text_model == "constructor-model"
