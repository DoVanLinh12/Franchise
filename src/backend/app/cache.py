import json
from typing import Any

from redis.asyncio import Redis
from redis.exceptions import RedisError

from app.config import settings


async def get_json(key: str) -> Any | None:
    client = Redis.from_url(settings.REDIS_URL, decode_responses=True)
    try:
        value = await client.get(key)
        return json.loads(value) if value else None
    except (RedisError, json.JSONDecodeError):
        return None
    finally:
        await client.aclose()


async def set_json(key: str, value: Any, ttl_seconds: int = 60) -> None:
    client = Redis.from_url(settings.REDIS_URL, decode_responses=True)
    try:
        await client.set(
            key,
            json.dumps(value, default=str, separators=(",", ":")),
            ex=ttl_seconds,
        )
    except RedisError:
        pass
    finally:
        await client.aclose()
