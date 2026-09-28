# Giai đoạn 1 — Identity và Authentication backend core

## Kết quả

Giai đoạn 1 đã hoàn thành phần lõi backend, chưa mở endpoint HTTP. Luồng hiện
tại là:

```text
API (sẽ làm ở giai đoạn sau)
  → AuthService
  → AuthRepository
  → Stored Procedure / Function
  → PostgreSQL
```

Không dùng SQLAlchemy hay ORM. Python chỉ gọi routine bằng `asyncpg` và tham số
`$1`, `$2`.

## Thành phần đã làm

### User và mật khẩu

- Đăng ký User với email chuẩn hóa chữ thường.
- Mật khẩu được hash bằng Argon2; không lưu hoặc ghi log mật khẩu thô.
- Theo dõi lần đăng nhập cuối, số lần sai và thời điểm khóa tạm.
- Sau 5 lần sai, tài khoản bị chặn đăng nhập 15 phút theo cấu hình.
- Reset mật khẩu dùng token ngẫu nhiên một lần, mặc định hết hạn sau 30 phút.

### JWT session

- Access token mặc định 15 phút.
- Refresh token mặc định 7 ngày.
- JWT có `sub`, `jti`, `type`, `iat`, `nbf`, `exp`, `iss`, `aud`.
- Refresh token được rotation: dùng thành công thì token cũ bị revoke.
- Logout revoke refresh token.
- Database chỉ giữ SHA-256 hash của refresh/reset token.
- Reset mật khẩu hoặc vô hiệu hóa User revoke mọi refresh token còn hiệu lực.

JWT được ký chứ không mã hóa, vì vậy không đưa dữ liệu bí mật vào claims.

### RBAC và quản trị User

Ba role hiện có:

```text
ADMIN
STORE_OWNER
ACCOUNTANT
```

Admin có thể gán/gỡ role và đổi trạng thái User thông qua Service/Stored
Procedure. Database ngăn việc làm mất Admin hoạt động cuối cùng. Các thay đổi
trạng thái, role, đăng nhập, refresh và reset mật khẩu đều được ghi Audit Log.

Người vừa đăng ký chưa có role. Role `STORE_OWNER` được gán khi Admin tạo Store
từ hồ sơ Franchise đã duyệt; role khác do Admin quản lý.

## File chính

```text
database/migrations/003_identity_authentication_tables.sql
database/migrations/004_identity_authentication_routines.sql
database/tests/002_identity_authentication_flow.sql
src/backend/app/security.py
src/backend/app/repositories/auth_repository.py
src/backend/app/services/auth_service.py
src/backend/tests/test_security.py
src/backend/tests/test_auth_service.py
```

## Cấu hình

Các biến quan trọng nằm trong `src/backend/.env.example`:

```text
JWT_SECRET_KEY
JWT_ALGORITHM
JWT_ISSUER
JWT_AUDIENCE
ACCESS_TOKEN_EXPIRE_MINUTES
REFRESH_TOKEN_EXPIRE_DAYS
PASSWORD_RESET_EXPIRE_MINUTES
MAX_LOGIN_ATTEMPTS
LOGIN_LOCK_MINUTES
```

`JWT_SECRET_KEY` mẫu chỉ dành cho local. Sao chép `.env.example` thành `.env`
và thay bằng chuỗi ngẫu nhiên dài; không commit `.env`.

## Kiểm thử

Khi Docker Desktop đang chạy:

```bash
docker compose --profile test build backend-test
docker compose --profile test run --rm backend-test \
  sh -c "ruff check . && mypy app && python -m pytest --cov=app --cov-report=term-missing"
bash scripts/dev.sh db-test
```

Database integration test chạy trong transaction rồi `ROLLBACK`, nên không để
lại tài khoản hoặc token test.

Kết quả xác minh ngày 26/09/2026:

```text
Ruff: passed
mypy: passed (16 source files)
pytest: 25 passed
coverage: 87.20%
Database integration: 2/2 SQL flow passed
Migration idempotency: passed (001–004 được skip khi chạy lại)
Runtime health: GET /health → {"status":"ok"}
```

## Chưa thuộc giai đoạn này

- Endpoint HTTP và Pydantic request/response schema.
- Dependency lấy Bearer token và policy authorization tại API layer.
- Email gửi link reset qua Celery/MailHog.
- 2FA/OAuth2 bên thứ ba.
- API Postman cho authentication.

Những phần trên được nối sau; nền tảng service và database đã sẵn sàng để API
gọi mà không đưa SQL hoặc quy tắc bảo mật vào endpoint.
