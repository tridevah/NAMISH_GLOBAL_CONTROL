ssh -i ~/.ssh/namish_erp_vps tridevah@97.74.92.189 "find /etc /srv /home/tridevah -name '*.env*' -exec grep -l GC_DATABASE_URL {} + 2>/dev/null"
