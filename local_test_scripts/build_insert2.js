const fs = require('fs');

const hsn = fs.readFileSync('exported_hsn.jsonl', 'utf8').split('\n').filter(Boolean);
const units = fs.readFileSync('exported_units.jsonl', 'utf8').split('\n').filter(Boolean);
const taxes = fs.readFileSync('exported_taxes.jsonl', 'utf8').split('\n').filter(Boolean);

let sql = `
BEGIN;
SET LOCAL search_path = '';
DELETE FROM catalog.catalog_releases WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
INSERT INTO catalog.catalog_releases (id, version, status, hsn_sac_intentionally_empty, tax_profiles_intentionally_empty, units_intentionally_empty)
VALUES ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'v8.0.0', 'DRAFT', false, false, false);
INSERT INTO catalog.catalog_release_items (item_id, release_id, item_type, payload) VALUES
`;

const values = [];

for (const line of hsn) {
    const obj = JSON.parse(line);
    const payload = {
        id: obj.id,
        code: obj.code,
        type: obj.type || 'HSN',
        description: obj.description || '',
        category: obj.category || 'GOODS'
    };
    values.push(`('${obj.id}', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'HSN_SAC', '${JSON.stringify(payload).replace(/'/g, "''")}'::jsonb)`);
}

for (const line of units) {
    const obj = JSON.parse(line);
    const payload = {
        id: obj.id,
        code: obj.code,
        canonical_code: obj.canonical_code || obj.code,
        name: obj.name || obj.code,
        is_business: !!obj.is_business,
        business_name: obj.business_name || null,
        short_name: obj.short_name || obj.code,
        status: obj.status || 'ACTIVE'
    };
    values.push(`('${obj.id}', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'UNIT', '${JSON.stringify(payload).replace(/'/g, "''")}'::jsonb)`);
}

for (const line of taxes) {
    const obj = JSON.parse(line);
    const payload = {
        id: obj.id,
        country_id: obj.country_id,
        rate_name: obj.rate_name,
        rate_percent: obj.rate_percent,
        statutory_rate_percent: obj.statutory_rate_percent,
        effective_display_percent: obj.effective_display_percent,
        erp_visibility: obj.erp_visibility,
        valuation_basis: obj.valuation_basis,
        itc_policy: obj.itc_policy,
        conditions: obj.conditions || {},
        usage_scope: obj.usage_scope,
        status: obj.status,
        effective_from: obj.effective_from,
        effective_to: obj.effective_to,
        is_current: obj.is_current
    };
    values.push(`('${obj.id}', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'TAX_PROFILE', '${JSON.stringify(payload).replace(/'/g, "''")}'::jsonb)`);
}

sql += values.join(',\n') + ';\n';

sql += `
DROP TRIGGER IF EXISTS trg_publish_release ON catalog.catalog_releases;
CREATE TRIGGER trg_publish_release
BEFORE UPDATE ON catalog.catalog_releases
FOR EACH ROW EXECUTE FUNCTION catalog.fn_publish_release();

UPDATE catalog.catalog_releases SET status = 'PUBLISHED' WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
COMMIT;
`;

fs.writeFileSync('insert_real.sql', sql);
