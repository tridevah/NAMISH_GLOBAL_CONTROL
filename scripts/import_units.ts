import { config } from 'dotenv';
import * as path from 'path';
config({ path: path.resolve(__dirname, '../.env.local') });
import { createClient } from '@supabase/supabase-js';
import * as fs from 'fs';
import * as crypto from 'crypto';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
    throw new Error('Missing Supabase environment variables: NEXT_PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in .env.local');
}

const urlObj = new URL(supabaseUrl);
console.log('Connecting to project:', urlObj.hostname);

const supabaseAdmin = createClient(supabaseUrl, supabaseKey, {
    auth: {
        persistSession: false,
        autoRefreshToken: false,
        detectSessionInUrl: false
    }
});

(async () => {
    try {
        const seedPath = path.resolve(__dirname, '../seed/unece_parsed.json');
        const seedBytes = fs.readFileSync(seedPath);
        const seedHash = crypto.createHash('sha256').update(seedBytes).digest('hex');

        const seedData = JSON.parse(seedBytes.toString('utf8'));

        console.log('Starting import of', seedData.provenance.source);
        console.log('SHA-256:', seedData.provenance.sha256);

        if (seedHash !== '62e1f03e27e178dc3640385290d9c7b8512d4fd6e0874785fb51f0d408b9da21') {
            throw new Error('Seed SHA-256 validation failed. Has the seed been modified?');
        }

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

        const { data, error } = await supabaseAdmin.rpc('import_unit_master', {
            p_units: mappedUnits,
            p_uqc_mappings: seedData.india_uqc_mappings,
            p_conversions: seedData.unit_conversions
        });

        if (error) {
            console.error('Import transaction failed cleanly to prevent unreviewed overrides. Error Details:', error);
            process.exit(1);
        }

        console.log('Import successful. Transaction result:', data);
    } catch(e) {
        console.error('Import script execution failed:', e);
        process.exit(1);
    }
})();
