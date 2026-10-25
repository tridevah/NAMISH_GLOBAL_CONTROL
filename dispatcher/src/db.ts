import { Pool } from 'pg';
import * as dotenv from 'dotenv';
import * as path from 'path';
import * as fs from 'fs';

let connectionString = process.env.GC_DATABASE_URL;

if (!connectionString) {
    const envPaths = [
        path.resolve(process.cwd(), '.env.worker'),
        path.resolve(process.cwd(), '../.env.worker'),
        path.resolve(__dirname, '../../.env.worker')
    ];
    for (const p of envPaths) {
        if (fs.existsSync(p)) {
            dotenv.config({ path: p });
            connectionString = process.env.GC_DATABASE_URL;
            if (connectionString) break;
        }
    }
}

if (!connectionString || !connectionString.startsWith('postgres://')) {
    console.error('FATAL: Valid GC_DATABASE_URL environment variable is required to prevent localhost fallback.');
    process.exit(1);
}

export const pool = new Pool({
    connectionString,
    ssl: { rejectUnauthorized: false }
});
