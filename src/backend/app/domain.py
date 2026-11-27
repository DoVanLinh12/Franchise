from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal
from uuid import UUID


@dataclass(frozen=True, slots=True)
class SubmitApplicationCommand:
    applicant_id: UUID
    applicant_name: str
    email: str
    phone: str
    proposed_store_name: str
    proposed_address: str
    proposed_area: Decimal | None = None
    investment_budget: Decimal | None = None
    note: str | None = None


@dataclass(frozen=True, slots=True)
class CreateDraftContractCommand:
    actor_id: UUID
    application_id: UUID
    contract_no: str
    signed_date: date | None
    effective_from: date
    effective_to: date
    royalty_rate: Decimal
    initial_franchise_fee: Decimal
    deposit_amount: Decimal
    system_fee: Decimal
    service_fee: Decimal


@dataclass(frozen=True, slots=True)
class RegisterUserCommand:
    email: str
    password: str
    full_name: str
    phone: str | None = None


@dataclass(frozen=True, slots=True)
class AccessToken:
    access_token: str
    token_type: str
    access_expires_at: datetime


@dataclass(frozen=True, slots=True)
class TokenClaims:
    user_id: UUID
    token_id: UUID
    expires_at: datetime
