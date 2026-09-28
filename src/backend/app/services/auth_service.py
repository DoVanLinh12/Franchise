from __future__ import annotations

import re
import secrets
from datetime import UTC, datetime, timedelta
from ipaddress import IPv4Address, IPv6Address, ip_address
from typing import Any
from uuid import UUID, uuid4

from app.config import Settings, settings
from app.database import get_pool
from app.domain import RegisterUserCommand, TokenClaims, TokenPair
from app.exceptions import AuthenticationError, ValidationError
from app.repositories.auth_repository import AuthRepository
from app.security import JwtService, PasswordService, hash_token

EMAIL_PATTERN = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
VALID_USER_STATUSES = {"ACTIVE", "INACTIVE", "LOCKED"}
VALID_ROLE_CODES = {"ADMIN", "STORE_OWNER", "ACCOUNTANT"}


class AuthService:
    def __init__(
        self,
        repository: AuthRepository | None = None,
        password_service: PasswordService | None = None,
        jwt_service: JwtService | None = None,
        config: Settings | None = None,
    ) -> None:
        self._repository = repository or AuthRepository()
        self._passwords = password_service or PasswordService()
        self._config = config or settings
        self._jwt = jwt_service or JwtService(self._config)

    async def register(self, command: RegisterUserCommand) -> UUID:
        self._validate_registration(command)
        user_id = uuid4()
        password_hash = self._passwords.hash(command.password)
        async with get_pool().acquire() as connection:
            async with connection.transaction():
                await self._repository.register(
                    connection,
                    user_id=user_id,
                    email=command.email.lower().strip(),
                    password_hash=password_hash,
                    full_name=command.full_name.strip(),
                    phone=command.phone.strip() if command.phone else None,
                )
        return user_id

    async def authenticate(
        self,
        email: str,
        password: str,
        *,
        client_ip: str | None = None,
        user_agent: str | None = None,
    ) -> TokenPair:
        normalized_email = email.lower().strip()
        async with get_pool().acquire() as connection:
            user = await self._repository.get_auth_by_email(
                connection, normalized_email
            )
            if user is None:
                self._passwords.consume_dummy_verification(password)
                raise AuthenticationError("Email or password is incorrect")

            now = datetime.now(UTC)
            is_available = (
                user["status"] == "ACTIVE"
                and user["deleted_at"] is None
                and (
                    user["locked_until"] is None
                    or user["locked_until"] <= now
                )
            )
            verified, updated_hash = self._passwords.verify_and_update(
                password, user["password_hash"]
            )
            if not is_available or not verified:
                is_temporarily_locked = (
                    user["locked_until"] is not None
                    and user["locked_until"] > now
                )
                if user["status"] == "ACTIVE" and not is_temporarily_locked:
                    async with connection.transaction():
                        await self._repository.record_login_failure(
                            connection,
                            normalized_email,
                            self._config.MAX_LOGIN_ATTEMPTS,
                            self._config.LOGIN_LOCK_MINUTES,
                        )
                raise AuthenticationError("Email or password is incorrect")

            user_id = UUID(str(user["id"]))
            roles = await self._repository.get_roles(connection, user_id)
            pair = self._jwt.issue_pair(user_id, roles)
            async with connection.transaction():
                if updated_hash is not None:
                    await self._repository.update_password_hash(
                        connection, user_id, updated_hash
                    )
                await self._repository.record_login_success(connection, user_id)
                await self._repository.store_refresh_token(
                    connection,
                    token_id=pair.refresh_token_id,
                    user_id=user_id,
                    token_hash=hash_token(pair.refresh_token),
                    expires_at=pair.refresh_expires_at,
                    ip_address=self._parse_ip(client_ip),
                    user_agent=user_agent,
                )
            return pair

    async def refresh(
        self,
        refresh_token: str,
        *,
        client_ip: str | None = None,
        user_agent: str | None = None,
    ) -> TokenPair:
        claims = self._jwt.decode(refresh_token, "refresh")
        async with get_pool().acquire() as connection:
            roles = await self._repository.get_roles(
                connection, claims.user_id
            )
            pair = self._jwt.issue_pair(claims.user_id, roles)
            async with connection.transaction():
                await self._repository.rotate_refresh_token(
                    connection,
                    old_token_hash=hash_token(refresh_token),
                    user_id=claims.user_id,
                    new_token_id=pair.refresh_token_id,
                    new_token_hash=hash_token(pair.refresh_token),
                    new_expires_at=pair.refresh_expires_at,
                    ip_address=self._parse_ip(client_ip),
                    user_agent=user_agent,
                )
        return pair

    async def logout(self, refresh_token: str) -> None:
        claims = self._jwt.decode(refresh_token, "refresh")
        async with get_pool().acquire() as connection:
            async with connection.transaction():
                await self._repository.revoke_refresh_token(
                    connection,
                    hash_token(refresh_token),
                    claims.user_id,
                    "LOGOUT",
                )

    def verify_access_token(self, access_token: str) -> TokenClaims:
        return self._jwt.decode(access_token, "access")

    async def request_password_reset(
        self, email: str, *, client_ip: str | None = None
    ) -> str | None:
        """Return a one-time token for the future mail job, or None silently."""
        async with get_pool().acquire() as connection:
            user = await self._repository.get_auth_by_email(
                connection, email.lower().strip()
            )
            if user is None or user["status"] != "ACTIVE":
                return None

            raw_token = secrets.token_urlsafe(32)
            expires_at = datetime.now(UTC) + timedelta(
                minutes=self._config.PASSWORD_RESET_EXPIRE_MINUTES
            )
            async with connection.transaction():
                await self._repository.create_password_reset_token(
                    connection,
                    token_id=uuid4(),
                    user_id=UUID(str(user["id"])),
                    token_hash=hash_token(raw_token),
                    expires_at=expires_at,
                    ip_address=self._parse_ip(client_ip),
                )
            return raw_token

    async def reset_password(self, token: str, new_password: str) -> None:
        self._validate_password(new_password)
        new_hash = self._passwords.hash(new_password)
        async with get_pool().acquire() as connection:
            async with connection.transaction():
                await self._repository.reset_password(
                    connection, hash_token(token), new_hash
                )

    async def get_user(self, user_id: UUID) -> dict[str, Any] | None:
        async with get_pool().acquire() as connection:
            user = await self._repository.get_user(connection, user_id)
            if user is not None:
                user["roles"] = await self._repository.get_roles(
                    connection, user_id
                )
            return user

    async def change_user_status(
        self,
        user_id: UUID,
        actor_id: UUID,
        new_status: str,
        reason: str,
    ) -> None:
        status = new_status.upper().strip()
        if status not in VALID_USER_STATUSES:
            raise ValidationError("Invalid user status")
        if not reason.strip():
            raise ValidationError("Status change reason is required")
        async with get_pool().acquire() as connection:
            async with connection.transaction():
                await self._repository.change_user_status(
                    connection, user_id, actor_id, status, reason.strip()
                )

    async def assign_role(
        self, user_id: UUID, role_code: str, actor_id: UUID
    ) -> None:
        role = self._validate_role(role_code)
        async with get_pool().acquire() as connection:
            async with connection.transaction():
                await self._repository.assign_role(
                    connection, user_id, role, actor_id
                )

    async def remove_role(
        self, user_id: UUID, role_code: str, actor_id: UUID
    ) -> None:
        role = self._validate_role(role_code)
        async with get_pool().acquire() as connection:
            async with connection.transaction():
                await self._repository.remove_role(
                    connection, user_id, role, actor_id
                )

    @staticmethod
    def _validate_registration(command: RegisterUserCommand) -> None:
        if not EMAIL_PATTERN.fullmatch(command.email.strip()):
            raise ValidationError("Invalid email address")
        if not command.full_name.strip():
            raise ValidationError("Full name is required")
        AuthService._validate_password(command.password)

    @staticmethod
    def _validate_password(password: str) -> None:
        if len(password) < 8:
            raise ValidationError("Password must contain at least 8 characters")
        if len(password) > 128:
            raise ValidationError("Password must not exceed 128 characters")

    @staticmethod
    def _validate_role(role_code: str) -> str:
        role = role_code.upper().strip()
        if role not in VALID_ROLE_CODES:
            raise ValidationError("Invalid role code")
        return role

    @staticmethod
    def _parse_ip(value: str | None) -> IPv4Address | IPv6Address | None:
        if value is None:
            return None
        try:
            return ip_address(value)
        except ValueError as exc:
            raise ValidationError("Invalid client IP address") from exc
