BEGIN;

CALL app.proc_register_user(
    '20000000-0000-0000-0000-000000000001',
    'admin@example.com',
    'argon2-test-hash',
    'Admin User',
    '0900000001'
);

INSERT INTO app.user_roles (user_id, role_id)
SELECT '20000000-0000-0000-0000-000000000001', id
FROM app.roles WHERE code = 'ADMIN';

CALL app.proc_register_user(
    '20000000-0000-0000-0000-000000000002',
    'owner@example.com',
    'argon2-owner-hash',
    'Owner User',
    '0900000002'
);

CALL app.proc_assign_user_role(
    '20000000-0000-0000-0000-000000000002',
    'STORE_OWNER',
    '20000000-0000-0000-0000-000000000001'
);

CALL app.proc_record_login_failure('owner@example.com', 5, 15);
CALL app.proc_record_login_success(
    '20000000-0000-0000-0000-000000000002'
);

CALL app.proc_store_refresh_token(
    '21000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000002',
    repeat('a', 64),
    now() + interval '7 days',
    '127.0.0.1',
    'database-integration-test'
);

CALL app.proc_rotate_refresh_token(
    repeat('a', 64),
    '20000000-0000-0000-0000-000000000002',
    '21000000-0000-0000-0000-000000000002',
    repeat('b', 64),
    now() + interval '7 days',
    '127.0.0.1',
    'database-integration-test'
);

CALL app.proc_create_password_reset_token(
    '22000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000002',
    repeat('c', 64),
    now() + interval '30 minutes',
    '127.0.0.1'
);

CALL app.proc_reset_password(repeat('c', 64), 'argon2-new-hash');

DO $$
DECLARE
    v_user record;
    v_old_token record;
    v_new_token record;
    v_role_count integer;
    v_audit_count integer;
BEGIN
    SELECT * INTO v_user
    FROM app.fn_get_user_auth_by_email('owner@example.com');
    IF v_user.password_hash <> 'argon2-new-hash'
       OR v_user.failed_login_attempts <> 0
       OR v_user.locked_until IS NOT NULL THEN
        RAISE EXCEPTION 'AUTH_USER_STATE_ASSERTION_FAILED';
    END IF;

    SELECT * INTO v_old_token FROM app.refresh_tokens
    WHERE id = '21000000-0000-0000-0000-000000000001';
    SELECT * INTO v_new_token FROM app.refresh_tokens
    WHERE id = '21000000-0000-0000-0000-000000000002';
    IF v_old_token.revoke_reason <> 'ROTATED'
       OR v_new_token.revoke_reason <> 'PASSWORD_RESET' THEN
        RAISE EXCEPTION 'REFRESH_TOKEN_ROTATION_ASSERTION_FAILED';
    END IF;

    SELECT count(*) INTO v_role_count
    FROM app.fn_get_user_roles(
        '20000000-0000-0000-0000-000000000002'
    ) WHERE code = 'STORE_OWNER';
    IF v_role_count <> 1 THEN
        RAISE EXCEPTION 'ROLE_ASSERTION_FAILED';
    END IF;

    SELECT count(*) INTO v_audit_count
    FROM app.audit_logs
    WHERE entity_id = '20000000-0000-0000-0000-000000000002'
      AND action IN (
          'REGISTER_USER', 'ASSIGN_ROLE', 'LOGIN_FAILED',
          'LOGIN_SUCCESS', 'REFRESH_TOKEN_ROTATED', 'PASSWORD_RESET'
      );
    IF v_audit_count <> 6 THEN
        RAISE EXCEPTION 'AUTH_AUDIT_ASSERTION_FAILED:%', v_audit_count;
    END IF;
END;
$$;

CALL app.proc_change_user_status(
    '20000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000001',
    'INACTIVE',
    'Integration test'
);

DO $$
BEGIN
    IF app.is_active_user(
        '20000000-0000-0000-0000-000000000002'
    ) THEN
        RAISE EXCEPTION 'USER_STATUS_ASSERTION_FAILED';
    END IF;
END;
$$;

ROLLBACK;
