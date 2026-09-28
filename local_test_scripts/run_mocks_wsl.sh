#!/usr/bin/env bash
set -euo pipefail

WIN_ROOT=$(pwd)
WSL_ROOT=$(wslpath -a "$WIN_ROOT")
echo "Running in WSL at $WSL_ROOT"

apk add git >/dev/null 2>&1 || true

MOCK_BIN=$(mktemp -d)
export PATH="$MOCK_BIN:$PATH"

export REMOTE_ROOT="/tmp/mock_root"
export APP_SYMLINK="$REMOTE_ROOT/app"
export PREV_RELEASE_DIR="$REMOTE_ROOT/releases/mock_prev_sha"

cat << 'EOF' > "$MOCK_BIN/scp"
#!/usr/bin/env bash
echo "1" >> /tmp/mock_scp_count
exit 0
EOF
chmod +x "$MOCK_BIN/scp"

cat << 'EOF' > "$MOCK_BIN/git"
#!/usr/bin/env bash
if [[ "$*" == *"rev-parse HEAD"* ]]; then
    echo "3d34be32ce705d006ff697c8266622b0274eb81c"
    exit 0
fi
if [[ "$*" == *"archive"* ]]; then
    T=$(mktemp -d)
    mkdir -p "$T/public" "$T/.next"
    touch "$T/package.json"
    tar -cf - -C "$T" .
    rm -rf "$T"
    exit 0
fi
exec /usr/bin/git "$@"
EOF
chmod +x "$MOCK_BIN/git"

cat << 'EOF' > "$MOCK_BIN/npm"
#!/usr/bin/env bash
if [[ "$*" == *"run build"* ]]; then
    if [ "${MOCK_BUILD_FAIL:-0}" == "1" ]; then
        echo "Mock build failure"
        exit 1
    fi
    mkdir -p .next/standalone/.next/server .next/standalone/.next/static
    mkdir -p .next/standalone/node_modules
    mkdir -p public .next/static/css
    touch .next/standalone/server.js package.json .next/BUILD_ID
    touch .next/static/css/test.css
    echo '<html><link href="/_next/static/css/test.css" /></html>' > public/login
fi
exit 0
EOF
chmod +x "$MOCK_BIN/npm"

export NEW_RELEASE_DIR="$REMOTE_ROOT/releases/3d34be32ce705d006ff697c8266622b0274eb81c"

cat << 'EOF' > "$MOCK_BIN/ssh"
#!/usr/bin/env bash
echo "1" >> /tmp/mock_ssh_count
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
    if [ "$action" == "start" ]; then 
        TARGET=$(readlink -f "$APP_SYMLINK" || true)
        if [ "$TARGET" == "$NEW_RELEASE_DIR" ]; then
            service_active=$MOCK_STARTUP_SUCCESS
        else
            service_active=1
        fi
        return 0
    fi
    if [ "$action" == "is-active" ]; then 
        if [ "$service_active" -eq 1 ]; then return 0; else return 1; fi
    fi
    if [ "$action" == "show" ]; then
        echo "99999"
        return 0
    fi
}
export -f systemctl

function curl() {
    local out_file=""
    local write_out=""
    local url=""
    local is_silent=0
    
    local args=("$@")
    for ((i=0; i<${#args[@]}; i++)); do
        if [[ "${args[i]}" == "-o" ]]; then
            out_file="${args[i+1]}"
        elif [[ "${args[i]}" == "-w" ]]; then
            write_out="${args[i+1]}"
        elif [[ "${args[i]}" == http* ]]; then
            url="${args[i]}"
        elif [[ "${args[i]}" == "-sS" ]] || [[ "${args[i]}" == "-s" ]]; then
            is_silent=1
        fi
    done
    
    local status="000"
    local active_target=$(readlink -f "$APP_SYMLINK" || echo "none")
    
    if [ "$active_target" == "$PREV_RELEASE_DIR" ]; then
        status="$MOCK_ROLLBACK_HEALTH"
        if [ "$status" == "200" ] && [ -n "$out_file" ] && [ "$out_file" != "/dev/null" ]; then
            if [[ "$url" == *"health"* ]]; then
                echo '{"status": "ok", "service": "global-control"}' > "$out_file"
            elif [[ "$url" == *"login"* ]]; then
                echo '<html><link href="/_next/static/css/test.css" /></html>' > "$out_file"
            fi
        fi
    else
        if [[ "$url" == *"login"* ]]; then
            status="$MOCK_NEW_PUBLIC_HEALTH"
            if [ "$status" == "200" ] && [ -n "$out_file" ] && [ "$out_file" != "/dev/null" ]; then
                if [ "$MOCK_ASSET_STATUS" == "MISSING_ASSETS" ]; then
                    echo '<html></html>' > "$out_file"
                else
                    echo '<html><link href="/_next/static/css/test.css" /></html>' > "$out_file"
                fi
            fi
        elif [[ "$url" == *"_next"* ]]; then
            status="$MOCK_ASSET_STATUS"
            if [ "$status" == "MISSING_ASSETS" ]; then status="404"; fi
        else
            status="$MOCK_NEW_INTERNAL_HEALTH"
            if [ "$status" == "200" ] && [ -n "$out_file" ] && [ "$out_file" != "/dev/null" ]; then
                if [ "$MOCK_IDENTITY" != "null" ]; then
                    echo '{"sha": "'$MOCK_IDENTITY'"}' > "$out_file"
                else
                    echo '{"status": "ok", "service": "global-control"}' > "$out_file"
                fi
            fi
        fi
    fi
    
    if [ "$write_out" == "%{http_code}" ]; then
        echo "$status"
    fi
    return 0
}
export -f curl

function jq() {
    if [ "$MOCK_IDENTITY" != "null" ]; then echo "$MOCK_IDENTITY"; else 
      if grep -q "status" "$3"; then echo ""; else echo "$MOCK_IDENTITY"; fi
    fi
}
export -f jq

function ss() { return 0; }
export -f ss

function readlink() {
    if [[ "$*" == *"/proc/99999"* ]]; then
        echo "$MOCK_CWD"
    else
        /usr/bin/readlink "$@"
    fi
}
export -f readlink

MOCK_FUNCS

bash -c "source /tmp/mock_remote_funcs.sh; set -Eeuo pipefail; source /tmp/mock_remote_script.sh"
exit $?
EOF
chmod +x "$MOCK_BIN/ssh"

echo "Running bash syntax checks..."
bash -n local_test_scripts/quick_deploy.sh
bash -n local_test_scripts/run_mocks_wsl.sh
bash -n <(sed -n '/cat << '\''MOCK_FUNCS'\''/,/^MOCK_FUNCS$/p' local_test_scripts/run_mocks_wsl.sh | grep -v 'cat <<' | grep -v 'MOCK_FUNCS')

function run_test() {
    local expected_exit=$1
    local expected_state=$2
    
    export MOCK_STARTUP_SUCCESS=$3
    export MOCK_NEW_INTERNAL_HEALTH=$4
    export MOCK_NEW_PUBLIC_HEALTH=$5
    export MOCK_ASSET_STATUS=$6
    export MOCK_IDENTITY=$7
    export MOCK_ROLLBACK_HEALTH=$8
    
    local override_cwd=$9
    if [ "$override_cwd" == "valid" ]; then
        export MOCK_CWD="$NEW_RELEASE_DIR"
    else
        export MOCK_CWD="$override_cwd"
    fi
    
    local description=${10}
    
    echo -e "\n=== Testing: $description ==="
    
    rm -rf "$REMOTE_ROOT"
    mkdir -p "$PREV_RELEASE_DIR"
    ln -sfn "$PREV_RELEASE_DIR" "$APP_SYMLINK"
    
    rm -f /tmp/mock_scp_count /tmp/mock_ssh_count
    
    set +e
    bash local_test_scripts/quick_deploy.sh | tee /tmp/test_output.log
    local exit_code=${PIPESTATUS[0]}
    set -e
    
    local scp_count=$(cat /tmp/mock_scp_count 2>/dev/null | wc -l)
    local ssh_count=$(cat /tmp/mock_ssh_count 2>/dev/null | wc -l)
    
    local actual_state="UNKNOWN"
    if grep -q "Deployment successful" /tmp/test_output.log; then
        actual_state="CUTOVER_SUCCESS"
    elif grep -q "Rolling back to" /tmp/test_output.log; then
        actual_state="ROLLBACK_PERFORMED"
    elif grep -q "State UNCHANGED" /tmp/test_output.log; then
        actual_state="UNCHANGED"
    elif [ "$scp_count" -eq 0 ] && [ "$ssh_count" -eq 0 ]; then
        actual_state="UNCHANGED"
    elif grep -q "Active release is already" /tmp/test_output.log; then
        actual_state="UNCHANGED"
    fi
    
    local CURRENT_TARGET=$(readlink -f "$APP_SYMLINK" || echo "none")

    echo "ACTUAL EXIT CODE: $exit_code"
    echo "ACTUAL STATE: $actual_state"
    echo "SCP INVOCATIONS: $scp_count"
    echo "SSH INVOCATIONS: $ssh_count"
    echo "CURRENT SYMLINK: $CURRENT_TARGET"
    
    if [ "$exit_code" -ne "$expected_exit" ]; then
        echo "ASSERTION FAILED: Expected exit code $expected_exit, but got $exit_code"
        exit 1
    fi
    if [ "$actual_state" != "$expected_state" ]; then
        echo "ASSERTION FAILED: Expected state '$expected_state', but got '$actual_state'"
        exit 1
    fi
    
    local expected_symlink=""
    if [ "$expected_state" == "CUTOVER_SUCCESS" ]; then
        expected_symlink="$NEW_RELEASE_DIR"
    else
        expected_symlink="$PREV_RELEASE_DIR"
    fi
    
    if [ "$CURRENT_TARGET" != "$expected_symlink" ]; then
        echo "ASSERTION FAILED: Expected symlink $expected_symlink, got $CURRENT_TARGET"
        exit 1
    fi

    if [ "$description" == "Build failure" ]; then
        if [ "$scp_count" -ne 0 ] || [ "$ssh_count" -ne 0 ]; then
            echo "ASSERTION FAILED: Build failure must invoke 0 SCP/SSH. Got SCP=$scp_count, SSH=$ssh_count"
            exit 1
        fi
    fi
    echo "ASSERTIONS PASSED"
}

echo "Starting tests..."
export MOCK_NEW_SHA=$(git rev-parse HEAD)

run_test 0 "CUTOVER_SUCCESS" 1 200 200 200 "null" 200 "valid" "Healthy deployment without SHA in health response"
run_test 1 "ROLLBACK_PERFORMED" 1 200 200 200 "null" 200 "/wrong/cwd/path" "Wrong MainPID working directory"
run_test 1 "ROLLBACK_PERFORMED" 1 200 200 404 "null" 200 "valid" "Missing/public-404 asset"
run_test 1 "ROLLBACK_PERFORMED" 1 500 200 200 "null" 200 "valid" "Candidate health failure with healthy previous release"
run_test 3 "ROLLBACK_PERFORMED" 1 500 200 200 "null" 500 "valid" "Unhealthy rollback"

echo -e "\n=== Testing: Build Failure (No SCP/SSH Invocation) ==="
export MOCK_BUILD_FAIL=1
run_test 1 "UNCHANGED" 1 200 200 200 "null" 200 "valid" "Build failure"
export MOCK_BUILD_FAIL=0

echo -e "\n=== Testing: Same-SHA Deployment ==="
rm -rf "$REMOTE_ROOT"
mkdir -p "$NEW_RELEASE_DIR"
ln -sfn "$NEW_RELEASE_DIR" "$APP_SYMLINK"
rm -f /tmp/mock_scp_count /tmp/mock_ssh_count
set +e
bash local_test_scripts/quick_deploy.sh | tee /tmp/test_output.log
exit_code=${PIPESTATUS[0]}
set -e

scp_count=$(cat /tmp/mock_scp_count 2>/dev/null | wc -l)
ssh_count=$(cat /tmp/mock_ssh_count 2>/dev/null | wc -l)
CURRENT_TARGET=$(readlink -f "$APP_SYMLINK" || echo "none")

echo "ACTUAL EXIT CODE: $exit_code"
echo "SCP INVOCATIONS: $scp_count"
echo "SSH INVOCATIONS: $ssh_count"
echo "CURRENT SYMLINK: $CURRENT_TARGET"

if [ "$exit_code" -ne 1 ]; then
    echo "ASSERTION FAILED: Expected exit code 1 for Same-SHA deployment, got $exit_code"
    exit 1
fi
if [ "$CURRENT_TARGET" != "$NEW_RELEASE_DIR" ]; then
    echo "ASSERTION FAILED: Expected symlink $NEW_RELEASE_DIR, got $CURRENT_TARGET"
    exit 1
fi
echo "ASSERTIONS PASSED"
