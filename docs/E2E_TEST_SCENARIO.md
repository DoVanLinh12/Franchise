# Kịch bản kiểm thử End-to-End

## 1. Mục tiêu

Kiểm tra một vòng đời Franchise hoàn chỉnh qua frontend và REST API:

```text
Tạo User → Gán quyền Store Owner → Nộp hồ sơ → Admin duyệt
→ Tạo Store → Tạo/activate Contract → Tạo Promotion
→ Owner báo cáo Revenue → Accountant duyệt Revenue
→ Tạo/issue Invoice → Ghi nhận Payment → Report/Notification/Audit
```

Kịch bản đồng thời kiểm tra JWT, RBAC, Stored Procedure, PostgreSQL, Redis,
PDF/CSV và các màn hình vận hành trên frontend.

## 2. Chuẩn bị

Trong Git Bash:

```bash
cd /d/Franchise
docker compose up -d --build
docker compose ps
```

Kết quả mong đợi: `api`, `frontend`, `postgres` và `redis` đều `Up`; các
container có healthcheck phải hiển thị `healthy`.

Mở:

- Frontend: `http://localhost:3000`
- Swagger: `http://localhost:8000/docs`
- Postman: collection `postman/franchise-api.postman_collection.json`

Tạo bộ dữ liệu riêng cho lần chạy. Ví dụ:

```text
RUN_ID       = 20260927-01
TODAY        = 2026-09-27
MONTH_START  = 2026-09-01
NEXT_WEEK    = 2026-10-04
NEXT_YEAR    = 2027-09-27
OWNER_EMAIL  = owner.20260927-01@franchise.local
```

Khi chạy vào ngày khác, thay các giá trị trên. Không dùng lại `RUN_ID` cũ.

Tài khoản seed:

| Vai trò | Email | Mật khẩu |
|---|---|---|
| Admin | `admin@franchise.local` | `Admin@123` |
| Kế toán | `accountant@franchise.local` | `Admin@123` |

Trong các bước dưới đây, thao tác bằng màn hình, nút và biểu mẫu nghiệp vụ trên
frontend. Các khối endpoint/JSON được giữ lại để đối chiếu request trong Swagger
hoặc log backend; người vận hành không phải tự nhập endpoint hay JSON.

## 3. Luồng E2E chính

### Bước 1 — Admin đăng nhập

Đăng nhập frontend bằng:

```text
admin@franchise.local / Admin@123
```

Mong đợi:

- Chuyển sang Dashboard.
- Hiển thị tên `Nguyễn Hoàng Nam` và role `ADMIN`.
- Dashboard hiển thị dữ liệu theo phạm vi của Admin.

### Bước 2 — Đăng ký tài khoản Chủ cửa hàng riêng cho lần test

Đăng xuất Admin, tại màn hình đăng nhập chọn **Đăng ký tài khoản mới**, điền họ
tên, email, điện thoại và mật khẩu rồi nhấn **Đăng ký**.

```http
POST /api/v1/auth/register
```

```json
{
  "email": "owner.20260927-01@franchise.local",
  "password": "Admin@123",
  "full_name": "Nguyễn Minh Khôi",
  "phone": "0916882233"
}
```

Mong đợi: thông báo đăng ký thành công và API trả `201 Created`. Quyền
`STORE_OWNER` sẽ được Admin gán tự động khi tạo Store từ hồ sơ đã duyệt.

### Bước 3 — Owner nộp hồ sơ Franchise

Đăng nhập bằng tài khoản vừa đăng ký:

```text
owner.20260927-01@franchise.local / Admin@123
```

Mở **Hồ sơ đăng ký**, nhấn **Nộp hồ sơ**, điền biểu mẫu rồi xác nhận. Frontend
sẽ gửi request:

```http
POST /api/v1/applications
```

```json
{
  "applicant_name": "Nguyễn Minh Khôi",
  "email": "owner.20260927-01@franchise.local",
  "phone": "0916882233",
  "proposed_store_name": "Mộc Miên Coffee Hà Đông",
  "proposed_address": "22 Tố Hữu, phường Hà Cầu, quận Hà Đông, Hà Nội",
  "proposed_area": 135,
  "investment_budget": 2100000000,
  "note": "Mặt bằng gần khu đô thị, có khu vực giao hàng riêng."
}
```

Mong đợi: `201 Created`. Lưu `id` thành `APPLICATION_ID`.

Mở **Hồ sơ đăng ký**, kiểm tra bản ghi có trạng thái `PENDING` (`Chờ xử lý`).

### Bước 4 — Admin duyệt hồ sơ

Đăng xuất Owner, đăng nhập lại Admin. Mở **Hồ sơ đăng ký**, tại dòng hồ sơ vừa
tạo lần lượt nhấn **Thẩm định** rồi **Duyệt**. Frontend thực hiện:

```http
POST /api/v1/applications/{APPLICATION_ID}/start-review
```

Không nhập body. Mong đợi: `204 No Content`.

```http
POST /api/v1/applications/{APPLICATION_ID}/approve
```

```json
{
  "note": "Mặt bằng và phương án đầu tư đáp ứng tiêu chuẩn nhượng quyền."
}
```

Mong đợi: `204 No Content`; trạng thái hồ sơ thành `APPROVED`.

### Bước 5 — Admin tạo Store

Mở **Cửa hàng**, nhấn **Tạo cửa hàng**, chọn hồ sơ đã duyệt và điền thông tin.
Frontend tự gán quyền `STORE_OWNER` cho người đăng ký rồi gọi:

```http
POST /api/v1/stores
```

```json
{
  "application_id": "{APPLICATION_ID}",
  "owner_id": "{OWNER_ID}",
  "code": "HN-HD-009",
  "name": "Mộc Miên Coffee Hà Đông",
  "address": "22 Tố Hữu, phường Hà Cầu, quận Hà Đông, Hà Nội",
  "phone": "02433552233",
  "email": "hadong@mocmien.local"
}
```

Mong đợi: `201 Created`. Trong danh sách **Cửa hàng**, Store đang ở trạng thái
`INACTIVE` (`Chưa hoạt động`).

### Bước 6 — Tạo hợp đồng

Mở **Hợp đồng**, nhấn **Tạo hợp đồng**, chọn Store vừa tạo và điền biểu mẫu.

```http
POST /api/v1/contracts
```

```json
{
  "store_id": "{STORE_ID}",
  "contract_no": "E2E-CONTRACT-20260927-01",
  "signed_date": "2026-09-27",
  "effective_from": "2026-09-01",
  "effective_to": "2027-09-27",
  "royalty_rate": 5,
  "initial_franchise_fee": 100000000,
  "deposit_amount": 20000000,
  "system_fee": 1000000,
  "service_fee": 2000000
}
```

Mong đợi: `201 Created`. Lưu `id` thành `CONTRACT_ID`; trạng thái `DRAFT`.

### Bước 7 — Ghi nhận 20% phí ban đầu và activate Contract

Tại dòng hợp đồng, nhấn **Ghi nhận phí**, nhập khoản thanh toán ban đầu rồi xác
nhận:

```http
POST /api/v1/contracts/{CONTRACT_ID}/financial-transactions
```

```json
{
  "transaction_type": "INITIAL_FEE_PAYMENT",
  "amount": 20000000,
  "transaction_date": "2026-09-27",
  "reference_no": "BANK-20260927-01",
  "note": "Thanh toan 20 phan tram phi ban dau"
}
```

Mong đợi: `201 Created`.

Sau đó nhấn **Kích hoạt**:

```http
POST /api/v1/contracts/{CONTRACT_ID}/activate
```

Không nhập body. Mong đợi: `204 No Content`.

Đối chiếu:

- Contract chuyển thành `ACTIVE`.
- Store chuyển thành `ACTIVE` trong cùng transaction.

### Bước 8 — Admin tạo và kích hoạt Promotion

Mở **Khuyến mãi**, nhấn **Tạo khuyến mãi**, điền biểu mẫu rồi xác nhận:

```http
POST /api/v1/promotions
```

```json
{
  "name": "E2E Promotion 20260927-01",
  "description": "Khuyen mai kiem thu E2E",
  "discount_type": "FIXED_AMOUNT",
  "discount_value": 100000,
  "start_date": "2026-09-27",
  "end_date": "2026-10-04",
  "scope": "ALL_STORES",
  "funding_type": "SHARED",
  "brand_share": 60,
  "store_share": 40,
  "store_ids": []
}
```

Mong đợi: `201 Created`. Lưu `id` thành `PROMOTION_ID`.

```http
POST /api/v1/promotions/{PROMOTION_ID}/activate
```

Mong đợi: `204 No Content`; Promotion thành `ACTIVE`.

### Bước 9 — Owner báo cáo doanh thu ngày

Đăng xuất Admin rồi đăng nhập lại Owner. Mở **Doanh thu**, nhấn **Ghi nhận doanh
thu**, chọn Store/Promotion và điền số tiền.

```http
POST /api/v1/revenues
```

```json
{
  "store_id": "{STORE_ID}",
  "business_date": "2026-09-27",
  "gross_revenue": 10000000,
  "note": "Doanh thu ngay kiem thu E2E",
  "promotion_details": [
    {
      "promotion_id": "{PROMOTION_ID}",
      "discount_amount": 100000
    }
  ]
}
```

Mong đợi: `201 Created`. Lưu `id` thành `REVENUE_ID`; trạng thái `DRAFT`.

Tại dòng doanh thu nháp, nhấn **Gửi duyệt**:

```http
POST /api/v1/revenues/{REVENUE_ID}/submit
```

Mong đợi: `204 No Content`; trạng thái thành `SUBMITTED`.

### Bước 10 — Kế toán duyệt doanh thu

Đăng xuất Owner rồi đăng nhập Kế toán. Mở **Doanh thu**, tại dòng đang chờ duyệt
nhấn **Duyệt** và nhập ghi chú:

```text
accountant@franchise.local / Admin@123
```

```http
POST /api/v1/revenues/{REVENUE_ID}/approve
```

```json
{
  "note": "Da doi chieu doanh thu E2E"
}
```

Mong đợi: `204 No Content`; Revenue thành `APPROVED`.

Đối chiếu Revenue:

```text
Gross Revenue       = 10.000.000
Promotion Discount =    100.000
Net Revenue         =  9.900.000
```

### Bước 11 — Kế toán tạo và phát hành Invoice

Mở **Hóa đơn**, nhấn **Lập hóa đơn**, chọn Store/kỳ phí rồi xác nhận:

```http
POST /api/v1/invoices/generate
```

```json
{
  "store_id": "{STORE_ID}",
  "invoice_no": "E2E-INV-20260927-01",
  "period_month": "2026-09-01",
  "vat_rate": 10
}
```

Mong đợi: `201 Created`. Lưu `id` thành `INVOICE_ID`; trạng thái `DRAFT`.

Tại dòng hóa đơn nháp, nhấn **Phát hành**:

```http
POST /api/v1/invoices/{INVOICE_ID}/issue
```

Mong đợi: `204 No Content`; Invoice thành `ISSUED`.

Nhấn **Tải PDF** để kiểm tra hợp đồng/hóa đơn:

```http
GET /api/v1/invoices/{INVOICE_ID}/pdf
```

Mong đợi: `200 OK`, content type `application/pdf` và trình duyệt tải file.

### Bước 12 — Kế toán ghi nhận thanh toán một phần

Tại dòng hóa đơn đã phát hành, nhấn **Thanh toán**, điền biểu mẫu:

```http
POST /api/v1/invoices/{INVOICE_ID}/payments
```

```json
{
  "payment_no": "E2E-PAY-20260927-01",
  "amount": 1000000,
  "payment_date": "2026-09-27",
  "method": "BANK_TRANSFER",
  "reference_no": "REF-20260927-01"
}
```

Mong đợi: `201 Created`. Lưu `id` thành `PAYMENT_ID`.

Đối chiếu:

- Payment có trạng thái hợp lệ.
- Invoice chuyển thành `PARTIALLY_PAID`.
- `paid_amount` tăng 1.000.000.
- `outstanding_amount` giảm 1.000.000.

### Bước 13 — Owner kiểm tra kết quả

Đăng nhập lại Owner và kiểm tra:

- **Cửa hàng**: Store của owner ở trạng thái `ACTIVE`.
- **Doanh thu**: Revenue ở trạng thái `APPROVED`.
- **Hóa đơn**: Invoice ở trạng thái `PARTIALLY_PAID`.
- **Thanh toán**: có Payment vừa tạo.
- **Thông báo**: có thông báo liên quan hồ sơ, Contract, Invoice hoặc Payment.

Mở **Báo cáo**, chọn từ `MONTH_START` đến `TODAY`, nhấn **Xem báo cáo**, sau
đó thử **Tải CSV** và **Tải Excel**.

### Bước 14 — Admin kiểm tra Audit log

Đăng nhập Admin, mở **Nhật ký hệ thống**:

```http
GET /api/v1/audit-logs?page=1&page_size=100
```

Mong đợi `200 OK`. Kiểm tra có log cho các thao tác chính như tạo User, gán
role, duyệt Application, activate Contract, duyệt Revenue, tạo Invoice và ghi
nhận Payment.

## 4. Kiểm thử RBAC âm

Các bước này chứng minh backend không chỉ ẩn nút trên frontend mà thực sự chặn
request trái quyền.

| Người thực hiện | Request | Kết quả mong đợi |
|---|---|---|
| Owner | `GET /api/v1/audit-logs` | `403 Forbidden` |
| Owner | `POST /api/v1/revenues/{REVENUE_ID}/approve` | `403 Forbidden` |
| Accountant | `POST /api/v1/stores` | `403 Forbidden` |
| Không có token | `GET /api/v1/stores` | `401 Unauthorized` |
| Owner khác | Truy cập PDF Invoice của Store không thuộc sở hữu | `403 Forbidden` |

Các lỗi `401` và `403` ở phần này là kết quả **PASS** của kiểm thử bảo mật.

## 5. Kiểm thử ràng buộc dữ liệu

| Tình huống | Kết quả mong đợi |
|---|---|
| Nộp hai Revenue cùng Store và ngày | `409` hoặc lỗi business tương ứng |
| Activate Contract khi chưa trả đủ 20% Initial Fee | Bị từ chối |
| Payment lớn hơn outstanding amount | Bị từ chối, Invoice không đổi |
| Promotion có `brand_share + store_share != 100` | Bị từ chối |
| `effective_to <= effective_from` | Bị từ chối |
| Gửi UUID không đúng định dạng | `422 Unprocessable Entity` |

Sau mỗi trường hợp lỗi, tải lại danh sách để xác nhận transaction đã rollback và
không để lại dữ liệu dở dang.

## 6. Chạy E2E tự động bằng Postman/Newman

Kịch bản tự động tương ứng đã nằm trong collection và tự tạo Owner riêng cho
mỗi lần chạy:

```bash
bash scripts/dev.sh postman-test
```

Kết quả mong đợi:

```text
requests:   30 executed, 0 failed
assertions: 30 executed, 0 failed
```

Báo cáo JUnit:

```text
reports/postman/postman-junit.xml
```

## 7. Bằng chứng cần lưu cho báo cáo

1. `docker compose ps` thể hiện các service healthy.
2. Dashboard frontend sau khi đăng nhập từng role.
3. Revenue `APPROVED`, Invoice `PARTIALLY_PAID` và Payment vừa tạo.
4. File PDF Invoice và file báo cáo CSV/XLSX.
5. Postman Runner hiển thị `30 Passed`, `0 Failed`, `0 Errors`.
6. Jenkins Test Result và artifact `postman-junit.xml` nếu trình diễn CI.

## 8. Tiêu chí kết luận PASS

- Toàn bộ bước luồng chính trả đúng HTTP status và trạng thái nghiệp vụ.
- Dữ liệu người dùng chỉ hiển thị trong phạm vi được phép.
- Các kiểm thử RBAC âm bị chặn đúng `401/403`.
- Các ràng buộc sai không làm thay đổi dữ liệu.
- PDF, CSV và XLSX tải được.
- Postman/Newman đạt `30/30`.
- Không có response `500 Internal Server Error`.
