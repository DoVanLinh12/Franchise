from datetime import datetime
from ipaddress import IPv4Address, IPv6Address
from typing import Any
from uuid import UUID

import asyncpg


class AuthRepository:
    async def register(
        self,
        connection: asyncpg.Connection,
        *,
        user_id: UUID,
        email: str,
        password_hash: str,
        full_name: str,
        phone: str | None,
    ) -> None:
        await connection.execute(
            "CALL app.proc_register_user($1, $2, $3, $4, $5)",
            user_id,
            email,
            password_hash,
            full_name,
            phone,
        )

    async def get_auth_by_email(
        self, connection: asyncpg.Connection, email: str
    ) -> dict[str, Any] | None:
        row = await connection.fetchrow(
            "SELECT * FROM app.fn_get_user_auth_by_email($1)", email
        )
        return dict(row) if row is not None else None

    async def get_user(
        self, connection: asyncpg.Connection, user_id: UUID
    ) -> dict[str, Any] | None:
        row = await connection.fetchrow(
            "SELECT * FROM app.fn_get_user($1)", user_id
        )
        return dict(row) if row is not None else None

    async def get_roles(
        self, connection: asyncpg.Connection, user_id: UUID
    ) -> list[str]:
        rows = await connection.fetch(
            "SELECT * FROM app.fn_get_user_roles($1)", user_id
        )
        return [str(row["code"]) for row in rows]

    async def record_login_success(
        self, connection: asyncpg.Connection, user_id: UUID
    ) -> None:
        await connection.execute(
            "CALL app.proc_record_login_success($1)", user_id
        )

    async def update_password_hash(
        self,
        connection: asyncpg.Connection,
        user_id: UUID,
        password_hash: str,
    ) -> None:
        await connection.execute(
            "CALL app.proc_update_password_hash($1, $2)",
            user_id,
            password_hash,
        )

    async def create_password_reset_token(
        self,
        connection: asyncpg.Connection,
        *,
        token_id: UUID,
        user_id: UUID,
        token_hash: str,
        expires_at: datetime,
        ip_address: IPv4Address | IPv6Address | None,
    ) -> None:
        await connection.execute(
            "CALL app.proc_create_password_reset_token("
            "$1, $2, $3, $4, $5)",
            token_id,
            user_id,
            token_hash,
            expires_at,
            ip_address,
        )

    async def reset_password(
        self,
        connection: asyncpg.Connection,
        token_hash: str,
        new_password_hash: str,
    ) -> None:
        await connection.execute(
            "CALL app.proc_reset_password($1, $2)",
            token_hash,
            new_password_hash,
        )

    async def change_user_status(
        self,
        connection: asyncpg.Connection,
        user_id: UUID,
        actor_id: UUID,
        new_status: str,
        reason: str,
    ) -> None:
        await connection.execute(
            "CALL app.proc_change_user_status($1, $2, $3, $4)",
            user_id,
            actor_id,
            new_status,
            reason,
        )

    async def assign_role(
        self,
        connection: asyncpg.Connection,
        user_id: UUID,
        role_code: str,
        actor_id: UUID,
    ) -> None:
        await connection.execute(
            "CALL app.proc_assign_user_role($1, $2, $3)",
            user_id,
            role_code,
            actor_id,
        )

    async def remove_role(
        self,
        connection: asyncpg.Connection,
        user_id: UUID,
        role_code: str,
        actor_id: UUID,
    ) -> None:
        await connection.execute(
            "CALL app.proc_remove_user_role($1, $2, $3)",
            user_id,
            role_code,
            actor_id,
        )
