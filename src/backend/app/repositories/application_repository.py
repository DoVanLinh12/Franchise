from decimal import Decimal
from uuid import UUID

import asyncpg


class ApplicationRepository:
    async def submit(
        self,
        connection: asyncpg.Connection,
        *,
        application_id: UUID,
        applicant_id: UUID,
        applicant_name: str,
        email: str,
        phone: str,
        proposed_store_name: str,
        proposed_address: str,
        proposed_area: Decimal | None,
        investment_budget: Decimal | None,
        note: str | None,
    ) -> None:
        await connection.execute(
            "CALL app.proc_submit_franchise_application("
            "$1, $2, $3, $4, $5, $6, $7, $8, $9, $10)",
            application_id,
            applicant_id,
            applicant_name,
            email,
            phone,
            proposed_store_name,
            proposed_address,
            proposed_area,
            investment_budget,
            note,
        )

    async def withdraw(
        self,
        connection: asyncpg.Connection,
        application_id: UUID,
        actor_id: UUID,
        reason: str | None,
    ) -> None:
        await connection.execute(
            "CALL app.proc_withdraw_franchise_application($1, $2, $3)",
            application_id,
            actor_id,
            reason,
        )

    async def start_review(
        self,
        connection: asyncpg.Connection,
        application_id: UUID,
        actor_id: UUID,
    ) -> None:
        await connection.execute(
            "CALL app.proc_start_application_review($1, $2)",
            application_id,
            actor_id,
        )

    async def approve(
        self,
        connection: asyncpg.Connection,
        application_id: UUID,
        actor_id: UUID,
        review_note: str | None,
    ) -> None:
        await connection.execute(
            "CALL app.proc_approve_franchise_application($1, $2, $3)",
            application_id,
            actor_id,
            review_note,
        )

    async def reject(
        self,
        connection: asyncpg.Connection,
        application_id: UUID,
        actor_id: UUID,
        review_note: str,
    ) -> None:
        await connection.execute(
            "CALL app.proc_reject_franchise_application($1, $2, $3)",
            application_id,
            actor_id,
            review_note,
        )

