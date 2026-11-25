-- Stored procedures/functions for 050_revenues.sql.

CREATE OR REPLACE PROCEDURE app.proc_save_revenue(
    p_revenue_id uuid,
    p_store_id uuid,
    p_actor_id uuid,
    p_business_date date,
    p_gross_revenue numeric,
    p_note text,
    p_promotion_details jsonb
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_store app.stores%ROWTYPE;
    v_revenue app.revenues%ROWTYPE;
    v_detail jsonb;
    v_promotion app.promotions%ROWTYPE;
    v_discount numeric;
    v_total_discount numeric := 0;
    v_brand_support numeric;
    v_store_cost numeric;
    v_is_existing boolean := false;
BEGIN
    PERFORM app.assert_role(p_actor_id, 'STORE_OWNER');
    SELECT * INTO v_store FROM app.stores
    WHERE id = p_store_id AND deleted_at IS NULL FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'STORE_NOT_FOUND'; END IF;
    IF v_store.owner_id <> p_actor_id THEN
        RAISE EXCEPTION 'STORE_OWNERSHIP_REQUIRED';
    END IF;
    IF v_store.status <> 'ACTIVE' THEN RAISE EXCEPTION 'STORE_NOT_ACTIVE'; END IF;
    IF p_business_date < v_store.activated_at::date
       OR p_business_date > current_date THEN
        RAISE EXCEPTION 'REVENUE_BUSINESS_DATE_INVALID';
    END IF;
    IF p_gross_revenue < 0 THEN RAISE EXCEPTION 'REVENUE_AMOUNT_INVALID'; END IF;

    SELECT * INTO v_revenue FROM app.revenues
    WHERE store_id = p_store_id AND business_date = p_business_date
    FOR UPDATE;
    v_is_existing := FOUND;
    IF FOUND AND v_revenue.id <> p_revenue_id THEN
        RAISE EXCEPTION 'REVENUE_ALREADY_EXISTS_FOR_DATE';
    END IF;
    IF FOUND AND v_revenue.status NOT IN (
        'DRAFT', 'REJECTED', 'ADJUSTMENT_REQUESTED'
    ) THEN RAISE EXCEPTION 'REVENUE_CANNOT_BE_EDITED'; END IF;

    FOR v_detail IN SELECT * FROM jsonb_array_elements(
        coalesce(p_promotion_details, '[]'::jsonb)
    ) LOOP
        v_discount := (v_detail->>'discount_amount')::numeric;
        IF v_discount < 0 THEN RAISE EXCEPTION 'PROMOTION_DISCOUNT_INVALID'; END IF;
        SELECT * INTO v_promotion FROM app.promotions
        WHERE id = (v_detail->>'promotion_id')::uuid
          AND status = 'ACTIVE' AND deleted_at IS NULL
          AND p_business_date BETWEEN start_date AND end_date
          AND (
              scope = 'ALL_STORES'
              OR EXISTS (
                  SELECT 1 FROM app.promotion_stores ps
                  WHERE ps.promotion_id = promotions.id
                    AND ps.store_id = p_store_id
              )
          );
        IF NOT FOUND THEN RAISE EXCEPTION 'PROMOTION_NOT_APPLICABLE'; END IF;
        v_total_discount := v_total_discount + v_discount;
    END LOOP;
    IF v_total_discount > p_gross_revenue THEN
        RAISE EXCEPTION 'PROMOTION_DISCOUNT_EXCEEDS_GROSS';
    END IF;

    IF NOT v_is_existing THEN
        INSERT INTO app.revenues (
            id, store_id, business_date, gross_revenue,
            promotion_discount, reported_by, note
        ) VALUES (
            p_revenue_id, p_store_id, p_business_date, p_gross_revenue,
            v_total_discount, p_actor_id, nullif(btrim(p_note), '')
        );
    ELSE
        INSERT INTO app.revenue_versions (
            revenue_id, version, snapshot, change_reason, changed_by
        ) VALUES (
            v_revenue.id, v_revenue.version, to_jsonb(v_revenue),
            coalesce(v_revenue.adjustment_reason, 'OWNER_EDIT'), p_actor_id
        ) ON CONFLICT DO NOTHING;
        UPDATE app.revenues
        SET gross_revenue = p_gross_revenue,
            promotion_discount = v_total_discount,
            status = 'DRAFT', version = version + 1,
            note = nullif(btrim(p_note), ''), updated_at = now(),
            reviewed_by = NULL, reviewed_at = NULL, review_note = NULL
        WHERE id = p_revenue_id;
        DELETE FROM app.revenue_promotion_details
        WHERE revenue_id = p_revenue_id;
    END IF;

    FOR v_detail IN SELECT * FROM jsonb_array_elements(
        coalesce(p_promotion_details, '[]'::jsonb)
    ) LOOP
        v_discount := (v_detail->>'discount_amount')::numeric;
        SELECT * INTO v_promotion FROM app.promotions
        WHERE id = (v_detail->>'promotion_id')::uuid;
        v_brand_support := round(
            v_discount * v_promotion.brand_share_percent / 100
        );
        v_store_cost := v_discount - v_brand_support;
        INSERT INTO app.revenue_promotion_details (
            id, revenue_id, promotion_id, discount_amount,
            brand_share_percent, store_share_percent,
            brand_support_amount, store_cost_amount,
            promotion_name_snapshot
        ) VALUES (
            gen_random_uuid(), p_revenue_id, v_promotion.id, v_discount,
            v_promotion.brand_share_percent, v_promotion.store_share_percent,
            v_brand_support, v_store_cost, v_promotion.name
        );
    END LOOP;
END;
$$;

CREATE OR REPLACE PROCEDURE app.proc_submit_revenue(
    p_revenue_id uuid, p_actor_id uuid
)
LANGUAGE plpgsql
AS $$
DECLARE v_revenue app.revenues%ROWTYPE; v_owner uuid;
BEGIN
    PERFORM app.assert_role(p_actor_id, 'STORE_OWNER');
    SELECT r.* INTO v_revenue
    FROM app.revenues r
    WHERE r.id = p_revenue_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'REVENUE_NOT_FOUND'; END IF;
    SELECT owner_id INTO v_owner FROM app.stores
    WHERE id = v_revenue.store_id;
    IF v_owner <> p_actor_id THEN RAISE EXCEPTION 'STORE_OWNERSHIP_REQUIRED'; END IF;
    IF v_revenue.status NOT IN ('DRAFT', 'REJECTED') THEN
        RAISE EXCEPTION 'REVENUE_CANNOT_BE_SUBMITTED';
    END IF;
    UPDATE app.revenues SET status = 'SUBMITTED', reported_at = now(),
        updated_at = now() WHERE id = p_revenue_id;
    INSERT INTO app.audit_logs (actor_id, action, entity_type, entity_id)
    VALUES (p_actor_id, 'SUBMIT_REVENUE', 'REVENUE', p_revenue_id);
END;
$$;

CREATE OR REPLACE PROCEDURE app.proc_review_revenue(
    p_revenue_id uuid,
    p_actor_id uuid,
    p_decision text,
    p_note text
)
LANGUAGE plpgsql
AS $$
DECLARE v_revenue app.revenues%ROWTYPE;
BEGIN
    PERFORM app.assert_role(p_actor_id, 'ACCOUNTANT');
    SELECT * INTO v_revenue FROM app.revenues
    WHERE id = p_revenue_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'REVENUE_NOT_FOUND'; END IF;
    IF v_revenue.status <> 'SUBMITTED' THEN
        RAISE EXCEPTION 'REVENUE_MUST_BE_SUBMITTED';
    END IF;
    IF v_revenue.reported_by = p_actor_id THEN
        RAISE EXCEPTION 'REVENUE_SELF_APPROVAL_FORBIDDEN';
    END IF;
    IF upper(p_decision) NOT IN ('APPROVED', 'REJECTED') THEN
        RAISE EXCEPTION 'REVENUE_DECISION_INVALID';
    END IF;
    IF upper(p_decision) = 'REJECTED'
       AND nullif(btrim(p_note), '') IS NULL THEN
        RAISE EXCEPTION 'REJECTION_REASON_REQUIRED';
    END IF;
    UPDATE app.revenues SET status = upper(p_decision),
        reviewed_by = p_actor_id, reviewed_at = now(),
        review_note = nullif(btrim(p_note), ''), updated_at = now()
    WHERE id = p_revenue_id;
    INSERT INTO app.audit_logs (
        actor_id, action, entity_type, entity_id,
        old_values, new_values, reason
    ) VALUES (
        p_actor_id,
        CASE WHEN upper(p_decision) = 'APPROVED'
            THEN 'APPROVE_REVENUE' ELSE 'REJECT_REVENUE' END,
        'REVENUE', p_revenue_id,
        jsonb_build_object('status', v_revenue.status),
        jsonb_build_object('status', upper(p_decision)),
        nullif(btrim(p_note), '')
    );
    IF upper(p_decision) = 'REJECTED' THEN
        INSERT INTO app.notifications (
            id, user_id, notification_type, title, message,
            entity_type, entity_id, dedupe_key
        ) VALUES (
            gen_random_uuid(), v_revenue.reported_by, 'REVENUE_REJECTED',
            'Revenue rejected', coalesce(p_note, 'Revenue requires correction'),
            'REVENUE', p_revenue_id,
            'REVENUE_REJECTED:' || p_revenue_id || ':' || v_revenue.version
        ) ON CONFLICT (dedupe_key) DO NOTHING;
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE app.proc_request_revenue_adjustment(
    p_revenue_id uuid, p_actor_id uuid, p_reason text
)
LANGUAGE plpgsql
AS $$
DECLARE v_revenue app.revenues%ROWTYPE;
BEGIN
    PERFORM app.assert_role(p_actor_id, 'ACCOUNTANT');
    IF nullif(btrim(p_reason), '') IS NULL THEN
        RAISE EXCEPTION 'ADJUSTMENT_REASON_REQUIRED';
    END IF;
    SELECT * INTO v_revenue FROM app.revenues
    WHERE id = p_revenue_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'REVENUE_NOT_FOUND'; END IF;
    IF v_revenue.status <> 'APPROVED' THEN
        RAISE EXCEPTION 'REVENUE_MUST_BE_APPROVED';
    END IF;
    INSERT INTO app.revenue_versions (
        revenue_id, version, snapshot, change_reason, changed_by
    ) VALUES (
        p_revenue_id, v_revenue.version, to_jsonb(v_revenue),
        btrim(p_reason), p_actor_id
    ) ON CONFLICT DO NOTHING;
    UPDATE app.revenues SET status = 'ADJUSTMENT_REQUESTED',
        adjustment_requested_by = p_actor_id,
        adjustment_requested_at = now(), adjustment_reason = btrim(p_reason),
        updated_at = now() WHERE id = p_revenue_id;
    INSERT INTO app.audit_logs (
        actor_id, action, entity_type, entity_id, reason
    ) VALUES (
        p_actor_id, 'REQUEST_REVENUE_ADJUSTMENT', 'REVENUE',
        p_revenue_id, btrim(p_reason)
    );
    INSERT INTO app.notifications (
        id, user_id, notification_type, title, message,
        entity_type, entity_id, dedupe_key
    ) VALUES (
        gen_random_uuid(), v_revenue.reported_by,
        'REVENUE_ADJUSTMENT_REQUESTED', 'Revenue adjustment requested',
        btrim(p_reason), 'REVENUE', p_revenue_id,
        'REVENUE_ADJUST:' || p_revenue_id || ':' || v_revenue.version
    ) ON CONFLICT (dedupe_key) DO NOTHING;
END;
$$;

CREATE OR REPLACE FUNCTION app.fn_get_revenue(p_revenue_id uuid)
RETURNS TABLE (data jsonb)
LANGUAGE sql STABLE AS $$
    SELECT to_jsonb(r) || jsonb_build_object(
        'promotion_details', coalesce((
            SELECT jsonb_agg(to_jsonb(d) ORDER BY d.created_at)
            FROM app.revenue_promotion_details d WHERE d.revenue_id = r.id
        ), '[]'::jsonb)
    ) FROM app.revenues r WHERE r.id = p_revenue_id;
$$;
