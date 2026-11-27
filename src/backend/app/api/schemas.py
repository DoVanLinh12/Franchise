from datetime import date, datetime
from decimal import Decimal
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class RegisterRequest(BaseModel):
    email: str = Field(min_length=3, max_length=320)
    password: str = Field(min_length=8, max_length=128)
    full_name: str = Field(min_length=1, max_length=200)
    phone: str | None = Field(default=None, max_length=30)


class LoginRequest(BaseModel):
    email: str
    password: str


class PasswordResetRequest(BaseModel):
    email: str


class PasswordResetConfirmRequest(BaseModel):
    token: str
    new_password: str = Field(min_length=8, max_length=128)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    access_expires_at: datetime


class UserResponse(BaseModel):
    model_config = ConfigDict(extra="allow")

    id: UUID
    email: str
    full_name: str
    phone: str | None
    status: str
    roles: list[str] = Field(default_factory=list)


class StatusChangeRequest(BaseModel):
    status: str
    reason: str = Field(min_length=1, max_length=500)


class RoleChangeRequest(BaseModel):
    role: str


class MessageResponse(BaseModel):
    message: str


class IdResponse(BaseModel):
    id: UUID


class PageResponse(BaseModel):
    items: list[dict[str, Any]]
    total: int
    page: int
    page_size: int


class ApplicationCreateRequest(BaseModel):
    applicant_name: str
    email: str
    phone: str
    proposed_store_name: str
    proposed_address: str
    proposed_area: Decimal | None = None
    investment_budget: Decimal | None = None
    note: str | None = None


class ReasonRequest(BaseModel):
    reason: str = Field(min_length=1, max_length=1000)


class ReviewRequest(BaseModel):
    note: str | None = Field(default=None, max_length=1000)


class ContractCreateRequest(BaseModel):
    application_id: UUID
    contract_no: str
    signed_date: date | None = None
    effective_from: date
    effective_to: date
    royalty_rate: Decimal
    initial_franchise_fee: Decimal
    deposit_amount: Decimal
    system_fee: Decimal
    service_fee: Decimal


class ContractTransactionRequest(BaseModel):
    transaction_type: str
    amount: Decimal = Field(gt=0)
    transaction_date: date
    reference_no: str | None = None
    note: str | None = None


class PromotionCreateRequest(BaseModel):
    name: str
    description: str | None = None
    discount_type: str
    discount_value: Decimal
    start_date: date
    end_date: date
    scope: str
    store_ids: list[UUID] = Field(default_factory=list)


class PromotionDetailRequest(BaseModel):
    promotion_id: UUID
    discount_amount: Decimal = Field(ge=0)


class RevenueSaveRequest(BaseModel):
    store_id: UUID
    business_date: date
    gross_revenue: Decimal = Field(ge=0)
    note: str | None = None
    promotion_details: list[PromotionDetailRequest] = Field(
        default_factory=list
    )


class RevenueReviewRequest(BaseModel):
    note: str | None = None


class BillingAdjustmentRequest(BaseModel):
    source_period: date | None = None
    amount: Decimal
    reason: str = Field(min_length=1)


class InvoiceGenerateRequest(BaseModel):
    store_id: UUID
    invoice_no: str
    period_month: date
    vat_rate: Decimal = Field(ge=0, le=100)


class PaymentCreateRequest(BaseModel):
    payment_no: str
    amount: Decimal = Field(gt=0)
    payment_date: date
    method: str
    reference_no: str | None = None
