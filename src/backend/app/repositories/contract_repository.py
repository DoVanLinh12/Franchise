from datetime import date
from decimal import Decimal
from typing import Any
from uuid import UUID

import asyncpg


class ContractRepository:
    async def create_draft(
        self,
        connection: asyncpg.Connection,
        *,
        contract_id: UUID,
        actor_id: UUID,
        application_id: UUID,
        contract_no: str,
        signed_date: date | None,
        effective_from: date,
        effective_to: date,
        royalty_rate: Decimal,
        initial_franchise_fee: Decimal,
        deposit_amount: Decimal,
        system_fee: Decimal,
        service_fee: Decimal,
    ) -> None:
        await connection.execute(
            "CALL app.proc_create_draft_contract("
            "$1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)",
            contract_id,
            actor_id,
            application_id,
            contract_no,
            signed_date,
            effective_from,
            effective_to,
            royalty_rate,
            initial_franchise_fee,
            deposit_amount,
            system_fee,
            service_fee,
        )

    async def get_by_id(
        self,
        connection: asyncpg.Connection,
        contract_id: UUID,
    ) -> dict[str, Any] | None:
        row = await connection.fetchrow(
            "SELECT * FROM app.fn_get_contract($1)", contract_id
        )
        return dict(row) if row is not None else None
