import json
import re

with open('unit_master_rehearsal.sql', 'r', encoding='utf8') as f:
    content = f.read()

m = re.search(r"v_units JSONB := '(\[.*?\])'::jsonb;", content, re.DOTALL)
if m:
    data = m.group(1)
    try:
        units = json.loads(data)
        requested = ["Bag", "Bottle", "Box", "Bundle", "Can", "Carton", "Cubic Meter", "Day", "Dozen", "Gram", "Milligram", "Hour", "Kilogram", "Kilometer", "Litre", "Meter", "Millilitre", "Number", "Pack", "Pair", "Piece", "Quintal", "Roll", "Service", "Set", "Square Feet", "Square Meter", "Tablet", "Metric Ton", "Unit"]
        for req in requested:
            kw = req.lower()
            exacts = [u for u in units if u['name'].lower() == kw]
            if not exacts: exacts = [u for u in units if u['name'].lower() in [kw + 's', kw + 'es']]
            if not exacts: exacts = [u for u in units if kw in u['name'].lower()]
            found = [{"code": u["canonical_code"], "name": u["name"], "status": u["status"], "std": u["standard_code"]} for u in exacts]
            print(f"\n--- {req} ---")
            print(json.dumps(found[:3], indent=2))
    except Exception as e:
        print("Error parsing json:", e)
else:
    print("Not found")
