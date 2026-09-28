CREATE OR REPLACE FUNCTION app.user_can_access_store(
    p_user_id uuid, p_store_id uuid
)
RETURNS boolean
LANGUAGE sql STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 FROM app.stores s
        WHERE s.id = p_store_id AND s.deleted_at IS NULL
          AND (
              s.owner_id = p_user_id
              OR app.user_has_role(p_user_id, 'ADMIN')
              OR app.user_has_role(p_user_id, 'ACCOUNTANT')
          )
    );
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
