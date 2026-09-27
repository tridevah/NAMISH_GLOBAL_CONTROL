#!/usr/bin/env bash
set -Eeuo pipefail

LOCAL_HEAD=$(git rev-parse HEAD)
ORIGIN_HEAD=$(git rev-parse origin/main 2>/dev/null || echo "")

if [[ "$LOCAL_HEAD" != "$ORIGIN_HEAD" ]]; then
  echo "ERROR: Local HEAD ($LOCAL_HEAD) does not match origin/main ($ORIGIN_HEAD)"
  exit 1
fi

if [[ -n "$(git status -uno --porcelain)" ]]; then
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
if ! ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no "$VPS_USER@$VPS_HOST" bash << 'EOF'
  ENV_FILE=/etc/namish-global-control/production.env
  if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: Environment file missing"
    exit 1
  fi
  for key in NEXT_PUBLIC_SUPABASE_URL NEXT_PUBLIC_SUPABASE_ANON_KEY SUPABASE_SERVICE_ROLE_KEY HMAC_SECRET; do
    if ! grep -q "^$key=" "$ENV_FILE"; then
      echo "ERROR: Missing required env key: $key"
      exit 1
    fi
  done
EOF
then
  echo "ERROR: Remote environment precheck failed."
  exit 1
fi

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

# Record the previous release as the rollback target before deploying
echo "Determining previous release..."
PREVIOUS_RELEASE_DIR=$(ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no "$VPS_USER@$VPS_HOST" "readlink -f $SYMLINK_PATH")

if [[ -z "$PREVIOUS_RELEASE_DIR" || "$PREVIOUS_RELEASE_DIR" != "$APP_ROOT/releases/"* ]]; then
  echo "ERROR: Invalid or missing previous release: $PREVIOUS_RELEASE_DIR"
  exit 1
fi

if [[ "$PREVIOUS_RELEASE_DIR" == "$REMOTE_RELEASE_DIR" ]]; then
  echo "ERROR: Target release is already the active release. Aborting to prevent overwrite."
  exit 1
fi

echo "Verifying previous release directory exists on VPS..."
if ! ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no "$VPS_USER@$VPS_HOST" "[ -d \"$PREVIOUS_RELEASE_DIR\" ]"; then
  echo "ERROR: Previous release directory does not exist on VPS: $PREVIOUS_RELEASE_DIR"
  exit 1
fi

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
if ! ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no "$VPS_USER@$VPS_HOST" "
  ln -sfn $REMOTE_RELEASE_DIR $SYMLINK_PATH &&
  sudo systemctl restart $SERVICE_NAME
"; then
  echo "ERROR: Activation/restart failed. Initiating rollback..."
  if ! ./scripts/rollback-global-control.sh "$PREVIOUS_RELEASE_DIR"; then
    echo "CRITICAL: Rollback failed! Manual intervention required."
    exit 1
  fi
  exit 1
fi

echo "Health checking..."
MAX_RETRIES=6
RETRY_DELAY=5
HEALTH_STATUS="000"
for ((i=1; i<=MAX_RETRIES; i++)); do
    if HEALTH_STATUS=$(ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no "$VPS_USER@$VPS_HOST" "curl -s -o /dev/null -w '%{http_code}' --max-time 5 --connect-timeout 2 http://127.0.0.1:3100/api/health" 2>/dev/null); then
        if [[ "$HEALTH_STATUS" == "200" ]]; then
            break
        fi
    else
        echo "Health check SSH command failed (attempt $i/$MAX_RETRIES)."
        HEALTH_STATUS="SSH_ERROR"
    fi
    sleep $RETRY_DELAY
done

if [[ "$HEALTH_STATUS" != "200" ]]; then
  echo "ERROR: Health check failed ($HEALTH_STATUS). Initiating rollback..."
  if ! ./scripts/rollback-global-control.sh "$PREVIOUS_RELEASE_DIR"; then
    echo "CRITICAL: Rollback failed! Manual intervention required."
    exit 1
  fi
  exit 1
fi

echo "Deployment successful."
