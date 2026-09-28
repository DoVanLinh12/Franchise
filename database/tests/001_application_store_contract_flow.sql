BEGIN;

INSERT INTO app.users (id, email, password_hash, full_name)
VALUES
    (
        '00000000-0000-0000-0000-000000000001',
        'admin.integration@example.com',
        'test-only',
        'Integration Admin'
    ),
    (
        '00000000-0000-0000-0000-000000000002',
        'owner.integration@example.com',
        'test-only',
        'Integration Owner'
    );

INSERT INTO app.user_roles (user_id, role_id)
SELECT
    '00000000-0000-0000-0000-000000000001',
    id
FROM app.roles
WHERE code = 'ADMIN';

CALL app.proc_submit_franchise_application(
    '10000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000002',
    'Integration Owner',
    'owner.integration@example.com',
    '0900000000',
    'Integration Store',
    'Integration Address',
    100,
    500000000,
    'Database integration test'
);

CALL app.proc_start_application_review(
    '10000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001'
);

CALL app.proc_approve_franchise_application(
    '10000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    'Approved by integration test'
);

CALL app.proc_create_store_from_application(
    '20000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000002',
    'TEST-STORE-001',
    'Integration Store',
    'Integration Address',
    '0900000000',
    'store.integration@example.com'
);

CALL app.proc_create_draft_contract(
    '30000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    'TEST-CONTRACT-001',
    DATE '2026-09-25',
    DATE '2026-10-01',
    DATE '2027-09-30',
    5.5,
    100000000,
    20000000,
    1000000,
    2000000
);

DO $$
DECLARE
    v_application_status text;
    v_application_converted_at timestamptz;
    v_store_status text;
    v_contract_status text;
    v_is_store_owner boolean;
    v_audit_count integer;
BEGIN
    SELECT status, converted_at
    INTO v_application_status, v_application_converted_at
    FROM app.fn_get_franchise_application(
        '10000000-0000-0000-0000-000000000001'
    );

    SELECT status INTO v_store_status
    FROM app.fn_get_store('20000000-0000-0000-0000-000000000001');

    SELECT status INTO v_contract_status
    FROM app.fn_get_contract('30000000-0000-0000-0000-000000000001');

    v_is_store_owner := app.user_has_role(
        '00000000-0000-0000-0000-000000000002',
        'STORE_OWNER'
    );

    SELECT count(*) INTO v_audit_count
    FROM app.audit_logs
    WHERE entity_id IN (
        '10000000-0000-0000-0000-000000000001',
        '20000000-0000-0000-0000-000000000001',
        '30000000-0000-0000-0000-000000000001'
    );

    IF v_application_status <> 'APPROVED' THEN
        RAISE EXCEPTION 'Expected APPROVED application';
    END IF;
    IF v_application_converted_at IS NULL THEN
        RAISE EXCEPTION 'Expected converted application';
    END IF;
    IF v_store_status <> 'INACTIVE' THEN
        RAISE EXCEPTION 'Expected INACTIVE store';
    END IF;
    IF v_contract_status <> 'DRAFT' THEN
        RAISE EXCEPTION 'Expected DRAFT contract';
    END IF;
    IF NOT v_is_store_owner THEN
        RAISE EXCEPTION 'Expected STORE_OWNER role assignment';
    END IF;
    IF v_audit_count <> 5 THEN
        RAISE EXCEPTION 'Expected 5 audit records, found %', v_audit_count;
    END IF;
END;
$$;

ROLLBACK;
