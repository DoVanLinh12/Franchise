-- Stored procedures/functions for 001_authorization.sql.

CREATE OR REPLACE FUNCTION app.is_active_user(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM app.users u
        WHERE u.id = p_user_id
          AND u.status = 'ACTIVE'
          AND u.deleted_at IS NULL
    );
$$;

CREATE OR REPLACE FUNCTION app.user_has_role(
    p_user_id uuid,
    p_role_code text
)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM app.users u
        WHERE u.id = p_user_id
          AND p_role_code = ANY (u.roles)
          AND u.status = 'ACTIVE'
          AND u.deleted_at IS NULL
    );
$$;

CREATE OR REPLACE FUNCTION app.assert_active_user(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT app.is_active_user(p_user_id) THEN
        RAISE EXCEPTION 'USER_NOT_ACTIVE';
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION app.assert_role(
    p_user_id uuid,
    p_role_code text
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT app.user_has_role(p_user_id, p_role_code) THEN
        RAISE EXCEPTION 'ROLE_REQUIRED:%', p_role_code;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION app.user_can_access_store(
    p_user_id uuid, p_store_id uuid
)
RETURNS boolean
LANGUAGE sql STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 FROM app.stores s
        WHERE s.id = p_store_id AND s.deleted_at IS NULL
          AND (
              s.owner_id = p_user_id
              OR app.user_has_role(p_user_id, 'ADMIN')
              OR app.user_has_role(p_user_id, 'ACCOUNTANT')
          )
    );
$$;
