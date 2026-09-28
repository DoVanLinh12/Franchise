# Product Requirements Document

## Sản phẩm

Franchise Management API là backend phục vụ Brand quản lý vòng đời cửa hàng
nhượng quyền từ hồ sơ đăng ký đến doanh thu, phí định kỳ và công nợ. Sản phẩm
có một frontend local tối giản để trình diễn và gọi API; không phát triển thành
hệ thống UI sản xuất và không quản lý POS, kho, đơn hàng hay payment gateway.

## Người dùng

- `ADMIN`: hồ sơ, Store, Contract, Promotion, User/RBAC và giám sát hệ thống.
- `STORE_OWNER`: Store của mình, Revenue, Invoice, Payment và Notification.
- `ACCOUNTANT`: duyệt Revenue, Invoice, Payment, công nợ và báo cáo tài chính.

## Giá trị chính

- Một nguồn dữ liệu kiểm soát toàn bộ chuỗi Franchise.
- Royalty tự tính trên Gross Revenue đã duyệt.
- Promotion Support có snapshot và khấu trừ Invoice minh bạch.
- Invoice giữ snapshot VAT/phí; Payment sai được reverse, không sửa lịch sử.
- Audit cho mọi thao tác nhạy cảm.

## Tiêu chí hoàn thành

- Workflow end-to-end chạy qua API và Stored Procedure.
- RBAC và ownership được kiểm tra.
- Search/filter/pagination, CSV/XLSX/PDF và Postman có sẵn.
- Docker Compose, Jenkins, health check, logging, rate limit và cache hoạt động.
- Unit/API/database integration test đạt tối thiểu 30% coverage.

Đặc tả nghiệp vụ chi tiết và nguồn quyết định chính thức nằm tại
`FRANCHISE_BUSINESS_SPEC_VI.md`.
