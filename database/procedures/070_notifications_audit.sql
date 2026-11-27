-- Stored procedures/functions for 070_notifications_audit.sql.

CREATE OR REPLACE FUNCTION app.prevent_audit_log_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'AUDIT_LOG_IMMUTABLE';
END;
$$;

CREATE OR REPLACE PROCEDURE app.proc_generate_operational_alerts(
    p_as_of timestamptz
)
LANGUAGE plpgsql
AS $$
DECLARE v_store record; v_date date; v_invoice record;
BEGIN
    v_date := (p_as_of::date - 1);
    IF p_as_of::time >= time '23:00' THEN
        FOR v_store IN SELECT id, owner_id, name FROM app.stores
            WHERE status = 'ACTIVE' AND deleted_at IS NULL
        LOOP
            IF NOT EXISTS (
                SELECT 1 FROM app.revenues
                WHERE store_id = v_store.id AND business_date = v_date
                  AND status IN ('SUBMITTED', 'APPROVED')
            ) THEN
                INSERT INTO app.notifications (
                    id, user_id, notification_type, title, message,
                    entity_type, entity_id, dedupe_key
                ) VALUES (
                    gen_random_uuid(), v_store.owner_id, 'REVENUE_OVERDUE',
                    'Chậm báo cáo doanh thu',
                    'Cửa hàng ' || v_store.name || ' chưa nộp doanh thu ngày ' || to_char(v_date, 'DD/MM/YYYY'),
                    'STORE', v_store.id,
                    'REVENUE_OVERDUE:' || v_store.id || ':' || v_date
                ) ON CONFLICT (dedupe_key) DO NOTHING;
            END IF;
        END LOOP;
    END IF;
    FOR v_invoice IN
        SELECT i.id, i.invoice_no, s.owner_id
        FROM app.invoices i JOIN app.stores s ON s.id = i.store_id
        WHERE i.status IN ('ISSUED', 'PARTIALLY_PAID')
          AND i.outstanding_amount > 0 AND i.due_date < p_as_of::date
        FOR UPDATE OF i
    LOOP
        UPDATE app.invoices SET status = 'OVERDUE', updated_at = now()
        WHERE id = v_invoice.id;
        INSERT INTO app.notifications (
            id, user_id, notification_type, title, message,
            entity_type, entity_id, dedupe_key
        ) VALUES (
            gen_random_uuid(), v_invoice.owner_id, 'INVOICE_OVERDUE',
            'Hóa đơn quá hạn', 'Hóa đơn ' || v_invoice.invoice_no || ' đã quá hạn thanh toán',
            'INVOICE', v_invoice.id, 'INVOICE_OVERDUE:' || v_invoice.id
        ) ON CONFLICT (dedupe_key) DO NOTHING;
    END LOOP;
END;
$$;

CREATE OR REPLACE PROCEDURE app.proc_mark_notification_read(
    p_notification_id uuid, p_user_id uuid
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE app.notifications SET read_at = coalesce(read_at, now())
    WHERE id = p_notification_id AND user_id = p_user_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'NOTIFICATION_NOT_FOUND'; END IF;
END;
$$;

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
                THEN 'Hồ sơ được duyệt' ELSE 'Hồ sơ bị từ chối' END,
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
                'Khuyến mãi bắt đầu', 'Cửa hàng của bạn có chương trình khuyến mãi mới',
                'PROMOTION', NEW.entity_id,
                'PROMOTION_STARTED:' || NEW.entity_id || ':' || v_store.owner_id
            ) ON CONFLICT (dedupe_key) DO NOTHING;
        END LOOP;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_logs_immutable ON app.audit_logs;
CREATE TRIGGER trg_audit_logs_immutable
BEFORE UPDATE OR DELETE ON app.audit_logs
FOR EACH ROW
EXECUTE FUNCTION app.prevent_audit_log_mutation();

DROP TRIGGER IF EXISTS trg_audit_business_notifications ON app.audit_logs;
CREATE TRIGGER trg_audit_business_notifications
AFTER INSERT ON app.audit_logs
FOR EACH ROW
EXECUTE FUNCTION app.create_notification_from_audit();
