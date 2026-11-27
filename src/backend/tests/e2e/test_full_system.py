"""End-to-end tests that call every API endpoint of a running stack.

Run against Docker Compose (default http://localhost:8000):

    E2E_BASE_URL=http://localhost:8000 pytest -m e2e tests/e2e -v

The module is skipped when the API is not reachable, so the normal unit test
run (and the CI backend job) is unaffected. Tests run in file order and share
state through ``S``; each run uses a unique suffix so it can be repeated.
"""

from __future__ import annotations

import csv
import io
import os
import quopri
import re
import time
import uuid
from datetime import date, datetime, timedelta, timezone
from typing import Any

import httpx
import pytest

BASE_URL = os.environ.get("E2E_BASE_URL", "http://localhost:8000").rstrip("/")
MAILHOG_URL = os.environ.get("E2E_MAILHOG_URL", "http://localhost:8025").rstrip("/")
API = f"{BASE_URL}/api/v1"
PASSWORD = "Admin@123"
RUN = uuid.uuid4().hex[:10]
# Business dates follow Vietnam time (UTC+7), like the database.
TODAY = datetime.now(timezone(timedelta(hours=7))).date()
MONTH_START = TODAY.replace(day=1)


def _api_up() -> bool:
    try:
        return httpx.get(f"{BASE_URL}/health", timeout=3).status_code == 200
    except httpx.HTTPError:
        return False


pytestmark = [
    pytest.mark.e2e,
    pytest.mark.skipif(not _api_up(), reason=f"API not reachable at {BASE_URL}"),
]

S: dict[str, Any] = {}
_http = httpx.Client(timeout=30)


def call(method: str, path: str, token: str | None = None, **kwargs: Any) -> httpx.Response:
    """HTTP call that waits out the API rate limit (429) instead of failing."""
    url = path if path.startswith("http") else f"{API}{path}"
    headers = kwargs.pop("headers", {})
    if token:
        headers["Authorization"] = f"Bearer {token}"
    for _ in range(5):
        response = _http.request(method, url, headers=headers, **kwargs)
        if response.status_code != 429:
            return response
        time.sleep(int(response.headers.get("Retry-After", "60")) + 1)
    return response


def ok(response: httpx.Response, status: int = 200) -> Any:
    assert response.status_code == status, f"{response.status_code}: {response.text}"
    if response.headers.get("content-type", "").startswith("application/json"):
        return response.json()
    return response


def fails(response: httpx.Response, status: int, detail: str | None = None) -> None:
    assert response.status_code == status, f"{response.status_code}: {response.text}"
    if detail:
        assert detail in response.text, response.text


def login(email: str, password: str = PASSWORD) -> str:
    body = ok(call("POST", "/auth/login", json={"email": email, "password": password}))
    return body["access_token"]


def find(path: str, token: str, item_id: str, **params: Any) -> dict[str, Any]:
    params.setdefault("page_size", 200)
    items = ok(call("GET", path, token, params=params))["items"]
    match = [item for item in items if str(item["id"]) == str(item_id)]
    assert match, f"{item_id} not found in {path}"
    return match[0]


def register(prefix: str) -> tuple[str, str]:
    email = f"{prefix}.{RUN}@e2e.local"
    body = ok(call("POST", "/auth/register", json={
        "email": email, "password": PASSWORD,
        "full_name": f"E2E {prefix}", "phone": "0900000000",
    }), 201)
    return email, body["id"]


def application_body(email: str, name: str) -> dict[str, Any]:
    return {
        "applicant_name": f"E2E {name}", "email": email, "phone": "0911222333",
        "proposed_store_name": f"Mộc Miên E2E {name} {RUN}",
        "proposed_address": f"{RUN} Đường Thử Nghiệm, Hà Nội",
        "proposed_area": 80, "investment_budget": 1500000000, "note": "E2E",
    }


# --------------------------------------------------------------------- system
def test_health_endpoints():
    assert ok(call("GET", f"{BASE_URL}/health"))
    assert ok(call("GET", f"{BASE_URL}/health/ready"))


def test_openapi_lists_all_routes():
    paths = ok(call("GET", f"{BASE_URL}/openapi.json"))["paths"]
    operations = sum(len(methods) for methods in paths.values())
    assert operations >= 49  # 51 including the two health checks


def test_cors_allows_frontend_origin():
    response = call("OPTIONS", "/stores", headers={
        "Origin": "http://localhost:3000",
        "Access-Control-Request-Method": "GET",
    })
    assert response.headers.get("access-control-allow-origin") == "http://localhost:3000"


def test_request_id_header_is_returned():
    response = call("GET", f"{BASE_URL}/health")
    assert any(key.lower() == "x-request-id" for key in response.headers)


# ------------------------------------------------------------- authentication
def test_login_seed_accounts():
    S["admin"] = login("admin@franchise.local")
    S["accountant"] = login("accountant@franchise.local")
    me = ok(call("GET", "/auth/me", S["admin"]))
    assert "ADMIN" in me["roles"]
    S["admin_id"] = me["id"]


def test_login_rejects_wrong_password():
    response = call("POST", "/auth/login", json={
        "email": "admin@franchise.local", "password": "wrong-password"})
    fails(response, 401, "incorrect")


def test_protected_routes_require_token():
    fails(call("GET", "/stores"), 401)
    fails(call("GET", "/stores", "not-a-jwt"), 401)


def test_register_validation():
    fails(call("POST", "/auth/register", json={
        "email": f"weak.{RUN}@e2e.local", "password": "123", "full_name": "Weak"}), 422)
    fails(call("POST", "/auth/register", json={
        "email": "not-an-email", "password": PASSWORD, "full_name": "Bad"}), 422)


def test_register_owner_and_duplicate_email():
    S["owner_email"], S["owner_id"] = register("owner")
    response = call("POST", "/auth/register", json={
        "email": S["owner_email"], "password": PASSWORD, "full_name": "Dup"})
    assert response.status_code in (400, 409), response.text
    S["owner"] = login(S["owner_email"])
    me = ok(call("GET", "/auth/me", S["owner"]))
    assert me["roles"] == []


# --------------------------------------------------------- applications flow
def test_owner_submits_application():
    body = application_body(S["owner_email"], "Owner")
    S["app_id"] = ok(call("POST", "/applications", S["owner"], json=body), 201)["id"]
    item = find("/applications", S["owner"], S["app_id"])
    assert item["status"] == "PENDING"


def test_second_open_application_is_rejected():
    body = application_body(S["owner_email"], "Again")
    fails(call("POST", "/applications", S["owner"], json=body), 409,
          "OPEN_APPLICATION_ALREADY_EXISTS")


def test_owner_cannot_review_application():
    fails(call("POST", f"/applications/{S['app_id']}/start-review", S["owner"]), 403)


def test_admin_reviews_and_approves_application():
    ok(call("POST", f"/applications/{S['app_id']}/start-review", S["admin"]), 204)
    assert find("/applications", S["admin"], S["app_id"])["status"] == "UNDER_REVIEW"
    ok(call("POST", f"/applications/{S['app_id']}/approve", S["admin"],
            json={"note": "E2E approved"}), 204)
    assert find("/applications", S["admin"], S["app_id"])["status"] == "APPROVED"


def test_admin_assigns_store_owner_role():
    ok(call("POST", f"/auth/users/{S['owner_id']}/roles", S["admin"],
            json={"role": "STORE_OWNER"}), 204)
    me = ok(call("GET", "/auth/me", S["owner"]))
    assert "STORE_OWNER" in me["roles"]


def test_reject_and_withdraw_flows():
    email, user_id = register("rejected")
    S["other_email"], S["other_id"] = email, user_id
    token = login(email)
    app_id = ok(call("POST", "/applications", token,
                     json=application_body(email, "Reject")), 201)["id"]
    ok(call("POST", f"/applications/{app_id}/start-review", S["admin"]), 204)
    fails(call("POST", f"/applications/{app_id}/reject", S["admin"],
               json={"reason": ""}), 422)
    ok(call("POST", f"/applications/{app_id}/reject", S["admin"],
            json={"reason": "Địa điểm không phù hợp"}), 204)
    assert find("/applications", S["admin"], app_id)["status"] == "REJECTED"

    second = ok(call("POST", "/applications", token,
                     json=application_body(email, "Withdraw")), 201)["id"]
    fails(call("POST", f"/applications/{second}/withdraw", S["owner"],
               json={"reason": "not mine"}), 409, "APPLICATION_OWNERSHIP_REQUIRED")
    ok(call("POST", f"/applications/{second}/withdraw", token,
            json={"reason": "Đổi kế hoạch"}), 204)
    assert find("/applications", S["admin"], second)["status"] == "WITHDRAWN"


def test_application_search_and_pagination():
    page = ok(call("GET", "/applications", S["admin"],
                   params={"search": RUN, "page": 1, "page_size": 2}))
    assert page["page_size"] == 2 and page["total"] >= 3
    assert len(page["items"]) <= 2
    fails(call("GET", "/applications", S["admin"], params={"page": 0}), 422)


# ----------------------------------------------------------- contract -> store
def contract_body(**extra: Any) -> dict[str, Any]:
    body = {
        "application_id": S["app_id"], "contract_no": f"E2E-HD-{RUN}",
        "signed_date": TODAY.isoformat(), "effective_from": MONTH_START.isoformat(),
        "effective_to": (MONTH_START + timedelta(days=365)).isoformat(),
        "royalty_rate": 5, "initial_franchise_fee": 100000000,
        "deposit_amount": 20000000, "system_fee": 1000000, "service_fee": 2000000,
    }
    body.update(extra)
    return body


def test_manual_store_creation_endpoint_is_removed():
    fails(call("POST", "/stores", S["admin"], json={}), 405)


def test_contract_creates_store_automatically():
    fails(call("POST", "/contracts", S["owner"], json=contract_body()), 403)
    assert ok(call("GET", "/stores", S["owner"]))["total"] == 0
    S["contract_id"] = ok(call("POST", "/contracts", S["admin"], json=contract_body()), 201)["id"]
    contract = find("/contracts", S["admin"], S["contract_id"])
    assert contract["status"] == "DRAFT" and contract["store_id"]
    stores = ok(call("GET", "/stores", S["owner"], params={"page_size": 200}))["items"]
    assert [item["id"] for item in stores] == [contract["store_id"]]
    store = stores[0]
    # Nothing typed in: code generated, name/address taken from the application.
    assert re.fullmatch(r"CH\d{4}", store["code"])
    assert store["name"] == f"Mộc Miên E2E Owner {RUN}"
    assert store["address"] == f"{RUN} Đường Thử Nghiệm, Hà Nội"
    assert store["status"] == "INACTIVE" and store["activated_at"] is None
    assert store["owner_id"] == S["owner_id"]
    S["store_id"], S["store_code"] = store["id"], store["code"]
    assert find("/applications", S["admin"], S["app_id"])["converted_at"]
    fails(call("POST", "/contracts", S["admin"], json=contract_body(contract_no=f"E2E-HD2-{RUN}")),
          409, "CONTRACT_ALREADY_EXISTS_FOR_APPLICATION")


def test_store_cannot_report_revenue_before_activation():
    fails(call("POST", "/revenues", S["owner"], json={
        "store_id": S["store_id"], "business_date": TODAY.isoformat(),
        "gross_revenue": 1000000, "promotion_details": []}), 400, "STORE_NOT_ACTIVE")
    response = call("GET", f"/contracts/{S['contract_id']}/pdf", S["owner"])
    assert response.status_code == 200 and response.content.startswith(b"%PDF")


def test_contract_activation_requires_20_percent_initial_fee():
    ok(call("POST", f"/contracts/{S['contract_id']}/financial-transactions", S["admin"], json={
        "transaction_type": "INITIAL_FEE_PAYMENT", "amount": 10000000,
        "transaction_date": TODAY.isoformat(), "reference_no": f"BANK-{RUN}-1"}), 201)
    fails(call("POST", f"/contracts/{S['contract_id']}/activate", S["admin"]), 409,
          "INITIAL_FEE_20_PERCENT_REQUIRED")
    fails(call("POST", f"/contracts/{S['contract_id']}/financial-transactions", S["admin"],
               json={"transaction_type": "INITIAL_FEE_PAYMENT", "amount": 0,
                     "transaction_date": TODAY.isoformat()}), 422)


def test_contract_activation_activates_store():
    ok(call("POST", f"/contracts/{S['contract_id']}/financial-transactions", S["admin"], json={
        "transaction_type": "INITIAL_FEE_PAYMENT", "amount": 10000000,
        "transaction_date": TODAY.isoformat(), "reference_no": f"BANK-{RUN}-2"}), 201)
    ok(call("POST", f"/contracts/{S['contract_id']}/financial-transactions", S["admin"], json={
        "transaction_type": "DEPOSIT_PAYMENT", "amount": 20000000,
        "transaction_date": TODAY.isoformat(), "reference_no": f"BANK-{RUN}-3"}), 201)
    ok(call("POST", f"/contracts/{S['contract_id']}/activate", S["admin"]), 204)
    assert find("/contracts", S["admin"], S["contract_id"])["status"] == "ACTIVE"
    store = find("/stores", S["owner"], S["store_id"])
    assert store["status"] == "ACTIVE" and store["activated_at"]
    found = ok(call("GET", "/stores", S["admin"], params={"search": S["store_code"]}))
    assert found["total"] == 1
    fails(call("POST", f"/contracts/{S['contract_id']}/activate", S["admin"]), 409,
          "CONTRACT_MUST_BE_DRAFT")


def test_contract_pdf_export():
    response = call("GET", f"/contracts/{S['contract_id']}/pdf", S["owner"])
    assert response.status_code == 200
    assert response.headers["content-type"] == "application/pdf"
    assert response.content.startswith(b"%PDF")


# ------------------------------------------------------------------ promotions
def promotion_body(name: str, **extra: Any) -> dict[str, Any]:
    body = {
        "name": f"E2E {name} {RUN}", "description": "E2E",
        "discount_type": "FIXED_AMOUNT", "discount_value": 100000,
        "start_date": TODAY.isoformat(), "end_date": (TODAY + timedelta(days=7)).isoformat(),
        "scope": "ALL_STORES", "store_ids": [],
    }
    body.update(extra)
    return body


def test_promotion_lifecycle():
    fails(call("POST", "/promotions", S["owner"], json=promotion_body("X")), 403)
    S["promo_id"] = ok(call("POST", "/promotions", S["admin"],
                            json=promotion_body("Shared")), 201)["id"]
    ok(call("POST", f"/promotions/{S['promo_id']}/activate", S["admin"]), 204)
    assert find("/promotions", S["admin"], S["promo_id"])["status"] == "ACTIVE"
    fails(call("DELETE", f"/promotions/{S['promo_id']}", S["admin"],
               json={"reason": "x"}), 409, "ACTIVE_PROMOTION_CANNOT_BE_DELETED")

    selected = ok(call("POST", "/promotions", S["admin"], json=promotion_body(
        "Selected", scope="SELECTED_STORES", store_ids=[S["store_id"]])), 201)["id"]
    ok(call("POST", f"/promotions/{selected}/cancel", S["admin"],
            json={"reason": "Đổi kế hoạch"}), 204)
    assert find("/promotions", S["admin"], selected)["status"] == "CANCELLED"

    draft = ok(call("POST", "/promotions", S["admin"],
                    json=promotion_body("Draft")), 201)["id"]
    ok(call("DELETE", f"/promotions/{draft}", S["admin"],
            json={"reason": "Tạo nhầm"}), 204)
    items = ok(call("GET", "/promotions", S["admin"], params={"search": RUN}))["items"]
    assert draft not in [item["id"] for item in items]


def test_promotion_validation():
    response = call("POST", "/promotions", S["admin"], json=promotion_body(
        "BadDates", end_date=(TODAY - timedelta(days=1)).isoformat()))
    assert response.status_code in (400, 409), response.text


# --------------------------------------------------------------------- revenue
def revenue_body(gross: int, discount: int = 0, day: date = TODAY) -> dict[str, Any]:
    details = [{"promotion_id": S["promo_id"], "discount_amount": discount}] if discount else []
    return {"store_id": S["store_id"], "business_date": day.isoformat(),
            "gross_revenue": gross, "note": "E2E", "promotion_details": details}


def test_revenue_validation_rules():
    fails(call("POST", "/revenues", S["owner"],
               json=revenue_body(1000000, day=TODAY + timedelta(days=1))), 409,
          "REVENUE_BUSINESS_DATE_INVALID")
    fails(call("POST", "/revenues", S["owner"],
               json=revenue_body(1000000, day=TODAY - timedelta(days=1))), 409,
          "REVENUE_BUSINESS_DATE_INVALID")
    fails(call("POST", "/revenues", S["owner"], json=revenue_body(50000, 100000)), 400)
    # Known gap: the endpoint has no role dependency, so the database role
    # check answers 409 ROLE_REQUIRED instead of the API answering 403.
    fails(call("POST", "/revenues", S["accountant"], json=revenue_body(1000000)), 409,
          "ROLE_REQUIRED:STORE_OWNER")
    fails(call("POST", "/revenues", S["owner"], json=revenue_body(-1)), 422)


def test_owner_reports_daily_revenue_with_promotion():
    S["revenue_id"] = ok(call("POST", "/revenues", S["owner"],
                              json=revenue_body(10000000, 100000)), 201)["id"]
    item = find("/revenues", S["owner"], S["revenue_id"])
    assert item["status"] == "DRAFT"
    assert float(item["net_revenue"]) == 9900000
    fails(call("POST", "/revenues", S["owner"], json=revenue_body(5000000)), 409,
          "REVENUE_ALREADY_EXISTS_FOR_DATE")


def test_revenue_submit_reject_resubmit_approve():
    rid = S["revenue_id"]
    ok(call("POST", f"/revenues/{rid}/submit", S["owner"]), 204)
    fails(call("POST", f"/revenues/{rid}/approve", S["owner"], json={}), 403)
    fails(call("POST", f"/revenues/{rid}/reject", S["accountant"], json={"reason": ""}), 422)
    ok(call("POST", f"/revenues/{rid}/reject", S["accountant"],
            json={"reason": "Sai số tiền"}), 204)
    assert find("/revenues", S["owner"], rid)["status"] == "REJECTED"
    ok(call("PUT", f"/revenues/{rid}", S["owner"], json=revenue_body(12000000, 100000)), 200)
    ok(call("POST", f"/revenues/{rid}/submit", S["owner"]), 204)
    ok(call("POST", f"/revenues/{rid}/approve", S["accountant"],
            json={"note": "Đã đối soát"}), 204)
    assert find("/revenues", S["owner"], rid)["status"] == "APPROVED"


def test_approved_revenue_adjustment_keeps_version():
    rid = S["revenue_id"]
    fails(call("PUT", f"/revenues/{rid}", S["owner"], json=revenue_body(1, 0)), 409,
          "REVENUE_CANNOT_BE_EDITED")
    ok(call("POST", f"/revenues/{rid}/request-adjustment", S["accountant"],
            json={"reason": "Thiếu hóa đơn chiều"}), 204)
    assert find("/revenues", S["owner"], rid)["status"] == "ADJUSTMENT_REQUESTED"
    ok(call("PUT", f"/revenues/{rid}", S["owner"], json=revenue_body(10000000, 100000)), 200)
    ok(call("POST", f"/revenues/{rid}/submit", S["owner"]), 204)
    ok(call("POST", f"/revenues/{rid}/approve", S["accountant"], json={}), 204)
    item = find("/revenues", S["owner"], rid)
    assert item["status"] == "APPROVED" and int(item["version"]) >= 3


def test_revenue_import_reports_row_errors():
    buffer = io.StringIO()
    writer = csv.DictWriter(buffer, fieldnames=["store_id", "business_date", "gross_revenue", "note"])
    writer.writeheader()
    writer.writerow({"store_id": S["store_id"], "business_date": TODAY.isoformat(),
                     "gross_revenue": 1000, "note": "duplicate date"})
    writer.writerow({"store_id": S["store_id"], "business_date": "not-a-date",
                     "gross_revenue": 1000, "note": "bad"})
    files = {"file": ("revenues.csv", buffer.getvalue().encode(), "text/csv")}
    result = ok(call("POST", "/revenues/import", S["owner"], files=files))
    assert result["total_rows"] == 2 and result["failed_rows"] == 2
    fails(call("POST", "/revenues/import", S["owner"],
               files={"file": ("x.txt", b"a", "text/plain")}), 422)
    lines = [
        "store_code,business_date,gross_revenue,note",
        f"{S['store_code']},{TODAY.isoformat()},1000,trùng ngày",
        f"KHONG-CO-{RUN},{TODAY.isoformat()},1000,mã sai",
    ]
    files = {"file": ("mau.csv", "\n".join(lines).encode(), "text/csv")}
    result = ok(call("POST", "/revenues/import", S["owner"], files=files))
    errors = [item["error"] for item in result["errors"]]
    assert "REVENUE_ALREADY_EXISTS_FOR_DATE" in errors[0]
    assert errors[1].startswith("STORE_NOT_FOUND")


# --------------------------------------------------- invoice, payment, billing
def test_billing_adjustment():
    fails(call("POST", "/billing-adjustments", S["owner"], params={"store_id": S["store_id"]},
               json={"amount": 50000, "reason": "x"}), 403)
    ok(call("POST", "/billing-adjustments", S["accountant"],
            params={"store_id": S["store_id"]},
            json={"source_period": MONTH_START.isoformat(), "amount": 50000,
                  "reason": "Phí đào tạo bổ sung"}), 201)


def test_generate_monthly_invoice_computes_fees():
    body = {"store_id": S["store_id"], "invoice_no": f"E2E-INV-{RUN}",
            "period_month": MONTH_START.isoformat(), "vat_rate": 10}
    fails(call("POST", "/invoices/generate", S["owner"], json=body), 403)
    S["invoice_id"] = ok(call("POST", "/invoices/generate", S["accountant"], json=body), 201)["id"]
    inv = find("/invoices", S["accountant"], S["invoice_id"], search=f"E2E-INV-{RUN}")
    # gross 10,000,000 x 5% = 500,000; + 1,000,000 + 2,000,000 + adjustment 50,000
    # - brand support (brand pays the whole discount) 100,000
    # -> taxable 3,450,000; VAT 345,000; total 3,795,000
    assert float(inv["royalty_fee"]) == 500000
    assert float(inv["brand_promotion_support"]) == 100000
    assert float(inv["taxable_amount"]) == 3450000
    assert float(inv["invoice_total"]) == 3795000
    assert inv["status"] == "DRAFT"
    S["invoice_total"] = int(float(inv["invoice_total"]))
    fails(call("POST", "/invoices/generate", S["accountant"],
               json={**body, "invoice_no": f"E2E-INV2-{RUN}"}), 409,
          "INVOICE_ALREADY_EXISTS_FOR_PERIOD")


def test_issue_invoice_and_pdf():
    ok(call("POST", f"/invoices/{S['invoice_id']}/issue", S["accountant"]), 204)
    assert find("/invoices", S["owner"], S["invoice_id"])["status"] == "ISSUED"
    response = call("GET", f"/invoices/{S['invoice_id']}/pdf", S["owner"])
    assert response.status_code == 200 and response.content.startswith(b"%PDF")


def payment(no: str, amount: int) -> httpx.Response:
    return call("POST", f"/invoices/{S['invoice_id']}/payments", S["accountant"], json={
        "payment_no": f"{no}-{RUN}", "amount": amount,
        "payment_date": TODAY.isoformat(), "method": "BANK_TRANSFER",
        "reference_no": f"REF-{no}-{RUN}"})


def test_payments_partial_overpay_and_full():
    S["pay1"] = ok(payment("E2E-PAY1", 1000000), 201)["id"]
    assert find("/invoices", S["owner"], S["invoice_id"])["status"] == "PARTIALLY_PAID"
    fails(payment("E2E-OVER", S["invoice_total"]), 409,
          "PAYMENT_AMOUNT_INVALID_OR_EXCEEDS_OUTSTANDING")
    S["pay2"] = ok(payment("E2E-PAY2", S["invoice_total"] - 1000000), 201)["id"]
    inv = find("/invoices", S["owner"], S["invoice_id"])
    assert inv["status"] == "PAID" and float(inv["outstanding_amount"]) == 0
    payments = ok(call("GET", "/payments", S["owner"], params={"search": RUN}))["items"]
    assert {S["pay1"], S["pay2"]} <= {item["id"] for item in payments}


def test_reverse_payments_and_cancel_invoice():
    fails(call("POST", f"/payments/{S['pay2']}/reverse", S["accountant"],
               json={"reason": ""}), 422)
    ok(call("POST", f"/payments/{S['pay2']}/reverse", S["accountant"],
            json={"reason": "Nhập sai"}), 204)
    inv = find("/invoices", S["owner"], S["invoice_id"])
    assert inv["status"] == "PARTIALLY_PAID"
    assert float(inv["outstanding_amount"]) == S["invoice_total"] - 1000000
    fails(call("POST", f"/invoices/{S['invoice_id']}/cancel", S["accountant"],
               json={"reason": "x"}), 409, "INVOICE_CANNOT_BE_CANCELLED")
    ok(call("POST", f"/payments/{S['pay1']}/reverse", S["accountant"],
            json={"reason": "Nhập sai"}), 204)
    ok(call("POST", f"/invoices/{S['invoice_id']}/cancel", S["accountant"],
            json={"reason": "Lập lại hóa đơn"}), 204)
    assert find("/invoices", S["accountant"], S["invoice_id"])["status"] == "CANCELLED"
    regenerated = ok(call("POST", "/invoices/generate", S["accountant"], json={
        "store_id": S["store_id"], "invoice_no": f"E2E-INV3-{RUN}",
        "period_month": MONTH_START.isoformat(), "vat_rate": 10}), 201)["id"]
    assert find("/invoices", S["accountant"], regenerated)["status"] == "DRAFT"


# ---------------------------------------------- notifications, alerts, audit
def test_notifications_and_mark_read():
    page = ok(call("GET", "/notifications", S["owner"], params={"page_size": 200}))
    types = {item["notification_type"] for item in page["items"]}
    assert page["total"] >= 3, types
    first = page["items"][0]["id"]
    ok(call("PATCH", f"/notifications/{first}/read", S["owner"]), 204)
    item = find("/notifications", S["owner"], first)
    assert item.get("read_at") or item.get("is_read")


def test_generate_alerts_admin_only():
    fails(call("POST", "/operations/generate-alerts", S["owner"]), 403)
    ok(call("POST", "/operations/generate-alerts", S["admin"]), 204)


def test_audit_logs_admin_only():
    fails(call("GET", "/audit-logs", S["owner"]), 403)
    page = ok(call("GET", "/audit-logs", S["admin"], params={"search": "APPROVE"}))
    assert page["total"] >= 1


# ------------------------------------------------------------ reports, export
def test_financial_summary_scoped_by_role():
    params = {"period_from": MONTH_START.isoformat(), "period_to": TODAY.isoformat()}
    owner_rows = ok(call("GET", "/reports/financial-summary", S["owner"], params=params))
    assert [row["store_id"] for row in owner_rows] == [S["store_id"]]
    admin_rows = ok(call("GET", "/reports/financial-summary", S["admin"], params=params))
    assert len(admin_rows) > len(owner_rows)


def test_financial_summary_export_formats():
    params = {"period_from": MONTH_START.isoformat(), "period_to": TODAY.isoformat()}
    csv_response = call("GET", "/reports/financial-summary/export", S["accountant"],
                        params={**params, "format": "csv"})
    assert csv_response.status_code == 200
    text = csv_response.content.decode("utf-8-sig")
    assert "Mã cửa hàng" in text and "TỔNG CỘNG" in text
    xlsx = call("GET", "/reports/financial-summary/export", S["accountant"],
                params={**params, "format": "xlsx"})
    assert xlsx.status_code == 200 and xlsx.content.startswith(b"PK")
    fails(call("GET", "/reports/financial-summary/export", S["accountant"],
               params={**params, "format": "pdf"}), 422)


# ------------------------------------------------------- user administration
def test_admin_deactivates_and_reactivates_user():
    path = f"/auth/users/{S['other_id']}/status"
    fails(call("PATCH", path, S["owner"], json={"status": "INACTIVE", "reason": "x"}), 403)
    ok(call("PATCH", path, S["admin"], json={"status": "INACTIVE", "reason": "Tạm khóa"}), 204)
    fails(call("POST", "/auth/login", json={"email": S["other_email"], "password": PASSWORD}), 401)
    ok(call("PATCH", path, S["admin"], json={"status": "ACTIVE", "reason": "Mở lại"}), 204)
    assert login(S["other_email"])


def test_admin_assigns_and_removes_role():
    path = f"/auth/users/{S['other_id']}/roles"
    fails(call("POST", path, S["admin"], json={"role": "SUPERUSER"}), 422)
    ok(call("POST", path, S["admin"], json={"role": "ACCOUNTANT"}), 204)
    token = login(S["other_email"])
    assert "ACCOUNTANT" in ok(call("GET", "/auth/me", token))["roles"]
    ok(call("DELETE", f"{path}/ACCOUNTANT", S["admin"]), 204)
    assert "ACCOUNTANT" not in ok(call("GET", "/auth/me", token))["roles"]


# ------------------------------------------------------------- password reset
def test_password_reset_request_and_confirm():
    response = ok(call("POST", "/auth/password-reset/request",
                       json={"email": S["other_email"]}))
    assert "reset" in response["message"].lower()
    ok(call("POST", "/auth/password-reset/request", json={"email": f"none.{RUN}@e2e.local"}))
    fails(call("POST", "/auth/password-reset/confirm",
               json={"token": "invalid-token", "new_password": "NewPass@123"}), 409,
          "PASSWORD_RESET_TOKEN_INVALID")

    try:  # MailHog runs only with `docker compose --profile full up -d`
        messages = httpx.get(f"{MAILHOG_URL}/api/v2/messages", timeout=3)
    except httpx.HTTPError:
        pytest.skip("MailHog not running: email part of reset not verified")
    token = None
    for _ in range(20):
        messages = httpx.get(f"{MAILHOG_URL}/api/v2/messages", timeout=3).json()
        for message in messages.get("items", []):
            if S["other_email"] in message["Raw"]["To"]:
                body = quopri.decodestring(message["Content"]["Body"]).decode()
                token = body.rsplit(":", 1)[-1].strip()
                break
        if token:
            break
        time.sleep(1)
    assert token, "reset email not delivered by Celery worker"
    ok(call("POST", "/auth/password-reset/confirm",
            json={"token": token, "new_password": "NewPass@123"}))
    assert login(S["other_email"], "NewPass@123")
    fails(call("POST", "/auth/password-reset/confirm",
               json={"token": token, "new_password": "Again@1234"}), 409,
          "PASSWORD_RESET_TOKEN_INVALID")
