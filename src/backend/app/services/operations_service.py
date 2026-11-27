import json
from datetime import UTC, date, datetime
from typing import Any
from uuid import UUID, uuid4

from app.cache import get_json, set_json
from app.database import get_pool
from app.exceptions import AuthorizationError, NotFoundError, ValidationError
from app.repositories.operations_repository import OperationsRepository


class OperationsService:
    def __init__(self, repository: OperationsRepository | None = None) -> None:
        self._repository = repository or OperationsRepository()

    async def list_records(
        self,
        entity: str,
        user_id: UUID,
        search: str | None,
        status: str | None,
        page: int,
        page_size: int,
    ) -> tuple[list[dict[str, Any]], int]:
        if page < 1 or page_size < 1 or page_size > 200:
            raise ValidationError("Invalid pagination")
        async with get_pool().acquire() as connection:
            return await self._repository.list_records(
                connection,
                entity,
                user_id,
                search,
                status,
                page_size,
                (page - 1) * page_size,
            )

    async def assert_store_access(
        self, user_id: UUID, store_id: UUID
    ) -> None:
        async with get_pool().acquire() as connection:
            allowed = await self._repository.can_access_store(
                connection, user_id, store_id
            )
        if not allowed:
            raise AuthorizationError("Store access denied")

    async def record_contract_transaction(
        self, contract_id: UUID, actor_id: UUID, values: dict[str, Any]
    ) -> UUID:
        transaction_id = uuid4()
        async with get_pool().acquire() as connection:
            async with connection.transaction():
                await self._repository.record_contract_transaction(
                    connection,
                    transaction_id=transaction_id,
                    contract_id=contract_id,
                    actor_id=actor_id,
                    **values,
                )
        return transaction_id

    async def activate_contract(
        self, contract_id: UUID, actor_id: UUID
    ) -> None:
        async with get_pool().acquire() as connection:
            async with connection.transaction():
                await self._repository.activate_contract(
                    connection, contract_id, actor_id
                )

    async def create_promotion(
        self, actor_id: UUID, values: dict[str, Any]
    ) -> UUID:
        promotion_id = uuid4()
        async with get_pool().acquire() as connection:
            async with connection.transaction():
                await self._repository.create_promotion(
                    connection,
                    promotion_id=promotion_id,
                    actor_id=actor_id,
                    **values,
                )
        return promotion_id

    async def change_promotion_status(
        self,
        promotion_id: UUID,
        actor_id: UUID,
        status: str,
        reason: str | None,
    ) -> None:
        async with get_pool().acquire() as connection:
            async with connection.transaction():
                await self._repository.change_promotion_status(
                    connection, promotion_id, actor_id, status, reason
                )

    async def soft_delete_promotion(
        self, promotion_id: UUID, actor_id: UUID, reason: str
    ) -> None:
        async with get_pool().acquire() as connection:
            async with connection.transaction():
                await self._repository.soft_delete_promotion(
                    connection, promotion_id, actor_id, reason
                )

    async def save_revenue(
        self,
        revenue_id: UUID | None,
        store_id: UUID,
        actor_id: UUID,
        values: dict[str, Any],
    ) -> UUID:
        identifier = revenue_id or uuid4()
        details = values.pop("promotion_details", [])
        async with get_pool().acquire() as connection:
            async with connection.transaction():
                await self._repository.save_revenue(
                    connection,
                    revenue_id=identifier,
                    store_id=store_id,
                    actor_id=actor_id,
                    promotion_details_json=json.dumps(
                        details, default=str, separators=(",", ":")
                    ),
                    **values,
                )
        return identifier

    async def submit_revenue(
        self, revenue_id: UUID, actor_id: UUID
    ) -> None:
        async with get_pool().acquire() as connection:
            async with connection.transaction():
                await self._repository.submit_revenue(
                    connection, revenue_id, actor_id
                )

    async def review_revenue(
        self,
        revenue_id: UUID,
        actor_id: UUID,
        decision: str,
        note: str | None,
    ) -> None:
        async with get_pool().acquire() as connection:
            async with connection.transaction():
                await self._repository.review_revenue(
                    connection, revenue_id, actor_id, decision, note
                )

    async def request_revenue_adjustment(
        self, revenue_id: UUID, actor_id: UUID, reason: str
    ) -> None:
        if not reason.strip():
            raise ValidationError("Adjustment reason is required")
        async with get_pool().acquire() as connection:
            async with connection.transaction():
                await self._repository.request_revenue_adjustment(
                    connection, revenue_id, actor_id, reason
                )

    async def get_document(
        self, kind: str, record_id: UUID
    ) -> dict[str, Any]:
        async with get_pool().acquire() as connection:
            document = await self._repository.get_document(
                connection, kind, record_id
            )
        if document is None:
            raise NotFoundError(f"{kind.title()} not found")
        return document

    async def create_adjustment(
        self, store_id: UUID, actor_id: UUID, values: dict[str, Any]
    ) -> UUID:
        adjustment_id = uuid4()
        async with get_pool().acquire() as connection:
            async with connection.transaction():
                await self._repository.create_billing_adjustment(
                    connection,
                    adjustment_id=adjustment_id,
                    store_id=store_id,
                    actor_id=actor_id,
                    **values,
                )
        return adjustment_id

    async def generate_invoice(
        self, store_id: UUID, actor_id: UUID, values: dict[str, Any]
    ) -> UUID:
        invoice_id = uuid4()
        async with get_pool().acquire() as connection:
            async with connection.transaction():
                await self._repository.generate_invoice(
                    connection,
                    invoice_id=invoice_id,
                    store_id=store_id,
                    actor_id=actor_id,
                    **values,
                )
        return invoice_id

    async def issue_invoice(
        self, invoice_id: UUID, actor_id: UUID
    ) -> None:
        async with get_pool().acquire() as connection:
            async with connection.transaction():
                await self._repository.issue_invoice(
                    connection, invoice_id, actor_id
                )

    async def cancel_invoice(
        self, invoice_id: UUID, actor_id: UUID, reason: str
    ) -> None:
        async with get_pool().acquire() as connection:
            async with connection.transaction():
                await self._repository.cancel_invoice(
                    connection, invoice_id, actor_id, reason
                )

    async def record_payment(
        self, invoice_id: UUID, actor_id: UUID, values: dict[str, Any]
    ) -> UUID:
        payment_id = uuid4()
        async with get_pool().acquire() as connection:
            async with connection.transaction():
                await self._repository.record_payment(
                    connection,
                    payment_id=payment_id,
                    invoice_id=invoice_id,
                    actor_id=actor_id,
                    **values,
                )
        return payment_id

    async def reverse_payment(
        self, payment_id: UUID, actor_id: UUID, reason: str
    ) -> None:
        async with get_pool().acquire() as connection:
            async with connection.transaction():
                await self._repository.reverse_payment(
                    connection, payment_id, actor_id, reason
                )

    async def generate_alerts(self, as_of: datetime | None = None) -> None:
        async with get_pool().acquire() as connection:
            async with connection.transaction():
                await self._repository.generate_alerts(
                    connection, as_of or datetime.now(UTC)
                )

    async def mark_notification_read(
        self, notification_id: UUID, user_id: UUID
    ) -> None:
        async with get_pool().acquire() as connection:
            async with connection.transaction():
                await self._repository.mark_notification_read(
                    connection, notification_id, user_id
                )

    async def financial_summary(
        self, user_id: UUID, period_from: date, period_to: date
    ) -> list[dict[str, Any]]:
        if period_to < period_from:
            raise ValidationError("Invalid report period")
        cache_key = f"report:financial:{user_id}:{period_from}:{period_to}"
        cached = await get_json(cache_key)
        if isinstance(cached, list):
            return cached
        async with get_pool().acquire() as connection:
            result = await self._repository.financial_summary(
                connection, user_id, period_from, period_to
            )
        await set_json(cache_key, result, ttl_seconds=60)
        return result
