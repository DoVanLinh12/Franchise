# Software Requirements Specification

## Functional requirements

1. Identity: đăng ký, đăng nhập JWT, refresh rotation, logout, reset mật khẩu.
2. RBAC: Admin, Store Owner, Accountant; kiểm tra ownership theo Store.
3. Onboarding: Application → review → approve → Store → Contract.
4. Activation: thu tối thiểu 20% Initial Fee trước khi Contract/Store ACTIVE.
5. Promotion: Brand/Store/Shared funding và phạm vi áp dụng.
6. Revenue: một Store/ngày, workflow và version adjustment.
7. Billing: monthly aggregation, Royalty, support, adjustment, credit, VAT.
8. Payment: partial, không overpay, reverse và outstanding tự tính lại.
9. Notification: application/revenue/promotion/invoice/payment/late alert.
10. Report/import/export: CSV/XLSX/PDF và financial summary.

## Non-functional requirements

- REST/OpenAPI và Postman.
- Parameterized SQL; không ORM; Stored Procedure cho write workflow.
- Argon2, JWT validation, CORS và rate limiting.
- Audit bất biến, soft-delete và versioning dữ liệu nhạy cảm.
- Structured JSON logging, request ID, readiness/health.
- Redis cache cho báo cáo; Celery cho email/cảnh báo nền.
- PostgreSQL/Redis/API chạy bằng Docker Compose trên máy local.
- Jenkins build, lint, type-check, unit/integration/Postman test.

## Constraints

- Currency VND, làm tròn đến 1 VND.
- Một Invoice/Store/tháng, trừ Invoice đã cancel.
- Không xóa Revenue duyệt, Invoice hoặc Payment; dùng adjustment/cancel/reverse.
- Các rule còn mở trong mục 46 của đặc tả không được tự động suy diễn.
