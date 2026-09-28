# Lộ trình triển khai 10 giai đoạn

1. **Identity core** — User, Argon2, JWT access/refresh, reset password, RBAC,
   audit và khóa đăng nhập.
2. **Authentication API** — endpoint đăng ký/đăng nhập/refresh/logout/reset,
   dependency Bearer token, policy role và quản trị User.
3. **Onboarding và Contract activation** — Application, Store, Contract,
   khoản thanh toán ban đầu 20% và kích hoạt Store.
4. **Promotion** — lifecycle, phạm vi Store, funding và snapshot tỷ lệ hỗ trợ.
5. **Daily Revenue** — CRUD theo trạng thái, submit/approve/reject, adjustment,
   versioning và deadline báo cáo.
6. **Monthly billing** — tổng hợp tháng, Royalty, Promotion Support, VAT,
   Billing Adjustment, Credit và Invoice snapshot.
7. **Payment và công nợ** — partial payment, chống overpayment, reverse và tự
   tính lại trạng thái Invoice.
8. **Notification và background job** — late report, overdue invoice, in-app
   notification và Celery task tùy chọn.
9. **Import/export và report** — CSV/Excel, PDF Contract/Invoice và báo cáo.
10. **Hoàn thiện chất lượng** — search/filter/sort/pagination, rate limit, CORS,
    structured logging, Redis cache, seed trên 2.000 bản ghi, Postman, Docker,
    Jenkins và tài liệu bàn giao.

Nguyên tắc xuyên suốt: FastAPI → Service → Repository → PostgreSQL Stored
Procedure/Function; không SQLAlchemy/ORM và không đưa SQL vào API/Service.
