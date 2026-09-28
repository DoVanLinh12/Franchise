from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Request, Response, status
from fastapi.security import OAuth2PasswordRequestForm

from app.api.dependencies import AdminUser, CurrentUser
from app.api.schemas import (
    IdResponse,
    LoginRequest,
    MessageResponse,
    PasswordResetConfirmRequest,
    PasswordResetRequest,
    RefreshRequest,
    RegisterRequest,
    RoleChangeRequest,
    StatusChangeRequest,
    TokenResponse,
    UserResponse,
)
from app.domain import RegisterUserCommand, TokenPair
from app.services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["Authentication"])


def _client_metadata(request: Request) -> tuple[str | None, str | None]:
    client_ip = request.client.host if request.client else None
    return client_ip, request.headers.get("user-agent")


def _token_response(pair: TokenPair) -> TokenResponse:
    return TokenResponse(
        access_token=pair.access_token,
        refresh_token=pair.refresh_token,
        token_type=pair.token_type,
        access_expires_at=pair.access_expires_at,
        refresh_expires_at=pair.refresh_expires_at,
    )


@router.post("/register", response_model=IdResponse, status_code=201)
async def register(payload: RegisterRequest) -> IdResponse:
    user_id = await AuthService().register(
        RegisterUserCommand(
            email=payload.email,
            password=payload.password,
            full_name=payload.full_name,
            phone=payload.phone,
        )
    )
    return IdResponse(id=user_id)


@router.post("/login", response_model=TokenResponse)
async def login(payload: LoginRequest, request: Request) -> TokenResponse:
    client_ip, user_agent = _client_metadata(request)
    pair = await AuthService().authenticate(
        payload.email,
        payload.password,
        client_ip=client_ip,
        user_agent=user_agent,
    )
    return _token_response(pair)


@router.post("/token", response_model=TokenResponse)
async def oauth2_token(
    form: Annotated[OAuth2PasswordRequestForm, Depends()], request: Request
) -> TokenResponse:
    client_ip, user_agent = _client_metadata(request)
    pair = await AuthService().authenticate(
        form.username,
        form.password,
        client_ip=client_ip,
        user_agent=user_agent,
    )
    return _token_response(pair)


@router.post("/refresh", response_model=TokenResponse)
async def refresh(payload: RefreshRequest, request: Request) -> TokenResponse:
    client_ip, user_agent = _client_metadata(request)
    pair = await AuthService().refresh(
        payload.refresh_token,
        client_ip=client_ip,
        user_agent=user_agent,
    )
    return _token_response(pair)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(payload: RefreshRequest) -> Response:
    await AuthService().logout(payload.refresh_token)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/password-reset/request", response_model=MessageResponse)
async def request_password_reset(
    payload: PasswordResetRequest, request: Request
) -> MessageResponse:
    client_ip, _ = _client_metadata(request)
    token = await AuthService().request_password_reset(
        payload.email, client_ip=client_ip
    )
    if token is not None:
        from app.celery_app import send_email

        send_email.delay(
            payload.email,
            "Franchise password reset",
            f"Your one-time password reset token is: {token}",
        )
    return MessageResponse(
        message="If the account exists, reset instructions will be sent"
    )


@router.post("/password-reset/confirm", response_model=MessageResponse)
async def confirm_password_reset(
    payload: PasswordResetConfirmRequest,
) -> MessageResponse:
    await AuthService().reset_password(payload.token, payload.new_password)
    return MessageResponse(message="Password has been reset")


@router.get("/me", response_model=UserResponse)
async def me(user: CurrentUser) -> dict:
    return user


@router.patch("/users/{user_id}/status", status_code=204)
async def change_status(
    user_id: UUID,
    payload: StatusChangeRequest,
    admin: AdminUser,
) -> Response:
    await AuthService().change_user_status(
        user_id, UUID(str(admin["id"])), payload.status, payload.reason
    )
    return Response(status_code=204)


@router.post("/users/{user_id}/roles", status_code=204)
async def assign_role(
    user_id: UUID, payload: RoleChangeRequest, admin: AdminUser
) -> Response:
    await AuthService().assign_role(
        user_id, payload.role, UUID(str(admin["id"]))
    )
    return Response(status_code=204)


@router.delete("/users/{user_id}/roles/{role_code}", status_code=204)
async def remove_role(
    user_id: UUID, role_code: str, admin: AdminUser
) -> Response:
    await AuthService().remove_role(
        user_id, role_code, UUID(str(admin["id"]))
    )
    return Response(status_code=204)
