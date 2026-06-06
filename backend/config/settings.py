from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    anthropic_api_key: str
    environment: str = "development"

    # Claude-Modell — Sonnet ist das beste Preis-Leistungs-Verhältnis
    claude_model: str = "claude-sonnet-4-5"
    claude_max_tokens: int = 2048


settings = Settings()
