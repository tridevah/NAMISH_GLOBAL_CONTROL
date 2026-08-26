#!/usr/bin/env bash
set -Eeuo pipefail

LOCAL_HEAD=$(git rev-parse HEAD)
ORIGIN_HEAD=$(git rev-parse origin/main 2>/dev/null || echo "")

if [[ "$LOCAL_HEAD" != "$ORIGIN_HEAD" ]]; then
  echo "ERROR: Local HEAD ($LOCAL_HEAD) does not match origin/main ($ORIGIN_HEAD)"
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: Tracked working tree must be clean"
  exit 1
fi

VPS_HOST="97.74.92.189"
VPS_USER="tridevah"
SSH_KEY="$HOME/.ssh/namish_erp_vps"
APP_ROOT="/srv/namish-global-control"
REMOTE_RELEASE_DIR="$APP_ROOT/releases/$LOCAL_HEAD"
SYMLINK_PATH="$APP_ROOT/app"
SERVICE_NAME="namish-global-control.service"

echo "Checking required environment variables on VPS..."
ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no "$VPS_USER@$VPS_HOST" "
  ENV_FILE=/etc/namish-global-control/production.env
  if [ ! -f \ ]; then
    echo 'ERROR: Environment file missing'
    exit 1
  fi
  for key in NEXT_PUBLIC_SUPABASE_URL NEXT_PUBLIC_SUPABASE_ANON_KEY SUPABASE_SERVICE_ROLE_KEY HMAC_SECRET; do
    if ! grep -q "^\=" \; then
      echo "ERROR: Missing required env key: \"
      exit 1
    fi
  done
" || exit 1

echo "Building standalone artifact..."
npm run build

RELEASE_DIR=".next/standalone"
cp -r public "$RELEASE_DIR/"
cp -r .next/static "$RELEASE_DIR/.next/"

echo "Packaging release..."
TAR_FILE="deploy_$LOCAL_HEAD.tar.gz"
tar -czf "$TAR_FILE" -C "$RELEASE_DIR" .
SHA256=$(sha256sum "$TAR_FILE" | awk '{print $1}')
echo "Archive SHA256: $SHA256"

echo "Deploying to VPS..."
ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no "$VPS_USER@$VPS_HOST" "mkdir -p $REMOTE_RELEASE_DIR"
scp -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no "$TAR_FILE" "$VPS_USER@$VPS_HOST:$APP_ROOT/"
ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no "$VPS_USER@$VPS_HOST" "
  cd $APP_ROOT &&
  echo '$SHA256  $TAR_FILE' | sha256sum -c - &&
  tar -xzf $TAR_FILE -C $REMOTE_RELEASE_DIR &&
  rm $TAR_FILE
"

echo "Activating release..."
ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no "$VPS_USER@$VPS_HOST" "
  ln -sfn $REMOTE_RELEASE_DIR $SYMLINK_PATH &&
  sudo systemctl restart $SERVICE_NAME
"

echo "Health checking..."
sleep 5
HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$VPS_HOST:3100/api/health || echo "000")

if [[ "$HEALTH_STATUS" != "200" ]]; then
  echo "ERROR: Health check failed ($HEALTH_STATUS). Initiating rollback..."
  ./scripts/rollback-global-control.sh
  exit 1
fi

echo "Deployment successful."
