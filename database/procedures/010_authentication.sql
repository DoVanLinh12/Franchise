-- Stored procedures/functions for 010_authentication.sql.

-- Keep an existing local database aligned with the simplified auth scope.
ALTER TABLE app.users
    DROP CONSTRAINT IF EXISTS ck_users_failed_login_attempts,
    DROP COLUMN IF EXISTS failed_login_attempts,
    DROP COLUMN IF EXISTS locked_until;
UPDATE app.users SET status = 'INACTIVE' WHERE status = 'LOCKED';
ALTER TABLE app.users DROP CONSTRAINT IF EXISTS ck_users_status;
ALTER TABLE app.users ADD CONSTRAINT ck_users_status
    CHECK (status IN ('ACTIVE', 'INACTIVE'));
DROP TABLE IF EXISTS app.refresh_tokens;
DROP PROCEDURE IF EXISTS app.proc_record_login_failure(text, integer, integer);
DO $$
DECLARE
    old_routine record;
BEGIN
    FOR old_routine IN
        SELECT p.oid::regprocedure AS signature
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'app'
          AND p.prokind = 'p'
          AND p.proname IN (
              'proc_store_refresh_token',
              'proc_rotate_refresh_token',
              'proc_revoke_refresh_token'
          )
    LOOP
        EXECUTE 'DROP PROCEDURE ' || old_routine.signature;
    END LOOP;
END;
$$;
DROP FUNCTION IF EXISTS app.fn_get_user_auth_by_email(text);

CREATE OR REPLACE PROCEDURE app.proc_register_user(
    p_user_id uuid,
    p_email text,
    p_password_hash text,
    p_full_name text,
    p_phone text
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_user app.users%ROWTYPE;
BEGIN
    IF nullif(btrim(p_email), '') IS NULL
       OR nullif(btrim(p_password_hash), '') IS NULL
       OR nullif(btrim(p_full_name), '') IS NULL THEN
        RAISE EXCEPTION 'USER_REQUIRED_FIELDS_MISSING';
    END IF;

    INSERT INTO app.users (id, email, password_hash, full_name, phone)
    VALUES (
        p_user_id,
        lower(btrim(p_email)),
        p_password_hash,
        btrim(p_full_name),
        nullif(btrim(p_phone), '')
    )
    RETURNING * INTO v_user;

    INSERT INTO app.audit_logs (
        actor_id, action, entity_type, entity_id, new_values
    )
    VALUES (
        p_user_id,
        'REGISTER_USER',
        'USER',
        p_user_id,
        to_jsonb(v_user) - 'password_hash'
    );
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'EMAIL_ALREADY_EXISTS';
END;
$$;

CREATE OR REPLACE FUNCTION app.fn_get_user_auth_by_email(p_email text)
RETURNS TABLE (
    id uuid,
    email varchar,
    password_hash text,
    full_name varchar,
    status varchar,
    deleted_at timestamptz
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        u.id, u.email, u.password_hash, u.full_name, u.status,
        u.deleted_at
    FROM app.users u
    WHERE lower(u.email) = lower(btrim(p_email))
      AND u.deleted_at IS NULL;
$$;

CREATE OR REPLACE FUNCTION app.fn_get_user(p_user_id uuid)
RETURNS TABLE (
    id uuid,
    email varchar,
    full_name varchar,
    phone varchar,
    status varchar,
    password_changed_at timestamptz,
    last_login_at timestamptz,
    created_at timestamptz,
    updated_at timestamptz
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        u.id, u.email, u.full_name, u.phone, u.status,
        u.password_changed_at, u.last_login_at, u.created_at, u.updated_at
    FROM app.users u
    WHERE u.id = p_user_id
      AND u.deleted_at IS NULL;
$$;

CREATE OR REPLACE FUNCTION app.fn_get_user_roles(p_user_id uuid)
RETURNS TABLE (code varchar)
LANGUAGE sql
STABLE
AS $$
    SELECT r.code
    FROM app.user_roles ur
    JOIN app.roles r ON r.id = ur.role_id
    WHERE ur.user_id = p_user_id
    ORDER BY r.code;
$$;

CREATE OR REPLACE PROCEDURE app.proc_record_login_success(p_user_id uuid)
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM app.assert_active_user(p_user_id);

    UPDATE app.users
    SET last_login_at = now(),
        updated_at = now()
    WHERE id = p_user_id;

    INSERT INTO app.audit_logs (
        actor_id, action, entity_type, entity_id
    )
    VALUES (p_user_id, 'LOGIN_SUCCESS', 'USER', p_user_id);
END;
$$;

CREATE OR REPLACE PROCEDURE app.proc_update_password_hash(
    p_user_id uuid,
    p_password_hash text
)
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM app.assert_active_user(p_user_id);
    UPDATE app.users
    SET password_hash = p_password_hash,
        updated_at = now()
    WHERE id = p_user_id;
END;
$$;

CREATE OR REPLACE PROCEDURE app.proc_create_password_reset_token(
    p_token_id uuid,
    p_user_id uuid,
    p_token_hash text,
    p_expires_at timestamptz,
    p_ip_address inet
)
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM app.assert_active_user(p_user_id);

    UPDATE app.password_reset_tokens
    SET used_at = now()
    WHERE user_id = p_user_id
      AND used_at IS NULL;

    INSERT INTO app.password_reset_tokens (
        id, user_id, token_hash, expires_at, requested_by_ip
    )
    VALUES (p_token_id, p_user_id, p_token_hash, p_expires_at, p_ip_address);
END;
$$;

CREATE OR REPLACE PROCEDURE app.proc_reset_password(
    p_token_hash text,
    p_new_password_hash text
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_token app.password_reset_tokens%ROWTYPE;
BEGIN
    SELECT * INTO v_token
    FROM app.password_reset_tokens
    WHERE token_hash = p_token_hash
    FOR UPDATE;

    IF NOT FOUND
       OR v_token.used_at IS NOT NULL
       OR v_token.expires_at <= now()
       OR NOT app.is_active_user(v_token.user_id) THEN
        RAISE EXCEPTION 'PASSWORD_RESET_TOKEN_INVALID';
    END IF;

    UPDATE app.password_reset_tokens
    SET used_at = now()
    WHERE id = v_token.id;

    UPDATE app.users
    SET password_hash = p_new_password_hash,
        password_changed_at = now(),
        updated_at = now()
    WHERE id = v_token.user_id;

    INSERT INTO app.audit_logs (
        actor_id, action, entity_type, entity_id
    )
    VALUES (v_token.user_id, 'PASSWORD_RESET', 'USER', v_token.user_id);
END;
$$;

CREATE OR REPLACE PROCEDURE app.proc_change_user_status(
    p_user_id uuid,
    p_actor_id uuid,
    p_new_status text,
    p_reason text
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_user app.users%ROWTYPE;
    v_active_admin_count integer;
BEGIN
    PERFORM app.assert_role(p_actor_id, 'ADMIN');
    IF p_new_status NOT IN ('ACTIVE', 'INACTIVE') THEN
        RAISE EXCEPTION 'USER_STATUS_INVALID';
    END IF;
    IF nullif(btrim(p_reason), '') IS NULL THEN
        RAISE EXCEPTION 'STATUS_CHANGE_REASON_REQUIRED';
    END IF;

    SELECT * INTO v_user FROM app.users
    WHERE id = p_user_id AND deleted_at IS NULL
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'USER_NOT_FOUND';
    END IF;

    IF v_user.status = 'ACTIVE'
       AND p_new_status <> 'ACTIVE'
       AND app.user_has_role(p_user_id, 'ADMIN') THEN
        SELECT count(*) INTO v_active_admin_count
        FROM app.user_roles ur
        JOIN app.roles r ON r.id = ur.role_id
        JOIN app.users u ON u.id = ur.user_id
        WHERE r.code = 'ADMIN'
          AND u.status = 'ACTIVE'
          AND u.deleted_at IS NULL;
        IF v_active_admin_count <= 1 THEN
            RAISE EXCEPTION 'LAST_ACTIVE_ADMIN_REQUIRED';
        END IF;
    END IF;

    UPDATE app.users
    SET status = p_new_status,
        updated_at = now()
    WHERE id = p_user_id;

    INSERT INTO app.audit_logs (
        actor_id, action, entity_type, entity_id,
        old_values, new_values, reason
    )
    VALUES (
        p_actor_id, 'CHANGE_USER_STATUS', 'USER', p_user_id,
        jsonb_build_object('status', v_user.status),
        jsonb_build_object('status', p_new_status),
        btrim(p_reason)
    );
END;
$$;

CREATE OR REPLACE PROCEDURE app.proc_assign_user_role(
    p_user_id uuid,
    p_role_code text,
    p_actor_id uuid
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_role_id smallint;
BEGIN
    PERFORM app.assert_role(p_actor_id, 'ADMIN');
    PERFORM app.assert_active_user(p_user_id);
    SELECT id INTO v_role_id FROM app.roles WHERE code = upper(btrim(p_role_code));
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ROLE_NOT_FOUND';
    END IF;
    IF EXISTS (
        SELECT 1 FROM app.user_roles
        WHERE user_id = p_user_id AND role_id = v_role_id
    ) THEN
        RAISE EXCEPTION 'ROLE_ALREADY_ASSIGNED';
    END IF;

    INSERT INTO app.user_roles (user_id, role_id)
    VALUES (p_user_id, v_role_id);
    INSERT INTO app.audit_logs (
        actor_id, action, entity_type, entity_id, new_values
    ) VALUES (
        p_actor_id, 'ASSIGN_ROLE', 'USER', p_user_id,
        jsonb_build_object('role', upper(btrim(p_role_code)))
    );
END;
$$;

CREATE OR REPLACE PROCEDURE app.proc_remove_user_role(
    p_user_id uuid,
    p_role_code text,
    p_actor_id uuid
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_role_id smallint;
    v_active_admin_count integer;
BEGIN
    PERFORM app.assert_role(p_actor_id, 'ADMIN');
    SELECT id INTO v_role_id FROM app.roles WHERE code = upper(btrim(p_role_code));
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ROLE_NOT_FOUND';
    END IF;
    IF upper(btrim(p_role_code)) = 'ADMIN' THEN
        SELECT count(*) INTO v_active_admin_count
        FROM app.user_roles ur
        JOIN app.roles r ON r.id = ur.role_id
        JOIN app.users u ON u.id = ur.user_id
        WHERE r.code = 'ADMIN'
          AND u.status = 'ACTIVE'
          AND u.deleted_at IS NULL;
        IF app.user_has_role(p_user_id, 'ADMIN')
           AND v_active_admin_count <= 1 THEN
            RAISE EXCEPTION 'LAST_ACTIVE_ADMIN_REQUIRED';
        END IF;
    END IF;

    DELETE FROM app.user_roles
    WHERE user_id = p_user_id AND role_id = v_role_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ROLE_NOT_ASSIGNED';
    END IF;
    INSERT INTO app.audit_logs (
        actor_id, action, entity_type, entity_id, old_values
    ) VALUES (
        p_actor_id, 'REMOVE_ROLE', 'USER', p_user_id,
        jsonb_build_object('role', upper(btrim(p_role_code)))
    );
END;
$$;
