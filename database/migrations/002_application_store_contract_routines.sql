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
        FROM app.user_roles ur
        JOIN app.roles r ON r.id = ur.role_id
        JOIN app.users u ON u.id = ur.user_id
        WHERE ur.user_id = p_user_id
          AND r.code = p_role_code
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

CREATE OR REPLACE PROCEDURE app.proc_submit_franchise_application(
    p_application_id uuid,
    p_applicant_id uuid,
    p_applicant_name text,
    p_email text,
    p_phone text,
    p_proposed_store_name text,
    p_proposed_address text,
    p_proposed_area numeric,
    p_investment_budget numeric,
    p_note text
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_new_values jsonb;
BEGIN
    PERFORM app.assert_active_user(p_applicant_id);
    PERFORM pg_advisory_xact_lock(hashtextextended(p_applicant_id::text, 0));

    IF EXISTS (
        SELECT 1
        FROM app.franchise_applications fa
        WHERE fa.applicant_id = p_applicant_id
          AND fa.deleted_at IS NULL
          AND (
              fa.status IN ('PENDING', 'UNDER_REVIEW')
              OR (fa.status = 'APPROVED' AND fa.converted_at IS NULL)
          )
    ) THEN
        RAISE EXCEPTION 'OPEN_APPLICATION_ALREADY_EXISTS';
    END IF;

    INSERT INTO app.franchise_applications (
        id,
        applicant_id,
        applicant_name,
        email,
        phone,
        proposed_store_name,
        proposed_address,
        proposed_area,
        investment_budget,
        note
    )
    VALUES (
        p_application_id,
        p_applicant_id,
        btrim(p_applicant_name),
        lower(btrim(p_email)),
        btrim(p_phone),
        btrim(p_proposed_store_name),
        btrim(p_proposed_address),
        p_proposed_area,
        p_investment_budget,
        nullif(btrim(p_note), '')
    )
    RETURNING to_jsonb(franchise_applications) INTO v_new_values;

    INSERT INTO app.audit_logs (
        actor_id, action, entity_type, entity_id, new_values
    )
    VALUES (
        p_applicant_id,
        'SUBMIT_APPLICATION',
        'FRANCHISE_APPLICATION',
        p_application_id,
        v_new_values
    );
END;
$$;

CREATE OR REPLACE PROCEDURE app.proc_withdraw_franchise_application(
    p_application_id uuid,
    p_actor_id uuid,
    p_reason text
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_application app.franchise_applications%ROWTYPE;
    v_new_values jsonb;
BEGIN
    PERFORM app.assert_active_user(p_actor_id);

    SELECT * INTO v_application
    FROM app.franchise_applications
    WHERE id = p_application_id
      AND deleted_at IS NULL
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'APPLICATION_NOT_FOUND';
    END IF;
    IF v_application.applicant_id <> p_actor_id THEN
        RAISE EXCEPTION 'APPLICATION_OWNERSHIP_REQUIRED';
    END IF;
    IF v_application.status NOT IN ('PENDING', 'UNDER_REVIEW') THEN
        RAISE EXCEPTION 'APPLICATION_CANNOT_BE_WITHDRAWN_FROM_STATUS:%',
            v_application.status;
    END IF;

    UPDATE app.franchise_applications
    SET status = 'WITHDRAWN',
        withdrawn_by = p_actor_id,
        withdrawn_at = now(),
        withdrawal_reason = nullif(btrim(p_reason), ''),
        updated_at = now()
    WHERE id = p_application_id
    RETURNING to_jsonb(franchise_applications) INTO v_new_values;

    INSERT INTO app.audit_logs (
        actor_id, action, entity_type, entity_id,
        old_values, new_values, reason
    )
    VALUES (
        p_actor_id, 'WITHDRAW_APPLICATION', 'FRANCHISE_APPLICATION',
        p_application_id, to_jsonb(v_application), v_new_values,
        nullif(btrim(p_reason), '')
    );
END;
$$;

CREATE OR REPLACE PROCEDURE app.proc_start_application_review(
    p_application_id uuid,
    p_actor_id uuid
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_application app.franchise_applications%ROWTYPE;
    v_new_values jsonb;
BEGIN
    PERFORM app.assert_role(p_actor_id, 'ADMIN');

    SELECT * INTO v_application
    FROM app.franchise_applications
    WHERE id = p_application_id
      AND deleted_at IS NULL
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'APPLICATION_NOT_FOUND';
    END IF;
    IF v_application.status <> 'PENDING' THEN
        RAISE EXCEPTION 'APPLICATION_MUST_BE_PENDING';
    END IF;

    UPDATE app.franchise_applications
    SET status = 'UNDER_REVIEW',
        review_started_by = p_actor_id,
        review_started_at = now(),
        updated_at = now()
    WHERE id = p_application_id
    RETURNING to_jsonb(franchise_applications) INTO v_new_values;

    INSERT INTO app.audit_logs (
        actor_id, action, entity_type, entity_id, old_values, new_values
    )
    VALUES (
        p_actor_id, 'START_APPLICATION_REVIEW', 'FRANCHISE_APPLICATION',
        p_application_id, to_jsonb(v_application), v_new_values
    );
END;
$$;

CREATE OR REPLACE PROCEDURE app.proc_approve_franchise_application(
    p_application_id uuid,
    p_actor_id uuid,
    p_review_note text
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_application app.franchise_applications%ROWTYPE;
    v_new_values jsonb;
BEGIN
    PERFORM app.assert_role(p_actor_id, 'ADMIN');

    SELECT * INTO v_application
    FROM app.franchise_applications
    WHERE id = p_application_id
      AND deleted_at IS NULL
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'APPLICATION_NOT_FOUND';
    END IF;
    IF v_application.status <> 'UNDER_REVIEW' THEN
        RAISE EXCEPTION 'APPLICATION_MUST_BE_UNDER_REVIEW';
    END IF;

    UPDATE app.franchise_applications
    SET status = 'APPROVED',
        review_note = nullif(btrim(p_review_note), ''),
        reviewed_by = p_actor_id,
        reviewed_at = now(),
        updated_at = now()
    WHERE id = p_application_id
    RETURNING to_jsonb(franchise_applications) INTO v_new_values;

    INSERT INTO app.audit_logs (
        actor_id, action, entity_type, entity_id,
        old_values, new_values, reason
    )
    VALUES (
        p_actor_id, 'APPROVE_APPLICATION', 'FRANCHISE_APPLICATION',
        p_application_id, to_jsonb(v_application), v_new_values,
        nullif(btrim(p_review_note), '')
    );
END;
$$;

CREATE OR REPLACE PROCEDURE app.proc_reject_franchise_application(
    p_application_id uuid,
    p_actor_id uuid,
    p_review_note text
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_application app.franchise_applications%ROWTYPE;
    v_new_values jsonb;
BEGIN
    PERFORM app.assert_role(p_actor_id, 'ADMIN');

    IF nullif(btrim(p_review_note), '') IS NULL THEN
        RAISE EXCEPTION 'REJECTION_REASON_REQUIRED';
    END IF;

    SELECT * INTO v_application
    FROM app.franchise_applications
    WHERE id = p_application_id
      AND deleted_at IS NULL
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'APPLICATION_NOT_FOUND';
    END IF;
    IF v_application.status <> 'UNDER_REVIEW' THEN
        RAISE EXCEPTION 'APPLICATION_MUST_BE_UNDER_REVIEW';
    END IF;

    UPDATE app.franchise_applications
    SET status = 'REJECTED',
        review_note = btrim(p_review_note),
        reviewed_by = p_actor_id,
        reviewed_at = now(),
        updated_at = now()
    WHERE id = p_application_id
    RETURNING to_jsonb(franchise_applications) INTO v_new_values;

    INSERT INTO app.audit_logs (
        actor_id, action, entity_type, entity_id,
        old_values, new_values, reason
    )
    VALUES (
        p_actor_id, 'REJECT_APPLICATION', 'FRANCHISE_APPLICATION',
        p_application_id, to_jsonb(v_application), v_new_values,
        btrim(p_review_note)
    );
END;
$$;

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

CREATE OR REPLACE FUNCTION app.fn_get_franchise_application(
    p_application_id uuid
)
RETURNS SETOF app.franchise_applications
LANGUAGE sql
STABLE
AS $$
    SELECT *
    FROM app.franchise_applications
    WHERE id = p_application_id
      AND deleted_at IS NULL;
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
