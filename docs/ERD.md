# ERD hiện tại

ERD này chỉ phản ánh phần backend đã triển khai, không mô tả trước Revenue,
Promotion, Invoice hoặc Payment.

```mermaid
erDiagram
    USERS ||--o{ USER_ROLES : has
    USERS ||--o{ REFRESH_TOKENS : owns
    USERS ||--o{ PASSWORD_RESET_TOKENS : requests
    REFRESH_TOKENS ||--o| REFRESH_TOKENS : replaces
    ROLES ||--o{ USER_ROLES : assigned
    USERS ||--o{ FRANCHISE_APPLICATIONS : submits
    FRANCHISE_APPLICATIONS ||--o| STORES : creates
    USERS ||--o{ STORES : owns
    STORES ||--o{ CONTRACTS : has
    USERS ||--o{ AUDIT_LOGS : acts

    USERS {
        uuid id PK
        varchar email UK
        text password_hash
        varchar full_name
        varchar status
        int failed_login_attempts
        timestamptz locked_until
        timestamptz last_login_at
        timestamptz password_changed_at
        timestamptz deleted_at
    }

    ROLES {
        smallint id PK
        varchar code UK
        varchar name
    }

    USER_ROLES {
        uuid user_id PK,FK
        smallint role_id PK,FK
    }

    REFRESH_TOKENS {
        uuid id PK
        uuid user_id FK
        char token_hash UK
        timestamptz expires_at
        timestamptz revoked_at
        uuid replaced_by_token_id FK
    }

    PASSWORD_RESET_TOKENS {
        uuid id PK
        uuid user_id FK
        char token_hash UK
        timestamptz expires_at
        timestamptz used_at
    }

    FRANCHISE_APPLICATIONS {
        uuid id PK
        uuid applicant_id FK
        varchar status
        uuid reviewed_by FK
        timestamptz converted_at
        timestamptz deleted_at
    }

    STORES {
        uuid id PK
        varchar code UK
        uuid owner_id FK
        uuid application_id UK,FK
        varchar status
        timestamptz deleted_at
    }

    CONTRACTS {
        uuid id PK
        varchar contract_no UK
        uuid store_id FK
        numeric royalty_rate
        numeric initial_franchise_fee
        numeric deposit_amount
        numeric system_fee
        numeric service_fee
        varchar status
    }

    AUDIT_LOGS {
        bigint id PK
        uuid actor_id FK
        varchar action
        varchar entity_type
        uuid entity_id
        jsonb old_values
        jsonb new_values
    }
```

Nguồn chính xác cuối cùng của schema là các file trong `database/migrations`.

## Billing và vận hành

```mermaid
erDiagram
    STORES ||--o{ CONTRACTS : has
    CONTRACTS ||--o{ CONTRACT_FINANCIAL_TRANSACTIONS : receives
    STORES ||--o{ REVENUES : reports
    REVENUES ||--o{ REVENUE_PROMOTION_DETAILS : contains
    REVENUES ||--o{ REVENUE_VERSIONS : versions
    PROMOTIONS ||--o{ REVENUE_PROMOTION_DETAILS : snapshots
    PROMOTIONS ||--o{ PROMOTION_STORES : scopes
    STORES ||--o{ PROMOTION_STORES : selected
    STORES ||--o{ MONTHLY_CLOSES : closes
    MONTHLY_CLOSES ||--|| INVOICES : produces
    INVOICES ||--o{ INVOICE_ITEMS : snapshots
    INVOICES ||--o{ PAYMENTS : receives
    STORES ||--o{ BILLING_ADJUSTMENTS : carries
    STORES ||--o{ STORE_CREDITS : owns
    USERS ||--o{ NOTIFICATIONS : receives

    REVENUES {
        uuid id PK
        uuid store_id FK
        date business_date UK
        numeric gross_revenue
        numeric promotion_discount
        numeric net_revenue
        varchar status
        integer version
    }
    PROMOTIONS {
        uuid id PK
        varchar scope
        varchar funding_type
        numeric brand_share_percent
        numeric store_share_percent
        varchar status
    }
    INVOICES {
        uuid id PK
        uuid store_id FK
        date period_month
        numeric taxable_amount
        numeric vat_rate
        numeric vat_amount
        numeric invoice_total
        numeric outstanding_amount
        varchar status
    }
    PAYMENTS {
        uuid id PK
        uuid invoice_id FK
        numeric amount
        varchar status
    }
```
