# Chạy local bằng Docker Desktop

Dự án không deploy lên server. Yêu cầu duy nhất là Docker Desktop đang chạy.

Trong Git Bash:

```bash
cd /d/Franchise
docker compose up -d --build
```

Compose tự thiết lập schema, nạp procedures và seed dữ liệu trước khi API khởi động; không cần
chạy thêm lệnh chuẩn bị database ở lần chạy đầu.

Địa chỉ:

```text
API       http://localhost:8000
Swagger   http://localhost:8000/docs
Frontend  http://localhost:3000
Postgres  localhost:5432
Redis     localhost:6379
```

Stack đầy đủ có Celery, scheduler và MailHog:

```bash
docker compose --profile full up -d --build
```

MailHog: `http://localhost:8025`.

Kiểm tra:

```bash
docker compose --profile test run --rm database-test   # test SQL
docker compose --profile test run --rm postman         # Postman/Newman
cd src/backend && pytest --cov=app                      # unit + integration
cd src/backend && pytest -m e2e tests/e2e               # end-to-end (hệ thống đang chạy)
```

CI/CD: GitHub Actions (`.github/workflows/ci.yml`) chạy lint, test, SQL test,
Postman và đẩy image lên `ghcr.io` khi push lên `main`.

Không commit `.env`. Đổi `JWT_SECRET_KEY` trong `.env` trước khi demo. Tài khoản
seed local dùng chung mật khẩu `Admin@123`:

```text
admin@franchise.local       ADMIN
owner@franchise.local       STORE_OWNER
accountant@franchise.local  ACCOUNTANT
```

Dừng container nhưng giữ database:

```bash
docker compose --profile full down
```

Không dùng `--volumes` nếu muốn giữ dữ liệu local.
