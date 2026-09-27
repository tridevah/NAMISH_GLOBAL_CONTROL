#!/bin/bash
echo "Exporting Taxes..."
npx supabase db query "SELECT row_to_json(t) FROM catalog.gst_rate_master t;" --linked > raw_taxes.json
node local_test_scripts/parse_json.js raw_taxes.json > exported_taxes.jsonl

echo "Exporting Units..."
npx supabase db query "SELECT row_to_json(t) FROM catalog.measurement_units t;" --linked > raw_units.json
node local_test_scripts/parse_json.js raw_units.json > exported_units.jsonl

echo "Exporting HSN (with pagination)..."
rm -f exported_hsn.jsonl
for offset in 0 5000 10000 15000 20000 25000; do
    echo "Offset $offset..."
    npx supabase db query "SELECT row_to_json(t) FROM catalog.hsn_sac t ORDER BY id LIMIT 5000 OFFSET $offset;" --linked > raw_hsn_$offset.json
    node local_test_scripts/parse_json.js raw_hsn_$offset.json >> exported_hsn.jsonl
done

echo "Export Complete."
wc -l exported_taxes.jsonl exported_units.jsonl exported_hsn.jsonl
