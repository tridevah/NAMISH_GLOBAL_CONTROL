#!/bin/bash
export SSH_KEY="dummy"
export VPS_USER="user"
export VPS_HOST="host"
export LOCAL_HEAD="newsha"

# Stub ssh
function ssh() {
    # Stub readlink for deploy
    if [[ "$*" == *"readlink -f "* && "$*" != *"is-active"* ]]; then
        if [[ "$MOCK_MISSING_PREVIOUS" == "1" ]]; then
            echo ""
            return 0
        fi
        echo "/srv/namish-global-control/releases/oldsha"
        return 0
    fi
    # Stub directory check in rollback
    if [[ "$*" == *"[ ! -d"* ]]; then
        return 0
    fi
    # Stub restart in deploy
    if [[ "$*" == *"sudo systemctl restart"* && "$MOCK_IS_ROLLBACK" != "1" ]]; then
        if [[ "$MOCK_RESTART_FAIL" == "1" ]]; then return 1; else return 0; fi
    fi
    # Stub restart in rollback
    if [[ "$*" == *"sudo systemctl restart"* && "$MOCK_IS_ROLLBACK" == "1" ]]; then
        if [[ "$MOCK_ROLLBACK_RESTART_FAIL" == "1" ]]; then return 1; else return 0; fi
    fi
    # Stub validation in rollback
    if [[ "$*" == *"is-active"* ]]; then
        if [[ "$MOCK_ROLLBACK_VALIDATION_FAIL" == "1" ]]; then return 1; else return 0; fi
    fi
    # Stub curl health check
    if [[ "$*" == *"curl"* ]]; then
        if [[ "$MOCK_IS_ROLLBACK" != "1" ]]; then
            if [[ "$MOCK_HTTP_FAIL" == "1" ]]; then echo "500"; return 0; fi
            if [[ "$MOCK_SSH_FAIL" == "1" ]]; then return 1; fi
        else
            if [[ "$MOCK_ROLLBACK_HTTP_FAIL" == "1" ]]; then echo "500"; return 0; fi
        fi
        echo "200"
        return 0
    fi
    return 0
}
export -f ssh

run_deploy() {
    bash ./scripts/deploy-global-control-test.sh
}

cat << 'WRAPPER' > scripts/rollback-wrapper.sh
#!/bin/bash
export MOCK_IS_ROLLBACK=1
bash ./scripts/rollback-global-control.sh "$@"
WRAPPER
chmod +x scripts/rollback-wrapper.sh
sed -i 's|\./scripts/rollback-global-control.sh|./scripts/rollback-wrapper.sh|g' scripts/deploy-global-control-test.sh

echo "--- 1. Missing previous release ---"
MOCK_MISSING_PREVIOUS=1 run_deploy || true
echo "--- 2. Failed deployment restores exact target ---"
MOCK_RESTART_FAIL=1 run_deploy || true
echo "--- 3. Unhealthy rollback reports failure ---"
MOCK_RESTART_FAIL=1 MOCK_ROLLBACK_HTTP_FAIL=1 run_deploy || true
