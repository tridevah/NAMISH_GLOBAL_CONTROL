const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const outDir = path.join(__dirname, '../gst_dataset');
if (!fs.existsSync(outDir)) {
    fs.mkdirSync(outDir, { recursive: true });
}

// Current Effective Rates dataset (Mocked/Simplified for architectural demonstration based on V4.3)
const effective_rates = [
  { category: 'STANDARD_GOODS_18', code: 'IGST_18', rate: 18.00, hsn_prefix: 'ANY', effective_from: '2025-10-01', status: 'ACTIVE', provenance: '09/2025-Integrated Tax (Rate)' },
  { category: 'STANDARD_SERVICES_18', code: 'IGST_18_SVC', rate: 18.00, sac_prefix: '99', effective_from: '2025-10-01', status: 'ACTIVE', provenance: '11/2017-Central Tax (Rate) as amended by 15/2025' },
  { category: 'EXEMPT_GOODS', code: 'IGST_0', rate: 0.00, hsn_prefix: '0101', effective_from: '2025-10-01', status: 'ACTIVE', provenance: '10/2025-Integrated Tax (Rate)' },
  { category: 'COMPOSITION_TRADERS', code: 'COMP_1', rate: 1.00, hsn_prefix: 'ANY', effective_from: '2019-04-01', status: 'ACTIVE', provenance: '14/2019-Central Tax' },
  { category: 'COMPOSITION_SERVICES', code: 'COMP_6', rate: 6.00, sac_prefix: 'ANY', effective_from: '2019-04-01', status: 'ACTIVE', provenance: '02/2019-Central Tax (Rate)' },
  { category: 'TOBACCO_CESS', code: 'CESS_TOBACCO', rate: 290.00, hsn_prefix: '2402', effective_from: '2026-02-01', status: 'ACTIVE', provenance: '01/2026-Central Tax (Rate)' }
];

const effective_rules = [
  { rule_type: 'RCM_GOODS', condition: 'Cashew nuts, not shelled or peeled', supplier: 'Agriculturist', recipient: 'Registered Person', effective_from: '2017-07-01', status: 'ACTIVE', provenance: '04/2017-Central Tax (Rate)' },
  { rule_type: 'RCM_SERVICES', condition: 'GTA Services', supplier: 'Goods Transport Agency', recipient: 'Registered Person', effective_from: '2025-07-01', status: 'ACTIVE', provenance: '13/2017-Central Tax (Rate) as amended by 07/2025' },
  { rule_type: 'SEC_9_4_RCM', condition: 'Promoter purchasing from unregistered', supplier: 'Unregistered', recipient: 'Promoter', effective_from: '2019-04-01', status: 'ACTIVE', provenance: '07/2019-Central Tax (Rate)' }
];

const unresolved = [
  { type: 'HSN_RATE_MATRIX', reason: 'Full 10,000+ row HSN schedule extraction requires dedicated OCR/NLP pipeline beyond current script scope.', status: 'UNRESOLVED_EXTRACTION' },
  { type: 'SAC_RATE_MATRIX', reason: 'Full SAC schedule extraction requires dedicated NLP pipeline.', status: 'UNRESOLVED_EXTRACTION' },
  { type: 'CESS_SCHEDULE_DETAILS', reason: 'Specific cess rates for motor vehicles require complex condition parsing.', status: 'UNRESOLVED_EXTRACTION' }
];

fs.writeFileSync(path.join(outDir, 'current_effective_rates.json'), JSON.stringify(effective_rates, null, 2));
fs.writeFileSync(path.join(outDir, 'current_effective_rules.json'), JSON.stringify(effective_rules, null, 2));
fs.writeFileSync(path.join(outDir, 'unresolved_extractions.json'), JSON.stringify(unresolved, null, 2));

console.log('Dataset built.');
