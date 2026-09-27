const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const outDir = path.join(__dirname, '../gst_dataset/v5');

// Since we cannot use mock schedules, and the primary rate schedule (e.g. 01/2017-CT(R) and its 2025/2026 amendments) 
// were not fully downloaded as valid PDFs in V4.3 (we only got some egazettes and RCM notifications), 
// we MUST mark the entire rate matrix as unresolved.

const verified_rates = [];

const unresolved = [
  {
    target: "CGST_RATE_SCHEDULE_GOODS",
    estimated_entries: 4500,
    reason: "Primary consolidated goods rate schedule PDF not acquired in V4.3. Raw tabular extraction and cross-validation against 2026 amendments impossible without source.",
    status: "UNRESOLVED_SOURCE_AND_EXTRACTION"
  },
  {
    target: "IGST_RATE_SCHEDULE_GOODS",
    estimated_entries: 4500,
    reason: "Primary consolidated goods rate schedule PDF not acquired in V4.3. Raw tabular extraction and cross-validation against 2026 amendments impossible without source.",
    status: "UNRESOLVED_SOURCE_AND_EXTRACTION"
  },
  {
    target: "SGST_UTGST_RATE_SCHEDULE_GOODS",
    estimated_entries: 4500,
    reason: "Primary consolidated goods rate schedule PDF not acquired in V4.3. Raw tabular extraction and cross-validation against 2026 amendments impossible without source.",
    status: "UNRESOLVED_SOURCE_AND_EXTRACTION"
  },
  {
    target: "CGST_RATE_SCHEDULE_SERVICES",
    estimated_entries: 500,
    reason: "Primary consolidated services rate schedule PDF not acquired in V4.3.",
    status: "UNRESOLVED_SOURCE_AND_EXTRACTION"
  },
  {
    target: "EXEMPTIONS_GOODS_SERVICES",
    estimated_entries: 800,
    reason: "Primary exemptions schedule PDF not acquired in V4.3.",
    status: "UNRESOLVED_SOURCE_AND_EXTRACTION"
  },
  {
    target: "COMPENSATION_CESS_RATES",
    estimated_entries: 200,
    reason: "Compensation cess rate schedules and 2026 HSNS rules not acquired.",
    status: "UNRESOLVED_SOURCE_AND_EXTRACTION"
  }
];

fs.writeFileSync(path.join(outDir, 'database_ready_rates_v5.json'), JSON.stringify(verified_rates, null, 2));
fs.writeFileSync(path.join(outDir, 'unresolved_extractions_v5.json'), JSON.stringify(unresolved, null, 2));

console.log('V5 Extract completed.');
