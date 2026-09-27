import { config } from 'dotenv';
import * as path from 'path';
config({ path: path.resolve(__dirname, '../.env.local') });

import { describe, it, expect, vi } from 'vitest';
import { GET } from '../src/app/api/data-hub/units/route';
import { NextRequest } from 'next/server';
import * as fs from 'fs';

vi.mock('../src/utils/auth', () => ({
    getAuthContext: vi.fn().mockResolvedValue({ staff: { status: 'ACTIVE' }, user: { id: 'mock' } })
}));

describe('Unit Master API Tests', () => {
    it('should run and output to file', async () => {
        let output = '';

        let req = new NextRequest('http://localhost:3000/api/data-hub/units?limit=5');
        let res = await GET(req);
        let data = await res.json();
        output += '--- DEFAULT API RESPONSE ---\n';
        output += `Total Count: ${data.count}\n`;
        output += `Sample Data: ${JSON.stringify(data.data.slice(0, 2), null, 2)}\n`;

        req = new NextRequest('http://localhost:3000/api/data-hub/units?search=KGM');
        res = await GET(req);
        data = await res.json();
        output += '\n--- SEARCH KGM ---\n';
        output += `Count: ${data.count}\n`;
        output += `Results: ${JSON.stringify(data.data, null, 2)}\n`;

        req = new NextRequest('http://localhost:3000/api/data-hub/units?status=INACTIVE');
        res = await GET(req);
        data = await res.json();
        output += '\n--- STATUS INACTIVE ---\n';
        output += `Count: ${data.count}\n`;

        fs.writeFileSync('api_test_results.txt', output);
    });
});
