ssh -i ~/.ssh/namish_erp_vps tridevah@97.74.92.189 "find /opt /home/tridevah -name 'dispatcher' -type d -path '*/gc-catalog-sync-dispatcher*' 2>/dev/null"
ssh -i ~/.ssh/namish_erp_vps tridevah@97.74.92.189 "systemctl list-units | grep -i sync"
ssh -i ~/.ssh/namish_erp_vps tridevah@97.74.92.189 "systemctl list-units | grep -i catalog"
