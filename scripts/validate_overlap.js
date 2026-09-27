const fs = require('fs');
const path = require('path');
const yauzl = require('yauzl');
const XLSX = require('xlsx');

const SRC = 'D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826';
let apCodes = { district: new Set(), subdistrict: new Set(), block: new Set() };
let arCodes = { district: new Set(), subdistrict: new Set(), block: new Set() };

function getCodesFromZip(zipPath, codesObj, callback) {
    yauzl.open(zipPath, {lazyEntries: true}, (err, zf) => {
        if (err) throw err;
        zf.readEntry();
        zf.on('entry', (e) => {
            if (e.fileName.includes('districtofSpecific') || e.fileName.includes('subDistrictofSpecific') || e.fileName.includes('blockofspecific')) {
                zf.openReadStream(e, (err, stream) => {
                    let buffers = [];
                    stream.on('data', d => buffers.push(d));
                    stream.on('end', () => {
                        let buf = Buffer.concat(buffers);
                        let wb = XLSX.read(buf, {type: 'buffer'});
                        let ws = wb.Sheets[wb.SheetNames[0]];
                        let rows = XLSX.utils.sheet_to_json(ws, {header:1, defval:''});
                        
                        let headerIdx = rows.findIndex(r => r[0] && String(r[0]).toLowerCase().includes('s.no') || String(r[0]).toLowerCase().includes('s. no'));
                        if (headerIdx >= 0) {
                            let header = rows[headerIdx].map(c=>String(c).toLowerCase().trim().replace(/\r?\n/g, ' '));
                            
                            if (e.fileName.includes('districtofSpecific')) {
                                let codeIdx = header.findIndex(c => c === 'district code');
                                let data = rows.slice(headerIdx+1).filter(r => r[codeIdx] && !isNaN(parseInt(r[codeIdx])));
                                for(let r of data) codesObj.district.add(r[codeIdx]);
                            } else if (e.fileName.includes('subDistrictofSpecific')) {
                                let codeIdx = header.findIndex(c => c === 'subdistrict code' || c === 'sub-district code');
                                let data = rows.slice(headerIdx+1).filter(r => r[codeIdx] && !isNaN(parseInt(r[codeIdx])));
                                for(let r of data) codesObj.subdistrict.add(r[codeIdx]);
                            } else if (e.fileName.includes('blockofspecific')) {
                                let codeIdx = header.findIndex(c => c === 'block code');
                                let data = rows.slice(headerIdx+1).filter(r => r[codeIdx] && !isNaN(parseInt(r[codeIdx])));
                                for(let r of data) codesObj.block.add(r[codeIdx]);
                            }
                        }
                        zf.readEntry();
                    });
                });
            } else {
                zf.readEntry();
            }
        });
        zf.on('end', callback);
    });
}

const apZip = fs.readdirSync(path.join(SRC, 'ANDHRA PRADESH')).filter(f => f.endsWith('.zip'))[0];
const arZip = 'ARUNACHAL_PRADESH_CORE_FIXED.zip';

getCodesFromZip(path.join(SRC, 'ANDHRA PRADESH', apZip), apCodes, () => {
    getCodesFromZip(path.join(SRC, 'ARUNACHAL PRADESH', arZip), arCodes, () => {
        let overlaps = { district: 0, subdistrict: 0, block: 0 };
        for (let c of arCodes.district) if(apCodes.district.has(c)) overlaps.district++;
        for (let c of arCodes.subdistrict) if(apCodes.subdistrict.has(c)) overlaps.subdistrict++;
        for (let c of arCodes.block) if(apCodes.block.has(c)) overlaps.block++;
        
        console.log('Arunachal Districts:', arCodes.district.size, 'Overlap with AP:', overlaps.district);
        console.log('Arunachal SubDistricts:', arCodes.subdistrict.size, 'Overlap with AP:', overlaps.subdistrict);
        console.log('Arunachal Blocks:', arCodes.block.size, 'Overlap with AP:', overlaps.block);
    });
});
