ssh -i ~/.ssh/namish_erp_vps tridevah@97.74.92.189 "cat /proc/\$(systemctl show -p MainPID --value namish-erp.service)/environ | tr '\0' '\n' | grep GC_WEBHOOK_SECRET | cut -d '=' -f2 | sha256sum"
