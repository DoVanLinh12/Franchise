from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    APP_NAME: str = "Franchise Management API"
    DATABASE_URL: str = (
        "postgresql://postgres:postgres@localhost:5432/franchise"
    )
    REDIS_URL: str = "redis://localhost:6379/0"
    JWT_SECRET_KEY: str = (
        "local-development-only-change-this-secret-before-sharing"
    )
    JWT_ALGORITHM: str = "HS256"
    JWT_ISSUER: str = "franchise-api"
    JWT_AUDIENCE: str = "franchise-api-users"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    PASSWORD_RESET_EXPIRE_MINUTES: int = 30
    CORS_ORIGINS: str = "http://localhost:3000,http://localhost:5173"
    RATE_LIMIT_REQUESTS: int = 120
    RATE_LIMIT_WINDOW_SECONDS: int = 60
    SMTP_HOST: str = "localhost"
    SMTP_PORT: int = 1025
    EMAIL_FROM: str = "noreply@franchise.local"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
