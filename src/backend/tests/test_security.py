from uuid import uuid4

import pytest

from app.config import Settings
from app.exceptions import TokenError
from app.security import JwtService, PasswordService, hash_token


def test_password_service_hashes_and_verifies_password():
    service = PasswordService()
    password_hash = service.hash("strong-password")

    assert password_hash != "strong-password"
    assert service.verify("strong-password", password_hash)
    assert not service.verify("wrong-password", password_hash)
    assert not service.verify("strong-password", "not-a-valid-hash")


def test_jwt_service_issues_typed_token_pair():
    config = Settings(
        JWT_SECRET_KEY="unit-test-secret-that-is-long-enough-for-tests",
        ACCESS_TOKEN_EXPIRE_MINUTES=10,
        REFRESH_TOKEN_EXPIRE_DAYS=2,
    )
    service = JwtService(config)
    user_id = uuid4()

    pair = service.issue_pair(user_id, ["ADMIN"])

    assert service.decode(pair.access_token, "access").user_id == user_id
    assert service.decode(pair.refresh_token, "refresh").user_id == user_id
    assert len(hash_token(pair.refresh_token)) == 64
    with pytest.raises(TokenError, match="Unexpected token type"):
        service.decode(pair.access_token, "refresh")


def test_jwt_service_rejects_tampered_token():
    service = JwtService(
        Settings(JWT_SECRET_KEY="unit-test-secret-that-is-long-enough")
    )
    token = service.issue_pair(uuid4(), []).access_token

    with pytest.raises(TokenError, match="Invalid or expired"):
        service.decode(f"{token}tampered", "access")
