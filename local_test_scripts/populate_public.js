const fs = require('fs');

const hsn = fs.readFileSync('exported_hsn.jsonl', 'utf8').split('\n').filter(Boolean);
const units = fs.readFileSync('exported_units.jsonl', 'utf8').split('\n').filter(Boolean);
const taxes = fs.readFileSync('exported_taxes.jsonl', 'utf8').split('\n').filter(Boolean);

let sql = `
BEGIN;
CREATE SCHEMA IF NOT EXISTS public;
CREATE TABLE IF NOT EXISTS public.hsn_sac (
    id UUID PRIMARY KEY, code TEXT, type TEXT, description TEXT, category TEXT
);
CREATE TABLE IF NOT EXISTS public.measurement_units (
    id UUID PRIMARY KEY, code TEXT, canonical_code TEXT, name TEXT, is_business BOOLEAN,
    business_name TEXT, short_name TEXT, status TEXT
);
CREATE TABLE IF NOT EXISTS public.gst_rate_master (
    id UUID PRIMARY KEY, country_id UUID, rate_name TEXT, rate_percent NUMERIC,
    statutory_rate_percent NUMERIC, effective_display_percent NUMERIC,
    erp_visibility TEXT, valuation_basis TEXT, itc_policy TEXT, conditions JSONB,
    usage_scope TEXT, status TEXT, effective_from DATE, effective_to DATE, is_current BOOLEAN, category TEXT
);
TRUNCATE public.hsn_sac, public.measurement_units, public.gst_rate_master CASCADE;
`;

const hVals = [];
for (const line of hsn) {
    const o = JSON.parse(line);
    hVals.push(`('${o.id}', '${o.code}', '${o.type}', '${(o.description||'').replace(/'/g,"''")}', '${o.category}')`);
}
if(hVals.length) sql += `INSERT INTO public.hsn_sac (id, code, type, description, category) VALUES ` + hVals.join(',') + `;\n`;

const uVals = [];
for (const line of units) {
    const o = JSON.parse(line);
    uVals.push(`('${o.id}', '${o.code}', '${o.canonical_code||o.code}', '${(o.name||'').replace(/'/g,"''")}', ${!!o.is_business}, ${o.business_name ? `'${o.business_name.replace(/'/g,"''")}'` : 'NULL'}, '${(o.short_name||'').replace(/'/g,"''")}', '${o.status}')`);
}
if(uVals.length) sql += `INSERT INTO public.measurement_units (id, code, canonical_code, name, is_business, business_name, short_name, status) VALUES ` + uVals.join(',') + `;\n`;

const tVals = [];
for (const line of taxes) {
    const o = JSON.parse(line);
    tVals.push(`('${o.id}', '${o.country_id}', '${(o.rate_name||o.name||'').replace(/'/g,"''")}', ${o.rate_percent||o.rate||0}, ${o.statutory_rate_percent||0}, ${o.effective_display_percent||0}, '${o.erp_visibility}', '${o.valuation_basis}', '${o.itc_policy}', '${JSON.stringify(o.conditions||{}).replace(/'/g,"''")}'::jsonb, '${o.usage_scope}', '${o.status}', ${o.effective_from ? `'${o.effective_from}'` : 'NULL'}, ${o.effective_to ? `'${o.effective_to}'` : 'NULL'}, ${!!o.is_current}, '${o.category}')`);
}
if(tVals.length) sql += `INSERT INTO public.gst_rate_master (id, country_id, rate_name, rate_percent, statutory_rate_percent, effective_display_percent, erp_visibility, valuation_basis, itc_policy, conditions, usage_scope, status, effective_from, effective_to, is_current, category) VALUES ` + tVals.join(',') + `;\n`;

sql += `COMMIT;`;
fs.writeFileSync('populate_public.sql', sql);
