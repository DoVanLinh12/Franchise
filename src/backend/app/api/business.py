from datetime import date
from typing import Any
from uuid import UUID

from fastapi import APIRouter, Query, Response

from app.api.dependencies import AccountantUser, AdminUser, CurrentUser
from app.api.schemas import (
    ApplicationCreateRequest,
    BillingAdjustmentRequest,
    ContractCreateRequest,
    ContractTransactionRequest,
    IdResponse,
    InvoiceGenerateRequest,
    PageResponse,
    PaymentCreateRequest,
    PromotionCreateRequest,
    ReasonRequest,
    RevenueReviewRequest,
    RevenueSaveRequest,
    ReviewRequest,
)
from app.domain import (
    CreateDraftContractCommand,
    SubmitApplicationCommand,
)
from app.services.application_service import ApplicationService
from app.services.contract_service import ContractService
from app.services.operations_service import OperationsService

router = APIRouter(tags=["Business"])


def _user_id(user: dict[str, Any]) -> UUID:
    return UUID(str(user["id"]))


async def _page(
    entity: str,
    user: dict[str, Any],
    search: str | None,
    status: str | None,
    page: int,
    page_size: int,
) -> PageResponse:
    items, total = await OperationsService().list_records(
        entity, _user_id(user), search, status, page, page_size
    )
    return PageResponse(
        items=items, total=total, page=page, page_size=page_size
    )


@router.post("/applications", response_model=IdResponse, status_code=201)
async def create_application(
    payload: ApplicationCreateRequest, user: CurrentUser
) -> IdResponse:
    identifier = await ApplicationService().submit(
        SubmitApplicationCommand(
            applicant_id=_user_id(user), **payload.model_dump()
        )
    )
    return IdResponse(id=identifier)


@router.get("/applications", response_model=PageResponse)
async def list_applications(
    user: CurrentUser,
    search: str | None = None,
    status: str | None = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=200),
) -> PageResponse:
    return await _page(
        "applications", user, search, status, page, page_size
    )


@router.post("/applications/{application_id}/withdraw", status_code=204)
async def withdraw_application(
    application_id: UUID, payload: ReasonRequest, user: CurrentUser
) -> Response:
    await ApplicationService().withdraw(
        application_id, _user_id(user), payload.reason
    )
    return Response(status_code=204)


@router.post("/applications/{application_id}/start-review", status_code=204)
async def start_application_review(
    application_id: UUID, admin: AdminUser
) -> Response:
    await ApplicationService().start_review(application_id, _user_id(admin))
    return Response(status_code=204)


@router.post("/applications/{application_id}/approve", status_code=204)
async def approve_application(
    application_id: UUID, payload: ReviewRequest, admin: AdminUser
) -> Response:
    await ApplicationService().approve(
        application_id, _user_id(admin), payload.note
    )
    return Response(status_code=204)


@router.post("/applications/{application_id}/reject", status_code=204)
async def reject_application(
    application_id: UUID, payload: ReasonRequest, admin: AdminUser
) -> Response:
    await ApplicationService().reject(
        application_id, _user_id(admin), payload.reason
    )
    return Response(status_code=204)


@router.get("/stores", response_model=PageResponse)
async def list_stores(
    user: CurrentUser,
    search: str | None = None,
    status: str | None = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=200),
) -> PageResponse:
    return await _page("stores", user, search, status, page, page_size)


@router.post("/contracts", response_model=IdResponse, status_code=201)
async def create_contract(
    payload: ContractCreateRequest, admin: AdminUser
) -> IdResponse:
    identifier = await ContractService().create_draft(
        CreateDraftContractCommand(
            actor_id=_user_id(admin), **payload.model_dump()
        )
    )
    return IdResponse(id=identifier)


@router.get("/contracts", response_model=PageResponse)
async def list_contracts(
    user: CurrentUser,
    search: str | None = None,
    status: str | None = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=200),
) -> PageResponse:
    return await _page("contracts", user, search, status, page, page_size)


@router.post(
    "/contracts/{contract_id}/financial-transactions",
    response_model=IdResponse,
    status_code=201,
)
async def record_contract_transaction(
    contract_id: UUID,
    payload: ContractTransactionRequest,
    admin: AdminUser,
) -> IdResponse:
    identifier = await OperationsService().record_contract_transaction(
        contract_id, _user_id(admin), payload.model_dump()
    )
    return IdResponse(id=identifier)


@router.post("/contracts/{contract_id}/activate", status_code=204)
async def activate_contract(
    contract_id: UUID, admin: AdminUser
) -> Response:
    await OperationsService().activate_contract(contract_id, _user_id(admin))
    return Response(status_code=204)


@router.post("/promotions", response_model=IdResponse, status_code=201)
async def create_promotion(
    payload: PromotionCreateRequest, admin: AdminUser
) -> IdResponse:
    identifier = await OperationsService().create_promotion(
        _user_id(admin), payload.model_dump()
    )
    return IdResponse(id=identifier)


@router.get("/promotions", response_model=PageResponse)
async def list_promotions(
    user: CurrentUser,
    search: str | None = None,
    status: str | None = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=200),
) -> PageResponse:
    return await _page("promotions", user, search, status, page, page_size)


@router.post("/promotions/{promotion_id}/activate", status_code=204)
async def activate_promotion(
    promotion_id: UUID, admin: AdminUser
) -> Response:
    await OperationsService().change_promotion_status(
        promotion_id, _user_id(admin), "ACTIVE", None
    )
    return Response(status_code=204)


@router.post("/promotions/{promotion_id}/cancel", status_code=204)
async def cancel_promotion(
    promotion_id: UUID, payload: ReasonRequest, admin: AdminUser
) -> Response:
    await OperationsService().change_promotion_status(
        promotion_id, _user_id(admin), "CANCELLED", payload.reason
    )
    return Response(status_code=204)


@router.delete("/promotions/{promotion_id}", status_code=204)
async def delete_promotion(
    promotion_id: UUID, payload: ReasonRequest, admin: AdminUser
) -> Response:
    await OperationsService().soft_delete_promotion(
        promotion_id, _user_id(admin), payload.reason
    )
    return Response(status_code=204)


@router.post("/revenues", response_model=IdResponse, status_code=201)
async def create_revenue(
    payload: RevenueSaveRequest, user: CurrentUser
) -> IdResponse:
    values = payload.model_dump()
    store_id = values.pop("store_id")
    identifier = await OperationsService().save_revenue(
        None, store_id, _user_id(user), values
    )
    return IdResponse(id=identifier)


@router.put("/revenues/{revenue_id}", response_model=IdResponse)
async def update_revenue(
    revenue_id: UUID, payload: RevenueSaveRequest, user: CurrentUser
) -> IdResponse:
    values = payload.model_dump()
    store_id = values.pop("store_id")
    identifier = await OperationsService().save_revenue(
        revenue_id, store_id, _user_id(user), values
    )
    return IdResponse(id=identifier)


@router.get("/revenues", response_model=PageResponse)
async def list_revenues(
    user: CurrentUser,
    status: str | None = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=200),
) -> PageResponse:
    return await _page("revenues", user, None, status, page, page_size)


@router.post("/revenues/{revenue_id}/submit", status_code=204)
async def submit_revenue(revenue_id: UUID, user: CurrentUser) -> Response:
    await OperationsService().submit_revenue(revenue_id, _user_id(user))
    return Response(status_code=204)


@router.post("/revenues/{revenue_id}/approve", status_code=204)
async def approve_revenue(
    revenue_id: UUID,
    payload: RevenueReviewRequest,
    accountant: AccountantUser,
) -> Response:
    await OperationsService().review_revenue(
        revenue_id, _user_id(accountant), "APPROVED", payload.note
    )
    return Response(status_code=204)


@router.post("/revenues/{revenue_id}/reject", status_code=204)
async def reject_revenue(
    revenue_id: UUID, payload: ReasonRequest, accountant: AccountantUser
) -> Response:
    await OperationsService().review_revenue(
        revenue_id, _user_id(accountant), "REJECTED", payload.reason
    )
    return Response(status_code=204)


@router.post("/revenues/{revenue_id}/request-adjustment", status_code=204)
async def request_revenue_adjustment(
    revenue_id: UUID, payload: ReasonRequest, accountant: AccountantUser
) -> Response:
    await OperationsService().request_revenue_adjustment(
        revenue_id, _user_id(accountant), payload.reason
    )
    return Response(status_code=204)


@router.post("/billing-adjustments", response_model=IdResponse, status_code=201)
async def create_billing_adjustment(
    store_id: UUID,
    payload: BillingAdjustmentRequest,
    accountant: AccountantUser,
) -> IdResponse:
    identifier = await OperationsService().create_adjustment(
        store_id, _user_id(accountant), payload.model_dump()
    )
    return IdResponse(id=identifier)


@router.post("/invoices/generate", response_model=IdResponse, status_code=201)
async def generate_invoice(
    payload: InvoiceGenerateRequest, accountant: AccountantUser
) -> IdResponse:
    values = payload.model_dump()
    store_id = values.pop("store_id")
    identifier = await OperationsService().generate_invoice(
        store_id, _user_id(accountant), values
    )
    return IdResponse(id=identifier)


@router.get("/invoices", response_model=PageResponse)
async def list_invoices(
    user: CurrentUser,
    search: str | None = None,
    status: str | None = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=200),
) -> PageResponse:
    return await _page("invoices", user, search, status, page, page_size)


@router.post("/invoices/{invoice_id}/issue", status_code=204)
async def issue_invoice(
    invoice_id: UUID, accountant: AccountantUser
) -> Response:
    await OperationsService().issue_invoice(invoice_id, _user_id(accountant))
    return Response(status_code=204)


@router.post("/invoices/{invoice_id}/cancel", status_code=204)
async def cancel_invoice(
    invoice_id: UUID, payload: ReasonRequest, accountant: AccountantUser
) -> Response:
    await OperationsService().cancel_invoice(
        invoice_id, _user_id(accountant), payload.reason
    )
    return Response(status_code=204)


@router.post(
    "/invoices/{invoice_id}/payments",
    response_model=IdResponse,
    status_code=201,
)
async def record_payment(
    invoice_id: UUID,
    payload: PaymentCreateRequest,
    accountant: AccountantUser,
) -> IdResponse:
    identifier = await OperationsService().record_payment(
        invoice_id, _user_id(accountant), payload.model_dump()
    )
    return IdResponse(id=identifier)


@router.get("/payments", response_model=PageResponse)
async def list_payments(
    user: CurrentUser,
    search: str | None = None,
    status: str | None = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=200),
) -> PageResponse:
    return await _page("payments", user, search, status, page, page_size)


@router.post("/payments/{payment_id}/reverse", status_code=204)
async def reverse_payment(
    payment_id: UUID, payload: ReasonRequest, accountant: AccountantUser
) -> Response:
    await OperationsService().reverse_payment(
        payment_id, _user_id(accountant), payload.reason
    )
    return Response(status_code=204)


@router.get("/notifications", response_model=PageResponse)
async def list_notifications(
    user: CurrentUser,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=200),
) -> PageResponse:
    return await _page("notifications", user, None, None, page, page_size)


@router.patch("/notifications/{notification_id}/read", status_code=204)
async def mark_notification_read(
    notification_id: UUID, user: CurrentUser
) -> Response:
    await OperationsService().mark_notification_read(
        notification_id, _user_id(user)
    )
    return Response(status_code=204)


@router.post("/operations/generate-alerts", status_code=204)
async def generate_alerts(admin: AdminUser) -> Response:
    await OperationsService().generate_alerts()
    return Response(status_code=204)


@router.get("/audit-logs", response_model=PageResponse)
async def list_audit_logs(
    admin: AdminUser,
    search: str | None = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=200),
) -> PageResponse:
    return await _page("audit_logs", admin, search, None, page, page_size)


@router.get("/reports/financial-summary")
async def financial_summary(
    period_from: date, period_to: date, user: CurrentUser
) -> list[dict[str, Any]]:
    return await OperationsService().financial_summary(
        _user_id(user), period_from, period_to
    )
