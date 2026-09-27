ssh -i ~/.ssh/namish_erp_vps tridevah@97.74.92.189 << 'EOF'
sudo mv /tmp/namish-gc-dispatcher.service /etc/systemd/system/
sudo systemctl daemon-reload
# KEEP STOPPED
sudo systemctl disable namish-gc-dispatcher.service
EOF
