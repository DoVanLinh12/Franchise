# Backend đã triển khai

## 1. Phạm vi

Backend triển khai các business rule đã chốt trong
`FRANCHISE_BUSINESS_SPEC_VI.md` và công bố qua REST API.

Đã triển khai:

- Identity/RBAC và Authentication backend core.
- Franchise Application workflow.
- Tạo Store từ Application đã duyệt.
- Tạo Contract ở trạng thái `DRAFT`.
- Contract/Store activation, Promotion, Revenue và version adjustment.
- Monthly Invoice, VAT, Credit, Payment, Outstanding và Notification.
- CSV/XLSX import-export, Contract/Invoice PDF và báo cáo.
- Audit Log bất biến cho các thao tác quan trọng.
- SQL database setup runner with feature-grouped procedures/functions.
- Repository và Service layer gọi Stored Procedure/Function bằng `asyncpg`.

## 2. Database

`database/schema/001_create_all_tables.sql` tạo toàn bộ bảng, index và
constraints, bao gồm:

- `app.users`;
- `app.roles`;
- `app.user_roles`;
- `app.franchise_applications`;
- `app.stores`;
- `app.contracts`;
- `app.audit_logs`.

Các role được nạp từ `database/reference-data/001_roles.sql`:

```text
ADMIN
STORE_OWNER
ACCOUNTANT
```

Các ràng buộc chính:

- Email User đang hoạt động không trùng nhau.
- Một User chỉ có một Application chưa kết thúc.
- Một Application chỉ tạo được một Store.
- Store mới luôn `INACTIVE`.
- Một Store chỉ có tối đa một Contract `ACTIVE`.
- Fee không âm; royalty rate nằm trong khoảng 0–100.
- Audit Log không được update hoặc delete.
- Password reset token chỉ được lưu dưới dạng SHA-256 hash và chỉ dùng một lần.
- API cấp access JWT khi đăng nhập; không có refresh token, nên đăng nhập lại
  khi access token hết hạn.
- Không cho vô hiệu hóa hoặc gỡ role của Admin hoạt động cuối cùng.

## 3. Stored Procedure và Function

Các routine được nhóm theo chức năng trong `database/procedures/`:

```text
proc_submit_franchise_application
proc_withdraw_franchise_application
proc_start_application_review
proc_approve_franchise_application
proc_reject_franchise_application
proc_create_store_from_application
proc_create_draft_contract
```

Function đọc dữ liệu:

```text
fn_get_franchise_application
fn_get_store
fn_get_contract
```

Nhóm `010_authentication.sql` khai báo routines:

```text
password_reset_tokens
fn_get_user_auth_by_email
fn_get_user
fn_get_user_roles
proc_register_user
proc_record_login_success
proc_create_password_reset_token / proc_reset_password
proc_change_user_status
proc_assign_user_role / proc_remove_user_role
```

Các procedure thay đổi trạng thái sử dụng row lock và ghi Audit trong cùng
transaction. Procedure tạo Store tự gán role `STORE_OWNER` cho chủ cửa hàng.

## 4. Backend layer

Domain command nằm tại `app/domain.py` và dùng `UUID`, `Decimal`, `date`; không
có ORM entity.

Repository:

```text
app/repositories/application_repository.py
app/repositories/store_repository.py
app/repositories/contract_repository.py
app/repositories/auth_repository.py
app/repositories/operations_repository.py
```

Repository chỉ gọi Stored Procedure/Function, không quyết định workflow.

Service:

```text
app/services/application_service.py
app/services/store_service.py
app/services/contract_service.py
app/services/auth_service.py
app/services/operations_service.py
app/services/export_service.py
```

`app/security.py` đóng gói Argon2, phát/kiểm tra JWT access, đồng
thời hash token trước khi lưu database. `AuthService` không phụ thuộc FastAPI,
do đó được test độc lập trước khi mở endpoint HTTP.

Service kiểm tra input cơ bản, tạo UUID, mở transaction và điều phối Repository.

Unit test bao phủ các workflow Service và validation đầu vào. Docker có test
target riêng nên image API runtime không chứa pytest, Ruff hoặc mã nguồn test.

Database integration test chạy trực tiếp chuỗi Stored Procedure:

```text
Submit Application
→ Start Review
→ Approve
→ Create Store
→ Create Contract DRAFT
→ Record 20% Initial Fee → Activate Contract/Store
→ Promotion → Revenue → Approve
→ Monthly Invoice/VAT → Payment → Reverse
→ Verify Notification, snapshot, status và Audit Log
```

Test kết thúc bằng `ROLLBACK`, không để lại dữ liệu mẫu trong database.

## 5. Thiết lập database

Bật Docker Desktop rồi chạy trong Git Bash:

```bash
docker compose up -d postgres
bash scripts/dev.sh db-setup
bash scripts/dev.sh db-test
```

Schema được tạo một lần trên volume mới; mỗi lần chạy setup, procedures và
functions được nạp lại để thuận tiện chỉnh SQL trong lúc phát triển.

Jenkins cũng chạy database setup trên PostgreSQL tạm trước khi chạy Postman health
test, nhờ đó lỗi cú pháp SQL hoặc lỗi tạo routine sẽ làm pipeline thất bại. Khi
pipeline kết thúc, database volume tạm của Jenkins được xóa để lần build sau
kiểm tra lại schema và routines từ database sạch.

## 6. Giới hạn có chủ đích

Không triển khai rule chưa chốt tại mục 46 của đặc tả: Contract renewal và
termination nâng cao, lịch trả góp 80% Initial Fee, hoàn Deposit, Store holiday,
fee change giữa kỳ, reopen monthly close và credit khi Contract kết thúc.

Deposit transaction đã có loại ghi nhận riêng nhưng không bị bắt buộc trước
activation vì đặc tả chưa chốt điều kiện này. Initial Fee installment trên
Invoice hiện bằng 0 cho tới khi lịch trả góp được quyết định chính thức.

## 7. API và kiểm thử

Danh sách endpoint nằm trong `docs/API.md`. Database có ba integration flow.
Postman/Newman chạy request health/readiness, đăng nhập và luồng
Application → Store → Contract → Promotion → Revenue → Invoice → Payment →
Notification → PDF/CSV. Seed local tạo ba tài khoản role mẫu và 2.000 Revenue.
