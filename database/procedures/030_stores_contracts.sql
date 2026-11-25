-- Stored procedures/functions for 030_stores_contracts.sql.

CREATE OR REPLACE PROCEDURE app.proc_create_store_from_application(
    p_store_id uuid,
    p_application_id uuid,
    p_actor_id uuid,
    p_owner_id uuid,
    p_code text,
    p_name text,
    p_address text,
    p_phone text,
    p_email text
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_application app.franchise_applications%ROWTYPE;
    v_new_store jsonb;
    v_store_owner_role_id smallint;
BEGIN
    PERFORM app.assert_role(p_actor_id, 'ADMIN');
    PERFORM app.assert_active_user(p_owner_id);

    SELECT * INTO v_application
    FROM app.franchise_applications
    WHERE id = p_application_id
      AND deleted_at IS NULL
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'APPLICATION_NOT_FOUND';
    END IF;
    IF v_application.status <> 'APPROVED' THEN
        RAISE EXCEPTION 'APPLICATION_MUST_BE_APPROVED';
    END IF;
    IF v_application.converted_at IS NOT NULL THEN
        RAISE EXCEPTION 'APPLICATION_ALREADY_CONVERTED_TO_STORE';
    END IF;

    INSERT INTO app.stores (
        id, code, name, owner_id, application_id,
        address, phone, email
    )
    VALUES (
        p_store_id,
        btrim(p_code),
        btrim(p_name),
        p_owner_id,
        p_application_id,
        btrim(p_address),
        nullif(btrim(p_phone), ''),
        nullif(lower(btrim(p_email)), '')
    )
    RETURNING to_jsonb(stores) INTO v_new_store;

    UPDATE app.franchise_applications
    SET converted_at = now(), updated_at = now()
    WHERE id = p_application_id;

    SELECT id INTO v_store_owner_role_id
    FROM app.roles
    WHERE code = 'STORE_OWNER';

    INSERT INTO app.user_roles (user_id, role_id)
    VALUES (p_owner_id, v_store_owner_role_id)
    ON CONFLICT DO NOTHING;

    INSERT INTO app.audit_logs (
        actor_id, action, entity_type, entity_id, new_values
    )
    VALUES (
        p_actor_id, 'CREATE_STORE', 'STORE', p_store_id, v_new_store
    );
END;
$$;

CREATE OR REPLACE PROCEDURE app.proc_create_draft_contract(
    p_contract_id uuid,
    p_actor_id uuid,
    p_store_id uuid,
    p_contract_no text,
    p_signed_date date,
    p_effective_from date,
    p_effective_to date,
    p_royalty_rate numeric,
    p_initial_franchise_fee numeric,
    p_deposit_amount numeric,
    p_system_fee numeric,
    p_service_fee numeric
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_store app.stores%ROWTYPE;
    v_new_values jsonb;
BEGIN
    PERFORM app.assert_role(p_actor_id, 'ADMIN');

    SELECT * INTO v_store
    FROM app.stores
    WHERE id = p_store_id
      AND deleted_at IS NULL
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'STORE_NOT_FOUND';
    END IF;

    INSERT INTO app.contracts (
        id, contract_no, store_id, signed_date,
        effective_from, effective_to, royalty_rate,
        initial_franchise_fee, deposit_amount, system_fee, service_fee
    )
    VALUES (
        p_contract_id, btrim(p_contract_no), p_store_id, p_signed_date,
        p_effective_from, p_effective_to, p_royalty_rate,
        p_initial_franchise_fee, p_deposit_amount, p_system_fee, p_service_fee
    )
    RETURNING to_jsonb(contracts) INTO v_new_values;

    INSERT INTO app.audit_logs (
        actor_id, action, entity_type, entity_id, new_values
    )
    VALUES (
        p_actor_id, 'CREATE_CONTRACT', 'CONTRACT',
        p_contract_id, v_new_values
    );
END;
$$;

CREATE OR REPLACE FUNCTION app.fn_get_store(p_store_id uuid)
RETURNS SETOF app.stores
LANGUAGE sql
STABLE
AS $$
    SELECT *
    FROM app.stores
    WHERE id = p_store_id
      AND deleted_at IS NULL;
$$;

CREATE OR REPLACE FUNCTION app.fn_get_contract(p_contract_id uuid)
RETURNS SETOF app.contracts
LANGUAGE sql
STABLE
AS $$
    SELECT *
    FROM app.contracts
    WHERE id = p_contract_id;
$$;

CREATE OR REPLACE PROCEDURE app.proc_record_contract_financial_transaction(
    p_transaction_id uuid,
    p_contract_id uuid,
    p_actor_id uuid,
    p_transaction_type text,
    p_amount numeric,
    p_transaction_date date,
    p_reference_no text,
    p_note text
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_contract app.contracts%ROWTYPE;
BEGIN
    PERFORM app.assert_role(p_actor_id, 'ADMIN');
    SELECT * INTO v_contract FROM app.contracts
    WHERE id = p_contract_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'CONTRACT_NOT_FOUND'; END IF;
    IF v_contract.status <> 'DRAFT' THEN
        RAISE EXCEPTION 'CONTRACT_MUST_BE_DRAFT';
    END IF;
    IF p_transaction_type NOT IN ('INITIAL_FEE_PAYMENT', 'DEPOSIT_PAYMENT')
       OR p_amount <= 0 THEN
        RAISE EXCEPTION 'CONTRACT_FINANCIAL_TRANSACTION_INVALID';
    END IF;

    INSERT INTO app.contract_financial_transactions (
        id, contract_id, transaction_type, amount, transaction_date,
        reference_no, note, recorded_by
    ) VALUES (
        p_transaction_id, p_contract_id, p_transaction_type, p_amount,
        p_transaction_date, nullif(btrim(p_reference_no), ''),
        nullif(btrim(p_note), ''), p_actor_id
    );
    INSERT INTO app.audit_logs (
        actor_id, action, entity_type, entity_id, new_values
    ) VALUES (
        p_actor_id, 'RECORD_CONTRACT_PAYMENT', 'CONTRACT', p_contract_id,
        jsonb_build_object('type', p_transaction_type, 'amount', p_amount)
    );
END;
$$;

CREATE OR REPLACE PROCEDURE app.proc_activate_contract(
    p_contract_id uuid,
    p_actor_id uuid
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_contract app.contracts%ROWTYPE;
    v_initial_paid numeric;
    v_required numeric;
BEGIN
    PERFORM app.assert_role(p_actor_id, 'ADMIN');
    SELECT * INTO v_contract FROM app.contracts
    WHERE id = p_contract_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'CONTRACT_NOT_FOUND'; END IF;
    IF v_contract.status <> 'DRAFT' THEN
        RAISE EXCEPTION 'CONTRACT_MUST_BE_DRAFT';
    END IF;
    IF v_contract.signed_date IS NULL THEN
        RAISE EXCEPTION 'CONTRACT_SIGNED_DATE_REQUIRED';
    END IF;
    IF EXISTS (
        SELECT 1 FROM app.contracts
        WHERE store_id = v_contract.store_id AND status = 'ACTIVE'
    ) THEN
        RAISE EXCEPTION 'ACTIVE_CONTRACT_ALREADY_EXISTS';
    END IF;
    SELECT coalesce(sum(amount), 0) INTO v_initial_paid
    FROM app.contract_financial_transactions
    WHERE contract_id = p_contract_id
      AND transaction_type = 'INITIAL_FEE_PAYMENT';
    v_required := ceil(v_contract.initial_franchise_fee * 0.20);
    IF v_initial_paid < v_required THEN
        RAISE EXCEPTION 'INITIAL_FEE_20_PERCENT_REQUIRED:%', v_required;
    END IF;

    UPDATE app.contracts SET status = 'ACTIVE', updated_at = now()
    WHERE id = p_contract_id;
    UPDATE app.stores
    SET status = 'ACTIVE', activated_at = coalesce(activated_at, now()),
        updated_at = now()
    WHERE id = v_contract.store_id AND status = 'INACTIVE';
    INSERT INTO app.audit_logs (
        actor_id, action, entity_type, entity_id, old_values, new_values
    ) VALUES (
        p_actor_id, 'ACTIVATE_CONTRACT', 'CONTRACT', p_contract_id,
        jsonb_build_object('status', 'DRAFT'),
        jsonb_build_object('status', 'ACTIVE', 'initial_paid', v_initial_paid)
    );
END;
$$;
