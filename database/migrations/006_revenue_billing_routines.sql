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
    p_funding_type text,
    p_brand_share numeric,
    p_store_share numeric,
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
        start_date, end_date, scope, funding_type,
        brand_share_percent, store_share_percent, created_by
    ) VALUES (
        p_promotion_id, btrim(p_name), nullif(btrim(p_description), ''),
        upper(p_discount_type), p_discount_value, p_start_date, p_end_date,
        upper(p_scope), upper(p_funding_type), p_brand_share, p_store_share,
        p_actor_id
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
                    'Revenue report overdue',
                    'Revenue for ' || v_date || ' is overdue',
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
            'Invoice overdue', 'Invoice ' || v_invoice.invoice_no || ' is overdue',
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

CREATE OR REPLACE FUNCTION app.fn_get_promotion(p_promotion_id uuid)
RETURNS TABLE (data jsonb)
LANGUAGE sql STABLE AS $$
    SELECT to_jsonb(p) || jsonb_build_object(
        'store_ids', coalesce((SELECT jsonb_agg(ps.store_id)
            FROM app.promotion_stores ps WHERE ps.promotion_id = p.id), '[]'::jsonb)
    ) FROM app.promotions p
    WHERE p.id = p_promotion_id AND p.deleted_at IS NULL;
$$;

CREATE OR REPLACE FUNCTION app.fn_list_records(
    p_entity text,
    p_user_id uuid,
    p_search text,
    p_status text,
    p_page_size integer,
    p_offset integer
)
RETURNS TABLE (data jsonb, total_count bigint)
LANGUAGE plpgsql STABLE
AS $$
BEGIN
    IF p_page_size < 1 OR p_page_size > 200 OR p_offset < 0 THEN
        RAISE EXCEPTION 'PAGINATION_INVALID';
    END IF;
    IF p_entity = 'applications' THEN
        RETURN QUERY SELECT to_jsonb(x), count(*) OVER ()
        FROM app.franchise_applications x
        WHERE x.deleted_at IS NULL
          AND (app.user_has_role(p_user_id, 'ADMIN') OR x.applicant_id = p_user_id)
          AND (p_status IS NULL OR x.status = upper(p_status))
          AND (p_search IS NULL OR x.applicant_name ILIKE '%' || p_search || '%'
               OR x.proposed_store_name ILIKE '%' || p_search || '%')
        ORDER BY x.created_at DESC LIMIT p_page_size OFFSET p_offset;
    ELSIF p_entity = 'stores' THEN
        RETURN QUERY SELECT to_jsonb(x), count(*) OVER () FROM app.stores x
        WHERE x.deleted_at IS NULL
          AND (app.user_has_role(p_user_id, 'ADMIN')
               OR app.user_has_role(p_user_id, 'ACCOUNTANT')
               OR x.owner_id = p_user_id)
          AND (p_status IS NULL OR x.status = upper(p_status))
          AND (p_search IS NULL OR x.name ILIKE '%' || p_search || '%'
               OR x.code ILIKE '%' || p_search || '%')
        ORDER BY x.created_at DESC LIMIT p_page_size OFFSET p_offset;
    ELSIF p_entity = 'contracts' THEN
        RETURN QUERY SELECT to_jsonb(x), count(*) OVER () FROM app.contracts x
        JOIN app.stores s ON s.id = x.store_id
        WHERE (app.user_has_role(p_user_id, 'ADMIN')
               OR app.user_has_role(p_user_id, 'ACCOUNTANT')
               OR s.owner_id = p_user_id)
          AND (p_status IS NULL OR x.status = upper(p_status))
          AND (p_search IS NULL OR x.contract_no ILIKE '%' || p_search || '%')
        ORDER BY x.created_at DESC LIMIT p_page_size OFFSET p_offset;
    ELSIF p_entity = 'promotions' THEN
        RETURN QUERY SELECT to_jsonb(x), count(*) OVER () FROM app.promotions x
        WHERE x.deleted_at IS NULL
          AND (p_status IS NULL OR x.status = upper(p_status))
          AND (p_search IS NULL OR x.name ILIKE '%' || p_search || '%')
        ORDER BY x.created_at DESC LIMIT p_page_size OFFSET p_offset;
    ELSIF p_entity = 'revenues' THEN
        RETURN QUERY SELECT to_jsonb(x), count(*) OVER () FROM app.revenues x
        JOIN app.stores s ON s.id = x.store_id
        WHERE (app.user_has_role(p_user_id, 'ADMIN')
               OR app.user_has_role(p_user_id, 'ACCOUNTANT')
               OR s.owner_id = p_user_id)
          AND (p_status IS NULL OR x.status = upper(p_status))
        ORDER BY x.business_date DESC LIMIT p_page_size OFFSET p_offset;
    ELSIF p_entity = 'invoices' THEN
        RETURN QUERY SELECT to_jsonb(x), count(*) OVER () FROM app.invoices x
        JOIN app.stores s ON s.id = x.store_id
        WHERE (app.user_has_role(p_user_id, 'ADMIN')
               OR app.user_has_role(p_user_id, 'ACCOUNTANT')
               OR s.owner_id = p_user_id)
          AND (p_status IS NULL OR x.status = upper(p_status))
          AND (p_search IS NULL OR x.invoice_no ILIKE '%' || p_search || '%')
        ORDER BY x.period_month DESC LIMIT p_page_size OFFSET p_offset;
    ELSIF p_entity = 'payments' THEN
        RETURN QUERY SELECT to_jsonb(x), count(*) OVER () FROM app.payments x
        JOIN app.invoices i ON i.id = x.invoice_id
        JOIN app.stores s ON s.id = i.store_id
        WHERE (app.user_has_role(p_user_id, 'ADMIN')
               OR app.user_has_role(p_user_id, 'ACCOUNTANT')
               OR s.owner_id = p_user_id)
          AND (p_status IS NULL OR x.status = upper(p_status))
          AND (p_search IS NULL OR x.payment_no ILIKE '%' || p_search || '%')
        ORDER BY x.created_at DESC LIMIT p_page_size OFFSET p_offset;
    ELSIF p_entity = 'notifications' THEN
        RETURN QUERY SELECT to_jsonb(x), count(*) OVER ()
        FROM app.notifications x WHERE x.user_id = p_user_id
        ORDER BY x.created_at DESC LIMIT p_page_size OFFSET p_offset;
    ELSIF p_entity = 'audit_logs' THEN
        PERFORM app.assert_role(p_user_id, 'ADMIN');
        RETURN QUERY SELECT to_jsonb(x), count(*) OVER () FROM app.audit_logs x
        WHERE (p_search IS NULL OR x.action ILIKE '%' || p_search || '%')
        ORDER BY x.created_at DESC LIMIT p_page_size OFFSET p_offset;
    ELSE
        RAISE EXCEPTION 'LIST_ENTITY_INVALID';
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION app.fn_financial_summary(
    p_user_id uuid, p_period_from date, p_period_to date
)
RETURNS TABLE (
    store_id uuid, store_code varchar, store_name varchar,
    gross_revenue numeric, promotion_discount numeric, net_revenue numeric,
    royalty_fee numeric, brand_support numeric, invoice_total numeric,
    paid_amount numeric, outstanding_amount numeric
)
LANGUAGE sql STABLE AS $$
    SELECT s.id, s.code, s.name,
        coalesce(sum(i.monthly_gross_revenue), 0),
        coalesce(sum(mc.monthly_promotion_discount), 0),
        coalesce(sum(mc.monthly_net_revenue), 0),
        coalesce(sum(i.royalty_fee), 0),
        coalesce(sum(i.brand_promotion_support), 0),
        coalesce(sum(i.invoice_total), 0),
        coalesce(sum(i.paid_amount), 0),
        coalesce(sum(i.outstanding_amount), 0)
    FROM app.stores s
    LEFT JOIN app.invoices i ON i.store_id = s.id
        AND i.period_month BETWEEN date_trunc('month', p_period_from)::date
        AND date_trunc('month', p_period_to)::date
        AND i.status <> 'CANCELLED'
    LEFT JOIN app.monthly_closes mc ON mc.id = i.monthly_close_id
    WHERE s.deleted_at IS NULL AND (
        app.user_has_role(p_user_id, 'ADMIN')
        OR app.user_has_role(p_user_id, 'ACCOUNTANT')
        OR s.owner_id = p_user_id
    )
    GROUP BY s.id, s.code, s.name ORDER BY s.code;
$$;
