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
- Hạ tầng local: Docker Compose, Jenkins CI

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
|-- infrastructure/jenkins/      # Jenkins chạy local
|-- database/
|   |-- migrations/              # SQL schema + Stored Procedure/Function
|   `-- run-migrations.sh        # Migration runner
|-- postman/                     # Postman collection kiểm thử API
|-- scripts/dev.sh
|-- docker-compose.yml
`-- Jenkinsfile
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

Lệnh trên tự build API, chờ PostgreSQL/Redis, chạy migration, seed dữ liệu mẫu
rồi mới khởi động API. Có thể gọi `db-migrate` hoặc `db-seed` riêng khi cần kiểm
tra thủ công; chạy lại an toàn vì cả hai đều idempotent.

- FastAPI: http://localhost:8000
- Swagger: http://localhost:8000/docs
- Health: http://localhost:8000/health
- Frontend: http://localhost:3000

Stack mặc định gồm PostgreSQL, Redis, migration/seed one-shot, API và frontend.
Frontend là giao diện vận hành hệ thống, không phải công cụ nhập endpoint để thử
API. Sau khi đăng nhập, menu và thao tác được hiển thị theo vai trò:

- Admin xử lý hồ sơ, cửa hàng, hợp đồng, khuyến mãi và audit log.
- Chủ cửa hàng khai báo doanh thu, theo dõi hóa đơn và thông báo.
- Kế toán duyệt doanh thu, phát hành hóa đơn, ghi nhận thanh toán và xem báo cáo.

Swagger và Postman được giữ riêng cho việc xem đặc tả, kiểm thử và lưu bằng chứng
test API.

Dữ liệu local mặc định gồm các hồ sơ và cửa hàng Mộc Miên Coffee tại nhiều tỉnh
thành, hợp đồng, khuyến mãi, 2.520 doanh thu theo ngày, hóa đơn, thanh toán,
thông báo và audit log. Khi cần xóa dữ liệu do các lần test trước tạo ra và nạp
lại bộ dữ liệu chuẩn, chạy trong Git Bash:

```bash
bash scripts/dev.sh db-reset
```

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
pytest --cov=app --cov-report=term-missing
```

## Kiểm thử API bằng Postman

Collection nằm tại `postman/franchise-api.postman_collection.json`. Có thể import
file này vào Postman để chạy thủ công với biến `baseUrl=http://localhost:8000`.
Collection gồm 30 request, trong đó có luồng tích hợp đầy đủ từ đăng ký/đăng nhập,
Application, Store, Contract, Promotion, Revenue, Invoice, Payment đến export.

Để chạy tự động bằng Newman trong Docker và tạo báo cáo JUnit:

```bash
cd /d/Franchise
bash scripts/dev.sh postman-test
```

Báo cáo được lưu tại `reports/postman/postman-junit.xml`. Jenkins cũng chạy
collection này, hiển thị kết quả test và lưu report trong artifacts của build.

Kịch bản E2E thủ công theo ba vai trò, gồm dữ liệu mẫu và kết quả mong đợi, nằm
tại `docs/E2E_TEST_SCENARIO.md`.

## Quản lý database không dùng ORM

Schema được quản lý bằng các file SQL có thứ tự:

```text
database/
`-- migrations/
    |-- 001_identity_application_store_contract.sql
    |-- 002_application_store_contract_routines.sql
    |-- 003_identity_authentication_tables.sql
    |-- 004_identity_authentication_routines.sql
    |-- 005_revenue_billing_tables.sql
    |-- 006_revenue_billing_routines.sql
    |-- 007_access_and_notification_routines.sql
    `-- 008_business_notification_trigger.sql
```

Các script này là nguồn chính thức để tạo table, index, Function và Stored
Procedure. Migration đã áp dụng được ghi trong `public.schema_migrations`; không
sửa migration cũ sau khi đã áp dụng mà phải tạo migration mới.

## Jenkins local

```bash
bash scripts/dev.sh jenkins-up
bash scripts/dev.sh jenkins-password
```

Jenkins chạy lint, unit test, coverage, validate Compose, build API image và chạy
Postman API test ngay trên máy local. Không push registry và không SSH deploy.

## Trạng thái hiện tại

Repo hiện có backend/API và giao diện vận hành local, đã triển khai đủ 10 giai đoạn
trong `docs/IMPLEMENTATION_ROADMAP.md`: Authentication/RBAC, onboarding, Contract
activation, Promotion, Revenue, Invoice/VAT/Credit, Payment/công nợ,
Notification/Celery, import/export/report và hardening/CI. Swagger đầy đủ tại
`http://localhost:8000/docs` sau khi chạy Docker.
