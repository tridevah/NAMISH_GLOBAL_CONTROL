# -*- coding: utf-8 -*-
import csv
import json
import hashlib
import sys

def parse():
    expected_sha256 = 'e2d06370cdadf5da1bce705783ff5d0d94d11d70eacba6d592adf401c32fb76e'
    
    with open('seed/unece_raw.csv', 'rb') as f:
        file_bytes = f.read()
        actual_sha256 = hashlib.sha256(file_bytes).hexdigest()
        
    if actual_sha256 != expected_sha256:
        print(f"Error: Raw CSV checksum mismatch.\nExpected: {expected_sha256}\nActual:   {actual_sha256}")
        sys.exit(1)
        
    units = []
    codes_seen = set()
    
    # decode for reading
    csv_text = file_bytes.decode('utf-8-sig').splitlines()
    reader = csv.DictReader(csv_text)
    
    for row in reader:
        code = row.get('CommonCode', '').strip()
        if not code:
            raise ValueError(f"Missing CommonCode in row: {row}")
            
        if code in codes_seen:
            raise ValueError(f"Duplicate CommonCode found: {code}")
            
        codes_seen.add(code)
        status_col = row.get('Status', '').strip()
        
        units.append({
            'canonical_code': f"UNECE_REC20_{code}",
            'standard_code': code,
            'name': row.get('Name', '').strip(),
            'symbol': row.get('Symbol', '').strip(),
            'category': row.get('LevelAndCategory', '').strip(),
            'source_status': status_col,
            'status': 'INACTIVE' if status_col in ['X', 'D'] else 'ACTIVE',
            'description': row.get('Description', '').strip()
        })
            
    unit_dict = {u['standard_code']: u for u in units}
    
    india_uqc_list = [
        {"uqc": "BOU", "desc": "BOU - BILLION OF UNITS"}, {"uqc": "BGS", "desc": "BGS - BAGS (Legacy)"},
        {"uqc": "BAG", "desc": "BAG - BAGS (Official)"}, {"uqc": "BDL", "desc": "BDL - BUNDLES (Official)"},
        {"uqc": "CAN", "desc": "CAN - CANS (Official)"}, {"uqc": "MLT", "desc": "MLT - MILLILITRE (Official)"},
        {"uqc": "BAL", "desc": "BAL - BALE"}, {"uqc": "BTL", "desc": "BTL - BOTTLES"},
        {"uqc": "BOX", "desc": "BOX - BOX"}, {"uqc": "BKL", "desc": "BKL - BUCKLES"},
        {"uqc": "BUN", "desc": "BUN - BUNCHES"}, {"uqc": "CBM", "desc": "CBM - CUBIC METER"},
        {"uqc": "CCM", "desc": "CCM - CUBIC CENTIMETER"}, {"uqc": "CMS", "desc": "CMS - CENTIMETER"},
        {"uqc": "CTN", "desc": "CTN - CARTONS"}, {"uqc": "DOZ", "desc": "DOZ - DOZEN"},
        {"uqc": "DRM", "desc": "DRM - DRUM"}, {"uqc": "GGR", "desc": "GGR - GREAT GROSS"},
        {"uqc": "GMS", "desc": "GMS - GRAMS"}, {"uqc": "GRS", "desc": "GRS - GROSS"},
        {"uqc": "GYD", "desc": "GYD - GROSS YARDS"}, {"uqc": "KGS", "desc": "KGS - KILOGRAMS"},
        {"uqc": "KLR", "desc": "KLR - KILOLITRE"}, {"uqc": "KME", "desc": "KME - KILOMETRE"},
        {"uqc": "LTR", "desc": "LTR - LITRES"}, {"uqc": "MTR", "desc": "MTR - METERS"},
        {"uqc": "MTS", "desc": "MTS - METRIC TON"}, {"uqc": "NOS", "desc": "NOS - NUMBERS"},
        {"uqc": "PAC", "desc": "PAC - PACKS"}, {"uqc": "PCS", "desc": "PCS - PIECES"},
        {"uqc": "PRS", "desc": "PRS - PAIRS"}, {"uqc": "QTL", "desc": "QTL - QUINTAL"},
        {"uqc": "ROL", "desc": "ROL - ROLLS"}, {"uqc": "SET", "desc": "SET - SETS"},
        {"uqc": "SQF", "desc": "SQF - SQUARE FEET"}, {"uqc": "SQM", "desc": "SQM - SQUARE METERS"},
        {"uqc": "SQY", "desc": "SQY - SQUARE YARDS"}, {"uqc": "TBS", "desc": "TBS - TABLETS"},
        {"uqc": "TGM", "desc": "TGM - TEN GROSS"}, {"uqc": "THD", "desc": "THD - THOUSANDS"},
        {"uqc": "TON", "desc": "TON - TONNES"}, {"uqc": "TUB", "desc": "TUB - TUBES"},
        {"uqc": "UGS", "desc": "UGS - US GALLONS"}, {"uqc": "UNT", "desc": "UNT - UNITS"},
        {"uqc": "YDS", "desc": "YDS - YARDS"}, {"uqc": "OTH", "desc": "OTH - OTHERS"}
    ]
    
    manual_maps = {
        'KGS': 'KGM', 'GMS': 'GRM', 'MTR': 'MTR', 'SQM': 'MTK', 'CBM': 'MTQ', 'LTR': 'LTR',
        'PCS': 'C62', 'PRS': 'PR', 'DOZ': 'DZN', 'BGS': 'BG', 'BAG': 'BG', 'BDL': 'BE',
        'CAN': 'CA', 'MLT': 'MLT', 'BOX': 'BX', 'CTN': 'CT', 'BTL': 'BO', 'ROL': 'RO',
        'NOS': 'C62', 'PAC': 'PK', 'SET': 'SET', 'SQF': 'FTK', 'SQY': 'YDK', 'TON': 'TNE',
        'CMS': 'CMT', 'DRM': 'DR', 'KLR': 'K6', 'KME': 'KMT', 'UNT': 'C62', 'MTS': 'TNE',
        'QTL': 'DTN', 'CCM': 'CMQ', 'GGR': 'GGR'
    }
    
    uqc_mapping_results = []
    for uqc_entry in india_uqc_list:
        uqc = uqc_entry['uqc']
        mapped_code = manual_maps.get(uqc) # Strict review-only mapping, NO automatic fallback
            
        if mapped_code and mapped_code in codes_seen:
            target_unit = unit_dict[mapped_code]
            uqc_mapping_results.append({
                'uqc_code': uqc, 'uqc_desc': uqc_entry['desc'],
                'target_canonical_code': target_unit['canonical_code'],
                'target_code': mapped_code, 'target_status': target_unit['status'],
                'target_source_status': target_unit['source_status'], 'outcome': 'MAPPED',
                'basis': 'Semantic manual map'
            })
        else:
            uqc_mapping_results.append({
                'uqc_code': uqc, 'uqc_desc': uqc_entry['desc'],
                'target_canonical_code': None, 'target_code': None, 'target_status': None,
                'target_source_status': None, 'outcome': 'UNMAPPED',
                'basis': 'No Match'
            })

    output = {
        'provenance': {
            'source': 'UNECE_REC20',
            'version': 'GitHub datasets/unece-units-of-measure (Redistributed)',
            'commit_url': 'https://github.com/datasets/unece-units-of-measure/tree/031455016cf62d3f5e74ff5ceda79d3eac32a22e',
            'underlying_release': 'UNECE Recommendation 20 (Rev 17)',
            'sha256': actual_sha256
        },
        'india_uqc_mappings': uqc_mapping_results,
        'units': units,
        'unit_conversions': [
            { "from_code": "KGM", "to_code": "GRM", "multiplier": 1000 },
            { "from_code": "TNE", "to_code": "KGM", "multiplier": 1000 },
            { "from_code": "DTN", "to_code": "KGM", "multiplier": 100 },
            { "from_code": "MTR", "to_code": "CMT", "multiplier": 100 },
            { "from_code": "MTR", "to_code": "MMT", "multiplier": 1000 },
            { "from_code": "DZN", "to_code": "C62", "multiplier": 12 },
            { "from_code": "LBR", "to_code": "KGM", "multiplier": 0.45359237 }
        ]
    }
    with open('seed/unece_parsed.json', 'w', encoding='utf-8') as f:
        json.dump(output, f, indent=2)
        
    print(f"Generated seed data: {len(units)} units, {len(india_uqc_list)} UQCs.")

parse()
