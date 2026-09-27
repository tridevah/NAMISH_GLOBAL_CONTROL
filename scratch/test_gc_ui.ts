import * as dotenv from 'dotenv';
dotenv.config({ path: '.env.local' });

type GstRate = any;

function mockComponentLogic(rates: GstRate[], view: 'TRANSACTION' | 'REFERENCE', search: string = '', statusFilter: string = 'ACTIVE') {
    // 1. View Filter
    const viewRates = rates.filter(r => {
        const isEligibleTx = r.usage_scope === 'TRANSACTION_RATE' && r.is_current === true && (r.erp_visibility === 'GENERAL' || r.erp_visibility === 'CONTEXT_ONLY');
        if (view === 'TRANSACTION') {
            return isEligibleTx;
        } else {
            return !isEligibleTx;
        }
    })

    // 2. Expand
    let expanded: any[] = [];
    for (const r of viewRates) {
        const statRate = r.statutory_rate_percent ?? r.rate_percent;
        const effRate = r.effective_display_percent ?? r.rate_percent;
        const differ = statRate !== effRate;
        
        const isConditional = r.erp_visibility === 'CONTEXT_ONLY';
        const isEffective = differ;

        if (view === 'TRANSACTION') {
            if (r.category === 'EXEMPT') {
                expanded.push({ displayName: 'Exempt', displayRate: '—', record: r, isConditional, isEffective });
            } else {
                expanded.push({ displayName: `IGST@${effRate}%`, displayRate: String(effRate), record: r, isConditional, isEffective });
                expanded.push({ displayName: `GST@${effRate}%`, displayRate: String(effRate), record: r, isConditional, isEffective });
            }
        } else {
            expanded.push({ displayName: r.rate_name, displayRate: String(r.rate_percent), record: r, isConditional: false, isEffective: false });
        }
    }

    // 3. Search & Status Filter
    const filtered = expanded.filter(item => {
        if (statusFilter !== 'ALL' && item.record.status !== statusFilter) return false;
        if (search) {
            const q = search.toLowerCase();
            return item.displayName.toLowerCase().includes(q) || item.record.rate_name.toLowerCase().includes(q);
        }
        return true;
    });

    return filtered;
}

const mockDb: GstRate[] = [
    { id: '1', rate_name: 'Nil Rated', rate_percent: 0, category: 'NIL', is_current: true, status: 'ACTIVE', usage_scope: 'TRANSACTION_RATE', erp_visibility: 'GENERAL' },
    { id: '2', rate_name: 'Exempt Rate', rate_percent: 0, category: 'EXEMPT', is_current: true, status: 'ACTIVE', usage_scope: 'TRANSACTION_RATE', erp_visibility: 'GENERAL' },
    { id: '3', rate_name: 'Real Estate', rate_percent: 5, category: 'SPECIAL', is_current: true, status: 'ACTIVE', usage_scope: 'TRANSACTION_RATE', erp_visibility: 'CONTEXT_ONLY', statutory_rate_percent: 7.5, effective_display_percent: 5 },
    { id: '4', rate_name: 'Composition 1%', rate_percent: 1, category: 'COMPOSITION', is_current: true, status: 'ACTIVE', usage_scope: 'TAXPAYER_SCHEME', erp_visibility: 'HIDDEN' }
];

console.log("=== Transaction View: Nil Rated ===");
const txNil = mockComponentLogic([mockDb[0]], 'TRANSACTION');
txNil.forEach(r => console.log(`${r.displayName} | Rate: ${r.displayRate} | Cond: ${r.isConditional} | Eff: ${r.isEffective}`));

console.log("\n=== Transaction View: Exempt ===");
const txExempt = mockComponentLogic([mockDb[1]], 'TRANSACTION');
txExempt.forEach(r => console.log(`${r.displayName} | Rate: ${r.displayRate} | Cond: ${r.isConditional} | Eff: ${r.isEffective}`));

console.log("\n=== Transaction View: Real Estate ===");
const txReal = mockComponentLogic([mockDb[2]], 'TRANSACTION');
txReal.forEach(r => console.log(`${r.displayName} | Rate: ${r.displayRate} | Cond: ${r.isConditional} | Eff: ${r.isEffective}`));

console.log("\n=== Reference View: Composition ===");
const refComp = mockComponentLogic([mockDb[3]], 'REFERENCE');
refComp.forEach(r => console.log(`${r.displayName} | Rate: ${r.displayRate} | Cond: ${r.isConditional} | Eff: ${r.isEffective}`));

console.log("\n=== Display-name search: 'gst@0%' ===");
const searchRes = mockComponentLogic(mockDb, 'TRANSACTION', 'gst@0%');
console.log(`Matched records: ${searchRes.length}`);
searchRes.forEach(r => console.log(`- ${r.displayName}`));

