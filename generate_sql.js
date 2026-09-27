const fs = require('fs');

const hsn = fs.readFileSync('hsn_nodes.jsonl', 'utf8').split('\n').filter(l => l.trim()).map(JSON.parse);
const sac = fs.readFileSync('sac_nodes.jsonl', 'utf8').split('\n').filter(l => l.trim()).map(JSON.parse);

const all = [];
hsn.forEach(n => {
    all.push({
        code: n.code,
        code_type: 'HSN',
        description: String(n.description).replace(/'/g, "''"),
        chapter: String(n.code).substring(0, 2),
        goods_or_service: 'GOODS',
        classification_level: n.level,
        code_length: n.code_length,
        parent_code: n.parent_code || null,
        official_source: 'https://tutorial.gst.gov.in/downloads/HSN_SAC.xlsx',
        source_reference: 'GST Portal Excel SHA256:051108e31063f1ef0d6dfb005a622bcc848878fa2d94fae51a73e67f8916871e'
    });
});
sac.forEach(n => {
    all.push({
        code: n.code,
        code_type: 'SAC',
        description: String(n.description).replace(/'/g, "''"),
        chapter: String(n.code).substring(0, 2),
        goods_or_service: 'SERVICE',
        classification_level: n.level,
        code_length: n.code_length,
        parent_code: n.parent_code || null,
        official_source: 'https://cbic-gst.gov.in/hindi/pdf/central-tax-rate/Notification11-CGST-Annexure.pdf',
        source_reference: "Annexure 11/2017-CTR & Notif 12/2023-CTR. SAC base SHA256:fb4c2005c60ee3ce063945bdb8d34f2adab78c946fabd6d9f05d3d0418cc886b"
    });
});

// Part migrations start at 000011 (000010 = disable RLS)
let fileIndex = 11;
let currentLines = [];

function flushFile(isLast) {
    if (currentLines.length === 0) return;
    if (isLast) {
        currentLines.push('');
        currentLines.push('-- Mark non-leaf nodes');
        currentLines.push('UPDATE catalog.hsn_sac p SET is_leaf = false');
        currentLines.push('WHERE EXISTS (');
        currentLines.push('    SELECT 1 FROM catalog.hsn_sac c');
        currentLines.push('    WHERE c.parent_code = p.code AND c.country_id = p.country_id AND c.code_type = p.code_type');
        currentLines.push(');');
    }
    const part = fileIndex - 10;
    const partStr = String(part).padStart(2, '0');
    const ts = `20260904000${String(fileIndex).padStart(3, '0')}`;
    const content = `-- Migration ${ts}: HSN/SAC canonical master data part ${part}\n` + currentLines.join('\n');
    const filename = `supabase/migrations/${ts}_hsn_sac_data_part${partStr}.sql`;
    fs.writeFileSync(filename, content);
    console.log(`Part ${part} → ${filename} (${content.length} bytes)`);
    fileIndex++;
    currentLines = [];
}

const BATCH_SIZE = 100;
for (let i = 0; i < all.length; i += BATCH_SIZE) {
    const batch = all.slice(i, i + BATCH_SIZE);
    const values = batch.map(r =>
        `  ((SELECT id FROM catalog.countries WHERE iso2 = 'IN'), ` +
        `'${r.code}', '${r.code_type}', '${r.description}', '${r.chapter}', '${r.goods_or_service}', ` +
        `'ACTIVE', '${r.classification_level}', ${r.code_length}, ` +
        `${r.parent_code ? "'" + r.parent_code + "'" : 'NULL'}, true, ` +
        `'${r.official_source}', '${r.source_reference.replace(/'/g, "''")}')`
    ).join(',\n');

    currentLines.push(
        `INSERT INTO catalog.hsn_sac (country_id, code, code_type, description, chapter, goods_or_service, status, classification_level, code_length, parent_code, is_leaf, official_source, source_reference) VALUES\n` +
        values +
        `\nON CONFLICT (country_id, code_type, code) DO UPDATE SET\n` +
        `  description = EXCLUDED.description,\n  status = EXCLUDED.status,\n` +
        `  classification_level = EXCLUDED.classification_level,\n  code_length = EXCLUDED.code_length,\n` +
        `  parent_code = EXCLUDED.parent_code,\n  official_source = EXCLUDED.official_source,\n` +
        `  source_reference = EXCLUDED.source_reference;\n`
    );

    if (currentLines.join('\n').length > 500000) {
        flushFile(false);
    }
}
flushFile(true);

console.log(`Total rows: ${all.length}, Files generated: ${fileIndex - 11}`);
