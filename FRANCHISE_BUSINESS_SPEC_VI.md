# FRANCHISE MANAGEMENT — ĐẶC TẢ NGHIỆP VỤ BACKEND/API

> Tài liệu này tổng hợp **toàn bộ nghiệp vụ đã chốt đến hiện tại** của đề tài Franchise Management.
>
> Phạm vi hiện tại chỉ tập trung vào **nghiệp vụ Backend + API**. Không mô tả kiến trúc kỹ thuật, ORM, Stored Procedure, frontend hoặc cách tổ chức source code.
>
> Những nội dung chưa chốt được gom riêng ở cuối tài liệu trong mục **“Các vấn đề cần thảo luận tiếp”** để tránh triển khai sớm rồi phải sửa lại.

---

# 1. Mục tiêu hệ thống

Hệ thống phục vụ phía **Brand/Franchisor** để quản lý vòng đời của các cửa hàng nhượng quyền, bao gồm:

- đăng ký tài khoản;
- nộp hồ sơ xin nhượng quyền;
- xét duyệt hồ sơ;
- tạo cửa hàng sau khi hồ sơ được duyệt;
- quản lý hợp đồng nhượng quyền;
- báo cáo doanh thu hằng ngày;
- duyệt và điều chỉnh doanh thu;
- tự động tổng hợp doanh thu theo tháng;
- tính phí nhượng quyền định kỳ;
- quản lý chương trình khuyến mãi do Brand phát hành;
- tính phần chi phí khuyến mãi Brand hỗ trợ;
- lập hóa đơn phí nhượng quyền theo tháng;
- tính VAT;
- ghi nhận thanh toán;
- theo dõi công nợ;
- cảnh báo chậm báo doanh thu;
- gửi thông báo;
- lưu audit log;
- báo cáo và xuất dữ liệu.

Luồng tổng quát:

```text
User đăng ký tài khoản
→ Đăng nhập
→ Gửi Franchise Application
→ Admin xét duyệt
→ APPROVED
→ Tạo Store
→ Tạo/Kích hoạt Contract
→ Store ACTIVE
→ Báo Revenue hằng ngày
→ Accountant duyệt Revenue
→ Tổng hợp tháng
→ Tính Royalty
→ Tính Promotion Support
→ Tạo Monthly Invoice
→ Tính VAT
→ Ghi nhận Payment
→ Theo dõi Outstanding
→ Notification / Audit / Report
```

---

# 2. Phạm vi KHÔNG làm

Đề tài không mở rộng sang:

- POS;
- quản lý sản phẩm;
- quản lý kho;
- đơn hàng;
- khách hàng cuối;
- CRM;
- payroll;
- ERP;
- payment gateway;
- cổng thanh toán online;
- tích hợp hóa đơn điện tử với cơ quan thuế;
- chữ ký số;
- multi-company SaaS;
- microservices.

Invoice trong hệ thống được hiểu là **chứng từ quản lý nghĩa vụ phí franchise nội bộ**, có VAT theo business rule của đề tài nhưng không phải hệ thống hóa đơn điện tử pháp lý.

---

# 3. Vai trò

Có 3 vai trò chính:

```text
ADMIN
STORE_OWNER
ACCOUNTANT
```

## 3.1 ADMIN

Admin phụ trách:

- xem toàn bộ dữ liệu trong hệ thống;
- xét duyệt Franchise Application;
- tạo Store từ Application đã được duyệt;
- quản lý Contract;
- tạo và quản lý Promotion;
- quản lý User/RBAC;
- xem báo cáo toàn hệ thống;
- xem audit log;
- theo dõi Revenue, Invoice, Payment, công nợ.

Admin **không mặc định thực hiện nghiệp vụ duyệt Revenue**. Nghiệp vụ duyệt Revenue thuộc Accountant để phân tách trách nhiệm.

## 3.2 STORE_OWNER

Store Owner được:

- xem Store của mình;
- xem Contract của Store mình;
- tạo Revenue hằng ngày;
- sửa Revenue ở trạng thái cho phép;
- submit Revenue;
- xem lịch sử Revenue;
- xem Promotion áp dụng cho Store mình;
- xem Invoice;
- xem Payment;
- xem công nợ;
- nhận Notification.

Store Owner chỉ được thao tác trên Store mà mình sở hữu.

Một User có thể sở hữu nhiều Store.

## 3.3 ACCOUNTANT

Accountant phụ trách:

- xem Revenue toàn hệ thống;
- approve Revenue;
- reject Revenue;
- yêu cầu điều chỉnh Revenue đã duyệt;
- kiểm tra số liệu tháng;
- lập/kiểm tra Invoice;
- phát hành Invoice;
- ghi nhận Payment;
- reverse Payment nhập sai;
- theo dõi công nợ;
- xem báo cáo tài chính.

Người báo Revenue không được tự approve Revenue đó.

---

# 4. Tài khoản và trạng thái hoạt động

Cần phân biệt rõ:

```text
User ACTIVE
≠ Store ACTIVE
≠ Contract ACTIVE
```

- `User ACTIVE`: được phép đăng nhập.
- `Store ACTIVE`: cửa hàng đang được phép vận hành nghiệp vụ.
- `Contract ACTIVE`: hợp đồng nhượng quyền đang có hiệu lực.

User có thể đăng nhập ngay cả khi chưa có Store ACTIVE, ví dụ để:

- gửi Franchise Application;
- theo dõi trạng thái hồ sơ;
- xem thông báo.

---

# 5. Franchise Application

## 5.1 Ý nghĩa

`FranchiseApplication` là hồ sơ xin tham gia nhượng quyền.

Application **không phải Store**.

Store chỉ được tạo sau khi Application được duyệt.

## 5.2 Thông tin chính

Application dự kiến có:

```text
id
applicant_id
applicant_name
email
phone

proposed_store_name
proposed_address
proposed_area
investment_budget

note

status

review_note
reviewed_by
reviewed_at

created_at
updated_at
deleted_at
```

## 5.3 Trạng thái

```text
PENDING
→ UNDER_REVIEW
→ APPROVED
```

hoặc:

```text
PENDING
→ UNDER_REVIEW
→ REJECTED
```

Ngoài ra bổ sung:

```text
PENDING / UNDER_REVIEW
→ WITHDRAWN
```

`WITHDRAWN` dùng khi người đăng ký chủ động rút hồ sơ.

## 5.4 Quy tắc

- Application mới có trạng thái `PENDING`.
- Chỉ Admin được chuyển sang `UNDER_REVIEW`.
- Chỉ Admin được `APPROVE` hoặc `REJECT`.
- Khi approve/reject phải lưu người xét duyệt và thời điểm xét duyệt.
- `REJECTED` nên bắt buộc có lý do.
- `WITHDRAWN` không bị xóa khỏi lịch sử.
- Application đã `REJECTED` không sinh Store.
- Application đã `APPROVED` mới được dùng để tạo Store.
- Một Application chỉ được sinh tối đa một Store.

## 5.5 Một User được có bao nhiêu Application đang mở?

Chốt:

> Một User chỉ được có **một hồ sơ chưa kết thúc tại một thời điểm**.

Hồ sơ chưa kết thúc gồm:

```text
PENDING
UNDER_REVIEW
APPROVED nhưng chưa tạo Store
```

Nếu hồ sơ cũ đã:

```text
REJECTED
WITHDRAWN
```

thì User được tạo hồ sơ mới.

## 5.6 Application trùng địa chỉ

Không chặn cứng chỉ vì trùng địa chỉ.

Lý do:

- trung tâm thương mại có thể có nhiều kiosk cùng địa chỉ;
- một tòa nhà có nhiều tầng;
- cùng khu vực có thể tồn tại nhiều vị trí kinh doanh.

Trùng địa chỉ chỉ là tín hiệu để Admin kiểm tra thêm.

---

# 6. Tạo Store

## 6.1 Điều kiện

Store chỉ được tạo từ:

```text
Application.status = APPROVED
```

Approve Application **không tự động sinh Store**.

Luồng:

```text
Application APPROVED
→ Admin kiểm tra thông tin cuối cùng
→ Tạo Store
→ Store INACTIVE
```

## 6.2 Lý do không tự sinh Store

Thông tin trên Application có thể chỉ là thông tin đề xuất:

```text
Tên dự kiến
Địa chỉ dự kiến
Khu vực dự kiến
```

Trong khi Store chính thức cần:

```text
Mã Store
Tên Store chính thức
Địa chỉ chính thức
Owner chính thức
```

## 6.3 Trạng thái Store

```text
INACTIVE
ACTIVE
SUSPENDED
CLOSED
```

Hiện tại rule đã đủ rõ nhất cho:

```text
INACTIVE
→ ACTIVE
```

`SUSPENDED` và `CLOSED` để thảo luận chi tiết sau.

## 6.4 Thông tin chính

```text
id
code
name

owner_id
application_id

address
phone
email

status

activated_at
closed_at

created_at
updated_at
deleted_at
```

---

# 7. Contract — phần đã đủ để dùng cho các nghiệp vụ khác

Contract là dependency bắt buộc cho:

- Store activation;
- royalty rate;
- system fee;
- service fee;
- initial franchise fee;
- deposit;
- thời gian hiệu lực.

## 7.1 Thông tin tối thiểu cần có

```text
id
contract_no
store_id

signed_date
effective_from
effective_to

royalty_rate

initial_franchise_fee
deposit_amount
system_fee
service_fee

status

created_at
updated_at
```

## 7.2 Trạng thái cơ bản

```text
DRAFT
ACTIVE
EXPIRED
TERMINATED
CANCELLED
```

## 7.3 Activation

Store mới tạo có trạng thái:

```text
INACTIVE
```

Khi Contract đủ điều kiện và được kích hoạt:

```text
Contract = ACTIVE
```

thì Store mới được chuyển:

```text
Store = ACTIVE
```

Chi tiết gia hạn/chấm dứt/thay đổi điều khoản vẫn để thảo luận sau.

---

# 8. Các loại phí franchise

Có 5 nhóm chính:

## 8.1 Initial Franchise Fee

Phí nhượng quyền ban đầu.

Đã chốt:

```text
20% thanh toán trước khi Store được kích hoạt
80% còn lại trả góp
```

Số kỳ trả góp của 80% còn lại **chưa chốt chính thức**.

## 8.2 Deposit

Tiền đặt cọc.

Không hard-code một số tiền chung.

Mỗi Contract có:

```text
deposit_amount
```

Logic hoàn cọc dự kiến:

```text
refundable_deposit
=
MAX(deposit_amount - outstanding_debt, 0)
```

Nếu công nợ lớn hơn tiền cọc:

```text
refund = 0
```

và Store vẫn còn nợ phần chênh lệch.

## 8.3 System Fee

Phí hệ thống cố định theo kỳ.

## 8.4 Service Fee

Phí chăm sóc/hỗ trợ cố định theo kỳ.

## 8.5 Royalty Fee

Phí nhượng quyền định kỳ theo phần trăm doanh thu.

```text
royalty_fee
=
monthly_approved_gross_revenue
× royalty_rate
```

---

# 9. Revenue — báo doanh thu hằng ngày

## 9.1 Nguyên tắc

Store Owner báo Revenue theo từng ngày.

Không nhập Revenue tháng bằng tay.

Backend tổng hợp doanh thu tháng từ Revenue ngày đã được APPROVED.

## 9.2 Thông tin Revenue

```text
id
store_id
business_date

gross_revenue
promotion_discount
net_revenue

status

reported_by
reported_at

note

created_at
updated_at
```

## 9.3 Ý nghĩa các số tiền

```text
gross_revenue
= doanh thu trước giảm giá
```

```text
promotion_discount
= tổng số tiền giảm giá từ tất cả Promotion áp dụng trong ngày
```

```text
net_revenue
=
gross_revenue - promotion_discount
```

## 9.4 Validation

```text
gross_revenue >= 0
promotion_discount >= 0
promotion_discount <= gross_revenue
net_revenue >= 0
```

## 9.5 Trạng thái Revenue

```text
DRAFT
→ SUBMITTED
→ APPROVED
```

hoặc:

```text
SUBMITTED
→ REJECTED
→ chỉnh sửa
→ SUBMITTED lại
```

## 9.6 Ai được làm gì?

### Store Owner

Được:

- tạo Revenue;
- sửa `DRAFT`;
- sửa `REJECTED`;
- submit;
- xem Revenue của Store mình.

### Accountant

Được:

- xem toàn hệ thống;
- approve;
- reject;
- yêu cầu adjustment.

### Admin

Được:

- xem toàn bộ;
- không mặc định approve Revenue.

## 9.7 Một Store mỗi ngày một Revenue

Mỗi Store chỉ có một báo cáo doanh thu tổng cho một `business_date`.

## 9.8 Revenue = 0

Trong thời gian Store ACTIVE, mỗi ngày đều phải có Revenue record.

Nếu không có doanh thu:

```text
gross_revenue = 0
```

Điều này phân biệt:

```text
0 doanh thu
≠
chưa báo cáo
```

## 9.9 Không cho Revenue ngoài thời gian hợp lệ

Không cho:

```text
business_date < Store.activated_date
```

Không cho:

```text
business_date > ngày hiện tại
```

---

# 10. Deadline báo Revenue

Revenue ngày D phải được submit trước:

```text
23:00 ngày D+1
```

Ví dụ:

```text
Revenue ngày 10/10
→ deadline 23:00 ngày 11/10
```

Sau deadline, nếu Revenue vẫn:

```text
không tồn tại
hoặc
DRAFT
```

thì coi là:

```text
LATE_REPORT
```

Nếu đã:

```text
SUBMITTED
APPROVED
```

thì không bị tính chậm.

---

# 11. Điều chỉnh Revenue đã APPROVED

Revenue đã APPROVED vẫn có thể được điều chỉnh nhưng không được ghi đè mất lịch sử.

Luồng:

```text
APPROVED
→ Accountant yêu cầu adjustment
→ bắt buộc có lý do
→ Store Owner sửa
→ SUBMITTED lại
→ Accountant duyệt lại
```

Phải giữ được:

```text
giá trị cũ
giá trị mới
lý do
người yêu cầu
người chỉnh sửa
thời gian
```

Nếu kỳ chưa lập Invoice:

```text
Revenue mới được dùng để tính lại tháng.
```

Nếu Invoice đã phát hành:

```text
không sửa ngược Invoice cũ
→ chênh lệch được xử lý bằng Billing Adjustment ở kỳ sau
```

---

# 12. Monthly Revenue Aggregation

Không nhập tổng tháng thủ công.

Backend tự tổng hợp:

```text
monthly_gross_revenue
=
SUM(gross_revenue của Revenue APPROVED)
```

```text
monthly_promotion_discount
=
SUM(promotion_discount của Revenue APPROVED)
```

```text
monthly_net_revenue
=
SUM(net_revenue của Revenue APPROVED)
```

Chỉ Revenue `APPROVED` được tính vào kỳ.

---

# 13. Mốc chốt tháng

Hạn hoàn tất đối soát tháng trước:

```text
23:00 ngày 12 tháng kế tiếp
```

Ví dụ:

```text
Revenue tháng 09
→ hoàn tất đối soát trước 23:00 ngày 12/10
```

Sau mốc này hệ thống có thể:

```text
tổng hợp
→ tính phí
→ tạo Invoice
```

---

# 14. Royalty

Đã chốt:

> Royalty tính trên doanh thu trước giảm giá.

Công thức:

```text
royalty_fee
=
monthly_approved_gross_revenue
× royalty_rate
```

Promotion không làm giảm căn cứ tính Royalty.

Ví dụ:

```text
Gross Revenue = 500 triệu
Promotion Discount = 40 triệu
Net Revenue = 460 triệu

Royalty Rate = 5%

Royalty Fee = 25 triệu
```

Royalty tính trên 500 triệu, không phải 460 triệu.

---

# 15. Promotion

## 15.1 Ai tạo Promotion?

Tất cả Promotion do:

```text
Brand / Admin
```

tạo.

Store Owner:

```text
không được tạo
không được sửa
chỉ được xem và áp dụng
```

## 15.2 Một ngày có thể có nhiều Promotion

Đã chốt:

> Một Store có thể áp dụng nhiều Promotion trong cùng một ngày.

Do đó phải phân biệt discount theo từng Promotion.

## 15.3 Thông tin Promotion

```text
id
name
description

discount_type
discount_value

start_date
end_date

scope

funding_type
brand_share_percent
store_share_percent

status

created_by
created_at
updated_at
deleted_at
```

## 15.4 Discount Type

```text
PERCENTAGE
FIXED_AMOUNT
```

Validation:

```text
PERCENTAGE:
0 < discount_value <= 100
```

```text
FIXED_AMOUNT:
discount_value > 0
```

## 15.5 Scope

```text
ALL_STORES
SELECTED_STORES
```

Promotion chỉ được áp dụng nếu:

- đang trong thời gian hiệu lực;
- Store nằm trong phạm vi chương trình;
- Promotion ở trạng thái cho phép áp dụng.

---

# 16. Funding của Promotion

Có ba loại:

```text
BRAND
STORE
SHARED
```

## 16.1 BRAND

```text
Brand chịu 100%
Store chịu 0%
```

## 16.2 STORE

```text
Brand chịu 0%
Store chịu 100%
```

## 16.3 SHARED

```text
brand_share_percent
+
store_share_percent
=
100
```

Ví dụ:

```text
Discount = 20 triệu
Brand = 60%
Store = 40%

Brand Support = 12 triệu
Store Cost = 8 triệu
```

---

# 17. Promotion chi tiết theo Revenue

Vì một ngày có thể có nhiều Promotion, mỗi Revenue phải phân biệt phần discount của từng Promotion.

Ví dụ:

```text
Gross Revenue ngày = 100 triệu
```

Promotion A:

```text
Discount = 10 triệu
Brand chịu = 80%
Store chịu = 20%
```

Promotion B:

```text
Discount = 5 triệu
Brand chịu = 40%
Store chịu = 60%
```

Tổng:

```text
promotion_discount
= 10 + 5
= 15 triệu
```

Net Revenue:

```text
100 - 15
= 85 triệu
```

Brand Support:

```text
10 × 80%
+
5 × 40%
=
10 triệu
```

Store Promotion Cost:

```text
10 × 20%
+
5 × 60%
=
5 triệu
```

Royalty vẫn tính:

```text
100 triệu × royalty_rate
```

## 17.1 Snapshot Funding

Tỷ lệ Brand/Store chịu tại thời điểm Promotion được áp dụng phải được giữ lại cho lịch sử.

Ví dụ tháng 9 Promotion A:

```text
Brand = 80%
Store = 20%
```

Tháng 10 Admin thay đổi Promotion thành:

```text
Brand = 50%
Store = 50%
```

Revenue và Invoice tháng 9 vẫn phải giữ tỷ lệ 80/20 cũ.

---

# 18. Brand Promotion Support

Phần Brand chịu được dùng để giảm nghĩa vụ Invoice của Store.

```text
brand_promotion_support
=
SUM(discount_amount × brand_share_percent)
```

Brand Support được:

```text
trừ trực tiếp khỏi Monthly Invoice
```

Brand không hoàn tiền riêng bằng Payment trong scope hiện tại.

---

# 19. Monthly Invoice

## 19.1 Chu kỳ

```text
1 Store
→ 1 Invoice cho mỗi tháng
```

## 19.2 Các thành phần trước VAT

Invoice có:

```text
Royalty Fee
+ System Fee
+ Service Fee
+ Initial Franchise Fee Installment (nếu còn)
+ Positive Billing Adjustment (nếu có)

- Brand Promotion Support
- Carried Credit kỳ trước
- Negative Billing Adjustment (nếu có)
```

## 19.3 Fee Subtotal

```text
fee_subtotal
=
royalty_fee
+ system_fee
+ service_fee
+ initial_fee_installment
+ positive_adjustments
```

## 19.4 Deductions

```text
deductions
=
brand_promotion_support
+ carried_credit
+ negative_adjustments
```

## 19.5 Taxable Amount

```text
raw_taxable_amount
=
fee_subtotal - deductions
```

Nếu:

```text
raw_taxable_amount >= 0
```

thì:

```text
taxable_amount = raw_taxable_amount
```

Nếu:

```text
raw_taxable_amount < 0
```

thì:

```text
taxable_amount = 0
```

và phần âm chuyển thành credit cho kỳ sau.

---

# 20. VAT

VAT là thành phần chính thức của Invoice.

## 20.1 Công thức

```text
vat_amount
=
ROUND(taxable_amount × vat_rate)
```

```text
invoice_total
=
taxable_amount + vat_amount
```

## 20.2 VAT Rate

Không hard-code VAT vào lịch sử.

Mỗi Invoice phải giữ:

```text
vat_rate
taxable_amount
vat_amount
```

đã áp dụng tại thời điểm phát hành.

Nếu sau này VAT Rate thay đổi, Invoice cũ không thay đổi.

## 20.3 Ví dụ

```text
Royalty Fee                         25,000,000
System Fee                           1,000,000
Service Fee                          2,000,000
Initial Fee Installment             20,000,000
Brand Promotion Support            -12,000,000
------------------------------------------------
Taxable Amount                      36,000,000
```

Giả sử:

```text
VAT Rate = 10%
```

thì:

```text
VAT Amount = 3,600,000
```

Invoice Total:

```text
39,600,000
```

## 20.4 Deposit

Deposit không được đưa vào Monthly Invoice để tính VAT.

Deposit được quản lý riêng như tiền đảm bảo hợp đồng.

---

# 21. Credit khi Brand Support lớn hơn phí

Không cho Invoice âm.

Ví dụ:

```text
Fee Subtotal = 8 triệu
Deductions = 12 triệu
```

Kết quả thô:

```text
-4 triệu
```

Chốt:

```text
taxable_amount = 0
vat_amount = 0
invoice_total = 0
```

Phần dư:

```text
4 triệu
```

trở thành:

```text
Carried Credit
```

để chuyển sang kỳ sau.

Ví dụ kỳ sau:

```text
Fee Subtotal = 20 triệu
Carried Credit = 4 triệu

Taxable Amount = 16 triệu
VAT tính trên 16 triệu
```

---

# 22. Invoice Total = 0

Nếu:

```text
invoice_total = 0
```

thì Store không có nghĩa vụ thanh toán.

Không tạo Payment `0 đồng`.

Invoice được xem là đã settled ngay khi phát hành.

---

# 23. Invoice phải giữ snapshot lịch sử

Một Invoice đã phát hành phải giữ nguyên các số liệu đã dùng để tính.

Ví dụ tháng 10:

```text
Royalty Rate = 5%
System Fee = 1 triệu
VAT Rate = 10%
```

Sang tháng 11 Contract/VAT thay đổi thì Invoice tháng 10 không thay đổi.

Invoice nên giữ snapshot về:

```text
billing_period

monthly_gross_revenue
monthly_promotion_discount
monthly_net_revenue

royalty_rate
royalty_fee

system_fee
service_fee
initial_fee_installment

brand_promotion_support
carried_credit
billing_adjustment

taxable_amount
vat_rate
vat_amount

invoice_total
```

---

# 24. Invoice Status

```text
DRAFT
→ ISSUED
→ PARTIALLY_PAID
→ PAID
```

Ngoài ra:

```text
OVERDUE
CANCELLED
```

`OVERDUE` không phải trạng thái cuối.

Sau khi Store thanh toán đủ:

```text
OVERDUE
→ PAID
```

---

# 25. Invoice Due Date

Hạn thanh toán:

```text
7 ngày kể từ ngày phát hành
```

Ví dụ:

```text
issued_date = 13/10
due_date = 20/10
```

Nếu sau due date:

```text
outstanding_amount > 0
```

thì Invoice:

```text
OVERDUE
```

---

# 26. Cancel Invoice

## 26.1 DRAFT

Có thể cancel.

## 26.2 ISSUED nhưng chưa có Payment

Được cancel nếu phát hiện sai.

Bắt buộc có:

```text
cancel_reason
```

Sau đó có thể tạo Invoice replacement cho cùng kỳ.

Ví dụ:

```text
INV-001 → CANCELLED
INV-002 → Invoice thay thế
```

## 26.3 Invoice đã có Payment

Không được cancel trực tiếp nếu:

```text
PARTIALLY_PAID
PAID
```

Nếu phát hiện sai:

```text
giữ Invoice cũ
→ tạo Billing Adjustment ở kỳ sau
```

---

# 27. Billing Adjustment

Billing Adjustment dùng để xử lý sai lệch của kỳ trước mà không sửa Invoice lịch sử.

## 27.1 Store bị tính thiếu

Ví dụ kỳ trước thiếu 2 triệu:

```text
Billing Adjustment = +2 triệu
```

Kỳ hiện tại tăng nghĩa vụ thêm 2 triệu trước VAT.

## 27.2 Store bị tính dư

Ví dụ kỳ trước dư 2 triệu:

```text
Billing Adjustment = -2 triệu
```

Kỳ hiện tại được giảm 2 triệu trước VAT.

## 27.3 Revenue sai sau khi Invoice đã phát hành

Ví dụ tháng 9 phát hiện thiếu:

```text
Gross Revenue +10 triệu
Royalty Rate = 5%
```

Chênh lệch Royalty:

```text
+500,000
```

Không sửa Invoice tháng 9.

Invoice kỳ tiếp theo thêm:

```text
Billing Adjustment tháng 9
+500,000
```

VAT của kỳ hiện tại được tính sau khi adjustment được đưa vào taxable amount.

---

# 28. Payment

## 28.1 Ý nghĩa

Invoice:

```text
Store phải trả bao nhiêu
```

Payment:

```text
Store thực tế đã trả bao nhiêu
```

## 28.2 Quan hệ

```text
1 Invoice
→ N Payments
```

```text
1 Payment
→ 1 Invoice
```

Không hỗ trợ một Payment trả nhiều Invoice.

## 28.3 Payment là số tiền đã gồm VAT

Store thanh toán trên:

```text
invoice_total
```

Ví dụ:

```text
Taxable Amount = 36 triệu
VAT = 3.6 triệu
Invoice Total = 39.6 triệu
```

Store có nghĩa vụ thanh toán:

```text
39.6 triệu
```

---

# 29. Partial Payment

Cho phép thanh toán nhiều lần.

Ví dụ:

```text
Invoice Total = 39.6 triệu
```

Payment 1:

```text
20 triệu
```

Kết quả:

```text
Paid = 20 triệu
Outstanding = 19.6 triệu
Status = PARTIALLY_PAID
```

Payment 2:

```text
19.6 triệu
```

Kết quả:

```text
Outstanding = 0
Status = PAID
```

---

# 30. Không được trả vượt công nợ

Payment phải thỏa:

```text
amount > 0
```

và:

```text
amount <= outstanding_amount
```

Không hỗ trợ overpayment.

---

# 31. Payment nhập sai

Payment đã xác nhận:

```text
không sửa amount trực tiếp
không xóa trực tiếp
```

Nếu nhập sai:

```text
CONFIRMED
→ REVERSED
```

bắt buộc có:

```text
reversal_reason
```

Sau đó tạo Payment mới đúng.

Ví dụ:

```text
Payment #5 = 10 triệu
```

nhập sai.

Thực hiện:

```text
Payment #5
→ REVERSED
Reason = "Nhập dư một số 0"
```

Sau đó:

```text
Payment #6
Amount = 1 triệu
→ CONFIRMED
```

---

# 32. Payment Status

Giữ đơn giản:

```text
CONFIRMED
REVERSED
```

Không cần:

```text
PENDING
FAILED
```

vì không có payment gateway.

---

# 33. Công nợ

Không cần khái niệm nghiệp vụ Debt độc lập.

Công nợ được tính từ:

```text
Invoice
-
Confirmed Payments
```

Công thức:

```text
paid_amount
=
SUM(payment.amount WHERE status = CONFIRMED)
```

```text
outstanding_amount
=
invoice_total - paid_amount
```

Payment `REVERSED` không được tính.

---

# 34. Invoice Status sau Payment

Nếu:

```text
paid_amount = 0
```

và chưa quá hạn:

```text
ISSUED
```

Nếu:

```text
0 < paid_amount < invoice_total
```

và chưa quá hạn:

```text
PARTIALLY_PAID
```

Nếu:

```text
outstanding_amount = 0
```

thì:

```text
PAID
```

Nếu:

```text
outstanding_amount > 0
AND current_date > due_date
```

thì:

```text
OVERDUE
```

---

# 35. Reverse Payment làm Invoice đổi trạng thái

Sau khi reverse, hệ thống tính lại toàn bộ Confirmed Payment.

Ví dụ Invoice:

```text
30 triệu
Due Date = 20/10
```

Payment:

```text
30 triệu
→ PAID
```

Nếu reverse ngày 18/10:

```text
Paid = 0
Outstanding = 30 triệu
Current Date < Due Date

→ ISSUED
```

Nếu reverse ngày 25/10:

```text
Paid = 0
Outstanding = 30 triệu
Current Date > Due Date

→ OVERDUE
```

Nếu còn một phần Payment:

```text
Paid > 0
Outstanding > 0
```

thì:

- trước due date → `PARTIALLY_PAID`;
- sau due date → `OVERDUE`.

---

# 36. Late Report Alert

Store ACTIVE có nghĩa vụ báo Revenue mỗi ngày.

Nếu quá:

```text
23:00 ngày D+1
```

mà Revenue ngày D:

```text
không tồn tại
hoặc
DRAFT
```

thì tạo cảnh báo:

```text
LATE_REPORT
```

Revenue có:

```text
gross_revenue = 0
```

nhưng đã submit thì không bị coi là thiếu báo cáo.

---

# 37. Notification

Các loại Notification nghiệp vụ chính:

```text
APPLICATION_APPROVED
APPLICATION_REJECTED

REVENUE_REJECTED
REVENUE_ADJUSTMENT_REQUESTED
REVENUE_OVERDUE

PROMOTION_STARTED

INVOICE_ISSUED
INVOICE_OVERDUE

PAYMENT_CONFIRMED
PAYMENT_REVERSED
```

Notification có thể được dùng cho:

- thông báo trong hệ thống;
- email test local.

---

# 38. Audit Log

Các nghiệp vụ nhạy cảm phải được audit:

```text
APPROVE_APPLICATION
REJECT_APPLICATION
WITHDRAW_APPLICATION

CREATE_STORE

ACTIVATE_CONTRACT

APPROVE_REVENUE
REJECT_REVENUE
REQUEST_REVENUE_ADJUSTMENT

CREATE_PROMOTION
ACTIVATE_PROMOTION
CANCEL_PROMOTION

GENERATE_INVOICE
ISSUE_INVOICE
CANCEL_INVOICE

RECORD_PAYMENT
REVERSE_PAYMENT

CHANGE_ROLE
```

Audit cần ghi được:

```text
ai thực hiện
hành động gì
đối tượng nào
giá trị cũ
giá trị mới
lý do
thời gian
```

Audit log không được sửa/xóa thông thường.

---

# 39. Soft Delete và dữ liệu lịch sử

Có thể soft-delete cho:

```text
users
franchise_applications
stores
promotions
```

Không dùng xóa dữ liệu như cách xử lý chính cho:

```text
approved revenue
invoice
payment
```

Các dữ liệu tài chính nên dùng:

```text
CANCELLED
REVERSED
ADJUSTMENT
```

để giữ lịch sử.

---

# 40. Search / Filter / Sort / Pagination

Các danh sách nghiệp vụ chính phải hỗ trợ:

```text
search
filter
sort
pagination
```

Áp dụng cho:

```text
applications
stores
contracts
revenues
promotions
invoices
payments
notifications
audit logs
```

---

# 41. Import / Export

## 41.1 Revenue

Cho phép:

```text
Import CSV/Excel
Export CSV/Excel
```

Kết quả Import cần phản ánh:

```text
total_rows
success_rows
failed_rows
errors
```

## 41.2 Contract

```text
Export PDF
```

## 41.3 Invoice

```text
Export PDF
```

## 41.4 Reports

```text
Export CSV/Excel
```

---

# 42. Reporting

Mặc dù không làm frontend, hệ thống vẫn cần nghiệp vụ báo cáo.

Có thể báo cáo:

```text
Doanh thu ngày
Doanh thu tháng
Doanh thu theo Store

Gross Revenue
Promotion Discount
Net Revenue

Royalty Fee

Brand Promotion Support
Store Promotion Cost

Taxable Amount
VAT Amount

Invoice Total
Paid Amount
Outstanding Amount

Overdue Invoice

Store báo cáo trễ
```

---

# 43. Tiền tệ và làm tròn

Chốt:

```text
Currency = VND
```

Không hỗ trợ đa tiền tệ.

Tất cả số tiền cuối cùng được làm tròn đến:

```text
1 VND
```

Royalty Rate có thể có phần thập phân:

```text
5%
5.5%
4.75%
```

Nên:

```text
tổng hợp doanh thu tháng trước
→ nhân royalty rate
→ làm tròn kết quả cuối cùng
```

Không làm tròn Royalty từng ngày rồi cộng lại.

---

# 44. Ví dụ End-to-End hoàn chỉnh

```text
1. User đăng ký tài khoản.

2. User đăng nhập.

3. User gửi Franchise Application.

4. Admin đưa hồ sơ sang UNDER_REVIEW.

5. Admin APPROVE.

6. Admin tạo Store.
   Store = INACTIVE.

7. Admin tạo Contract.

8. Store Owner hoàn thành điều kiện tài chính ban đầu theo Contract.

9. Contract = ACTIVE.

10. Store = ACTIVE.

11. Store Owner báo Revenue mỗi ngày.

12. Accountant kiểm tra và APPROVE Revenue.

13. Brand tạo nhiều Promotion.

14. Trong một ngày Store có thể áp dụng Promotion A + Promotion B.

15. Revenue ghi Gross Revenue và discount theo từng Promotion.

16. Cuối tháng hệ thống tổng hợp Revenue APPROVED.

17. Tính Monthly Gross Revenue.

18. Tính Royalty:
    Gross Revenue × Royalty Rate.

19. Tính Brand Promotion Support theo từng Promotion.

20. Tính:
    Royalty
    + System Fee
    + Service Fee
    + Initial Fee Installment
    +/− Billing Adjustment
    − Brand Promotion Support
    − Carried Credit.

21. Nếu kết quả âm:
    Taxable Amount = 0
    phần dư → Credit kỳ sau.

22. Tính VAT.

23. Tạo Invoice Total.

24. Issue Invoice.

25. Due Date = 7 ngày sau ngày phát hành.

26. Store thanh toán một phần.
    → PARTIALLY_PAID.

27. Store thanh toán đủ.
    → PAID.

28. Nếu quá hạn còn nợ:
    → OVERDUE.

29. Nếu Payment nhập sai:
    → REVERSED
    → tạo Payment mới.

30. Nếu Revenue kỳ cũ bị phát hiện sai sau khi Invoice đã phát hành:
    → không sửa Invoice cũ
    → tạo Billing Adjustment kỳ sau.

31. Nếu Store không báo Revenue đúng hạn:
    → LATE_REPORT + Notification.

32. Mọi action nhạy cảm:
    → Audit Log.
```

---

# 45. Các quyết định nghiệp vụ đã chốt

| Vấn đề | Quyết định |
|---|---|
| Một User có nhiều Store | Có |
| Một User có nhiều Application đang mở | Không |
| Application bị reject có nộp lại được không | Có |
| Approve Application tự tạo Store | Không |
| Xóa Application đã gửi | Không, dùng WITHDRAWN |
| Một Application sinh nhiều Store | Không |
| Store mới tạo | INACTIVE |
| Revenue | Theo ngày |
| Revenue tháng | Tự tổng hợp |
| Revenue = 0 | Vẫn phải báo |
| Revenue trước activated_date | Không cho |
| Revenue tương lai | Không cho |
| Deadline Revenue | 23:00 ngày D+1 |
| Người submit tự approve | Không |
| Người approve Revenue | ACCOUNTANT |
| Admin approve Revenue thường xuyên | Không |
| Royalty base | Gross Revenue |
| Promotion ảnh hưởng Royalty | Không |
| Promotion do ai tạo | Brand/Admin |
| Nhiều Promotion trong một ngày | Có |
| Discount phải phân biệt theo Promotion | Có |
| Promotion funding | BRAND / STORE / SHARED |
| Brand Support | Trừ Invoice |
| Invoice cycle | Theo tháng |
| Due date | 7 ngày |
| VAT | Có |
| Currency | VND |
| Invoice âm | Không |
| Credit âm dư | Chuyển kỳ sau |
| Invoice = 0 | Không cần Payment |
| Invoice đã phát hành | Giữ snapshot |
| Invoice đã có Payment được cancel | Không |
| Revenue sai sau billing | Billing Adjustment kỳ sau |
| Payment partial | Có |
| Một Payment trả nhiều Invoice | Không |
| Overpayment | Không cho |
| Payment sai | REVERSED + tạo Payment mới |
| Debt table riêng | Không cần về mặt nghiệp vụ |
| Payment gateway | Không nằm trong scope |

---

# 46. CÁC VẤN ĐỀ CẦN THẢO LUẬN TIẾP

Các phần dưới đây **chưa nên đóng business rule cuối cùng**.

## 46.1 Contract Renewal

Cần chốt:

- Gia hạn bằng Contract mới hay phiên bản mới của Contract cũ?
- Contract mới bắt đầu từ ngày nào?
- Có cho phép khoảng trống giữa hai Contract?
- Điều kiện gia hạn là gì?
- Có bắt buộc hết công nợ trước khi gia hạn không?

## 46.2 Contract Expiry

Cần chốt:

- Đến `effective_to`, Contract tự `EXPIRED` hay cần Admin xác nhận?
- Store tự chuyển `INACTIVE` khi Contract hết hạn hay chờ xử lý?
- Store có được tiếp tục báo Revenue trong thời gian chờ gia hạn không?

## 46.3 Contract Termination

Cần chốt:

- Ai được terminate?
- Cần lý do không?
- Có thời gian báo trước không?
- Các Invoice chưa thanh toán xử lý thế nào?
- Initial Fee installment còn lại có bị thu ngay không?

## 46.4 Store SUSPENDED

Cần chốt:

- Ai được suspend Store?
- Lý do suspend?
- Store có được login không?
- Store có được xem lịch sử không?
- Store có được trả công nợ không?
- Store có phải báo Revenue trong thời gian suspended không?
- Promotion đang áp dụng xử lý thế nào?

## 46.5 Initial Franchise Fee Installment

Đã chốt:

```text
20% trước activation
80% trả góp
```

Nhưng chưa chốt:

- 80% trả trong bao nhiêu kỳ?
- kỳ đầu tiên bắt đầu khi nào?
- due date của installment có cùng Monthly Invoice không?
- Store trả trước toàn bộ phần còn lại có được không?
- nếu terminate sớm thì phần chưa trả xử lý thế nào?

## 46.6 Deposit

Chưa chốt:

- Deposit tiêu chuẩn là bao nhiêu?
- Deposit thanh toán trước activation hay cùng Initial Fee?
- Deposit có được bổ sung nếu bị trừ công nợ không?
- Khi nào hoàn Deposit?
- Nếu có tranh chấp thì có giữ Deposit không?

## 46.7 Fee Change giữa kỳ Contract

Cần chốt nếu:

```text
Royalty Rate
System Fee
Service Fee
```

thay đổi giữa tháng.

Ví dụ:

```text
01–15: Royalty 5%
16–30: Royalty 6%
```

Cần quyết định:

- chia kỳ theo ngày;
- áp rate đầu tháng;
- hay rate mới chỉ có hiệu lực từ tháng kế tiếp.

Đây là rule quan trọng trước khi hỗ trợ Contract amendment/versioning.

## 46.8 VAT Rate thay đổi giữa tháng

Cần chốt:

- VAT rate áp dụng theo ngày phát hành Invoice;
- hay theo từng Invoice Item;
- hay theo thời gian phát sinh phí.

Hiện tại tài liệu đang giả định đơn giản:

```text
một Invoice dùng một VAT Rate snapshot
```

Nhưng nếu muốn bám sát nghiệp vụ thuế thực tế hơn thì cần thảo luận riêng.

## 46.9 Revenue obligation khi Store nghỉ/tạm đóng

Hiện rule là:

```text
Store ACTIVE → mỗi ngày phải báo Revenue
```

Cần chốt thêm:

- ngày nghỉ lễ;
- cửa hàng đóng bảo trì;
- thiên tai/sự cố;
- Store được phép đăng ký ngày không hoạt động hay không.

Nếu không có khái niệm ngày nghỉ, Store phải báo `0` để tránh Late Report.

## 46.10 Promotion overlap chi tiết

Đã cho phép nhiều Promotion cùng ngày, nhưng còn cần chốt:

- một giao dịch có được hưởng nhiều Promotion đồng thời không?
- hay chỉ tổng hợp discount cuối ngày mà không quan tâm từng order?
- Promotion A và B có thể cùng áp dụng lên cùng doanh thu hay chỉ các nhóm doanh thu khác nhau?

Vì đề tài không quản lý POS/order, hướng phù hợp hiện tại là:

```text
Store báo tổng discount theo từng Promotion trong ngày
```

mà không quản lý từng giao dịch.

## 46.11 Promotion bị sửa khi đang ACTIVE

Cần chốt:

- Có được sửa discount/rate funding khi Promotion đã ACTIVE không?
- Nếu sửa thì hiệu lực từ thời điểm nào?
- Revenue trước thời điểm sửa giữ rule cũ như thế nào?

Hiện tại đã chốt nguyên tắc snapshot lịch sử, nhưng lifecycle của Promotion vẫn cần cụ thể hơn.

## 46.12 Promotion Credit

Đã chốt Credit chuyển kỳ sau khi deductions > fee subtotal.

Cần chốt thêm:

- Credit có hết hạn không?
- Credit được dùng vô thời hạn hay giới hạn số kỳ?
- Nếu Contract kết thúc mà vẫn còn Credit thì Brand hoàn tiền hay Credit mất hiệu lực?
- Credit có được hoàn bằng tiền không?

## 46.13 Invoice Replacement

Đã cho phép cancel Invoice chưa có Payment và tạo lại.

Cần chốt:

- Invoice replacement có cần liên kết với Invoice cũ không?
- Có cần lý do replacement?
- Invoice number mới hay giữ số cũ?

## 46.14 Billing Adjustment

Cần chốt chi tiết:

- Adjustment có giới hạn số kỳ lùi không?
- Accountant tự tạo hay hệ thống tự tạo?
- Có cần Admin duyệt adjustment lớn không?
- Adjustment có thể bắt nguồn từ Revenue, Promotion hay Contract không?

## 46.15 Monthly Close

Cần chốt rõ:

- Sau 23:00 ngày 12 có tự khóa kỳ không?
- Accountant có nút “Close Period” không?
- Có được reopen kỳ không?
- Ai được reopen?
- Điều kiện reopen là gì?

## 46.16 Invoice Total = 0

Hiện đang coi là settled ngay khi issue.

Cần chốt tên trạng thái thể hiện:

- dùng luôn `PAID`;
- hay thêm `SETTLED`;
- hay `ISSUED` nhưng outstanding = 0.

Về nghiệp vụ, `SETTLED` có thể rõ nghĩa hơn `PAID` vì thực tế không có Payment.

## 46.17 Notification và Escalation

Cần chốt:

- Late Report gửi cho Store Owner ngay khi trễ hay sau bao lâu?
- Có gửi cho Accountant/Admin không?
- Invoice Overdue nhắc mỗi ngày hay chỉ một lần?
- Có escalation sau 3/7/15 ngày không?

## 46.18 Báo cáo cuối cùng cần nộp

Cần chốt bộ report bắt buộc cho demo:

- Revenue Report;
- Royalty Report;
- Promotion Support Report;
- Invoice Report;
- Outstanding/Overdue Report;
- Late Reporting Report;
- Contract Report.

Có thể chọn một bộ tối thiểu để tránh làm quá rộng.

---

# 47. Ưu tiên thảo luận tiếp

Để tiếp tục thiết kế nghiệp vụ mà không ảnh hưởng phần đã chốt, nên bàn theo thứ tự:

```text
1. Contract lifecycle
2. Initial Fee installment
3. Deposit
4. Store SUSPENDED
5. Fee change giữa kỳ
6. Monthly Close / Reopen
7. Promotion lifecycle chi tiết
8. Credit khi Contract kết thúc
9. Invoice replacement / adjustment nâng cao
10. Notification escalation
```

Các phần Application, Store creation, Daily Revenue, Promotion funding, Monthly Invoice cơ bản, VAT, Payment và Outstanding hiện đã đủ rõ để dùng làm nền nghiệp vụ.
