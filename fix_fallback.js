import fs from 'fs'

const commonCodes = [
    'UNECE_REC21_BG', 'UNECE_REC21_BO', 'UNECE_REC21_BX', 'UNECE_REC21_BE',
    'UNECE_REC21_CA', 'UNECE_REC21_CT', 'UNECE_REC20_MTQ', 'UNECE_REC20_DAY',
    'UNECE_REC20_DZN', 'UNECE_REC20_GRM', 'UNECE_REC20_MGM', 'UNECE_REC20_HUR',
    'UNECE_REC20_KGM', 'UNECE_REC20_KMT', 'UNECE_REC20_LTR', 'UNECE_REC20_MTR',
    'UNECE_REC20_MLT', 'UNECE_REC20_C62', 'UNECE_REC21_PK', 'UNECE_REC20_PR',
    'UNECE_REC20_H87', 'UNECE_REC20_DTN', 'UNECE_REC21_RO', 'UNECE_REC20_E48',
    'UNECE_REC20_SET', 'UNECE_REC20_FTK', 'UNECE_REC20_MTK', 'UNECE_REC20_U2',
    'UNECE_REC20_TNE', 'UNECE_REC20_EA'
];

let code = fs.readFileSync('src/app/api/data-hub/units/route.ts', 'utf8');

const fallbackReplacement = `        if (error && (error.code === 'PGRST200' || error?.message?.includes('Could not find') || error?.code === 'PGRST204' || error?.code === '42703')) {
            // Fallback for unapplied migration
            const fallback = await buildQuery('id, canonical_code, standard_code, name, symbol, category, aliases, status, source, source_version')
            
            let fallbackData = fallback.data || []
            if (isCommon === 'true') {
                const businessCodes = ${JSON.stringify(commonCodes)}
                fallbackData = fallbackData.filter((u: any) => businessCodes.includes(u.canonical_code))
            }
            
            data = fallbackData
            count = isCommon === 'true' ? fallbackData.length : fallback.count
            error = fallback.error
        }`;

code = code.replace(/if \(error && \(?error\.code === 'PGRST200'[\s\S]*?error = fallback\.error\n        \}/, fallbackReplacement);

fs.writeFileSync('src/app/api/data-hub/units/route.ts', code);
