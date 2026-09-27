import { config } from 'dotenv';
import * as path from 'path';
config({ path: path.resolve(__dirname, '../.env.local') });

import { GET } from '../src/app/api/data-hub/units/route';
import { NextRequest } from 'next/server';

// Mock getAuthContext globally for the route module
import * as authObj from '../src/utils/auth';
Object.defineProperty(authObj, 'getAuthContext', {
    value: async () => ({ staff: { status: 'ACTIVE' }, user: { id: 'mock' } })
});

(async () => {
    try {
        console.log('Testing /api/data-hub/units');
        
        let req = new NextRequest('http://localhost:3000/api/data-hub/units?limit=5');
        let res = await GET(req);
        let data = await res.json();
        console.log('\n--- DEFAULT API RESPONSE (limit=5) ---');
        console.log(`Total Count: ${data.count}`);
        console.log(`Sample Data:`, JSON.stringify(data.data.slice(0, 2), null, 2));

        req = new NextRequest('http://localhost:3000/api/data-hub/units?search=KGM');
        res = await GET(req);
        data = await res.json();
        console.log('\n--- SEARCH "KGM" ---');
        console.log(`Count: ${data.count}`);
        console.log(`Results:`, JSON.stringify(data.data, null, 2));

        req = new NextRequest('http://localhost:3000/api/data-hub/units?status=INACTIVE');
        res = await GET(req);
        data = await res.json();
        console.log('\n--- STATUS INACTIVE ---');
        console.log(`Count: ${data.count}`);
        
        req = new NextRequest('http://localhost:3000/api/data-hub/units?category=VOLUME');
        res = await GET(req);
        data = await res.json();
        console.log('\n--- CATEGORY VOLUME ---');
        console.log(`Count: ${data.count}`);

    } catch (e) {
        console.error(e);
    }
})();
