#!/bin/bash
set -e
SHA=$(git rev-parse HEAD)
echo "Deploying GC SHA: $SHA"

echo "Building locally..."
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
npm ci
npm run build

echo "Packaging standalone artifact..."
cp -r public .next/standalone/public
cp -r .next/static .next/standalone/.next/static
tar -czf /tmp/deploy_$SHA.tar.gz -C .next/standalone .

echo "Uploading artifact..."
scp -i ~/.ssh/namish_erp_vps /tmp/deploy_$SHA.tar.gz tridevah@97.74.92.189:/tmp/

echo "Deploying on VPS..."
ssh -i ~/.ssh/namish_erp_vps tridevah@97.74.92.189 << EOF
set -e
sudo systemctl stop namish-global-control.service || true
mkdir -p /srv/namish-global-control/releases/$SHA
tar -xzf /tmp/deploy_$SHA.tar.gz -C /srv/namish-global-control/releases/$SHA

ln -sfn /srv/namish-global-control/releases/$SHA /srv/namish-global-control/app
sudo systemctl start namish-global-control.service
echo "Deployment successful: $SHA"
EOF
