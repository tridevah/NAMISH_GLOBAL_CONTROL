#!/bin/bash
echo "Exporting HSN..."
npx supabase db query "SELECT row_to_json(t) FROM catalog.hsn_sac t;" --linked > raw_hsn.txt
cat raw_hsn.txt | grep '^{"row_to_json"' | sed 's/^{"row_to_json"://' | sed 's/}$//' > exported_hsn.json

echo "Exporting Units..."
npx supabase db query "SELECT row_to_json(t) FROM catalog.measurement_units t;" --linked > raw_units.txt
cat raw_units.txt | grep '^{"row_to_json"' | sed 's/^{"row_to_json"://' | sed 's/}$//' > exported_units.json

echo "Exporting Taxes..."
npx supabase db query "SELECT row_to_json(t) FROM catalog.gst_rate_master t;" --linked > raw_taxes.txt
cat raw_taxes.txt | grep '^{"row_to_json"' | sed 's/^{"row_to_json"://' | sed 's/}$//' > exported_taxes.json

echo "Export Complete."
wc -l exported_hsn.json exported_units.json exported_taxes.json
