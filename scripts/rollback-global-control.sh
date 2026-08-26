#!/usr/bin/env bash
set -Eeuo pipefail

VPS_HOST="97.74.92.189"
VPS_USER="tridevah"
SSH_KEY="$HOME/.ssh/namish_erp_vps"
APP_ROOT="/srv/namish-global-control"
SYMLINK_PATH="$APP_ROOT/app"
SERVICE_NAME="namish-global-control.service"

echo "Finding previous release..."
PREV_RELEASE=$(ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no "$VPS_USER@$VPS_HOST" "ls -1dt $APP_ROOT/releases/* | head -n 2 | tail -n 1")

if [ -z "$PREV_RELEASE" ]; then
  echo "ERROR: Could not determine previous release."
  exit 1
fi

echo "Rolling back to: $PREV_RELEASE"
ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no "$VPS_USER@$VPS_HOST" "
  ln -sfn $PREV_RELEASE $SYMLINK_PATH &&
  sudo systemctl restart $SERVICE_NAME
"

echo "Rollback health check..."
sleep 5
HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$VPS_HOST:3100/api/health || echo "000")

if [[ "$HEALTH_STATUS" != "200" ]]; then
  echo "CRITICAL: Rollback health check failed ($HEALTH_STATUS). Manual intervention required!"
  exit 1
fi

echo "Rollback successful."
