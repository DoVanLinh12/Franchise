from typing import Any
from uuid import UUID, uuid4

from app.database import get_pool
from app.domain import CreateStoreCommand
from app.exceptions import ValidationError
from app.repositories.store_repository import StoreRepository


class StoreService:
    def __init__(self, repository: StoreRepository | None = None) -> None:
        self._repository = repository or StoreRepository()

    async def create_from_application(self, command: CreateStoreCommand) -> UUID:
        required = {
            "code": command.code,
            "name": command.name,
            "address": command.address,
        }
        missing = [name for name, value in required.items() if not value.strip()]
        if missing:
            raise ValidationError(
                f"Required fields are empty: {', '.join(missing)}"
            )

        store_id = uuid4()
        async with get_pool().acquire() as connection:
            async with connection.transaction():
                await self._repository.create_from_application(
                    connection,
                    store_id=store_id,
                    application_id=command.application_id,
                    actor_id=command.actor_id,
                    owner_id=command.owner_id,
                    code=command.code,
                    name=command.name,
                    address=command.address,
                    phone=command.phone,
                    email=command.email,
                )
        return store_id

    async def get_by_id(self, store_id: UUID) -> dict[str, Any] | None:
        async with get_pool().acquire() as connection:
            return await self._repository.get_by_id(connection, store_id)
