-- Stored procedures/functions for 020_applications.sql.

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
