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
bash scripts/dev.sh db-test
bash scripts/dev.sh coverage
bash scripts/dev.sh postman-test
```

Jenkins local:

```bash
bash scripts/dev.sh jenkins-up
bash scripts/dev.sh jenkins-password
```

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
