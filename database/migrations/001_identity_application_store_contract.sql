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
    CONSTRAINT ck_users_status
        CHECK (status IN ('ACTIVE', 'INACTIVE', 'LOCKED'))
);

CREATE UNIQUE INDEX uq_users_email_active
    ON app.users (lower(email))
    WHERE deleted_at IS NULL;

CREATE TABLE app.roles (
    id smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(30) NOT NULL UNIQUE,
    name varchar(100) NOT NULL
);

INSERT INTO app.roles (code, name)
VALUES
    ('ADMIN', 'Administrator'),
    ('STORE_OWNER', 'Store Owner'),
    ('ACCOUNTANT', 'Accountant')
ON CONFLICT (code) DO NOTHING;

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

CREATE UNIQUE INDEX uq_franchise_applications_one_open_per_user
    ON app.franchise_applications (applicant_id)
    WHERE deleted_at IS NULL
      AND (
          status IN ('PENDING', 'UNDER_REVIEW')
          OR (status = 'APPROVED' AND converted_at IS NULL)
      );

CREATE INDEX ix_franchise_applications_status
    ON app.franchise_applications (status);

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

CREATE INDEX ix_stores_owner_id ON app.stores (owner_id);
CREATE INDEX ix_stores_status ON app.stores (status);

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

CREATE UNIQUE INDEX uq_contracts_one_active_per_store
    ON app.contracts (store_id)
    WHERE status = 'ACTIVE';

CREATE INDEX ix_contracts_store_id ON app.contracts (store_id);
CREATE INDEX ix_contracts_status ON app.contracts (status);

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

CREATE INDEX ix_audit_logs_entity
    ON app.audit_logs (entity_type, entity_id, created_at DESC);

CREATE INDEX ix_audit_logs_actor
    ON app.audit_logs (actor_id, created_at DESC);

CREATE OR REPLACE FUNCTION app.prevent_audit_log_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'AUDIT_LOG_IMMUTABLE';
END;
$$;

CREATE TRIGGER trg_audit_logs_immutable
BEFORE UPDATE OR DELETE ON app.audit_logs
FOR EACH ROW
EXECUTE FUNCTION app.prevent_audit_log_mutation();
