from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    anthropic_api_key: str
    environment: str = "development"

    # Haiku für Empfehlungen (schnell, ~3-5s) — Sonnet für Erklärungen (qualitativ)
    claude_model: str = "claude-haiku-4-5-20251001"
    claude_explain_model: str = "claude-sonnet-4-5"
    claude_max_tokens: int = 4096


settings = Settings()
