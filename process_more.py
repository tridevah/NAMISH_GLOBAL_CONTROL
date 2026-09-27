import json
import re

with open('unit_master_rehearsal.sql', 'r', encoding='utf8') as f:
    content = f.read()

m = re.search(r"v_units JSONB := '(\[.*?\])'::jsonb;", content, re.DOTALL)
if m:
    data = m.group(1)
    units = json.loads(data)
    
    queries = {
        "Cubic Meter": ["cubic metre", "MTQ"],
        "Kilometer": ["kilometre", "KMT"],
        "Meter": ["metre", "MTR"],
        "Square Feet": ["square foot", "FTK"],
        "Square Meter": ["square metre", "MTK"],
        "Quintal": ["decitonne", "quintal", "DTN"],
        "Metric Ton": ["tonne", "TNE"],
        "Number": ["C62"],
        "Unit": ["EA", "C62"]
    }
    
    for q, kws in queries.items():
        found = []
        for u in units:
            name = u['name'].lower()
            std = u['standard_code']
            for kw in kws:
                if kw in name or kw == std:
                    found.append(u)
                    break
        
        found = [{"code": u["canonical_code"], "name": u["name"], "status": u["status"], "std": u["standard_code"]} for u in found]
        print(f"\n--- {q} ---")
        print(json.dumps(found[:3], indent=2))
