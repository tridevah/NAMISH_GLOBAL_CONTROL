import { config } from 'dotenv';
config({ path: '.env.local' });
import { createAdminClient } from '../../src/utils/supabase/admin';
import * as fs from 'fs';
import * as path from 'path';

(async () => {
    try {
        const seedPath = path.resolve(__dirname, '../seed/unece_parsed.json');
        const seedData = JSON.parse(fs.readFileSync(seedPath, 'utf8'));

        console.log('Starting import of', seedData.provenance.source);
        console.log('SHA-256:', seedData.provenance.sha256);

        const mappedUnits = seedData.units.map((u: any) => ({
            canonical_code: u.canonical_code,
            standard_code: u.standard_code,
            name: u.name,
            symbol: u.symbol,
            category: u.category,
            source_status: u.source_status,
            status: u.status,
            description: u.description,
            source: seedData.provenance.source,
            source_version: seedData.provenance.version
        }));

        const { data, error } = await createAdminClient().rpc('import_unit_master', {
            p_units: mappedUnits,
            p_uqc_mappings: seedData.india_uqc_mappings,
            p_conversions: seedData.unit_conversions
        });

        if (error) {
            console.error('Import transaction failed cleanly to prevent unreviewed overrides. Error Details:', error);
            process.exit(1);
        }

        console.log('Import successful. Transaction result:', data);
    } catch (e: any) {
        console.error('Import script execution failed:', e);
        process.exit(1);
    }
})();
