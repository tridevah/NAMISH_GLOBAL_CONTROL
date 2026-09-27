#!/bin/bash
set -e
SHA="be673b532f81a2507df85727d306fe0b86fd75b5"

mkdir -p /srv/namish-global-control/releases/$SHA
tar -xzf /tmp/deploy_$SHA.tar.gz -C /srv/namish-global-control/releases/$SHA
cd /srv/namish-global-control/releases/$SHA

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

npm ci
npm run build

ln -sfn /srv/namish-global-control/releases/$SHA /srv/namish-global-control/app
sudo systemctl restart namish-global-control.service
echo "Deployment successful: $SHA"
