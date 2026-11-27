-- Stored procedures/functions for 040_promotions.sql.
-- Promotions are fully funded by the brand.

CREATE OR REPLACE PROCEDURE app.proc_create_promotion(
    p_promotion_id uuid,
    p_actor_id uuid,
    p_name text,
    p_description text,
    p_discount_type text,
    p_discount_value numeric,
    p_start_date date,
    p_end_date date,
    p_scope text,
    p_store_ids uuid[]
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_store_id uuid;
BEGIN
    PERFORM app.assert_role(p_actor_id, 'ADMIN');
    IF nullif(btrim(p_name), '') IS NULL THEN
        RAISE EXCEPTION 'PROMOTION_NAME_REQUIRED';
    END IF;
    INSERT INTO app.promotions (
        id, name, description, discount_type, discount_value,
        start_date, end_date, scope, created_by
    ) VALUES (
        p_promotion_id, btrim(p_name), nullif(btrim(p_description), ''),
        upper(p_discount_type), p_discount_value, p_start_date, p_end_date,
        upper(p_scope), p_actor_id
    );
    IF upper(p_scope) = 'SELECTED_STORES' THEN
        IF coalesce(array_length(p_store_ids, 1), 0) = 0 THEN
            RAISE EXCEPTION 'PROMOTION_STORES_REQUIRED';
        END IF;
        FOREACH v_store_id IN ARRAY p_store_ids LOOP
            IF NOT EXISTS (
                SELECT 1 FROM app.stores
                WHERE id = v_store_id AND deleted_at IS NULL
            ) THEN RAISE EXCEPTION 'STORE_NOT_FOUND:%', v_store_id; END IF;
            INSERT INTO app.promotion_stores (promotion_id, store_id)
            VALUES (p_promotion_id, v_store_id);
        END LOOP;
    END IF;
    INSERT INTO app.audit_logs (
        actor_id, action, entity_type, entity_id, new_values
    ) SELECT p_actor_id, 'CREATE_PROMOTION', 'PROMOTION', p_promotion_id,
        to_jsonb(p) FROM app.promotions p WHERE p.id = p_promotion_id;
END;
$$;

CREATE OR REPLACE PROCEDURE app.proc_change_promotion_status(
    p_promotion_id uuid,
    p_actor_id uuid,
    p_new_status text,
    p_reason text
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_promotion app.promotions%ROWTYPE;
BEGIN
    PERFORM app.assert_role(p_actor_id, 'ADMIN');
    SELECT * INTO v_promotion FROM app.promotions
    WHERE id = p_promotion_id AND deleted_at IS NULL FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'PROMOTION_NOT_FOUND'; END IF;
    IF upper(p_new_status) = 'ACTIVE' AND v_promotion.status <> 'DRAFT' THEN
        RAISE EXCEPTION 'PROMOTION_MUST_BE_DRAFT';
    ELSIF upper(p_new_status) = 'CANCELLED'
          AND v_promotion.status NOT IN ('DRAFT', 'ACTIVE') THEN
        RAISE EXCEPTION 'PROMOTION_CANNOT_BE_CANCELLED';
    ELSIF upper(p_new_status) NOT IN ('ACTIVE', 'CANCELLED') THEN
        RAISE EXCEPTION 'PROMOTION_STATUS_INVALID';
    END IF;
    UPDATE app.promotions SET status = upper(p_new_status), updated_at = now()
    WHERE id = p_promotion_id;
    INSERT INTO app.audit_logs (
        actor_id, action, entity_type, entity_id,
        old_values, new_values, reason
    ) VALUES (
        p_actor_id,
        CASE WHEN upper(p_new_status) = 'ACTIVE'
            THEN 'ACTIVATE_PROMOTION' ELSE 'CANCEL_PROMOTION' END,
        'PROMOTION', p_promotion_id,
        jsonb_build_object('status', v_promotion.status),
        jsonb_build_object('status', upper(p_new_status)),
        nullif(btrim(p_reason), '')
    );
END;
$$;

CREATE OR REPLACE PROCEDURE app.proc_soft_delete_promotion(
    p_promotion_id uuid, p_actor_id uuid, p_reason text
)
LANGUAGE plpgsql
AS $$
DECLARE v_status text;
BEGIN
    PERFORM app.assert_role(p_actor_id, 'ADMIN');
    IF nullif(btrim(p_reason), '') IS NULL THEN
        RAISE EXCEPTION 'DELETE_REASON_REQUIRED';
    END IF;
    SELECT status INTO v_status FROM app.promotions
    WHERE id = p_promotion_id AND deleted_at IS NULL FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'PROMOTION_NOT_FOUND'; END IF;
    IF v_status = 'ACTIVE' THEN RAISE EXCEPTION 'ACTIVE_PROMOTION_CANNOT_BE_DELETED'; END IF;
    UPDATE app.promotions SET deleted_at = now(), updated_at = now()
    WHERE id = p_promotion_id;
    INSERT INTO app.audit_logs (
        actor_id, action, entity_type, entity_id, reason
    ) VALUES (
        p_actor_id, 'SOFT_DELETE_PROMOTION', 'PROMOTION',
        p_promotion_id, btrim(p_reason)
    );
END;
$$;
