from typing import Any
from uuid import UUID

import asyncpg


class StoreRepository:
    async def create_from_application(
        self,
        connection: asyncpg.Connection,
        *,
        store_id: UUID,
        application_id: UUID,
        actor_id: UUID,
        owner_id: UUID,
        code: str,
        name: str,
        address: str,
        phone: str | None,
        email: str | None,
    ) -> None:
        await connection.execute(
            "CALL app.proc_create_store_from_application("
            "$1, $2, $3, $4, $5, $6, $7, $8, $9)",
            store_id,
            application_id,
            actor_id,
            owner_id,
            code,
            name,
            address,
            phone,
            email,
        )

    async def get_by_id(
        self,
        connection: asyncpg.Connection,
        store_id: UUID,
    ) -> dict[str, Any] | None:
        row = await connection.fetchrow(
            "SELECT * FROM app.fn_get_store($1)", store_id
        )
        return dict(row) if row is not None else None
