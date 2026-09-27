const crypto = require('crypto');

function normalizePathAndUnicodeNFC(str) { return str ? str.replace(/\\\\/g, '/').normalize('NFC') : ''; }
function normalizeUnicodeNFC(str) { return str ? str.normalize('NFC') : ''; }

function makeKey(sourceFileSha256, internalMemberPath, sheetName, physicalRowNumber, logicalBatchKey, logicalOutputOrdinal, emittedRecordOrdinal) {
    const observationMaterial = JSON.stringify([
        "OBS_V2",
        sourceFileSha256.toLowerCase(),
        normalizePathAndUnicodeNFC(internalMemberPath),
        normalizeUnicodeNFC(sheetName ?? ""),
        Number(physicalRowNumber),
        logicalBatchKey,
        Number(logicalOutputOrdinal),
        Number(emittedRecordOrdinal)
    ]);
    return crypto.createHash("sha256").update(observationMaterial, "utf8").digest("hex");
}

const base = makeKey('AABB', 'file.zip', 'Sheet1', 1, 'BATCH', 1, 1);
const same = makeKey('aabb', 'file.zip', 'Sheet1', 1, 'BATCH', 1, 1);
const diffRow = makeKey('AABB', 'file.zip', 'Sheet1', 2, 'BATCH', 1, 1);
const sheet1_row2 = makeKey('AABB', 'file.zip', 'Sheet1', 2, 'BATCH', 1, 1);
const sheet_row12 = makeKey('AABB', 'file.zip', 'Sheet', 12, 'BATCH', 1, 1);
const windows = makeKey('AABB', 'dir\\\\file.zip', 'Sheet1', 1, 'BATCH', 1, 1);
const unix = makeKey('AABB', 'dir/file.zip', 'Sheet1', 1, 'BATCH', 1, 1);
const composed = makeKey('AABB', 'file.zip', 'A\u030A', 1, 'BATCH', 1, 1); // Å
const decomposed = makeKey('AABB', 'file.zip', '\u00C5', 1, 'BATCH', 1, 1); // Å
const diffLog = makeKey('AABB', 'file.zip', 'Sheet1', 1, 'BATCH', 2, 1);
const diffEmit = makeKey('AABB', 'file.zip', 'Sheet1', 1, 'BATCH', 1, 2);

console.log('same replay -> same key:', base === same);
console.log('different physical row number -> different key:', base !== diffRow);
console.log('Sheet1 + row 2 versus Sheet + row 12 -> different keys:', sheet1_row2 !== sheet_row12);
console.log('Windows \\\\ versus normalized / -> same intended key:', windows === unix);
console.log('Unicode composed/decomposed -> same intended key:', composed === decomposed);
console.log('different logical output ordinal -> different key:', base !== diffLog);
console.log('different emitted record ordinal -> different key:', base !== diffEmit);

