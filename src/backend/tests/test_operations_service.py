from uuid import uuid4

import pytest

from app.services import operations_service
from app.services.operations_service import OperationsService


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


class OperationsRepositorySpy:
    def __init__(self):
        self.calls = []

    async def list_records(self, connection, *args):
        self.calls.append(("list", args))
        return [{"id": "1"}], 1

    async def save_revenue(self, connection, **kwargs):
        self.calls.append(("save_revenue", kwargs))

    async def review_revenue(self, connection, *args):
        self.calls.append(("review_revenue", args))

    async def can_access_store(self, connection, user_id, store_id):
        self.calls.append(("can_access", (user_id, store_id)))
        return True


@pytest.mark.asyncio
async def test_list_and_save_revenue(monkeypatch):
    repository = OperationsRepositorySpy()
    service = OperationsService(repository)
    monkeypatch.setattr(operations_service, "get_pool", lambda: FakePool())
    actor_id = uuid4()
    store_id = uuid4()

    items, total = await service.list_records(
        "revenues", actor_id, None, None, 1, 20
    )
    revenue_id = await service.save_revenue(
        None,
        store_id,
        actor_id,
        {
            "business_date": "2026-09-27",
            "gross_revenue": 1000,
            "note": None,
            "promotion_details": [],
        },
    )
    await service.review_revenue(
        revenue_id, actor_id, "APPROVED", None
    )

    assert total == 1 and items == [{"id": "1"}]
    assert [call[0] for call in repository.calls] == [
        "list",
        "save_revenue",
        "review_revenue",
    ]


@pytest.mark.asyncio
async def test_store_access(monkeypatch):
    repository = OperationsRepositorySpy()
    service = OperationsService(repository)
    monkeypatch.setattr(operations_service, "get_pool", lambda: FakePool())

    await service.assert_store_access(uuid4(), uuid4())

    assert repository.calls[0][0] == "can_access"
