from datetime import date
from decimal import Decimal
from uuid import uuid4

import pytest

from app.domain import (
    CreateDraftContractCommand,
    SubmitApplicationCommand,
)
from app.exceptions import ValidationError
from app.services import application_service, contract_service
from app.services.application_service import ApplicationService
from app.services.contract_service import ContractService


class AsyncContext:
    def __init__(self, value=None):
        self.value = value

    async def __aenter__(self):
        return self.value

    async def __aexit__(self, exc_type, exc_value, traceback):
        return False


class FakeConnection:
    def transaction(self):
        return AsyncContext()


class FakePool:
    def __init__(self):
        self.connection = FakeConnection()

    def acquire(self):
        return AsyncContext(self.connection)


class ApplicationRepositorySpy:
    def __init__(self):
        self.calls = []

    async def submit(self, connection, **kwargs):
        self.calls.append(("submit", connection, kwargs))

    async def withdraw(self, connection, *args):
        self.calls.append(("withdraw", connection, args))

    async def start_review(self, connection, *args):
        self.calls.append(("start_review", connection, args))

    async def approve(self, connection, *args):
        self.calls.append(("approve", connection, args))

    async def reject(self, connection, *args):
        self.calls.append(("reject", connection, args))



class ContractRepositorySpy:
    def __init__(self):
        self.calls = []

    async def create_draft(self, connection, **kwargs):
        self.calls.append(("create_draft", connection, kwargs))

    async def get_by_id(self, connection, contract_id):
        self.calls.append(("get_by_id", connection, (contract_id,)))
        return {"id": contract_id, "status": "DRAFT"}


def application_command(**overrides):
    values = {
        "applicant_id": uuid4(),
        "applicant_name": "Applicant",
        "email": "owner@example.com",
        "phone": "0900000000",
        "proposed_store_name": "Store One",
        "proposed_address": "Address One",
        "proposed_area": Decimal("100"),
        "investment_budget": Decimal("500000000"),
    }
    values.update(overrides)
    return SubmitApplicationCommand(**values)


@pytest.mark.asyncio
async def test_application_service_workflow_calls_repository(monkeypatch):
    pool = FakePool()
    repository = ApplicationRepositorySpy()
    service = ApplicationService(repository)
    monkeypatch.setattr(application_service, "get_pool", lambda: pool)

    application_id = await service.submit(application_command())
    actor_id = uuid4()

    await service.withdraw(application_id, actor_id, "Changed plan")
    await service.start_review(application_id, actor_id)
    await service.approve(application_id, actor_id, "Approved")
    await service.reject(application_id, actor_id, "Missing documents")

    assert [call[0] for call in repository.calls] == [
        "submit",
        "withdraw",
        "start_review",
        "approve",
        "reject",
    ]


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("overrides", "message"),
    [
        ({"applicant_name": ""}, "Required fields are empty"),
        ({"proposed_area": Decimal("0")}, "greater than zero"),
        ({"investment_budget": Decimal("-1")}, "cannot be negative"),
    ],
)
async def test_application_submit_validation(overrides, message):
    service = ApplicationService(ApplicationRepositorySpy())

    with pytest.raises(ValidationError, match=message):
        await service.submit(application_command(**overrides))


@pytest.mark.asyncio
async def test_application_rejection_requires_reason():
    service = ApplicationService(ApplicationRepositorySpy())

    with pytest.raises(ValidationError, match="Rejection reason"):
        await service.reject(uuid4(), uuid4(), "  ")


def contract_command(**overrides):
    values = {
        "actor_id": uuid4(),
        "application_id": uuid4(),
        "contract_no": "CONTRACT-001",
        "signed_date": date(2026, 9, 25),
        "effective_from": date(2026, 10, 1),
        "effective_to": date(2027, 9, 30),
        "royalty_rate": Decimal("5.5"),
        "initial_franchise_fee": Decimal("100000000"),
        "deposit_amount": Decimal("20000000"),
        "system_fee": Decimal("1000000"),
        "service_fee": Decimal("2000000"),
    }
    values.update(overrides)
    return CreateDraftContractCommand(**values)


@pytest.mark.asyncio
async def test_contract_service_create_and_get(monkeypatch):
    pool = FakePool()
    repository = ContractRepositorySpy()
    service = ContractService(repository)
    monkeypatch.setattr(contract_service, "get_pool", lambda: pool)

    contract_id = await service.create_draft(contract_command())
    result = await service.get_by_id(contract_id)

    assert result == {"id": contract_id, "status": "DRAFT"}
    assert [call[0] for call in repository.calls] == [
        "create_draft",
        "get_by_id",
    ]


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("overrides", "message"),
    [
        ({"contract_no": ""}, "Contract number"),
        (
            {
                "effective_from": date(2027, 1, 1),
                "effective_to": date(2026, 1, 1),
            },
            "end date",
        ),
        ({"royalty_rate": Decimal("101")}, "Royalty rate"),
        ({"deposit_amount": Decimal("-1")}, "cannot be negative"),
    ],
)
async def test_contract_validation(overrides, message):
    service = ContractService(ContractRepositorySpy())

    with pytest.raises(ValidationError, match=message):
        await service.create_draft(contract_command(**overrides))
