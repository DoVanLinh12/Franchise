from uuid import uuid4

import pytest

from app.config import Settings
from app.domain import RegisterUserCommand
from app.exceptions import AuthenticationError, ValidationError
from app.security import JwtService
from app.services import auth_service
from app.services.auth_service import AuthService


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


class PasswordStub:
    def hash(self, password):
        return f"hashed:{password}"

    def verify_and_update(self, password, password_hash):
        return password_hash == f"hashed:{password}", None

    def consume_dummy_verification(self, password):
        return None


class AuthRepositorySpy:
    def __init__(self, user=None):
        self.user = user
        self.calls = []

    async def register(self, connection, **kwargs):
        self.calls.append(("register", kwargs))

    async def get_auth_by_email(self, connection, email):
        self.calls.append(("get_auth", email))
        return self.user

    async def get_roles(self, connection, user_id):
        self.calls.append(("get_roles", user_id))
        return ["STORE_OWNER"]

    async def record_login_failure(self, connection, *args):
        self.calls.append(("login_failure", args))

    async def record_login_success(self, connection, user_id):
        self.calls.append(("login_success", user_id))

    async def update_password_hash(self, connection, *args):
        self.calls.append(("update_hash", args))

    async def store_refresh_token(self, connection, **kwargs):
        self.calls.append(("store_refresh", kwargs))

    async def rotate_refresh_token(self, connection, **kwargs):
        self.calls.append(("rotate_refresh", kwargs))

    async def revoke_refresh_token(self, connection, *args):
        self.calls.append(("revoke_refresh", args))

    async def create_password_reset_token(self, connection, **kwargs):
        self.calls.append(("create_reset", kwargs))

    async def reset_password(self, connection, *args):
        self.calls.append(("reset_password", args))

    async def get_user(self, connection, user_id):
        self.calls.append(("get_user", user_id))
        return {"id": user_id, "status": "ACTIVE"}

    async def change_user_status(self, connection, *args):
        self.calls.append(("change_status", args))

    async def assign_role(self, connection, *args):
        self.calls.append(("assign_role", args))

    async def remove_role(self, connection, *args):
        self.calls.append(("remove_role", args))


def make_service(repository):
    config = Settings(
        JWT_SECRET_KEY="unit-test-secret-that-is-long-enough-for-auth",
        ACCESS_TOKEN_EXPIRE_MINUTES=15,
        REFRESH_TOKEN_EXPIRE_DAYS=7,
    )
    return AuthService(
        repository=repository,
        password_service=PasswordStub(),
        jwt_service=JwtService(config),
        config=config,
    )


@pytest.mark.asyncio
async def test_register_hashes_password_and_calls_repository(monkeypatch):
    repository = AuthRepositorySpy()
    service = make_service(repository)
    monkeypatch.setattr(auth_service, "get_pool", lambda: FakePool())

    user_id = await service.register(
        RegisterUserCommand(
            email=" Owner@Example.com ",
            password="password123",
            full_name=" Owner One ",
            phone=" 0900000000 ",
        )
    )

    call = repository.calls[0]
    assert call[0] == "register"
    assert call[1]["user_id"] == user_id
    assert call[1]["email"] == "owner@example.com"
    assert call[1]["password_hash"] == "hashed:password123"


@pytest.mark.asyncio
async def test_authenticate_stores_refresh_token(monkeypatch):
    user_id = uuid4()
    repository = AuthRepositorySpy(
        {
            "id": user_id,
            "password_hash": "hashed:password123",
            "status": "ACTIVE",
            "deleted_at": None,
            "locked_until": None,
        }
    )
    service = make_service(repository)
    monkeypatch.setattr(auth_service, "get_pool", lambda: FakePool())

    pair = await service.authenticate(
        "owner@example.com",
        "password123",
        client_ip="127.0.0.1",
        user_agent="pytest",
    )

    assert pair.token_type == "bearer"
    assert [call[0] for call in repository.calls] == [
        "get_auth",
        "get_roles",
        "login_success",
        "store_refresh",
    ]


@pytest.mark.asyncio
async def test_authenticate_records_wrong_password(monkeypatch):
    repository = AuthRepositorySpy(
        {
            "id": uuid4(),
            "password_hash": "hashed:right-password",
            "status": "ACTIVE",
            "deleted_at": None,
            "locked_until": None,
        }
    )
    service = make_service(repository)
    monkeypatch.setattr(auth_service, "get_pool", lambda: FakePool())

    with pytest.raises(AuthenticationError, match="incorrect"):
        await service.authenticate("owner@example.com", "wrong-password")

    assert repository.calls[-1][0] == "login_failure"


@pytest.mark.asyncio
async def test_refresh_logout_and_password_reset(monkeypatch):
    user_id = uuid4()
    repository = AuthRepositorySpy(
        {
            "id": user_id,
            "password_hash": "hashed:password123",
            "status": "ACTIVE",
            "deleted_at": None,
            "locked_until": None,
        }
    )
    service = make_service(repository)
    monkeypatch.setattr(auth_service, "get_pool", lambda: FakePool())
    original = service._jwt.issue_pair(user_id, ["STORE_OWNER"])

    replacement = await service.refresh(original.refresh_token)
    await service.logout(replacement.refresh_token)
    reset_token = await service.request_password_reset("owner@example.com")
    await service.reset_password(reset_token or "", "new-password123")

    names = [call[0] for call in repository.calls]
    assert "rotate_refresh" in names
    assert "revoke_refresh" in names
    assert "create_reset" in names
    assert "reset_password" in names


@pytest.mark.asyncio
async def test_user_management_and_get_user(monkeypatch):
    repository = AuthRepositorySpy()
    service = make_service(repository)
    monkeypatch.setattr(auth_service, "get_pool", lambda: FakePool())
    user_id = uuid4()
    actor_id = uuid4()

    result = await service.get_user(user_id)
    await service.change_user_status(user_id, actor_id, "locked", "Review")
    await service.assign_role(user_id, "accountant", actor_id)
    await service.remove_role(user_id, "accountant", actor_id)

    assert result is not None and result["roles"] == ["STORE_OWNER"]
    assert [call[0] for call in repository.calls] == [
        "get_user",
        "get_roles",
        "change_status",
        "assign_role",
        "remove_role",
    ]


@pytest.mark.parametrize(
    "command",
    [
        RegisterUserCommand("invalid", "password123", "Name"),
        RegisterUserCommand("a@example.com", "short", "Name"),
        RegisterUserCommand("a@example.com", "password123", " "),
    ],
)
@pytest.mark.asyncio
async def test_registration_validation(command):
    with pytest.raises(ValidationError):
        await make_service(AuthRepositorySpy()).register(command)


@pytest.mark.asyncio
async def test_management_validation(monkeypatch):
    service = make_service(AuthRepositorySpy())
    with pytest.raises(ValidationError, match="status"):
        await service.change_user_status(uuid4(), uuid4(), "unknown", "why")
    with pytest.raises(ValidationError, match="role"):
        await service.assign_role(uuid4(), "unknown", uuid4())
    repository = AuthRepositorySpy(
        {
            "id": uuid4(),
            "password_hash": "hashed:password123",
            "status": "ACTIVE",
            "deleted_at": None,
            "locked_until": None,
        }
    )
    service = make_service(repository)
    monkeypatch.setattr(auth_service, "get_pool", lambda: FakePool())
    with pytest.raises(ValidationError, match="IP"):
        await service.authenticate(
            "owner@example.com", "password123", client_ip="not-an-ip"
        )
