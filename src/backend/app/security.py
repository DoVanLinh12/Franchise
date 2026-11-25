from __future__ import annotations

from datetime import UTC, datetime, timedelta
from hashlib import sha256
from typing import Any
from uuid import UUID, uuid4

import jwt
from pwdlib import PasswordHash
from pwdlib.exceptions import PwdlibError

from app.config import Settings, settings
from app.domain import AccessToken, TokenClaims
from app.exceptions import TokenError


class PasswordService:
    """Argon2 password hashing without exposing its details to services."""

    def __init__(self) -> None:
        self._password_hash = PasswordHash.recommended()
        self._dummy_hash = self._password_hash.hash(
            "dummy-password-used-only-to-equalize-login-timing"
        )

    def hash(self, password: str) -> str:
        return self._password_hash.hash(password)

    def verify(self, password: str, password_hash: str) -> bool:
        try:
            return self._password_hash.verify(password, password_hash)
        except (PwdlibError, TypeError, ValueError):
            return False

    def verify_and_update(
        self, password: str, password_hash: str
    ) -> tuple[bool, str | None]:
        try:
            return self._password_hash.verify_and_update(password, password_hash)
        except (PwdlibError, TypeError, ValueError):
            return False, None

    def consume_dummy_verification(self, password: str) -> None:
        self.verify(password, self._dummy_hash)


class JwtService:
    def __init__(self, config: Settings | None = None) -> None:
        self._config = config or settings

    def issue_access_token(self, user_id: UUID, roles: list[str]) -> AccessToken:
        now = datetime.now(UTC)
        access_id = uuid4()
        access_expires_at = now + timedelta(
            minutes=self._config.ACCESS_TOKEN_EXPIRE_MINUTES
        )

        common: dict[str, Any] = {
            "sub": str(user_id),
            "iat": now,
            "nbf": now,
            "iss": self._config.JWT_ISSUER,
            "aud": self._config.JWT_AUDIENCE,
        }
        access_token = self._encode(
            {
                **common,
                "jti": str(access_id),
                "type": "access",
                "roles": roles,
                "exp": access_expires_at,
            }
        )
        return AccessToken(
            access_token=access_token,
            token_type="bearer",
            access_expires_at=access_expires_at,
            access_token_id=access_id,
        )

    def decode_access_token(self, token: str) -> TokenClaims:
        try:
            payload = jwt.decode(
                token,
                self._config.JWT_SECRET_KEY,
                algorithms=[self._config.JWT_ALGORITHM],
                audience=self._config.JWT_AUDIENCE,
                issuer=self._config.JWT_ISSUER,
                options={
                    "require": [
                        "sub",
                        "jti",
                        "type",
                        "iat",
                        "nbf",
                        "exp",
                        "iss",
                        "aud",
                    ]
                },
            )
            if payload["type"] != "access":
                raise TokenError("Unexpected token type")
            return TokenClaims(
                user_id=UUID(str(payload["sub"])),
                token_id=UUID(str(payload["jti"])),
                expires_at=datetime.fromtimestamp(payload["exp"], tz=UTC),
            )
        except TokenError:
            raise
        except (jwt.PyJWTError, KeyError, TypeError, ValueError) as exc:
            raise TokenError("Invalid or expired token") from exc

    def _encode(self, payload: dict[str, Any]) -> str:
        return jwt.encode(
            payload,
            self._config.JWT_SECRET_KEY,
            algorithm=self._config.JWT_ALGORITHM,
        )


def hash_token(token: str) -> str:
    return sha256(token.encode("utf-8")).hexdigest()
