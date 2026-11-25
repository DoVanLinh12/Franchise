# Kịch bản test API Franchise trên Postman

Tài liệu này được đối chiếu với các router hiện có trong \`src/backend/app/api/\`. API được chia theo nhóm Swagger: Authentication, Business, Import and Export, System. Mỗi endpoint có ba input mẫu để thử. Với JSON, copy **một object** vào Body → raw → JSON, không gửi cả mảng. Với GET, nhập giá trị ở Params. Thay các ID trong dấu \`<...>\` bằng UUID thật từ response trước đó. Email, điện thoại, tên và mã nghiệp vụ đã có dữ liệu cụ thể.

## Chuẩn bị

- Base URL: \`http://localhost:8000\`.
- Admin: \`admin@franchise.local\` / \`Admin@123\`; Kế toán: \`accountant@franchise.local\` / \`Admin@123\`.
- Chủ cửa hàng tự đăng ký bằng API bên dưới, sau đó đăng nhập lấy Bearer token.
- Ngày mẫu là \`2026-09-28\`. Nếu chạy vào ngày khác, cập nhật ngày cho hợp lệ; doanh thu không được ở tương lai.
- Access token lấy từ response đăng nhập; reset token lấy từ email thật. Các ID trong path/body phải lấy từ response API trước đó.
- Request trả \`204\` không có response body. API không nhận body thì để Body trống.

# 1. Authentication

## POST /api/v1/auth/register — chủ cửa hàng đăng ký

\`\`\`json
{"email":"owner.hadong.01@mocmien.local","password":"Owner@12345","full_name":"Nguyễn Minh Khôi","phone":"0916882233"}
\`\`\`
\`\`\`json
{"email":"owner.bachmai.02@mocmien.local","password":"Owner@12345","full_name":"Trần Ngọc Mai","phone":"0938123456"}
\`\`\`
\`\`\`json
{"email":"owner.thaodien.03@mocmien.local","password":"Owner@12345","full_name":"Phạm Quốc Bảo","phone":"0909123456"}
\`\`\`

## POST /api/v1/auth/login — đăng nhập JSON

\`\`\`json
{"email":"admin@franchise.local","password":"Admin@123"}
\`\`\`
\`\`\`json
{"email":"accountant@franchise.local","password":"Admin@123"}
\`\`\`
\`\`\`json
{"email":"owner.hadong.01@mocmien.local","password":"Owner@12345"}
\`\`\`

## POST /api/v1/auth/password-reset/request

\`\`\`json
{"email":"admin@franchise.local"}
\`\`\`
\`\`\`json
{"email":"accountant@franchise.local"}
\`\`\`
\`\`\`json
{"email":"owner.hadong.01@mocmien.local"}
\`\`\`

Muốn nhận email trong local, bật cấu hình worker/email; mở MailHog tại \`http://localhost:8025\` để xem thư.

## POST /api/v1/auth/password-reset/confirm

Mỗi token chỉ dùng một lần; lấy token tương ứng từ email MailHog.

\`\`\`json
{"token":"<token trong email Admin>","new_password":"AdminNew@123"}
\`\`\`
\`\`\`json
{"token":"<token trong email Kế toán>","new_password":"AccountantNew@123"}
\`\`\`
\`\`\`json
{"token":"<token trong email Chủ cửa hàng>","new_password":"OwnerNew@123"}
\`\`\`

## GET /api/v1/auth/me

Không có body. Gọi ba lần với Bearer token của Admin, Kế toán, Chủ cửa hàng.

## PATCH /api/v1/auth/users/{user_id}/status

Admin; thay user_id bằng UUID user thật. Trạng thái hợp lệ: ACTIVE hoặc INACTIVE.

\`\`\`json
{"status":"INACTIVE","reason":"Tạm ngưng tài khoản trong thời gian kiểm thử."}
\`\`\`
\`\`\`json
{"status":"ACTIVE","reason":"Kích hoạt lại tài khoản sau khi kiểm thử."}
\`\`\`

## POST /api/v1/auth/users/{user_id}/roles

Admin; chỉ gán role chưa có cho user test.

\`\`\`json
{"role":"STORE_OWNER"}
\`\`\`
\`\`\`json
{"role":"ACCOUNTANT"}
\`\`\`
\`\`\`json
{"role":"ADMIN"}
\`\`\`

## DELETE /api/v1/auth/users/{user_id}/roles/{role_code}

Admin, không có body. Ba path mẫu: \`/users/<user_id>/roles/STORE_OWNER\`, \`/users/<user_id>/roles/ACCOUNTANT\`, \`/users/<user_id>/roles/ADMIN\`. Chỉ dùng user test; tránh tự gỡ quyền Admin đang đăng nhập.

# 2. Business

## Hồ sơ đăng ký

### POST /api/v1/applications — chủ cửa hàng nộp hồ sơ

\`\`\`json
{"applicant_name":"Nguyễn Minh Khôi","email":"owner.hadong.01@mocmien.local","phone":"0916882233","proposed_store_name":"Mộc Miên Hà Đông","proposed_address":"15 Trần Phú, Hà Đông, Hà Nội","proposed_area":95,"investment_budget":1800000000,"note":"Mặt bằng gần khu dân cư và trường học."}
\`\`\`
\`\`\`json
{"applicant_name":"Trần Ngọc Mai","email":"owner.bachmai.02@mocmien.local","phone":"0938123456","proposed_store_name":"Mộc Miên Bạch Mai","proposed_address":"88 Bạch Mai, Hai Bà Trưng, Hà Nội","proposed_area":82,"investment_budget":1550000000,"note":"Đã khảo sát lưu lượng khách giờ cao điểm."}
\`\`\`
\`\`\`json
{"applicant_name":"Phạm Quốc Bảo","email":"owner.thaodien.03@mocmien.local","phone":"0909123456","proposed_store_name":"Mộc Miên Thảo Điền","proposed_address":"25 Xuân Thủy, Thảo Điền, TP. Thủ Đức","proposed_area":110,"investment_budget":2100000000,"note":"Dự kiến khai trương sau khi hoàn thiện nội thất."}
\`\`\`

### GET /api/v1/applications — tìm/lọc hồ sơ

Nhập trong Params, từng dòng là một lần test:

\`\`\`text
search=Mộc Miên Hà Đông; status=PENDING; page=1; page_size=20
\`\`\`
\`\`\`text
search=Trần Ngọc Mai; status=UNDER_REVIEW; page=1; page_size=30
\`\`\`
\`\`\`text
search=Mộc Miên Thảo Điền; status=APPROVED; page=1; page_size=50
\`\`\`

### POST /api/v1/applications/{application_id}/withdraw

\`\`\`json
{"reason":"Chưa thu xếp được vốn đầu tư trong thời gian này."}
\`\`\`
\`\`\`json
{"reason":"Mặt bằng dự kiến không đạt điều kiện kinh doanh."}
\`\`\`
\`\`\`json
{"reason":"Xin rút hồ sơ để cập nhật lại phương án địa điểm."}
\`\`\`

### POST /api/v1/applications/{application_id}/start-review

Admin; không có body. Dùng lần lượt ID hồ sơ Hà Đông, Bạch Mai, Thảo Điền.

### POST /api/v1/applications/{application_id}/approve

Admin; mỗi hồ sơ cần ở trạng thái đang duyệt.

\`\`\`json
{"note":"Đã thẩm định mặt bằng và năng lực tài chính, hồ sơ đạt yêu cầu."}
\`\`\`
\`\`\`json
{"note":"Đã xác minh thông tin ứng viên và kế hoạch đầu tư."}
\`\`\`
\`\`\`json
{"note":"Địa điểm phù hợp tiêu chuẩn khu vực kinh doanh."}
\`\`\`

### POST /api/v1/applications/{application_id}/reject

Admin; hồ sơ cần đang được duyệt.

\`\`\`json
{"reason":"Diện tích mặt bằng chưa đạt tiêu chuẩn tối thiểu."}
\`\`\`
\`\`\`json
{"reason":"Hồ sơ chứng minh năng lực tài chính chưa đầy đủ."}
\`\`\`
\`\`\`json
{"reason":"Địa điểm đề xuất nằm ngoài khu vực được quy hoạch."}
\`\`\`

## Cửa hàng

### POST /api/v1/stores — Admin tạo cửa hàng từ hồ sơ đã duyệt

Thay application_id, owner_id bằng UUID thật (owner_id lấy từ đăng ký tài khoản).

\`\`\`json
{"application_id":"<application_id Hà Đông>","owner_id":"<owner_id Hà Đông>","code":"MM-HN-HD-001","name":"Mộc Miên Hà Đông","address":"15 Trần Phú, Hà Đông, Hà Nội","phone":"0916882233","email":"owner.hadong.01@mocmien.local"}
\`\`\`
\`\`\`json
{"application_id":"<application_id Bạch Mai>","owner_id":"<owner_id Bạch Mai>","code":"MM-HN-BM-002","name":"Mộc Miên Bạch Mai","address":"88 Bạch Mai, Hai Bà Trưng, Hà Nội","phone":"0938123456","email":"owner.bachmai.02@mocmien.local"}
\`\`\`
\`\`\`json
{"application_id":"<application_id Thảo Điền>","owner_id":"<owner_id Thảo Điền>","code":"MM-HCM-TD-003","name":"Mộc Miên Thảo Điền","address":"25 Xuân Thủy, Thảo Điền, TP. Thủ Đức","phone":"0909123456","email":"owner.thaodien.03@mocmien.local"}
\`\`\`

### GET /api/v1/stores

\`\`\`text
search=MM-HN-HD-001; status=ACTIVE; page=1; page_size=20
\`\`\`
\`\`\`text
search=Mộc Miên Bạch Mai; status=ACTIVE; page=1; page_size=30
\`\`\`
\`\`\`text
search=Thảo Điền; status=ACTIVE; page=1; page_size=50
\`\`\`

## Hợp đồng

### POST /api/v1/contracts — Admin tạo hợp đồng nháp

\`\`\`json
{"store_id":"<store_id Hà Đông>","contract_no":"HD-MOCMIEN-2026-001","signed_date":"2026-09-28","effective_from":"2026-10-01","effective_to":"2031-09-30","royalty_rate":5,"initial_franchise_fee":300000000,"deposit_amount":100000000,"system_fee":3000000,"service_fee":2000000}
\`\`\`
\`\`\`json
{"store_id":"<store_id Bạch Mai>","contract_no":"HD-MOCMIEN-2026-002","signed_date":"2026-09-28","effective_from":"2026-10-01","effective_to":"2031-09-30","royalty_rate":4.5,"initial_franchise_fee":280000000,"deposit_amount":90000000,"system_fee":3000000,"service_fee":2500000}
\`\`\`
\`\`\`json
{"store_id":"<store_id Thảo Điền>","contract_no":"HD-MOCMIEN-2026-003","signed_date":"2026-09-28","effective_from":"2026-10-15","effective_to":"2031-10-14","royalty_rate":5,"initial_franchise_fee":350000000,"deposit_amount":120000000,"system_fee":3500000,"service_fee":3000000}
\`\`\`

### GET /api/v1/contracts

\`\`\`text
search=HD-MOCMIEN-2026-001; status=DRAFT; page=1; page_size=20
\`\`\`
\`\`\`text
search=HD-MOCMIEN-2026-002; status=ACTIVE; page=1; page_size=30
\`\`\`
\`\`\`text
search=HD-MOCMIEN-2026-003; status=DRAFT; page=1; page_size=50
\`\`\`

### POST /api/v1/contracts/{contract_id}/financial-transactions

transaction_type: INITIAL_FEE_PAYMENT hoặc DEPOSIT_PAYMENT. Để kích hoạt hợp đồng, cần thanh toán tối thiểu 20% phí nhượng quyền ban đầu.

\`\`\`json
{"transaction_type":"INITIAL_FEE_PAYMENT","amount":80000000,"transaction_date":"2026-09-28","reference_no":"UNC-MB-20260928-001","note":"Đợt 1 phí nhượng quyền Hà Đông."}
\`\`\`
\`\`\`json
{"transaction_type":"DEPOSIT_PAYMENT","amount":90000000,"transaction_date":"2026-09-28","reference_no":"UNC-MB-20260928-002","note":"Tiền đặt cọc hợp đồng Bạch Mai."}
\`\`\`
\`\`\`json
{"transaction_type":"INITIAL_FEE_PAYMENT","amount":100000000,"transaction_date":"2026-09-28","reference_no":"UNC-VTB-20260928-003","note":"Đợt 1 phí nhượng quyền Thảo Điền."}
\`\`\`

### POST /api/v1/contracts/{contract_id}/activate

Admin; không có body. Dùng ID hợp đồng tương ứng; chỉ thành công khi thỏa điều kiện thanh toán và thời hạn.

## Khuyến mãi

### POST /api/v1/promotions

discount_type: PERCENTAGE/FIXED_AMOUNT; scope: ALL_STORES/SELECTED_STORES; funding_type: BRAND/STORE/SHARED; brand_share + store_share phải bằng 100. Với SELECTED_STORES, điền store_ids bằng ID thật.

\`\`\`json
{"name":"Khai trương Mộc Miên tháng 10","description":"Giảm giá tuần khai trương.","discount_type":"PERCENTAGE","discount_value":15,"start_date":"2026-10-01","end_date":"2026-10-31","scope":"ALL_STORES","funding_type":"SHARED","brand_share":60,"store_share":40,"store_ids":[]}
\`\`\`
\`\`\`json
{"name":"Ưu đãi khách hàng thân thiết","description":"Ưu đãi hóa đơn từ 300.000 đồng.","discount_type":"FIXED_AMOUNT","discount_value":30000,"start_date":"2026-10-01","end_date":"2026-11-30","scope":"SELECTED_STORES","funding_type":"BRAND","brand_share":100,"store_share":0,"store_ids":["<store_id Hà Đông>"]}
\`\`\`
\`\`\`json
{"name":"Cuối tuần cùng Mộc Miên","description":"Ưu đãi cuối tuần tại cửa hàng tham gia.","discount_type":"PERCENTAGE","discount_value":10,"start_date":"2026-10-03","end_date":"2026-12-31","scope":"SELECTED_STORES","funding_type":"STORE","brand_share":0,"store_share":100,"store_ids":["<store_id Bạch Mai>","<store_id Thảo Điền>"]}
\`\`\`

### GET /api/v1/promotions

\`\`\`text
search=Khai trương; status=DRAFT; page=1; page_size=20
\`\`\`
\`\`\`text
search=khách hàng thân thiết; status=ACTIVE; page=1; page_size=30
\`\`\`
\`\`\`text
search=Cuối tuần; status=CANCELLED; page=1; page_size=50
\`\`\`

### POST /api/v1/promotions/{promotion_id}/activate

Không có body; thay ID chương trình khuyến mãi thật.

### POST /api/v1/promotions/{promotion_id}/cancel

\`\`\`json
{"reason":"Kết thúc chương trình theo kế hoạch."}
\`\`\`
\`\`\`json
{"reason":"Điều chỉnh ngân sách marketing quý IV."}
\`\`\`
\`\`\`json
{"reason":"Dừng ưu đãi tại các cửa hàng tham gia."}
\`\`\`

### DELETE /api/v1/promotions/{promotion_id} — xóa mềm

\`\`\`json
{"reason":"Tạo nhầm chương trình, chưa phát sinh giao dịch."}
\`\`\`
\`\`\`json
{"reason":"Chương trình trùng nội dung với kế hoạch đã duyệt."}
\`\`\`
\`\`\`json
{"reason":"Dữ liệu thử nghiệm không còn sử dụng."}
\`\`\`

Không xóa chương trình đang ACTIVE; hủy trước nếu trạng thái cho phép.

## Doanh thu

### POST /api/v1/revenues — chủ cửa hàng tạo doanh thu nháp

promotion_details để [] nếu không áp dụng khuyến mãi. Nếu có, cần promotion_id thật đang áp dụng cho cửa hàng.

\`\`\`json
{"store_id":"<store_id Hà Đông>","business_date":"2026-09-28","gross_revenue":18650000,"note":"Doanh thu bán hàng trong ngày.","promotion_details":[]}
\`\`\`
\`\`\`json
{"store_id":"<store_id Bạch Mai>","business_date":"2026-09-28","gross_revenue":22400000,"note":"Doanh thu đã đối chiếu POS.","promotion_details":[]}
\`\`\`
\`\`\`json
{"store_id":"<store_id Thảo Điền>","business_date":"2026-09-28","gross_revenue":31280000,"note":"Doanh thu ca sáng và ca tối.","promotion_details":[]}
\`\`\`

### PUT /api/v1/revenues/{revenue_id} — cập nhật doanh thu còn được sửa

\`\`\`json
{"store_id":"<store_id Hà Đông>","business_date":"2026-09-28","gross_revenue":18900000,"note":"Cập nhật sau khi đối soát POS.","promotion_details":[]}
\`\`\`
\`\`\`json
{"store_id":"<store_id Bạch Mai>","business_date":"2026-09-28","gross_revenue":22600000,"note":"Bổ sung giao dịch cuối ngày.","promotion_details":[]}
\`\`\`
\`\`\`json
{"store_id":"<store_id Thảo Điền>","business_date":"2026-09-28","gross_revenue":31000000,"note":"Điều chỉnh theo biên bản kiểm quỹ.","promotion_details":[]}
\`\`\`

### GET /api/v1/revenues

\`\`\`text
status=DRAFT; page=1; page_size=20
\`\`\`
\`\`\`text
status=SUBMITTED; page=1; page_size=30
\`\`\`
\`\`\`text
status=APPROVED; page=1; page_size=50
\`\`\`

### POST /api/v1/revenues/{revenue_id}/submit

Không có body; dùng ID doanh thu nháp.

### POST /api/v1/revenues/{revenue_id}/approve — kế toán duyệt

\`\`\`json
{"note":"Đã đối chiếu với báo cáo POS Hà Đông."}
\`\`\`
\`\`\`json
{"note":"Số liệu Bạch Mai khớp bảng kê bán hàng."}
\`\`\`
\`\`\`json
{"note":"Đã kiểm tra doanh thu Thảo Điền."}
\`\`\`

### POST /api/v1/revenues/{revenue_id}/reject — kế toán từ chối

\`\`\`json
{"reason":"Thiếu báo cáo POS đính kèm cho ngày đối soát."}
\`\`\`
\`\`\`json
{"reason":"Tổng doanh thu không khớp bảng kê giao dịch."}
\`\`\`
\`\`\`json
{"reason":"Cần kiểm tra lại giao dịch hoàn tiền trong ngày."}
\`\`\`

### POST /api/v1/revenues/{revenue_id}/request-adjustment

\`\`\`json
{"reason":"Vui lòng giải trình khoản hoàn tiền 450.000 đồng."}
\`\`\`
\`\`\`json
{"reason":"Đối chiếu doanh thu tiền mặt với biên bản kiểm quỹ."}
\`\`\`
\`\`\`json
{"reason":"Bổ sung chi tiết khuyến mãi đã áp dụng."}
\`\`\`

## Billing và hóa đơn

### POST /api/v1/billing-adjustments?store_id=<store_id>

store_id là query parameter, JSON là Body. amount phải khác 0.

\`\`\`json
{"source_period":"2026-09-01","amount":-250000,"reason":"Điều chỉnh giảm do ghi nhận thừa phí dịch vụ tháng 9."}
\`\`\`
\`\`\`json
{"source_period":"2026-09-01","amount":450000,"reason":"Bổ sung phí phát sinh đã được xác nhận."}
\`\`\`
\`\`\`json
{"source_period":"2026-08-01","amount":-120000,"reason":"Điều chỉnh chênh lệch sau đối soát kỳ trước."}
\`\`\`

### POST /api/v1/invoices/generate — kế toán lập hóa đơn

\`\`\`json
{"store_id":"<store_id Hà Đông>","invoice_no":"MM-INV-2026-09-HD-001","period_month":"2026-09-01","vat_rate":10}
\`\`\`
\`\`\`json
{"store_id":"<store_id Bạch Mai>","invoice_no":"MM-INV-2026-09-BM-002","period_month":"2026-09-01","vat_rate":10}
\`\`\`
\`\`\`json
{"store_id":"<store_id Thảo Điền>","invoice_no":"MM-INV-2026-09-TD-003","period_month":"2026-09-01","vat_rate":8}
\`\`\`

### GET /api/v1/invoices

\`\`\`text
search=MM-INV-2026-09-HD-001; status=DRAFT; page=1; page_size=20
\`\`\`
\`\`\`text
search=MM-INV-2026-09-BM-002; status=ISSUED; page=1; page_size=30
\`\`\`
\`\`\`text
search=MM-INV-2026-09-TD-003; status=PARTIALLY_PAID; page=1; page_size=50
\`\`\`

### POST /api/v1/invoices/{invoice_id}/issue

Kế toán phát hành hóa đơn nháp; không có body.

### POST /api/v1/invoices/{invoice_id}/cancel

\`\`\`json
{"reason":"Hóa đơn lập nhầm kỳ, chưa có thanh toán."}
\`\`\`
\`\`\`json
{"reason":"Thông tin cửa hàng trên hóa đơn cần được lập lại."}
\`\`\`
\`\`\`json
{"reason":"Điều chỉnh hồ sơ phí trước khi phát hành lại."}
\`\`\`

Không hủy hóa đơn đã có thanh toán xác nhận.

### POST /api/v1/invoices/{invoice_id}/payments — ghi nhận thanh toán

method: BANK_TRANSFER, CASH hoặc OTHER. amount không được vượt dư nợ.

\`\`\`json
{"payment_no":"MM-PAY-2026-09-HD-001","amount":1250000,"payment_date":"2026-09-28","method":"BANK_TRANSFER","reference_no":"VCB-20260928-001"}
\`\`\`
\`\`\`json
{"payment_no":"MM-PAY-2026-09-BM-002","amount":1680000,"payment_date":"2026-09-28","method":"BANK_TRANSFER","reference_no":"BIDV-20260928-002"}
\`\`\`
\`\`\`json
{"payment_no":"MM-PAY-2026-09-TD-003","amount":2100000,"payment_date":"2026-09-28","method":"CASH","reference_no":"PT-20260928-003"}
\`\`\`

### GET /api/v1/payments

\`\`\`text
search=MM-PAY-2026-09-HD-001; status=CONFIRMED; page=1; page_size=20
\`\`\`
\`\`\`text
search=MM-PAY-2026-09-BM-002; status=CONFIRMED; page=1; page_size=30
\`\`\`
\`\`\`text
search=MM-PAY-2026-09-TD-003; status=REVERSED; page=1; page_size=50
\`\`\`

### POST /api/v1/payments/{payment_id}/reverse

\`\`\`json
{"reason":"Giao dịch chuyển khoản bị ngân hàng hoàn trả."}
\`\`\`
\`\`\`json
{"reason":"Nhập nhầm số tiền, cần đảo giao dịch để ghi nhận lại."}
\`\`\`
\`\`\`json
{"reason":"Thanh toán hạch toán nhầm vào hóa đơn này."}
\`\`\`

## Thông báo, vận hành, nhật ký, báo cáo

### GET /api/v1/notifications

\`\`\`text
page=1; page_size=20
\`\`\`
\`\`\`text
page=1; page_size=50
\`\`\`
\`\`\`text
page=2; page_size=100
\`\`\`

### PATCH /api/v1/notifications/{notification_id}/read

Không có body; dùng ID thông báo của user hiện tại.

### POST /api/v1/operations/generate-alerts

Admin; không có input/body. Gọi sau khi có cửa hàng thiếu báo cáo để sinh cảnh báo.

### GET /api/v1/audit-logs

Chỉ Admin. search là từ khóa hành động; page/page_size là phân trang.

\`\`\`text
search=CREATE; page=1; page_size=20
\`\`\`
\`\`\`text
search=APPROVE; page=1; page_size=50
\`\`\`
\`\`\`text
search=LOGIN; page=2; page_size=100
\`\`\`

### GET /api/v1/reports/financial-summary

Params ngày dạng YYYY-MM-DD.

\`\`\`text
period_from=2026-09-01; period_to=2026-09-28
\`\`\`
\`\`\`text
period_from=2026-08-01; period_to=2026-09-28
\`\`\`
\`\`\`text
period_from=2026-01-01; period_to=2026-09-28
\`\`\`

# 3. Import and Export

## GET /api/v1/contracts/{contract_id}/pdf

Không body; đổi contract_id trong URL thành ID thật. Thử với hợp đồng Hà Đông, Bạch Mai, Thảo Điền. Postman nhận binary; dùng Save Response để lưu PDF.

## GET /api/v1/invoices/{invoice_id}/pdf

Không body; thay invoice_id bằng ID hóa đơn thật của từng cửa hàng.

## GET /api/v1/reports/financial-summary/export

Params:

\`\`\`text
period_from=2026-09-01; period_to=2026-09-28; format=csv
\`\`\`
\`\`\`text
period_from=2026-08-01; period_to=2026-09-28; format=xlsx
\`\`\`
\`\`\`text
period_from=2026-01-01; period_to=2026-09-28; format=csv
\`\`\`

## POST /api/v1/revenues/import

Body → form-data; key \`file\`, type File, chọn một tệp CSV/XLSX. Không tự đặt Content-Type; Postman thêm multipart boundary. Cột bắt buộc: store_id,business_date,gross_revenue,note. Lưu mỗi mẫu sau thành file CSV riêng UTF-8; dùng store ID thật và ngày chưa có báo cáo trùng.

\`\`\`csv
store_id,business_date,gross_revenue,note
<store_id Hà Đông>,2026-09-27,18450000,Doanh thu ngày 27/09
\`\`\`
\`\`\`csv
store_id,business_date,gross_revenue,note
<store_id Bạch Mai>,2026-09-26,21600000,Doanh thu ngày 26/09
\`\`\`
\`\`\`csv
store_id,business_date,gross_revenue,note
<store_id Thảo Điền>,2026-09-25,29800000,Doanh thu ngày 25/09
\`\`\`

# 4. System

## GET /health

Không có input/body. Gọi thử ba lần; kết quả mong đợi HTTP 200, \`{"status":"ok"}\`.

## GET /health/ready

Không có input/body. Kiểm tra API, PostgreSQL và Redis; mong đợi HTTP 200 cùng trạng thái ready.

# Trình tự E2E gợi ý

1. Đăng ký ba chủ cửa hàng, đăng nhập từng tài khoản, gửi hồ sơ.
2. Đăng nhập Admin: xem hồ sơ → start-review → approve → tạo store.
3. Admin tạo hợp đồng → ghi giao dịch phí/đặt cọc đủ điều kiện → activate → tải PDF hợp đồng.
4. Chủ cửa hàng ghi doanh thu → submit. Kế toán approve/reject/request-adjustment.
5. Kế toán lập hóa đơn → issue → ghi thanh toán → tải PDF hóa đơn.
6. Kiểm tra báo cáo, CSV/XLSX, notifications, audit log và cảnh báo.

Các mẫu ba lần là ba input thay thế để test trên ba bản ghi/lần chạy. Không chạy ba mẫu trạng thái liên tiếp trên cùng một ID nếu thao tác trước đã làm đổi trạng thái; ví dụ một hồ sơ đã approve thì không thể approve lại.
