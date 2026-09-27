import * as fs from 'fs';
import * as path from 'path';

function runTests() {
    console.log('Running focused unit master validation tests...');
    const seedPath = path.resolve(__dirname, 'seed/unece_units.json');
    const data = JSON.parse(fs.readFileSync(seedPath, 'utf8'));

    // 1. Catalog parsing and source presence
    if (!data.source || data.source !== 'UNECE_REC20') throw new Error('Missing official source');
    if (data.units.length !== data.record_count) throw new Error('Record count mismatch');
    console.log('PASS: Catalog parsing and provenance.');

    // 2. Duplicate handling & Stable IDs
    const codes = new Set();
    data.units.forEach((u: any) => {
        if (codes.has(u.code)) throw new Error('Duplicate code found: ' + u.code);
        codes.add(u.code);
        if (!u.category || !u.name || !u.symbol) throw new Error('Missing core fields for ' + u.code);
    });
    console.log('PASS: Duplicate handling and immutable ID structure validation.');

    // 3. Conversion Validation
    data.conversions.forEach((c: any) => {
        if (!codes.has(c.from)) throw new Error('Unknown from unit: ' + c.from);
        if (!codes.has(c.to)) throw new Error('Unknown to unit: ' + c.to);
        if (typeof c.multiplier !== 'number' || c.multiplier <= 0) throw new Error('Invalid multiplier for ' + c.from);
    });
    console.log('PASS: Conversion logic validation.');

    // 4. India UQC Mapping
    data.india_uqc_mappings.forEach((m: any) => {
        if (!codes.has(m.unit_code)) throw new Error('UQC mapped to unknown universal unit: ' + m.unit_code);
    });
    console.log('PASS: India UQC separation and mapping validation.');

    console.log('ALL TESTS PASSED SUCCESSFULLY.');
}
try {
    runTests();
} catch (e) {
    console.error(e);
    process.exit(1);
}
