from collections.abc import AsyncIterator

import asyncpg

from app.config import settings

_pool: asyncpg.Pool | None = None


async def connect_database() -> None:
    global _pool
    _pool = await asyncpg.create_pool(dsn=settings.DATABASE_URL)


async def disconnect_database() -> None:
    global _pool
    if _pool is not None:
        await _pool.close()
        _pool = None


def get_pool() -> asyncpg.Pool:
    if _pool is None:
        raise RuntimeError("Database pool is not initialized")
    return _pool


async def get_connection() -> AsyncIterator[asyncpg.Connection]:
    async with get_pool().acquire() as connection:
        yield connection
