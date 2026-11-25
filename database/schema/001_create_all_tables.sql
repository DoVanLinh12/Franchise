-- Canonical schema: tables, indexes, and table constraints only.
CREATE SCHEMA IF NOT EXISTS app;

CREATE TABLE app.users (
    id uuid PRIMARY KEY,
    email varchar(320) NOT NULL,
    password_hash text NOT NULL,
    full_name varchar(200) NOT NULL,
    phone varchar(30),
    status varchar(20) NOT NULL DEFAULT 'ACTIVE',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    password_changed_at timestamptz NOT NULL DEFAULT now(),
    last_login_at timestamptz,
    CONSTRAINT ck_users_status
        CHECK (status IN ('ACTIVE', 'INACTIVE'))
);

CREATE TABLE app.roles (
    id smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(30) NOT NULL UNIQUE,
    name varchar(100) NOT NULL
);

CREATE TABLE app.user_roles (
    user_id uuid NOT NULL REFERENCES app.users(id),
    role_id smallint NOT NULL REFERENCES app.roles(id),
    assigned_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, role_id)
);

CREATE TABLE app.franchise_applications (
    id uuid PRIMARY KEY,
    applicant_id uuid NOT NULL REFERENCES app.users(id),
    applicant_name varchar(200) NOT NULL,
    email varchar(320) NOT NULL,
    phone varchar(30) NOT NULL,
    proposed_store_name varchar(200) NOT NULL,
    proposed_address text NOT NULL,
    proposed_area numeric(12, 2),
    investment_budget numeric(18, 0),
    note text,
    status varchar(30) NOT NULL DEFAULT 'PENDING',
    review_started_by uuid REFERENCES app.users(id),
    review_started_at timestamptz,
    review_note text,
    reviewed_by uuid REFERENCES app.users(id),
    reviewed_at timestamptz,
    withdrawn_by uuid REFERENCES app.users(id),
    withdrawn_at timestamptz,
    withdrawal_reason text,
    converted_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    CONSTRAINT ck_franchise_applications_status
        CHECK (status IN (
            'PENDING', 'UNDER_REVIEW', 'APPROVED', 'REJECTED', 'WITHDRAWN'
        )),
    CONSTRAINT ck_franchise_applications_area
        CHECK (proposed_area IS NULL OR proposed_area > 0),
    CONSTRAINT ck_franchise_applications_budget
        CHECK (investment_budget IS NULL OR investment_budget >= 0),
    CONSTRAINT ck_franchise_applications_rejection_reason
        CHECK (
            status <> 'REJECTED'
            OR nullif(btrim(review_note), '') IS NOT NULL
        )
);

CREATE TABLE app.stores (
    id uuid PRIMARY KEY,
    code varchar(50) NOT NULL UNIQUE,
    name varchar(200) NOT NULL,
    owner_id uuid NOT NULL REFERENCES app.users(id),
    application_id uuid NOT NULL UNIQUE
        REFERENCES app.franchise_applications(id),
    address text NOT NULL,
    phone varchar(30),
    email varchar(320),
    status varchar(20) NOT NULL DEFAULT 'INACTIVE',
    activated_at timestamptz,
    closed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    CONSTRAINT ck_stores_status
        CHECK (status IN ('INACTIVE', 'ACTIVE', 'SUSPENDED', 'CLOSED'))
);

CREATE TABLE app.contracts (
    id uuid PRIMARY KEY,
    contract_no varchar(100) NOT NULL UNIQUE,
    store_id uuid NOT NULL REFERENCES app.stores(id),
    signed_date date,
    effective_from date NOT NULL,
    effective_to date NOT NULL,
    royalty_rate numeric(7, 4) NOT NULL,
    initial_franchise_fee numeric(18, 0) NOT NULL,
    deposit_amount numeric(18, 0) NOT NULL,
    system_fee numeric(18, 0) NOT NULL,
    service_fee numeric(18, 0) NOT NULL,
    status varchar(20) NOT NULL DEFAULT 'DRAFT',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_contracts_status
        CHECK (status IN ('DRAFT', 'ACTIVE', 'EXPIRED', 'TERMINATED', 'CANCELLED')),
    CONSTRAINT ck_contracts_dates
        CHECK (effective_to >= effective_from),
    CONSTRAINT ck_contracts_royalty_rate
        CHECK (royalty_rate >= 0 AND royalty_rate <= 100),
    CONSTRAINT ck_contracts_amounts
        CHECK (
            initial_franchise_fee >= 0
            AND deposit_amount >= 0
            AND system_fee >= 0
            AND service_fee >= 0
        )
);

CREATE TABLE app.audit_logs (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    actor_id uuid REFERENCES app.users(id),
    action varchar(100) NOT NULL,
    entity_type varchar(100) NOT NULL,
    entity_id uuid NOT NULL,
    old_values jsonb,
    new_values jsonb,
    reason text,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX uq_users_email_active
    ON app.users (lower(email))
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX uq_franchise_applications_one_open_per_user
    ON app.franchise_applications (applicant_id)
    WHERE deleted_at IS NULL
      AND (
          status IN ('PENDING', 'UNDER_REVIEW')
          OR (status = 'APPROVED' AND converted_at IS NULL)
      );

CREATE INDEX ix_franchise_applications_status
    ON app.franchise_applications (status);

CREATE INDEX ix_stores_owner_id ON app.stores (owner_id);

CREATE INDEX ix_stores_status ON app.stores (status);

CREATE UNIQUE INDEX uq_contracts_one_active_per_store
    ON app.contracts (store_id)
    WHERE status = 'ACTIVE';

CREATE INDEX ix_contracts_store_id ON app.contracts (store_id);

CREATE INDEX ix_contracts_status ON app.contracts (status);

CREATE INDEX ix_audit_logs_entity
    ON app.audit_logs (entity_type, entity_id, created_at DESC);

CREATE INDEX ix_audit_logs_actor
    ON app.audit_logs (actor_id, created_at DESC);

CREATE TABLE app.password_reset_tokens (
    id uuid PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES app.users(id),
    token_hash char(64) NOT NULL UNIQUE,
    expires_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    used_at timestamptz,
    requested_by_ip inet,
    CONSTRAINT ck_password_reset_tokens_expiry CHECK (expires_at > created_at)
);

CREATE INDEX ix_password_reset_tokens_user_active
    ON app.password_reset_tokens (user_id, expires_at DESC)
    WHERE used_at IS NULL;

CREATE TABLE app.contract_financial_transactions (
    id uuid PRIMARY KEY,
    contract_id uuid NOT NULL REFERENCES app.contracts(id),
    transaction_type varchar(30) NOT NULL,
    amount numeric(18, 0) NOT NULL,
    transaction_date date NOT NULL,
    reference_no varchar(100),
    note text,
    recorded_by uuid NOT NULL REFERENCES app.users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_contract_financial_type CHECK (
        transaction_type IN ('INITIAL_FEE_PAYMENT', 'DEPOSIT_PAYMENT')
    ),
    CONSTRAINT ck_contract_financial_amount CHECK (amount > 0)
);

CREATE TABLE app.promotions (
    id uuid PRIMARY KEY,
    name varchar(200) NOT NULL,
    description text,
    discount_type varchar(20) NOT NULL,
    discount_value numeric(18, 2) NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    scope varchar(20) NOT NULL,
    funding_type varchar(20) NOT NULL,
    brand_share_percent numeric(7, 4) NOT NULL,
    store_share_percent numeric(7, 4) NOT NULL,
    status varchar(20) NOT NULL DEFAULT 'DRAFT',
    created_by uuid NOT NULL REFERENCES app.users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    CONSTRAINT ck_promotions_discount_type
        CHECK (discount_type IN ('PERCENTAGE', 'FIXED_AMOUNT')),
    CONSTRAINT ck_promotions_discount_value CHECK (
        (discount_type = 'PERCENTAGE' AND discount_value > 0
            AND discount_value <= 100)
        OR (discount_type = 'FIXED_AMOUNT' AND discount_value > 0)
    ),
    CONSTRAINT ck_promotions_dates CHECK (end_date >= start_date),
    CONSTRAINT ck_promotions_scope
        CHECK (scope IN ('ALL_STORES', 'SELECTED_STORES')),
    CONSTRAINT ck_promotions_funding
        CHECK (funding_type IN ('BRAND', 'STORE', 'SHARED')),
    CONSTRAINT ck_promotions_shares CHECK (
        brand_share_percent >= 0 AND store_share_percent >= 0
        AND brand_share_percent + store_share_percent = 100
        AND (funding_type <> 'BRAND' OR brand_share_percent = 100)
        AND (funding_type <> 'STORE' OR store_share_percent = 100)
    ),
    CONSTRAINT ck_promotions_status
        CHECK (status IN ('DRAFT', 'ACTIVE', 'CANCELLED', 'EXPIRED'))
);

CREATE TABLE app.promotion_stores (
    promotion_id uuid NOT NULL REFERENCES app.promotions(id),
    store_id uuid NOT NULL REFERENCES app.stores(id),
    PRIMARY KEY (promotion_id, store_id)
);

CREATE TABLE app.revenues (
    id uuid PRIMARY KEY,
    store_id uuid NOT NULL REFERENCES app.stores(id),
    business_date date NOT NULL,
    gross_revenue numeric(18, 0) NOT NULL,
    promotion_discount numeric(18, 0) NOT NULL DEFAULT 0,
    net_revenue numeric(18, 0) GENERATED ALWAYS AS (
        gross_revenue - promotion_discount
    ) STORED,
    status varchar(30) NOT NULL DEFAULT 'DRAFT',
    reported_by uuid NOT NULL REFERENCES app.users(id),
    reported_at timestamptz,
    reviewed_by uuid REFERENCES app.users(id),
    reviewed_at timestamptz,
    review_note text,
    adjustment_requested_by uuid REFERENCES app.users(id),
    adjustment_requested_at timestamptz,
    adjustment_reason text,
    version integer NOT NULL DEFAULT 1,
    note text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_revenues_store_date UNIQUE (store_id, business_date),
    CONSTRAINT ck_revenues_amounts CHECK (
        gross_revenue >= 0
        AND promotion_discount >= 0
        AND promotion_discount <= gross_revenue
    ),
    CONSTRAINT ck_revenues_status CHECK (
        status IN (
            'DRAFT', 'SUBMITTED', 'APPROVED', 'REJECTED',
            'ADJUSTMENT_REQUESTED'
        )
    )
);

CREATE TABLE app.revenue_promotion_details (
    id uuid PRIMARY KEY,
    revenue_id uuid NOT NULL REFERENCES app.revenues(id) ON DELETE CASCADE,
    promotion_id uuid NOT NULL REFERENCES app.promotions(id),
    discount_amount numeric(18, 0) NOT NULL,
    brand_share_percent numeric(7, 4) NOT NULL,
    store_share_percent numeric(7, 4) NOT NULL,
    brand_support_amount numeric(18, 0) NOT NULL,
    store_cost_amount numeric(18, 0) NOT NULL,
    promotion_name_snapshot varchar(200) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_revenue_promotion UNIQUE (revenue_id, promotion_id),
    CONSTRAINT ck_revenue_promotion_amounts CHECK (
        discount_amount >= 0 AND brand_support_amount >= 0
        AND store_cost_amount >= 0
        AND brand_support_amount + store_cost_amount = discount_amount
    )
);

CREATE TABLE app.revenue_versions (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    revenue_id uuid NOT NULL REFERENCES app.revenues(id),
    version integer NOT NULL,
    snapshot jsonb NOT NULL,
    change_reason text NOT NULL,
    changed_by uuid NOT NULL REFERENCES app.users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (revenue_id, version)
);

CREATE TABLE app.monthly_closes (
    id uuid PRIMARY KEY,
    store_id uuid NOT NULL REFERENCES app.stores(id),
    period_month date NOT NULL,
    monthly_gross_revenue numeric(18, 0) NOT NULL,
    monthly_promotion_discount numeric(18, 0) NOT NULL,
    monthly_net_revenue numeric(18, 0) NOT NULL,
    brand_promotion_support numeric(18, 0) NOT NULL,
    closed_by uuid NOT NULL REFERENCES app.users(id),
    closed_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_monthly_closes_store_period
        UNIQUE (store_id, period_month),
    CONSTRAINT ck_monthly_closes_period
        CHECK (period_month = date_trunc('month', period_month)::date)
);

CREATE TABLE app.billing_adjustments (
    id uuid PRIMARY KEY,
    store_id uuid NOT NULL REFERENCES app.stores(id),
    source_period date,
    amount numeric(18, 0) NOT NULL,
    reason text NOT NULL,
    status varchar(20) NOT NULL DEFAULT 'PENDING',
    created_by uuid NOT NULL REFERENCES app.users(id),
    applied_invoice_id uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    applied_at timestamptz,
    CONSTRAINT ck_billing_adjustments_amount CHECK (amount <> 0),
    CONSTRAINT ck_billing_adjustments_status
        CHECK (status IN ('PENDING', 'APPLIED', 'CANCELLED'))
);

CREATE TABLE app.store_credits (
    id uuid PRIMARY KEY,
    store_id uuid NOT NULL REFERENCES app.stores(id),
    source_invoice_id uuid,
    amount numeric(18, 0) NOT NULL,
    remaining_amount numeric(18, 0) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_store_credits_amount CHECK (
        amount > 0 AND remaining_amount >= 0 AND remaining_amount <= amount
    )
);

CREATE TABLE app.invoices (
    id uuid PRIMARY KEY,
    invoice_no varchar(100) NOT NULL UNIQUE,
    store_id uuid NOT NULL REFERENCES app.stores(id),
    contract_id uuid NOT NULL REFERENCES app.contracts(id),
    monthly_close_id uuid NOT NULL REFERENCES app.monthly_closes(id),
    period_month date NOT NULL,
    royalty_rate numeric(7, 4) NOT NULL,
    monthly_gross_revenue numeric(18, 0) NOT NULL,
    royalty_fee numeric(18, 0) NOT NULL,
    system_fee numeric(18, 0) NOT NULL,
    service_fee numeric(18, 0) NOT NULL,
    initial_fee_installment numeric(18, 0) NOT NULL DEFAULT 0,
    positive_adjustments numeric(18, 0) NOT NULL DEFAULT 0,
    brand_promotion_support numeric(18, 0) NOT NULL DEFAULT 0,
    carried_credit numeric(18, 0) NOT NULL DEFAULT 0,
    negative_adjustments numeric(18, 0) NOT NULL DEFAULT 0,
    fee_subtotal numeric(18, 0) NOT NULL,
    deductions numeric(18, 0) NOT NULL,
    taxable_amount numeric(18, 0) NOT NULL,
    vat_rate numeric(7, 4) NOT NULL,
    vat_amount numeric(18, 0) NOT NULL,
    invoice_total numeric(18, 0) NOT NULL,
    paid_amount numeric(18, 0) NOT NULL DEFAULT 0,
    outstanding_amount numeric(18, 0) NOT NULL,
    status varchar(30) NOT NULL DEFAULT 'DRAFT',
    issued_at timestamptz,
    due_date date,
    cancelled_at timestamptz,
    cancel_reason text,
    created_by uuid NOT NULL REFERENCES app.users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_invoices_status CHECK (
        status IN (
            'DRAFT', 'ISSUED', 'PARTIALLY_PAID', 'PAID',
            'OVERDUE', 'CANCELLED'
        )
    ),
    CONSTRAINT ck_invoices_amounts CHECK (
        royalty_fee >= 0 AND system_fee >= 0 AND service_fee >= 0
        AND initial_fee_installment >= 0 AND positive_adjustments >= 0
        AND brand_promotion_support >= 0 AND carried_credit >= 0
        AND negative_adjustments >= 0 AND fee_subtotal >= 0
        AND deductions >= 0 AND taxable_amount >= 0 AND vat_amount >= 0
        AND invoice_total >= 0 AND paid_amount >= 0
        AND outstanding_amount >= 0
    )
);

CREATE TABLE app.invoice_items (
    id uuid PRIMARY KEY,
    invoice_id uuid NOT NULL REFERENCES app.invoices(id),
    item_type varchar(50) NOT NULL,
    description varchar(300) NOT NULL,
    amount numeric(18, 0) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE app.payments (
    id uuid PRIMARY KEY,
    payment_no varchar(100) NOT NULL UNIQUE,
    invoice_id uuid NOT NULL REFERENCES app.invoices(id),
    amount numeric(18, 0) NOT NULL,
    payment_date date NOT NULL,
    method varchar(30) NOT NULL,
    reference_no varchar(100),
    status varchar(20) NOT NULL DEFAULT 'CONFIRMED',
    recorded_by uuid NOT NULL REFERENCES app.users(id),
    reversed_by uuid REFERENCES app.users(id),
    reversed_at timestamptz,
    reversal_reason text,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_payments_amount CHECK (amount > 0),
    CONSTRAINT ck_payments_status CHECK (status IN ('CONFIRMED', 'REVERSED')),
    CONSTRAINT ck_payments_method CHECK (
        method IN ('BANK_TRANSFER', 'CASH', 'OTHER')
    )
);

CREATE TABLE app.notifications (
    id uuid PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES app.users(id),
    notification_type varchar(50) NOT NULL,
    title varchar(200) NOT NULL,
    message text NOT NULL,
    entity_type varchar(50),
    entity_id uuid,
    dedupe_key varchar(200) UNIQUE,
    read_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ix_contract_financial_contract
    ON app.contract_financial_transactions (contract_id, transaction_type);

CREATE INDEX ix_promotions_active_dates
    ON app.promotions (status, start_date, end_date)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_revenues_store_date
    ON app.revenues (store_id, business_date DESC);

CREATE INDEX ix_revenues_status_date
    ON app.revenues (status, business_date DESC);

CREATE UNIQUE INDEX uq_invoices_one_current_per_period
    ON app.invoices (store_id, period_month)
    WHERE status <> 'CANCELLED';

CREATE INDEX ix_invoices_store_period
    ON app.invoices (store_id, period_month DESC);

CREATE INDEX ix_invoices_status_due
    ON app.invoices (status, due_date);

CREATE INDEX ix_payments_invoice ON app.payments (invoice_id, created_at);

CREATE INDEX ix_notifications_user_unread
    ON app.notifications (user_id, created_at DESC)
    WHERE read_at IS NULL;

ALTER TABLE app.billing_adjustments
    ADD CONSTRAINT fk_billing_adjustments_invoice
    FOREIGN KEY (applied_invoice_id) REFERENCES app.invoices(id);

ALTER TABLE app.store_credits
    ADD CONSTRAINT fk_store_credits_invoice
    FOREIGN KEY (source_invoice_id) REFERENCES app.invoices(id);
