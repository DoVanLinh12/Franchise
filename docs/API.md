# API hiện tại

Base URL local: `http://localhost:8000/api/v1`. Swagger tại
`http://localhost:8000/docs`. Các endpoint ngoài đăng ký, đăng nhập,
đặt lại mật khẩu và health yêu cầu `Authorization: Bearer <access_token>`.

## Authentication và User

```text
POST   /auth/register
POST   /auth/login
POST   /auth/password-reset/request
POST   /auth/password-reset/confirm
GET    /auth/me
PATCH  /auth/users/{id}/status     ADMIN
POST   /auth/users/{id}/roles      ADMIN
DELETE /auth/users/{id}/roles/{role} ADMIN
```

## Application, Store và Contract

```text
POST /applications
GET  /applications
POST /applications/{id}/withdraw
POST /applications/{id}/start-review  ADMIN
POST /applications/{id}/approve       ADMIN
POST /applications/{id}/reject        ADMIN

GET  /stores                           (cửa hàng được tạo tự động khi lập hợp đồng)

POST /contracts                        ADMIN
GET  /contracts
POST /contracts/{id}/financial-transactions ADMIN
POST /contracts/{id}/activate          ADMIN
GET  /contracts/{id}/pdf
```

`POST /contracts` nhận `application_id` của hồ sơ đã duyệt và các điều khoản phí; hệ thống tự
tạo cửa hàng INACTIVE (mã tự sinh, tên/địa chỉ lấy từ hồ sơ). Kích hoạt hợp đồng mở cửa hàng.
Contract chỉ activate khi đã ký và tổng `INITIAL_FEE_PAYMENT` đạt ít nhất 20%
Initial Franchise Fee. Store được activate trong cùng transaction.

## Promotion và Revenue

```text
POST   /promotions                     ADMIN
GET    /promotions
POST   /promotions/{id}/activate       ADMIN
POST   /promotions/{id}/cancel         ADMIN
DELETE /promotions/{id}                ADMIN, soft-delete

POST /revenues                         STORE_OWNER
PUT  /revenues/{id}                    STORE_OWNER
GET  /revenues
POST /revenues/{id}/submit             STORE_OWNER
POST /revenues/{id}/approve            ACCOUNTANT
POST /revenues/{id}/reject             ACCOUNTANT
POST /revenues/{id}/request-adjustment ACCOUNTANT
POST /revenues/import                  STORE_OWNER, CSV/XLSX
```

Revenue lưu snapshot tỷ lệ Brand/Store của từng Promotion. Revenue đã duyệt
không bị ghi đè lịch sử; adjustment tạo version trước khi sửa.

## Invoice, Payment và Notification

```text
POST /billing-adjustments                       ACCOUNTANT
POST /invoices/generate                         ACCOUNTANT
GET  /invoices
POST /invoices/{id}/issue                       ACCOUNTANT
POST /invoices/{id}/cancel                      ACCOUNTANT
GET  /invoices/{id}/pdf
POST /invoices/{id}/payments                    ACCOUNTANT
GET  /payments
POST /payments/{id}/reverse                     ACCOUNTANT
GET  /notifications
PATCH /notifications/{id}/read
POST /operations/generate-alerts                ADMIN
GET  /audit-logs                                ADMIN
```

## Báo cáo và vận hành

```text
GET /reports/financial-summary
GET /reports/financial-summary/export?format=csv|xlsx
GET /health
GET /health/ready
```

Danh sách hỗ trợ `search`, `status`, `page`, `page_size` tùy endpoint. Kích
thước trang tối đa 200. Import tối đa 5.000 dòng hoặc 10 MB.

Postman collection: `postman/franchise-api.postman_collection.json`.
