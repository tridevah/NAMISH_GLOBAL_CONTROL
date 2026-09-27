#!/usr/bin/env bash
set -Eeuo pipefail

VPS_HOST="97.74.92.189"
VPS_USER="tridevah"
SSH_KEY="$HOME/.ssh/namish_erp_vps"
APP_ROOT="/srv/namish-global-control"
SYMLINK_PATH="$APP_ROOT/app"
SERVICE_NAME="namish-global-control.service"

TARGET_RELEASE="${1:-}"
if [[ -z "$TARGET_RELEASE" ]]; then
  echo "ERROR: No target release provided for rollback."
  exit 1
fi

echo "Rolling back to: $TARGET_RELEASE"
ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no "$VPS_USER@$VPS_HOST" "
  if [ ! -d \"$TARGET_RELEASE\" ]; then
    echo \"ERROR: Target release directory does not exist.\"
    exit 1
  fi
  ln -sfn \"$TARGET_RELEASE\" \"$SYMLINK_PATH\" &&
  sudo systemctl restart \"$SERVICE_NAME\"
"

echo "Rollback health check..."
MAX_RETRIES=2
RETRY_DELAY=1
HEALTH_STATUS="000"
for ((i=1; i<=MAX_RETRIES; i++)); do
    if HEALTH_STATUS=$(ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no "$VPS_USER@$VPS_HOST" "curl -s -o /dev/null -w '%{http_code}' --max-time 5 --connect-timeout 2 http://127.0.0.1:3100/api/health" 2>/dev/null); then
        if [[ "$HEALTH_STATUS" == "200" ]]; then
            break
        fi
    fi
    sleep $RETRY_DELAY
done

if ! ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no "$VPS_USER@$VPS_HOST" "
  [ \"\$(readlink -f $SYMLINK_PATH)\" = \"$TARGET_RELEASE\" ] &&
  sudo systemctl is-active --quiet $SERVICE_NAME
"; then
  echo "CRITICAL: Rollback validation failed (symlink or service state)."
  exit 1
fi

if [[ "$HEALTH_STATUS" != "200" ]]; then
  echo "CRITICAL: Rollback health check failed ($HEALTH_STATUS)."
  exit 1
fi

echo "Rollback successful."
