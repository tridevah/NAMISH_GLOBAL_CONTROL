#!/bin/bash
set -e
SHA=$(git rev-parse HEAD)
echo "Deploying GC SHA: $SHA"

git archive --format=tar.gz -o /tmp/deploy_$SHA.tar.gz HEAD
scp -i ~/.ssh/namish_erp_vps /tmp/deploy_$SHA.tar.gz tridevah@97.74.92.189:/tmp/

ssh -i ~/.ssh/namish_erp_vps tridevah@97.74.92.189 << EOF
set -e
mkdir -p /srv/namish-global-control/releases/$SHA
tar -xzf /tmp/deploy_$SHA.tar.gz -C /srv/namish-global-control/releases/$SHA
cd /srv/namish-global-control/releases/$SHA

export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"

npm ci
npm run build

ln -sfn /srv/namish-global-control/releases/$SHA /srv/namish-global-control/app
sudo systemctl restart namish-global-control.service
echo "Deployment successful: $SHA"
EOF
