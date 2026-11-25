-- Stored procedures/functions for 080_queries_reports.sql.

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
