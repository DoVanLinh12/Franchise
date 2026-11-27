# ERD

Cơ sở dữ liệu gồm 14 bảng trong schema `app`
(`database/schema/001_create_all_tables.sql`), rút gọn từ 21 bảng ở bản thiết kế đầu.

```mermaid
erDiagram
    USERS ||--o{ FRANCHISE_APPLICATIONS : submits
    FRANCHISE_APPLICATIONS ||--o| STORES : creates
    USERS ||--o{ STORES : owns
    STORES ||--o{ CONTRACTS : has
    FRANCHISE_APPLICATIONS ||--o{ CONTRACTS : contracted
    CONTRACTS ||--o{ CONTRACT_FINANCIAL_TRANSACTIONS : receives
    PROMOTIONS ||--o{ PROMOTION_STORES : scopes
    STORES ||--o{ PROMOTION_STORES : selected
    STORES ||--o{ REVENUES : reports
    REVENUES ||--o{ REVENUE_PROMOTION_DETAILS : contains
    PROMOTIONS ||--o{ REVENUE_PROMOTION_DETAILS : snapshots
    STORES ||--o{ INVOICES : billed
    CONTRACTS ||--o{ INVOICES : prices
    INVOICES ||--o{ PAYMENTS : receives
    STORES ||--o{ BILLING_ADJUSTMENTS : carries
    INVOICES ||--o{ BILLING_ADJUSTMENTS : applies
    USERS ||--o{ NOTIFICATIONS : receives
    USERS ||--o{ AUDIT_LOGS : acts

    USERS {
        uuid id PK
        varchar email UK
        text password_hash
        varchar_array roles "ADMIN, STORE_OWNER, ACCOUNTANT"
        char reset_token_hash UK "SHA-256, dùng một lần"
        timestamptz reset_token_expires_at
        varchar status
    }
    FRANCHISE_APPLICATIONS {
        uuid id PK
        uuid applicant_id FK
        varchar proposed_store_name
        varchar status
    }
    STORES {
        uuid id PK
        uuid application_id FK
        uuid owner_id FK
        varchar code UK
        varchar status
        timestamptz activated_at
    }
    CONTRACTS {
        uuid id PK
        uuid application_id FK
        uuid store_id FK "cửa hàng tạo tự động khi lập hợp đồng"
        varchar store_code "mã tự sinh CHxxxx"
        varchar store_name
        text store_address
        numeric royalty_rate
        numeric initial_franchise_fee
        numeric system_fee
        numeric service_fee
        varchar status
    }
    CONTRACT_FINANCIAL_TRANSACTIONS {
        uuid id PK
        uuid contract_id FK
        varchar transaction_type "INITIAL_FEE_PAYMENT, DEPOSIT_PAYMENT"
        numeric amount
    }
    PROMOTIONS {
        uuid id PK
        varchar discount_type
        numeric discount_value
        varchar scope "thương hiệu chịu 100% chi phí"
        varchar status
    }
    PROMOTION_STORES {
        uuid promotion_id PK
        uuid store_id PK
    }
    REVENUES {
        uuid id PK
        uuid store_id FK
        date business_date UK
        numeric gross_revenue
        numeric promotion_discount
        numeric net_revenue
        varchar status
        integer version "phiên bản cũ lưu ở audit_logs"
    }
    REVENUE_PROMOTION_DETAILS {
        uuid id PK
        uuid revenue_id FK
        uuid promotion_id FK
        numeric discount_amount "thương hiệu hỗ trợ toàn bộ"
    }
    INVOICES {
        uuid id PK
        uuid store_id FK
        uuid contract_id FK
        date period_month
        numeric monthly_gross_revenue
        numeric monthly_promotion_discount
        numeric monthly_net_revenue
        numeric royalty_fee
        numeric brand_promotion_support
        numeric carried_credit
        numeric vat_amount
        numeric invoice_total
        numeric outstanding_amount
        varchar status
    }
    PAYMENTS {
        uuid id PK
        uuid invoice_id FK
        numeric amount
        varchar status "CONFIRMED, REVERSED"
    }
    BILLING_ADJUSTMENTS {
        uuid id PK
        uuid store_id FK
        varchar adjustment_type "ADJUSTMENT, CREDIT"
        numeric amount
        varchar status "PENDING, APPLIED"
        uuid applied_invoice_id FK
        uuid source_invoice_id FK
    }
    NOTIFICATIONS {
        uuid id PK
        uuid user_id FK
        varchar notification_type
        timestamptz read_at
    }
    AUDIT_LOGS {
        bigint id PK
        uuid actor_id FK
        varchar action "kể cả REVENUE_VERSION"
        jsonb old_values
        jsonb new_values
    }
```

## Các bảng đã gộp

| Bảng cũ | Nay nằm ở |
|---|---|
| `roles`, `user_roles` | `users.roles` (mảng, CHECK chỉ nhận 3 vai trò) |
| `password_reset_tokens` | `users.reset_token_hash`, `users.reset_token_expires_at` |
| `monthly_closes` | các cột tổng tháng trong `invoices` |
| `invoice_items` | tính từ các cột phí của `invoices` (`fn_get_invoice` trả về `items`) |
| `revenue_versions` | `audit_logs` với `action = 'REVENUE_VERSION'`, bản cũ trong `old_values` |
| `store_credits` | `billing_adjustments` với `adjustment_type = 'CREDIT'` (số tiền âm) |
