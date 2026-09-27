const fs = require('fs');

const raw = fs.readFileSync('current_gst_rates.json', 'utf8');
const lines = raw.split('\n');
const jsonStr = lines.slice(lines.findIndex(l => l.includes('"rows":')) - 1, lines.findIndex(l => l.includes('"warning"'))).join('\n') + '}';
const rows = JSON.parse(jsonStr).rows;

let sql = `-- Migration 20260904000033_gst_rate_scope_and_completeness.sql

ALTER TABLE catalog.gst_rate_master ADD COLUMN rate_code TEXT;
ALTER TABLE catalog.gst_rate_master ADD COLUMN usage_scope TEXT;
ALTER TABLE catalog.gst_rate_master ADD COLUMN erp_visibility TEXT;
ALTER TABLE catalog.gst_rate_master ADD COLUMN statutory_rate_percent NUMERIC;
ALTER TABLE catalog.gst_rate_master ADD COLUMN effective_display_percent NUMERIC;
ALTER TABLE catalog.gst_rate_master ADD COLUMN valuation_basis TEXT;
ALTER TABLE catalog.gst_rate_master ADD COLUMN itc_policy TEXT;
ALTER TABLE catalog.gst_rate_master ADD COLUMN conditions JSONB;

-- Clean up existing data for exactly 14 rows mapping
DELETE FROM catalog.gst_rate_master WHERE country_id = (SELECT id FROM catalog.countries WHERE iso2 = 'IN');

ALTER TABLE catalog.gst_rate_master ADD CONSTRAINT gst_rate_master_usage_scope_check 
    CHECK (usage_scope IN ('TRANSACTION_RATE', 'TAXPAYER_SCHEME', 'HISTORICAL'));
ALTER TABLE catalog.gst_rate_master ADD CONSTRAINT gst_rate_master_erp_visibility_check 
    CHECK (erp_visibility IN ('GENERAL', 'CONTEXT_ONLY', 'NEVER_LINE_ITEM', 'HIDDEN'));

-- Also create applications table
CREATE TABLE catalog.gst_rate_applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country_id UUID NOT NULL REFERENCES catalog.countries(id),
    application_code TEXT NOT NULL,
    base_rate_code TEXT NOT NULL,
    usage_scope TEXT,
    erp_visibility TEXT,
    effective_display_percent NUMERIC,
    cgst_percent NUMERIC,
    sgst_utgst_percent NUMERIC,
    igst_percent NUMERIC,
    valuation_factor NUMERIC,
    itc_policy TEXT,
    conditions JSONB,
    UNIQUE(country_id, application_code)
);

DO $$
DECLARE
    v_in_id UUID;
BEGIN
    SELECT id INTO STRICT v_in_id FROM catalog.countries WHERE iso2 = 'IN';

`;

function formatString(s) {
    if (s === null || s === undefined) return 'NULL';
    return "'" + s.replace(/'/g, "''") + "'";
}

const newRows = [];

rows.forEach(r => {
    let rate_code = 'IN_GST_' + parseFloat(r.rate_percent).toString().replace('.', '_');
    let usage_scope = 'TRANSACTION_RATE';
    let erp_visibility = 'GENERAL';
    let stat = parseFloat(r.rate_percent);
    let eff = parseFloat(r.rate_percent);
    let val_basis = 'TRANSACTION_VALUE';
    let itc_policy = 'DEFAULT';
    let conditions = 'null';
    let is_current = r.is_current;
    let status = r.status;
    
    if (r.category === 'COMPOSITION') {
        usage_scope = 'TAXPAYER_SCHEME';
        erp_visibility = 'NEVER_LINE_ITEM';
        rate_code = 'IN_GST_COMP_' + stat.toString().replace('.', '_');
    }
    else if (r.category === 'HISTORICAL' || !is_current || stat === 28) {
        usage_scope = 'HISTORICAL';
        erp_visibility = 'HIDDEN';
        is_current = false;
        r.effective_to = '2026-01-31';
        rate_code = 'IN_GST_HIST_28';
    }
    
    if (stat === 0.25 || stat === 3 || stat === 40) {
        erp_visibility = 'GENERAL';
    }
    
    if (stat === 1.5) {
        erp_visibility = 'CONTEXT_ONLY';
        eff = 1.0;
        val_basis = 'TWO_THIRDS_GROSS';
        itc_policy = 'NO_ITC';
    }

    if (stat === 12) {
        erp_visibility = 'CONTEXT_ONLY';
        r.rate_name = 'Specified bricks/tiles only';
        r.category = 'SPECIAL';
    }

    newRows.push({
        ...r, rate_code, usage_scope, erp_visibility, stat, eff, val_basis, itc_policy, conditions, is_current, status
    });
});

// Add 0.10% SPECIAL and 7.5% SPECIAL
newRows.push({
    category: "SPECIAL",
    effective_from: "2017-10-23",
    effective_to: null,
    is_current: true,
    notes: null,
    notification_date: "2017-10-23",
    notification_number: "40/2017-Central Tax (Rate)",
    official_source: "https://gstcouncil.gov.in/sites/default/files/gst-rates/40-2017-CGST-Rate-English.pdf",
    source_reference: null,
    rate_name: "Merchant-export procurement only",
    rate_percent: "0.10",
    status: "ACTIVE",
    rate_code: "IN_GST_0_1",
    usage_scope: "TRANSACTION_RATE",
    erp_visibility: "CONTEXT_ONLY",
    stat: 0.10,
    eff: 0.10,
    val_basis: "TRANSACTION_VALUE",
    itc_policy: "RESTRICTED",
    conditions: '{"merchant_export": true}'
});

newRows.push({
    category: "SPECIAL",
    effective_from: "2019-04-01",
    effective_to: null,
    is_current: true,
    notes: "Real estate other than affordable housing",
    notification_date: "2019-03-29",
    notification_number: "03/2019-Central Tax (Rate)",
    official_source: "https://gstcouncil.gov.in/sites/default/files/gst-rates/03-2019-CGST-Rate-English.pdf",
    source_reference: null,
    rate_name: "Real Estate (Other than affordable)",
    rate_percent: "7.50",
    status: "ACTIVE",
    rate_code: "IN_GST_7_5",
    usage_scope: "TRANSACTION_RATE",
    erp_visibility: "CONTEXT_ONLY",
    stat: 7.50,
    eff: 5.00,
    val_basis: "TWO_THIRDS_GROSS",
    itc_policy: "NO_ITC",
    conditions: '{"real_estate_other": true}'
});

newRows.forEach(r => {
    sql += `
    INSERT INTO catalog.gst_rate_master (
        id, country_id, rate_percent, rate_name, category, is_current, status, 
        notification_number, notification_date, official_source, source_reference, notes, effective_from, effective_to,
        rate_code, usage_scope, erp_visibility, statutory_rate_percent, effective_display_percent, valuation_basis, itc_policy, conditions
    ) VALUES (
        gen_random_uuid(), v_in_id, ${r.stat}, ${formatString(r.rate_name)}, ${formatString(r.category)}, ${r.is_current}, ${formatString(r.status)},
        ${formatString(r.notification_number)}, ${formatString(r.notification_date)}, ${formatString(r.official_source)}, ${formatString(r.source_reference)}, ${formatString(r.notes)}, ${formatString(r.effective_from)}, ${formatString(r.effective_to)},
        ${formatString(r.rate_code)}, ${formatString(r.usage_scope)}, ${formatString(r.erp_visibility)}, ${r.stat}, ${r.eff}, ${formatString(r.val_basis)}, ${formatString(r.itc_policy)}, '${r.conditions}'::jsonb
    );
`;
});

sql += `
    -- Add Applications
    INSERT INTO catalog.gst_rate_applications (country_id, application_code, base_rate_code, usage_scope, erp_visibility, effective_display_percent, cgst_percent, sgst_utgst_percent, igst_percent, valuation_factor, itc_policy, conditions) VALUES
    (v_in_id, 'MERCHANT_EXPORT_0_10', 'IN_GST_0_1', 'TRANSACTION_RATE', 'CONTEXT_ONLY', 0.10, 0.05, 0.05, 0.10, 1.0, 'RESTRICTED', '{"merchant_export": true}'::jsonb),
    (v_in_id, 'REAL_ESTATE_AFFORDABLE_EFFECTIVE_1', 'IN_GST_1_5', 'TRANSACTION_RATE', 'CONTEXT_ONLY', 1.00, 0.50, 0.50, 1.00, 0.666667, 'NO_ITC', '{"real_estate_affordable": true}'::jsonb),
    (v_in_id, 'REAL_ESTATE_OTHER_EFFECTIVE_5', 'IN_GST_7_5', 'TRANSACTION_RATE', 'CONTEXT_ONLY', 5.00, 2.50, 2.50, 5.00, 0.666667, 'NO_ITC', '{"real_estate_other": true}'::jsonb),
    (v_in_id, 'BRICKS_TILES_12', 'IN_GST_12', 'TRANSACTION_RATE', 'CONTEXT_ONLY', 12.00, 6.00, 6.00, 12.00, 1.0, 'DEFAULT', '{"notification_14_2025_scope": true}'::jsonb),
    (v_in_id, 'COMPOSITION_MANUFACTURER_1', 'IN_GST_COMP_1', 'TAXPAYER_SCHEME', 'NEVER_LINE_ITEM', 1.00, 0.50, 0.50, 0.00, 1.0, 'NO_ITC', '{"composition_manufacturer": true}'::jsonb),
    (v_in_id, 'COMPOSITION_OTHER_SUPPLIER_1', 'IN_GST_COMP_1', 'TAXPAYER_SCHEME', 'NEVER_LINE_ITEM', 1.00, 0.50, 0.50, 0.00, 1.0, 'NO_ITC', '{"composition_other": true}'::jsonb),
    (v_in_id, 'COMPOSITION_RESTAURANT_5', 'IN_GST_COMP_5', 'TAXPAYER_SCHEME', 'NEVER_LINE_ITEM', 5.00, 2.50, 2.50, 0.00, 1.0, 'NO_ITC', '{"composition_restaurant": true}'::jsonb),
    (v_in_id, 'COMPOSITION_SERVICE_6', 'IN_GST_COMP_6', 'TAXPAYER_SCHEME', 'NEVER_LINE_ITEM', 6.00, 3.00, 3.00, 0.00, 1.0, 'NO_ITC', '{"composition_service": true}'::jsonb),
    (v_in_id, 'NIL_RATED', 'IN_GST_0', 'TRANSACTION_RATE', 'GENERAL', 0.00, 0.00, 0.00, 0.00, 1.0, 'DEFAULT', '{"treatment": "NIL_RATED"}'::jsonb),
    (v_in_id, 'EXEMPT', 'IN_GST_0', 'TRANSACTION_RATE', 'GENERAL', 0.00, 0.00, 0.00, 0.00, 1.0, 'DEFAULT', '{"treatment": "EXEMPT"}'::jsonb),
    (v_in_id, 'ZERO_RATED', 'IN_GST_0', 'TRANSACTION_RATE', 'GENERAL', 0.00, 0.00, 0.00, 0.00, 1.0, 'DEFAULT', '{"treatment": "ZERO_RATED"}'::jsonb);
END $$;
ALTER TABLE catalog.gst_rate_master ADD CONSTRAINT gst_rate_master_country_rate_code_key UNIQUE (country_id, rate_code);
`;

fs.writeFileSync('D:\\NAMISH_GLOBAL_CONTROL\\supabase\\migrations\\20260904000033_gst_rate_scope_and_completeness.sql', sql);
