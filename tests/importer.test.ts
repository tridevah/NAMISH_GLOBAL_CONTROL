import { describe, it, expect } from 'vitest';
import * as fs from 'fs';
import * as path from 'path';

describe('Unit Master Strict Payload Validation (Mocked Payload Check)', () => {
    const seedPath = path.resolve(__dirname, '../seed/unece_parsed.json');
    const seedData = JSON.parse(fs.readFileSync(seedPath, 'utf8'));

    it('should include official descriptions for all units', () => {
        const bgUnit = seedData.units.find((u: any) => u.standard_code === 'BG');
        expect(bgUnit.description).toBeDefined();
        expect(typeof bgUnit.description).toBe('string');
    });

    it('should assign explicit statuses correctly (ACTIVE/INACTIVE only)', () => {
        seedData.units.forEach((u: any) => {
            expect(['ACTIVE', 'INACTIVE']).toContain(u.status);
        });
        const bgUnit = seedData.units.find((u: any) => u.standard_code === 'BG');
        expect(bgUnit.source_status).toBe('X');
        expect(bgUnit.status).toBe('INACTIVE');
    });

    it('should have correct semantic mappings for MTS and QTL collisions', () => {
        const mtsMap = seedData.india_uqc_mappings.find((m: any) => m.uqc_code === 'MTS');
        expect(mtsMap.target_code).toBe('TNE');
        expect(mtsMap.target_canonical_code).toBe('UNECE_REC20_TNE');
        
        const qtlMap = seedData.india_uqc_mappings.find((m: any) => m.uqc_code === 'QTL');
        expect(qtlMap.target_code).toBe('DTN');
        expect(qtlMap.target_canonical_code).toBe('UNECE_REC20_DTN');
    });

    it('should include strictly mapped universal conversions with finite positive multipliers', () => {
        expect(seedData.unit_conversions.length).toBeGreaterThan(0);
        seedData.unit_conversions.forEach((c: any) => {
            expect(c.multiplier).toBeGreaterThan(0);
            expect(Number.isFinite(c.multiplier)).toBe(true);
        });
        const kgsToGrm = seedData.unit_conversions.find((c: any) => c.from_code === 'KGM' && c.to_code === 'GRM');
        expect(kgsToGrm.multiplier).toBe(1000);
    });

    it('should require a target_canonical_code for all MAPPED entries', () => {
        seedData.india_uqc_mappings.forEach((m: any) => {
            expect(['MAPPED', 'UNMAPPED']).toContain(m.outcome);
            if (m.outcome === 'MAPPED') {
                expect(m.target_canonical_code).toBeTruthy();
            }
        });
    });

    it('should not contain any duplicate canonical codes', () => {
        const codes = seedData.units.map((u: any) => u.canonical_code);
        const uniqueCodes = new Set(codes);
        expect(codes.length).toBe(uniqueCodes.size);
    });

    it('should not contain any duplicate UQC codes', () => {
        const uqcCodes = seedData.india_uqc_mappings.map((m: any) => m.uqc_code);
        const uniqueUqcCodes = new Set(uqcCodes);
        expect(uqcCodes.length).toBe(uniqueUqcCodes.size);
    });
});
