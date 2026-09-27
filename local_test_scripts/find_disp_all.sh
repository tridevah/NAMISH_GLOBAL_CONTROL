ssh -i ~/.ssh/namish_erp_vps tridevah@97.74.92.189 "find / -name package.json -exec grep -l 'gc-catalog-sync-dispatcher' {} + 2>/dev/null"
