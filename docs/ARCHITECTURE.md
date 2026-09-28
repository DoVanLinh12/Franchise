# Kiến trúc backend 3 layer dùng Stored Procedure

## Quyết định

Backend sử dụng FastAPI và PostgreSQL nhưng không dùng SQLAlchemy hoặc ORM.
`asyncpg` chỉ là database driver: quản lý connection pool và gọi Stored
Procedure/Function bằng tham số.

Kiến trúc là modular monolith 3 layer:

```mermaid
flowchart TD
    Client[Frontend / Postman / HTTP client]
    API[API layer<br/>Router + Pydantic schema]
    Service[Service layer<br/>Use case + transaction]
    Repository[Repository layer<br/>Call Procedure/Function]
    Pool[asyncpg connection pool]
    DB[(PostgreSQL)]

    Client --> API
    API --> Service
    Service --> Repository
    Repository --> Pool
    Pool --> DB
```

Frontend là client tĩnh độc lập tại `src/frontend`, dùng HTML/CSS/JavaScript
thuần và gọi REST API qua HTTP. Frontend không truy cập PostgreSQL, Redis hoặc
Stored Procedure trực tiếp; toàn bộ validation và phân quyền vẫn thuộc backend.

## 1. API layer

Trách nhiệm:

- Khai báo route và HTTP method.
- Model binding và validation bằng Pydantic.
- Chuyển HTTP input thành tham số gọi service.
- Chọn status code và response schema.
- Chuyển exception đã biết thành HTTP response.

Không được:

- Viết SQL.
- Mở transaction.
- Chứa quy tắc xử lý chính.
- Truy cập trực tiếp connection pool.

## 2. Service layer

Trách nhiệm:

- Điều phối một use case.
- Thực hiện validation không thuộc HTTP.
- Gọi một hoặc nhiều repository.
- Xác định transaction boundary.
- Phối hợp cache hoặc background task khi cần.

Không được:

- Viết SQL.
- Phụ thuộc FastAPI Request/Response.
- Tự tạo database connection ngoài abstraction đã thống nhất.

Ví dụ transaction nhiều thao tác:

```python
async with pool.acquire() as connection:
    async with connection.transaction():
        await first_repository.execute(connection, ...)
        await second_repository.execute(connection, ...)
```

Service sở hữu transaction vì service biết toàn bộ use case cần nguyên tử đến
đâu. Repository chỉ thực thi câu lệnh bằng connection được truyền vào.

## 3. Repository layer

Trách nhiệm:

- Chứa lệnh gọi Stored Procedure/Function.
- Dùng `execute` để `CALL` procedure và dùng `fetch`, `fetchrow`, `fetchval` để
  lấy kết quả từ function.
- Nhận connection khi cần tham gia transaction.
- Chuyển `asyncpg.Record` thành dữ liệu đơn giản cho service.
- Không trả database connection ra bên ngoài.

Lệnh gọi bắt buộc dùng placeholder PostgreSQL:

```python
await connection.execute(
    "CALL app.proc_execute_operation($1, $2)",
    first_value,
    second_value,
)
```

Truy vấn trả dữ liệu sử dụng PostgreSQL Function:

```python
rows = await connection.fetch(
    "SELECT * FROM app.fn_list_records($1, $2)",
    page_size,
    offset,
)
```

Không được nối input vào lệnh gọi:

```python
# Không an toàn, không được sử dụng
query = f"CALL app.proc_operation({record_id})"
```

Quy ước database routine:

- `proc_...`: Stored Procedure thực hiện thao tác ghi hoặc nhiều bước.
- `fn_...`: Function truy vấn, tính toán hoặc trả danh sách.
- `p_...`: tên tham số của Procedure/Function.
- Routine nằm trong schema ứng dụng và luôn được gọi kèm schema, ví dụ
  `app.proc_execute_operation`.
- Service quản lý transaction; Procedure không tự `COMMIT` hoặc `ROLLBACK` khi
  được gọi trong transaction của Service.
- Không đưa phân quyền HTTP, JWT hoặc việc gửi email vào database routine.

## 4. Database foundation

`app/database.py` cung cấp:

- `connect_database()`: tạo asyncpg pool khi FastAPI start.
- `disconnect_database()`: đóng pool khi FastAPI stop.
- `get_pool()`: lấy pool đã được khởi tạo.
- `get_connection()`: acquire và release connection an toàn.

FastAPI lifespan quản lý vòng đời pool:

```text
Application start → create_pool
Application running → acquire/release connection
Application stop → pool.close
```

`DATABASE_URL` dùng định dạng asyncpg chuẩn:

```text
postgresql://user:password@host:5432/database
```

## 5. Dữ liệu truyền giữa các layer

Không dùng ORM entity. Các dạng dữ liệu được phép:

- Pydantic request/response DTO tại biên HTTP.
- Primitive values.
- Dataclass hoặc typed dictionary nếu service cần kiểu nội bộ.
- `asyncpg.Record` chỉ nên tồn tại bên trong Repository và được chuyển đổi trước
  khi trả ra.

Pydantic object không phải ORM; nó chỉ validate và serialize dữ liệu API.

## 6. Schema, Stored Procedure và migration

Không dùng Alembic vì Alembic thuộc hệ sinh thái SQLAlchemy. Khi bắt đầu tạo
table, schema được quản lý bằng SQL script có thứ tự:

```text
database/migrations/
├── 001_initial_schema.sql
├── 002_create_functions.sql
`── 003_create_procedures.sql
```

Nguyên tắc:

- Không sửa script đã áp dụng; tạo script mới.
- Mỗi script phải có thứ tự và tên mô tả.
- Dùng transaction khi câu DDL hỗ trợ.
- Mọi thay đổi của Function/Procedure phải nằm trong migration SQL.
- Review SQL trước khi chạy.
- Không tạo script rỗng khi chưa có schema.

Migration được áp dụng bằng `database/run-migrations.sh` thông qua service
`migrate` của Docker Compose. Các migration đã chạy được ghi tại
`public.schema_migrations`.

## 7. Cấu trúc sẽ mở rộng theo nhu cầu

```text
app/
├── api/
│   `── <feature>.py
├── services/
│   `── <feature>_service.py
├── repositories/
│   `── <feature>_repository.py
├── config.py
├── database.py
`── main.py
```

Không tạo toàn bộ file/folder rỗng từ trước.

## 8. Tối ưu API

Không dùng Celery cho CRUD hoặc query cần trả kết quả ngay. Hiệu năng API được
tối ưu theo thứ tự:

1. SQL đúng và chỉ lấy cột cần thiết.
2. Index dựa trên truy vấn thực tế.
3. Pagination giới hạn số row.
4. Connection pool asyncpg.
5. Không thực hiện blocking I/O trong async endpoint.
6. Redis cache cho dữ liệu đọc nhiều, có chính sách TTL/invalidation.
7. Đo thời gian query và endpoint trước khi tối ưu.
8. Celery chỉ dành cho tác vụ dài không cần hoàn thành trong HTTP request.

## 9. Trạng thái hiện tại

- Connection pool asyncpg: đã có.
- Pool lifecycle: đã nối với FastAPI.
- Repository và Service: đã có cho Application, Store và Contract DRAFT.
- Identity/Auth core: đăng ký, Argon2, JWT access/refresh, token rotation,
  logout, password reset, trạng thái User và RBAC đã có ở Service/Repository.
- Stored Procedure/Function: đã có cho các workflow trên.
- Database table: đã có lát cắt Identity/RBAC, Application, Store, Contract và
  Audit Log.
- SQL migration runner: đã có.
- API Authentication và nghiệp vụ: đã mở dưới `/api/v1`.
- Revenue, Promotion, Invoice, Payment và Notification: đã triển khai.
- Import/export CSV/XLSX, PDF và báo cáo cache Redis: đã triển khai.
- Celery worker/beat và MailHog: chạy khi bật profile `full`.
