const fs = require('fs');
function check() {
  try {
    const hb = JSON.parse(fs.readFileSync('D:/ANTIGRAVITY_WORKSPACE/LGD_IMPORT_RUNTIME/R9/heartbeat.json', 'utf8'));
    if (hb.current_logical_output === 'COMPLETE' || hb.status !== 'RUNNING') {
      console.log('Finished!', JSON.stringify(hb));
      process.exit(0);
    } else {
      console.log('Running: batch', hb.batches_completed, 'rows:', hb.rows_staged);
      setTimeout(check, 5000);
    }
  } catch(e) {
    console.log('Error reading heartbeat', e.message);
    setTimeout(check, 5000);
  }
}
check();
