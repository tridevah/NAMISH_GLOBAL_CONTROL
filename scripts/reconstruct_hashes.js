const fs = require('fs');
const crypto = require('crypto');
const path = 'supabase/migrations/20260902000004_tax_coverage_model.sql';
let content = fs.readFileSync(path, 'utf8');

// The applied file's hash:
const appliedHash = crypto.createHash('sha256').update(content).digest('hex');
console.log('Applied Hash:', appliedHash);

// Reconstruct the rollback version:
const rollbackContent = content.replace('-- Rollback removed for commit', `-- Force unconditional rollback\n    RAISE EXCEPTION 'UNCONDITIONAL_ROLLBACK_REHEARSAL_SUCCESS';`);

const rollbackHash = crypto.createHash('sha256').update(rollbackContent).digest('hex');
console.log('Reconstructed Rollback Hash:', rollbackHash);

if (rollbackHash === '5680227ffaab49276ef3f54905866bb87874714542db1ed5301455990fb1412e') {
  console.log('Successfully reconstructed exact rollback version!');
  fs.writeFileSync('C:/Users/Atul1/.gemini/antigravity/brain/66cbea70-fd6b-47b0-a32c-4681abc67020/20260902000004_tax_coverage_model_rehearsal.sql', rollbackContent);
  console.log('Saved to artifact directory.');
} else {
  console.log('Mismatch. Trying alternative line endings or spaces...');
}
