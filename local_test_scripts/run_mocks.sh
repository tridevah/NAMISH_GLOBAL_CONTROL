#!/usr/bin/env bash
set -euo pipefail

MOCK_BIN=$(mktemp -d)
export PATH="$MOCK_BIN:$PATH"

export REMOTE_ROOT="/tmp/mock_root"
export APP_SYMLINK="$REMOTE_ROOT/app"
export PREV_RELEASE_DIR="$REMOTE_ROOT/releases/mock_prev_sha"

cat << 'EOF' > "$MOCK_BIN/scp"
#!/usr/bin/env bash
# $1 = -i, $2 = key, $3 = -o, $4 = ConnectTimeout=10, $5 = src, $6 = dest
# cp source to /tmp/
cp "$5" "/tmp/$(basename "$5")"
exit 0
EOF
chmod +x "$MOCK_BIN/scp"

cat << 'EOF' > "$MOCK_BIN/git"
#!/usr/bin/env bash
if [[ "$*" == *"archive"* ]]; then
    T=$(mktemp -d)
    mkdir -p "$T/public" "$T/.next/static"
    mkdir -p "$T/.next/standalone/.next/server"
    touch "$T/.next/standalone/server.js" "$T/package.json" "$T/.next/BUILD_ID"
    tar -cf - -C "$T" .
    rm -rf "$T"
    exit 0
fi
exec /mingw64/bin/git "$@"
EOF
chmod +x "$MOCK_BIN/git"

cat << 'EOF' > "$MOCK_BIN/npm"
#!/usr/bin/env bash
if [[ "$*" == *"run build"* ]]; then
    mkdir -p .next/standalone/.next/server
    touch .next/standalone/server.js .next/standalone/package.json .next/standalone/.next/BUILD_ID
fi
exit 0
EOF
chmod +x "$MOCK_BIN/npm"

export NEW_RELEASE_DIR="$REMOTE_ROOT/releases/$(git rev-parse HEAD || echo mock)"

cat << 'EOF' > "$MOCK_BIN/ssh"
#!/usr/bin/env bash
cat > /tmp/mock_remote_script.sh

cat << 'MOCK_FUNCS' > /tmp/mock_remote_funcs.sh
export REMOTE_ROOT="/tmp/mock_root"
export APP_SYMLINK="$REMOTE_ROOT/app"

function sudo() { "$@"; }
export -f sudo

service_active=1
function systemctl() {
    local action=$1
    if [ "$action" == "stop" ]; then service_active=0; return 0; fi
    if [ "$action" == "start" ]; then service_active=$MOCK_STARTUP_SUCCESS; return 0; fi
    if [ "$action" == "is-active" ]; then 
        if [ "$service_active" -eq 1 ]; then return 0; else return 1; fi
    fi
}
export -f systemctl

function curl() {
    if [[ "$*" == *"login"* ]]; then
        if [ "$MOCK_PUBLIC_STATUS" == "200" ]; then echo "200"; return 0; else echo "000"; return 0; fi
    else
        if [ "$MOCK_INTERNAL_STATUS" == "200" ]; then
            echo '{"sha": "'$MOCK_IDENTITY'"}' > /tmp/hc.json
            echo "200"
            return 0
        else
            echo "000"
            return 0
        fi
    fi
}
export -f curl

function jq() {
    if [ "$MOCK_IDENTITY" != "null" ]; then echo "$MOCK_IDENTITY"; else cat; fi
}
export -f jq

function ss() { return 1; }
export -f ss

function tar() {
    mkdir -p "$NEW_RELEASE_DIR/.next/server" "$NEW_RELEASE_DIR/.next/static/css" "$NEW_RELEASE_DIR/.next/static/chunks" "$NEW_RELEASE_DIR/public" "$NEW_RELEASE_DIR/node_modules"
    touch "$NEW_RELEASE_DIR/server.js" "$NEW_RELEASE_DIR/.release-sha" "$NEW_RELEASE_DIR/.next/BUILD_ID" "$NEW_RELEASE_DIR/package.json"
    touch "$NEW_RELEASE_DIR/.next/static/css/test.css"
    touch "$NEW_RELEASE_DIR/.next/static/chunks/test.js"
    return 0
}
export -f tar
MOCK_FUNCS

bash -c "source /tmp/mock_remote_funcs.sh; set -Eeuo pipefail; source /tmp/mock_remote_script.sh"
exit $?
EOF
chmod +x "$MOCK_BIN/ssh"

function run_test() {
    export MOCK_STARTUP_SUCCESS=$1
    export MOCK_INTERNAL_STATUS=$2
    export MOCK_PUBLIC_STATUS=$3
    export MOCK_IDENTITY=$4
    local description=$5
    
    echo -e "\n=== Testing: $description ==="
    
    rm -rf "$REMOTE_ROOT"
    mkdir -p "$PREV_RELEASE_DIR"
    ln -sfn "$PREV_RELEASE_DIR" "$APP_SYMLINK"
    
    set +e
    bash local_test_scripts/quick_deploy.sh
    local exit_code=$?
    set -e
    
    echo "EXIT CODE: $exit_code"
    local CURRENT_TARGET=$(readlink -f "$APP_SYMLINK" || echo "none")
    if [ "$CURRENT_TARGET" == "$PREV_RELEASE_DIR" ]; then echo "ROLLBACK: YES"; else echo "ROLLBACK: NO"; fi
}

echo "Starting tests..."
export MOCK_NEW_SHA=$(git rev-parse HEAD || echo mock)

run_test 0 200 200 "$MOCK_NEW_SHA" "Startup Failure"
run_test 1 500 200 "$MOCK_NEW_SHA" "Internal Health Timeout"
run_test 1 200 200 "wrong_sha" "Identity Mismatch"
run_test 1 200 200 "$MOCK_NEW_SHA" "Success"

rm -rf "$REMOTE_ROOT"
mkdir -p "$NEW_RELEASE_DIR"
ln -sfn "$NEW_RELEASE_DIR" "$APP_SYMLINK"
echo -e "\n=== Testing: Same-SHA Deployment ==="
set +e
bash local_test_scripts/quick_deploy.sh
exit_code=$?
set -e
echo "EXIT CODE: $exit_code"

echo -e "\n=== Testing: Rollback Failure ==="
rm -rf "$REMOTE_ROOT"
mkdir -p "$PREV_RELEASE_DIR"
ln -sfn "$PREV_RELEASE_DIR" "$APP_SYMLINK"
export MOCK_STARTUP_SUCCESS=1
export MOCK_INTERNAL_STATUS=500
export MOCK_PUBLIC_STATUS=200
export MOCK_IDENTITY="$MOCK_NEW_SHA"

cat << 'EOF' > "$MOCK_BIN/ssh"
#!/usr/bin/env bash
cat > /tmp/mock_remote_script.sh
cat << 'MOCK_FUNCS' > /tmp/mock_remote_funcs.sh
export REMOTE_ROOT="/tmp/mock_root"
export APP_SYMLINK="$REMOTE_ROOT/app"
export FAIL_ROLLBACK=1
function sudo() { "$@"; }
service_active=1
call_count=0
function systemctl() {
    local action=$1
    if [ "$action" == "stop" ]; then service_active=0; return 0; fi
    if [ "$action" == "start" ]; then call_count=$((call_count+1)); service_active=1; return 0; fi
    if [ "$action" == "is-active" ]; then 
        if [ "$FAIL_ROLLBACK" == "1" ] && [ "$call_count" -gt 1 ]; then return 1; fi
        if [ "$service_active" -eq 1 ]; then return 0; else return 1; fi
    fi
}
export -f sudo systemctl
function curl() { if [[ "$*" == *"login"* ]]; then echo "200"; return 0; else echo "000"; return 0; fi }
export -f curl
function jq() { echo "wrong"; }
export -f jq
function ss() { return 1; }
export -f ss
function tar() {
    mkdir -p "$NEW_RELEASE_DIR/.next/server" "$NEW_RELEASE_DIR/.next/static/css" "$NEW_RELEASE_DIR/.next/static/chunks" "$NEW_RELEASE_DIR/public" "$NEW_RELEASE_DIR/node_modules"
    touch "$NEW_RELEASE_DIR/server.js" "$NEW_RELEASE_DIR/.release-sha" "$NEW_RELEASE_DIR/.next/BUILD_ID" "$NEW_RELEASE_DIR/package.json"
    touch "$NEW_RELEASE_DIR/.next/static/css/test.css" "$NEW_RELEASE_DIR/.next/static/chunks/test.js"
    return 0
}
export -f tar
MOCK_FUNCS
bash -c "source /tmp/mock_remote_funcs.sh; set -Eeuo pipefail; source /tmp/mock_remote_script.sh"
exit $?
EOF

set +e
bash local_test_scripts/quick_deploy.sh
exit_code=$?
set -e
echo "EXIT CODE: $exit_code"
rm -rf "$MOCK_BIN"
