from typing import Any
from uuid import UUID, uuid4

from app.database import get_pool
from app.domain import CreateDraftContractCommand
from app.exceptions import ValidationError
from app.repositories.contract_repository import ContractRepository


class ContractService:
    def __init__(self, repository: ContractRepository | None = None) -> None:
        self._repository = repository or ContractRepository()

    async def create_draft(self, command: CreateDraftContractCommand) -> UUID:
        if not command.contract_no.strip():
            raise ValidationError("Contract number is required")
        if command.effective_to < command.effective_from:
            raise ValidationError("Contract end date cannot precede start date")
        if not 0 <= command.royalty_rate <= 100:
            raise ValidationError("Royalty rate must be between 0 and 100")

        amounts = (
            command.initial_franchise_fee,
            command.deposit_amount,
            command.system_fee,
            command.service_fee,
        )
        if any(amount < 0 for amount in amounts):
            raise ValidationError("Contract amounts cannot be negative")

        contract_id = uuid4()
        async with get_pool().acquire() as connection:
            async with connection.transaction():
                await self._repository.create_draft(
                    connection,
                    contract_id=contract_id,
                    actor_id=command.actor_id,
                    store_id=command.store_id,
                    contract_no=command.contract_no,
                    signed_date=command.signed_date,
                    effective_from=command.effective_from,
                    effective_to=command.effective_to,
                    royalty_rate=command.royalty_rate,
                    initial_franchise_fee=command.initial_franchise_fee,
                    deposit_amount=command.deposit_amount,
                    system_fee=command.system_fee,
                    service_fee=command.service_fee,
                )
        return contract_id

    async def get_by_id(self, contract_id: UUID) -> dict[str, Any] | None:
        async with get_pool().acquire() as connection:
            return await self._repository.get_by_id(connection, contract_id)
