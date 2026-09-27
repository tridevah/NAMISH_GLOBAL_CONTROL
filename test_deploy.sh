#!/bin/bash
export SSH_KEY="dummy"
export VPS_USER="user"
export VPS_HOST="host"
export REMOTE_RELEASE_DIR="/tmp/release"
export SYMLINK_PATH="/tmp/app"
export SERVICE_NAME="service"

function ssh() {
    if [[ "$*" == *"sudo systemctl restart"* ]]; then
        if [[ "$MOCK_RESTART_FAIL" == "1" ]]; then return 1; else return 0; fi
    elif [[ "$*" == *"curl"* ]]; then
        if [[ "$MOCK_SSH_FAIL" == "1" ]]; then return 1; fi
        if [[ "$MOCK_HTTP_FAIL" == "1" ]]; then echo "500"; return 0; fi
        echo "200"; return 0;
    fi
    return 0
}
export -f ssh

mkdir -p scripts
cat << 'ROLLBACK' > scripts/rollback-global-control.sh
#!/bin/bash
if [[ "$MOCK_ROLLBACK_FAIL" == "1" ]]; then exit 1; else exit 0; fi
ROLLBACK
chmod +x scripts/rollback-global-control.sh

run_deploy() {
    echo "Activating release..."
    if ! ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no "$VPS_USER@$VPS_HOST" "
      ln -sfn $REMOTE_RELEASE_DIR $SYMLINK_PATH &&
      sudo systemctl restart $SERVICE_NAME
    "; then
      echo "ERROR: Activation/restart failed. Initiating rollback..."
      if ! ./scripts/rollback-global-control.sh; then
        echo "CRITICAL: Rollback failed! Manual intervention required."
        return 1
      fi
      return 1
    fi

    echo "Health checking..."
    MAX_RETRIES=2
    RETRY_DELAY=1
    HEALTH_STATUS="000"
    for ((i=1; i<=MAX_RETRIES; i++)); do
        if HEALTH_STATUS=$(ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no "$VPS_USER@$VPS_HOST" "curl -s -o /dev/null -w '%{http_code}' --max-time 5 --connect-timeout 2 http://127.0.0.1:3100/api/health"); then
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
      if ! ./scripts/rollback-global-control.sh; then
        echo "CRITICAL: Rollback failed! Manual intervention required."
        return 1
      fi
      return 1
    fi

    echo "Deployment successful."
    return 0
}

echo "--- 1. Restart failure ---"
MOCK_RESTART_FAIL=1 run_deploy
echo "--- 2. Health-check SSH failure ---"
MOCK_RESTART_FAIL=0 MOCK_SSH_FAIL=1 run_deploy
echo "--- 3. HTTP non-200 ---"
MOCK_SSH_FAIL=0 MOCK_HTTP_FAIL=1 run_deploy
echo "--- 4. Successful health check ---"
MOCK_HTTP_FAIL=0 run_deploy
