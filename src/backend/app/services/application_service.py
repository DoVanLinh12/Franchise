from uuid import UUID, uuid4

from app.database import get_pool
from app.domain import SubmitApplicationCommand
from app.exceptions import ValidationError
from app.repositories.application_repository import ApplicationRepository


class ApplicationService:
    def __init__(self, repository: ApplicationRepository | None = None) -> None:
        self._repository = repository or ApplicationRepository()

    async def submit(self, command: SubmitApplicationCommand) -> UUID:
        self._validate_submit(command)
        application_id = uuid4()

        async with get_pool().acquire() as connection:
            async with connection.transaction():
                await self._repository.submit(
                    connection,
                    application_id=application_id,
                    applicant_id=command.applicant_id,
                    applicant_name=command.applicant_name,
                    email=command.email,
                    phone=command.phone,
                    proposed_store_name=command.proposed_store_name,
                    proposed_address=command.proposed_address,
                    proposed_area=command.proposed_area,
                    investment_budget=command.investment_budget,
                    note=command.note,
                )
        return application_id

    async def withdraw(
        self, application_id: UUID, actor_id: UUID, reason: str | None
    ) -> None:
        async with get_pool().acquire() as connection:
            async with connection.transaction():
                await self._repository.withdraw(
                    connection, application_id, actor_id, reason
                )

    async def start_review(
        self, application_id: UUID, actor_id: UUID
    ) -> None:
        async with get_pool().acquire() as connection:
            async with connection.transaction():
                await self._repository.start_review(
                    connection, application_id, actor_id
                )

    async def approve(
        self,
        application_id: UUID,
        actor_id: UUID,
        review_note: str | None,
    ) -> None:
        async with get_pool().acquire() as connection:
            async with connection.transaction():
                await self._repository.approve(
                    connection, application_id, actor_id, review_note
                )

    async def reject(
        self,
        application_id: UUID,
        actor_id: UUID,
        review_note: str,
    ) -> None:
        if not review_note.strip():
            raise ValidationError("Rejection reason is required")

        async with get_pool().acquire() as connection:
            async with connection.transaction():
                await self._repository.reject(
                    connection, application_id, actor_id, review_note
                )

    @staticmethod
    def _validate_submit(command: SubmitApplicationCommand) -> None:
        required = {
            "applicant_name": command.applicant_name,
            "email": command.email,
            "phone": command.phone,
            "proposed_store_name": command.proposed_store_name,
            "proposed_address": command.proposed_address,
        }
        missing = [name for name, value in required.items() if not value.strip()]
        if missing:
            raise ValidationError(
                f"Required fields are empty: {', '.join(missing)}"
            )
        if command.proposed_area is not None and command.proposed_area <= 0:
            raise ValidationError("Proposed area must be greater than zero")
        if (
            command.investment_budget is not None
            and command.investment_budget < 0
        ):
            raise ValidationError("Investment budget cannot be negative")
