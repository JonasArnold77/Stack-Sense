from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    anthropic_api_key: str
    environment: str = "development"

    # Haiku für Empfehlungen (schnell, ~3-5s) — Sonnet für Erklärungen (qualitativ)
    claude_model: str = "claude-haiku-4-5-20251001"
    claude_explain_model: str = "claude-sonnet-4-5"
    claude_max_tokens: int = 3000   # 5 Supplements × ~500 Token reicht gut aus

    # RDS / pgvector (optional — App startet auch ohne)
    db_host: str = "stacksense-db.chym26e8iw2p.eu-central-1.rds.amazonaws.com"
    db_user: str = "stacksense"
    db_pass: str = ""
    db_name: str = "postgres"
    db_port: int = 5432

    # AWS Cognito — User Pool für Auth
    # Werte aus AWS Console: Cognito → User Pools → dein Pool
    cognito_region: str = "eu-central-1"
    cognito_user_pool_id: str = ""        # z.B. "eu-central-1_AbCdEfGhI"
    cognito_client_id: str = ""           # App-Client-ID aus dem User Pool


settings = Settings()
