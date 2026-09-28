CREATE OR REPLACE FUNCTION app.create_notification_from_audit()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id uuid;
    v_store record;
BEGIN
    IF NEW.action IN ('APPROVE_APPLICATION', 'REJECT_APPLICATION') THEN
        SELECT applicant_id INTO v_user_id
        FROM app.franchise_applications WHERE id = NEW.entity_id;
        INSERT INTO app.notifications (
            id, user_id, notification_type, title, message,
            entity_type, entity_id, dedupe_key
        ) VALUES (
            gen_random_uuid(), v_user_id,
            CASE WHEN NEW.action = 'APPROVE_APPLICATION'
                THEN 'APPLICATION_APPROVED' ELSE 'APPLICATION_REJECTED' END,
            CASE WHEN NEW.action = 'APPROVE_APPLICATION'
                THEN 'Application approved' ELSE 'Application rejected' END,
            coalesce(NEW.reason, NEW.action),
            'FRANCHISE_APPLICATION', NEW.entity_id,
            NEW.action || ':' || NEW.entity_id
        ) ON CONFLICT (dedupe_key) DO NOTHING;
    ELSIF NEW.action = 'ACTIVATE_PROMOTION' THEN
        FOR v_store IN
            SELECT DISTINCT s.owner_id
            FROM app.stores s
            JOIN app.promotions p ON p.id = NEW.entity_id
            WHERE s.status = 'ACTIVE' AND s.deleted_at IS NULL
              AND (
                  p.scope = 'ALL_STORES'
                  OR EXISTS (
                      SELECT 1 FROM app.promotion_stores ps
                      WHERE ps.promotion_id = p.id AND ps.store_id = s.id
                  )
              )
        LOOP
            INSERT INTO app.notifications (
                id, user_id, notification_type, title, message,
                entity_type, entity_id, dedupe_key
            ) VALUES (
                gen_random_uuid(), v_store.owner_id, 'PROMOTION_STARTED',
                'Promotion started', 'A promotion is available for your store',
                'PROMOTION', NEW.entity_id,
                'PROMOTION_STARTED:' || NEW.entity_id || ':' || v_store.owner_id
            ) ON CONFLICT (dedupe_key) DO NOTHING;
        END LOOP;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_audit_business_notifications
AFTER INSERT ON app.audit_logs
FOR EACH ROW
EXECUTE FUNCTION app.create_notification_from_audit();
