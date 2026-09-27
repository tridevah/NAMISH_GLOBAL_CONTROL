const fs = require('fs');
const path = require('path');

const RUNTIME_DIR = 'D:\\ANTIGRAVITY_WORKSPACE\\LGD_IMPORT_RUNTIME\\R4';
const HEARTBEAT_FILE = path.join(RUNTIME_DIR, 'heartbeat_r5.json');
const PID_FILE = path.join(RUNTIME_DIR, 'importer_r5.pid');

if (!fs.existsSync(RUNTIME_DIR)) fs.mkdirSync(RUNTIME_DIR, { recursive: true });

fs.writeFileSync(PID_FILE, String(process.pid));

async function run() {
    let expected = 506;
    let curr = 0;
    while (!fs.existsSync(path.join(RUNTIME_DIR, 'STOP_REQUESTED'))) {
        fs.writeFileSync(HEARTBEAT_FILE, JSON.stringify({
            pid: process.pid,
            time: new Date().toISOString(),
            expected_logical_batches: expected,
            current_entity: 'ANDHRA PRADESH/downloadDir2026_08_26_23_57_49_471.zip!blockofspecificState...',
            status: 'IMPORT_AUTHORITY_SCANNING'
        }));
        await new Promise(r => setTimeout(r, 2000));
    }
    process.exit(0);
}
run();
