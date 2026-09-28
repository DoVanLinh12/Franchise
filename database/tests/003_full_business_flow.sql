BEGIN;

CALL app.proc_register_user(
    '30000000-0000-0000-0000-000000000001',
    'phase-admin@example.com', 'hash', 'Phase Admin', NULL
);
CALL app.proc_register_user(
    '30000000-0000-0000-0000-000000000002',
    'phase-owner@example.com', 'hash', 'Phase Owner', NULL
);
CALL app.proc_register_user(
    '30000000-0000-0000-0000-000000000003',
    'phase-accountant@example.com', 'hash', 'Phase Accountant', NULL
);
INSERT INTO app.user_roles (user_id, role_id)
SELECT '30000000-0000-0000-0000-000000000001', id
FROM app.roles WHERE code = 'ADMIN';
CALL app.proc_assign_user_role(
    '30000000-0000-0000-0000-000000000003', 'ACCOUNTANT',
    '30000000-0000-0000-0000-000000000001'
);

CALL app.proc_submit_franchise_application(
    '31000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000002',
    'Phase Owner', 'phase-owner@example.com', '0900000000',
    'Phase Store', 'Phase Address', 100, 500000000, NULL
);
CALL app.proc_start_application_review(
    '31000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001'
);
CALL app.proc_approve_franchise_application(
    '31000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001', 'Approved'
);
CALL app.proc_create_store_from_application(
    '32000000-0000-0000-0000-000000000001',
    '31000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000002',
    'PHASE-001', 'Phase Store', 'Phase Address', NULL, NULL
);
CALL app.proc_create_draft_contract(
    '33000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    '32000000-0000-0000-0000-000000000001',
    'PHASE-CONTRACT-001', current_date,
    date_trunc('month', current_date)::date,
    (date_trunc('month', current_date) + interval '1 year')::date,
    5, 100000000, 20000000, 1000000, 2000000
);
CALL app.proc_record_contract_financial_transaction(
    '34000000-0000-0000-0000-000000000001',
    '33000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    'INITIAL_FEE_PAYMENT', 20000000, current_date, 'BANK-001', NULL
);
CALL app.proc_activate_contract(
    '33000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001'
);

CALL app.proc_create_promotion(
    '35000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    'Phase Promotion', NULL, 'FIXED_AMOUNT', 100000,
    current_date, current_date + 7, 'ALL_STORES', 'SHARED', 60, 40,
    ARRAY[]::uuid[]
);
CALL app.proc_change_promotion_status(
    '35000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001', 'ACTIVE', NULL
);

CALL app.proc_save_revenue(
    '36000000-0000-0000-0000-000000000001',
    '32000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000002',
    current_date, 10000000, 'Daily revenue',
    '[{"promotion_id":"35000000-0000-0000-0000-000000000001",'
    '"discount_amount":100000}]'::jsonb
);
CALL app.proc_submit_revenue(
    '36000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000002'
);
CALL app.proc_review_revenue(
    '36000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000003', 'APPROVED', NULL
);

CALL app.proc_generate_monthly_invoice(
    '37000000-0000-0000-0000-000000000001', 'PHASE-INV-001',
    '32000000-0000-0000-0000-000000000001',
    date_trunc('month', current_date)::date, 10,
    '30000000-0000-0000-0000-000000000003'
);
CALL app.proc_issue_invoice(
    '37000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000003'
);
CALL app.proc_record_payment(
    '38000000-0000-0000-0000-000000000001', 'PHASE-PAY-001',
    '37000000-0000-0000-0000-000000000001', 1892000,
    current_date, 'BANK_TRANSFER', 'REF-001',
    '30000000-0000-0000-0000-000000000003'
);
CALL app.proc_record_payment(
    '38000000-0000-0000-0000-000000000002', 'PHASE-PAY-002',
    '37000000-0000-0000-0000-000000000001', 1892000,
    current_date, 'BANK_TRANSFER', 'REF-002',
    '30000000-0000-0000-0000-000000000003'
);

DO $$
DECLARE v_invoice jsonb; v_revenue jsonb; v_count integer;
BEGIN
    SELECT data INTO v_revenue FROM app.fn_get_revenue(
        '36000000-0000-0000-0000-000000000001'
    );
    IF v_revenue->>'status' <> 'APPROVED'
       OR (v_revenue->>'net_revenue')::numeric <> 9900000 THEN
        RAISE EXCEPTION 'REVENUE_FLOW_ASSERTION_FAILED:%', v_revenue;
    END IF;
    SELECT data INTO v_invoice FROM app.fn_get_invoice(
        '37000000-0000-0000-0000-000000000001'
    );
    IF v_invoice->>'status' <> 'PAID'
       OR (v_invoice->>'invoice_total')::numeric <> 3784000
       OR (v_invoice->>'outstanding_amount')::numeric <> 0 THEN
        RAISE EXCEPTION 'INVOICE_FLOW_ASSERTION_FAILED:%', v_invoice;
    END IF;
    SELECT count(*) INTO v_count FROM app.notifications
    WHERE user_id = '30000000-0000-0000-0000-000000000002';
    IF v_count < 3 THEN
        RAISE EXCEPTION 'NOTIFICATION_ASSERTION_FAILED:%', v_count;
    END IF;
END;
$$;

CALL app.proc_reverse_payment(
    '38000000-0000-0000-0000-000000000002',
    '30000000-0000-0000-0000-000000000003', 'Incorrect payment'
);

DO $$
DECLARE v_invoice jsonb;
BEGIN
    SELECT data INTO v_invoice FROM app.fn_get_invoice(
        '37000000-0000-0000-0000-000000000001'
    );
    IF v_invoice->>'status' <> 'PARTIALLY_PAID'
       OR (v_invoice->>'outstanding_amount')::numeric <> 1892000 THEN
        RAISE EXCEPTION 'PAYMENT_REVERSAL_ASSERTION_FAILED:%', v_invoice;
    END IF;
END;
$$;

ROLLBACK;
