# Franchise Management

Khung kỹ thuật local cho bài tập cá nhân Web API. Dự án chạy trên Windows bằng
Docker Desktop và Git Bash; không triển khai lên server từ xa.

## Công nghệ

- Frontend: HTML, CSS, JavaScript thuần, Nginx Alpine
- Backend: Python 3.12, FastAPI, Uvicorn
- Database: PostgreSQL 16, Stored Procedure/Function
- Kết nối database: `asyncpg` (driver, không phải ORM)
- Kiến trúc backend: 3 layer, không SQLAlchemy/ORM
- Cache và Celery broker: Redis 7
- Tác vụ nền tùy chọn: Celery
- Email test tùy chọn: MailHog
- API test: Postman collection chạy tự động bằng Newman
- Chất lượng: pytest, coverage, Ruff, mypy
- Hạ tầng local: Docker Compose, GitHub Actions CI/CD

SQLAlchemy và ORM không được sử dụng. Repository không tạo object để ORM tự sinh
SQL; Repository gọi Stored Procedure/Function đã định nghĩa trong PostgreSQL
thông qua `asyncpg`.

## Kiến trúc backend

```text
HTTP request
    ↓
API layer
    - Router/endpoint
    - Pydantic request/response schema
    - HTTP status code
    ↓
Service layer
    - Điều phối use case
    - Quy tắc và transaction boundary
    ↓
Repository layer
    - Gọi Stored Procedure/Function
    - Nhận asyncpg connection
    - Chuyển kết quả database thành dữ liệu cho service
    ↓
asyncpg connection pool
    ↓
PostgreSQL
```

Nguyên tắc:

- API layer không viết SQL.
- Service layer không viết SQL.
- Repository layer không xử lý HTTP.
- Lệnh gọi database luôn parameterized bằng `$1`, `$2`..., không nối chuỗi từ input.
- Service mở transaction khi một use case có nhiều thao tác cần nguyên tử.
- Pydantic chỉ dùng cho validation/DTO, không phải ORM model.
- Stored Procedure dùng cho thao tác ghi; Function dùng cho truy vấn trả dữ liệu.
- Chỉ tạo folder/file cho từng layer khi bắt đầu chức năng thực tế.

Ví dụ Repository gọi Stored Procedure:

```python
await connection.execute(
    "CALL app.proc_execute_operation($1, $2)",
    first_value,
    second_value,
)
```

Ví dụ gọi Function để nhận danh sách:

```python
rows = await connection.fetch(
    "SELECT * FROM app.fn_list_records($1, $2)",
    page_size,
    offset,
)
```

## Cấu trúc hiện tại

```text
.
|-- src/
|   |-- frontend/                # Giao diện web tĩnh tối giản
|   |-- backend/
|   |   |-- app/
|   |   |   |-- repositories/    # Gọi Stored Procedure/Function
|   |   |   |-- services/        # Workflow và business validation
|   |   |   |-- domain.py        # Command/token DTO nội bộ, không ORM
|   |   |   |-- security.py      # Argon2, JWT và token hashing
|   |   |   |-- main.py          # FastAPI và lifespan
|   |   |   |-- config.py        # Environment settings
|   |   |   |-- database.py      # asyncpg connection pool
|   |   |   `-- celery_app.py    # Celery tùy chọn
|   |   |-- tests/               # Unit test và API foundation test
|   |   `-- Dockerfile
|-- database/
|   |-- schema/                  # Tạo 14 bảng
|   |-- procedures/              # Stored Procedure/Function theo chức năng
|   `-- run-database-setup.sh    # Khởi tạo schema và cài procedures
|-- postman/                     # Postman collection kiểm thử API
|-- docker-compose.yml
`-- .github/workflows/ci.yml   # GitHub Actions CI/CD
```

## Chạy bằng Docker Desktop

Chỉ cần bật Docker Desktop rồi chạy trong Git Bash:

```bash
cd /d/Franchise
docker compose up -d
```

Build lại sau khi thay đổi dependency hoặc Dockerfile:

```bash
docker compose up -d --build
```

Lệnh trên tự build API, chờ PostgreSQL/Redis, thiết lập database, seed dữ liệu mẫu
rồi mới khởi động API. Seed chỉ nạp khi database còn trống nên khởi động lại không
làm trùng dữ liệu.

- FastAPI: http://localhost:8000
- Swagger: http://localhost:8000/docs
- Health: http://localhost:8000/health
- Frontend: http://localhost:3000

Stack mặc định gồm PostgreSQL, Redis, database-setup/seed one-shot, API và frontend.
Frontend là giao diện vận hành hệ thống, không phải công cụ nhập endpoint để thử
API. Sau khi đăng nhập, menu và thao tác được hiển thị theo vai trò:

- Admin xử lý hồ sơ, cửa hàng, hợp đồng, khuyến mãi và audit log.
- Chủ cửa hàng khai báo doanh thu, theo dõi hóa đơn và thông báo.
- Kế toán duyệt doanh thu, phát hành hóa đơn, ghi nhận thanh toán và xem báo cáo.

Swagger và Postman được giữ riêng cho việc xem đặc tả, kiểm thử và lưu bằng chứng
test API.

Dữ liệu mẫu được nạp trong lần khởi tạo database mới. Repo không còn lệnh hay
script xóa/reset dữ liệu local; khi cần bắt đầu lại, hãy chủ động tạo database
mới và lưu ý thao tác đó có thể làm mất dữ liệu đang dùng.

Chạy thêm Celery scheduler/worker và MailHog khi cần:

```bash
docker compose --profile full up -d
```

## Chạy backend bằng .venv

```bash
cd /d/Franchise
docker compose up -d postgres redis

cd src/backend
py -3.12 -m venv .venv
source .venv/Scripts/activate
python -m pip install --upgrade pip
pip install -r requirements-dev.txt
cp .env.example .env
uvicorn app.main:app --reload
```

## Kiểm tra

```bash
cd /d/Franchise/src/backend
ruff check .
pytest --cov=app --cov-report=term-missing   # unit + integration test
```

### Test end-to-end toàn hệ thống

`tests/e2e/test_full_system.py` gọi thật vào API đang chạy (42 ca kiểm thử, phủ đủ
51 endpoint: đăng nhập, phân quyền, hồ sơ, cửa hàng, hợp đồng, khuyến mãi, doanh thu,
hóa đơn, thanh toán, thông báo, cảnh báo, audit log, báo cáo, xuất file, quản trị
user và đặt lại mật khẩu qua email). Khi API không chạy, các test này tự bỏ qua.

```bash
docker compose --profile full up -d --build      # cần Celery + MailHog cho test email
cd src/backend
pytest -m e2e tests/e2e -v                       # E2E_BASE_URL mặc định http://localhost:8000
```

## Kiểm thử API bằng Postman

Collection nằm tại `postman/franchise-api.postman_collection.json`. Có thể import
file này vào Postman để chạy thủ công với biến `baseUrl=http://localhost:8000`.
Collection gồm 29 request, trong đó có luồng tích hợp đầy đủ từ đăng ký/đăng nhập,
Application, Store, Contract, Promotion, Revenue, Invoice, Payment đến export.

Để chạy tự động bằng Newman trong Docker và tạo báo cáo JUnit:

```bash
cd /d/Franchise
docker compose --profile test run --rm postman
```

Báo cáo được lưu tại `reports/postman/postman-junit.xml`. GitHub Actions cũng chạy
collection này, hiển thị kết quả test và lưu report trong artifacts của build.

## Quản lý database không dùng ORM

Schema được quản lý bằng các file SQL có thứ tự:

```text
database/
|-- schema/001_create_all_tables.sql   # tạo mới 14 bảng
`-- procedures/
    |-- 001_authorization.sql
    |-- 010_authentication.sql
    |-- 020_applications.sql
    |-- 030_stores_contracts.sql
    |-- 040_promotions.sql
    |-- 050_revenues.sql
    |-- 060_billing_payments.sql
    |-- 070_notifications_audit.sql
    `-- 080_queries_reports.sql
```

File schema tạo các bảng/index/constraint. Mỗi file trong `procedures/` gom
Stored Procedure/Function của một nhóm chức năng. `database-setup` chạy schema
khi chưa có bảng, rồi áp dụng lại các procedure/function mỗi lần chạy.

Khi chỉ sửa procedure/function, chạy `docker compose run --rm database-setup`. Khi thay
đổi cấu trúc bảng, cần tạo lại database local bằng `docker compose down -v`
rồi `docker compose up -d --build`; lệnh `down -v` xóa dữ liệu trong volume
đang dùng.

## CI/CD bằng GitHub Actions

Workflow `.github/workflows/ci.yml` chạy mỗi khi push hoặc mở pull request:

1. **backend**: Ruff, mypy, pytest với coverage tối thiểu 30%.
2. **frontend**: kiểm tra cú pháp `app.js`.
3. **integration**: build image, setup database, chạy SQL test, seed và Postman/Newman.
4. **deploy** (chỉ khi push lên `main`): build và đẩy image `franchise-api`,
   `franchise-frontend` lên GitHub Container Registry (`ghcr.io`).

Báo cáo test và coverage được lưu ở mục Artifacts của từng lần chạy.

## Trạng thái hiện tại

Repo hiện có backend/API và giao diện vận hành local, đã triển khai đủ các nhóm chức năng:
Authentication/RBAC, onboarding, Contract
activation, Promotion, Revenue, Invoice/VAT/Credit, Payment/công nợ,
Notification/Celery, import/export/report và hardening/CI. Swagger đầy đủ tại
`http://localhost:8000/docs` sau khi chạy Docker.
