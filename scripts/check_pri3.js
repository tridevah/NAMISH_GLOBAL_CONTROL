const yauzl = require('yauzl');
const sax = require('sax');
const { Transform } = require('stream');

function readXlsStreamRows(stream, onRow, onEnd) {
    const saxStream = sax.createStream(true, { trim: true });
    let inRow = false, inCell = false, inData = false, currentRow = [], cellData = '';
    
    saxStream.on('opentag', tag => {
        if (tag.name === 'Row') { inRow = true; currentRow = []; }
        else if (inRow && tag.name === 'Cell') { inCell = true; cellData = ''; }
        else if (inCell && tag.name === 'Data') { inData = true; }
    });
    saxStream.on('text', t => { if (inData) cellData += t; });
    saxStream.on('closetag', tag => {
        if (tag === 'Data') inData = false;
        else if (tag === 'Cell') { currentRow.push(cellData.trim()); inCell = false; }
        else if (tag === 'Row') { inRow = false; onRow(currentRow); }
    });
    saxStream.on('end', onEnd);
    stream.pipe(saxStream);
}

yauzl.open('D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/ANDHRA PRADESH/downloadDir2026_08_26_23_57_49_471.zip', {lazyEntries:true}, (err, zf) => {
    zf.readEntry();
    zf.on('entry', entry => {
        if (entry.fileName.includes('priLb')) {
            zf.openReadStream(entry, (err, stream) => {
                let rowNum = 0;
                readXlsStreamRows(stream, row => {
                    if (row[1] == '2') console.log('ROW TYPE 2:', row);
                    if (row[1] == '3' && rowNum++ < 3) console.log('ROW TYPE 3:', row);
                    if (row[1] == '4') console.log('ROW TYPE 4:', row);
                    if (row[1] == '5') console.log('ROW TYPE 5:', row);
                    if (row[1] == '6') console.log('ROW TYPE 6:', row);
                }, () => process.exit(0));
            });
        } else {
            zf.readEntry();
        }
    });
});
