-- Stored procedures/functions for 030_stores_contracts.sql.

-- A store is created automatically (INACTIVE) as soon as a contract is made
-- from an approved application, and opened when the contract is activated.

CREATE OR REPLACE FUNCTION app.fn_next_store_code()
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE v_code text;
BEGIN
    LOOP
        v_code := 'CH' || lpad(nextval('app.store_code_seq')::text, 4, '0');
        EXIT WHEN NOT EXISTS (SELECT 1 FROM app.stores WHERE code = v_code);
    END LOOP;
    RETURN v_code;
END;
$$;

CREATE OR REPLACE PROCEDURE app.proc_create_draft_contract(
    p_contract_id uuid,
    p_actor_id uuid,
    p_application_id uuid,
    p_contract_no text,
    p_signed_date date,
    p_effective_from date,
    p_effective_to date,
    p_royalty_rate numeric,
    p_initial_franchise_fee numeric,
    p_deposit_amount numeric,
    p_system_fee numeric,
    p_service_fee numeric,
    p_store_id uuid DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_application app.franchise_applications%ROWTYPE;
    v_applicant app.users%ROWTYPE;
    v_store app.stores%ROWTYPE;
    v_new_values jsonb;
BEGIN
    PERFORM app.assert_role(p_actor_id, 'ADMIN');

    SELECT * INTO v_application
    FROM app.franchise_applications
    WHERE id = p_application_id AND deleted_at IS NULL
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'APPLICATION_NOT_FOUND';
    END IF;
    IF v_application.status <> 'APPROVED' THEN
        RAISE EXCEPTION 'APPLICATION_MUST_BE_APPROVED';
    END IF;
    IF v_application.converted_at IS NOT NULL OR EXISTS (
        SELECT 1 FROM app.contracts
        WHERE application_id = p_application_id
          AND status IN ('DRAFT', 'ACTIVE')
    ) THEN
        RAISE EXCEPTION 'CONTRACT_ALREADY_EXISTS_FOR_APPLICATION';
    END IF;
    PERFORM app.assert_active_user(v_application.applicant_id);
    SELECT * INTO v_applicant FROM app.users WHERE id = v_application.applicant_id;

    -- Store details come from the application; nothing has to be typed in.
    INSERT INTO app.stores (
        id, code, name, owner_id, application_id, address, phone, email, status
    ) VALUES (
        coalesce(p_store_id, gen_random_uuid()), app.fn_next_store_code(),
        v_application.proposed_store_name, v_application.applicant_id,
        v_application.id, v_application.proposed_address,
        coalesce(v_application.phone, v_applicant.phone),
        lower(coalesce(v_application.email, v_applicant.email)), 'INACTIVE'
    )
    RETURNING * INTO v_store;

    UPDATE app.franchise_applications
    SET converted_at = now(), updated_at = now()
    WHERE id = v_application.id;
    UPDATE app.users
    SET roles = array_append(roles, 'STORE_OWNER'), updated_at = now()
    WHERE id = v_application.applicant_id AND NOT ('STORE_OWNER' = ANY (roles));

    INSERT INTO app.contracts (
        id, contract_no, application_id, store_id, store_code, store_name,
        store_address, store_phone, store_email, signed_date,
        effective_from, effective_to, royalty_rate,
        initial_franchise_fee, deposit_amount, system_fee, service_fee
    )
    VALUES (
        p_contract_id, btrim(p_contract_no), v_application.id, v_store.id,
        v_store.code, v_store.name, v_store.address, v_store.phone, v_store.email,
        p_signed_date, p_effective_from, p_effective_to, p_royalty_rate,
        p_initial_franchise_fee, p_deposit_amount, p_system_fee, p_service_fee
    )
    RETURNING to_jsonb(contracts) INTO v_new_values;

    INSERT INTO app.audit_logs (actor_id, action, entity_type, entity_id, new_values)
    VALUES (p_actor_id, 'CREATE_STORE', 'STORE', v_store.id, to_jsonb(v_store));
    INSERT INTO app.audit_logs (actor_id, action, entity_type, entity_id, new_values)
    VALUES (p_actor_id, 'CREATE_CONTRACT', 'CONTRACT', p_contract_id, v_new_values);
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
    IF v_contract.store_id IS NULL THEN
        RAISE EXCEPTION 'STORE_NOT_FOUND';
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
    -- The store has been prepared since signing; it opens for business now.
    UPDATE app.stores
    SET status = 'ACTIVE', activated_at = coalesce(activated_at, now()),
        updated_at = now()
    WHERE id = v_contract.store_id AND status = 'INACTIVE';
    INSERT INTO app.audit_logs (
        actor_id, action, entity_type, entity_id, old_values, new_values
    ) VALUES (
        p_actor_id, 'ACTIVATE_CONTRACT', 'CONTRACT', p_contract_id,
        jsonb_build_object('status', 'DRAFT'),
        jsonb_build_object('status', 'ACTIVE', 'store_id', v_contract.store_id,
                           'initial_paid', v_initial_paid)
    );
END;
$$;
