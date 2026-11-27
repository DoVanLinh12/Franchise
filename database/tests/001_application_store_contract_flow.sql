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

UPDATE app.users SET roles = ARRAY['ADMIN']::varchar(30)[]
WHERE id = '00000000-0000-0000-0000-000000000001';

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

CALL app.proc_create_draft_contract(
    '30000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'TEST-CONTRACT-001',
    DATE '2026-09-25',
    DATE '2026-10-01',
    DATE '2027-09-30',
    5.5,
    100000000,
    20000000,
    1000000,
    2000000,
    '20000000-0000-0000-0000-000000000001'
);

-- Making the contract creates the store automatically, not yet open.
DO $$
DECLARE v_store app.stores%ROWTYPE; v_contract app.contracts%ROWTYPE;
BEGIN
    SELECT * INTO v_store FROM app.fn_get_store('20000000-0000-0000-0000-000000000001');
    SELECT * INTO v_contract FROM app.fn_get_contract('30000000-0000-0000-0000-000000000001');
    IF v_store.status <> 'INACTIVE' OR v_store.code !~ '^CH[0-9]{4}$'
       OR v_store.name <> 'Integration Store' OR v_store.address <> 'Integration Address'
       OR v_store.owner_id <> '00000000-0000-0000-0000-000000000002'
       OR v_store.activated_at IS NOT NULL THEN
        RAISE EXCEPTION 'Expected an INACTIVE store generated from the application: %', to_jsonb(v_store);
    END IF;
    IF v_contract.status <> 'DRAFT' OR v_contract.store_id <> v_store.id THEN
        RAISE EXCEPTION 'Draft contract must be linked to the new store';
    END IF;
    IF (SELECT converted_at FROM app.fn_get_franchise_application(
            '10000000-0000-0000-0000-000000000001')) IS NULL THEN
        RAISE EXCEPTION 'Application must be converted when the contract is made';
    END IF;
    IF NOT app.user_has_role('00000000-0000-0000-0000-000000000002', 'STORE_OWNER') THEN
        RAISE EXCEPTION 'Expected STORE_OWNER role assignment';
    END IF;
END;
$$;

CALL app.proc_record_contract_financial_transaction(
    '40000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    'INITIAL_FEE_PAYMENT', 20000000, DATE '2026-09-25', 'BANK-INT-001', NULL
);

CALL app.proc_activate_contract(
    '30000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001'
);

DO $$
DECLARE v_store app.stores%ROWTYPE; v_actions text[];
BEGIN
    SELECT * INTO v_store FROM app.fn_get_store('20000000-0000-0000-0000-000000000001');
    IF v_store.status <> 'ACTIVE' OR v_store.activated_at IS NULL THEN
        RAISE EXCEPTION 'Store must open when the contract is activated';
    END IF;
    IF (SELECT status FROM app.fn_get_contract('30000000-0000-0000-0000-000000000001')) <> 'ACTIVE' THEN
        RAISE EXCEPTION 'Expected ACTIVE contract';
    END IF;
    SELECT array_agg(action ORDER BY action) INTO v_actions
    FROM app.audit_logs
    WHERE entity_id IN ('20000000-0000-0000-0000-000000000001',
                        '30000000-0000-0000-0000-000000000001');
    IF v_actions <> ARRAY['ACTIVATE_CONTRACT', 'CREATE_CONTRACT', 'CREATE_STORE',
                          'RECORD_CONTRACT_PAYMENT']::text[] THEN
        RAISE EXCEPTION 'Unexpected audit actions: %', v_actions;
    END IF;
END;
$$;

ROLLBACK;
