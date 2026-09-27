const yauzl = require('yauzl');
yauzl.open('D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/BIHAR/downloadDir2026_08_27_00_00_37_836.zip', {lazyEntries: true}, (err, zf) => {
    if (err) throw err;
    zf.readEntry();
    zf.on('entry', (e) => {
        console.log(e.fileName);
        zf.readEntry();
    });
});
