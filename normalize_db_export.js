const fs = require('fs');

function extractAndNormalizeDb(inputFile, outputFile) {
    const raw = fs.readFileSync(inputFile, 'utf8');
    let parsed = JSON.parse(raw);
    rows = Array.isArray(parsed) ? parsed : (parsed.rows || []);

    const data = rows.map(r => ({
        code_type: r.code_type,
        code: r.code,
        description: r.description ? String(r.description).normalize('NFC') : null,
        parent_code: r.parent_code || null,
        classification_level: r.classification_level || null
    }));

    data.sort((a, b) => {
        if (a.code_type < b.code_type) return -1;
        if (a.code_type > b.code_type) return 1;
        if (a.code < b.code) return -1;
        if (a.code > b.code) return 1;
        return 0;
    });

    const lines = data.map(obj => JSON.stringify(obj));
    fs.writeFileSync(outputFile, lines.join('\n') + '\n', { encoding: 'utf8' });
}

extractAndNormalizeDb('db_hsn_export.json', 'normalized_db_hsn.json');
extractAndNormalizeDb('db_sac_export.json', 'normalized_db_sac.json');
console.log('DB normalized exports generated.');
