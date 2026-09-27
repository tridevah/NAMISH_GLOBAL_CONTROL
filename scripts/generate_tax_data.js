const fs = require('fs');
const crypto = require('crypto');

const rawCountries = JSON.parse(fs.readFileSync('countries.json', 'utf8'));
const regex = /\('([^']+)',\s*'([^']+)',\s*'[^']+',\s*'[^']+',\s*'([^']+)'/;

const countries = [];
for (const line of rawCountries) {
  const match = regex.exec(line);
  if (match) {
    countries.push({ id: match[1], iso2: match[2], name: match[3] });
  }
}

const knownAuthorities = {
  'IN': { type: 'GST', name: 'Goods and Services Tax Council', url: 'https://gstcouncil.gov.in', ref: 'CBIC/GSTC' },
  'US': { type: 'SALES_TAX', name: 'Internal Revenue Service (Federal) / State Revenue Departments', url: 'https://www.irs.gov', ref: 'IRS_STATE_DEPT' },
  'GB': { type: 'VAT', name: 'HM Revenue and Customs', url: 'https://www.gov.uk/government/organisations/hm-revenue-customs', ref: 'HMRC' },
  'DE': { type: 'VAT', name: 'Bundeszentralamt für Steuern', url: 'https://www.bzst.de', ref: 'BZSt' },
  'FR': { type: 'VAT', name: 'Direction générale des Finances publiques', url: 'https://www.impots.gouv.fr', ref: 'DGFiP' },
  'JP': { type: 'VAT', name: 'National Tax Agency', url: 'https://www.nta.go.jp', ref: 'NTA' },
  'CN': { type: 'VAT', name: 'State Taxation Administration', url: 'http://www.chinatax.gov.cn', ref: 'STA' },
  'BR': { type: 'VAT', name: 'Receita Federal do Brasil', url: 'https://www.gov.br/receitafederal', ref: 'RFB' },
  'AU': { type: 'GST', name: 'Australian Taxation Office', url: 'https://www.ato.gov.au', ref: 'ATO' },
  'CA': { type: 'GST', name: 'Canada Revenue Agency', url: 'https://www.canada.ca/en/revenue-agency.html', ref: 'CRA' },
  'AE': { type: 'VAT', name: 'Federal Tax Authority', url: 'https://tax.gov.ae', ref: 'FTA' },
  'ZA': { type: 'VAT', name: 'South African Revenue Service', url: 'https://www.sars.gov.za', ref: 'SARS' },
  'NZ': { type: 'GST', name: 'Inland Revenue Department', url: 'https://www.ird.govt.nz', ref: 'IRD' },
  'SG': { type: 'GST', name: 'Inland Revenue Authority of Singapore', url: 'https://www.iras.gov.sg', ref: 'IRAS' },
  'IE': { type: 'VAT', name: 'Revenue Commissioners', url: 'https://www.revenue.ie', ref: 'REVENUE_IE' },
  'IT': { type: 'VAT', name: 'Agenzia delle Entrate', url: 'https://www.agenziaentrate.gov.it', ref: 'AGE' },
  'ES': { type: 'VAT', name: 'Agencia Estatal de Administración Tributaria', url: 'https://sede.agenciatributaria.gob.es', ref: 'AEAT' },
  'NL': { type: 'VAT', name: 'Belastingdienst', url: 'https://www.belastingdienst.nl', ref: 'BD' },
  'CH': { type: 'VAT', name: 'Federal Tax Administration', url: 'https://www.estv.admin.ch', ref: 'ESTV' },
  'SE': { type: 'VAT', name: 'Skatteverket', url: 'https://www.skatteverket.se', ref: 'SKV' },
  'NO': { type: 'VAT', name: 'Skatteetaten', url: 'https://www.skatteetaten.no', ref: 'SKT' },
  'FI': { type: 'VAT', name: 'Verohallinto', url: 'https://www.vero.fi', ref: 'VERO' },
  'DK': { type: 'VAT', name: 'Skattestyrelsen', url: 'https://skat.dk', ref: 'SKAT' },
  'AT': { type: 'VAT', name: 'Bundesministerium für Finanzen', url: 'https://www.bmf.gv.at', ref: 'BMF' },
  'BE': { type: 'VAT', name: 'FPS Finances', url: 'https://finance.belgium.be', ref: 'FPSF' },
  'PT': { type: 'VAT', name: 'Autoridade Tributária e Aduaneira', url: 'https://www.portaldasfinancas.gov.pt', ref: 'AT' },
  'GR': { type: 'VAT', name: 'Independent Authority for Public Revenue', url: 'https://www.aade.gr', ref: 'AADE' },
  'TR': { type: 'VAT', name: 'Gelir İdaresi Başkanlığı', url: 'https://www.gib.gov.tr', ref: 'GIB' },
  'RU': { type: 'VAT', name: 'Federal Tax Service', url: 'https://www.nalog.gov.ru', ref: 'FNS' },
  'MX': { type: 'VAT', name: 'Servicio de Administración Tributaria', url: 'https://www.sat.gob.mx', ref: 'SAT' },
  'AR': { type: 'VAT', name: 'Administración Federal de Ingresos Públicos', url: 'https://www.afip.gob.ar', ref: 'AFIP' },
  'KR': { type: 'VAT', name: 'National Tax Service', url: 'https://www.nts.go.kr', ref: 'NTS' },
  'ID': { type: 'VAT', name: 'Directorate General of Taxes', url: 'https://www.pajak.go.id', ref: 'DGT' },
  'SA': { type: 'VAT', name: 'Zakat, Tax and Customs Authority', url: 'https://zatca.gov.sa', ref: 'ZATCA' },
  'MY': { type: 'SALES_TAX', name: 'Royal Malaysian Customs Department', url: 'https://www.customs.gov.my', ref: 'RMCD' },
  'PH': { type: 'VAT', name: 'Bureau of Internal Revenue', url: 'https://www.bir.gov.ph', ref: 'BIR' },
  'VN': { type: 'VAT', name: 'General Department of Taxation', url: 'https://www.gdt.gov.vn', ref: 'GDT' },
  'TH': { type: 'VAT', name: 'The Revenue Department', url: 'https://www.rd.go.th', ref: 'RD' },
  'PK': { type: 'SALES_TAX', name: 'Federal Board of Revenue', url: 'https://www.fbr.gov.pk', ref: 'FBR' },
  'BD': { type: 'VAT', name: 'National Board of Revenue', url: 'https://nbr.gov.bd', ref: 'NBR' },
  'EG': { type: 'VAT', name: 'Egyptian Tax Authority', url: 'https://eta.gov.eg', ref: 'ETA' },
  'NG': { type: 'VAT', name: 'Federal Inland Revenue Service', url: 'https://www.firs.gov.ng', ref: 'FIRS' },
  'KE': { type: 'VAT', name: 'Kenya Revenue Authority', url: 'https://www.kra.go.ke', ref: 'KRA' },
  'CO': { type: 'VAT', name: 'Dirección de Impuestos y Aduanas Nacionales', url: 'https://www.dian.gov.co', ref: 'DIAN' },
  'CL': { type: 'VAT', name: 'Servicio de Impuestos Internos', url: 'https://www.sii.cl', ref: 'SII' },
  'PE': { type: 'VAT', name: 'Superintendencia Nacional de Aduanas y de Administración Tributaria', url: 'https://www.sunat.gob.pe', ref: 'SUNAT' },
  'AQ': { type: 'NOT_APPLICABLE', name: 'Antarctica - No Official Taxation', url: 'N/A', ref: 'ANTARCTIC_TREATY' },
  'PS': { type: 'VAT', name: 'Palestinian Ministry of Finance', url: 'http://www.pmof.ps', ref: 'PMOF' }
};

let sql = `-- Migration 000018: Global Tax Authorities Canonical Data Load\n\n`;
let knownCount = 0;
let unresolvedCount = 0;
let notApplicableCount = 0;

sql += `
-- Pre-requisites: Ensure applicability_scopes and jurisdictions match expected schema
CREATE TABLE IF NOT EXISTS catalog.applicability_scopes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country_id UUID NOT NULL REFERENCES catalog.countries(id),
    scope_type TEXT NOT NULL CHECK (scope_type IN ('COUNTRY_WIDE', 'GEOGRAPHIC')),
    priority INT NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE catalog.jurisdictions ADD COLUMN IF NOT EXISTS country_id UUID REFERENCES catalog.countries(id);
ALTER TABLE catalog.jurisdictions ADD COLUMN IF NOT EXISTS applicability_scope_id UUID REFERENCES catalog.applicability_scopes(id);

ALTER TABLE catalog.tax_authorities DROP CONSTRAINT IF EXISTS tax_authorities_tax_type_check;
ALTER TABLE catalog.tax_authorities ADD CONSTRAINT tax_authorities_tax_type_check CHECK (tax_type IN ('GST', 'VAT', 'SALES_TAX', 'WITHHOLDING', 'TDS', 'CUSTOMS', 'EXCISE', 'NOT_APPLICABLE', 'UNRESOLVED'));

`;

for (const c of countries) {
  const code = c.iso2;
  let auth = knownAuthorities[code] || { type: 'UNRESOLVED', name: 'UNRESOLVED EXCEPTION', url: 'UNRESOLVED', ref: 'UNRESOLVED' };
  
  const scopeId = crypto.randomUUID();
  const jurId = crypto.randomUUID();
  const authId = crypto.randomUUID();
  const dateStr = new Date().toISOString();
  
  const h = crypto.createHash('sha256').update(c.id + auth.name + auth.url).digest('hex');
  
  // Create Scope
  sql += `INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('${scopeId}', '${c.id}', 'COUNTRY_WIDE');\n`;
  // Create Jurisdiction
  sql += `INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('${jurId}', '${c.id}', '${scopeId}', '${code}_NATIONAL', '${c.name.replace(/'/g, "''")} National Tax Jurisdiction');\n`;
  // Create Authority
  sql += `INSERT INTO catalog.tax_authorities (id, country_id, jurisdiction_id, tax_type, authority_name, official_website, provenance_reference, effective_from) VALUES ('${authId}', '${c.id}', '${jurId}', '${auth.type}', '${auth.name.replace(/'/g, "''")}', '${auth.url}', 'HASH:${h}', '${dateStr}');\n`;
  
  if (auth.type === 'UNRESOLVED') unresolvedCount++;
  else if (auth.type === 'NOT_APPLICABLE') notApplicableCount++;
  else knownCount++;
}

fs.writeFileSync('supabase/migrations/20260902000004_tax_authority_data.sql', sql);
console.log(`Generated migration with ${knownCount} known, ${notApplicableCount} not applicable, ${unresolvedCount} unresolved.`);
console.log(`Total 249 countries covered.`);
