-- UNAPPLIED: Adds the explicit EXEMPT classification explicitly defining its availability,
-- not acting as a product-specific exemption authority itself.
INSERT INTO public.gst_rate_master (
    id,
    country_id,
    rate_percent,
    rate_name,
    category,
    is_current,
    status,
    notification_number,
    notification_date,
    official_source,
    effective_from,
    rate_code,
    usage_scope,
    erp_visibility,
    statutory_rate_percent,
    effective_display_percent,
    valuation_basis,
    itc_policy,
    conditions
) VALUES (
    gen_random_uuid(),
    'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', -- India country_id
    0,
    'Exempt',
    'EXEMPT',
    true,
    'ACTIVE',
    NULL, -- Nullable per schema; specific exemption authority left to transaction/product layer
    NULL,
    NULL,
    '2017-07-01', -- Indicates classification availability from GST inception date
    'IN_GST_EXEMPT',
    'TRANSACTION_RATE',
    'GENERAL',
    0,
    0,
    'TRANSACTION_VALUE',
    'NO_ITC', -- Permitted policy value representing blocked ITC under Section 17(2)
    '{"treatment": "EXEMPT"}'::jsonb
);
