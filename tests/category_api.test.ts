import { config } from 'dotenv';
import * as path from 'path';
config({ path: path.resolve(__dirname, '../.env.local') });

import { describe, it, expect, vi } from 'vitest';
import { GET as categoriesGET } from '../src/app/api/data-hub/units/categories/route';
import { GET as unitsGET } from '../src/app/api/data-hub/units/route';
import { NextRequest } from 'next/server';

vi.mock('../src/utils/auth', () => ({
    getAuthContext: vi.fn().mockResolvedValue({ staff: { status: 'ACTIVE' }, user: { id: 'mock' } })
}));

describe('Unit Master Category API', () => {
    it('should return all 22 distinct categories via full pagination', async () => {
        const req = new NextRequest('http://localhost:3001/api/data-hub/units/categories');
        const res = await categoriesGET(req);
        const data = await res.json();

        expect(data.categories).toBeDefined();
        expect(data.categories.length).toBe(22);
        expect(data.categories).toContain('1');
        expect(data.categories).toContain('2');
        expect(data.categories).toContain('3.9');
        console.log('All categories:', data.categories);
    });

    it('should filter category "1" and return 177 results', async () => {
        const req = new NextRequest('http://localhost:3001/api/data-hub/units?category=1&limit=5');
        const res = await unitsGET(req);
        const data = await res.json();
        expect(data.count).toBe(177);
    });

    it('should filter category "2" and return 507 results', async () => {
        const req = new NextRequest('http://localhost:3001/api/data-hub/units?category=2&limit=5');
        const res = await unitsGET(req);
        const data = await res.json();
        expect(data.count).toBe(507);
    });

    it('should return total 2136 with no filter', async () => {
        const req = new NextRequest('http://localhost:3001/api/data-hub/units?limit=5');
        const res = await unitsGET(req);
        const data = await res.json();
        expect(data.count).toBe(2136);
    });
});
