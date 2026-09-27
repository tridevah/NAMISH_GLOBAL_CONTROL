ssh -i ~/.ssh/namish_erp_vps tridevah@97.74.92.189 << 'EOF'
sudo mkdir -p /srv/namish-global-control/dispatcher
sudo chown -R tridevah:tridevah /srv/namish-global-control/dispatcher
tar -xzf /tmp/dispatcher.tar.gz -C /srv/namish-global-control/
cd /srv/namish-global-control/dispatcher
npm ci --production
EOF
