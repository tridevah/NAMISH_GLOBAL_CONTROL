#!/bin/bash
echo "Exporting Taxes..."
npx supabase db query "SELECT row_to_json(t) FROM catalog.gst_rate_master t;" --linked > raw_taxes.json
cat raw_taxes.json | jq -c '.rows[].row_to_json' > exported_taxes.jsonl

echo "Exporting Units..."
npx supabase db query "SELECT row_to_json(t) FROM catalog.measurement_units t;" --linked > raw_units.json
cat raw_units.json | jq -c '.rows[].row_to_json' > exported_units.jsonl

echo "Exporting HSN (with pagination)..."
# 22607 rows might be too big for a single query in Supabase CLI (can cause timeout or out-of-memory). Let's chunk it.
rm -f exported_hsn.jsonl
for offset in 0 5000 10000 15000 20000; do
    echo "Offset $offset..."
    npx supabase db query "SELECT row_to_json(t) FROM catalog.hsn_sac t ORDER BY id LIMIT 5000 OFFSET $offset;" --linked > raw_hsn_$offset.json
    cat raw_hsn_$offset.json | jq -c '.rows[].row_to_json' >> exported_hsn.jsonl
done

echo "Export Complete."
wc -l exported_taxes.jsonl exported_units.jsonl exported_hsn.jsonl
