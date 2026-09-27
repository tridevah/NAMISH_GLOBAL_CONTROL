const fs = require('fs');
const path = require('path');
const yauzl = require('yauzl');
const XLSX = require('xlsx');
const csv = require('csv-parser');

const SRC = 'D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826';
let totalParsed = 0;
let results = {}; // entity -> { physical: 0, emitted: 0, invalid: 0 }
let priMatrix = [];

function getLogicalEntities(fileName) {
    if (fileName.includes('district')) return ['DISTRICT'];
    if (fileName.includes('subdistrict')) return ['SUB_DISTRICT'];
    if (fileName.includes('village') && !fileName.includes('LocalBody') && !fileName.includes('Block') && !fileName.includes('pri')) return ['VILLAGE'];
    if (fileName.includes('block') && !fileName.includes('Village')) return ['BLOCK'];
    if (fileName.includes('blockVillage')) return ['BLOCK_VILLAGE'];
    if (fileName.includes('priLbSpecific')) return ['PRI_DISTRICT', 'PRI_INTERMEDIATE', 'GRAM_PANCHAYAT'];
    if (fileName.includes('ulbSpecific')) return ['URBAN_LOCAL_BODY'];
    if (fileName.includes('tlbSpecific')) return ['TRADITIONAL_LOCAL_BODY'];
    if (fileName.includes('lbSpecificVillage')) return ['LOCAL_BODY_VILLAGE'];
    if (fileName.includes('urbanWard')) return ['URBAN_WARD'];
    if (fileName.includes('priWard')) return ['PRI_WARD'];
    if (fileName.includes('wardCoverage')) return ['WARD_COVERAGE'];
    if (fileName === 'PIN CODE.csv') return ['PINCODE', 'POST_OFFICE'];
    if (fileName === 'Pincodeto_Village_Mapping_2026-08-26_23-05-48.xlsx') return ['PIN_VILLAGE'];
    if (fileName === 'Pincodeto_Urban_Mapping_2026-08-26_23-06-09.xlsx') return ['PIN_URBAN_LOCAL_BODY'];
    return [];
}

async function processXlsxStream(stream, fileName, state) {
    return new Promise((resolve, reject) => {
        let buffers = [];
        stream.on('data', d => buffers.push(d));
        stream.on('end', () => {
            try {
                let buf = Buffer.concat(buffers);
                let wb = XLSX.read(buf, {type: 'buffer'});
                let ws = wb.Sheets[wb.SheetNames[0]];
                let rawRows = XLSX.utils.sheet_to_json(ws, {header:1, defval:''});
                
                let headerIdx = rawRows.findIndex(r => String(r[0]||'').toLowerCase().includes('s.no'));
                if (headerIdx < 0) return resolve();
                
                let header = rawRows[headerIdx].map(c=>String(c||'').trim().toLowerCase());
                let dataRows = rawRows.slice(headerIdx+1);
                
                let entities = getLogicalEntities(fileName);
                
                if (entities.includes('PRI_DISTRICT')) {
                    // special PRI logic
                    let priStats = {};
                    for (let r of dataRows) {
                        let rowObj = {};
                        header.forEach((h, i) => rowObj[h] = r[i]);
                        if (!rowObj['s.no']) continue;
                        
                        let tierCode = parseInt(rowObj['localbody type code'] || 0);
                        let typeName = String(rowObj['localbody type name'] || '').trim();
                        let logical = null;
                        
                        let tnLower = typeName.toLowerCase();
                        if (tierCode === 1 && (tnLower.includes('district') || tnLower.includes('zila') || tnLower.includes('zilla'))) {
                            logical = 'PRI_DISTRICT';
                        } else if (tierCode === 2 && (tnLower.includes('intermediate') || tnLower.includes('block') || tnLower.includes('mandal') || tnLower.includes('samiti') || tnLower.includes('anchalik') || tnLower.includes('janpad') || tnLower.includes('kshetra') || tnLower.includes('taluka') || tnLower.includes('commune'))) {
                            logical = 'PRI_INTERMEDIATE';
                        } else if (tierCode === 3 && (tnLower.includes('gram') || tnLower.includes('village') || tnLower.includes('gaon') || tnLower.includes('halqa'))) {
                            logical = 'GRAM_PANCHAYAT';
                        }
                        
                        let key = state + '|' + tierCode + '|' + typeName;
                        if (!priStats[key]) priStats[key] = { physical:0, emitted:0, invalid:0, logical: logical || 'INVALID' };
                        priStats[key].physical++;
                        
                        if (logical) {
                            priStats[key].emitted++;
                            if (!results[logical]) results[logical] = { physical:0, emitted:0, invalid:0 };
                            results[logical].emitted++;
                            results[logical].physical++;
                        } else {
                            priStats[key].invalid++;
                        }
                    }
                    for (let k in priStats) {
                        let [s, tc, tn] = k.split('|');
                        priMatrix.push({ state: s, tier: tc, typeName: tn, logical: priStats[k].logical, physical: priStats[k].physical, emitted: priStats[k].emitted, invalid: priStats[k].invalid });
                    }
                } else {
                    for (let ent of entities) {
                        if (!results[ent]) results[ent] = { physical:0, emitted:0, invalid:0 };
                        let validCount = dataRows.filter(r => r[0]).length;
                        results[ent].physical += validCount;
                        results[ent].emitted += validCount; // basic counting
                    }
                }
                
                resolve();
            } catch (e) { resolve(); }
        });
    });
}

async function processZip(zipPath, state) {
    return new Promise((resolve) => {
        yauzl.open(zipPath, {lazyEntries: true}, (err, zf) => {
            if (err) return resolve();
            zf.readEntry();
            zf.on('entry', async (e) => {
                let p = new Promise(r => zf.openReadStream(e, (err, s) => {
                    if (err) return r();
                    processXlsxStream(s, e.fileName, state).then(r);
                }));
                await p;
                zf.readEntry();
            });
            zf.on('end', resolve);
        });
    });
}

async function run() {
    console.log('Starting DRY PARSE...');
    const states = fs.readdirSync(SRC).filter(d => fs.statSync(path.join(SRC, d)).isDirectory());
    for (const state of states) {
        const stateDir = path.join(SRC, state);
        const files = fs.readdirSync(stateDir);
        for (const file of files) {
            const fullPath = path.join(stateDir, file);
            if (file.endsWith('.zip')) {
                await processZip(fullPath, state);
            } else if (file.endsWith('.xlsx')) {
                await processXlsxStream(fs.createReadStream(fullPath), file, state);
            }
        }
    }
    
    fs.writeFileSync('D:/NAMISH_GLOBAL_CONTROL/scripts/dry_parse_results.json', JSON.stringify({ results, priMatrix }, null, 2));
    console.log('DRY PARSE COMPLETE.');
}
run();
