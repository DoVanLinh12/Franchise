import json
from datetime import date, datetime
from typing import Any
from uuid import UUID

import asyncpg


def _json_object(value: Any) -> dict[str, Any]:
    """Normalize asyncpg's default JSON/JSONB string representation."""
    if isinstance(value, str):
        decoded = json.loads(value)
        if not isinstance(decoded, dict):
            raise ValueError("Expected a JSON object from the database")
        return decoded
    return dict(value)


class OperationsRepository:
    async def can_access_store(
        self,
        connection: asyncpg.Connection,
        user_id: UUID,
        store_id: UUID,
    ) -> bool:
        return bool(
            await connection.fetchval(
                "SELECT app.user_can_access_store($1,$2)", user_id, store_id
            )
        )
    async def list_records(
        self,
        connection: asyncpg.Connection,
        entity: str,
        user_id: UUID,
        search: str | None,
        status: str | None,
        page_size: int,
        offset: int,
    ) -> tuple[list[dict[str, Any]], int]:
        rows = await connection.fetch(
            "SELECT * FROM app.fn_list_records($1, $2, $3, $4, $5, $6)",
            entity,
            user_id,
            search,
            status,
            page_size,
            offset,
        )
        items = [_json_object(row["data"]) for row in rows]
        total = int(rows[0]["total_count"]) if rows else 0
        return items, total

    async def record_contract_transaction(
        self, connection: asyncpg.Connection, **values: Any
    ) -> None:
        await connection.execute(
            "CALL app.proc_record_contract_financial_transaction("
            "$1,$2,$3,$4,$5,$6,$7,$8)",
            values["transaction_id"],
            values["contract_id"],
            values["actor_id"],
            values["transaction_type"],
            values["amount"],
            values["transaction_date"],
            values["reference_no"],
            values["note"],
        )

    async def activate_contract(
        self, connection: asyncpg.Connection, contract_id: UUID, actor_id: UUID
    ) -> None:
        await connection.execute(
            "CALL app.proc_activate_contract($1,$2)", contract_id, actor_id
        )

    async def create_promotion(
        self, connection: asyncpg.Connection, **values: Any
    ) -> None:
        await connection.execute(
            "CALL app.proc_create_promotion("
            "$1,$2,$3,$4,$5,$6,$7,$8,$9,$10)",
            values["promotion_id"],
            values["actor_id"],
            values["name"],
            values["description"],
            values["discount_type"],
            values["discount_value"],
            values["start_date"],
            values["end_date"],
            values["scope"],
            values["store_ids"],
        )

    async def change_promotion_status(
        self,
        connection: asyncpg.Connection,
        promotion_id: UUID,
        actor_id: UUID,
        status: str,
        reason: str | None,
    ) -> None:
        await connection.execute(
            "CALL app.proc_change_promotion_status($1,$2,$3,$4)",
            promotion_id,
            actor_id,
            status,
            reason,
        )

    async def soft_delete_promotion(
        self,
        connection: asyncpg.Connection,
        promotion_id: UUID,
        actor_id: UUID,
        reason: str,
    ) -> None:
        await connection.execute(
            "CALL app.proc_soft_delete_promotion($1,$2,$3)",
            promotion_id,
            actor_id,
            reason,
        )

    async def save_revenue(
        self, connection: asyncpg.Connection, **values: Any
    ) -> None:
        await connection.execute(
            "CALL app.proc_save_revenue($1,$2,$3,$4,$5,$6,$7::jsonb)",
            values["revenue_id"],
            values["store_id"],
            values["actor_id"],
            values["business_date"],
            values["gross_revenue"],
            values["note"],
            values["promotion_details_json"],
        )

    async def submit_revenue(
        self, connection: asyncpg.Connection, revenue_id: UUID, actor_id: UUID
    ) -> None:
        await connection.execute(
            "CALL app.proc_submit_revenue($1,$2)", revenue_id, actor_id
        )

    async def review_revenue(
        self,
        connection: asyncpg.Connection,
        revenue_id: UUID,
        actor_id: UUID,
        decision: str,
        note: str | None,
    ) -> None:
        await connection.execute(
            "CALL app.proc_review_revenue($1,$2,$3,$4)",
            revenue_id,
            actor_id,
            decision,
            note,
        )

    async def request_revenue_adjustment(
        self,
        connection: asyncpg.Connection,
        revenue_id: UUID,
        actor_id: UUID,
        reason: str,
    ) -> None:
        await connection.execute(
            "CALL app.proc_request_revenue_adjustment($1,$2,$3)",
            revenue_id,
            actor_id,
            reason,
        )

    async def create_billing_adjustment(
        self, connection: asyncpg.Connection, **values: Any
    ) -> None:
        await connection.execute(
            "CALL app.proc_create_billing_adjustment($1,$2,$3,$4,$5,$6)",
            values["adjustment_id"],
            values["store_id"],
            values["actor_id"],
            values["source_period"],
            values["amount"],
            values["reason"],
        )

    async def generate_invoice(
        self, connection: asyncpg.Connection, **values: Any
    ) -> None:
        await connection.execute(
            "CALL app.proc_generate_monthly_invoice($1,$2,$3,$4,$5,$6)",
            values["invoice_id"],
            values["invoice_no"],
            values["store_id"],
            values["period_month"],
            values["vat_rate"],
            values["actor_id"],
        )

    async def issue_invoice(
        self, connection: asyncpg.Connection, invoice_id: UUID, actor_id: UUID
    ) -> None:
        await connection.execute(
            "CALL app.proc_issue_invoice($1,$2)", invoice_id, actor_id
        )

    async def cancel_invoice(
        self,
        connection: asyncpg.Connection,
        invoice_id: UUID,
        actor_id: UUID,
        reason: str,
    ) -> None:
        await connection.execute(
            "CALL app.proc_cancel_invoice($1,$2,$3)",
            invoice_id,
            actor_id,
            reason,
        )

    async def get_document(
        self, connection: asyncpg.Connection, kind: str, record_id: UUID
    ) -> dict[str, Any] | None:
        function = {
            "contract": "app.fn_contract_document",
            "invoice": "app.fn_invoice_document",
        }[kind]
        value = await connection.fetchval(f"SELECT {function}($1)", record_id)
        return _json_object(value) if value else None

    async def record_payment(
        self, connection: asyncpg.Connection, **values: Any
    ) -> None:
        await connection.execute(
            "CALL app.proc_record_payment($1,$2,$3,$4,$5,$6,$7,$8)",
            values["payment_id"],
            values["payment_no"],
            values["invoice_id"],
            values["amount"],
            values["payment_date"],
            values["method"],
            values["reference_no"],
            values["actor_id"],
        )

    async def reverse_payment(
        self,
        connection: asyncpg.Connection,
        payment_id: UUID,
        actor_id: UUID,
        reason: str,
    ) -> None:
        await connection.execute(
            "CALL app.proc_reverse_payment($1,$2,$3)",
            payment_id,
            actor_id,
            reason,
        )

    async def generate_alerts(
        self, connection: asyncpg.Connection, as_of: datetime
    ) -> None:
        await connection.execute(
            "CALL app.proc_generate_operational_alerts($1)", as_of
        )

    async def mark_notification_read(
        self,
        connection: asyncpg.Connection,
        notification_id: UUID,
        user_id: UUID,
    ) -> None:
        await connection.execute(
            "CALL app.proc_mark_notification_read($1,$2)",
            notification_id,
            user_id,
        )

    async def financial_summary(
        self,
        connection: asyncpg.Connection,
        user_id: UUID,
        period_from: date,
        period_to: date,
    ) -> list[dict[str, Any]]:
        rows = await connection.fetch(
            "SELECT * FROM app.fn_financial_summary($1,$2,$3)",
            user_id,
            period_from,
            period_to,
        )
        return [dict(row) for row in rows]
