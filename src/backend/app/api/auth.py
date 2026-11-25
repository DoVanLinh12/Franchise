from uuid import UUID

from fastapi import APIRouter, Request, Response

from app.api.dependencies import AdminUser, CurrentUser
from app.api.schemas import (
    IdResponse,
    LoginRequest,
    MessageResponse,
    PasswordResetConfirmRequest,
    PasswordResetRequest,
    RegisterRequest,
    RoleChangeRequest,
    StatusChangeRequest,
    TokenResponse,
    UserResponse,
)
from app.domain import AccessToken, RegisterUserCommand
from app.services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["Authentication"])


def _client_metadata(request: Request) -> tuple[str | None, str | None]:
    client_ip = request.client.host if request.client else None
    return client_ip, request.headers.get("user-agent")


def _token_response(token: AccessToken) -> TokenResponse:
    return TokenResponse(
        access_token=token.access_token,
        token_type=token.token_type,
        access_expires_at=token.access_expires_at,
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
async def login(payload: LoginRequest) -> TokenResponse:
    token = await AuthService().authenticate(
        payload.email,
        payload.password,
    )
    return _token_response(token)


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
