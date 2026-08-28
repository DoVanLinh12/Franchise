# Franchise Management

Khung công nghệ và hạ tầng tối thiểu cho dự án web quản lý chuỗi cửa hàng nhượng quyền.

## Công nghệ đã chọn

- Backend: Python 3.12, FastAPI, SQLAlchemy async, Alembic
- Dữ liệu: PostgreSQL 16, Redis 7
- Tác vụ nền: Celery
- Frontend: React 19, Vite, Nginx
- Kiểm thử/chất lượng: pytest, coverage, Ruff, Oxlint
- Hạ tầng: Docker Compose, Jenkins Pipeline

## Cấu trúc hiện tại

```text
.
|-- src/
|   |-- backend/          # API bootstrap, DB, Celery, Alembic và smoke test
|   `-- frontend/         # Vite/React bootstrap tối thiểu
|-- infrastructure/
|   |-- deploy/           # Compose dành cho máy triển khai
|   `-- jenkins/          # Jenkins controller và Docker daemon
|-- scripts/dev.sh        # Lệnh tiện ích cho Git Bash
|-- docker-compose.yml    # Môi trường phát triển
`-- Jenkinsfile           # CI/CD pipeline
```

Thư mục `docs` được giữ trống theo chủ ý và chỉ viết khi dự án hoàn thành.

## Chạy bằng Docker

Từ Git Bash trên Windows:

```bash
cd /d/Franchise
cp .env.example .env
bash scripts/dev.sh up
docker compose ps
```

- Frontend: http://localhost:3000
- Swagger: http://localhost:8000/docs
- API health: http://localhost:8000/health
- MailHog: http://localhost:8025

## Chạy backend bằng `.venv`

Bạn có thể tạo môi trường ảo sau, khi bắt đầu phát triển backend:

```bash
cd /d/Franchise/src/backend
py -3.12 -m venv .venv
source .venv/Scripts/activate
python -m pip install --upgrade pip
pip install -r requirements-dev.txt
cp .env.example .env
uvicorn app.main:app --reload
```

Nếu backend chạy trong `.venv`, chỉ cần bật các dịch vụ hạ tầng:

```bash
cd /d/Franchise
docker compose up -d postgres redis mailhog
```

## Chạy frontend

```bash
cd /d/Franchise/src/frontend
npm ci
npm run dev
```

## Lệnh Git Bash thường dùng

```bash
bash scripts/dev.sh config
bash scripts/dev.sh logs
bash scripts/dev.sh test
bash scripts/dev.sh coverage
bash scripts/dev.sh migration "create first table"
bash scripts/dev.sh migrate
bash scripts/dev.sh down
```

## Jenkins CI/CD

Jenkins chạy trong Docker Desktop ở chế độ Linux containers. Khởi động bằng:

```bash
cd /d/Franchise
bash scripts/dev.sh jenkins-up
bash scripts/dev.sh jenkins-password
```

Mở http://localhost:8080, hoàn tất thiết lập ban đầu và tạo **Multibranch
Pipeline** trỏ đến repository này. Pipeline mặc định chạy kiểm tra backend,
frontend, Docker Compose và build image. Publish/deploy chỉ chạy trên nhánh
`main` khi bật tham số tương ứng.

Khi cần publish/deploy, tạo hai credentials trong Jenkins:

- `franchise-registry`: tài khoản/token của Docker registry.
- `franchise-deploy-ssh`: SSH private key của máy triển khai.

Máy triển khai cần Docker Compose và file `.env` dựa trên
`infrastructure/deploy/.env.example`. Không commit `.env`, secret, `.venv`, file
upload hoặc file xuất vào repository.

```bash
bash scripts/dev.sh jenkins-logs
bash scripts/dev.sh jenkins-down
```
