import fs from 'fs'

const commonMetadata = {
    'UNECE_REC21_BG': { business_name: 'BAGS', short_name: 'Bag' },
    'UNECE_REC21_BO': { business_name: 'BOTTLES', short_name: 'Bottle' },
    'UNECE_REC21_BX': { business_name: 'BOX', short_name: 'Box' },
    'UNECE_REC21_BE': { business_name: 'BUNDLES', short_name: 'Bundle' },
    'UNECE_REC21_CA': { business_name: 'CANS', short_name: 'Can' },
    'UNECE_REC21_CT': { business_name: 'CARTONS', short_name: 'Carton' },
    'UNECE_REC20_MTQ': { business_name: 'CUBIC METERS', short_name: 'Cbm' },
    'UNECE_REC20_DAY': { business_name: 'DAYS', short_name: 'Day' },
    'UNECE_REC20_DZN': { business_name: 'DOZENS', short_name: 'Dozen' },
    'UNECE_REC20_GRM': { business_name: 'GRAMS', short_name: 'gm' },
    'UNECE_REC20_MGM': { business_name: 'MILLIGRAMS', short_name: 'mg' },
    'UNECE_REC20_HUR': { business_name: 'HOURS', short_name: 'Hr' },
    'UNECE_REC20_KGM': { business_name: 'KILOGRAMS', short_name: 'Kg' },
    'UNECE_REC20_KMT': { business_name: 'KILOMETERS', short_name: 'Km' },
    'UNECE_REC20_LTR': { business_name: 'LITRE', short_name: 'Ltr' },
    'UNECE_REC20_MTR': { business_name: 'METERS', short_name: 'Mtr' },
    'UNECE_REC20_MLT': { business_name: 'MILLILITRES', short_name: 'ml' },
    'UNECE_REC20_C62': { business_name: 'NUMBERS', short_name: 'Nos' },
    'UNECE_REC21_PK': { business_name: 'PACKS', short_name: 'Pack' },
    'UNECE_REC20_PR': { business_name: 'PAIRS', short_name: 'Pair' },
    'UNECE_REC20_H87': { business_name: 'PIECES', short_name: 'Pcs' },
    'UNECE_REC20_DTN': { business_name: 'QUINTAL', short_name: 'Qtl' },
    'UNECE_REC21_RO': { business_name: 'ROLLS', short_name: 'Roll' },
    'UNECE_REC20_E48': { business_name: 'SERVICES', short_name: 'Svc' },
    'UNECE_REC20_SET': { business_name: 'SETS', short_name: 'Set' },
    'UNECE_REC20_FTK': { business_name: 'SQUARE FEET', short_name: 'Sqft' },
    'UNECE_REC20_MTK': { business_name: 'SQUARE METERS', short_name: 'Sqm' },
    'UNECE_REC20_U2': { business_name: 'TABLETS', short_name: 'Tab' },
    'UNECE_REC20_TNE': { business_name: 'METRIC TONS', short_name: 'MT' },
    'UNECE_REC20_EA': { business_name: 'UNITS', short_name: 'Unit' }
}

let code = fs.readFileSync('src/app/api/data-hub/units/route.ts', 'utf8');

const fallbackReplacement = `        if (error && (error.code === 'PGRST200' || error?.message?.includes('Could not find') || error?.code === 'PGRST204' || error?.code === '42703')) {
            // Fallback for unapplied migration
            const fallback = await buildQuery('id, canonical_code, standard_code, name, symbol, category, aliases, status, source, source_version')
            
            let fallbackData = fallback.data || []
            const metaMap: Record<string, any> = ${JSON.stringify(commonMetadata)}
            
            fallbackData = fallbackData.map((u: any) => {
                if (metaMap[u.canonical_code]) {
                    return { ...u, business_name: metaMap[u.canonical_code].business_name, short_name: metaMap[u.canonical_code].short_name, is_common: true }
                }
                return { ...u, is_common: false }
            })

            if (isCommon === 'true') {
                fallbackData = fallbackData.filter((u: any) => u.is_common)
            }
            
            data = fallbackData
            count = isCommon === 'true' ? fallbackData.length : fallback.count
            error = fallback.error
        }`;

code = code.replace(/if \(error && \(?error\.code === 'PGRST200'[\s\S]*?error = fallback\.error\n        \}/, fallbackReplacement);

fs.writeFileSync('src/app/api/data-hub/units/route.ts', code);
