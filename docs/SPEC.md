# Technical Specification

## Stack

- Python 3.12, FastAPI, Uvicorn, Pydantic.
- PostgreSQL 16 Alpine, `asyncpg`, SQL migration và Stored Procedure.
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
không phải ORM. Migration được đánh số, ghi vào `schema_migrations` và không sửa
sau khi đã áp dụng.

## Security

- Argon2 hash password.
- Access JWT 15 phút, refresh JWT 7 ngày và rotation một lần.
- Chỉ lưu SHA-256 của refresh/reset token.
- Lock tạm 15 phút sau 5 lần đăng nhập sai.
- RBAC ở API và Stored Procedure; ownership ở database.
- CORS allow-list, rate limit, không nối input vào SQL.

## Money and history

Money dùng `numeric(18,0)`, rate dùng `numeric(7,4)`. Revenue Promotion,
Invoice, VAT và fee đều snapshot. Audit Log bị trigger chặn update/delete.
