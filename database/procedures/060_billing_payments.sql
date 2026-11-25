-- Stored procedures/functions for 060_billing_payments.sql.

CREATE OR REPLACE PROCEDURE app.proc_create_billing_adjustment(
    p_adjustment_id uuid, p_store_id uuid, p_actor_id uuid,
    p_source_period date, p_amount numeric, p_reason text
)
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM app.assert_role(p_actor_id, 'ACCOUNTANT');
    IF p_amount = 0 OR nullif(btrim(p_reason), '') IS NULL THEN
        RAISE EXCEPTION 'BILLING_ADJUSTMENT_INVALID';
    END IF;
    INSERT INTO app.billing_adjustments (
        id, store_id, source_period, amount, reason, created_by
    ) VALUES (
        p_adjustment_id, p_store_id, p_source_period, p_amount,
        btrim(p_reason), p_actor_id
    );
END;
$$;

CREATE OR REPLACE PROCEDURE app.proc_generate_monthly_invoice(
    p_invoice_id uuid,
    p_invoice_no text,
    p_store_id uuid,
    p_period_month date,
    p_vat_rate numeric,
    p_actor_id uuid
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_period date := date_trunc('month', p_period_month)::date;
    v_period_end date := (date_trunc('month', p_period_month)
        + interval '1 month - 1 day')::date;
    v_contract app.contracts%ROWTYPE;
    v_monthly_close_id uuid := gen_random_uuid();
    v_gross numeric; v_discount numeric; v_net numeric; v_brand numeric;
    v_royalty numeric; v_positive numeric; v_negative numeric;
    v_credit numeric; v_fee_subtotal numeric; v_deductions numeric;
    v_raw numeric; v_taxable numeric; v_vat numeric; v_total numeric;
    v_new_credit numeric;
BEGIN
    PERFORM app.assert_role(p_actor_id, 'ACCOUNTANT');
    IF p_vat_rate < 0 OR p_vat_rate > 100 THEN
        RAISE EXCEPTION 'VAT_RATE_INVALID';
    END IF;
    IF EXISTS (
        SELECT 1 FROM app.invoices
        WHERE store_id = p_store_id AND period_month = v_period
          AND status <> 'CANCELLED'
    ) THEN RAISE EXCEPTION 'INVOICE_ALREADY_EXISTS_FOR_PERIOD'; END IF;
    SELECT * INTO v_contract FROM app.contracts
    WHERE store_id = p_store_id AND status = 'ACTIVE'
      AND effective_from <= v_period_end AND effective_to >= v_period
    ORDER BY effective_from DESC LIMIT 1;
    IF NOT FOUND THEN RAISE EXCEPTION 'ACTIVE_CONTRACT_NOT_FOUND'; END IF;

    SELECT coalesce(sum(r.gross_revenue), 0),
           coalesce(sum(r.promotion_discount), 0),
           coalesce(sum(r.net_revenue), 0)
    INTO v_gross, v_discount, v_net
    FROM app.revenues r
    WHERE r.store_id = p_store_id AND r.status = 'APPROVED'
      AND r.business_date BETWEEN v_period AND v_period_end;
    SELECT coalesce(sum(d.brand_support_amount), 0) INTO v_brand
    FROM app.revenue_promotion_details d
    JOIN app.revenues r ON r.id = d.revenue_id
    WHERE r.store_id = p_store_id AND r.status = 'APPROVED'
      AND r.business_date BETWEEN v_period AND v_period_end;
    SELECT coalesce(sum(CASE WHEN amount > 0 THEN amount ELSE 0 END), 0),
           abs(coalesce(sum(CASE WHEN amount < 0 THEN amount ELSE 0 END), 0))
    INTO v_positive, v_negative
    FROM app.billing_adjustments
    WHERE store_id = p_store_id AND status = 'PENDING';
    SELECT coalesce(sum(remaining_amount), 0) INTO v_credit
    FROM app.store_credits WHERE store_id = p_store_id;

    v_royalty := round(v_gross * v_contract.royalty_rate / 100);
    v_fee_subtotal := v_royalty + v_contract.system_fee
        + v_contract.service_fee + v_positive;
    v_deductions := v_brand + v_credit + v_negative;
    v_raw := v_fee_subtotal - v_deductions;
    v_taxable := greatest(v_raw, 0);
    v_new_credit := greatest(-v_raw, 0);
    v_vat := round(v_taxable * p_vat_rate / 100);
    v_total := v_taxable + v_vat;

    INSERT INTO app.monthly_closes (
        id, store_id, period_month, monthly_gross_revenue,
        monthly_promotion_discount, monthly_net_revenue,
        brand_promotion_support, closed_by
    ) VALUES (
        v_monthly_close_id, p_store_id, v_period, v_gross,
        v_discount, v_net, v_brand, p_actor_id
    ) ON CONFLICT (store_id, period_month) DO UPDATE SET
        monthly_gross_revenue = excluded.monthly_gross_revenue,
        monthly_promotion_discount = excluded.monthly_promotion_discount,
        monthly_net_revenue = excluded.monthly_net_revenue,
        brand_promotion_support = excluded.brand_promotion_support,
        closed_by = excluded.closed_by, closed_at = now()
    RETURNING id INTO v_monthly_close_id;

    INSERT INTO app.invoices (
        id, invoice_no, store_id, contract_id, monthly_close_id,
        period_month, royalty_rate, monthly_gross_revenue, royalty_fee,
        system_fee, service_fee, positive_adjustments,
        brand_promotion_support, carried_credit, negative_adjustments,
        fee_subtotal, deductions, taxable_amount, vat_rate, vat_amount,
        invoice_total, outstanding_amount, created_by
    ) VALUES (
        p_invoice_id, btrim(p_invoice_no), p_store_id, v_contract.id,
        v_monthly_close_id, v_period, v_contract.royalty_rate, v_gross,
        v_royalty, v_contract.system_fee, v_contract.service_fee,
        v_positive, v_brand, v_credit, v_negative, v_fee_subtotal,
        v_deductions, v_taxable, p_vat_rate, v_vat, v_total, v_total,
        p_actor_id
    );
    INSERT INTO app.invoice_items (id, invoice_id, item_type, description, amount)
    VALUES
        (gen_random_uuid(), p_invoice_id, 'ROYALTY', 'Royalty fee', v_royalty),
        (gen_random_uuid(), p_invoice_id, 'SYSTEM_FEE', 'System fee', v_contract.system_fee),
        (gen_random_uuid(), p_invoice_id, 'SERVICE_FEE', 'Service fee', v_contract.service_fee),
        (gen_random_uuid(), p_invoice_id, 'PROMOTION_SUPPORT', 'Brand promotion support', -v_brand),
        (gen_random_uuid(), p_invoice_id, 'CARRIED_CREDIT', 'Carried credit', -v_credit),
        (gen_random_uuid(), p_invoice_id, 'BILLING_ADJUSTMENT', 'Net billing adjustments', v_positive - v_negative);
    UPDATE app.billing_adjustments SET status = 'APPLIED',
        applied_invoice_id = p_invoice_id, applied_at = now()
    WHERE store_id = p_store_id AND status = 'PENDING';
    UPDATE app.store_credits SET remaining_amount = 0
    WHERE store_id = p_store_id AND remaining_amount > 0;
    IF v_new_credit > 0 THEN
        INSERT INTO app.store_credits (
            id, store_id, source_invoice_id, amount, remaining_amount
        ) VALUES (
            gen_random_uuid(), p_store_id, p_invoice_id,
            v_new_credit, v_new_credit
        );
    END IF;
    INSERT INTO app.audit_logs (
        actor_id, action, entity_type, entity_id, new_values
    ) VALUES (
        p_actor_id, 'GENERATE_INVOICE', 'INVOICE', p_invoice_id,
        jsonb_build_object('total', v_total, 'vat', v_vat, 'period', v_period)
    );
END;
$$;

CREATE OR REPLACE PROCEDURE app.proc_issue_invoice(
    p_invoice_id uuid, p_actor_id uuid
)
LANGUAGE plpgsql
AS $$
DECLARE v_invoice app.invoices%ROWTYPE; v_owner_id uuid;
BEGIN
    PERFORM app.assert_role(p_actor_id, 'ACCOUNTANT');
    SELECT * INTO v_invoice FROM app.invoices
    WHERE id = p_invoice_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'INVOICE_NOT_FOUND'; END IF;
    SELECT owner_id INTO v_owner_id FROM app.stores
    WHERE id = v_invoice.store_id;
    IF v_invoice.status <> 'DRAFT' THEN RAISE EXCEPTION 'INVOICE_MUST_BE_DRAFT'; END IF;
    UPDATE app.invoices SET status = CASE WHEN invoice_total = 0
            THEN 'PAID' ELSE 'ISSUED' END,
        issued_at = now(), due_date = current_date + 7, updated_at = now()
    WHERE id = p_invoice_id;
    INSERT INTO app.notifications (
        id, user_id, notification_type, title, message,
        entity_type, entity_id, dedupe_key
    ) VALUES (
        gen_random_uuid(), v_owner_id, 'INVOICE_ISSUED', 'Invoice issued',
        'Invoice ' || v_invoice.invoice_no || ' has been issued',
        'INVOICE', p_invoice_id, 'INVOICE_ISSUED:' || p_invoice_id
    ) ON CONFLICT (dedupe_key) DO NOTHING;
    INSERT INTO app.audit_logs (actor_id, action, entity_type, entity_id)
    VALUES (p_actor_id, 'ISSUE_INVOICE', 'INVOICE', p_invoice_id);
END;
$$;

CREATE OR REPLACE PROCEDURE app.proc_cancel_invoice(
    p_invoice_id uuid, p_actor_id uuid, p_reason text
)
LANGUAGE plpgsql
AS $$
DECLARE v_invoice app.invoices%ROWTYPE;
BEGIN
    PERFORM app.assert_role(p_actor_id, 'ACCOUNTANT');
    IF nullif(btrim(p_reason), '') IS NULL THEN RAISE EXCEPTION 'CANCEL_REASON_REQUIRED'; END IF;
    SELECT * INTO v_invoice FROM app.invoices
    WHERE id = p_invoice_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'INVOICE_NOT_FOUND'; END IF;
    IF v_invoice.status NOT IN ('DRAFT', 'ISSUED') OR EXISTS (
        SELECT 1 FROM app.payments
        WHERE invoice_id = p_invoice_id AND status = 'CONFIRMED'
    ) THEN RAISE EXCEPTION 'INVOICE_CANNOT_BE_CANCELLED'; END IF;
    UPDATE app.invoices SET status = 'CANCELLED', cancelled_at = now(),
        cancel_reason = btrim(p_reason), updated_at = now()
    WHERE id = p_invoice_id;
    INSERT INTO app.audit_logs (
        actor_id, action, entity_type, entity_id, reason
    ) VALUES (p_actor_id, 'CANCEL_INVOICE', 'INVOICE', p_invoice_id, btrim(p_reason));
END;
$$;

CREATE OR REPLACE PROCEDURE app.proc_record_payment(
    p_payment_id uuid, p_payment_no text, p_invoice_id uuid,
    p_amount numeric, p_payment_date date, p_method text,
    p_reference_no text, p_actor_id uuid
)
LANGUAGE plpgsql
AS $$
DECLARE v_invoice app.invoices%ROWTYPE; v_new_paid numeric; v_owner_id uuid;
BEGIN
    PERFORM app.assert_role(p_actor_id, 'ACCOUNTANT');
    SELECT * INTO v_invoice FROM app.invoices
    WHERE id = p_invoice_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'INVOICE_NOT_FOUND'; END IF;
    SELECT owner_id INTO v_owner_id FROM app.stores
    WHERE id = v_invoice.store_id;
    IF v_invoice.status NOT IN ('ISSUED', 'PARTIALLY_PAID', 'OVERDUE') THEN
        RAISE EXCEPTION 'INVOICE_NOT_PAYABLE';
    END IF;
    IF p_amount <= 0 OR p_amount > v_invoice.outstanding_amount THEN
        RAISE EXCEPTION 'PAYMENT_AMOUNT_INVALID_OR_EXCEEDS_OUTSTANDING';
    END IF;
    INSERT INTO app.payments (
        id, payment_no, invoice_id, amount, payment_date, method,
        reference_no, recorded_by
    ) VALUES (
        p_payment_id, btrim(p_payment_no), p_invoice_id, p_amount,
        p_payment_date, upper(p_method), nullif(btrim(p_reference_no), ''),
        p_actor_id
    );
    v_new_paid := v_invoice.paid_amount + p_amount;
    UPDATE app.invoices SET paid_amount = v_new_paid,
        outstanding_amount = invoice_total - v_new_paid,
        status = CASE WHEN v_new_paid = invoice_total
            THEN 'PAID' WHEN current_date > due_date
            THEN 'OVERDUE' ELSE 'PARTIALLY_PAID' END,
        updated_at = now() WHERE id = p_invoice_id;
    INSERT INTO app.notifications (
        id, user_id, notification_type, title, message,
        entity_type, entity_id, dedupe_key
    ) VALUES (
        gen_random_uuid(), v_owner_id, 'PAYMENT_CONFIRMED',
        'Payment confirmed', 'Payment ' || p_payment_no || ' confirmed',
        'PAYMENT', p_payment_id, 'PAYMENT_CONFIRMED:' || p_payment_id
    );
    INSERT INTO app.audit_logs (
        actor_id, action, entity_type, entity_id, new_values
    ) VALUES (
        p_actor_id, 'RECORD_PAYMENT', 'PAYMENT', p_payment_id,
        jsonb_build_object('invoice_id', p_invoice_id, 'amount', p_amount)
    );
END;
$$;

CREATE OR REPLACE PROCEDURE app.proc_reverse_payment(
    p_payment_id uuid, p_actor_id uuid, p_reason text
)
LANGUAGE plpgsql
AS $$
DECLARE v_payment app.payments%ROWTYPE; v_invoice app.invoices%ROWTYPE;
    v_paid numeric; v_owner_id uuid;
BEGIN
    PERFORM app.assert_role(p_actor_id, 'ACCOUNTANT');
    IF nullif(btrim(p_reason), '') IS NULL THEN RAISE EXCEPTION 'REVERSAL_REASON_REQUIRED'; END IF;
    SELECT * INTO v_payment FROM app.payments
    WHERE id = p_payment_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'PAYMENT_NOT_FOUND'; END IF;
    IF v_payment.status <> 'CONFIRMED' THEN RAISE EXCEPTION 'PAYMENT_ALREADY_REVERSED'; END IF;
    SELECT * INTO v_invoice FROM app.invoices
    WHERE id = v_payment.invoice_id FOR UPDATE;
    UPDATE app.payments SET status = 'REVERSED', reversed_by = p_actor_id,
        reversed_at = now(), reversal_reason = btrim(p_reason)
    WHERE id = p_payment_id;
    SELECT coalesce(sum(amount), 0) INTO v_paid FROM app.payments
    WHERE invoice_id = v_payment.invoice_id AND status = 'CONFIRMED';
    UPDATE app.invoices SET paid_amount = v_paid,
        outstanding_amount = invoice_total - v_paid,
        status = CASE WHEN v_paid = invoice_total THEN 'PAID'
            WHEN current_date > due_date AND invoice_total - v_paid > 0 THEN 'OVERDUE'
            WHEN v_paid > 0 THEN 'PARTIALLY_PAID' ELSE 'ISSUED' END,
        updated_at = now() WHERE id = v_payment.invoice_id;
    SELECT owner_id INTO v_owner_id FROM app.stores WHERE id = v_invoice.store_id;
    INSERT INTO app.notifications (
        id, user_id, notification_type, title, message,
        entity_type, entity_id, dedupe_key
    ) VALUES (
        gen_random_uuid(), v_owner_id, 'PAYMENT_REVERSED',
        'Payment reversed', btrim(p_reason), 'PAYMENT', p_payment_id,
        'PAYMENT_REVERSED:' || p_payment_id
    );
    INSERT INTO app.audit_logs (
        actor_id, action, entity_type, entity_id, reason
    ) VALUES (p_actor_id, 'REVERSE_PAYMENT', 'PAYMENT', p_payment_id, btrim(p_reason));
END;
$$;

CREATE OR REPLACE FUNCTION app.fn_get_invoice(p_invoice_id uuid)
RETURNS TABLE (data jsonb)
LANGUAGE sql STABLE AS $$
    SELECT to_jsonb(i) || jsonb_build_object(
        'items', coalesce((SELECT jsonb_agg(to_jsonb(ii))
            FROM app.invoice_items ii WHERE ii.invoice_id = i.id), '[]'::jsonb),
        'payments', coalesce((SELECT jsonb_agg(to_jsonb(p))
            FROM app.payments p WHERE p.invoice_id = i.id), '[]'::jsonb)
    ) FROM app.invoices i WHERE i.id = p_invoice_id;
$$;
