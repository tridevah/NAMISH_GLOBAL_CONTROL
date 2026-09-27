#!/bin/bash
npx supabase db query "SELECT secret FROM integration.webhook_endpoints WHERE id = '4eb4da3b-c802-4d44-98b4-9859528e6beb';" --linked > raw_output.txt
cat raw_output.txt | grep -o 'whsec_[a-zA-Z0-9_-]*' > db_secret_clean.txt
sha256sum db_secret_clean.txt > db_hash.txt

ssh -i ~/.ssh/namish_erp_vps tridevah@97.74.92.189 "cat /home/tridevah/ncore-erp-shared/.env.production | grep GC_WEBHOOK_SECRET | cut -d '=' -f2 | tr -d '\"' | tr -d '\r'" > vps_secret_clean.txt
sha256sum vps_secret_clean.txt > vps_hash.txt

DB_SECRET=$(cat db_secret_clean.txt)
VPS_SECRET=$(cat vps_secret_clean.txt)

if [ "$DB_SECRET" == "$VPS_SECRET" ] && [ -n "$DB_SECRET" ]; then
    echo "MATCH"
else
    echo "MISMATCH"
fi
