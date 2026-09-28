ALTER TABLE app.users
    ADD COLUMN password_changed_at timestamptz NOT NULL DEFAULT now(),
    ADD COLUMN last_login_at timestamptz,
    ADD COLUMN failed_login_attempts integer NOT NULL DEFAULT 0,
    ADD COLUMN locked_until timestamptz,
    ADD CONSTRAINT ck_users_failed_login_attempts
        CHECK (failed_login_attempts >= 0);

CREATE TABLE app.refresh_tokens (
    id uuid PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES app.users(id),
    token_hash char(64) NOT NULL UNIQUE,
    expires_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    revoked_at timestamptz,
    revoke_reason varchar(100),
    replaced_by_token_id uuid REFERENCES app.refresh_tokens(id),
    created_by_ip inet,
    user_agent varchar(500),
    CONSTRAINT ck_refresh_tokens_expiry CHECK (expires_at > created_at),
    CONSTRAINT ck_refresh_tokens_revocation CHECK (
        (revoked_at IS NULL AND revoke_reason IS NULL)
        OR (revoked_at IS NOT NULL AND revoke_reason IS NOT NULL)
    )
);

CREATE INDEX ix_refresh_tokens_user_active
    ON app.refresh_tokens (user_id, expires_at DESC)
    WHERE revoked_at IS NULL;

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
