# Technical Specification

## Stack

- Python 3.12, FastAPI, Uvicorn, Pydantic.
- PostgreSQL 16 Alpine, `asyncpg`, SQL schema và Stored Procedure.
- Redis 7 Alpine; Celery worker/beat tùy chọn.
- MailHog cho email local.
- pytest/coverage, Ruff, mypy, Newman, Jenkins.
- openpyxl cho XLSX và ReportLab cho PDF.

## Architecture

```text
HTTP Router + Pydantic
→ Service (use case + transaction)
→ Repository (CALL proc / SELECT fn)
→ asyncpg pool
→ PostgreSQL
```

API và Service không chứa SQL. Repository dùng placeholder `$1...`; Pydantic
không phải ORM. Toàn bộ bảng được định nghĩa trong một file schema; functions
và procedures được tách thành các file theo chức năng. Compose dùng volume mới
cho cấu trúc database này.

## Security

- Argon2 hash password.
- Access JWT 15 phút cho API; không dùng refresh token. Token hết hạn thì
  người dùng đăng nhập lại.
- Password reset dùng token một lần; database chỉ lưu SHA-256 của reset token.
- RBAC ở API và Stored Procedure; ownership ở database.
- CORS allow-list, rate limit, không nối input vào SQL.

## Money and history

Money dùng `numeric(18,0)`, rate dùng `numeric(7,4)`. Revenue Promotion,
Invoice, VAT và fee đều snapshot. Audit Log bị trigger chặn update/delete.
