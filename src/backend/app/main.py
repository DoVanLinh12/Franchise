from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

import asyncpg
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from redis.asyncio import Redis

from app.api.auth import router as auth_router
from app.api.business import router as business_router
from app.api.exports import router as exports_router
from app.config import settings
from app.database import connect_database, disconnect_database, get_pool
from app.exceptions import (
    AuthenticationError,
    AuthorizationError,
    BusinessError,
    ConflictError,
    NotFoundError,
    ValidationError,
)
from app.observability import (
    RateLimitMiddleware,
    RequestLoggingMiddleware,
    configure_logging,
)


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    await connect_database()
    try:
        yield
    finally:
        await disconnect_database()

app = FastAPI(
    title=settings.APP_NAME,
    version="1.0.0",
    lifespan=lifespan,
)
configure_logging()
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        origin.strip()
        for origin in settings.CORS_ORIGINS.split(",")
        if origin.strip()
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(
    RateLimitMiddleware,
    requests=settings.RATE_LIMIT_REQUESTS,
    window_seconds=settings.RATE_LIMIT_WINDOW_SECONDS,
)
app.add_middleware(RequestLoggingMiddleware)
app.include_router(auth_router, prefix="/api/v1")
app.include_router(business_router, prefix="/api/v1")
app.include_router(exports_router, prefix="/api/v1")


@app.exception_handler(BusinessError)
async def business_error_handler(
    _: Request, exc: BusinessError
) -> JSONResponse:
    status_code = 400
    if isinstance(exc, AuthenticationError):
        status_code = 401
    elif isinstance(exc, AuthorizationError):
        status_code = 403
    elif isinstance(exc, NotFoundError):
        status_code = 404
    elif isinstance(exc, ConflictError):
        status_code = 409
    elif isinstance(exc, ValidationError):
        status_code = 422
    return JSONResponse(status_code=status_code, content={"detail": str(exc)})


@app.exception_handler(asyncpg.PostgresError)
async def database_error_handler(
    _: Request, exc: asyncpg.PostgresError
) -> JSONResponse:
    message = str(exc).split("\n", 1)[0]
    known_conflicts = (
        "ALREADY", "INVALID", "REQUIRED", "NOT_FOUND", "CANNOT", "MUST_BE"
    )
    status_code = 409 if any(x in message for x in known_conflicts) else 400
    return JSONResponse(status_code=status_code, content={"detail": message})


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/health/ready")
async def readiness() -> dict[str, str]:
    async with get_pool().acquire() as connection:
        await connection.fetchval("SELECT 1")
    redis_client = Redis.from_url(settings.REDIS_URL)
    try:
        await redis_client.ping()
    finally:
        await redis_client.aclose()
    return {"status": "ready", "database": "ok", "redis": "ok"}
